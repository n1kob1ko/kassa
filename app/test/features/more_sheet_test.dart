// Der Kopf der Bon-Spalte mit bis zu drei Funktionen: Darf die angemeldete
// Person genau eine, steht deren Taste dort; zwei oder drei: eine Taste
// "Mehr", die ein Blatt mit einer großen Taste je Funktion öffnet.

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/feature_access.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/features/kassa/more_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../support/demo_fixtures.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';

const _anna = Staff(id: 'a', name: 'Anna', role: StaffRole.staff);
const _chef = Staff(id: 'c', name: 'Chef', role: StaffRole.chef);

/// Die Beispiel-Karte ohne Pfand.
final _noDeposit = Catalog(
  business: catalog.business,
  categories: catalog.categories,
  items: [
    for (final i in catalog.items)
      if (i.depositCents == 0) i,
  ],
  templates: catalog.templates,
);

Future<void> _tap(WidgetTester t, String key) async {
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

void main() {
  test('headActions: eine Funktion → ihre Taste; zwei → Mehr; Pfand zurück '
      'nur mit Pfand in der Karte und nur für erlaubte Personen', () {
    List<HeadAction> of(
      RegisterSettings s, {
      Staff staff = _anna,
      Catalog? menu,
    }) => headActions(settings: s, staff: staff, catalog: menu ?? catalog);

    const off = RegisterSettings();
    expect(of(off), isEmpty);
    expect(of(off, staff: _chef), isEmpty);

    const open = RegisterSettings(openAmountAccess: FeatureAccess.all);
    expect(of(open), [HeadAction.openAmount]);

    const deposit = RegisterSettings(depositReturnAccess: FeatureAccess.all);
    expect(of(deposit), [HeadAction.depositReturn]);
    // Ohne Pfand in der Karte gibt es nichts zurückzugeben.
    expect(of(deposit, menu: _noDeposit), isEmpty);

    const both = RegisterSettings(
      openAmountAccess: FeatureAccess.all,
      depositReturnAccess: FeatureAccess.all,
    );
    expect(of(both), [HeadAction.openAmount, HeadAction.depositReturn]);
    expect(of(both, menu: _noDeposit), [HeadAction.openAmount]);

    // "Nur Chef" wirkt wie in 1a: für Anna fehlt die Funktion.
    const chefOnly = RegisterSettings(
      openAmountAccess: FeatureAccess.all,
      depositReturnAccess: FeatureAccess.chefOnly,
    );
    expect(of(chefOnly), [HeadAction.openAmount]);
    expect(of(chefOnly, staff: _chef), [
      HeadAction.openAmount,
      HeadAction.depositReturn,
    ]);
    const openChefOnly = RegisterSettings(
      openAmountAccess: FeatureAccess.chefOnly,
    );
    expect(of(openChefOnly), isEmpty);
    expect(of(openChefOnly, staff: _chef), [HeadAction.openAmount]);
  });

  test('headActions liefert den Gutschein in dieser Version noch nie, auch '
      'wenn der Schalter an ist', () {
    expect(voucherHeadActionReady, isFalse);
    const all = RegisterSettings(
      openAmountAccess: FeatureAccess.all,
      depositReturnAccess: FeatureAccess.all,
      voucherEnabled: true,
    );
    for (final staff in [_anna, _chef]) {
      expect(headActions(settings: all, staff: staff, catalog: catalog), [
        HeadAction.openAmount,
        HeadAction.depositReturn,
      ]);
    }
    expect(
      headActions(
        settings: const RegisterSettings(voucherEnabled: true),
        staff: _chef,
        catalog: catalog,
      ),
      isEmpty,
    );
  });

  testWidgets('nur freier Betrag an: der Kopf ist wie in 1.11.0 '
      '(open-amount-button, kein more-button)', (t) async {
    await pumpKassa(t);
    await setSettings(
      t,
      (s) => s.copyWith(openAmountAccess: FeatureAccess.all),
    );
    expect(find.byKey(const Key('open-amount-button')), findsOneWidget);
    expect(find.byKey(const Key('more-button')), findsNothing);
    expect(find.byKey(const Key('deposit-return-button')), findsNothing);
    expect(find.byKey(const Key('voucher-button')), findsNothing);
    await _tap(t, 'open-amount-button');
    expect(find.byKey(const Key('open-amount-sheet')), findsOneWidget);
  });

  testWidgets('nur Pfand zurück an: seine Taste steht allein im Kopf', (
    t,
  ) async {
    await pumpKassa(t);
    await setSettings(
      t,
      (s) => s.copyWith(depositReturnAccess: FeatureAccess.all),
    );
    expect(find.byKey(const Key('deposit-return-button')), findsOneWidget);
    expect(find.byKey(const Key('more-button')), findsNothing);
    expect(find.byKey(const Key('open-amount-button')), findsNothing);
    await _tap(t, 'deposit-return-button');
    expect(find.byKey(const Key('deposit-return-sheet')), findsOneWidget);
  });

  testWidgets('freier Betrag und Pfand zurück an: Mehr öffnet das Blatt, ein '
      'Tipp auf Pfand zurück öffnet dessen Blatt', (t) async {
    await pumpKassa(t);
    await setSettings(
      t,
      (s) => s.copyWith(
        openAmountAccess: FeatureAccess.all,
        depositReturnAccess: FeatureAccess.all,
        voucherEnabled: true,
      ),
    );
    expect(find.byKey(const Key('more-button')), findsOneWidget);
    expect(find.byKey(const Key('open-amount-button')), findsNothing);
    expect(find.byKey(const Key('deposit-return-button')), findsNothing);
    expect(textOf(t, const Key('more-button')), 'Mehr');

    await _tap(t, 'more-button');
    expect(find.byKey(const Key('more-sheet')), findsOneWidget);
    expect(find.byKey(const Key('more-open-amount')), findsOneWidget);
    expect(find.byKey(const Key('more-deposit-return')), findsOneWidget);
    // Der Gutschein kommt erst mit seinem Blatt.
    expect(find.byKey(const Key('more-voucher')), findsNothing);
    for (final key in ['more-open-amount', 'more-deposit-return']) {
      final size = t.getSize(find.byKey(Key(key)));
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
    }

    // Zurück: wieder der Bon.
    await _tap(t, 'more-back');
    expect(find.byKey(const Key('more-sheet')), findsNothing);
    expect(find.byKey(const Key('more-button')), findsOneWidget);

    await _tap(t, 'more-button');
    await _tap(t, 'more-deposit-return');
    expect(find.byKey(const Key('more-sheet')), findsNothing);
    expect(find.byKey(const Key('deposit-return-sheet')), findsOneWidget);
    await _tap(t, 'deposit-return-back');
    expect(find.byKey(const Key('deposit-return-sheet')), findsNothing);

    await _tap(t, 'more-button');
    await _tap(t, 'more-open-amount');
    expect(find.byKey(const Key('open-amount-sheet')), findsOneWidget);
  });

  testWidgets('Pfand zurück "Nur Chef": Anna sieht keine Taste, der Chef '
      'schon', (t) async {
    await pumpKassa(t);
    await setSettings(
      t,
      (s) => s.copyWith(depositReturnAccess: FeatureAccess.chefOnly),
    );
    expect(find.byKey(const Key('deposit-return-button')), findsNothing);
    expect(find.byKey(const Key('more-button')), findsNothing);

    await pumpKassa(t, sameDatabase: true, pin: '4711');
    expect(find.byKey(const Key('deposit-return-button')), findsOneWidget);
    expect(find.byKey(const Key('more-button')), findsNothing);

    // Mit freiem Betrag für alle: Anna sieht nur den freien Betrag, der Chef
    // "Mehr".
    await setSettings(
      t,
      (s) => s.copyWith(openAmountAccess: FeatureAccess.all),
    );
    expect(find.byKey(const Key('more-button')), findsOneWidget);
    await pumpKassa(t, sameDatabase: true);
    expect(find.byKey(const Key('open-amount-button')), findsOneWidget);
    expect(find.byKey(const Key('more-button')), findsNothing);
    expect(find.byKey(const Key('deposit-return-button')), findsNothing);
  });

  testWidgets('wird Pfand zurück ausgeschaltet, während "Mehr" offen ist, '
      'steht wieder der Bon da', (t) async {
    await pumpKassa(t);
    await setSettings(
      t,
      (s) => s.copyWith(
        openAmountAccess: FeatureAccess.all,
        depositReturnAccess: FeatureAccess.all,
      ),
    );
    await _tap(t, 'more-button');
    expect(find.byKey(const Key('more-sheet')), findsOneWidget);
    await setSettings(
      t,
      (s) => s.copyWith(depositReturnAccess: FeatureAccess.off),
    );
    expect(find.byKey(const Key('more-sheet')), findsNothing);
    expect(find.byKey(const Key('open-amount-button')), findsOneWidget);
  });
}
