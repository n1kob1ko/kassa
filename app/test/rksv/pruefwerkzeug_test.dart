// Lauf mit dem Prüfwerkzeug des Finanzministeriums über ein Protokoll der
// Kassa. Läuft nur, wenn KASSA_RKSV_TOOL auf den Ordner des Werkzeugs zeigt
// (tool/rksv/pruefen.sh); auf GitHub ist es nicht da.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/discount.dart';
import 'package:kassa/rksv/core/rksv_code.dart';
import 'package:kassa/rksv/dep_export.dart';

import '../support/demo_fixtures.dart';
import '../support/fake_atrust.dart';
import '../support/fake_signature_unit.dart';
import '../support/pruefwerkzeug.dart';
import '../support/rksv_rig.dart';
import '../support/sales.dart';

Item _item(String id, int priceCents, TaxRate rate, {int deposit = 0}) => Item(
  id: id,
  name: id,
  priceCents: priceCents,
  categoryId: 'snacks',
  taxRate: rate,
  depositCents: deposit,
  position: 0,
);

void main() {
  final tool = pruefwerkzeugDir();

  test(
    'Protokoll der Kassa besteht das Prüfwerkzeug des Finanzministeriums',
    () async {
      final rig = await RksvRig.open();
      addTearDown(rig.close);
      final temp = await Directory.systemTemp.createTemp('kassa-rksv-');
      addTearDown(() => temp.delete(recursive: true));

      // Feste Zeiten in der Vergangenheit: Das Prüfwerkzeug vergleicht jeden
      // Bon mit der echten Uhr, ein Bon nach "jetzt" scheitert immer (R11).
      // Bons vor dem 1.1.2026 liegen vor der Gültigkeit des Test-Zertifikats;
      // das nimmt das Prüfwerkzeug an.
      // Startbeleg am 18.11.2025 13:05:09.
      rig.clock.value = DateTime(2025, 11, 18, 13, 5, 9);
      await rig.service.enableProbe(staff: rig.chef);
      var minute = 0;
      void tick() =>
          rig.clock.value = DateTime(2025, 11, 18, 13, 6 + minute++, 9);

      // Ein Verkauf mit allen fünf Sätzen und Pfand.
      tick();
      await rig.sell(
        'alle-saetze',
        const Cart.empty()
            .add(cola)
            .add(huhnBowl, options: [xxl, nudeln])
            .add(_item('satz-13', 1350, TaxRate.reduced2))
            .add(_item('satz-0', 500, TaxRate.zero))
            .add(_item('satz-19', 1190, TaxRate.special)),
      );
      // Je ein Satz für sich, einer davon mit Karte.
      for (final (id, item) in [
        ('nur-20', cola),
        ('nur-10', teigtaschen),
        ('nur-13', _item('satz-13', 1350, TaxRate.reduced2)),
        ('nur-0', _item('satz-0', 500, TaxRate.zero)),
        ('nur-19', _item('satz-19', 1190, TaxRate.special)),
      ]) {
        tick();
        await rig.sell(id, const Cart.empty().add(item));
      }
      tick();
      await rig.sellCard(
        'karte',
        const Cart.empty().add(teigtaschen).add(cola),
      );
      // 1.234,56 Euro.
      tick();
      await rig.sell(
        'gross',
        const Cart.empty().add(_item('gross', 123456, TaxRate.normal)),
      );
      // Storno.
      tick();
      await rig.receipts.voidReceipt('nur-10', staff: rig.chef);
      // Zwei Bons im Ausfall, dann Sammelbeleg.
      rig.fake.mode = FakeMode.error;
      tick();
      await rig.sell('ausfall-1', const Cart.empty().add(cola));
      tick();
      await rig.sell('ausfall-2', const Cart.empty().add(teigtaschen));
      rig.fake.mode = FakeMode.ok;
      tick();
      expect(await rig.service.retrySignature(staff: rig.chef), isTrue);
      // Monatswechsel.
      rig.clock.value = DateTime(2025, 12, 1, 10);
      await rig.sell('dezember', const Cart.empty().add(cola));
      // Jahreswechsel.
      rig.clock.value = DateTime(2026, 1, 2, 10);
      await rig.sell('jaenner', const Cart.empty().add(teigtaschen));
      // Nullbeleg, Schlussbeleg.
      rig.clock.value = DateTime(2026, 1, 2, 10, 5);
      await rig.service.zeroReceipt(staff: rig.chef);
      rig.clock.value = DateTime(2026, 1, 2, 10, 10);
      await rig.service.disableProbe(staff: rig.chef);

      final kinds = await rig.entryKinds();
      expect(kinds, [
        'start',
        ...List.filled(8, 'sale'),
        'voided',
        'sale',
        'sale',
        'collective',
        'month',
        'sale',
        'year',
        'sale',
        'zero',
        'closing',
      ]);
      await rig.verifyChain(1);
      final entries = await rig.entries(1);
      expect(
        [for (final e in entries) e.damaged].where((d) => d),
        hasLength(2),
      );

      expect(
        await rig.service.exportProtocol(ExportRange.all, now: rig.clock.now()),
        ExportOutcome.saved,
      );
      final dep = File('${temp.path}/dep-export.json')
        ..writeAsStringSync(rig.saver.lastText);
      final crypto = File('${temp.path}/cryptographicMaterialContainer.json')
        ..writeAsStringSync(await cryptographicMaterialContainer(rig, 1));
      final problems = await checkWithPruefwerkzeug(
        tool!,
        dep: dep,
        crypto: crypto,
        entryCount: entries.length,
        workDir: temp,
      );
      expect(problems, isEmpty, reason: problems.join('\n\n'));
    },
    skip: tool == null
        ? 'Prüfwerkzeug nicht da: KASSA_RKSV_TOOL zeigt auf keinen Ordner.'
        : null,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'Kette mit Rabatt, Trinkgeld, gemischter Zahlung, freiem Betrag und '
    'Storno besteht das Prüfwerkzeug des Finanzministeriums',
    () async {
      final rig = await RksvRig.open();
      addTearDown(rig.close);
      final temp = await Directory.systemTemp.createTemp('kassa-rksv-');
      addTearDown(() => temp.delete(recursive: true));

      // Feste Zeiten in der Vergangenheit, wie oben (R11).
      // Startbeleg am 18.11.2025 15:05:09.
      rig.clock.value = DateTime(2025, 11, 18, 15, 5, 9);
      await rig.service.enableProbe(staff: rig.chef);
      var minute = 0;
      void tick() =>
          rig.clock.value = DateTime(2025, 11, 18, 15, 6 + minute++, 9);

      // Rabatt auf der Zeile und auf dem Bon.
      tick();
      final rabatt = const Cart.empty()
          .add(cola)
          .add(huhnBowl, options: [xxl, nudeln]);
      await rig.sell(
        'rabatt',
        rabatt
            .setLineDiscount(
              rabatt.lines[1].lineId,
              const Discount.percent(10, DiscountReason.regular),
            )
            .setReceiptDiscount(
              const Discount.percent(10, DiscountReason.promotion),
            ),
      );
      // Karte mit Trinkgeld.
      tick();
      await rig.sellCard(
        'trinkgeld',
        const Cart.empty().add(teigtaschen).add(cola),
        tipCents: 35,
      );
      // Bar und Karte, mit Trinkgeld und freiem Betrag zu 13 %.
      tick();
      await rig.sellCard(
        'gemischt',
        const Cart.empty()
            .add(teigtaschen)
            .add(cola)
            .addOpenAmount(amountCents: 1250, rate: TaxRate.reduced2),
        cashPartCents: 1000,
        tipCents: 125,
      );
      // Einladung: 100 % Rabatt, Summe 0.
      tick();
      await rig.sell(
        'einladung',
        const Cart.empty()
            .add(teigtaschen)
            .setReceiptDiscount(
              const Discount.percent(100, DiscountReason.invitation),
            ),
      );
      // Storno des gemischten Bons durch den Chef.
      tick();
      await rig.receipts.voidReceipt('gemischt', staff: rig.chef);
      // Nullbeleg, Schlussbeleg.
      tick();
      await rig.service.zeroReceipt(staff: rig.chef);
      tick();
      await rig.service.disableProbe(staff: rig.chef);

      expect(await rig.entryKinds(), [
        'start',
        'sale',
        'sale',
        'sale',
        'sale',
        'voided',
        'zero',
        'closing',
      ]);
      await rig.verifyChain(1);
      final entries = await rig.entries(1);

      expect(
        await rig.service.exportProtocol(ExportRange.all, now: rig.clock.now()),
        ExportOutcome.saved,
      );
      final dep = File('${temp.path}/dep-export.json')
        ..writeAsStringSync(rig.saver.lastText);
      final crypto = File('${temp.path}/cryptographicMaterialContainer.json')
        ..writeAsStringSync(await cryptographicMaterialContainer(rig, 1));
      final problems = await checkWithPruefwerkzeug(
        tool!,
        dep: dep,
        crypto: crypto,
        entryCount: entries.length,
        workDir: temp,
      );
      expect(problems, isEmpty, reason: problems.join('\n\n'));
    },
    skip: tool == null
        ? 'Prüfwerkzeug nicht da: KASSA_RKSV_TOOL zeigt auf keinen Ordner.'
        : null,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'Echte Kette am nachgebauten A-Trust besteht das Prüfwerkzeug des '
    'Finanzministeriums',
    () async {
      final atrust = FakeAtrust();
      final rig = await RksvRig.open(atrust: atrust);
      addTearDown(rig.close);
      final temp = await Directory.systemTemp.createTemp('kassa-rksv-');
      addTearDown(() => temp.delete(recursive: true));

      // Feste Zeiten in der Vergangenheit, wie oben (R11). Das Zertifikat
      // aus "Verbindung prüfen" (liveFacts) gilt von 2020 bis 2030.
      // Startbeleg am 18.11.2026 9:05:09, über prepareSetup und goLive,
      // signiert vom nachgebauten A-Trust.
      rig.clock.value = DateTime(2026, 11, 18, 9, 5, 9);
      final chain = await rig.seedLive();
      expect((await rig.chainRow(chain)).unit, 'atrust');
      var minute = 0;
      void tick() =>
          rig.clock.value = DateTime(2026, 11, 18, 9, 6 + minute++, 9);

      // Verkäufe, einer mit Karte, einer mit allen fünf Sätzen.
      tick();
      await rig.sell(
        'alle-saetze',
        const Cart.empty()
            .add(cola)
            .add(huhnBowl, options: [xxl, nudeln])
            .add(_item('satz-13', 1350, TaxRate.reduced2))
            .add(_item('satz-0', 500, TaxRate.zero))
            .add(_item('satz-19', 1190, TaxRate.special)),
      );
      tick();
      await rig.sell('bar', const Cart.empty().add(teigtaschen));
      tick();
      await rig.sellCard(
        'karte',
        const Cart.empty().add(teigtaschen).add(cola),
      );
      // Storno.
      tick();
      await rig.receipts.voidReceipt('bar', staff: rig.chef);
      // Kein Netz: zwei Bons im Ausfall, dann Sammelbeleg.
      atrust.offline = true;
      tick();
      await rig.sell('ausfall-1', const Cart.empty().add(cola));
      tick();
      await rig.sell('ausfall-2', const Cart.empty().add(teigtaschen));
      atrust.offline = false;
      tick();
      expect(await rig.service.retrySignature(staff: rig.chef), isTrue);
      tick();
      await rig.sell('danach', const Cart.empty().add(cola));
      // Nullbeleg, Schlussbeleg durch die Außerbetriebnahme.
      tick();
      await rig.service.zeroReceipt(staff: rig.chef);
      tick();
      await rig.service.decommission(staff: rig.chef);

      expect(await rig.entryKinds(chain), [
        'start',
        'sale',
        'sale',
        'sale',
        'voided',
        'sale',
        'sale',
        'collective',
        'sale',
        'zero',
        'closing',
      ]);
      await rig.verifyChain(chain);
      final entries = await rig.entries(chain);
      expect(
        [for (final e in entries) e.damaged].where((d) => d),
        hasLength(2),
      );
      // Signiert hat nur A-Trust: ein Zertifikat, das aus der Prüfung.
      expect({for (final e in entries) e.certSerial}, {'2159b9f6'});
      final state = await rig.stateRow();
      expect((state.mode, state.chain), ('off', null));

      expect(
        await rig.service.exportProtocol(ExportRange.all, now: rig.clock.now()),
        ExportOutcome.saved,
      );
      final dep = File('${temp.path}/dep-export.json')
        ..writeAsStringSync(rig.saver.lastText);
      final crypto = File('${temp.path}/cryptographicMaterialContainer.json')
        ..writeAsStringSync(await cryptographicMaterialContainer(rig, chain));
      final problems = await checkWithPruefwerkzeug(
        tool!,
        dep: dep,
        crypto: crypto,
        entryCount: entries.length,
        workDir: temp,
      );
      expect(problems, isEmpty, reason: problems.join('\n\n'));
    },
    skip: tool == null
        ? 'Prüfwerkzeug nicht da: KASSA_RKSV_TOOL zeigt auf keinen Ordner.'
        : null,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'Kette der nachgebauten Signaturkarte besteht das Prüfwerkzeug des '
    'Finanzministeriums',
    () async {
      final rig = await RksvRig.open(card: rigCard());
      addTearDown(rig.close);
      final temp = await Directory.systemTemp.createTemp('kassa-rksv-');
      addTearDown(() => temp.delete(recursive: true));
      final card = rig.cardReader!.card!;

      // Feste Zeiten in der Vergangenheit, wie oben (R11). Das
      // Test-Zertifikat der Karte gilt ab dem 1.1.2026.
      // Startbeleg am 18.11.2026 10:05:09, über prepareSetup mit der Karte,
      // changeCashBoxId und goLiveWithCard, signiert von der Karte über den
      // Halter (CardSigner) und die CardSignatureUnit.
      rig.clock.value = DateTime(2026, 11, 18, 10, 5, 9);
      final chain = await rig.startCardChain();
      expect((await rig.chainRow(chain)).unit, 'card');
      expect(card.signCount, 1);
      var minute = 0;
      void tick() =>
          rig.clock.value = DateTime(2026, 11, 18, 10, 6 + minute++, 9);

      // Verkäufe, einer mit Bankomatkarte, einer mit allen fünf Sätzen.
      tick();
      await rig.sell(
        'alle-saetze',
        const Cart.empty()
            .add(cola)
            .add(huhnBowl, options: [xxl, nudeln])
            .add(_item('satz-13', 1350, TaxRate.reduced2))
            .add(_item('satz-0', 500, TaxRate.zero))
            .add(_item('satz-19', 1190, TaxRate.special)),
      );
      tick();
      await rig.sell('bar', const Cart.empty().add(teigtaschen));
      tick();
      await rig.sellCard(
        'karte',
        const Cart.empty().add(teigtaschen).add(cola),
      );
      // Storno.
      tick();
      await rig.receipts.voidReceipt('bar', staff: rig.chef);
      // Karte gezogen: zwei Bons im Ausfall. Karte wieder gesteckt: der
      // nächste Bon signiert, davor der Sammelbeleg.
      card.removed = true;
      tick();
      final outage1 = await rig.sell('ausfall-1', const Cart.empty().add(cola));
      tick();
      final outage2 = await rig.sell(
        'ausfall-2',
        const Cart.empty().add(teigtaschen),
      );
      expect(
        (await rig.stateRow()).outageReason,
        'Keine Karte im Kartenleser.',
      );
      card.removed = false;
      tick();
      await rig.sell('danach', const Cart.empty().add(cola));
      expect((await rig.stateRow()).outageSince, isNull);
      // Nullbeleg, Schlussbeleg durch die Außerbetriebnahme.
      tick();
      await rig.service.zeroReceipt(staff: rig.chef);
      tick();
      await rig.service.decommission(staff: rig.chef);

      expect(await rig.entryKinds(chain), [
        'start',
        'sale',
        'sale',
        'sale',
        'voided',
        'sale',
        'sale',
        'collective',
        'sale',
        'zero',
        'closing',
      ]);
      await rig.verifyChain(chain);
      final entries = await rig.entries(chain);
      expect(
        [for (final e in entries) e.damaged].where((d) => d),
        hasLength(2),
      );
      // Beschädigt sind genau die zwei Bons, die bei gezogener Karte
      // entstanden: die Einträge 6 und 7, direkt vor dem Sammelbeleg.
      expect(
        [
          for (final e in entries)
            if (e.damaged) (e.position, e.receiptId),
        ],
        [(6, outage1.id), (7, outage2.id)],
      );
      // Signiert hat nur die Karte: jeder Eintrag außer den zwei im Ausfall.
      expect(card.signCount, entries.length - 2);
      expect(
        {for (final e in entries) e.certSerial},
        {rig.cardFacts().serialHex},
      );
      final state = await rig.stateRow();
      expect((state.mode, state.chain), ('off', null));

      expect(
        await rig.service.exportProtocol(ExportRange.all, now: rig.clock.now()),
        ExportOutcome.saved,
      );
      final dep = File('${temp.path}/dep-export.json')
        ..writeAsStringSync(rig.saver.lastText);
      final crypto = File('${temp.path}/cryptographicMaterialContainer.json')
        ..writeAsStringSync(await cryptographicMaterialContainer(rig, chain));
      final problems = await checkWithPruefwerkzeug(
        tool!,
        dep: dep,
        crypto: crypto,
        entryCount: entries.length,
        workDir: temp,
      );
      expect(problems, isEmpty, reason: problems.join('\n\n'));
    },
    skip: tool == null
        ? 'Prüfwerkzeug nicht da: KASSA_RKSV_TOOL zeigt auf keinen Ordner.'
        : null,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'Kette mit Pfand zurück, Auszahlung, Summe 0, Gutschein-Verkauf und '
    'Einlösung besteht das Prüfwerkzeug des Finanzministeriums',
    () async {
      final rig = await RksvRig.open();
      addTearDown(rig.close);
      final temp = await Directory.systemTemp.createTemp('kassa-rksv-');
      addTearDown(() => temp.delete(recursive: true));
      // Ein Artikel nur aus Pfand: Preis 0, Pfand 0,25 € (Becher).
      final pfandArtikel025 = _item(
        'pfandbecher',
        0,
        TaxRate.normal,
        deposit: 25,
      );

      // Feste Zeiten in der Vergangenheit, wie oben (R11). Eine eigene Kette
      // mit eigener Kassen-ID (die Probe zieht sie neu).
      // Startbeleg am 18.11.2025 17:05:09.
      rig.clock.value = DateTime(2025, 11, 18, 17, 5, 9);
      await rig.service.enableProbe(staff: rig.chef);
      var minute = 0;
      void tick() =>
          rig.clock.value = DateTime(2025, 11, 18, 17, 6 + minute++, 9);

      tick();
      await rig.sell(
        'pfand-mit-ware',
        cart.setDepositReturn(depositCents: 25, quantity: 3),
      );
      tick();
      await rig.payout(
        'pfand-auszahlung',
        const Cart.empty().setDepositReturn(depositCents: 25, quantity: 3),
      );
      tick();
      // Summe 0 über "Abschließen": bar, gegeben 0.
      await rig.sell(
        'pfand-null',
        const Cart.empty()
            .add(pfandArtikel025)
            .setDepositReturn(depositCents: 25, quantity: 1),
      );
      tick();
      await rig.sell(
        'gutschein-verkauf',
        cartCard.addVoucherSale(valueCents: 2500),
      );
      final v = (await rig.vouchers.soldOn('gutschein-verkauf')).single;
      tick();
      await rig.sellWithVoucher('gutschein-ganz', cartCard, v);
      tick();
      final rest = (await rig.vouchers.byId(v.id))!;
      await rig.sellCard(
        'gutschein-und-karte',
        cart.applyVoucher(applied(rest)),
        tipCents: 35,
      );
      tick();
      await rig.receipts.voidReceipt('gutschein-und-karte', staff: rig.chef);
      tick();
      await rig.receipts.voidReceipt('pfand-auszahlung', staff: rig.chef);

      expect(await rig.entryKinds(), [
        'start',
        ...List.filled(6, 'sale'),
        'voided',
        'voided',
      ]);
      await rig.verifyChain(1);
      final entries = await rig.entries(1);

      // Summe, Trinkgeld und Zahlungen (Art Betrag/Trinkgeld) der Bons.
      Future<List<Object>> money(String id) async {
        final r = await rig.receipts.byId(id);
        return [
          r.totalCents,
          r.tipCents,
          for (final p in r.payments)
            '${p.kind.name} ${p.amountCents}/${p.tipCents}',
        ];
      }

      expect(await money('pfand-mit-ware'), [1745, 0, 'cash 1745/0']);
      expect(await money('pfand-auszahlung'), [-75, 0, 'cash -75/0']);
      expect(await money('pfand-null'), [0, 0, 'cash 0/0']);
      expect(await money('gutschein-verkauf'), [3465, 0, 'cash 3465/0']);
      expect(await money('gutschein-ganz'), [965, 0, 'voucher 965/0']);
      expect(await money('gutschein-und-karte'), [
        1820,
        35,
        'voucher 1535/0',
        'card 285/35',
      ]);
      expect(v.valueCents, 2500);
      expect(rest.balanceCents, 1535);

      // Beträge je Satz (Normal, Ermäßigt 1, Ermäßigt 2, Null, Besonders).
      Future<List<String>> rates(String receiptId) async =>
          (await rig.codeFieldsOf(receiptId)).sublist(5, 10);
      // Cola 2,90 zu 20 % und 0,25 Pfand im Satz 0, Huhn Bowl 11,90 und
      // Teigtaschen 6,50 zu 10 %. Der Gutschein steht im Satz 0, das
      // Trinkgeld auch.
      expect(await rates('pfand-mit-ware'), [
        '5,80',
        '11,90',
        '0,00',
        '-0,25',
        '0,00',
      ]);
      expect(await rates('pfand-auszahlung'), [
        '0,00',
        '0,00',
        '0,00',
        '-0,75',
        '0,00',
      ]);
      expect(await rates('pfand-null'), [
        '0,00',
        '0,00',
        '0,00',
        '0,00',
        '0,00',
      ]);
      expect(await rates('gutschein-verkauf'), [
        '2,90',
        '6,50',
        '0,00',
        '25,25',
        '0,00',
      ]);
      expect(await rates('gutschein-ganz'), [
        '2,90',
        '6,50',
        '0,00',
        '0,25',
        '0,00',
      ]);
      expect(await rates('gutschein-und-karte'), [
        '5,80',
        '11,90',
        '0,00',
        '0,85',
        '0,00',
      ]);

      // Der Umsatzzähler sinkt mit der Auszahlung um 0,75.
      final chain = await rig.chainRow(1);
      final aesKey = (await rig.secrets.aesKey(1))!;
      Future<int> counterAt(String receiptId) async {
        final f = await rig.codeFieldsOf(receiptId);
        return decryptCounter(
          aesKey: aesKey,
          cashBoxId: chain.cashBoxId,
          receiptId: f[3],
          field: f[10],
        );
      }

      expect(
        await counterAt('pfand-auszahlung'),
        await counterAt('pfand-mit-ware') - 75,
      );

      expect(
        await rig.service.exportProtocol(ExportRange.all, now: rig.clock.now()),
        ExportOutcome.saved,
      );
      final dep = File('${temp.path}/dep-export.json')
        ..writeAsStringSync(rig.saver.lastText);
      final crypto = File('${temp.path}/cryptographicMaterialContainer.json')
        ..writeAsStringSync(await cryptographicMaterialContainer(rig, 1));
      final problems = await checkWithPruefwerkzeug(
        tool!,
        dep: dep,
        crypto: crypto,
        entryCount: entries.length,
        workDir: temp,
      );
      expect(problems, isEmpty, reason: problems.join('\n\n'));
    },
    skip: tool == null
        ? 'Prüfwerkzeug nicht da: KASSA_RKSV_TOOL zeigt auf keinen Ordner.'
        : null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
