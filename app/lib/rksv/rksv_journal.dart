// Der Schritt je Bon (RKSV): Zähler und Kettenwert rechnen, den Code
// signieren lassen, Eintrag und Zählerstand schreiben. Läuft in der
// Transaktion des Bons.

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/clock.dart';
import '../core/enums.dart';
import '../data/database.dart';
import '../domain/receipt.dart';
import 'core/rksv_code.dart';
import 'probe_signature_unit.dart';
import 'rksv_secrets.dart';
import 'rksv_state.dart';
import 'signature_unit.dart';

/// Liefert die Signatur-Einheit einer Kette; in der App: Probe-Signatur aus
/// RksvSecrets und rksv_certificates.
typedef SignatureUnitOf = Future<SignatureUnit> Function(int chain);

/// Die Signatur-Einheit der App: bei einer Probe-Kette die Probe-Signatur mit
/// dem Schlüssel aus [secrets] und dem Zertifikat der Kette. Fehlt etwas, ist
/// das ein unerwarteter Fehler ([StateError]), kein Ausfall.
SignatureUnitOf probeSignatureUnitOf(KassaDatabase db, RksvSecrets secrets) =>
    (chain) async {
      final row = await (db.select(db.rksvChainRows).join([
        innerJoin(
          db.rksvCertificateRows,
          db.rksvCertificateRows.serialHex.equalsExp(
            db.rksvChainRows.certSerial,
          ),
        ),
      ])..where(db.rksvChainRows.chain.equals(chain))).getSingleOrNull();
      if (row == null) {
        throw StateError('Kette $chain oder ihr Zertifikat fehlt.');
      }
      if (row.readTable(db.rksvChainRows).mode != RksvMode.probe.name) {
        throw StateError('Kette $chain ist keine Probe-Kette.');
      }
      final key = await secrets.probeKey(chain);
      if (key == null) {
        throw StateError('Der Schlüssel der Probe-Signatur fehlt.');
      }
      return ProbeSignatureUnit(
        privateKey: key,
        certificateDer: row.readTable(db.rksvCertificateRows).certificate,
      );
    };

const _reasonSilent = 'Die Signatur hat nicht geantwortet.';
const _reasonError = 'Die Signatur hat einen Fehler gemeldet.';
const _notice =
    'Die Probe-Signatur wurde beendet, weil sie nicht mehr arbeiten konnte. '
    'Der Verkauf läuft normal weiter.';

/// Ergebnis eines Versuchs zu signieren.
typedef _Signed = ({String jws, String certSerial, String? failure});

class RksvJournal {
  RksvJournal(this._db, this._secrets, this._unitOf, this._clock);

  final KassaDatabase _db;
  final RksvSecrets _secrets;
  final SignatureUnitOf _unitOf;
  final Clock _clock;

  static const signLimit = Duration(seconds: 5);
  static const signLimitDuringOutage = Duration(seconds: 1);

  /// Wahr, solange die Signatur läuft (mode nicht off).
  Future<bool> isActive() async => _mode(await _state()) != RksvMode.off;

  /// Läuft in der Transaktion des Bons, nachdem seine Zeilen stehen. Tut
  /// nichts bei mode off.
  /// [mustSign]: kein Ausfall-Eintrag, sondern SignatureFailure (für
  /// Sammelbeleg und Startbeleg).
  Future<void> record({
    required String receiptId,
    required int number,
    required DateTime createdAt,
    required ReceiptKind kind,
    required List<int> sumsCents,
    bool mustSign = false,
  }) async {
    // 1. Zustand, Kette, letzter Eintrag.
    final state = await _state();
    if (_mode(state) == RksvMode.off) return;
    final chain =
        state.chain ?? (throw StateError('Die Signatur hat keine Kette.'));
    final chainRow = await _chainRow(chain);
    final last = await _lastEntry(chain);
    final aesKey =
        await _secrets.aesKey(chain) ??
        (throw StateError('Der AES-Schlüssel der Kette $chain fehlt.'));

    // 2. Zähler.
    final counter =
        state.counterCents + sumsCents.fold<int>(0, (a, b) => a + b);
    final counterField = kind == ReceiptKind.voided
        ? stornoCounterField
        : encryptCounter(
            aesKey: aesKey,
            cashBoxId: chainRow.cashBoxId,
            receiptId: '$number',
            counterCents: counter,
          );

    // 3. Kettenwert.
    final previous = chainValue(last?.jws ?? chainRow.cashBoxId);

    // 4. und 5. Signieren, bei Ausfall der Vermerk.
    String text(SignerInfo? info) => codeText(
      CodeFields(
        zdaId: info?.zdaId ?? chainRow.zdaId,
        cashBoxId: chainRow.cashBoxId,
        receiptId: '$number',
        time: createdAt,
        sumsCents: sumsCents,
        counterField: counterField,
        certSerial: info?.serialHex ?? chainRow.certSerial,
        chain: previous,
      ),
    );
    final signed = await _sign(
      await _unitOf(chain),
      text,
      limit: state.outageSince == null ? signLimit : signLimitDuringOutage,
      fallbackSerial: chainRow.certSerial,
      mustSign: mustSign,
    );

    // 6. Eintrag und Zähler.
    await _db
        .into(_db.rksvEntryRows)
        .insert(
          RksvEntryRowsCompanion.insert(
            chain: chain,
            position: (last?.position ?? 0) + 1,
            receiptId: receiptId,
            jws: signed.jws,
            damaged: signed.failure != null,
            certSerial: signed.certSerial,
          ),
        );
    final startsOutage = signed.failure != null && state.outageSince == null;
    final endsOutage = kind == ReceiptKind.collective;
    await _writeState(
      RksvStateRowsCompanion(
        counterCents: Value(counter),
        outageSince: endsOutage
            ? const Value(null)
            : startsOutage
            ? Value(_clock.now())
            : const Value.absent(),
        outageReason: endsOutage
            ? const Value(null)
            : startsOutage
            ? Value(signed.failure)
            : const Value.absent(),
      ),
    );

    // 7. Aufgaben: kommen mit den Sonderbelegen von selbst (Task 6).
  }

  /// Signiert den Text aus [text] innerhalb von [limit]. Bei
  /// [SignatureFailure] oder Fristablauf: mit [mustSign] eine
  /// [SignatureFailure], sonst der Ausfall-Vermerk. Eine Antwort nach der
  /// Frist wird verworfen. Andere Fehler gehen weiter.
  Future<_Signed> _sign(
    SignatureUnit unit,
    String Function(SignerInfo? info) text, {
    required Duration limit,
    required String fallbackSerial,
    required bool mustSign,
  }) async {
    SignerInfo? info;
    String failure;
    try {
      return await () async {
        final i = await unit.info();
        info = i;
        final t = text(i);
        final signature = await unit.sign(jwsSigningInput(t));
        return (
          jws: jwsCompact(t, signature),
          certSerial: i.serialHex,
          failure: null,
        );
      }().timeout(limit);
    } on SignatureFailure {
      if (mustSign) rethrow;
      failure = _reasonError;
    } on TimeoutException {
      if (mustSign) throw const SignatureFailure(_reasonSilent);
      failure = _reasonSilent;
    }
    final known = info;
    return (
      jws: jwsDamaged(text(known)),
      certSerial: known?.serialHex ?? fallbackSerial,
      failure: failure,
    );
  }

  /// Welcher Beleg vor einem Verkauf oder Storno fällig ist: collective (bei
  /// Ausfall), sonst year, month, oder null. In Task 5 liefert sie immer
  /// null; die Regeln kommen in Task 6.
  Future<ReceiptKind?> dueBefore(DateTime now) async => null;

  /// Darf der Bon [receiptId] storniert werden? Ohne Signatur immer, sonst
  /// nur, wenn er einen Eintrag in der laufenden Kette hat (K7).
  Future<bool> mayVoid(String receiptId) async {
    final state = await _state();
    if (_mode(state) == RksvMode.off) return true;
    final chain = state.chain;
    if (chain == null) return false;
    final entry =
        await (_db.select(_db.rksvEntryRows)..where(
              (t) => t.receiptId.equals(receiptId) & t.chain.equals(chain),
            ))
            .getSingleOrNull();
    return entry != null;
  }

  /// Nach einem unerwarteten Fehler im Schritt je Bon (K9): Läuft die Probe,
  /// endet sie mit einem Hinweis, und es kommt true zurück. Sonst ändert sich
  /// nichts und es kommt false zurück.
  Future<bool> endProbeAfterError() async {
    final state = await _state();
    if (_mode(state) != RksvMode.probe) return false;
    final chain = state.chain;
    if (chain != null) {
      await (_db.update(_db.rksvChainRows)
            ..where((t) => t.chain.equals(chain) & t.endedAt.isNull()))
          .write(RksvChainRowsCompanion(endedAt: Value(_clock.now())));
    }
    await _writeState(
      RksvStateRowsCompanion(
        mode: Value(RksvMode.off.name),
        chain: const Value(null),
        outageSince: const Value(null),
        outageReason: const Value(null),
        notice: const Value(_notice),
      ),
    );
    return true;
  }

  /// Prüft die laufende Kette gegen sich selbst (Kettenwerte, Zähler,
  /// Positionen). Für Tests und "Protokoll ausgeben".
  Future<bool> chainIsSound(int chain) async {
    try {
      final chainRow = await _chainRow(chain);
      final entries =
          await (_db.select(_db.rksvEntryRows)
                ..where((t) => t.chain.equals(chain))
                ..orderBy([(t) => OrderingTerm.asc(t.position)]))
              .get();
      final aesKey = await _secrets.aesKey(chain);
      if (aesKey == null) return false;
      var previous = chainValue(chainRow.cashBoxId);
      var counter = 0;
      for (var i = 0; i < entries.length; i++) {
        final e = entries[i];
        if (e.position != i + 1) return false;
        final parts = e.jws.split('.');
        if (parts.length != 3) return false;
        final fields = utf8
            .decode(base64Url.decode(base64Url.normalize(parts[1])))
            .split('_');
        if (fields.length != 13 || fields[2] != chainRow.cashBoxId) {
          return false;
        }
        if (fields[12] != previous) return false;
        counter += fields
            .sublist(5, 10)
            .map(_parseAmount)
            .fold<int>(0, (a, b) => a + b);
        if (fields[10] != stornoCounterField &&
            decryptCounter(
                  aesKey: aesKey,
                  cashBoxId: chainRow.cashBoxId,
                  receiptId: fields[3],
                  field: fields[10],
                ) !=
                counter) {
          return false;
        }
        previous = chainValue(e.jws);
      }
      final state = await _state();
      return state.chain != chain || state.counterCents == counter;
    } on Object {
      return false;
    }
  }

  static int _parseAmount(String amount) {
    final m = RegExp(r'^(-?)(\d+),(\d\d)$').firstMatch(amount);
    if (m == null) throw FormatException('Betrag', amount);
    final cents = int.parse(m.group(2)!) * 100 + int.parse(m.group(3)!);
    return m.group(1) == '-' ? -cents : cents;
  }

  static RksvMode _mode(RksvStateRow state) =>
      enumByNameOr(RksvMode.values, state.mode, RksvMode.off);

  Future<RksvStateRow> _state() =>
      (_db.select(_db.rksvStateRows)..where((t) => t.id.equals(1))).getSingle();

  Future<void> _writeState(RksvStateRowsCompanion c) =>
      (_db.update(_db.rksvStateRows)..where((t) => t.id.equals(1))).write(c);

  Future<RksvChainRow> _chainRow(int chain) => (_db.select(
    _db.rksvChainRows,
  )..where((t) => t.chain.equals(chain))).getSingle();

  Future<RksvEntryRow?> _lastEntry(int chain) =>
      (_db.select(_db.rksvEntryRows)
            ..where((t) => t.chain.equals(chain))
            ..orderBy([(t) => OrderingTerm.desc(t.position)])
            ..limit(1))
          .getSingleOrNull();
}
