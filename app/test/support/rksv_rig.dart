// Testaufbau für die Signatur: Datenbank im Speicher, feste Uhr, Beispiel-
// Katalog, Anna (staff) und Chef (chef), geschützter Speicher im Speicher,
// Attrappe der Signatur, Journal, Bons und RksvService. Dazu verifyChain,
// das eine Kette unabhängig vom Journal nachrechnet. Gespeicherte Protokolle
// landen in [RksvRig.saver].

import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart'
    show OrderingTerm, Value, driftRuntimeOptions, innerJoin;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/catalog_repository.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/day_repository.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/data/rksv_repository.dart';
import 'package:kassa/data/staff_repository.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/rksv/card/certificate.dart';
import 'package:kassa/rksv/core/rksv_code.dart';
import 'package:kassa/rksv/dep_export.dart';
import 'package:kassa/rksv/rksv_journal.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/rksv_service.dart';
import 'package:kassa/rksv/rksv_state.dart';
import 'package:pointycastle/digests/sha256.dart';

import 'demo_fixtures.dart';
import 'fake_signature_unit.dart';

/// Speichert ausgegebene Protokolle im Speicher. Mit [accept] false bricht
/// die Person den Speichern-Dialog ab.
class RecordingProtocolSaver implements ProtocolSaver {
  bool accept = true;
  final saved = <(String, Uint8List)>[];

  @override
  Future<bool> save(String fileName, Uint8List bytes) async {
    if (!accept) return false;
    saved.add((fileName, bytes));
    return true;
  }

  /// Der Text der zuletzt gespeicherten Datei.
  String get lastText => utf8.decode(saved.last.$2);
}

class RksvRig {
  RksvRig._(
    this.db,
    this.clock,
    this.secrets,
    this.fake,
    this.journal,
    this.receipts,
    this.service,
    this.rksv,
    this.anna,
    this.chef,
    this.saver,
  );

  final KassaDatabase db;
  final FixedClock clock;
  final MemoryRksvSecrets secrets;
  final FakeSignatureUnit fake;
  final RksvJournal journal;
  final ReceiptRepository receipts;
  final RksvService service;
  final RksvRepository rksv;
  final Staff anna;
  final Staff chef;
  final RecordingProtocolSaver saver;

  /// Ohne [probeUnit] signiert jede Kette mit der Attrappe; deren Zertifikat
  /// steht dafür in `rksv_certificates`. Mit [probeUnit] signiert die
  /// Probe-Signatur wie in der App ([probeSignatureUnitOf]).
  static Future<RksvRig> open({bool probeUnit = false}) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = KassaDatabase(NativeDatabase.memory());
    final clock = FixedClock(DateTime(2026, 11, 18, 13, 5, 9));
    await CatalogRepository(db).importCatalog(catalog);
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
    final secrets = MemoryRksvSecrets();
    final fake = FakeSignatureUnit();
    final info = await fake.info();
    await db
        .into(db.rksvCertificateRows)
        .insert(
          RksvCertificateRowsCompanion.insert(
            serialHex: info.serialHex,
            certificate: info.certificateDer,
          ),
        );
    final journal = RksvJournal(
      db,
      secrets,
      probeUnit ? probeSignatureUnitOf(db, secrets) : (_) async => fake,
      clock,
    );
    final receipts = ReceiptRepository(
      db,
      clock,
      DayRepository(db, clock),
      journal: journal,
    );
    final saver = RecordingProtocolSaver();
    final service = RksvService(db, secrets, receipts, clock, saver: saver);
    return RksvRig._(
      db,
      clock,
      secrets,
      fake,
      journal,
      receipts,
      service,
      RksvRepository(db),
      anna,
      chef,
      saver,
    );
  }

  Future<void> close() => db.close();

  /// Verkauft [cart] bar als Anna, mit genau passendem Betrag.
  Future<Receipt> sell(String saleId, Cart cart) => receipts.finalizeCashSale(
    saleId: saleId,
    cart: cart,
    givenCents: cart.totalCents,
    staff: anna,
  );

  /// Verkauft [cart] mit Karte als Anna.
  Future<Receipt> sellCard(String saleId, Cart cart) =>
      receipts.finalizeCardSale(
        saleId: saleId,
        cart: cart,
        staff: anna,
        provider: 'sumup',
        txCode: 'TX-$saleId',
      );

  Future<RksvStateRow> stateRow() => db.select(db.rksvStateRows).getSingle();

  Future<RksvChainRow> chainRow(int chain) => (db.select(
    db.rksvChainRows,
  )..where((t) => t.chain.equals(chain))).getSingle();

  Future<List<RksvEntryRow>> entries([int? chain]) =>
      (db.select(db.rksvEntryRows)
            ..where(
              (t) =>
                  chain == null ? t.chain.isNotNull() : t.chain.equals(chain),
            )
            ..orderBy([
              (t) => OrderingTerm.asc(t.chain),
              (t) => OrderingTerm.asc(t.position),
            ]))
          .get();

  /// Art des Bons je Eintrag der Kette [chain], nach Position.
  Future<List<String>> entryKinds([int chain = 1]) async {
    final rows =
        await (db.select(db.rksvEntryRows).join([
                innerJoin(
                  db.receiptRows,
                  db.receiptRows.id.equalsExp(db.rksvEntryRows.receiptId),
                ),
              ])
              ..where(db.rksvEntryRows.chain.equals(chain))
              ..orderBy([OrderingTerm.asc(db.rksvEntryRows.position)]))
            .get();
    return [for (final r in rows) r.readTable(db.receiptRows).kind];
  }

  /// Die offenen Aufgaben als (Id, Art, Satz-Angabe).
  Future<List<(String, RksvTaskKind, String)>> tasks() async => [
    for (final t in (await rksv.current()).tasks) (t.id, t.kind, t.detail),
  ];

  Future<RksvEntryRow?> entryOf(String receiptId) => (db.select(
    db.rksvEntryRows,
  )..where((t) => t.receiptId.equals(receiptId))).getSingleOrNull();

  Future<int> count(String table) async =>
      (await db.customSelect('SELECT COUNT(*) c FROM $table').getSingle())
          .read<int>('c');

  /// Setzt den Zustand `live` direkt in die Datenbank (in dieser Stufe führt
  /// kein Weg der App dorthin): Kette 1 mit der Kassen-Kennung `LIVETEST01`,
  /// dem Zertifikat der Attrappe und dem AES-Schlüssel aus den Bytes 0 bis 31.
  Future<void> startLive() async {
    final info = await fake.info();
    await secrets.writeAesKey(
      1,
      Uint8List.fromList(List.generate(32, (i) => i)),
    );
    await db
        .into(db.rksvChainRows)
        .insert(
          RksvChainRowsCompanion.insert(
            chain: const Value(1),
            mode: 'live',
            cashBoxId: 'LIVETEST01',
            zdaId: 'AT100',
            certSerial: info.serialHex,
            startedAt: clock.now(),
          ),
        );
    await (db.update(db.rksvStateRows)..where((t) => t.id.equals(1))).write(
      const RksvStateRowsCompanion(mode: Value('live'), chain: Value(1)),
    );
  }

  /// Rechnet die Kette [chain] nach, ohne das Journal zu fragen: Positionen
  /// 1 bis n, Felder des Codes gegen den Bon, jeder Kettenwert, jede Signatur
  /// gegen ihr Zertifikat (oder der Ausfall-Text), jeder Zähler gegen die
  /// laufende Summe, und bei der laufenden Kette der Zählerstand.
  Future<void> verifyChain(int chain) async {
    final chainRow = await this.chainRow(chain);
    final list = await entries(chain);
    expect(list, isNotEmpty, reason: 'Kette $chain hat keine Einträge');
    final aesKey = (await secrets.aesKey(chain))!;
    var previous = _first8Sha256(chainRow.cashBoxId);
    var counter = 0;
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      final at = 'Kette $chain, Position ${e.position}';
      expect(e.position, i + 1, reason: '$at: Lücke');
      final receipt = await (db.select(
        db.receiptRows,
      )..where((t) => t.id.equals(e.receiptId))).getSingle();
      final parts = e.jws.split('.');
      expect(parts, hasLength(3), reason: at);
      expect(parts[0], 'eyJhbGciOiJFUzI1NiJ9', reason: at);
      final text = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final f = text.split('_');
      expect(f, hasLength(13), reason: '$at: $text');
      expect(f[0], '', reason: at);
      expect(f[1], 'R1-AT100', reason: at);
      expect(f[2], chainRow.cashBoxId, reason: at);
      expect(f[3], '${receipt.number}', reason: at);
      expect(DateTime.parse(f[4]), receipt.createdAt, reason: at);
      final sums = [for (final s in f.sublist(5, 10)) _cents(s)];
      expect(
        sums.fold<int>(0, (a, b) => a + b),
        receipt.totalCents,
        reason: '$at: Summe der Beträge',
      );
      counter += sums.fold<int>(0, (a, b) => a + b);
      if (receipt.kind == ReceiptKind.voided.name) {
        expect(f[10], 'U1RP', reason: at);
      } else {
        expect(
          decryptCounter(
            aesKey: aesKey,
            cashBoxId: chainRow.cashBoxId,
            receiptId: f[3],
            field: f[10],
          ),
          counter,
          reason: '$at: Zähler',
        );
      }
      expect(f[11], e.certSerial, reason: at);
      expect(f[12], previous, reason: '$at: Kettenwert');
      final signature = base64Url.decode(base64Url.normalize(parts[2]));
      if (e.damaged) {
        expect(
          utf8.decode(signature),
          'Sicherheitseinrichtung ausgefallen',
          reason: at,
        );
      } else {
        final cert = await (db.select(
          db.rksvCertificateRows,
        )..where((t) => t.serialHex.equals(e.certSerial))).getSingle();
        final hash = SHA256Digest().process(
          Uint8List.fromList(ascii.encode('${parts[0]}.${parts[1]}')),
        );
        expect(
          CardCertificate.parse(cert.certificate).verify(hash, signature),
          isTrue,
          reason: '$at: Signatur',
        );
      }
      previous = _first8Sha256(e.jws);
    }
    final state = await stateRow();
    if (state.chain == chain) {
      expect(state.counterCents, counter, reason: 'Zählerstand');
    }
  }

  /// Die Felder des Codes zum Bon [receiptId].
  Future<List<String>> codeFieldsOf(String receiptId) async {
    final e = (await entryOf(receiptId))!;
    final payload = e.jws.split('.')[1];
    return utf8
        .decode(base64Url.decode(base64Url.normalize(payload)))
        .split('_');
  }
}

String _first8Sha256(String s) => base64.encode(
  SHA256Digest().process(Uint8List.fromList(utf8.encode(s))).sublist(0, 8),
);

int _cents(String amount) {
  final m = RegExp(r'^(-?)(\d+),(\d\d)$').firstMatch(amount);
  expect(m, isNotNull, reason: 'Betrag "$amount"');
  final cents = int.parse(m!.group(2)!) * 100 + int.parse(m.group(3)!);
  return m.group(1) == '-' ? -cents : cents;
}
