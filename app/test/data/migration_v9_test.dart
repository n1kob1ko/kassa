import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/card_payment_repository.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/settings_repository.dart';

import 'generated_migrations/schema.dart';
import 'migration_test.dart' show copyFixture;

/// Version 9 (Stufe 1b: Pfand zurück, Gutschein, Rechnung an Firma,
/// digitaler Beleg) nach Version 8 (1.11.0). Die Datei `kassa_v8.sqlite`
/// entsteht mit `tool/make_kassa_v8_fixture.dart` aus dem Code von 1.11.0.
void main() {
  Future<int> userVersion(KassaDatabase db) async =>
      (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
        'user_version',
      );

  Future<List<Map<String, Object?>>> rows(KassaDatabase db, String sql) async =>
      [for (final r in await db.customSelect(sql).get()) r.data];

  /// Trigger und Indizes mit ihrem SQL, nach Namen.
  Future<List<Map<String, Object?>>> guards(KassaDatabase db) => rows(
    db,
    "SELECT type, name, sql FROM sqlite_master WHERE type IN ('trigger', "
    "'index') AND sql IS NOT NULL ORDER BY name",
  );

  for (final from in [1, 3, 6, 7, 8]) {
    test('Schema: Version $from wird zu Version 9', () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final db = KassaDatabase(await verifier.startAt(from));
      await verifier.migrateAndValidate(db, 9);
      await db.close();
    });
  }

  test('8 → 9: Bons, Zahlungen, Entwurf und offene Kartenzahlung aus 1.11.0 '
      'bleiben', () async {
    final file = await copyFixture('kassa_v8.sqlite');
    final raw = sqlite.sqlite3.open(file.path);
    expect(raw.select('PRAGMA user_version').single.values.single, 8);
    List<Map<String, Object?>> rawRows(String sql) => [
      for (final r in raw.select(sql)) {for (final k in r.keys) k: r[k]},
    ];
    final paymentsBefore = rawRows(
      'SELECT receipt_id, position, kind, amount_cents, given_cents, '
      'change_cents, tip_cents FROM payments ORDER BY receipt_id, position',
    );
    final receiptsBefore = rawRows('SELECT * FROM receipts ORDER BY number');
    final outboxBefore = rawRows('SELECT * FROM outbox ORDER BY id');
    raw.close();
    expect(receiptsBefore, hasLength(5));
    expect(paymentsBefore.map((p) => p['kind']).toSet(), {'cash', 'card'});
    final fixturePayments = [
      for (final p in paymentsBefore) {'kind': p['kind'], 'voucher_id': null},
    ];

    final db = KassaDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(await userVersion(db), 9);
    expect(
      await rows(
        db,
        'SELECT COUNT(*) AS c FROM receipts WHERE public_token IS NOT NULL',
      ),
      [
        {'c': 0},
      ],
    );
    expect(
      await rows(
        db,
        'SELECT kind, voucher_id FROM payments ORDER BY receipt_id, position',
      ),
      fixturePayments,
    );
    expect(
      await rows(
        db,
        'SELECT receipt_id, position, kind, amount_cents, given_cents, '
        'change_cents, tip_cents FROM payments '
        'WHERE voucher_code IS NULL AND voucher_balance_after_cents IS NULL '
        'ORDER BY receipt_id, position',
      ),
      paymentsBefore,
    );
    expect(
      await rows(
        db,
        'SELECT ${receiptsBefore.first.keys.join(', ')} FROM receipts '
        'ORDER BY number',
      ),
      receiptsBefore,
    );
    expect(
      await rows(
        db,
        'SELECT deposit_return_access, voucher, invoice, receipt_mode '
        'FROM settings',
      ),
      [
        {
          'deposit_return_access': 'off',
          'voucher': 0,
          'invoice': 0,
          'receipt_mode': 'alwaysPrint',
        },
      ],
    );
    expect(
      await rows(
        db,
        'SELECT split_payment, card_tip, discount_access, '
        'open_amount_access FROM settings',
      ),
      [
        {
          'split_payment': 1,
          'card_tip': 1,
          'discount_access': 'all',
          'open_amount_access': 'all',
        },
      ],
    );
    expect(await SettingsRepository(db).readDraft(), isNotNull);
    final pending = await CardPaymentRepository(
      db,
      FixedClock(DateTime.utc(2026, 11, 27)),
    ).pending();
    expect(pending, hasLength(1));
    expect((pending.single.cashPartCents, pending.single.tipCents), (400, 150));
    expect(
      await rows(
        db,
        'SELECT pull_cursor, initial_pull_done, '
        'register_id IS NOT NULL AS paired FROM sync_state',
      ),
      [
        {'pull_cursor': 0, 'initial_pull_done': 1, 'paired': 1},
      ],
      reason: 'die Datei ist gekoppelt und hatte pull_cursor 57',
    );
    // Nichts Neues in der Liste "noch zu senden", die neuen Tabellen leer.
    expect(await rows(db, 'SELECT * FROM outbox ORDER BY id'), outboxBefore);
    for (final table in const [
      'vouchers',
      'voucher_movements',
      'customers',
      'receipt_recipients',
      'receipt_deliveries',
    ]) {
      expect(await rows(db, 'SELECT COUNT(*) AS c FROM $table'), [
        {'c': 0},
      ], reason: table);
    }
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test(
    'frische Installation und Migration haben dieselben Trigger und Indizes',
    () async {
      final fresh = KassaDatabase(NativeDatabase.memory());
      addTearDown(fresh.close);
      final migrated = KassaDatabase(
        NativeDatabase(await copyFixture('kassa_v8.sqlite')),
      );
      addTearDown(migrated.close);
      expect(await guards(migrated), await guards(fresh));
      expect(await userVersion(fresh), 9);
    },
  );

  test('Schritt 9 ist wiederholbar: Version zurückgesetzt, die Kassa öffnet '
      'auf Version 9, und der Stand des Abholens bleibt', () async {
    final file = await copyFixture('kassa_v8.sqlite');
    final first = KassaDatabase(NativeDatabase(file));
    expect(await userVersion(first), 9);
    await first.customStatement('UPDATE sync_state SET pull_cursor = 12');
    await first.close();

    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('PRAGMA user_version = 8');
    raw.close();

    final db = KassaDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(await userVersion(db), 9);
    expect((await db.select(db.syncStateRows).getSingle()).pullCursor, 12);
  });

  group('die neuen Tabellen', () {
    late KassaDatabase db;

    setUp(() async {
      db = KassaDatabase(NativeDatabase.memory());
      await db.customStatement(
        'INSERT INTO voucher_movements (voucher_id, receipt_id, kind, '
        "amount_cents, created_at) VALUES ('g1', 'r1', 'sale', 2000, 1)",
      );
      await db.customStatement(
        'INSERT INTO receipt_recipients (receipt_id, version, customer_id, '
        'name, address_line1, address_line2, vat_id, created_at, staff_id, '
        "staff_name) VALUES ('r1', 0, 'c1', 'Muster GmbH', 'Musterweg 1', "
        "'1010 Wien', 'ATU00000000', 1, 'staff-anna', 'Anna')",
      );
      await db.customStatement(
        'INSERT INTO receipt_deliveries (receipt_id, kind, at) '
        "VALUES ('r1', 'printed', 1)",
      );
      await db.customStatement(
        'INSERT INTO vouchers (id, code, value_cents, created_at, '
        "sold_receipt_id, sold_line_position, is_test) VALUES ('g1', "
        "'ABCD-EFGH', 2000, 1, 'r1', 0, 0)",
      );
    });
    tearDown(() => db.close());

    test('Bewegungen, Empfänger und Belegerteilung nehmen kein UPDATE und kein '
        'DELETE', () async {
      for (final (table, set) in const [
        ('voucher_movements', 'amount_cents = 1'),
        ('receipt_recipients', "name = 'Andere GmbH'"),
        ('receipt_deliveries', 'at = 2'),
      ]) {
        await expectLater(
          db.customStatement('UPDATE $table SET $set'),
          throwsA(isA<SqliteException>()),
          reason: table,
        );
        await expectLater(
          db.customStatement('DELETE FROM $table'),
          throwsA(isA<SqliteException>()),
          reason: table,
        );
        expect(await rows(db, 'SELECT COUNT(*) AS c FROM $table'), [
          {'c': 1},
        ], reason: table);
      }
      expect(await rows(db, 'SELECT amount_cents FROM voucher_movements'), [
        {'amount_cents': 2000},
      ]);
    });

    test('ein Gutschein behält Code und Wert: UPDATE von code oder value_cents '
        'und DELETE werfen', () async {
      for (final set in const [
        "code = 'ZZZZ-ZZZZ'",
        'value_cents = 1',
        "code = 'ZZZZ-ZZZZ', value_cents = 1",
      ]) {
        await expectLater(
          db.customStatement('UPDATE vouchers SET $set'),
          throwsA(isA<SqliteException>()),
          reason: set,
        );
      }
      await expectLater(
        db.customStatement('DELETE FROM vouchers'),
        throwsA(isA<SqliteException>()),
      );
      // Andere Felder dürfen sich ändern, und derselbe Code mit demselben
      // Wert geht (ein Abgleich schreibt die Zeile noch einmal).
      await db.customStatement(
        "UPDATE vouchers SET is_test = 1, code = 'ABCD-EFGH', "
        'value_cents = 2000',
      );
      expect(
        await rows(db, 'SELECT code, value_cents, is_test FROM vouchers'),
        [
          {'code': 'ABCD-EFGH', 'value_cents': 2000, 'is_test': 1},
        ],
      );
    });

    test('ein neuer Empfänger und eine neue Belegerteilung stehen in der Liste '
        '"noch zu senden"', () async {
      expect(
        await rows(
          db,
          'SELECT kind, ref FROM outbox '
          "WHERE kind IN ('recipient', 'delivery') ORDER BY id",
        ),
        [
          {'kind': 'recipient', 'ref': 'r1/0'},
          {'kind': 'delivery', 'ref': 'r1/printed'},
        ],
      );
      // Gutscheine, Bewegungen und Firmenkunden tragen sich nicht ein.
      await db.customStatement(
        'INSERT INTO customers (id, name, address_line1, address_line2, '
        "updated_at) VALUES ('c1', 'Muster GmbH', 'Musterweg 1', "
        "'1010 Wien', 1)",
      );
      expect(
        await rows(
          db,
          'SELECT kind FROM outbox '
          "WHERE kind NOT IN ('recipient', 'delivery')",
        ),
        isEmpty,
      );
    });

    test('Schlüssel: je Gutschein und Bon eine Bewegung, je Bon und Fassung '
        'ein Empfänger, je Bon und Art eine Belegerteilung', () async {
      for (final sql in const [
        'INSERT INTO voucher_movements (voucher_id, receipt_id, kind, '
            "amount_cents, created_at) VALUES ('g1', 'r1', 'redeem', -500, 2)",
        'INSERT INTO receipt_recipients (receipt_id, version, name, '
            'address_line1, address_line2, created_at, staff_id, staff_name) '
            "VALUES ('r1', 0, 'Andere GmbH', 'Weg 2', '1010 Wien', 2, "
            "'staff-anna', 'Anna')",
        'INSERT INTO receipt_deliveries (receipt_id, kind, at) '
            "VALUES ('r1', 'printed', 2)",
      ]) {
        await expectLater(
          db.customStatement(sql),
          throwsA(isA<SqliteException>()),
          reason: sql,
        );
      }
      await db.customStatement(
        'INSERT INTO receipt_recipients (receipt_id, version, name, '
        'address_line1, address_line2, created_at, staff_id, staff_name) '
        "VALUES ('r1', 1, 'Andere GmbH', 'Weg 2', '1010 Wien', 2, "
        "'staff-anna', 'Anna')",
      );
      await db.customStatement(
        'INSERT INTO receipt_deliveries (receipt_id, kind, at) '
        "VALUES ('r1', 'digital', 2)",
      );
      expect(
        await rows(
          db,
          'SELECT kind, ref FROM outbox '
          "WHERE kind IN ('recipient', 'delivery') ORDER BY id",
        ),
        [
          {'kind': 'recipient', 'ref': 'r1/0'},
          {'kind': 'delivery', 'ref': 'r1/printed'},
          {'kind': 'recipient', 'ref': 'r1/1'},
          {'kind': 'delivery', 'ref': 'r1/digital'},
        ],
      );
    });

    test('Vorgaben: Firmenkunde nicht stillgelegt, Gutschein-Zeile ohne '
        'Verkauf', () async {
      await db.customStatement(
        'INSERT INTO customers (id, name, address_line1, address_line2, '
        "updated_at) VALUES ('c1', 'Muster GmbH', 'Musterweg 1', "
        "'1010 Wien', 1)",
      );
      await db.customStatement(
        'INSERT INTO vouchers (id, code, value_cents, created_at, is_test) '
        "VALUES ('g2', 'IJKL-MNOP', 1000, 1, 1)",
      );
      expect(
        await rows(db, 'SELECT archived, vat_id, last_used_at FROM customers'),
        [
          {'archived': 0, 'vat_id': null, 'last_used_at': null},
        ],
      );
      expect(
        await rows(
          db,
          "SELECT sold_receipt_id, sold_line_position FROM vouchers "
          "WHERE id = 'g2'",
        ),
        [
          {'sold_receipt_id': null, 'sold_line_position': null},
        ],
      );
      expect(
        await rows(
          db,
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND tbl_name = 'vouchers' AND sql LIKE '%code%'",
        ),
        hasLength(1),
      );
    });
  });
}
