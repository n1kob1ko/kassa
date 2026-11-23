// Helfer für Tests der Monatsabrechnung: Verkäufe in vergangenen Monaten
// anlegen, den Abschluss öffnen und auf "Monat" umschalten.

import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/features/login/session.dart';
import 'package:material_ui/material_ui.dart';

import 'bons_pump.dart';
import 'close_pump.dart';
import 'kassa_pump.dart';
import 'overview_pump.dart';

/// Ein Verkauf am 15.9.2026, drei im Oktober (zwei am 1.10., einer am 2.10.),
/// je 18,20 € bar: September 18,20 €, Oktober 54,60 €.
List<OverviewSale> defaultMonthSales() => [
  OverviewSale(DateTime(2026, 9, 15, 12)),
  OverviewSale(DateTime(2026, 10, 1, 12)),
  OverviewSale(DateTime(2026, 10, 1, 13)),
  OverviewSale(DateTime(2026, 10, 2, 12)),
];

/// Ein Monats- oder Jahresbeleg der Signatur, direkt in der Datenbank.
class SignatureReceipt {
  const SignatureReceipt(
    this.at, {
    this.number = 12400,
    this.kind = ReceiptKind.month,
    this.id = 'beleg-1',
  });

  final DateTime at;
  final int number;
  final ReceiptKind kind;
  final String id;
}

/// Legt als Chef [sales] an (aufsteigend, jeder Tag am Abend abgeschlossen),
/// stellt die Uhr auf [now] (Standard 17.11.2026, 11 Uhr), öffnet den
/// Abschluss und tippt auf "Monat" ([openMonth]).
///
/// [printer]: ein Netzwerkdrucker ist eingerichtet. [signature]: es gibt eine
/// Kette der Signatur (Probe), die Karte zum Monatsbeleg erscheint. [live]:
/// die Kette ist `live` und alle Bons stehen darin, also kein Testbetrieb.
/// [belege] sind Monats- oder Jahresbelege.
Future<void> pumpMonth(
  WidgetTester t, {
  List<OverviewSale>? sales,
  DateTime? now,
  bool printer = false,
  bool signature = false,
  bool live = false,
  List<SignatureReceipt> belege = const [],
  bool openMonth = true,
  Size size = const Size(1280, 800),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
}) async {
  final list = sales ?? defaultMonthSales();
  final clock = FixedClock(
    list.isEmpty ? DateTime(2026, 11, 17, 11) : list.first.at,
  );
  await pumpClose(
    t,
    sales: 0,
    openArea: false,
    clock: clock,
    size: size,
    brightness: brightness,
    textScale: textScale,
  );
  for (final s in list) {
    clock.value = s.at;
    await closeForgottenDay(t);
    final r = await sellCash(t, cart: s.cart ?? bowlCart());
    if (s.voided) {
      await containerOf(t)
          .read(receiptRepositoryProvider)
          .voidReceipt(r.id, staff: containerOf(t).read(sessionProvider)!);
    }
  }
  clock.value = now ?? DateTime(2026, 11, 17, 11);
  await closeForgottenDay(t);
  if (printer) await setUpPrinter(t);
  if (signature || live) await _seedChain(t, live: live);
  for (final b in belege) {
    await _insertBeleg(t, b);
  }
  await t.pumpAndSettle();
  await openClose(t);
  if (openMonth) await tapKey(t, 'segment-Monat');
}

Future<void> tapKey(WidgetTester t, String key) async {
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

/// Kette 1 der Signatur. Mit [live] stehen alle Verkäufe und Storno-Bons
/// darin.
Future<void> _seedChain(WidgetTester t, {required bool live}) async {
  final db = containerOf(t).read(databaseProvider);
  await db
      .into(db.rksvCertificateRows)
      .insert(
        RksvCertificateRowsCompanion.insert(
          serialHex: '01',
          certificate: Uint8List.fromList([1, 2, 3]),
        ),
      );
  await db
      .into(db.rksvChainRows)
      .insert(
        RksvChainRowsCompanion.insert(
          chain: const Value(1),
          mode: live ? 'live' : 'probe',
          cashBoxId: 'KASSA-1',
          zdaId: 'AT0',
          certSerial: '01',
          startedAt: DateTime(2026, 1, 1),
        ),
      );
  if (!live) return;
  final receipts = await (db.select(
    db.receiptRows,
  )..orderBy([(r) => OrderingTerm.asc(r.number)])).get();
  var position = 1;
  for (final r in receipts) {
    await db
        .into(db.rksvEntryRows)
        .insert(
          RksvEntryRowsCompanion.insert(
            chain: 1,
            position: position++,
            receiptId: r.id,
            jws: 'x',
            damaged: false,
            certSerial: '01',
          ),
        );
  }
}

Future<void> _insertBeleg(WidgetTester t, SignatureReceipt b) {
  final db = containerOf(t).read(databaseProvider);
  final staff = containerOf(t).read(sessionProvider)!;
  return db
      .into(db.receiptRows)
      .insert(
        ReceiptRowsCompanion.insert(
          id: b.id,
          number: b.number,
          createdAt: b.at,
          staffId: staff.id,
          staffName: staff.name,
          kind: b.kind.name,
          goodsCents: 0,
          depositCents: 0,
          totalCents: 0,
        ),
      );
}

/// Anzahl der Zeilen in Bons, Einträgen der Signatur und Ausgang.
Future<List<int>> rowCounts(WidgetTester t) async {
  final db = containerOf(t).read(databaseProvider);
  return [
    (await db.select(db.receiptRows).get()).length,
    (await db.select(db.rksvEntryRows).get()).length,
    (await db.select(db.outboxRows).get()).length,
  ];
}
