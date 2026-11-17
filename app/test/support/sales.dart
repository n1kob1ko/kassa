// Testumgebung für Bons: Datenbank im Speicher, feste Uhr, Beispiel-Katalog,
// Mitarbeiter Anna (Rolle staff) und Chef (Rolle chef). Spätere Tests
// erweitern die Klasse um ihre Repositories.

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/catalog_repository.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/day_repository.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/data/staff_repository.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/staff.dart';

import 'demo_fixtures.dart';

/// Der Bon aus dem ersten Bon-Test: 2 x Cola, 1 x Huhn Bowl (XXL, Nudeln),
/// 18,20 € mit 0,50 € Pfand.
final Cart cart = const Cart.empty().add(cola).add(cola).add(huhnBowl, options: [xxl, nudeln]);

class TestShop {
  TestShop._(
    this.db,
    this.clock,
    this.catalogRepo,
    this.staffRepo,
    this.days,
    this.receipts,
    this.anna,
    this.chef,
  );

  final KassaDatabase db;
  final FixedClock clock;
  final CatalogRepository catalogRepo;
  final StaffRepository staffRepo;
  final DayRepository days;
  final ReceiptRepository receipts;
  final Staff anna;
  final Staff chef;

  static Future<TestShop> open() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = KassaDatabase(NativeDatabase.memory());
    final clock = FixedClock(DateTime(2026, 11, 17, 11));
    final catalogRepo = CatalogRepository(db);
    await catalogRepo.importCatalog(catalog);
    final staffRepo = StaffRepository(db);
    final anna = await staffRepo.create(name: 'Anna', pin: '1111', role: StaffRole.staff);
    final chef = await staffRepo.create(name: 'Chef', pin: '2222', role: StaffRole.chef);
    final days = DayRepository(db, clock);
    final receipts = ReceiptRepository(db, clock, days);
    return TestShop._(db, clock, catalogRepo, staffRepo, days, receipts, anna, chef);
  }

  Future<void> close() => db.close();

  /// Verkauft [cart] bar mit 20,00 € als Anna.
  Future<Receipt> sell(String saleId) =>
      receipts.finalizeCashSale(saleId: saleId, cart: cart, givenCents: 2000, staff: anna);

  /// Id des offenen Geschäftstags.
  Future<String> dayId() async {
    final row = await db
        .customSelect('SELECT id FROM business_days WHERE closed_at IS NULL')
        .getSingle();
    return row.read<String>('id');
  }

  Future<int> count(String table) async =>
      (await db.customSelect('SELECT COUNT(*) c FROM $table').getSingle()).read<int>('c');
}
