// Probe-Signatur und Online-Probe ein- und ausschalten, Angaben für
// FinanzOnline, Inbetriebnahme und Außerbetriebnahme, Nullbeleg, "Nochmal
// prüfen", "Protokoll ausgeben".

import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../core/clock.dart';
import '../core/enums.dart';
import '../data/database.dart';
import '../data/receipt_repository.dart';
import '../domain/receipt.dart';
import '../domain/staff.dart';
import 'dep_export.dart';
import 'online/atrust_client.dart';
import 'online/connection_check.dart';
import 'probe_signature_unit.dart';
import 'rksv_secrets.dart';
import 'rksv_state.dart';
import 'setup_facts.dart';
import 'signature_unit.dart';

/// Etwas, das der Chef wissen muss; [message] ist ein deutscher Satz ohne
/// Geheimnisse.
final class RksvProblem implements Exception {
  const RksvProblem(this.message);
  final String message;

  @override
  String toString() => 'RksvProblem: $message';
}

const _storageProblem =
    'Das Tablet konnte den Schlüssel nicht sicher speichern.';
const _enableProblem = 'Die Probe-Signatur konnte nicht eingeschaltet werden.';
const _goLiveProblem = 'Die Kassa konnte nicht in Betrieb genommen werden.';
const _notRunning = 'Die Signatur ist nicht eingeschaltet.';
const _noProtocol = 'Es gibt noch kein Protokoll.';
const _storageReadProblem = 'Das Tablet konnte den Schlüssel nicht lesen.';

/// Zeichen der Kassen-Kennung: ohne I, O, 0 und 1, damit sie sich sicher
/// abschreiben lässt.
const _cashBoxIdAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

class RksvService {
  RksvService(
    this._db,
    this._secrets,
    this._receipts,
    this._clock, {
    Random? random,
    this._saver = const FilePickerProtocolSaver(),
  }) : _random = random ?? Random.secure();

  final KassaDatabase _db;
  final RksvSecrets _secrets;
  final ReceiptRepository _receipts;
  final Clock _clock;
  final Random _random;
  final ProtocolSaver _saver;

  /// Neue Kette: Kassen-Kennung, AES-Schlüssel, Probe-Schlüssel und
  /// Zertifikat erzeugen, Startbeleg signieren. Wirft RksvProblem, wenn der
  /// geschützte Speicher nicht schreibt, die Signatur scheitert oder sonst
  /// etwas schiefgeht; dann bleibt alles wie vorher. Ein alter Hinweis geht
  /// weg. Läuft die Signatur schon: [StateError].
  Future<Receipt> enableProbe({required Staff staff}) {
    // Alles in einer Transaktion, auch das Schreiben der Schlüssel: Ein
    // zweiter Aufruf zugleich wartet und sieht dann die laufende Probe, statt
    // die Schlüssel derselben Kette zu überschreiben.
    return _db.transaction(() async {
      final state = await _state();
      if (enumByNameOr(RksvMode.values, state.mode, RksvMode.off) !=
          RksvMode.off) {
        throw StateError('Die Signatur läuft schon.');
      }
      try {
        return await _startChain(staff);
      } on RksvProblem {
        rethrow;
      } on SignatureFailure catch (e) {
        throw RksvProblem(e.reason);
      } on Object {
        // Alles andere (etwa ein Speicher, der beim Startbeleg wirft): Die
        // Transaktion rollt alles zurück.
        throw const RksvProblem(_enableProblem);
      }
    });
  }

  /// Online-Probe (Entwurf 6.5): neue Kette am Testsystem von A-Trust mit
  /// Kennung und Zertifikat aus [facts], Startbeleg von A-Trust signiert
  /// (P3: in der Transaktion, mit der Frist des Journals; sonst fragt hier
  /// nichts bei A-Trust). Fehler wie bei [enableProbe]: RksvProblem, scheitert
  /// die Signatur mit dem Satz der Einheit, und nichts bleibt zurück. Läuft
  /// die Signatur schon, oder stammen [facts] nicht vom Testsystem:
  /// [StateError].
  Future<Receipt> enableOnlineProbe({
    required Staff staff,
    required ConnectionFacts facts,
  }) {
    return _db.transaction(() async {
      // Testsystem heißt Testbon (Plan, Global Constraints).
      if (facts.system != AtrustSystem.test) {
        throw StateError('Die Online-Probe läuft nur am Testsystem.');
      }
      final state = await _state();
      if (enumByNameOr(RksvMode.values, state.mode, RksvMode.off) !=
          RksvMode.off) {
        throw StateError('Die Signatur läuft schon.');
      }
      try {
        return await _startOnlineChain(staff, facts);
      } on RksvProblem {
        rethrow;
      } on SignatureFailure catch (e) {
        throw RksvProblem(e.reason);
      } on Object {
        throw const RksvProblem(_enableProblem);
      }
    });
  }

  Future<Receipt> _startChain(Staff staff) async {
    final chain = await _nextChain();
    final cashBoxId = _newCashBoxId();
    final aesKey = _newAesKey();
    final now = _clock.now();
    final probe = ProbeSignatureUnit.create(
      cashBoxId: cashBoxId,
      now: now,
      random: _random,
    );
    await _storeSecrets(chain, aesKey, probe.privateKey);

    await _db
        .into(_db.rksvCertificateRows)
        .insert(
          RksvCertificateRowsCompanion.insert(
            serialHex: probe.serialHex,
            certificate: probe.certificateDer,
          ),
        );
    await _db
        .into(_db.rksvChainRows)
        .insert(
          RksvChainRowsCompanion.insert(
            chain: Value(chain),
            mode: RksvMode.probe.name,
            cashBoxId: cashBoxId,
            zdaId: 'AT100',
            certSerial: probe.serialHex,
            startedAt: now,
          ),
        );
    return _startReceipt(chain, staff);
  }

  Future<Receipt> _startOnlineChain(Staff staff, ConnectionFacts facts) async {
    final chain = await _nextChain();
    final cashBoxId = _newCashBoxId();
    final aesKey = _newAesKey();
    final certificate = facts.certificate;
    await _storeSecrets(chain, aesKey);

    // Eine zweite Online-Probe mit demselben Zertifikat findet die Zeile
    // schon vor; sie bleibt, wie sie ist.
    await _db
        .into(_db.rksvCertificateRows)
        .insert(
          RksvCertificateRowsCompanion.insert(
            serialHex: certificate.serialHex,
            certificate: certificate.certificateDer,
            issuers: Value(
              jsonEncode([
                for (final i in certificate.issuersDer) base64.encode(i),
              ]),
            ),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await _db
        .into(_db.rksvChainRows)
        .insert(
          RksvChainRowsCompanion.insert(
            chain: Value(chain),
            mode: RksvMode.probe.name,
            unit: Value(RksvUnit.atrustTest.name),
            cashBoxId: cashBoxId,
            zdaId: facts.zdaId,
            certSerial: certificate.serialHex,
            startedAt: _clock.now(),
          ),
        );
    return _startReceipt(chain, staff);
  }

  Future<int> _nextChain() async {
    final highest = _db.rksvChainRows.chain.max();
    return (await (_db.selectOnly(
              _db.rksvChainRows,
            )..addColumns([highest])).map((r) => r.read(highest)).getSingle() ??
            0) +
        1;
  }

  String _newCashBoxId() => String.fromCharCodes([
    for (var i = 0; i < 10; i++)
      _cashBoxIdAlphabet.codeUnitAt(_random.nextInt(_cashBoxIdAlphabet.length)),
  ]);

  Uint8List _newAesKey() =>
      Uint8List.fromList([for (var i = 0; i < 32; i++) _random.nextInt(256)]);

  /// Stand auf die neue Kette [chain] im Modus [mode], mit [tasks], wenn
  /// angegeben; dann ihr Startbeleg (muss signiert sein).
  Future<Receipt> _startReceipt(
    int chain,
    Staff staff, {
    RksvMode mode = RksvMode.probe,
    List<RksvTask>? tasks,
  }) async {
    await _writeState(
      RksvStateRowsCompanion(
        mode: Value(mode.name),
        chain: Value(chain),
        counterCents: const Value(0),
        outageSince: const Value(null),
        outageReason: const Value(null),
        notice: const Value(null),
        tasks: tasks == null
            ? const Value.absent()
            : Value(encodeRksvTasks(tasks)),
      ),
    );
    return _receipts.createSpecial(
      ReceiptKind.start,
      staff: staff,
      mustSign: true,
    );
  }

  /// Höchstens so lange wartet das Einschalten auf den geschützten Speicher.
  /// Es hält dabei die Datenbank, also warten auch die Verkäufe.
  static const storageLimit = Duration(seconds: 5);

  /// Schreibt den AES-Schlüssel und, wenn es einen gibt, den Probe-Schlüssel
  /// [probeKey] und liest sie zurück, zusammen höchstens [storageLimit] lang.
  Future<void> _storeSecrets(
    int chain,
    Uint8List aesKey, [
    Uint8List? probeKey,
  ]) async {
    bool same(Uint8List? a, Uint8List b) =>
        a != null && a.length == b.length && _equal(a, b);
    try {
      await () async {
        await _secrets.writeAesKey(chain, aesKey);
        if (probeKey != null) await _secrets.writeProbeKey(chain, probeKey);
        if (!same(await _secrets.aesKey(chain), aesKey) ||
            (probeKey != null &&
                !same(await _secrets.probeKey(chain), probeKey))) {
          throw const RksvProblem(_storageProblem);
        }
      }().timeout(storageLimit);
    } on RksvProblem {
      rethrow;
    } on Object {
      throw const RksvProblem(_storageProblem);
    }
  }

  static bool _equal(Uint8List a, Uint8List b) {
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Schlussbeleg, Kette beenden, mode off. Ohne laufende Probe:
  /// [StateError].
  Future<Receipt> disableProbe({required Staff staff}) {
    return _db.transaction(() async {
      final state = await _state();
      if (state.mode != RksvMode.probe.name || state.chain == null) {
        throw StateError('Die Probe-Signatur läuft nicht.');
      }
      return _closeProbe(staff);
    });
  }

  /// Die laufende Probe beenden: Schlussbeleg, Kette zu, mode off, ihre
  /// Aufgaben weg. In der Transaktion des Aufrufers.
  Future<Receipt> _closeProbe(Staff staff) async {
    final chain = (await _state()).chain!;
    final closing = await _receipts.createSpecial(
      ReceiptKind.closing,
      staff: staff,
    );
    // Hat sich die Probe beim Schlussbeleg selbst beendet (K9), ist die
    // Kette schon zu.
    await _endChain(chain);
    await _writeState(
      RksvStateRowsCompanion(
        mode: Value(RksvMode.off.name),
        chain: const Value(null),
        outageSince: const Value(null),
        outageReason: const Value(null),
        // Die Aufgaben gehören zur Probe und enden mit ihr.
        tasks: const Value('[]'),
      ),
    );
    return closing;
  }

  Future<void> _endChain(int chain) =>
      (_db.update(_db.rksvChainRows)
            ..where((t) => t.chain.equals(chain) & t.endedAt.isNull()))
          .write(RksvChainRowsCompanion(endedAt: Value(_clock.now())));

  // Nur ein "Angaben für FinanzOnline" zugleich: Zwei Aufrufe dürfen nicht
  // je ein PendingSetup anlegen, sonst zeigte einer überholte Werte.
  Future<void> _setupQueue = Future.value();

  /// "Angaben für FinanzOnline" (Entwurf 6.7, Schritt 3, Q2): Kassen-Kennung
  /// und AES-Schlüssel aus dem PendingSetup, sonst neue (wie bei der
  /// Online-Probe), die bis zur Inbetriebnahme im geschützten Speicher
  /// bleiben; dazu Kennung und Seriennummer aus [facts]. Schreibt nichts in
  /// die Datenbank. Liest oder schreibt der geschützte Speicher nicht:
  /// [RksvProblem], und ein vorhandenes PendingSetup bleibt, wie es ist.
  /// Stammen [facts] nicht vom echten System oder ist die Kassa schon in
  /// Betrieb: [StateError].
  Future<SetupFacts> prepareSetup({required ConnectionFacts facts}) {
    final done = _setupQueue.then((_) => _prepareSetup(facts));
    _setupQueue = done.then<void>((_) {}, onError: (Object _) {});
    return done;
  }

  Future<SetupFacts> _prepareSetup(ConnectionFacts facts) async {
    if (facts.system != AtrustSystem.live) {
      throw StateError('Die Angaben gibt es nur am echten System.');
    }
    if (await _mode() == RksvMode.live) {
      throw StateError('Die Kassa ist schon in Betrieb.');
    }
    var setup = await _readPendingSetup();
    if (setup == null) {
      final fresh = PendingSetup(
        cashBoxId: _newCashBoxId(),
        aesKey: _newAesKey(),
      );
      try {
        await () async {
          await _secrets.writePendingSetup(fresh);
          final back = await _secrets.pendingSetup();
          if (back == null ||
              back.cashBoxId != fresh.cashBoxId ||
              back.aesKey.length != fresh.aesKey.length ||
              !_equal(back.aesKey, fresh.aesKey)) {
            throw const RksvProblem(_storageProblem);
          }
        }().timeout(storageLimit);
      } on Object {
        throw const RksvProblem(_storageProblem);
      }
      setup = fresh;
    }
    return setupFactsOf(
      zdaId: facts.zdaId,
      certSerialHex: facts.certificate.serialHex,
      cashBoxId: setup.cashBoxId,
      aesKey: setup.aesKey,
    );
  }

  /// Das PendingSetup, höchstens [storageLimit] lang gelesen; null auch,
  /// wenn eine Kette schon seine Kassen-Kennung trägt (das Löschen nach der
  /// Inbetriebnahme ist gescheitert): Eine Kennung gehört zu genau einer
  /// Kette. Scheitert das Lesen: [RksvProblem].
  Future<PendingSetup?> _readPendingSetup() async {
    final PendingSetup? setup;
    try {
      setup = await _secrets.pendingSetup().timeout(storageLimit);
    } on Object {
      throw const RksvProblem(_storageReadProblem);
    }
    if (setup == null) return null;
    final used = await (_db.select(
      _db.rksvChainRows,
    )..where((t) => t.cashBoxId.equals(setup!.cashBoxId))).get();
    return used.isEmpty ? setup : null;
  }

  /// "Jetzt in Betrieb nehmen" (Entwurf 6.7, Schritt 5, Q7), eine einzige
  /// Transaktion: Läuft eine Probe, endet sie mit Schlussbeleg (wie
  /// [disableProbe]). Dann neue Kette `live` am echten System mit
  /// Kassen-Kennung und AES-Schlüssel aus dem PendingSetup und Kennung und
  /// Zertifikat aus [facts], Stand `live`, Aufgaben "Bei FinanzOnline
  /// anmelden" (bis heute plus 7 Tage) und "Startbeleg prüfen", Startbeleg
  /// von A-Trust signiert. Danach kennt das Journal den AES-Schlüssel (Q17),
  /// und das PendingSetup wird gelöscht (scheitert das, ohne Folgen).
  ///
  /// Scheitert etwas, bleibt alles wie vorher, auch die Probe und das
  /// PendingSetup: [RksvProblem] mit dem Satz der Einheit, sonst einem
  /// allgemeinen. Stammen [facts] nicht vom echten System, fehlt das
  /// PendingSetup oder ist die Kassa schon in Betrieb: [StateError], ohne
  /// eine Anfrage an A-Trust.
  Future<Receipt> goLive({
    required Staff staff,
    required ConnectionFacts facts,
  }) async {
    final journal =
        _receipts.journal ??
        (throw StateError('Ohne Journal gibt es keinen echten Betrieb.'));
    int? chain;
    late Uint8List aesKey;
    final Receipt start;
    try {
      start = await _db.transaction(() async {
        // Echt heißt echt (Plan, Global Constraints).
        if (facts.system != AtrustSystem.live) {
          throw StateError('Die Inbetriebnahme läuft nur am echten System.');
        }
        final mode = await _mode();
        if (mode == RksvMode.live) {
          throw StateError('Die Kassa ist schon in Betrieb.');
        }
        final setup =
            await _readPendingSetup() ??
            (throw StateError('Es gibt keine Angaben für FinanzOnline.'));
        aesKey = setup.aesKey;
        try {
          if (mode == RksvMode.probe) await _closeProbe(staff);
          chain = await _nextChain();
          return await _startLiveChain(chain!, staff, facts, setup);
        } on RksvProblem {
          rethrow;
        } on SignatureFailure catch (e) {
          throw RksvProblem(e.reason);
        } on Object {
          throw const RksvProblem(_goLiveProblem);
        }
      });
    } on Object {
      // Die Kette gibt es nicht; ihr Schlüssel darf keiner späteren Kette
      // mit derselben Nummer bleiben.
      final c = chain;
      if (c != null) journal.forgetLiveKey(c);
      rethrow;
    }
    journal.rememberLiveKey(chain!, aesKey);
    try {
      await _secrets.writePendingSetup(null).timeout(storageLimit);
    } on Object {
      // Ohne Folgen: Ein PendingSetup, dessen Kennung eine Kette trägt,
      // gilt als keins (_readPendingSetup).
    }
    return start;
  }

  Future<Receipt> _startLiveChain(
    int chain,
    Staff staff,
    ConnectionFacts facts,
    PendingSetup setup,
  ) async {
    final certificate = facts.certificate;
    await _storeSecrets(chain, setup.aesKey);
    // Dasselbe Zertifikat aus einer früheren Kette bleibt, wie es ist.
    await _db
        .into(_db.rksvCertificateRows)
        .insert(
          RksvCertificateRowsCompanion.insert(
            serialHex: certificate.serialHex,
            certificate: certificate.certificateDer,
            issuers: Value(
              jsonEncode([
                for (final i in certificate.issuersDer) base64.encode(i),
              ]),
            ),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    final now = _clock.now();
    await _db
        .into(_db.rksvChainRows)
        .insert(
          RksvChainRowsCompanion.insert(
            chain: Value(chain),
            mode: RksvMode.live.name,
            unit: Value(RksvUnit.atrust.name),
            cashBoxId: setup.cashBoxId,
            zdaId: facts.zdaId,
            certSerial: certificate.serialHex,
            startedAt: now,
          ),
        );
    // "Startbeleg prüfen" legt das Journal mit dem Startbeleg an.
    return _startReceipt(
      chain,
      staff,
      mode: RksvMode.live,
      tasks: [
        ...decodeRksvTasks((await _state()).tasks),
        RksvTask(
          id: 'register-finanzonline-$chain',
          kind: RksvTaskKind.registerFinanzOnline,
          createdAt: now,
          detail: _inAWeek(now),
        ),
      ],
    );
  }

  /// "Kassa außer Betrieb nehmen" (Q8): Schlussbeleg (im Ausfall mit dem
  /// Vermerk), Kette beenden, mode off, Ausfall gelöscht. Die offenen
  /// Aufgaben bleiben, dazu "Außerbetriebnahme melden" (bis heute plus 7
  /// Tage) und, wenn nicht schon offen, "Protokoll sichern" (Q15). Nicht in
  /// Betrieb: [StateError].
  Future<Receipt> decommission({required Staff staff}) {
    return _db.transaction(() async {
      final state = await _state();
      final chain = state.chain;
      if (state.mode != RksvMode.live.name || chain == null) {
        throw StateError('Die Kassa ist nicht in Betrieb.');
      }
      final closing = await _receipts.createSpecial(
        ReceiptKind.closing,
        staff: staff,
      );
      await _endChain(chain);
      final now = _clock.now();
      final tasks = decodeRksvTasks((await _state()).tasks);
      await _writeState(
        RksvStateRowsCompanion(
          mode: Value(RksvMode.off.name),
          chain: const Value(null),
          outageSince: const Value(null),
          outageReason: const Value(null),
          tasks: Value(
            encodeRksvTasks([
              ...tasks,
              RksvTask(
                id: 'report-decommission-$chain',
                kind: RksvTaskKind.reportDecommission,
                createdAt: now,
                detail: _inAWeek(now),
              ),
              if (!tasks.any((t) => t.kind == RksvTaskKind.backupProtocol))
                RksvTask(
                  id: 'backup-decommission-$chain',
                  kind: RksvTaskKind.backupProtocol,
                  createdAt: now,
                ),
            ]),
          ),
        ),
      );
      return closing;
    });
  }

  /// Der Tag eine Woche nach [now], `25.11.2026`.
  static String _inAWeek(DateTime now) {
    final d = DateTime(now.year, now.month, now.day + 7);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  /// Nullbeleg, auf Wunsch des Chefs (gedruckt wird er vom Bildschirm).
  /// Ohne laufende Signatur: [RksvProblem].
  Future<Receipt> zeroReceipt({required Staff staff}) {
    return _db.transaction(() async {
      final state = await _state();
      if (enumByNameOr(RksvMode.values, state.mode, RksvMode.off) ==
          RksvMode.off) {
        throw const RksvProblem(_notRunning);
      }
      return _receipts.createSpecial(ReceiptKind.zero, staff: staff);
    });
  }

  /// "Nochmal prüfen": versucht den Sammelbeleg. true, wenn die Signatur
  /// wieder geht (der Sammelbeleg ist geschrieben, der Ausfall zu Ende);
  /// false ohne Ausfall oder wenn sie noch nicht geht, dann ohne Änderung.
  Future<bool> retrySignature({required Staff staff}) =>
      _receipts.retryCollective(staff: staff);

  /// "Protokoll ausgeben" (Q15): die laufende Kette, wenn sie `live` ist;
  /// sonst die jüngste beendete Kette `live`, wenn es eine gibt; sonst die
  /// laufende, sonst die zuletzt beendete Kette. Im Zeitraum [range]
  /// (Vierteljahre von [now] aus, Ortszeit). Ohne Kette: [RksvProblem]. Ohne
  /// Eintrag im Zeitraum: [ExportOutcome.empty], dann öffnet sich kein
  /// Fenster.
  Future<ExportOutcome> exportProtocol(
    ExportRange range, {
    required DateTime now,
  }) async {
    final state = await _state();
    final running = state.chain;
    final current = running == null
        ? null
        : await (_db.select(
            _db.rksvChainRows,
          )..where((t) => t.chain.equals(running))).getSingleOrNull();
    Future<RksvChainRow?> latestEnded({bool liveOnly = false}) =>
        (_db.select(_db.rksvChainRows)
              ..where(
                (t) => liveOnly
                    ? t.endedAt.isNotNull() & t.mode.equals(RksvMode.live.name)
                    : t.endedAt.isNotNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.chain)])
              ..limit(1))
            .getSingleOrNull();
    final chain = current?.mode == RksvMode.live.name
        ? current
        : await latestEnded(liveOnly: true) ?? current ?? await latestEnded();
    if (chain == null) throw const RksvProblem(_noProtocol);

    final quarter = DateTime(now.year, now.month - (now.month - 1) % 3);
    final (from, until) = switch (range) {
      ExportRange.all => (null, null),
      ExportRange.thisQuarter => (
        quarter,
        DateTime(quarter.year, quarter.month + 3),
      ),
      ExportRange.lastQuarter => (
        DateTime(quarter.year, quarter.month - 3),
        quarter,
      ),
    };
    final text = await buildDepExport(
      _db,
      chain: chain.chain,
      from: from,
      until: until,
    );
    final groups =
        (jsonDecode(text) as Map<String, dynamic>)['Belege-Gruppe'] as List;
    if (groups.isEmpty) return ExportOutcome.empty;
    final saved = await _saver.save(
      depFileName(
        cashBoxId: chain.cashBoxId,
        probe: chain.mode == RksvMode.probe.name,
        now: now,
      ),
      Uint8List.fromList(utf8.encode(text)),
    );
    return saved ? ExportOutcome.saved : ExportOutcome.cancelled;
  }

  Future<RksvMode> _mode() async =>
      enumByNameOr(RksvMode.values, (await _state()).mode, RksvMode.off);

  Future<RksvStateRow> _state() =>
      (_db.select(_db.rksvStateRows)..where((t) => t.id.equals(1))).getSingle();

  Future<void> _writeState(RksvStateRowsCompanion c) =>
      (_db.update(_db.rksvStateRows)..where((t) => t.id.equals(1))).write(c);
}
