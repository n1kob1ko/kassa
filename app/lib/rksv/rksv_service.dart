// Probe-Signatur ein- und ausschalten. Task 6 und 7 ergänzen Nullbeleg,
// "Nochmal prüfen" und "Protokoll ausgeben".

import 'dart:math';

import 'package:drift/drift.dart';

import '../core/clock.dart';
import '../core/enums.dart';
import '../data/database.dart';
import '../data/receipt_repository.dart';
import '../domain/receipt.dart';
import '../domain/staff.dart';
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
  }) : _random = random ?? Random.secure();

  final KassaDatabase _db;
  final RksvSecrets _secrets;
  final ReceiptRepository _receipts;
  final Clock _clock;
  final Random _random;

  /// Neue Kette: Kassen-Kennung, AES-Schlüssel, Probe-Schlüssel und
  /// Zertifikat erzeugen, Startbeleg signieren. Wirft RksvProblem, wenn der
  /// geschützte Speicher nicht schreibt oder die Signatur scheitert; dann
  /// bleibt alles wie vorher. Läuft die Signatur schon: [StateError].
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
      final highest = _db.rksvChainRows.chain.max();
      final chain =
          (await (_db.selectOnly(_db.rksvChainRows)..addColumns([highest]))
                  .map((r) => r.read(highest))
                  .getSingle() ??
              0) +
          1;
      final cashBoxId = String.fromCharCodes([
        for (var i = 0; i < 10; i++)
          _cashBoxIdAlphabet.codeUnitAt(
            _random.nextInt(_cashBoxIdAlphabet.length),
          ),
      ]);
      final aesKey = Uint8List.fromList([
        for (var i = 0; i < 32; i++) _random.nextInt(256),
      ]);
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
      await _writeState(
        RksvStateRowsCompanion(
          mode: Value(RksvMode.probe.name),
          chain: Value(chain),
          counterCents: const Value(0),
          outageSince: const Value(null),
          outageReason: const Value(null),
        ),
      );
      try {
        return await _receipts.createSpecial(
          ReceiptKind.start,
          staff: staff,
          mustSign: true,
        );
      } on SignatureFailure catch (e) {
        throw RksvProblem(e.reason);
      }
    });
  }

  /// Schreibt beide Schlüssel und liest sie zurück.
  Future<void> _storeSecrets(int chain, Uint8List aesKey, Uint8List key) async {
    bool same(Uint8List? a, Uint8List b) =>
        a != null && a.length == b.length && _equal(a, b);
    try {
      await _secrets.writeAesKey(chain, aesKey);
      await _secrets.writeProbeKey(chain, key);
      if (!same(await _secrets.aesKey(chain), aesKey) ||
          !same(await _secrets.probeKey(chain), key)) {
        throw const RksvProblem(_storageProblem);
      }
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
        ),
      );
      return closing;
    });
  }

  Future<RksvStateRow> _state() =>
      (_db.select(_db.rksvStateRows)..where((t) => t.id.equals(1))).getSingle();

  Future<void> _writeState(RksvStateRowsCompanion c) =>
      (_db.update(_db.rksvStateRows)..where((t) => t.id.equals(1))).write(c);
}
