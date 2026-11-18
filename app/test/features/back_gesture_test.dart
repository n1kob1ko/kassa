// "Zurück" des Tablets: schließt die oberste offene Ebene (Geräte testen, dann
// die Einstellungen), an der Kassa tut es nichts, und das Blatt zur unklaren
// Kartenzahlung bleibt davon unberührt.

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/staff.dart';
import 'package:material_ui/material_ui.dart';

import '../support/kassa_pump.dart';
import '../support/sales.dart';
import '../support/settings_pump.dart';

Future<void> _back(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await t.pumpAndSettle();
}

Future<void> _openDeviceTest(WidgetTester t) async {
  await t.ensureVisible(find.byKey(const Key('open-device-test')));
  await t.tap(find.byKey(const Key('open-device-test')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Zurück auf "Geräte testen" zeigt die Einstellungen', (t) async {
    await pumpSettings(t);
    await _openDeviceTest(t);
    expect(find.byKey(const Key('device-test')), findsOneWidget);
    await _back(t);
    expect(find.byKey(const Key('device-test')), findsNothing);
    expect(find.byKey(const Key('area-settings')), findsOneWidget);
    expect(find.byKey(const Key('open-device-test')), findsOneWidget);
  });

  testWidgets('Zurück in den Einstellungen zeigt den Bereich davor', (t) async {
    await pumpAppLoggedInAsChef(t);
    await t.tap(find.byKey(const Key('tab-Bons')));
    await t.pumpAndSettle();
    await openSettings(t);
    expect(find.byKey(const Key('area-settings')), findsOneWidget);
    await _back(t);
    expect(find.byKey(const Key('area-settings')), findsNothing);
    expect(find.byKey(const Key('area-bons')), findsOneWidget);
  });

  testWidgets('Zurück schließt nur eine Ebene auf einmal', (t) async {
    await pumpSettings(t);
    await _openDeviceTest(t);
    await _back(t);
    expect(find.byKey(const Key('area-settings')), findsOneWidget);
    await _back(t);
    expect(find.byKey(const Key('area-settings')), findsNothing);
    expect(find.byKey(const Key('area-kassa')), findsOneWidget);
  });

  testWidgets('Zurück an der Kassa ändert nichts', (t) async {
    await pumpAppLoggedInAsChef(t);
    await t.tap(find.byKey(const Key('item-tofu-bowl')));
    await t.pumpAndSettle();
    final before = cartOf(t).lines.length;
    await _back(t);
    expect(find.byKey(const Key('area-kassa')), findsOneWidget);
    expect(cartOf(t).lines.length, before);
    expect(t.takeException(), isNull);
  });

  testWidgets('Zurück bei offenem Blatt zur unklaren Zahlung ändert nichts '
      'dahinter', (t) async {
    await pumpSettings(t);
    await _openDeviceTest(t);
    const anna = Staff(id: 'anna', name: 'Anna', role: StaffRole.staff);
    await containerOf(t)
        .read(cardPaymentRepositoryProvider)
        .begin(paymentId: 'p1', cart: cart, staff: anna);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('unclear-card')), findsOneWidget);
    await _back(t);
    expect(find.byKey(const Key('unclear-card')), findsOneWidget);
    expect(find.byKey(const Key('device-test')), findsOneWidget);
  });
}
