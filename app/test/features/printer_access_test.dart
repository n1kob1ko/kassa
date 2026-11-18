// Die Erlaubnis für einen USB- oder Bluetooth-Drucker holt die Kassa, wenn
// sie aufgeht und wenn die App wieder in den Vordergrund kommt, nicht erst
// mitten im ersten Verkauf.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_devices.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';

final _clock = FixedClock(DateTime(2026, 11, 17, 11));

/// Datenbank mit eingerichtetem Drucker, noch vor dem Start der Oberfläche.
Future<List<Override>> _withPrinter(
  PrinterKind kind,
  String? address,
  FakeDiscovery discovery,
) async {
  _clock.value = DateTime(2026, 11, 17, 11);
  final overrides = await memoryOverrides(clock: _clock, discovery: discovery);
  final c = ProviderContainer(overrides: overrides);
  try {
    final repo = c.read(settingsRepositoryProvider);
    await repo.save(
      (await repo.current()).copyWith(
        printerKind: kind,
        printerAddress: address,
        printerName: 'Kassendrucker',
      ),
    );
  } finally {
    c.dispose();
  }
  return overrides;
}

Future<FakeDiscovery> _open(
  WidgetTester t,
  PrinterKind kind,
  String? address, {
  bool access = true,
}) async {
  final discovery = FakeDiscovery(access: access);
  await pumpKassa(t, overrides: await _withPrinter(kind, address, discovery));
  await t.pumpAndSettle();
  return discovery;
}

Future<void> _resume(WidgetTester t) async {
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('USB: die Kassa fragt beim Aufgehen nach der Erlaubnis', (
    t,
  ) async {
    final d = await _open(t, PrinterKind.usb, '1155:22304');
    expect(find.byKey(const Key('area-kassa')), findsOneWidget);
    expect(d.accessRequests, ['usb:1155:22304']);
  });

  testWidgets('Bluetooth: die Kassa fragt beim Aufgehen nach der Erlaubnis', (
    t,
  ) async {
    final d = await _open(t, PrinterKind.bluetooth, 'AA:BB:CC:DD:EE:FF');
    expect(d.accessRequests, ['bluetooth:AA:BB:CC:DD:EE:FF']);
  });

  testWidgets('Netzwerk oder kein Drucker: keine Frage', (t) async {
    final net = await _open(t, PrinterKind.network, '192.168.0.50:9100');
    await _resume(t);
    expect(net.accessRequests, isEmpty);
    final none = await _open(t, PrinterKind.none, null);
    await _resume(t);
    expect(none.accessRequests, isEmpty);
  });

  testWidgets('USB ohne Adresse: keine Frage', (t) async {
    final d = await _open(t, PrinterKind.usb, '  ');
    expect(d.accessRequests, isEmpty);
  });

  testWidgets('zurück in die App: die Kassa fragt noch einmal', (t) async {
    final d = await _open(t, PrinterKind.usb, '1155:22304');
    await _resume(t);
    expect(d.accessRequests, ['usb:1155:22304', 'usb:1155:22304']);
  });

  testWidgets('abgelehnt: gleich danach wird nicht wieder gefragt (das '
      'Schließen der Frage selbst bringt die App zurück), später schon', (
    t,
  ) async {
    final d = await _open(t, PrinterKind.usb, '1155:22304', access: false);
    expect(d.accessRequests, hasLength(1));
    await _resume(t);
    expect(d.accessRequests, hasLength(1));
    _clock.value = _clock.value.add(const Duration(minutes: 1));
    await _resume(t);
    expect(d.accessRequests, hasLength(2));
  });

  testWidgets('ein Fehler der Frage geht still unter, die Kassa geht', (
    t,
  ) async {
    final discovery = FakeDiscovery()..accessError = StateError('kaputt');
    await pumpKassa(
      t,
      overrides: await _withPrinter(
        PrinterKind.bluetooth,
        'AA:BB:CC:DD:EE:FF',
        discovery,
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(discovery.accessRequests, hasLength(1));
    await tapItem(t, 'cola');
    expect(textOf(t, const Key('cart-total')), isNot('0,00 €'));
  });
}
