// Nachrichten zum Senden (Teil C2): ein Eintrag der Liste "noch zu senden"
// wird beim Senden aus den Tabellen gelesen und in die Form gebracht, die der
// Server erwartet. Das Gegenstück auf dem Server ist `push_schema.ts`; beide
// prüfen sich an `shared/fixtures/sync/push_request.json`.

import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/database.dart';
import '../data/outbox_repository.dart';

/// Was der Server zu einem Eintrag sagt.
enum PushStatus { accepted, duplicate, rejected, error }

class PushResult {
  const PushResult({required this.seq, required this.status, this.reason});

  /// Wirft [FormatException], wenn `seq` oder `status` fehlen oder nicht
  /// passen. Ein unbekannter Zustand zählt als `error` (später wieder).
  factory PushResult.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Ergebnis ist kein Objekt');
    }
    final seq = json['seq'];
    final status = json['status'];
    final reason = json['reason'];
    if (seq is! int) throw const FormatException('Feld fehlt: seq');
    if (status is! String) throw const FormatException('Feld fehlt: status');
    if (reason != null && reason is! String) {
      throw const FormatException('Feld hat die falsche Art: reason');
    }
    return PushResult(
      seq: seq,
      status: PushStatus.values.asNameMap()[status] ?? PushStatus.error,
      reason: reason as String?,
    );
  }

  final int seq;
  final PushStatus status;

  /// Bei `rejected`: `conflict`, `invalid` oder `unknown_item`.
  final String? reason;
}

/// ISO 8601 in UTC mit Millisekunden: `2026-11-19T08:00:00.000Z`.
String _iso(DateTime t) => DateTime.fromMillisecondsSinceEpoch(
  t.millisecondsSinceEpoch,
  isUtc: true,
).toIso8601String();

String? _isoOrNull(DateTime? t) => t == null ? null : _iso(t);

/// Baut die Einträge der Anfrage an `POST /api/device/sync/push`.
class PushPayloads {
  PushPayloads(this._db);

  final KassaDatabase _db;

  /// Der Eintrag [e] in der Form der Nachrichtenformen, `seq` ist `e.id`.
  /// `null`, wenn es die Sache nicht mehr gibt.
  Future<Map<String, Object?>?> build(OutboxEntry e) async {
    final Map<String, Object?>? body = switch (e.kind) {
      'rksv_certificate' => await _certificate(e.ref),
      'rksv_chain' => await _chain(e.ref),
      'day' => await _day(e.ref),
      'cash_movement' => await _movement(e.ref),
      'receipt' => await _receipt(e.ref),
      // Kommt mit Task 8 (Artikel-Änderungen der Liste).
      'item_change' => throw UnimplementedError('item_change: Task 8'),
      // Kommt mit Task 10 (Berichte).
      'report' => throw UnimplementedError('report: Task 10'),
      _ => throw ArgumentError.value(e.kind, 'kind', 'Unbekannte Art'),
    };
    if (body == null) return null;
    return {'seq': e.id, 'kind': e.kind, ...body};
  }

  Future<Map<String, Object?>?> _certificate(String serialHex) async {
    final row = await (_db.select(
      _db.rksvCertificateRows,
    )..where((t) => t.serialHex.equals(serialHex))).getSingleOrNull();
    if (row == null) return null;
    return {
      'certificate': {
        'serialHex': row.serialHex,
        'certificate': base64.encode(row.certificate),
        'issuers': (jsonDecode(row.issuers) as List).cast<String>(),
      },
    };
  }

  Future<Map<String, Object?>?> _chain(String ref) async {
    final number = int.tryParse(ref);
    if (number == null) return null;
    final row = await (_db.select(
      _db.rksvChainRows,
    )..where((t) => t.chain.equals(number))).getSingleOrNull();
    if (row == null) return null;
    return {
      'chain': {
        'chain': row.chain,
        'mode': row.mode,
        'cashBoxId': row.cashBoxId,
        'zdaId': row.zdaId,
        'certSerial': row.certSerial,
        'startedAt': _iso(row.startedAt),
        'endedAt': _isoOrNull(row.endedAt),
      },
    };
  }

  Future<Map<String, Object?>?> _day(String id) async {
    final row = await (_db.select(
      _db.businessDayRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return {
      'day': {
        'id': row.id,
        'openedAt': _iso(row.openedAt),
        'closedAt': _isoOrNull(row.closedAt),
        // Der Server verlangt eine Zahl. Solange das Wechselgeld nicht
        // bekannt ist, geht 0 hinaus; ein späterer Stand des Tages ersetzt es.
        'openingFloatCents': row.openingFloatCents ?? 0,
        'countedCents': row.countedCents,
        'leftInDrawerCents': row.leftInDrawerCents,
        'expectedCents': row.expectedCents,
        'differenceCents': row.differenceCents,
        'closedByName': row.closedByName,
      },
    };
  }

  Future<Map<String, Object?>?> _movement(String id) async {
    final row = await (_db.select(
      _db.cashMovementRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return {
      'movement': {
        'id': row.id,
        'businessDayId': row.businessDayId,
        'kind': row.kind,
        'amountCents': row.amountCents,
        'reason': row.reason,
        'createdAt': _iso(row.createdAt),
        'staffId': row.staffId,
        'staffName': row.staffName,
      },
    };
  }

  Future<Map<String, Object?>?> _receipt(String id) async {
    final row = await (_db.select(
      _db.receiptRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;

    final lines =
        await (_db.select(_db.receiptLineRows)
              ..where((t) => t.receiptId.equals(id))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    final options =
        await (_db.select(_db.receiptLineOptionRows)
              ..where((t) => t.receiptId.equals(id))
              ..orderBy([
                (t) => OrderingTerm.asc(t.linePosition),
                (t) => OrderingTerm.asc(t.position),
              ]))
            .get();
    final payment = await (_db.select(
      _db.paymentRows,
    )..where((t) => t.receiptId.equals(id))).getSingleOrNull();
    final stamp = await (_db.select(_db.rksvEntryRows).join([
      innerJoin(
        _db.rksvChainRows,
        _db.rksvChainRows.chain.equalsExp(_db.rksvEntryRows.chain),
      ),
    ])..where(_db.rksvEntryRows.receiptId.equals(id))).getSingleOrNull();
    final entry = stamp?.readTable(_db.rksvEntryRows);
    final chain = stamp?.readTable(_db.rksvChainRows);

    return {
      'receipt': {
        'v': 1,
        'id': row.id,
        'number': row.number,
        'createdAt': _iso(row.createdAt),
        'staffId': row.staffId,
        'staffName': row.staffName,
        'businessDayId': row.businessDayId,
        'kind': row.kind,
        'voidsReceiptId': row.voidsReceiptId,
        'goodsCents': row.goodsCents,
        'depositCents': row.depositCents,
        'totalCents': row.totalCents,
        // Ein Bon zählt nur als echt, wenn er in einer Kette mit `live`
        // steht. Ohne Signatur und in einer Probe-Kette ist er ein Testbon.
        'test': chain?.mode != 'live',
        'lines': [
          for (final l in lines)
            {
              'position': l.position,
              'itemId': l.itemId,
              'name': l.name,
              'info': l.info,
              'unitPriceCents': l.unitPriceCents,
              'quantity': l.quantity,
              'unitDepositCents': l.unitDepositCents,
              'gross': {
                '20': l.gross20Cents,
                '10': l.gross10Cents,
                '13': l.gross13Cents,
                '0': l.gross0Cents,
                '19': l.gross19Cents,
              },
              'options': [
                for (final o in options)
                  if (o.linePosition == l.position)
                    {
                      'groupName': o.groupName,
                      'optionName': o.optionName,
                      'surchargeCents': o.surchargeCents,
                    },
              ],
            },
        ],
        'payment': payment == null
            ? null
            : {
                'kind': payment.kind,
                'amountCents': payment.amountCents,
                'givenCents': payment.givenCents,
                'changeCents': payment.changeCents,
                'provider': payment.provider,
                'providerTxCode': payment.providerTxCode,
                'cardScheme': payment.cardScheme,
                'cardLast4': payment.cardLast4,
              },
        'rksv': entry == null
            ? null
            : {
                'chain': entry.chain,
                'position': entry.position,
                'jws': entry.jws,
                'damaged': entry.damaged,
                'certSerial': entry.certSerial,
              },
      },
    };
  }
}
