// Ein Kartenleser nach Drehbuch: jeder Aufruf von `exchange` muss der
// nächste erwartete Schritt sein, sonst scheitert der Test.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/rksv/card/reader_transport.dart';

/// Bytes aus Hex-Zeichen; Leerzeichen werden übergangen (`'62 00 00'`).
Uint8List bytesOf(String hexText) {
  final digits = hexText.replaceAll(RegExp(r'\s'), '');
  if (digits.length.isOdd) {
    throw ArgumentError.value(hexText, 'hexText', 'ungerade Anzahl Zeichen');
  }
  return Uint8List.fromList([
    for (var i = 0; i < digits.length; i += 2)
      int.parse(digits.substring(i, i + 2), radix: 16),
  ]);
}

/// Ein erwarteter Aufruf von `exchange`.
class ScriptedStep {
  const ScriptedStep._(this.out, this.answer, this.error);

  /// Was hinausgehen soll; `null`: nur lesen.
  final Uint8List? out;

  /// Die Antwort des Lesers, wenn [error] nicht gesetzt ist.
  final Uint8List? answer;

  /// Wird statt einer Antwort geworfen.
  final Object? error;
}

/// Schickt [outHex] und bekommt [answerHex] zurück.
ScriptedStep send(String outHex, String answerHex) =>
    ScriptedStep._(bytesOf(outHex), bytesOf(answerHex), null);

/// Liest ohne zu schicken und bekommt [answerHex] zurück.
ScriptedStep read(String answerHex) =>
    ScriptedStep._(null, bytesOf(answerHex), null);

/// Schickt [outHex], dann wirft der Transport [error].
ScriptedStep sendFails(String outHex, Object error) =>
    ScriptedStep._(bytesOf(outHex), null, error);

/// Liest ohne zu schicken, dann wirft der Transport [error].
ScriptedStep readFails(Object error) => ScriptedStep._(null, null, error);

/// Muss innerhalb eines Tests gebaut werden: am Ende des Tests scheitert er,
/// wenn ein Aufruf unerwartet kam oder ein erwarteter fehlt. Ein unerwarteter
/// Aufruf wirft außerdem sofort einen [TestFailure].
class ScriptedReader implements ReaderTransport {
  ScriptedReader(
    List<ScriptedStep> steps, {
    Uint8List? descriptors,
    this.devices = const [],
    this.onExchange,
  }) : _steps = List.of(steps),
       _descriptors = descriptors ?? Uint8List(0) {
    addTearDown(_verify);
  }

  final List<ScriptedStep> _steps;
  final Uint8List _descriptors;

  /// Was [list] meldet.
  final List<UsbDeviceInfo> devices;

  /// Läuft vor jedem Aufruf von [exchange], z. B. um eine Uhr weiterzustellen.
  final void Function()? onExchange;

  /// Das [exchange]-Limit jedes Aufrufs, in der Reihenfolge.
  final List<Duration> limits = [];

  /// Adressen, mit denen [open] aufgerufen wurde.
  final List<String> opened = [];

  /// Wie oft [close] aufgerufen wurde.
  int closed = 0;

  final List<String> _unexpected = [];
  int _done = 0;

  @override
  Future<Uint8List> exchange(Uint8List? out, {required Duration limit}) async {
    onExchange?.call();
    limits.add(limit);
    final index = _done;
    if (_steps.isEmpty) {
      _flag('Aufruf ${index + 1} unerwartet: ${_show(out)}');
    }
    final step = _steps.removeAt(0);
    _done++;
    if (!_same(step.out, out)) {
      _flag(
        'Aufruf ${index + 1}: erwartet ${_show(step.out)}, kam ${_show(out)}',
      );
    }
    final error = step.error;
    if (error != null) throw error;
    return Uint8List.fromList(step.answer!);
  }

  @override
  Future<List<UsbDeviceInfo>> list() async => devices;

  @override
  Future<Uint8List> open(String address) async {
    opened.add(address);
    return _descriptors;
  }

  @override
  Future<void> close() async => closed++;

  @override
  Future<TabletInfo> info() async => const TabletInfo('', '');

  Never _flag(String problem) {
    _unexpected.add(problem);
    throw TestFailure(problem);
  }

  void _verify() {
    if (_unexpected.isNotEmpty) fail(_unexpected.join('\n'));
    if (_steps.isNotEmpty) {
      fail(
        '${_steps.length} erwartete Aufrufe fehlen, der nächste: '
        '${_show(_steps.first.out)}',
      );
    }
  }

  static bool _same(Uint8List? a, Uint8List? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static String _show(Uint8List? data) => data == null
      ? 'nur lesen'
      : data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
}
