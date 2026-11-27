// Abschnitt "Zahlen" der Einstellungen: vier Schalter, alle aus, jede
// Änderung steht sofort in der Datenbank.

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/domain/feature_access.dart';
import 'package:kassa/ui/app_toggle.dart';
import 'package:kassa/ui/segmented.dart';
import 'package:material_ui/material_ui.dart';

import '../support/kassa_pump.dart';
import '../support/settings_pump.dart';

/// Der Schalter in der Zeile mit diesem Schlüssel.
AppToggle switchOf(WidgetTester t, String key) => t.widget<AppToggle>(
  find.descendant(of: find.byKey(Key(key)), matching: find.byType(AppToggle)),
);

/// Das gewählte Segment des Reglers, dessen Segmente `<prefix>-<name>` heißen.
FeatureAccess selectedSegment(WidgetTester t, String prefix) => t
    .widget<Segmented<FeatureAccess>>(
      find.ancestor(
        of: find.byKey(Key('$prefix-${FeatureAccess.off.name}')),
        matching: find.byType(Segmented<FeatureAccess>),
      ),
    )
    .selected;

Future<void> _openPayments(WidgetTester t) async {
  await pumpSettings(t);
  await t.ensureVisible(find.byKey(const Key('payment-card')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Abschnitt "Zahlen": vier Zeilen, alles aus', (t) async {
    await _openPayments(t);
    expect(find.text('Zahlen'), findsOneWidget);
    expect(find.text('Teil bar, Rest Karte'), findsOneWidget);
    expect(find.text('Trinkgeld bei Kartenzahlung'), findsOneWidget);
    expect(find.text('Rabatt'), findsOneWidget);
    expect(find.text('Freier Betrag'), findsOneWidget);
    expect(switchOf(t, 'toggle-split-payment').value, isFalse);
    expect(switchOf(t, 'toggle-card-tip').value, isFalse);
    expect(selectedSegment(t, 'discount-access'), FeatureAccess.off);
    expect(selectedSegment(t, 'open-amount-access'), FeatureAccess.off);
    for (final prefix in ['discount-access', 'open-amount-access']) {
      for (final a in FeatureAccess.values) {
        expect(find.byKey(Key('$prefix-${a.name}')), findsOneWidget);
      }
    }
  });

  testWidgets('jede Änderung steht sofort in der Datenbank', (t) async {
    await _openPayments(t);
    await t.tap(find.byKey(const Key('toggle-card-tip')));
    await t.tap(find.byKey(const Key('discount-access-chefOnly')));
    await t.tap(find.byKey(const Key('open-amount-access-all')));
    await t.pumpAndSettle();
    final s = await settingsOf(t);
    expect(
      (
        s.splitPaymentEnabled,
        s.cardTipEnabled,
        s.discountAccess,
        s.openAmountAccess,
      ),
      (false, true, FeatureAccess.chefOnly, FeatureAccess.all),
    );
    expect(switchOf(t, 'toggle-card-tip').value, isTrue);
    expect(selectedSegment(t, 'discount-access'), FeatureAccess.chefOnly);
    expect(selectedSegment(t, 'open-amount-access'), FeatureAccess.all);

    await t.tap(find.byKey(const Key('toggle-split-payment')));
    await t.tap(find.byKey(const Key('toggle-card-tip')));
    await t.tap(find.byKey(const Key('discount-access-off')));
    await t.pumpAndSettle();
    final back = await settingsOf(t);
    expect(
      (
        back.splitPaymentEnabled,
        back.cardTipEnabled,
        back.discountAccess,
        back.openAmountAccess,
      ),
      (true, false, FeatureAccess.off, FeatureAccess.all),
    );
  });

  testWidgets('der Abschnitt folgt den gespeicherten Einstellungen', (t) async {
    await _openPayments(t);
    await setSettings(
      t,
      (s) => s.copyWith(
        splitPaymentEnabled: true,
        discountAccess: FeatureAccess.all,
        openAmountAccess: FeatureAccess.chefOnly,
      ),
    );
    expect(switchOf(t, 'toggle-split-payment').value, isTrue);
    expect(switchOf(t, 'toggle-card-tip').value, isFalse);
    expect(selectedSegment(t, 'discount-access'), FeatureAccess.all);
    expect(selectedSegment(t, 'open-amount-access'), FeatureAccess.chefOnly);
  });

  testWidgets('auf Arabisch: eigene Texte, kein Überlauf', (t) async {
    await _openPayments(t);
    await setSettings(t, (s) => s.copyWith(language: AppLanguage.ar));
    await t.ensureVisible(find.byKey(const Key('payment-card')));
    await t.pumpAndSettle();
    expect(find.text('الدفع'), findsOneWidget);
    expect(find.text('للمدير فقط'), findsNWidgets(3));
    expect(t.takeException(), isNull);
  });
}
