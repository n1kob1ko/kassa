import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:kassa/core/app_language.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/day_repository.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/domain/feature_access.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/staff.dart';

import 'generated_migrations/schema.dart';
import 'migration_test.dart' show copyFixture, count;

/// Version 8 (Stufe 1a: gemischt zahlen, Trinkgeld, Rabatt, freier Betrag)
/// nach Version 7 (1.10.0). Die Datei `kassa_v7.sqlite` entsteht mit
/// `tool/make_kassa_v7_fixture.dart` aus dem Abzug von Version 7.
void main() {
  Future<int> userVersion(KassaDatabase db) async =>
      (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
        'user_version',
      );

  Future<List<String>> triggerNames(KassaDatabase db) async => [
    for (final r
        in await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'trigger' "
              'ORDER BY name',
            )
            .get())
      r.read<String>('name'),
  ];

  for (final from in [1, 3, 6, 7]) {
    test('Schema: Version $from wird zu Version 8', () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final db = KassaDatabase(await verifier.startAt(from));
      await verifier.migrateAndValidate(db, 8);
      await db.close();
    });
  }

  test(
    'Update von 1.10.0: Zahlungen bekommen Stelle 0, alles andere bleibt',
    () async {
      final file = await copyFixture('kassa_v7.sqlite');
      // Zählung und Zahlungen vor dem Update, an der Datei selbst.
      final raw = sqlite.sqlite3.open(file.path);
      expect(raw.select('PRAGMA user_version').single.values.single, 7);
      int rawCount(String table) =>
          raw.select('SELECT COUNT(*) c FROM $table').single['c'] as int;
      final before = {
        for (final t in const [
          'receipts',
          'receipt_lines',
          'receipt_line_options',
          'payments',
          'pending_card_payments',
          'business_days',
          'cash_movements',
          'outbox',
          'items',
          'categories',
        ])
          t: rawCount(t),
      };
      final triggersBefore = [
        for (final r in raw.select(
          "SELECT name FROM sqlite_master WHERE type = 'trigger' "
          'ORDER BY name',
        ))
          r['name'] as String,
      ];
      final paymentsBefore = [
        for (final r in raw.select(
          'SELECT receipt_id, kind, amount_cents, given_cents, change_cents, '
          'provider_tx_code FROM payments ORDER BY receipt_id',
        ))
          (
            r['receipt_id'] as String,
            r['kind'] as String,
            r['amount_cents'] as int,
            r['given_cents'] as int,
            r['change_cents'] as int,
            r['provider_tx_code'] as String?,
          ),
      ];
      raw.close();
      expect(before['receipts'], 6);
      expect(before['outbox'], greaterThan(0));
      expect(before['pending_card_payments'], 1);
      expect(paymentsBefore.where((p) => p.$2 == 'card'), hasLength(1));
      expect(triggersBefore, isNotEmpty);

      final db = KassaDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(await userVersion(db), 9);

      final payments =
          await (db.select(db.paymentRows)..orderBy([
                (t) => OrderingTerm(expression: t.receiptId),
                (t) => OrderingTerm(expression: t.position),
              ]))
              .get();
      expect(payments.length, before['payments']);
      expect(
        payments.every(
          (p) =>
              p.position == 0 &&
              p.tipCents == 0 &&
              p.tipStaffId == null &&
              p.tipStaffName == null,
        ),
        isTrue,
      );
      expect([
        for (final p in payments)
          (
            p.receiptId,
            p.kind,
            p.amountCents,
            p.givenCents,
            p.changeCents,
            p.providerTxCode,
          ),
      ], paymentsBefore);
      final pk = await db
          .customSelect(
            "SELECT name FROM pragma_table_info('payments') WHERE pk > 0 "
            'ORDER BY pk',
          )
          .get();
      expect(
        [for (final r in pk) r.read<String>('name')],
        ['receipt_id', 'position'],
      );

      final receipts = await db.select(db.receiptRows).get();
      expect(
        receipts.every(
          (r) =>
              r.tipCents == 0 &&
              r.discountCents == 0 &&
              r.discountPercent == null &&
              r.discountAmountCents == 0 &&
              r.discountReason == null,
        ),
        isTrue,
      );
      final lines = await db.select(db.receiptLineRows).get();
      expect(
        lines.every(
          (l) =>
              l.discountCents == 0 &&
              l.ownDiscountPercent == null &&
              l.ownDiscountCents == 0 &&
              l.ownDiscountReason == null,
        ),
        isTrue,
      );

      // Bons, Liste ("noch zu senden") und Trigger sind unverändert.
      for (final MapEntry(:key, :value) in before.entries) {
        expect(await count(db, key), value, reason: key);
      }
      expect(
        await triggerNames(db),
        [
          ...triggersBefore,
          'receipt_deliveries_no_delete',
          'receipt_deliveries_no_update',
          'receipt_recipients_no_delete',
          'receipt_recipients_no_update',
          'voucher_movements_no_delete',
          'voucher_movements_no_update',
          'vouchers_no_delete',
          'vouchers_no_update_code_value',
        ]..sort(),
      );
      await expectLater(
        db.customStatement('UPDATE payments SET amount_cents = 1'),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        db.customStatement('DELETE FROM payments'),
        throwsA(isA<SqliteException>()),
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );

  test('Update von 1.10.0: der Abgleich-Stand bleibt', () async {
    final db = KassaDatabase(
      NativeDatabase(await copyFixture('kassa_v7.sqlite')),
    );
    addTearDown(db.close);
    final sync = await db.select(db.syncStateRows).getSingle();
    expect((sync.pullCursor, sync.initialPullDone), (40, true));
  });

  test('Update von 1.10.0: alle vier Schalter sind aus, alte Einstellungen bleiben', () async {
    final db = KassaDatabase(
      NativeDatabase(await copyFixture('kassa_v7.sqlite')),
    );
    addTearDown(db.close);
    final s = await SettingsRepository(db).current();
    expect(
      (
        s.splitPaymentEnabled,
        s.cardTipEnabled,
        s.discountAccess,
        s.openAmountAccess,
      ),
      (false, false, FeatureAccess.off, FeatureAccess.off),
    );
    expect(
      (s.language, s.kitchenMode, s.voidRequiresChef, s.printerColumns),
      (AppLanguage.tr, KitchenMode.receiptPrinter, true, 42),
    );
  });

  test(
    'Update von 1.10.0: offene Kartenzahlung und Entwurf bleiben lesbar',
    () async {
      final file = await copyFixture('kassa_v7.sqlite');
      final raw = sqlite.sqlite3.open(file.path);
      final pendingAmountBefore =
          raw
                  .select('SELECT amount_cents FROM pending_card_payments')
                  .single['amount_cents']
              as int;
      final draftBefore =
          raw
                  .select('SELECT receipt_draft FROM settings')
                  .single['receipt_draft']
              as String?;
      raw.close();
      expect(draftBefore, isNotNull);

      final db = KassaDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final p = (await db.select(db.pendingCardPaymentRows).get()).single;
      expect((p.cashPartCents, p.tipCents, p.state), (0, 0, 'started'));
      expect(p.amountCents, pendingAmountBefore);
      expect(
        (await db.select(db.settingsRows).getSingle()).receiptDraft,
        draftBefore,
      );
    },
  );

  test(
    'Update von 1.10.0: ein Bon, den 1.10.0 geschrieben hat, lässt sich '
    'stornieren; das Storno spiegelt ihn, keine Regel ist verletzt',
    () async {
      final db = KassaDatabase(
        NativeDatabase(await copyFixture('kassa_v7_receipts_1_10_0.sqlite')),
      );
      addTearDown(db.close);
      final clock = FixedClock(DateTime(2026, 11, 27, 11));
      final receipts = ReceiptRepository(db, clock, DayRepository(db, clock));
      const chefin = Staff(
        id: 'staff-chefin',
        name: 'Chefin',
        role: StaffRole.chef,
      );
      for (final id in [
        'eeeeeeee-1100-4000-8000-000000000001',
        'eeeeeeee-1100-4000-8000-000000000002',
      ]) {
        final sale = await receipts.byId(id);
        final v = await receipts.voidReceipt(id, staff: chefin);
        expect(v.kind, ReceiptKind.voided, reason: id);
        expect(v.voidsReceiptId, id);
        expect(
          (v.goodsCents, v.depositCents, v.totalCents, v.discountCents),
          (
            -sale.goodsCents,
            -sale.depositCents,
            -sale.totalCents,
            -sale.discountCents,
          ),
          reason: id,
        );
        expect(
          [for (final p in v.payments) (p.position, p.kind, p.amountCents)],
          [for (final p in sale.payments) (p.position, p.kind, -p.amountCents)],
          reason: id,
        );
        expect(
          [for (final l in v.lines) (l.itemId, -l.quantity)],
          [for (final l in sale.lines) (l.itemId, l.quantity)],
          reason: id,
        );
      }
    },
  );

  test('Schritt 8 ist wiederholbar: Version zurückgesetzt, die Kassa öffnet '
      'auf Version 8 und ein gespeicherter Schalter bleibt an', () async {
    final file = await copyFixture('kassa_v7.sqlite');
    final first = KassaDatabase(NativeDatabase(file));
    expect(await userVersion(first), 9);
    final repo = SettingsRepository(first);
    await repo.save((await repo.current()).copyWith(cardTipEnabled: true));
    final paymentsAfterFirst = await count(first, 'payments');
    await first.close();

    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('PRAGMA user_version = 7');
    raw.close();

    final db = KassaDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(await userVersion(db), 9);
    expect(await count(db, 'payments'), paymentsAfterFirst);
    expect((await SettingsRepository(db).current()).cardTipEnabled, isTrue);
  });

  test('neue Datenbank: Version 8, alle Schalter aus', () async {
    final db = KassaDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await userVersion(db), 9);
    final s = await SettingsRepository(db).current();
    expect(
      (
        s.splitPaymentEnabled,
        s.cardTipEnabled,
        s.discountAccess,
        s.openAmountAccess,
      ),
      (false, false, FeatureAccess.off, FeatureAccess.off),
    );
    // Auch eine gespeicherte Zeile trägt die Vorgaben der Datenbank.
    await db.customStatement('INSERT INTO settings (id) VALUES (1)');
    final row = await db.select(db.settingsRows).getSingle();
    expect(
      (row.splitPayment, row.cardTip, row.discountAccess, row.openAmountAccess),
      (false, false, 'off', 'off'),
    );
  });

  test(
    'zwei Zahlungen an einem Bon gehen, dieselbe Stelle zweimal nicht',
    () async {
      final db = KassaDatabase(
        NativeDatabase(await copyFixture('kassa_v7.sqlite')),
      );
      addTearDown(db.close);
      Future<void> insert(int position) => db.customStatement(
        'INSERT INTO payments (receipt_id, position, kind, amount_cents, '
        "given_cents, change_cents) VALUES ('v7-0002', $position, 'card', 100, "
        '0, 0)',
      );
      await insert(1);
      expect(
        await count(db, 'payments'),
        7,
        reason: 'v7-0002 hat jetzt Stelle 0 und 1',
      );
      await expectLater(insert(1), throwsA(isA<SqliteException>()));
    },
  );
}
