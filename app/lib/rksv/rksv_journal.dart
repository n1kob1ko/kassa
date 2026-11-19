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

/// Liefert die Signatur-Einheit einer Kette; in der App [signatureUnitOf].
typedef SignatureUnitOf = Future<SignatureUnit> Function(int chain);

/// Baut die Online-Einheit einer Kette aus ihren gespeicherten Zeilen.
typedef OnlineUnitOf = Future<SignatureUnit> Function(
  RksvChainRow chain,
  RksvCertificateRow certificate,
);

/// Die Signatur-Einheit der App, nach `rksv_chains.unit`: bei `probe` die
/// Probe-Signatur mit dem Schlüssel aus [secrets] und dem Zertifikat der
/// Kette, bei `atrustTest` und `atrust` was [online] aus Kette und
/// Zertifikat baut. Fehlt etwas, passt der Modus nicht oder ist die Einheit
/// unbekannt, ist das ein unerwarteter Fehler ([StateError]), kein Ausfall.
SignatureUnitOf signatureUnitOf(
  KassaDatabase db,
  RksvSecrets secrets, {
  required OnlineUnitOf online,
}) => (chain) async {
  final row = await (db.select(db.rksvChainRows).join([
    innerJoin(
      db.rksvCertificateRows,
      db.rksvCertificateRows.serialHex.equalsExp(db.rksvChainRows.certSerial),
    ),
  ])..where(db.rksvChainRows.chain.equals(chain))).getSingleOrNull();
  if (row == null) {
    throw StateError('Kette $chain oder ihr Zertifikat fehlt.');
  }
  final chainRow = row.readTable(db.rksvChainRows);
  final certificate = row.readTable(db.rksvCertificateRows);
  final unit =
      RksvUnit.values.asNameMap()[chainRow.unit] ??
      (throw StateError('Kette $chain hat eine unbekannte Signatur-Einheit.'));
  switch (unit) {
    case RksvUnit.probe:
      if (chainRow.mode != RksvMode.probe.name) {
        throw StateError('Kette $chain ist keine Probe-Kette.');
      }
      final key = await secrets.probeKey(chain);
      if (key == null) {
        throw StateError('Der Schlüssel der Probe-Signatur fehlt.');
      }
      return ProbeSignatureUnit(
        privateKey: key,
        certificateDer: certificate.certificate,
      );
    case RksvUnit.atrustTest:
      // Testsystem heißt Testbon (Plan, Global Constraints).
      if (chainRow.mode != RksvMode.probe.name) {
        throw StateError('Kette $chain am Testsystem ist keine Probe-Kette.');
      }
      return online(chainRow, certificate);
    case RksvUnit.atrust:
      return online(chainRow, certificate);
  }
};

/// Wie [signatureUnitOf], aber nur für Probe-Ketten: Eine Kette mit einer
/// Online-Einheit ist ein [StateError].
SignatureUnitOf probeSignatureUnitOf(KassaDatabase db, RksvSecrets secrets) =>
    signatureUnitOf(
      db,
      secrets,
      online: (chain, _) async =>
          throw StateError('Kette ${chain.chain} ist keine Probe-Kette.'),
    );

const _reasonSilent = 'Die Signatur hat nicht geantwortet.';

/// Nur noch, wenn ohne Frage an die Signatur ein Ausfall-Vermerk entsteht und
/// kein Grund gespeichert ist.
const _reasonError = 'Die Signatur hat einen Fehler gemeldet.';

/// Ab dieser Dauer ist ein Ausfall bei FinanzOnline zu melden.
const _outageToReport = Duration(hours: 48);
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
  /// [trySign] false: gleich der Ausfall-Eintrag, ohne die Signatur zu
  /// fragen (der Sammelbeleg davor ist eben gescheitert).
  Future<void> record({
    required String receiptId,
    required int number,
    required DateTime createdAt,
    required ReceiptKind kind,
    required List<int> sumsCents,
    bool mustSign = false,
    bool trySign = true,
  }) async {
    // 1. Zustand, Kette, letzter Eintrag.
    final state = await _state();
    if (_mode(state) == RksvMode.off) return;
    final chain =
        state.chain ?? (throw StateError('Die Signatur hat keine Kette.'));
    final chainRow = await _chainRow(chain);
    final last = await _lastEntry(chain);
    // 2. bis 5. unter einer Frist: Schlüssel lesen, Einheit bauen,
    // signieren. Ein Speicher, der nicht antwortet, hält den Bon nicht auf.
    final counter =
        state.counterCents + sumsCents.fold<int>(0, (a, b) => a + b);
    final signed = await _sign(
      chain: chain,
      chainRow: chainRow,
      number: number,
      createdAt: createdAt,
      kind: kind,
      sumsCents: sumsCents,
      counter: counter,
      // 3. Kettenwert.
      previous: chainValue(last?.jws ?? chainRow.cashBoxId),
      limit: state.outageSince == null ? signLimit : signLimitDuringOutage,
      mustSign: mustSign,
      skipReason: trySign ? null : (state.outageReason ?? _reasonError),
    );

    // 6. Eintrag und Zähler.
    final position = (last?.position ?? 0) + 1;
    await _db
        .into(_db.rksvEntryRows)
        .insert(
          RksvEntryRowsCompanion.insert(
            chain: chain,
            position: position,
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

    // 7. Aufgaben.
    await _addTasks(
      state: state,
      chain: chain,
      kind: kind,
      position: position,
      createdAt: createdAt,
      last: last,
      outageSince: state.outageSince ?? (startsOutage ? createdAt : null),
    );
  }

  /// Neue Aufgaben nach dem Eintrag an [position]; jede nur, wenn es ihre Id
  /// noch nicht gibt. [outageSince]: Beginn des Ausfalls, der bis zu diesem
  /// Eintrag lief (auch wenn ihn dieser Sammelbeleg beendet).
  Future<void> _addTasks({
    required RksvStateRow state,
    required int chain,
    required ReceiptKind kind,
    required int position,
    required DateTime createdAt,
    required RksvEntryRow? last,
    required DateTime? outageSince,
  }) async {
    final now = _clock.now();
    final added = <RksvTask>[];
    void add(String id, RksvTaskKind k, [String detail = '']) =>
        added.add(RksvTask(id: id, kind: k, createdAt: now, detail: detail));

    if (kind == ReceiptKind.start) {
      add('check-start-$chain', RksvTaskKind.checkStart);
    }
    final lastTime = last == null ? null : await _timeOf(last);
    if (kind == ReceiptKind.year) {
      final before = await _lastTime(chain, before: position, signedOnly: true);
      final year = '${(before ?? createdAt).year}';
      add('check-year-$year', RksvTaskKind.checkYear, year);
    }
    if (outageSince != null) {
      bool long(DateTime t) => t.difference(outageSince) > _outageToReport;
      // Nur beim ersten Eintrag nach 48 Stunden: Eine erledigte Meldung kommt
      // nicht mit dem nächsten Bon wieder.
      if (long(createdAt) && (lastTime == null || !long(lastTime))) {
        final first = await _firstOutageEntry(chain, position) ?? position;
        add(
          'report-outage-$chain-$first',
          RksvTaskKind.reportOutage,
          _dateTime(outageSince),
        );
      }
      if (kind == ReceiptKind.collective && long(createdAt)) {
        add(
          'report-outage-end-$chain-$position',
          RksvTaskKind.reportOutageEnd,
          _dateTime(createdAt),
        );
      }
    }
    if (lastTime != null && _quarter(lastTime) < _quarter(createdAt)) {
      final q = (createdAt.month - 1) ~/ 3 + 1;
      add('backup-${createdAt.year}-Q$q', RksvTaskKind.backupProtocol);
    }

    if (added.isEmpty) return;
    final tasks = decodeRksvTasks(state.tasks);
    final known = {for (final t in tasks) t.id};
    final fresh = [
      for (final t in added)
        if (known.add(t.id)) t,
    ];
    if (fresh.isEmpty) return;
    await _writeState(
      RksvStateRowsCompanion(
        tasks: Value(encodeRksvTasks([...tasks, ...fresh])),
      ),
    );
  }

  /// Position des ersten Ausfall-Eintrags des Ausfalls, der bis zum Eintrag
  /// an [position] lief: der erste mit Vermerk nach dem letzten Sammelbeleg
  /// davor.
  Future<int?> _firstOutageEntry(int chain, int position) async {
    final collectiveAt = _db.rksvEntryRows.position.max();
    final lastCollective =
        await (_db.selectOnly(_db.rksvEntryRows).join([
                innerJoin(
                  _db.receiptRows,
                  _db.receiptRows.id.equalsExp(_db.rksvEntryRows.receiptId),
                ),
              ])
              ..addColumns([collectiveAt])
              ..where(
                _db.rksvEntryRows.chain.equals(chain) &
                    _db.rksvEntryRows.position.isSmallerThanValue(position) &
                    _db.receiptRows.kind.equals(ReceiptKind.collective.name),
              ))
            .map((r) => r.read(collectiveAt))
            .getSingle() ??
        0;
    final first = _db.rksvEntryRows.position.min();
    return (_db.selectOnly(_db.rksvEntryRows)
          ..addColumns([first])
          ..where(
            _db.rksvEntryRows.chain.equals(chain) &
                _db.rksvEntryRows.damaged.equals(true) &
                _db.rksvEntryRows.position.isBiggerThanValue(lastCollective),
          ))
        .map((r) => r.read(first))
        .getSingle();
  }

  /// Zeit des Bons zum Eintrag [e].
  Future<DateTime> _timeOf(RksvEntryRow e) async => (await (_db.select(
    _db.receiptRows,
  )..where((t) => t.id.equals(e.receiptId))).getSingle()).createdAt;

  /// Zeit des letzten Eintrags der Kette (vor Position [before], wenn
  /// angegeben), mit [signedOnly] nur unter den signierten Einträgen ohne
  /// Sammelbelege. `null` ohne.
  Future<DateTime?> _lastTime(
    int chain, {
    int? before,
    bool signedOnly = false,
  }) async {
    final query =
        _db.select(_db.rksvEntryRows).join([
            innerJoin(
              _db.receiptRows,
              _db.receiptRows.id.equalsExp(_db.rksvEntryRows.receiptId),
            ),
          ])
          ..where(_db.rksvEntryRows.chain.equals(chain))
          ..orderBy([OrderingTerm.desc(_db.rksvEntryRows.position)])
          ..limit(1);
    if (before != null) {
      query.where(_db.rksvEntryRows.position.isSmallerThanValue(before));
    }
    if (signedOnly) {
      query.where(
        _db.rksvEntryRows.damaged.equals(false) &
            _db.receiptRows.kind.equals(ReceiptKind.collective.name).not(),
      );
    }
    return (await query.getSingleOrNull())
        ?.readTable(_db.receiptRows)
        .createdAt;
  }

  static int _quarter(DateTime t) => t.year * 4 + (t.month - 1) ~/ 3;

  /// `18.11.2026 13:05`
  static String _dateTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}.${two(t.month)}.${t.year} '
        '${two(t.hour)}:${two(t.minute)}';
  }

  /// Liest den AES-Schlüssel, rechnet den Zähler (2.), baut die Einheit und
  /// signiert den Code (4.), alles zusammen innerhalb von [limit]. Bei
  /// [SignatureFailure] oder Fristablauf beim Signieren (5.): mit [mustSign]
  /// eine [SignatureFailure], sonst der Ausfall-Vermerk. Eine Antwort nach
  /// der Frist wird verworfen. Läuft die Frist ab, bevor Schlüssel und
  /// Einheit da sind, ist das ein unerwarteter Fehler ([StateError]), wie
  /// jeder andere Fehler dabei.
  Future<_Signed> _sign({
    required int chain,
    required RksvChainRow chainRow,
    required int number,
    required DateTime createdAt,
    required ReceiptKind kind,
    required List<int> sumsCents,
    required int counter,
    required String previous,
    required Duration limit,
    required bool mustSign,
    String? skipReason,
  }) async {
    String? counterField;
    SignatureUnit? unit;
    SignerInfo? info;
    var tooLate = false;

    String text() => codeText(
      CodeFields(
        zdaId: info?.zdaId ?? chainRow.zdaId,
        cashBoxId: chainRow.cashBoxId,
        receiptId: '$number',
        time: createdAt,
        sumsCents: sumsCents,
        counterField: counterField!,
        certSerial: info?.serialHex ?? chainRow.certSerial,
        chain: previous,
      ),
    );

    /// Nach der Frist nichts mehr tun, vor allem nicht mehr in die
    /// Datenbank: Die Transaktion des Bons kann dann schon zu sein.
    void stopIfLate() {
      if (tooLate) throw StateError('Zu spät.');
    }

    Future<_Signed> attempt() async {
      final aesKey =
          await _secrets.aesKey(chain) ??
          (throw StateError('Der AES-Schlüssel der Kette $chain fehlt.'));
      stopIfLate();
      counterField = kind == ReceiptKind.voided
          ? stornoCounterField
          : encryptCounter(
              aesKey: aesKey,
              cashBoxId: chainRow.cashBoxId,
              receiptId: '$number',
              counterCents: counter,
            );
      if (skipReason != null) {
        return (
          jws: jwsDamaged(text()),
          certSerial: chainRow.certSerial,
          failure: skipReason,
        );
      }
      final u = await _unitOf(chain);
      stopIfLate();
      unit = u;
      final i = await u.info();
      stopIfLate();
      info = i;
      final t = text();
      final signature = await u.sign(jwsSigningInput(t));
      return (
        jws: jwsCompact(t, signature),
        certSerial: i.serialHex,
        failure: null,
      );
    }

    String failure;
    try {
      return await attempt().timeout(limit);
    } on SignatureFailure catch (e) {
      if (mustSign) rethrow;
      // Der Satz der Einheit wird der Grund des Ausfalls (P2).
      failure = e.reason;
    } on TimeoutException {
      tooLate = true;
      if (unit == null) {
        throw StateError('Der geschützte Speicher hat nicht geantwortet.');
      }
      if (mustSign) throw const SignatureFailure(_reasonSilent);
      failure = _reasonSilent;
    }
    final known = info;
    return (
      jws: jwsDamaged(text()),
      certSerial: known?.serialHex ?? chainRow.certSerial,
      failure: failure,
    );
  }

  /// Welcher Beleg vor einem Verkauf oder Storno fällig ist: collective (bei
  /// Ausfall), sonst year, month, oder null. Maßgeblich ist die Zeit des
  /// letzten signierten Eintrags der Kette, der kein Sammelbeleg ist: Nach
  /// einem Sammelbeleg folgt so noch der Monats- oder Jahresbeleg, auch wenn
  /// im neuen Monat schon Bons mit Ausfall-Vermerk stehen. Liegt [now] davor
  /// (Uhr zurückgestellt), ist nichts fällig.
  Future<ReceiptKind?> dueBefore(DateTime now) async {
    final state = await _state();
    final chain = state.chain;
    if (_mode(state) == RksvMode.off || chain == null) return null;
    if (state.outageSince != null) return ReceiptKind.collective;
    final last = await _lastTime(chain, signedOnly: true);
    if (last == null || now.isBefore(last)) return null;
    if (now.year > last.year) return ReceiptKind.year;
    if (now.month > last.month) return ReceiptKind.month;
    return null;
  }

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
        // Die Aufgaben gehören zur Probe und enden mit ihr.
        tasks: const Value('[]'),
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
