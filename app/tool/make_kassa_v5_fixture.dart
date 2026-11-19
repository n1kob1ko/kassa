// Erzeugt test/data/fixtures/kassa_v5.sqlite: eine Datenbank im Stand der
// ausgelieferten Version 1.5.0 (Datenbank Version 5). Das Schema kommt aus dem
// Abzug schema_v5.dart, der unverändert vom Signatur-Thread stammt, nicht aus
// dem heutigen Code. Aufruf aus `app/`:
//
//   dart run tool/make_kassa_v5_fixture.dart
//
// Inhalt (alles erfunden, keine echten Namen, keine Schlüssel): fünf Tage
// (vier abgeschlossen, der fünfte offen), je Tag eine Bargeld-Bewegung, gut
// 300 Bons mit Zeilen, Auswahl und Zahlung (Verkäufe bar und mit Karte,
// Stornos, Start- und Schlussbelege) und drei Ketten: 1 Probe (beendet),
// 2 Online-Probe am Testsystem (`atrustTest`, beendet), 3 Probe (läuft), jede
// mit eigenem Zertifikat und ihren Einträgen im Protokoll. Die ersten zehn
// Verkäufe liegen vor der ersten Kette und haben keinen Eintrag. Die Kassa
// ist gekoppelt, und am Tablet wurden Preise geändert (Huhn Bowl 1090,
// Cola 320, Teigtaschen nicht im Verkauf).
//
// Trigger und Indizes von Version 5 sind die von Version 4
// (`fixture_guards.dart`); Version 5 fügte nur die Spalte `unit` hinzu.

import 'dart:io';

import 'package:drift/native.dart';

import '../test/data/generated_migrations/schema_v5.dart';
import 'fixture_guards.dart';

const _target = 'test/data/fixtures/kassa_v5.sqlite';

/// 2026-11-10 06:00:00 UTC in Sekunden, der Morgen des ersten Tages.
const _t0 = 1794290400;
const _day = 86400;

/// Zahl der Tage und der Verkäufe je Tag.
const _days = 5;
const _salesPerDay = 56;

/// Verkäufe vor der ersten Kette (am ersten Tag).
const _unsigned = 10;

typedef _Item = ({String id, String name, int price, int tax, int deposit});

// Preise, wie sie am Tablet stehen (nach den Änderungen dort).
const List<_Item> _items = [
  (id: 'huhn-bowl', name: 'Huhn Bowl', price: 1090, tax: 10, deposit: 0),
  (id: 'tofu-bowl', name: 'Tofu Bowl', price: 950, tax: 10, deposit: 0),
  (id: 'teigtaschen', name: 'Teigtaschen', price: 650, tax: 10, deposit: 0),
  (id: 'pommes', name: 'Pommes', price: 390, tax: 10, deposit: 0),
  (id: 'cola', name: 'Cola 0,33 l', price: 320, tax: 20, deposit: 25),
  (id: 'limonade', name: 'Limonade 0,33 l', price: 290, tax: 20, deposit: 25),
];

const _staff = [
  ('staff-chefin', 'Chefin'),
  ('staff-anna', 'Anna'),
  ('staff-ben', 'Ben'),
];

typedef _Chain = ({
  int chain,
  String unit,
  String serial,
  String cashBoxId,
  String zdaId,
  int startDay,
  int? endDay,
});

const List<_Chain> _chains = [
  (
    chain: 1,
    unit: 'probe',
    serial: 'c0ffee01',
    cashBoxId: 'PROBEKASS1',
    zdaId: 'AT100',
    startDay: 0,
    endDay: 1,
  ),
  (
    chain: 2,
    unit: 'atrustTest',
    serial: '7e570002',
    cashBoxId: 'ONLINETST2',
    zdaId: 'AT1',
    startDay: 2,
    endDay: 2,
  ),
  (
    chain: 3,
    unit: 'probe',
    serial: 'c0ffee03',
    cashBoxId: 'PROBEKASS3',
    zdaId: 'AT100',
    startDay: 3,
    endDay: null,
  ),
];

typedef _Line = ({
  _Item item,
  int quantity,
  List<(String, String, int)> options,
  int gross,
});

/// Zeilen eines Verkaufs aus [seed], beim Storno ([sign] -1) mit negativer
/// Menge.
List<_Line> _linesOf(int seed, {int sign = 1}) => [
  for (var p = 0; p < 1 + seed % 3; p++)
    () {
      final item = _items[(seed + p * 2) % _items.length];
      final options = <(String, String, int)>[
        if (item.id.endsWith('bowl'))
          (seed + p).isEven ? ('Größe', 'Normal', 0) : ('Größe', 'Groß', 200),
        if (item.id.endsWith('bowl') && seed % 4 == 0) ('Sauce', 'Erdnuss', 50),
      ];
      final quantity = sign * (1 + (seed + p) % 2);
      final unit = item.price + options.fold<int>(0, (s, o) => s + o.$3);
      return (
        item: item,
        quantity: quantity,
        options: options,
        gross: unit * quantity,
      );
    }(),
];

String _q(String? s) => s == null ? 'NULL' : "'${s.replaceAll("'", "''")}'";

Future<void> main() async {
  final file = File(_target);
  if (file.existsSync()) file.deleteSync();
  final db = DatabaseAtV5(NativeDatabase(file));

  Future<void> run(String sql) => db.customStatement(sql);

  // Löst onCreate des Abzugs aus: alle Tabellen von Version 5.
  await run('SELECT 1');
  await createV4Guards(run);

  await run(
    'INSERT INTO business (id, name, address_lines, receipt_footer) VALUES '
    "(1, 'Beispiel-Imbiss', 'Musterstraße 1\n1010 Wien', 'Danke!')",
  );
  await run('INSERT INTO settings (id, show_images) VALUES (1, 1)');
  // Gekoppelt, keine Adresse, nur Platzhalter.
  await run(
    'INSERT INTO sync_state (id, register_id, register_name, business_id, '
    'pull_cursor, initial_pull_done, last_pull_at) VALUES '
    "(1, 'test-register', 'Kassa 1', 'test-business', 40, 1, "
    '${_t0 + 4 * _day})',
  );
  for (final (i, (id, name)) in _staff.indexed) {
    await run(
      'INSERT INTO staff (id, name, role, pin_salt, pin_hash) VALUES '
      "('$id', '$name', '${i == 0 ? 'chef' : 'staff'}', 'salt', 'hash')",
    );
  }
  await run(
    'INSERT INTO categories (id, name, position) VALUES '
    "('bowls', 'Bowls', 0), ('snacks', 'Snacks', 1), "
    "('getraenke', 'Getränke', 2)",
  );
  await run(
    'INSERT INTO modifier_templates (id, name, position) '
    "VALUES ('bowl', 'Bowl', 0)",
  );
  await run(
    'INSERT INTO modifier_groups (id, template_id, name, min_count, '
    "max_count, position) VALUES ('bowl-groesse', 'bowl', 'Größe', 1, 1, 0), "
    "('bowl-sauce', 'bowl', 'Sauce', 0, 2, 1)",
  );
  await run(
    'INSERT INTO modifier_options (id, group_id, name, surcharge_cents, '
    'is_default, position) VALUES '
    "('groesse-normal', 'bowl-groesse', 'Normal', 0, 1, 0), "
    "('groesse-gross', 'bowl-groesse', 'Groß', 200, 0, 1), "
    "('sauce-erdnuss', 'bowl-sauce', 'Erdnuss', 50, 0, 0), "
    "('sauce-chili', 'bowl-sauce', 'Chili', 0, 0, 1)",
  );
  for (final (i, item) in _items.indexed) {
    final bowl = item.id.endsWith('bowl');
    final category = item.tax == 20 ? 'getraenke' : (bowl ? 'bowls' : 'snacks');
    await run(
      'INSERT INTO items (id, name, price_cents, category_id, tax_percent, '
      'deposit_cents, tags, template_id, favorite, in_sale, position) VALUES '
      "('${item.id}', ${_q(item.name)}, ${item.price}, '$category', "
      "${item.tax}, ${item.deposit}, '${i == 1 ? 'vegan' : ''}', "
      "${bowl ? "'bowl'" : 'NULL'}, ${item.id == 'cola' ? 1 : 0}, "
      "${item.id == 'teigtaschen' ? 0 : 1}, $i)",
    );
  }
  for (final c in _chains) {
    // Erfundene Bytes, kein echtes Zertifikat.
    final issuers = c.unit == 'atrustTest' ? '["dGVzdA=="]' : '[]';
    await run(
      'INSERT INTO rksv_certificates (serial_hex, certificate, issuers) '
      "VALUES ('${c.serial}', x'308200${c.chain.toString().padLeft(2, '0')}', "
      "'$issuers')",
    );
  }

  var number = 0;
  // Laufende Kette, ihre letzte Position und ihr Umsatzzähler.
  _Chain? chain;
  var position = 0;
  var counter = 0;

  /// Schreibt einen Bon mit seinen Zeilen, der Zahlung und dem Eintrag im
  /// Protokoll, wenn eine Kette läuft. Liefert die Kennung.
  Future<String> receipt({
    required int at,
    required String kind,
    String? day,
    (String, String) staff = ('staff-chefin', 'Chefin'),
    String? voids,
    List<_Line> lines = const [],
    bool card = false,
  }) async {
    number++;
    final id = 'v5-${number.toString().padLeft(4, '0')}';
    final goods = lines.fold<int>(0, (s, l) => s + l.gross);
    final deposit = lines.fold<int>(
      0,
      (s, l) => s + l.item.deposit * l.quantity,
    );
    final total = goods + deposit;
    await run(
      'INSERT INTO receipts (id, number, created_at, staff_id, staff_name, '
      'business_day_id, kind, voids_receipt_id, goods_cents, deposit_cents, '
      "total_cents) VALUES ('$id', $number, $at, '${staff.$1}', "
      "'${staff.$2}', ${_q(day)}, '$kind', ${_q(voids)}, $goods, $deposit, "
      '$total)',
    );
    for (final (p, l) in lines.indexed) {
      await run(
        'INSERT INTO receipt_lines (receipt_id, position, item_id, name, '
        'unit_price_cents, quantity, unit_deposit_cents, '
        'gross${l.item.tax}_cents) VALUES '
        "('$id', $p, '${l.item.id}', ${_q(l.item.name)}, ${l.item.price}, "
        '${l.quantity}, ${l.item.deposit}, ${l.gross})',
      );
      for (final (o, (group, option, surcharge)) in l.options.indexed) {
        await run(
          'INSERT INTO receipt_line_options (receipt_id, line_position, '
          'position, group_name, option_name, surcharge_cents) VALUES '
          "('$id', $p, $o, '$group', '$option', $surcharge)",
        );
      }
    }
    if (kind == 'sale' || kind == 'voided') {
      final given = card
          ? 0
          : (total < 0 ? total : ((total + 999) ~/ 1000) * 1000);
      await run(
        'INSERT INTO payments (receipt_id, kind, amount_cents, given_cents, '
        'change_cents, provider, provider_tx_code, card_scheme, card_last4) '
        "VALUES ('$id', '${card ? 'card' : 'cash'}', $total, $given, "
        '${card ? 0 : given - total}, '
        "${card ? "'sumup', 'TX-$id', 'VISA', '4242'" : 'NULL, NULL, NULL, NULL'})",
      );
    }
    final c = chain;
    if (c != null) {
      position++;
      counter += total;
      await run(
        'INSERT INTO rksv_entries (chain, position, receipt_id, jws, damaged, '
        "cert_serial) VALUES (${c.chain}, $position, '$id', "
        "'eyJhbGciOiJFUzI1NiJ9.dGVzdA.c2lnLTAwMDA-${c.chain}-$position', 0, "
        "'${c.serial}')",
      );
    }
    return id;
  }

  for (var d = 0; d < _days; d++) {
    final dayId = 'day-${d + 1}';
    final morning = _t0 + d * _day;
    await run(
      'INSERT INTO business_days (id, opened_at, opening_float_cents) '
      "VALUES ('$dayId', ${morning + 1800}, 10000)",
    );

    for (var s = 0; s < _salesPerDay; s++) {
      final at = morning + 3600 + s * 300;
      final starting = [
        for (final c in _chains)
          if (c.startDay == d && s == (d == 0 ? _unsigned : 0)) c,
      ];
      for (final c in starting) {
        await run(
          'INSERT INTO rksv_chains (chain, mode, unit, cash_box_id, zda_id, '
          "cert_serial, started_at) VALUES (${c.chain}, 'probe', "
          "'${c.unit}', '${c.cashBoxId}', '${c.zdaId}', '${c.serial}', "
          '${at - 120})',
        );
        chain = c;
        position = 0;
        counter = 0;
        await receipt(at: at - 60, kind: 'start');
      }

      final seed = d * 100 + s;
      final card = seed % 3 == 0;
      final sale = await receipt(
        at: at,
        kind: 'sale',
        day: dayId,
        staff: _staff[1 + seed % 2],
        lines: _linesOf(seed),
        card: card,
      );
      // Jeder 13. Verkauf wird gleich wieder storniert.
      if (s % 13 == 5) {
        await receipt(
          at: at + 120,
          kind: 'voided',
          day: dayId,
          voids: sale,
          lines: _linesOf(seed, sign: -1),
          card: card,
        );
      }
    }

    final amount = 2000 + d * 500;
    await run(
      'INSERT INTO cash_movements (id, business_day_id, kind, amount_cents, '
      'reason, created_at, staff_id, staff_name) VALUES '
      "('move-${d + 1}', '$dayId', '${d.isEven ? 'withdrawal' : 'deposit'}', "
      "$amount, '${d.isEven ? 'bank' : 'change'}', ${morning + 5 * 3600}, "
      "'staff-chefin', 'Chefin')",
    );

    final c = chain;
    if (c != null && c.endDay == d) {
      final endedAt = morning + 13 * 3600;
      await receipt(at: endedAt - 60, kind: 'closing');
      await run(
        'UPDATE rksv_chains SET ended_at = $endedAt WHERE chain = ${c.chain}',
      );
      chain = null;
    }

    if (d < _days - 1) {
      final cash =
          (await db
                  .customSelect(
                    'SELECT COALESCE(SUM(p.amount_cents), 0) s FROM payments p '
                    'JOIN receipts r ON r.id = p.receipt_id '
                    "WHERE r.business_day_id = '$dayId' AND p.kind = 'cash'",
                  )
                  .getSingle())
              .read<int>('s');
      final expected = 10000 + cash + (d.isEven ? -amount : amount);
      await run(
        'UPDATE business_days SET closed_at = ${morning + 14 * 3600}, '
        'counted_cents = $expected, left_in_drawer_cents = 10000, '
        'expected_cents = $expected, difference_cents = 0, '
        "closed_by_name = 'Chefin' WHERE id = '$dayId'",
      );
    }
  }

  await run(
    'INSERT INTO rksv_state (id, mode, chain, counter_cents) '
    "VALUES (1, 'probe', ${chain!.chain}, $counter)",
  );
  await run('VACUUM');
  await db.close();
  stdout.writeln('Geschrieben: $_target ($number Bons)');
}
