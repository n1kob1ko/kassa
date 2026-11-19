// Probe-Signatur und Online-Probe ein- und ausschalten, Nullbeleg,
// "Nochmal prüfen", "Protokoll ausgeben".

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
const _notRunning = 'Die Signatur ist nicht eingeschaltet.';
const _noProtocol = 'Es gibt noch kein Protokoll.';

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

  /// Stand auf die neue Kette [chain], dann ihr Startbeleg (muss signiert
  /// sein).
  Future<Receipt> _startReceipt(int chain, Staff staff) async {
    await _writeState(
      RksvStateRowsCompanion(
        mode: Value(RksvMode.probe.name),
        chain: Value(chain),
        counterCents: const Value(0),
        outageSince: const Value(null),
        outageReason: const Value(null),
        notice: const Value(null),
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
      final chain = state.chain;
      if (state.mode != RksvMode.probe.name || chain == null) {
        throw StateError('Die Probe-Signatur läuft nicht.');
      }
      final closing = await _receipts.createSpecial(
        ReceiptKind.closing,
        staff: staff,
      );
      // Hat sich die Probe beim Schlussbeleg selbst beendet (K9), ist die
      // Kette schon zu.
      await (_db.update(_db.rksvChainRows)
            ..where((t) => t.chain.equals(chain) & t.endedAt.isNull()))
          .write(RksvChainRowsCompanion(endedAt: Value(_clock.now())));
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
    });
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

  /// "Protokoll ausgeben": die laufende Kette, sonst die zuletzt beendete,
  /// im Zeitraum [range] (Vierteljahre von [now] aus, Ortszeit). Ohne Kette:
  /// [RksvProblem]. Ohne Eintrag im Zeitraum: [ExportOutcome.empty], dann
  /// öffnet sich kein Fenster.
  Future<ExportOutcome> exportProtocol(
    ExportRange range, {
    required DateTime now,
  }) async {
    final state = await _state();
    final running = state.chain;
    final chain = running != null
        ? await (_db.select(
            _db.rksvChainRows,
          )..where((t) => t.chain.equals(running))).getSingleOrNull()
        : await (_db.select(_db.rksvChainRows)
                ..where((t) => t.endedAt.isNotNull())
                ..orderBy([(t) => OrderingTerm.desc(t.chain)])
                ..limit(1))
              .getSingleOrNull();
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

  Future<RksvStateRow> _state() =>
      (_db.select(_db.rksvStateRows)..where((t) => t.id.equals(1))).getSingle();

  Future<void> _writeState(RksvStateRowsCompanion c) =>
      (_db.update(_db.rksvStateRows)..where((t) => t.id.equals(1))).write(c);
}
