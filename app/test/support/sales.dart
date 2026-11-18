// Testumgebung für Bons: Datenbank im Speicher, feste Uhr, Beispiel-Katalog,
// Mitarbeiter Anna (Rolle staff) und Chef (Rolle chef). Spätere Tests
// erweitern die Klasse um ihre Repositories.

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/catalog_repository.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/day_repository.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/data/stats_repository.dart';
import 'package:kassa/data/staff_repository.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/staff.dart';

import 'demo_fixtures.dart';

/// Der Bon aus dem ersten Bon-Test: 2 x Cola, 1 x Huhn Bowl (XXL, Nudeln),
/// 18,20 € mit 0,50 € Pfand.
final Cart cart = const Cart.empty()
    .add(cola)
    .add(cola)
    .add(huhnBowl, options: [xxl, nudeln]);

/// Ein kleiner Bon für Kartenzahlungen: 1 x Teigtaschen, 1 x Cola.
final Cart cartCard = const Cart.empty().add(teigtaschen).add(cola);

class TestShop {
  TestShop._(
    this.db,
    this.clock,
    this.catalogRepo,
    this.staffRepo,
    this.days,
    this.receipts,
    this.stats,
    this.anna,
    this.chef,
  );

  final KassaDatabase db;
  final FixedClock clock;
  final CatalogRepository catalogRepo;
  final StaffRepository staffRepo;
  final DayRepository days;
  final ReceiptRepository receipts;
  final StatsRepository stats;
  final Staff anna;
  final Staff chef;

  static Future<TestShop> open() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = KassaDatabase(NativeDatabase.memory());
    final clock = FixedClock(DateTime(2026, 11, 17, 11));
    final catalogRepo = CatalogRepository(db);
    await catalogRepo.importCatalog(catalog);
    final staffRepo = StaffRepository(db);
    final anna = await staffRepo.create(
      name: 'Anna',
      pin: '1111',
      role: StaffRole.staff,
    );
    final chef = await staffRepo.create(
      name: 'Chef',
      pin: '2222',
      role: StaffRole.chef,
    );
    final days = DayRepository(db, clock);
    final receipts = ReceiptRepository(db, clock, days);
    final stats = StatsRepository(db, clock);
    return TestShop._(
      db,
      clock,
      catalogRepo,
      staffRepo,
      days,
      receipts,
      stats,
      anna,
      chef,
    );
  }

  Future<void> close() => db.close();

  /// Legt einen Kartenbon über [totalCents] ohne Zeilen an (die Kassa kennt
  /// noch keine Kartenzahlung). Ohne [day] gehört er zum offenen Tag, ohne
  /// [at] trägt er die Zeit der Uhr.
  Future<void> insertCardReceipt(
    String id,
    int number,
    int totalCents, {
    String? day,
    DateTime? at,
  }) async {
    day ??= await dayId();
    await db
        .into(db.receiptRows)
        .insert(
          ReceiptRowsCompanion.insert(
            id: id,
            number: number,
            createdAt: at ?? clock.now(),
            staffId: anna.id,
            staffName: anna.name,
            businessDayId: Value(day),
            kind: ReceiptKind.sale.name,
            goodsCents: totalCents,
            depositCents: 0,
            totalCents: totalCents,
          ),
        );
    await db
        .into(db.paymentRows)
        .insert(
          PaymentRowsCompanion.insert(
            receiptId: id,
            kind: PaymentKind.card.name,
            amountCents: totalCents,
            givenCents: 0,
            changeCents: 0,
          ),
        );
  }

  /// Legt einen Sonderbeleg der Art [kind] an, wie Task 5 ihn schreiben
  /// wird: Betrag 0, keine Zeilen, keine Zahlung, ohne [day] auch ohne Tag.
  Future<void> insertSpecialReceipt(
    String id,
    int number,
    ReceiptKind kind, {
    DateTime? at,
    String? day,
  }) => db
      .into(db.receiptRows)
      .insert(
        ReceiptRowsCompanion.insert(
          id: id,
          number: number,
          createdAt: at ?? clock.now(),
          staffId: anna.id,
          staffName: anna.name,
          businessDayId: Value(day),
          kind: kind.name,
          goodsCents: 0,
          depositCents: 0,
          totalCents: 0,
        ),
      );

  /// Legt einen Geschäftstag an, der um [openedAt] beginnt und, wenn
  /// [closedAt] gesetzt ist, schon abgeschlossen ist.
  Future<void> insertDay(String id, DateTime openedAt, {DateTime? closedAt}) =>
      db
          .into(db.businessDayRows)
          .insert(
            BusinessDayRowsCompanion.insert(
              id: id,
              openedAt: openedAt,
              closedAt: Value(closedAt),
            ),
          );

  /// Verkauft [cart] bar mit 20,00 € als Anna.
  Future<Receipt> sell(String saleId) => receipts.finalizeCashSale(
    saleId: saleId,
    cart: cart,
    givenCents: 2000,
    staff: anna,
  );

  /// Verkauft [cart] (Standard: [cartCard]) mit Karte als Anna.
  Future<Receipt> sellCard(String saleId, {Cart? cart}) =>
      receipts.finalizeCardSale(
        saleId: saleId,
        cart: cart ?? cartCard,
        staff: anna,
        provider: 'sumup',
        txCode: 'TX-$saleId',
        cardScheme: 'VISA',
        cardLast4: '4242',
      );

  /// Id des offenen Geschäftstags.
  Future<String> dayId() async {
    final row = await db
        .customSelect('SELECT id FROM business_days WHERE closed_at IS NULL')
        .getSingle();
    return row.read<String>('id');
  }

  Future<int> count(String table) async =>
      (await db.customSelect('SELECT COUNT(*) c FROM $table').getSingle())
          .read<int>('c');
}
