import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/rksv/rksv_providers.dart';
import 'package:kassa/ui/pressable.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:material_ui/material_ui.dart';

import '../support/bons_pump.dart' show sellCash;
import '../support/kassa_pump.dart';
import '../support/pump.dart';
import '../support/signature_pump.dart';

Finder _key(String key) => find.byKey(Key(key));

/// Die Kassa mit der Attrappe der Signatur und laufender Probe.
Future<FakeSignatureUnit> _kassaWithProbe(WidgetTester t) async {
  final fake = FakeSignatureUnit();
  await pumpKassa(
    t,
    overrides: [...await memoryOverrides(), ...fakeSignatureOverrides(fake)],
  );
  final c = containerOf(t);
  await c
      .read(rksvServiceProvider)
      .enableProbe(staff: c.read(sessionProvider)!);
  await t.pumpAndSettle();
  return fake;
}

/// Ein Verkauf, bei dem die Signatur einen Fehler meldet: Der Ausfall
/// beginnt (17.11.2026, 11:00).
Future<void> _startOutage(WidgetTester t, FakeSignatureUnit fake) async {
  fake.mode = FakeMode.error;
  await sellCash(t);
  await t.pumpAndSettle();
}

Future<void> _setOutage(WidgetTester t, DateTime? since) async {
  final db = containerOf(t).read(databaseProvider);
  await (db.update(db.rksvStateRows)..where((r) => r.id.equals(1))).write(
    RksvStateRowsCompanion(outageSince: Value(since)),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('ohne Signatur und in der Probe ohne Ausfall: kein Hinweis', (
    t,
  ) async {
    await pumpKassa(
      t,
      overrides: [...await memoryOverrides(), ...signatureOverrides()],
    );
    expect(_key('rksv-outage'), findsNothing);
    await seedProbe(t);
    expect(_key('rksv-outage'), findsNothing);
  });

  testWidgets('Hinweis erscheint über dem Bon und verschwindet, wenn der '
      'Ausfall endet', (t) async {
    await pumpKassa(
      t,
      overrides: [...await memoryOverrides(), ...signatureOverrides()],
    );
    await seedProbe(t, outageSince: DateTime(2026, 11, 17, 10, 5));
    expect(_key('rksv-outage'), findsOneWidget);
    expect(find.text('Signatur ausgefallen seit 10:05'), findsOneWidget);
    expect(find.text('Du kannst normal weiterverkaufen.'), findsOneWidget);
    expect(find.text('Nochmal prüfen'), findsOneWidget);
    // Über dem Kopf des Bons.
    expect(
      t.getBottomLeft(_key('rksv-outage')).dy,
      lessThanOrEqualTo(t.getTopLeft(_key('cart-count')).dy),
    );
    expect(t.getSize(_key('rksv-retry')).height, 56);
    // Bar und Karte bleiben, wie sie sind.
    await tapItem(t, 'cola');
    expect(t.widget<PrimaryButton>(_key('pay-cash')).onPressed, isNotNull);

    await _setOutage(t, null);
    expect(_key('rksv-outage'), findsNothing);
  });

  testWidgets('Ausfall seit einem anderen Tag: mit Datum', (t) async {
    await pumpKassa(
      t,
      overrides: [...await memoryOverrides(), ...signatureOverrides()],
    );
    await seedProbe(t, outageSince: DateTime(2026, 11, 16, 18, 30));
    expect(find.text('Signatur ausgefallen seit 16.11. 18:30'), findsOneWidget);
  });

  testWidgets('Nochmal prüfen, die Signatur geht noch nicht: "Geht noch '
      'nicht." im Hinweis, kein Dialog', (t) async {
    final fake = await _kassaWithProbe(t);
    await _startOutage(t, fake);
    expect(find.text('Signatur ausgefallen seit 11:00'), findsOneWidget);

    final before = fake.signCalls;
    await t.tap(_key('rksv-retry'));
    await t.pumpAndSettle();
    expect(fake.signCalls - before, 1);
    expect(
      find.descendant(
        of: _key('rksv-outage'),
        matching: find.text('Geht noch nicht.'),
      ),
      findsOneWidget,
    );
    expect(find.byType(Dialog), findsNothing);
    expect(_key('rksv-outage'), findsOneWidget);
    expect(
      (await containerOf(t).read(rksvRepositoryProvider).current()).outage,
      isTrue,
    );
  });

  testWidgets('Nochmal prüfen, die Signatur geht wieder: "Die Signatur geht '
      'wieder.", dann verschwindet der Hinweis', (t) async {
    final fake = await _kassaWithProbe(t);
    await _startOutage(t, fake);
    fake.mode = FakeMode.ok;

    await t.tap(_key('rksv-retry'));
    await t.pump();
    await t.pump();
    expect(find.text('Die Signatur geht wieder.'), findsOneWidget);
    expect(find.text('Nochmal prüfen'), findsNothing);
    expect(
      (await containerOf(t).read(rksvRepositoryProvider).current()).outage,
      isFalse,
    );
    final kinds = await containerOf(t)
        .read(databaseProvider)
        .customSelect('SELECT kind FROM receipts ORDER BY number')
        .map((r) => r.read<String>('kind'))
        .get();
    expect(kinds, ['start', 'sale', 'collective']);

    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();
    expect(_key('rksv-outage'), findsNothing);
  });

  testWidgets('während der Prüfung ist die Taste gesperrt; ein doppelter '
      'Tipp prüft einmal', (t) async {
    final fake = await _kassaWithProbe(t);
    await _startOutage(t, fake);
    fake.mode = FakeMode.silent;
    final before = fake.signCalls;

    await t.tap(_key('rksv-retry'));
    await t.tap(_key('rksv-retry'), warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 100));
    expect(t.widget<Pressable>(_key('rksv-retry')).onTap, isNull);
    await t.tap(_key('rksv-retry'), warnIfMissed: false);

    // Höchstens 1 Sekunde im Ausfall.
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(fake.signCalls - before, 1);
    expect(find.text('Geht noch nicht.'), findsOneWidget);
    expect(t.widget<Pressable>(_key('rksv-retry')).onTap, isNotNull);
    fake.release();
  });
}
