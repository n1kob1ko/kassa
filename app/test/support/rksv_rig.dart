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
import 'package:http/http.dart' as http;
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
import 'package:kassa/rksv/card/atrust_card.dart';
import 'package:kassa/rksv/card/card_facts.dart';
import 'package:kassa/rksv/card/card_signature_unit.dart';
import 'package:kassa/rksv/card/card_signer.dart';
import 'package:kassa/rksv/card/certificate.dart';
import 'package:kassa/rksv/card/pin_guard.dart';
import 'package:kassa/rksv/card/reader_transport.dart';
import 'package:kassa/rksv/core/rksv_code.dart';
import 'package:kassa/rksv/dep_export.dart';
import 'package:kassa/rksv/online/atrust_client.dart';
import 'package:kassa/rksv/online/atrust_session_keeper.dart';
import 'package:kassa/rksv/online/connection_check.dart';
import 'package:kassa/rksv/online/online_signature_unit.dart';
import 'package:kassa/rksv/rksv_journal.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/rksv_service.dart';
import 'package:kassa/rksv/rksv_state.dart';
import 'package:pointycastle/digests/sha256.dart';

import '../rksv/fixtures/test_card.dart';
import 'demo_fixtures.dart';
import 'fake_atrust.dart';
import 'fake_card_reader.dart';
import 'fake_signature_unit.dart';
import 'scripted_reader.dart' show bytesOf;

/// ATR der nachgebauten Karte des Rigs (a.sign RK CHIP mit ACOS-ID 4.1).
const rigCardAtr = '3BDF97008131FE4680319052410464050401AC73D622C0F9';

/// Die erfundene PIN der Karte des Rigs.
const rigCardPin = '246813';

/// Die nachgebaute Signaturkarte des Beispiel-Imbiss mit dem Test-Zertifikat
/// (dasselbe wie das der Attrappe). Ein VERIFY gilt bis zum Ausschalten,
/// außer mit [verifyPerSignature].
FakeCard rigCard({bool verifyPerSignature = false}) {
  final atr = bytesOf(rigCardAtr);
  return FakeCard(
    atr: atr,
    profile: profileForAtr(atr)!,
    pin: rigCardPin,
    certificate: testCertificate,
    signer: testSigner,
    verifyPerSignature: verifyPerSignature,
  );
}

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

/// Geschützter Speicher des Rigs: wie [MemoryRksvSecrets], dazu
/// [failCredentialReads], das nur das Lesen der Zugangsdaten scheitern lässt
/// (der AES-Schlüssel bleibt lesbar).
class RigSecrets extends MemoryRksvSecrets {
  bool failCredentialReads = false;

  /// Wie oft ein AES-Schlüssel gelesen wurde (auch gescheiterte Versuche).
  int aesKeyReads = 0;

  /// Nur das Schreiben (und Löschen) des PendingSetup scheitert.
  bool failPendingSetupWrites = false;

  @override
  Future<void> writePendingSetup(PendingSetup? setup) async {
    if (failPendingSetupWrites) {
      throw StateError('Der sichere Speicher ist nicht beschreibbar.');
    }
    return super.writePendingSetup(setup);
  }

  /// Gesetzt: so viele AES-Schlüssel liest er noch, danach scheitert jedes
  /// Lesen eines AES-Schlüssels (der Rest bleibt lesbar).
  int? aesKeyReadsBeforeFailure;

  @override
  Future<Uint8List?> aesKey(int chain) async {
    aesKeyReads++;
    final left = aesKeyReadsBeforeFailure;
    if (left != null) {
      if (left <= 0) throw StateError('Der sichere Speicher ist nicht lesbar.');
      aesKeyReadsBeforeFailure = left - 1;
    }
    return super.aesKey(chain);
  }

  @override
  Future<AtrustCredentials?> atrustCredentials() async {
    if (failCredentialReads) {
      throw StateError('Der sichere Speicher ist nicht lesbar.');
    }
    return super.atrustCredentials();
  }
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
    this.atrust,
    this.keeper,
    this.liveKeeper,
    this.cardReader,
    this.pinGuard,
    this.cardSigner,
  );

  final KassaDatabase db;
  final FixedClock clock;
  final RigSecrets secrets;
  final FakeSignatureUnit fake;
  final RksvJournal journal;
  final ReceiptRepository receipts;
  final RksvService service;
  final RksvRepository rksv;
  final Staff anna;
  final Staff chef;
  final RecordingProtocolSaver saver;

  /// Der nachgebaute A-Trust aus `open(atrust: …)`, sonst null.
  final FakeAtrust? atrust;

  /// Der Sitzungshalter am Testsystem über [atrust] oder `atrustClient`
  /// (mit [secrets] und [clock]), sonst null.
  final AtrustSessionKeeper? keeper;

  /// Der Sitzungshalter am echten System über [atrust] (nur mit dem
  /// nachgebauten A-Trust, nie mit `atrustClient`): wie in der App mit den
  /// Zugangsdaten aus [secrets], bei jeder Anmeldung neu gelesen, und dem
  /// Kennzeichen "abgelehnt" des echten Systems. Sonst null.
  final AtrustSessionKeeper? liveKeeper;

  /// Der nachgebaute Kartenleser aus `open(card: …)`, sonst null. Die Karte
  /// darin lässt sich ziehen (`card.removed`) oder tauschen.
  final FakeCardReader? cardReader;

  /// Der PIN-Wächter des Halters aus `open(card: …)`, sonst null.
  final MemoryPinGuard? pinGuard;

  /// Der Halter der Karte über [cardReader] (mit [secrets] und [pinGuard]),
  /// sonst null.
  final CardSigner? cardSigner;

  /// Gesetzt: Das Bauen der Einheit einer Kette mit Karte wirft dies, wie ein
  /// unerwarteter Fehler.
  Object? cardUnitError;

  /// Ohne [probeUnit] signiert jede Kette mit der Attrappe; deren Zertifikat
  /// steht dafür in `rksv_certificates`. Mit [probeUnit] signiert die
  /// Probe-Signatur wie in der App ([probeSignatureUnitOf]).
  ///
  /// Ohne [probeUnit] trägt die Kette nach `enableProbe` die Seriennummer des
  /// Probe-Zertifikats, signiert wird aber mit dem der Attrappe. Ein
  /// Ausfall-Eintrag ohne Frage an die Signatur (`trySign: false`) bekommt
  /// deshalb die Seriennummer der Kette und im Protokoll eine eigene Gruppe.
  /// In der App ist beides dasselbe Zertifikat.
  ///
  /// Mit [unitOf] baut das Journal seine Einheiten damit (etwa
  /// [signatureUnitOf] mit einer Online-Einheit an [FakeAtrust]).
  ///
  /// Mit [atrust] signiert das Journal wie in der App ([signatureUnitOf]):
  /// Probe-Ketten mit der Probe-Signatur, Ketten `atrustTest` mit einer
  /// [OnlineSignatureUnit] am Testsystem über [atrust] und [keeper], Ketten
  /// `atrust` mit einer am echten System über [atrust] und [liveKeeper]
  /// (angesprochen wird nur der nachgebaute A-Trust).
  ///
  /// [atrustClient] statt [atrust]: dasselbe über diesen Client, etwa den
  /// echten gegen das Testsystem (`atrust_testsystem_test.dart`). Eine Kette
  /// `atrust` ist dann ein [StateError]: Der echte Client spräche sonst mit
  /// dem echten System.
  ///
  /// Mit [card] steckt diese Karte in [cardReader], und das Journal signiert
  /// wie in der App ([signatureUnitOf]): Ketten `cardTest` und `card` mit
  /// einer [CardSignatureUnit] über [cardSigner], Probe-Ketten mit der
  /// Probe-Signatur, Online-Ketten nur zusammen mit [atrust] oder
  /// [atrustClient] (sonst [StateError]). [wrapCardReader] legt einen
  /// eigenen Leser um den nachgebauten, den der Halter dann benutzt.
  static Future<RksvRig> open({
    bool probeUnit = false,
    SignatureUnitOf Function(KassaDatabase db, RksvSecrets secrets)? unitOf,
    FakeAtrust? atrust,
    http.Client? atrustClient,
    FakeCard? card,
    ReaderTransport Function(FakeCardReader reader)? wrapCardReader,
  }) async {
    assert(atrust == null || atrustClient == null);
    final online = atrustClient ?? atrust?.client;
    assert(unitOf == null || (online == null && card == null));
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
    final secrets = RigSecrets();
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
    final keeper = online == null
        ? null
        : AtrustSessionKeeper(
            client: AtrustClient(online, AtrustSystem.test),
            credentials: () async =>
                const AtrustCredentials(atrustTestUser, atrustTestPassword),
            secrets: secrets,
            clock: clock,
          );
    final liveKeeper = atrust == null
        ? null
        : AtrustSessionKeeper(
            client: AtrustClient(atrust.client, AtrustSystem.live),
            credentials: secrets.atrustCredentials,
            secrets: secrets,
            clock: clock,
            live: true,
          );
    final cardReader = card == null ? null : FakeCardReader(card: card);
    final pinGuard = card == null ? null : MemoryPinGuard();
    final cardSigner = cardReader == null
        ? null
        : CardSigner(
            transport: wrapCardReader == null
                ? cardReader
                : wrapCardReader(cardReader),
            secrets: secrets,
            guard: pinGuard!,
          );
    // Das Rig selbst, sobald es steht (für [cardUnitError]).
    RksvRig? self;
    final journal = RksvJournal(
      db,
      secrets,
      unitOf != null
          ? unitOf(db, secrets)
          : online != null || cardSigner != null
          ? signatureUnitOf(
              db,
              secrets,
              online: (chain, cert) async {
                if (online == null) {
                  throw StateError('A-Trust gibt es hier nicht.');
                }
                final live = chain.unit == RksvUnit.atrust.name;
                if (live && liveKeeper == null) {
                  throw StateError('Das echte System gibt es hier nicht.');
                }
                return OnlineSignatureUnit(
                  client: AtrustClient(
                    online,
                    live ? AtrustSystem.live : AtrustSystem.test,
                  ),
                  keeper: live ? liveKeeper! : keeper!,
                  zdaId: chain.zdaId,
                  certificateDer: cert.certificate,
                  issuerCertificatesDer: [
                    for (final i in issuersBase64(cert)) base64.decode(i),
                  ],
                );
              },
              card: (chain, cert) async {
                final error = self?.cardUnitError;
                if (error != null) throw error;
                if (cardSigner == null) {
                  throw StateError('Eine Karte gibt es hier nicht.');
                }
                return CardSignatureUnit(
                  signer: cardSigner,
                  zdaId: chain.zdaId,
                  certificateDer: cert.certificate,
                );
              },
            )
          : probeUnit
          ? probeSignatureUnitOf(db, secrets)
          : (_) async => fake,
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
    return self = RksvRig._(
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
      atrust,
      keeper,
      liveKeeper,
      cardReader,
      pinGuard,
      cardSigner,
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

  /// Setzt den Zustand `live` direkt in die Datenbank, ohne A-Trust und ohne
  /// Startbeleg (signiert wird mit der Attrappe; den Weg der App geht
  /// [seedLive]): Kette 1 mit der Kassen-Kennung `LIVETEST01`,
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

  /// Setzt eine laufende Online-Probe direkt in die Datenbank (den Weg der
  /// App dorthin baut erst ein späterer Schritt): das Zertifikat von [atrust]
  /// mit seinen Ausstellern, Kette 1 mit der Einheit `atrustTest`, dem Modus
  /// `probe`, der Kennung `AT1` und der Kassen-Kennung `ONLINETEST`, dazu
  /// der AES-Schlüssel aus den Bytes 0 bis 31. Ohne Startbeleg.
  Future<void> startAtrustTest(FakeAtrust atrust) async {
    await secrets.writeAesKey(
      1,
      Uint8List.fromList(List.generate(32, (i) => i)),
    );
    await db
        .into(db.rksvCertificateRows)
        .insert(
          RksvCertificateRowsCompanion.insert(
            serialHex: '2159b9f6',
            certificate: atrust.certificateDer,
            issuers: Value(
              jsonEncode([for (final i in atrust.issuersDer) base64.encode(i)]),
            ),
          ),
        );
    await db
        .into(db.rksvChainRows)
        .insert(
          RksvChainRowsCompanion.insert(
            chain: const Value(1),
            mode: 'probe',
            unit: const Value('atrustTest'),
            cashBoxId: 'ONLINETEST',
            zdaId: 'AT1',
            certSerial: '2159b9f6',
            startedAt: clock.now(),
          ),
        );
    await (db.update(db.rksvStateRows)..where((t) => t.id.equals(1))).write(
      const RksvStateRowsCompanion(mode: Value('probe'), chain: Value(1)),
    );
  }

  /// Die Kassen-Kennung der Kette `card` aus [startCardChain].
  static const cardCashBoxId = 'BSPIMBKARTE';

  /// Was "Karte prüfen" über die Karte in [cardReader] weiß (braucht
  /// `open(card: …)`): Kartenart, Kartennummer, Zertifikat und Seriennummer.
  CardFacts cardFacts() {
    final card =
        cardReader?.card ?? (throw StateError('cardFacts braucht eine Karte.'));
    final certificate = CardCertificate.parse(card.certificate);
    return CardFacts(
      kind: card.profile.kind.name,
      numberHex: compactHex(card.number),
      certificateDer: certificate.der,
      serialHex: certificate.serial.toRadixString(16),
    );
  }

  /// Speichert die PIN der Karte in [cardReader] für deren Kartenart und
  /// Kartennummer, wie es "Karte und PIN" nach der Probe-Unterschrift tut.
  /// Mit [pin] eine andere (etwa eine falsche).
  Future<void> storeCardPin({String? pin}) async {
    final card =
        cardReader?.card ??
        (throw StateError('storeCardPin braucht eine Karte.'));
    await secrets.writeCardPin(
      CardPin(
        kind: card.profile.kind.name,
        numberHex: compactHex(card.number),
        pin: pin ?? card.pin,
      ),
    );
  }

  /// Startet eine Kette mit Karte über den Weg der App (braucht
  /// `open(card: …)`): die PIN der Karte im geschützten Speicher
  /// ([storeCardPin]), dann bei [RksvUnit.cardTest]
  /// [RksvService.enableCardProbe], bei [RksvUnit.card]
  /// [RksvService.prepareCardSetup], [RksvService.changeCashBoxId] auf
  /// [cardCashBoxId] und [RksvService.goLiveWithCard]. Den Startbeleg
  /// signiert die Karte. Liefert die Nummer der Kette.
  Future<int> startCardChain({RksvUnit unit = RksvUnit.card}) async {
    await storeCardPin();
    final facts = cardFacts();
    switch (unit) {
      case RksvUnit.cardTest:
        await service.enableCardProbe(staff: chef, facts: facts);
      case RksvUnit.card:
        await service.prepareCardSetup(facts: facts);
        await service.changeCashBoxId(cardCashBoxId);
        await service.goLiveWithCard(staff: chef, facts: facts);
      case RksvUnit.probe || RksvUnit.atrustTest || RksvUnit.atrust:
        throw ArgumentError.value(unit, 'unit');
    }
    return (await stateRow()).chain!;
  }

  /// Die Kassen-Kennung der Kette aus [seedLive].
  static const liveCashBoxId = 'BSPIMBECHT';

  /// Die Zugangsdaten, die [seedLive] speichert (erfunden).
  static const liveCredentials = AtrustCredentials(
    'u-beispiel',
    'geheim-beispiel',
  );

  /// Die Angaben von "Verbindung prüfen" am echten System, wie sie die App
  /// bekommt: der echte Lauf von [ConnectionCheck] mit [AtrustSystem.live],
  /// aber gegen einen eigenen nachgebauten A-Trust mit gültigem Zertifikat
  /// (Schlüssel und Seriennummer wie [atrust], also passen dessen
  /// Signaturen dazu) und einem eigenen Halter. In [atrust] erscheint keine
  /// Anfrage, und der Halter der Bons bleibt ohne Sitzung.
  Future<ConnectionFacts> liveFacts() async {
    final checked = FakeAtrust(validFrom: DateTime.utc(2020, 6, 1));
    final client = AtrustClient(checked.client, AtrustSystem.live);
    final result = await ConnectionCheck(
      client: client,
      keeper: AtrustSessionKeeper(
        client: client,
        credentials: () async => liveCredentials,
        secrets: MemoryRksvSecrets(),
        clock: clock,
        live: true,
      ),
      user: () async => liveCredentials.user,
      clock: clock,
    ).run(chefTapped: false);
    return result.facts ??
        (throw StateError('Verbindung prüfen ist gescheitert.'));
  }

  /// Nimmt die Kassa am nachgebauten A-Trust in Betrieb (braucht
  /// `open(atrust: …)`), über den Weg der App: [liveCredentials] im
  /// geschützten Speicher, ein PendingSetup mit der Kassen-Kennung
  /// [liveCashBoxId] und dem AES-Schlüssel aus den Bytes 0 bis 31 (damit
  /// Bons und Ausdrucke feste Werte zeigen), dann
  /// [RksvService.prepareSetup] und [RksvService.goLive] mit [liveFacts].
  /// Läuft eine Probe, endet sie dabei mit Schlussbeleg; den Startbeleg
  /// signiert A-Trust über [liveKeeper]. Liefert die Nummer der Kette.
  Future<int> seedLive() async {
    if (atrust == null) throw StateError('seedLive braucht open(atrust: …).');
    await secrets.writeAtrustCredentials(liveCredentials);
    await secrets.writePendingSetup(
      PendingSetup(
        cashBoxId: liveCashBoxId,
        aesKey: Uint8List.fromList(List.generate(32, (i) => i)),
      ),
    );
    final facts = await liveFacts();
    await service.prepareSetup(facts: facts);
    await service.goLive(staff: chef, facts: facts);
    return (await stateRow()).chain!;
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
      expect(f[1], 'R1-${chainRow.zdaId}', reason: at);
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
