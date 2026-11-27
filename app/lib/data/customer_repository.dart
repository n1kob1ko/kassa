// Firmenkunden und Rechnungsempfänger am Tablet (Spec 5.3). Beide tragen sich
// beim Schreiben selbst in die Liste "noch zu senden" ein, im selben Schritt
// der Datenbank: `customer` (ref = Kennung) und `recipient` (ref =
// `<Bon>/<Fassung>`). Der Bon und seine Signatur ändern sich dabei nie.

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/clock.dart';
import '../domain/customer.dart';
import '../domain/staff.dart';
import 'database.dart';

class CustomerRepository {
  CustomerRepository(this._db, this._clock);

  final KassaDatabase _db;
  final Clock _clock;

  static const _uuid = Uuid();

  /// Die Firmenkunden, die nicht archiviert sind: die zuletzt verwendeten
  /// oben (neueste zuerst), dann die übrigen nach Name, ohne Rücksicht auf
  /// groß und klein. Mit [initial] nur die mit diesem Anfangsbuchstaben
  /// ([customerInitial]).
  Future<List<Customer>> list({String? initial}) async {
    final all = [
      for (final r in await (_db.select(
        _db.customerRows,
      )..where((t) => t.archived.equals(false))).get())
        _customer(r),
    ];
    final chosen = [
      for (final c in all)
        if (initial == null || customerInitial(c.name) == initial) c,
    ];
    int byName(Customer a, Customer b) {
      final n = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return n != 0 ? n : a.id.compareTo(b.id);
    }

    chosen.sort((a, b) {
      final ua = a.lastUsedAt, ub = b.lastUsedAt;
      if (ua != null && ub != null) {
        final u = ub.compareTo(ua);
        return u != 0 ? u : byName(a, b);
      }
      if (ua != null) return -1;
      if (ub != null) return 1;
      return byName(a, b);
    });
    return chosen;
  }

  /// Die Anfangsbuchstaben, die bei den Firmenkunden aus [list] vorkommen,
  /// je einmal: Buchstaben nach dem Alphabet, `#` zuletzt.
  Future<List<String>> initials() async =>
      {for (final c in await list()) customerInitial(c.name)}.toList()
        ..sort(compareInitials);

  /// Legt einen Firmenkunden an (ohne [id]) oder ändert ihn. Die Werte
  /// werden vorn und hinten von Leerzeichen befreit, eine leere UID ist
  /// keine. Archiviert und zuletzt verwendet bleiben, wie sie waren.
  Future<Customer> save({
    String? id,
    required String name,
    required String addressLine1,
    required String addressLine2,
    String? vatId,
  }) => _db.transaction(() async {
    final key = id ?? _uuid.v4();
    final existing = await (_db.select(
      _db.customerRows,
    )..where((t) => t.id.equals(key))).getSingleOrNull();
    final row = CustomerRow(
      id: key,
      name: name.trim(),
      addressLine1: addressLine1.trim(),
      addressLine2: addressLine2.trim(),
      vatId: _vat(vatId),
      archived: existing?.archived ?? false,
      updatedAt: _clock.now(),
      lastUsedAt: existing?.lastUsedAt,
    );
    await _db.into(_db.customerRows).insertOnConflictUpdate(row);
    await _enqueue('customer', key);
    return _customer(row);
  });

  /// Speichert eine neue Fassung des Empfängers zum Bon [receiptId]: die
  /// höchste bisherige plus 1, die erste ist 0. Mit [customerId] gilt der
  /// Firmenkunde als eben verwendet (keine Änderung, kein Eintrag
  /// `customer`). Wirft [ArgumentError], wenn Name oder Adresse fehlen oder
  /// zu lang sind, und [StateError], wenn es den Bon nicht gibt.
  Future<ReceiptRecipient> setRecipient({
    required String receiptId,
    String? customerId,
    required String name,
    required String addressLine1,
    required String addressLine2,
    String? vatId,
    required Staff staff,
  }) => _db.transaction(() async {
    final total = await _db
        .customSelect(
          'SELECT total_cents FROM receipts WHERE id = ?',
          variables: [Variable.withString(receiptId)],
        )
        .map((r) => r.read<int>('total_cents'))
        .getSingleOrNull();
    if (total == null) throw StateError('Bon $receiptId unbekannt');
    final problems = checkRecipient(
      name: name,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      vatId: vatId ?? '',
      receiptTotalCents: total,
    );
    if (problems.isNotEmpty) {
      throw ArgumentError.value(problems, 'recipient', 'passt nicht');
    }
    final last = await _db
        .customSelect(
          'SELECT MAX(version) AS v FROM receipt_recipients '
          'WHERE receipt_id = ?',
          variables: [Variable.withString(receiptId)],
          readsFrom: {_db.receiptRecipientRows},
        )
        .map((r) => r.read<int?>('v'))
        .getSingle();
    final now = _clock.now();
    final row = ReceiptRecipientRow(
      receiptId: receiptId,
      version: last == null ? 0 : last + 1,
      customerId: customerId,
      name: name.trim(),
      addressLine1: addressLine1.trim(),
      addressLine2: addressLine2.trim(),
      vatId: _vat(vatId),
      createdAt: now,
      staffId: staff.id,
      staffName: staff.name,
    );
    await _db.into(_db.receiptRecipientRows).insert(row);
    if (customerId != null) {
      await (_db.update(_db.customerRows)
            ..where((t) => t.id.equals(customerId)))
          .write(CustomerRowsCompanion(lastUsedAt: Value(now)));
    }
    await _enqueue('recipient', '$receiptId/${row.version}');
    return _recipient(row);
  });

  /// Die letzte Fassung des Empfängers zum Bon, sonst `null`.
  Future<ReceiptRecipient?> recipientOf(String receiptId) =>
      _lastOf(receiptId).getSingleOrNull();

  /// Wie [recipientOf], als Strom: liefert neu, sobald eine Fassung dazukommt.
  Stream<ReceiptRecipient?> watchRecipient(String receiptId) =>
      _lastOf(receiptId).watchSingleOrNull();

  Selectable<ReceiptRecipient> _lastOf(String receiptId) =>
      (_db.select(_db.receiptRecipientRows)
            ..where((t) => t.receiptId.equals(receiptId))
            ..orderBy([(t) => OrderingTerm.desc(t.version)])
            ..limit(1))
          .map(_recipient);

  /// Ein Eintrag in "noch zu senden", wie die Trigger der Datenbank es tun:
  /// wartet schon einer, zählt seine Fassung hoch, sonst kommt ein neuer.
  Future<void> _enqueue(String kind, String ref) async {
    await _db.customUpdate(
      'UPDATE outbox SET rev = rev + 1 '
      "WHERE kind = ? AND kind <> 'item_change' AND ref = ?",
      variables: [Variable.withString(kind), Variable.withString(ref)],
      updates: {_db.outboxRows},
      updateKind: UpdateKind.update,
    );
    await _db
        .into(_db.outboxRows)
        .insert(
          OutboxRowsCompanion.insert(kind: kind, ref: ref),
          mode: InsertMode.insertOrIgnore,
        );
  }

  static String? _vat(String? vatId) {
    final v = vatId?.trim() ?? '';
    return v.isEmpty ? null : v;
  }

  static Customer _customer(CustomerRow r) => Customer(
    id: r.id,
    name: r.name,
    addressLine1: r.addressLine1,
    addressLine2: r.addressLine2,
    vatId: r.vatId,
    archived: r.archived,
    updatedAt: r.updatedAt,
    lastUsedAt: r.lastUsedAt,
  );

  static ReceiptRecipient _recipient(ReceiptRecipientRow r) => ReceiptRecipient(
    receiptId: r.receiptId,
    version: r.version,
    customerId: r.customerId,
    name: r.name,
    addressLine1: r.addressLine1,
    addressLine2: r.addressLine2,
    vatId: r.vatId,
    createdAt: r.createdAt,
    staffId: r.staffId,
    staffName: r.staffName,
  );
}
