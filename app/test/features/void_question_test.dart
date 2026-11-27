// Die Rückfrage vor dem Storno (Schlussprüfung B-I1): sie nennt, was bar
// zurückgeht oder hereinkommt, was jeder Gutschein zurückbekommt, was bei
// SumUp zurückzubuchen ist, und welcher verkaufte Gutschein danach nicht mehr
// gilt. Für jede Form, die 1.11.0 kannte, bleiben die Texte, wie sie waren
// (bons_test.dart, split_payment_test.dart).

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/core/money.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/voucher.dart';
import 'package:kassa/features/login/session.dart';
import 'package:material_ui/material_ui.dart';

import '../support/bons_pump.dart';
import '../support/kassa_pump.dart';
import '../support/sales.dart' show cartCard;

/// Verkauft einen Gutschein über [cents] bar (der nächste Bon).
Future<SoldVoucher> _sellVoucher(WidgetTester t, int cents) async =>
    (await sellCash(
      t,
      cart: const Cart.empty().addVoucherSale(valueCents: cents),
    )).soldVouchers.single;

AppliedVoucher _applied(SoldVoucher v, int balance) =>
    AppliedVoucher(voucherId: v.voucherId, code: v.code, balanceCents: balance);

/// Bons neu öffnen und die Rückfrage zum Bon [number] zeigen.
Future<void> _ask(WidgetTester t, int number) async {
  await t.tap(find.byKey(const Key('tab-Kassa')));
  await t.pump();
  await t.tap(find.byKey(const Key('tab-Bons')));
  await t.pumpAndSettle();
  await openReceipt(t, number);
  await t.tap(find.byKey(const Key('void-receipt')));
  await t.pumpAndSettle();
  expect(find.byKey(const Key('confirm-void')), findsOneWidget);
}

String _text(WidgetTester t, String key) =>
    t.widget<Text>(find.byKey(Key(key))).data!;

String _code(SoldVoucher v) => formatVoucherCode(v.code);

void main() {
  late ProviderContainer c;
  Future<void> pump(WidgetTester t, {Size size = const Size(1280, 800)}) async {
    await pumpBonsWithSales(t, 0, size: size);
    await setSettings(t, (s) => s.copyWith(voucherEnabled: true));
    c = containerOf(t);
  }

  testWidgets('Auszahlung: "Du bekommst 0,75 € bar zurück.", kein "Du gibst"', (
    t,
  ) async {
    await pump(t);
    await c
        .read(receiptRepositoryProvider)
        .finalizePayout(
          saleId: 'auszahlung',
          cart: const Cart.empty().setDepositReturn(
            depositCents: 25,
            quantity: 3,
          ),
          staff: c.read(sessionProvider)!,
        );
    await _ask(t, 1);
    expect(_text(t, 'void-cash-in'), 'Du bekommst 0,75 € bar zurück.');
    expect(find.textContaining('Du gibst'), findsNothing);
    expect(find.textContaining('-0,75'), findsNothing);
    expect(find.byKey(const Key('void-card-hint')), findsNothing);
  });

  testWidgets('nur mit Gutschein bezahlt: kein Bargeld, der Gutschein bekommt '
      'den ganzen Betrag zurück', (t) async {
    await pump(t);
    final v = await _sellVoucher(t, 2500);
    await c
        .read(receiptRepositoryProvider)
        .finalizeVoucherSale(
          saleId: 'nur-gutschein',
          cart: cartCard.applyVoucher(_applied(v, 2500)),
          staff: c.read(sessionProvider)!,
        );
    await _ask(t, 2);
    final total = formatEuro(cartCard.totalCents);
    expect(
      _text(t, 'void-voucher-back-0'),
      'Der Gutschein ${_code(v)} bekommt $total zurück.',
    );
    expect(find.textContaining('bar'), findsNothing);
    expect(find.byKey(const Key('void-card-hint')), findsNothing);
  });

  testWidgets('Gutschein 5,00 und Bar: der Bar-Teil und der Gutschein je '
      'für sich', (t) async {
    await pump(t);
    final v = await _sellVoucher(t, 500);
    final cash = cartCard.totalCents - 500;
    await c
        .read(receiptRepositoryProvider)
        .finalizeCashSale(
          saleId: 'gutschein-und-bar',
          cart: cartCard.applyVoucher(_applied(v, 500)),
          givenCents: cash,
          staff: c.read(sessionProvider)!,
        );
    await _ask(t, 2);
    expect(_text(t, 'void-cash-back'), '${formatEuro(cash)} bar zurückgeben.');
    expect(
      _text(t, 'void-voucher-back-0'),
      'Der Gutschein ${_code(v)} bekommt 5,00 € zurück.',
    );
    expect(find.textContaining('Du gibst'), findsNothing);
    // Die Reihenfolge: zuerst bar, dann der Gutschein.
    expect(
      t.getTopLeft(find.byKey(const Key('void-cash-back'))).dy,
      lessThan(t.getTopLeft(find.byKey(const Key('void-voucher-back-0'))).dy),
    );
    expect(find.byKey(const Key('void-card-hint')), findsNothing);
  });

  testWidgets('Gutschein und Karte ohne Trinkgeld: der Betrag der Karte und '
      'der Gutschein', (t) async {
    await pump(t);
    final v = await _sellVoucher(t, 500);
    final card = cartCard.totalCents - 500;
    await c
        .read(receiptRepositoryProvider)
        .finalizeCardSale(
          saleId: 'gutschein-und-karte',
          cart: cartCard.applyVoucher(_applied(v, 500)),
          staff: c.read(sessionProvider)!,
          provider: 'sumup',
          txCode: 'TX-GK',
        );
    await _ask(t, 2);
    expect(
      _text(t, 'void-voucher-back-0'),
      'Der Gutschein ${_code(v)} bekommt 5,00 € zurück.',
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('void-card-hint')),
        matching: find.text('${formatEuro(card)} bei SumUp zurückbuchen.'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('void-cash-back')), findsNothing);
  });

  testWidgets('Gutschein, Bar und Karte mit Trinkgeld: alle drei Zeilen in '
      'dieser Reihenfolge', (t) async {
    await pump(t);
    final v = await _sellVoucher(t, 500);
    final card = cartCard.totalCents - 500 - 100;
    await c
        .read(receiptRepositoryProvider)
        .finalizeCardSale(
          saleId: 'gutschein-bar-karte',
          cart: cartCard.applyVoucher(_applied(v, 500)),
          staff: c.read(sessionProvider)!,
          provider: 'sumup',
          txCode: 'TX-GBK',
          cashPartCents: 100,
          tipCents: 150,
        );
    await _ask(t, 2);
    expect(_text(t, 'void-cash-back'), '1,00 € bar zurückgeben.');
    expect(
      _text(t, 'void-voucher-back-0'),
      'Der Gutschein ${_code(v)} bekommt 5,00 € zurück.',
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('void-card-hint')),
        matching: find.text(
          '${formatEuro(card + 150)} bei SumUp zurückbuchen, davon 1,50 € '
          'Trinkgeld.',
        ),
      ),
      findsOneWidget,
    );
    double top(String key) => t.getTopLeft(find.byKey(Key(key))).dy;
    expect(top('void-cash-back'), lessThan(top('void-voucher-back-0')));
    expect(top('void-voucher-back-0'), lessThan(top('void-card-hint')));
  });

  testWidgets('ein verkaufter Gutschein: Bargeld zurück, und der Abschnitt '
      'muss zurück', (t) async {
    await pump(t);
    final v = await _sellVoucher(t, 2500);
    await _ask(t, 1);
    expect(find.text('Du gibst 25,00 € bar zurück.'), findsOneWidget);
    expect(
      _text(t, 'void-voucher-sold-0'),
      'Der Gutschein ${_code(v)} gilt danach nicht mehr. Bitte den Abschnitt '
      'zurücknehmen.',
    );
    double top(String key) => t.getTopLeft(find.byKey(Key(key))).dy;
    expect(
      t.getTopLeft(find.text('Du gibst 25,00 € bar zurück.')).dy,
      lessThan(top('void-voucher-sold-0')),
    );
  });

  for (final language in [AppLanguage.ar, AppLanguage.tr]) {
    testWidgets('${language.name}, Textskala 1,3, 1024 x 600: die längste '
        'Rückfrage (Gutschein, Bar, Karte mit Trinkgeld) passt, kein Text '
        'gekürzt, beide Knöpfe ganz zu sehen', (t) async {
      await pumpBonsWithSales(
        t,
        0,
        size: const Size(1024, 600),
        textScale: 1.3,
      );
      await setSettings(
        t,
        (s) => s.copyWith(voucherEnabled: true, language: language),
      );
      c = containerOf(t);
      final v = await _sellVoucher(t, 500);
      await c
          .read(receiptRepositoryProvider)
          .finalizeCardSale(
            saleId: 'gutschein-bar-karte',
            cart: cartCard.applyVoucher(_applied(v, 500)),
            staff: c.read(sessionProvider)!,
            provider: 'sumup',
            txCode: 'TX-GBK',
            cashPartCents: 100,
            tipCents: 150,
          );
      await t.tap(find.byKey(const Key('tab-Kassa')));
      await t.pump();
      await t.tap(find.byKey(const Key('tab-Bons')));
      await t.pumpAndSettle();
      await openReceipt(t, 2);
      // Bekannt und nicht Teil dieser Prüfung: der Kopf des Bons läuft auf
      // Arabisch mit drei Zahlungsarten in der Pille um 0,3 dp über (siehe
      // Bericht der Schlussprüfung). Hier zählt nur die Rückfrage.
      t.takeException();
      await t.tap(find.byKey(const Key('void-receipt')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('confirm-void')), findsOneWidget);
      expect(t.takeException(), isNull);
      final screen = Offset.zero & const Size(1024, 600);
      for (final key in ['confirm-void', 'cancel-void']) {
        final rect = t.getRect(find.byKey(Key(key)));
        expect(screen.contains(rect.topLeft), isTrue, reason: key);
        expect(
          screen.contains(rect.bottomRight - const Offset(1, 1)),
          isTrue,
          reason: key,
        );
      }
      for (final key in [
        'void-cash-back',
        'void-voucher-back-0',
        'void-card-hint',
      ]) {
        final paragraphs = find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byWidgetPredicate((w) => w is RichText),
        );
        final all = [
          ...find.byKey(Key(key)).evaluate(),
          ...paragraphs.evaluate(),
        ];
        for (final e in all) {
          final r = e.renderObject;
          if (r is RenderParagraph) {
            expect(r.didExceedMaxLines, isFalse, reason: key);
          }
        }
        final rect = t.getRect(find.byKey(Key(key)));
        expect(screen.contains(rect.topLeft), isTrue, reason: key);
        expect(rect.bottom, lessThanOrEqualTo(600), reason: key);
      }
    });
  }
}
