// Erzeugt test/data/fixtures/kassa_v8.sqlite: eine Datenbank im Stand der
// Version 1.11.0 (Datenbank Version 8). Anders als die älteren Werkzeuge
// schreibt dieses mit dem Code von 1.11.0 selbst (`KassaDatabase`,
// `ReceiptRepository`, `CardPaymentRepository`, `Cart`), damit Bons, Entwurf
// und offene Kartenzahlung genau die Form haben, die 1.11.0 schreibt. Darum
// läuft es nur, solange `KassaDatabase.schemaVersion` 8 ist (sonst bricht es
// ab); später mit dem Stand von 1.11.0 (Commit a06aeb3). Der Code der
// Bons zieht über die Signatur Flutter mit, darum läuft das Werkzeug mit
// `flutter test` statt `dart run`. Aufruf aus `app/`:
//
//   flutter test tool/make_kassa_v8_fixture.dart
//
// Inhalt (alles erfunden, keine echten Namen, keine Schlüssel): ein Imbiss,
// ein gekoppeltes Tablet (erfundene Kennungen, Stand 57, erstes Laden
// erledigt), alle vier Schalter von 1a an, ein offener Tag und fünf Bons: bar,
// "Teil bar, Rest Karte" mit Trinkgeld, mit Zeilen- und Bon-Rabatt, mit
// freiem Betrag, und das Storno des Bar-Bons. Dazu ein Entwurf des offenen
// Bons mit Rabatt und eine offene Kartenzahlung mit Bar-Teil und Trinkgeld.
// Die Liste der Sendungen füllen die Trigger von Version 8 mit.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/card_payment_repository.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/day_repository.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/discount.dart';
import 'package:kassa/domain/staff.dart';

const _target = 'test/data/fixtures/kassa_v8.sqlite';

const _bowl = Item(
  id: 'huhn-bowl',
  name: 'Huhn Bowl',
  priceCents: 1090,
  categoryId: 'bowls',
  taxRate: TaxRate.reduced1,
  position: 0,
);
const _cola = Item(
  id: 'cola',
  name: 'Cola 0,33 l',
  priceCents: 320,
  categoryId: 'getraenke',
  taxRate: TaxRate.normal,
  depositCents: 25,
  favorite: true,
  position: 1,
);

const _anna = Staff(id: 'staff-anna', name: 'Anna', role: StaffRole.staff);
const _chefin = Staff(id: 'staff-chefin', name: 'Chefin', role: StaffRole.chef);

void main() {
  test('schreibt $_target', _write);
}

Future<void> _write() async {
  // Erst die Version prüfen, dann die eingecheckte Datei löschen: mit dem
  // Code einer späteren Version bleibt sie, wie sie ist.
  final probe = KassaDatabase(NativeDatabase.memory());
  final version = probe.schemaVersion;
  await probe.close();
  if (version != 8) {
    fail(
      'Abbruch: der Code ist nicht mehr 1.11.0 '
      '(Datenbank-Version $version statt 8).',
    );
  }
  final file = File(_target);
  if (file.existsSync()) file.deleteSync();
  final db = KassaDatabase(NativeDatabase(file));
  Future<void> run(String sql) => db.customStatement(sql);

  // Löst onCreate aus: Tabellen, Trigger und Indizes von Version 8.
  await run('SELECT 1');
  await run(
    'INSERT INTO business (id, name, address_lines, receipt_footer) VALUES '
    "(1, 'Beispiel-Imbiss', 'Musterstraße 1\n1010 Wien', 'Danke!')",
  );
  await db
      .into(db.settingsRows)
      .insert(
        const SettingsRowsCompanion(
          id: Value(1),
          splitPayment: Value(true),
          cardTip: Value(true),
          discountAccess: Value('all'),
          openAmountAccess: Value('all'),
        ),
      );
  // Gekoppelt, keine Adresse; die Kennungen sind erfunden.
  await run(
    'INSERT INTO sync_state (id, register_id, register_name, business_id, '
    'pull_cursor, initial_pull_done, device_id) VALUES '
    "(1, '5d49b160-7775-46ff-adcb-417a02af69bd', 'Kassa 1', "
    "'bc39da18-8c2e-4862-85df-8c31c0c6f912', 57, 1, "
    "'fa807a27-f02f-4b9b-839d-9e2a7535e30f')",
  );
  await run(
    'INSERT INTO staff (id, name, role, pin_salt, pin_hash) VALUES '
    "('staff-chefin', 'Chefin', 'chef', 'salt', 'hash'), "
    "('staff-anna', 'Anna', 'staff', 'salt', 'hash')",
  );
  await run(
    'INSERT INTO categories (id, name, position) VALUES '
    "('bowls', 'Bowls', 0), ('getraenke', 'Getränke', 1)",
  );
  await run(
    'INSERT INTO items (id, name, price_cents, category_id, tax_percent, '
    'deposit_cents, tags, favorite, in_sale, position) VALUES '
    "('huhn-bowl', 'Huhn Bowl', 1090, 'bowls', 10, 0, '', 0, 1, 0), "
    "('cola', 'Cola 0,33 l', 320, 'getraenke', 20, 25, '', 1, 1, 1)",
  );

  // 2026-11-26, ab 10 Uhr.
  final clock = FixedClock(DateTime.utc(2026, 11, 26, 10));
  void later() => clock.value = clock.value.add(const Duration(minutes: 7));
  final days = DayRepository(db, clock);
  await days.setOpeningFloat(10000);
  final receipts = ReceiptRepository(db, clock, days);

  Cart bowlAndCola(String prefix) => const Cart.empty()
      .add(_bowl, lineId: '$prefix-line-1')
      .add(_cola, lineId: '$prefix-line-2');

  // 1. Bar.
  later();
  await receipts.finalizeCashSale(
    saleId: 'v8-0001',
    cart: bowlAndCola('v8-0001'),
    givenCents: 2000,
    staff: _anna,
  );
  // 2. Teil bar, Rest Karte, mit Trinkgeld.
  later();
  await receipts.finalizeCardSale(
    saleId: 'v8-0002',
    cart: bowlAndCola('v8-0002'),
    staff: _anna,
    provider: 'demo',
    txCode: 'TX-DEMO-0002',
    cardScheme: 'VISA',
    cardLast4: '0000',
    cashPartCents: 500,
    tipCents: 100,
  );
  // 3. Zeilen-Rabatt (10 %) und Bon-Rabatt (1,00), bar.
  later();
  await receipts.finalizeCashSale(
    saleId: 'v8-0003',
    cart: bowlAndCola('v8-0003')
        .setLineDiscount(
          'v8-0003-line-1',
          const Discount.percent(10, DiscountReason.regular),
        )
        .setReceiptDiscount(
          const Discount.amount(100, DiscountReason.promotion),
        ),
    givenCents: 2000,
    staff: _anna,
  );
  // 4. Freier Betrag zu 13 % neben einer Cola, bar.
  later();
  await receipts.finalizeCashSale(
    saleId: 'v8-0004',
    cart: const Cart.empty()
        .add(_cola, lineId: 'v8-0004-line-1')
        .addOpenAmount(
          amountCents: 450,
          rate: TaxRate.reduced2,
          lineId: 'v8-0004-line-2',
        ),
    givenCents: 1000,
    staff: _anna,
  );
  // 5. Storno des Bar-Bons.
  later();
  await receipts.voidReceipt('v8-0001', staff: _chefin);

  // Entwurf des offenen Bons mit Bon-Rabatt (nach den Bons: ein Abschluss
  // löscht den Entwurf).
  final draft = bowlAndCola('draft')
      .setReceiptDiscount(const Discount.percent(5, DiscountReason.staff));
  await (db.update(db.settingsRows)..where((t) => t.id.equals(1))).write(
    SettingsRowsCompanion(receiptDraft: Value(jsonEncode(draft.toJson()))),
  );

  // Eine Kartenzahlung mit Bar-Teil und Trinkgeld, am Terminal gestartet,
  // aber noch kein Bon.
  later();
  await CardPaymentRepository(db, clock).begin(
    paymentId: 'v8-pending-0001',
    cart: bowlAndCola('pending'),
    staff: _anna,
    cashPartCents: 400,
    tipCents: 150,
  );

  await run('VACUUM');
  await db.close();
  // ignore: avoid_print
  print('Geschrieben: $_target (5 Bons)');
}
