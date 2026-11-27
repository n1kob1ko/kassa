// Die Kassa in den anderen Sprachen: Tasten, Bon und ein ganzer Barverkauf.

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/feature_access.dart';
import 'package:kassa/features/kassa/cart_controller.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/l10n/generated/l10n.dart';
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../support/kassa_pump.dart';
import '../support/pump.dart';
import '../support/signature_pump.dart';

/// Stellt die Sprache der laufenden Kassa um, wie die Einstellungen es tun.
Future<void> _setLanguage(WidgetTester t, AppLanguage language) async {
  final repo = containerOf(t).read(settingsRepositoryProvider);
  await repo.save((await repo.current()).copyWith(language: language));
  await t.pumpAndSettle();
}

Finder _inKey(String key, String text) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

void main() {
  const expected = {
    AppLanguage.en: (cash: 'Cash', receipt: 'Receipt'),
    AppLanguage.zh: (cash: '现金', receipt: '小票'),
    AppLanguage.tr: (cash: 'Nakit', receipt: 'Fiş'),
    AppLanguage.ar: (cash: 'نقدًا', receipt: 'الفاتورة'),
  };

  for (final MapEntry(key: language, value: texts) in expected.entries) {
    testWidgets('${language.name}: Bar-Taste und Titel des Bons übersetzt', (
      t,
    ) async {
      await pumpKassaWith(t, ['cola']);
      await _setLanguage(t, language);
      expect(_inKey('pay-cash', texts.cash), findsOneWidget);
      expect(find.text(texts.receipt), findsOneWidget);
      expect(_inKey('pay-cash', 'Bar'), findsNothing);
      expect(find.text('Bon'), findsNothing);
      expect(find.text('Bon leeren'), findsNothing);
    });
  }

  const discountAndOpen = {
    AppLanguage.en: (discount: 'Discount', open: 'Open amount'),
    AppLanguage.zh: (discount: '折扣', open: '自定义金额'),
    AppLanguage.tr: (discount: 'İndirim', open: 'Serbest tutar'),
    AppLanguage.ar: (discount: 'خصم', open: 'مبلغ حر'),
  };

  testWidgets('en, zh, tr, ar: die Tasten "Rabatt" und "Freier Betrag" stehen '
      'in der Bediensprache', (t) async {
    for (final MapEntry(key: language, value: texts)
        in discountAndOpen.entries) {
      await pumpKassaWith(t, ['cola']);
      await setSettings(
        t,
        (s) => s.copyWith(
          language: language,
          discountAccess: FeatureAccess.all,
          openAmountAccess: FeatureAccess.all,
        ),
      );
      // Mit einem und mit zwei Artikeln: die Taste, der Titel und die Zahl
      // der Artikel daneben sind ganz zu lesen, ohne Auslassungspunkte.
      for (final count in [1, 2]) {
        if (count == 2) {
          await tapItem(t, 'teigtaschen');
          await t.pumpAndSettle();
        }
        final at = '${language.name}, $count';
        for (final (key, text) in [
          ('discount-button', texts.discount),
          ('open-amount-button', texts.open),
        ]) {
          final label = _inKey(key, text);
          expect(label, findsOneWidget, reason: '$at $key');
          final box = t.renderObject<RenderParagraph>(
            find.descendant(of: label, matching: find.byType(RichText)),
          );
          expect(box.didExceedMaxLines, isFalse, reason: '$at $key');
        }
        final countBox = t.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byKey(const Key('cart-count')),
            matching: find.byType(RichText),
            matchRoot: true,
          ),
        );
        expect(countBox.didExceedMaxLines, isFalse, reason: '$at cart-count');
      }
      expect(_inKey('discount-button', 'Rabatt'), findsNothing);
      expect(_inKey('open-amount-button', 'Freier Betrag'), findsNothing);
    }
  });

  testWidgets('tr: Barzahlung bis "Verkauf fertig"', (t) async {
    await pumpKassaWith(t, ['cola', 'teigtaschen']);
    await _setLanguage(t, AppLanguage.tr);
    await t.tap(find.byKey(const Key('pay-cash')));
    await t.pumpAndSettle();
    expect(find.text('Nakit ödeme'), findsOneWidget);
    expect(find.text('Ödenecek'), findsOneWidget);
    expect(find.text('Tam'), findsOneWidget);
    expect(find.text('Bar bezahlen'), findsNothing);

    await t.tap(find.byKey(const Key('finish-sale')));
    await t.pumpAndSettle();
    expect(find.text('Ödendi'), findsOneWidget);
    expect(find.textContaining('Fiş No. '), findsOneWidget);
    expect(find.text('Tam ödendi'), findsOneWidget);
    expect(_inKey('next-customer', 'Sonraki müşteri'), findsOneWidget);
    expect(find.text('Bezahlt'), findsNothing);

    await t.tap(find.byKey(const Key('next-customer')));
    await t.pumpAndSettle();
    expect(_inKey('pay-cash', 'Nakit'), findsOneWidget);
    expect(find.text('Henüz ürün yok'), findsOneWidget);
  });

  testWidgets('Ausfall der Signatur auf Englisch: Überschrift und Tasten '
      'übersetzt, der Grund bleibt wörtlich, darunter der feste Satz', (
    t,
  ) async {
    await pumpKassa(
      t,
      overrides: [...await memoryOverrides(), ...signatureOverrides()],
    );
    await seedProbe(t, outageSince: DateTime(2026, 11, 17, 10, 5));
    await _setLanguage(t, AppLanguage.en);
    final en = lookupL10n(const Locale('en'));
    expect(find.text('Signature down since 10:05'), findsOneWidget);
    expect(find.byKey(const Key('rksv-outage-reason')), findsOneWidget);
    expect(find.text('Die Signatur hat nicht geantwortet.'), findsOneWidget);
    expect(find.text(en.outageKeepsWorking), findsOneWidget);
    expect(find.text(en.outageRetry), findsOneWidget);
    expect(find.text('Du kannst normal weiterverkaufen.'), findsNothing);
  });

  test('jede Sprache hat jeden Text der Kassa, keiner ist leer', () {
    for (final code in ['de', 'en', 'zh', 'tr', 'ar']) {
      final l = lookupL10n(Locale(code));
      for (final text in [
        l.kassaCash,
        l.kassaCard,
        l.kassaReceipt,
        l.kassaItemCount(0),
        l.kassaItemCount(1),
        l.kassaItemCount(2),
        l.kassaItemCount(5),
        l.kassaItemCount(11),
        l.kassaItemCount(100),
        l.unclearMore(3),
        l.outageKeepsWorking,
        l.printPaperOut,
      ]) {
        expect(text.trim(), isNotEmpty, reason: code);
        expect(text, isNot(contains('{')), reason: code);
      }
    }
    // Arabisch zählt nach seinen eigenen Formen, mit den Ziffern 0 bis 9.
    final ar = lookupL10n(const Locale('ar'));
    expect(ar.kassaItemCount(3), '3 أصناف');
    expect(ar.kassaItemCount(11), '11 صنفًا');
    expect(ar.kassaItemCount(100), '100 صنف');
    expect(lookupL10n(const Locale('de')).kassaItemCount(1), '1 Artikel');
  });

  const depositReturn = {
    AppLanguage.en: (more: 'More', back: 'Deposit return', out: 'Pay out cash'),
    AppLanguage.zh: (more: '更多', back: '退押金', out: '现金退付'),
    AppLanguage.tr: (
      more: 'Daha fazla',
      back: 'Depozito iadesi',
      out: 'Nakit öde',
    ),
    AppLanguage.ar: (more: 'المزيد', back: 'إرجاع الرهن', out: 'صرف نقدًا'),
  };

  testWidgets('en, zh, tr, ar: "Mehr", "Pfand zurück" und "Bar auszahlen" '
      'stehen in der Bediensprache', (t) async {
    for (final MapEntry(key: language, value: texts) in depositReturn.entries) {
      await pumpKassa(t);
      await setSettings(
        t,
        (s) => s.copyWith(
          language: language,
          openAmountAccess: FeatureAccess.all,
          depositReturnAccess: FeatureAccess.all,
        ),
      );
      expect(_inKey('more-button', texts.more), findsOneWidget);
      await t.tap(find.byKey(const Key('more-button')));
      await t.pumpAndSettle();
      expect(_inKey('more-deposit-return', texts.back), findsOneWidget);
      await t.tap(find.byKey(const Key('more-deposit-return')));
      await t.pumpAndSettle();
      expect(find.text(texts.back), findsWidgets);
      await t.tap(find.byKey(const Key('deposit-return-plus-25')));
      await t.pump();
      await t.tap(find.byKey(const Key('deposit-return-add')));
      await t.pumpAndSettle();
      final payOut = find.descendant(
        of: find.byKey(const Key('pay-out')),
        matching: find.textContaining(texts.out),
      );
      expect(payOut, findsOneWidget, reason: language.name);
      expect(
        find.descendant(
          of: find.byKey(const Key('pay-out')),
          matching: find.textContaining('Bar auszahlen'),
        ),
        findsNothing,
      );
      expect(_inKey('more-button', 'Mehr'), findsNothing);
    }
  });

  const voucher = {
    AppLanguage.en: (
      head: 'Voucher',
      sell: 'Sell',
      check: 'Check',
      add: 'Add to receipt',
      print: 'Print voucher',
    ),
    AppLanguage.zh: (
      head: '礼券',
      sell: '出售',
      check: '查询',
      add: '加入小票',
      print: '打印礼券',
    ),
    AppLanguage.tr: (
      head: 'Hediye çeki',
      sell: 'Sat',
      check: 'Kontrol et',
      add: 'Fişe ekle',
      print: 'Hediye çekini yazdır',
    ),
    AppLanguage.ar: (
      head: 'قسيمة',
      sell: 'بيع',
      check: 'تحقّق',
      add: 'أضف إلى الفاتورة',
      print: 'اطبع القسيمة',
    ),
  };

  testWidgets('en, zh, tr, ar: "Gutschein", seine Reiter, "Auf den Bon" und '
      '"Gutschein drucken" stehen in der Bediensprache', (t) async {
    for (final MapEntry(key: language, value: texts) in voucher.entries) {
      await pumpKassa(t);
      await setSettings(
        t,
        (s) => s.copyWith(
          language: language,
          voucherEnabled: true,
          printerKind: PrinterKind.network,
          printerAddress: '192.168.0.50',
        ),
      );
      expect(_inKey('voucher-button', texts.head), findsOneWidget);
      await t.tap(find.byKey(const Key('voucher-button')));
      await t.pumpAndSettle();
      expect(_inKey('voucher-tab-sell', texts.sell), findsOneWidget);
      expect(_inKey('voucher-tab-check', texts.check), findsOneWidget);
      expect(_inKey('voucher-add', texts.add), findsOneWidget);
      await t.tap(find.byKey(const Key('voucher-preset-1000')));
      await t.pump();
      await t.tap(find.byKey(const Key('voucher-add')));
      await t.pumpAndSettle();
      // Die Zeile heißt am Bildschirm in der Bediensprache.
      expect(find.text(texts.head), findsWidgets);
      expect(find.text('Gutschein'), findsNothing);
      await t.tap(find.byKey(const Key('pay-cash')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('finish-sale')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('finish-sale')));
      await t.pumpAndSettle();
      expect(
        _inKey('sold-voucher-print-0', texts.print),
        findsOneWidget,
        reason: language.name,
      );
      expect(_inKey('sold-voucher-print-0', 'Gutschein drucken'), findsNothing);
    }
  });

  const redeem = {
    AppLanguage.en: (
      pay: 'Voucher',
      title: 'Redeem voucher',
      due: 'Still to pay',
      finish: 'Finish with voucher',
    ),
    AppLanguage.zh: (
      pay: '礼券',
      title: '使用礼券',
      due: '还需支付',
      finish: '用礼券结账',
    ),
    AppLanguage.tr: (
      pay: 'Hediye çeki',
      title: 'Hediye çeki kullan',
      due: 'Kalan ödeme',
      finish: 'Hediye çekiyle tamamla',
    ),
    AppLanguage.ar: (
      pay: 'قسيمة',
      title: 'استخدام قسيمة',
      due: 'المتبقي للدفع',
      finish: 'إتمام بالقسيمة',
    ),
  };

  testWidgets('en, zh, tr, ar: "Gutschein" über Bar und Karte, "Gutschein '
      'einlösen", "Noch zu zahlen" und "Mit Gutschein abschließen" stehen in '
      'der Bediensprache', (t) async {
    for (final MapEntry(key: language, value: texts) in redeem.entries) {
      await pumpKassa(t);
      await setSettings(
        t,
        (s) => s.copyWith(language: language, voucherEnabled: true),
      );
      final container = containerOf(t);
      final sold = await container
          .read(receiptRepositoryProvider)
          .finalizeCashSale(
            saleId: 'g-${language.name}',
            cart: const Cart.empty().addVoucherSale(valueCents: 200),
            givenCents: 200,
            staff: container.read(sessionProvider)!,
          );
      final code = sold.soldVouchers.single.code;
      await tapItem(t, 'cola');
      await t.pumpAndSettle();
      expect(_inKey('pay-voucher', texts.pay), findsOneWidget);
      await t.tap(find.byKey(const Key('pay-voucher')));
      await t.pumpAndSettle();
      expect(find.text(texts.title), findsOneWidget, reason: language.name);
      expect(find.text('Gutschein einlösen'), findsNothing);
      for (final d in code.split('')) {
        await t.ensureVisible(find.byKey(Key('key-$d')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(Key('key-$d')));
        await t.pump();
      }
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('voucher-redeem-go')));
      await t.pumpAndSettle();
      expect(_inKey('due-row', texts.due), findsOneWidget);
      expect(_inKey('due-row', 'Noch zu zahlen'), findsNothing);
      // Ein neuer Bon, den ein gewählter Gutschein ganz deckt.
      container.read(cartProvider.notifier).clear();
      await t.pumpAndSettle();
      await tapItem(t, 'cola');
      await t.pumpAndSettle();
      final full = await container
          .read(receiptRepositoryProvider)
          .finalizeCashSale(
            saleId: 'g2-${language.name}',
            cart: const Cart.empty().addVoucherSale(valueCents: 1000),
            givenCents: 1000,
            staff: container.read(sessionProvider)!,
          );
      final v = full.soldVouchers.single;
      container
          .read(cartProvider.notifier)
          .applyVoucher(
            AppliedVoucher(
              voucherId: v.voucherId,
              code: v.code,
              balanceCents: 1000,
            ),
          );
      await t.pumpAndSettle();
      expect(_inKey('finish-voucher', texts.finish), findsOneWidget);
      expect(_inKey('finish-voucher', 'Mit Gutschein abschließen'), findsNothing);
    }
  });
}

