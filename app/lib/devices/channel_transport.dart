// Druck über USB und Bluetooth: Android erledigt die Verbindung, Dart spricht
// mit ihm über den Kanal `kassa/printer` (siehe PrinterChannel.kt).

import 'package:flutter/services.dart';

import '../data/settings_repository.dart';
import 'printer.dart';

const printerChannel = MethodChannel('kassa/printer');

/// Übersetzt einen Fehlercode des Kanals; ein unbekannter Code heißt
/// "nicht erreichbar".
PrintProblem problemOfChannelError(String code) => switch (code) {
  'no_permission' => PrintProblem.noPermission,
  'timeout' => PrintProblem.timeout,
  _ => PrintProblem.unreachable,
};

class ChannelTransport implements PrinterTransport {
  /// [kind] ist [PrinterKind.usb] (Adresse `<vendorId>:<productId>`) oder
  /// [PrinterKind.bluetooth] (Adresse ist die MAC-Adresse).
  ChannelTransport(this.kind, this.address, {this.channel = printerChannel});

  final PrinterKind kind;
  final String address;
  final MethodChannel channel;

  final _clock = Stopwatch()..start();

  /// Ende des laufenden Aufrufs auf [_clock]; `null` ohne [startCall].
  Duration? _deadline;

  /// Zählt die aufgegebenen Aufrufe; eine Antwort aus einer früheren Runde
  /// wird ignoriert.
  int _epoch = 0;

  @override
  void startCall(Duration limit) => _deadline = _clock.elapsed + limit;

  @override
  void abandon() {
    _epoch++;
    _deadline = null;
  }

  /// Millisekunden, die Android für diesen Aufruf noch hat. Ohne
  /// [startCall] gilt [printCallLimit] ab jetzt.
  int _budgetMs() {
    final deadline = _deadline ?? _clock.elapsed + printCallLimit;
    final left = (deadline - _clock.elapsed).inMilliseconds;
    return left < 0 ? 0 : left;
  }

  @override
  Future<void> send(Uint8List bytes) async {
    final epoch = _epoch;
    final budget = _budgetMs();
    if (budget <= 0) throw const PrinterException(PrintProblem.timeout);
    try {
      await channel.invokeMethod<void>('send', {
        'kind': kind.name,
        'address': address,
        'bytes': bytes,
        'budgetMs': budget,
      });
    } on PlatformException catch (e) {
      if (epoch != _epoch) throw const PrinterException(PrintProblem.timeout);
      throw PrinterException(problemOfChannelError(e.code));
    } on MissingPluginException {
      // Kein Android (Tests, andere Plattformen): kein Drucker erreichbar.
      throw const PrinterException(PrintProblem.unreachable);
    }
    // Spät, nach dem Aufgeben: für den Druckdienst ist der Aufruf gescheitert.
    if (epoch != _epoch) throw const PrinterException(PrintProblem.timeout);
  }

  @override
  Future<int?> status(List<int> request) async {
    final epoch = _epoch;
    final budget = _budgetMs();
    if (budget <= 0) return null;
    try {
      final answer = await channel.invokeMethod<int>('status', {
        'kind': kind.name,
        'address': address,
        'request': Uint8List.fromList(request),
        'budgetMs': budget,
      });
      return epoch == _epoch ? answer : null;
    } catch (_) {
      return null;
    }
  }
}

/// Fragt Android nach der Erlaubnis für den Drucker, ohne etwas zu senden.
/// `false` ohne Kanal, bei einem Fehler oder bei Ablehnung.
Future<bool> requestChannelAccess(
  MethodChannel channel,
  PrinterKind kind,
  String address,
) async {
  try {
    final granted = await channel.invokeMethod<bool>('requestAccess', {
      'kind': kind.name,
      'address': address,
    });
    return granted ?? false;
  } catch (_) {
    return false;
  }
}
