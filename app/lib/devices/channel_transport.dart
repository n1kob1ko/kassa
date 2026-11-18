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

  @override
  Future<void> send(Uint8List bytes) async {
    try {
      await channel.invokeMethod<void>('send', {
        'kind': kind.name,
        'address': address,
        'bytes': bytes,
      });
    } on PlatformException catch (e) {
      throw PrinterException(problemOfChannelError(e.code));
    } on MissingPluginException {
      // Kein Android (Tests, andere Plattformen): kein Drucker erreichbar.
      throw const PrinterException(PrintProblem.unreachable);
    }
  }

  @override
  Future<int?> status(List<int> request) async {
    try {
      return await channel.invokeMethod<int>('status', {
        'kind': kind.name,
        'address': address,
        'request': Uint8List.fromList(request),
      });
    } catch (_) {
      return null;
    }
  }
}
