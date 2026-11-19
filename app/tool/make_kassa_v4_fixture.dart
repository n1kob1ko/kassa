// Erzeugt test/data/fixtures/kassa_v4_outbox.sqlite: eine Datenbank im Stand
// von Version 4 (das Schema kommt aus dem Abzug schema_v4.dart, nicht aus dem
// heutigen Code), gefüllt mit erfundenen Daten. Aufruf aus `app/`:
//
//   dart run tool/make_kassa_v4_fixture.dart
//
// Inhalt: zwei Tage (der erste abgeschlossen), eine Bargeld-Bewegung, vier
// Bons (Verkauf bar, Startbeleg, Verkauf Karte, Storno), eine Probe-Kette mit
// Zertifikat und drei Einträgen im Protokoll, drei Artikel, die Kassa ist
// gekoppelt. Keine echten Namen, keine Adresse, kein Schlüssel.
//
// Trigger und Indizes von Version 4 entstehen in `KassaDatabase.onCreate`,
// nicht im Abzug; sie stehen in `fixture_guards.dart` noch einmal so, wie sie
// in Version 4 waren.
//
// Daneben liegt `kassa_v4.sqlite` aus dem Signatur-Thread (zwei Probe-Ketten
// mit echten Signaturen, ohne Skript im Repository). Die Tests der Liste
// "noch zu senden" brauchen die Kopplung, die Bewegung und die zwei Tage, die
// nur diese Datei hat.

import 'dart:io';

import 'package:drift/native.dart';

import '../test/data/generated_migrations/schema_v4.dart';
import 'fixture_guards.dart';

const _target = 'test/data/fixtures/kassa_v4_outbox.sqlite';

/// 2026-11-16 08:00:00 UTC in Sekunden, die Grundlage aller Zeiten.
const _t0 = 1794816000;

Future<void> main() async {
  final file = File(_target);
  if (file.existsSync()) file.deleteSync();
  final db = DatabaseAtV4(NativeDatabase(file));

  Future<void> run(String sql) => db.customStatement(sql);

  // Löst onCreate des Abzugs aus: alle Tabellen von Version 4.
  await run('SELECT 1');

  await createV4Guards(run);

  await run(
    "INSERT INTO business (id, name, address_lines) "
    "VALUES (1, 'Beispiel-Imbiss', 'Musterstraße 1\n1010 Wien')",
  );
  await run("INSERT INTO settings (id) VALUES (1)");
  await run(
    "INSERT INTO rksv_state (id, mode, chain, counter_cents) "
    "VALUES (1, 'probe', 1, 1480)",
  );
  // Gekoppelt, aber noch nichts gesendet. Keine Adresse, nur Platzhalter.
  await run(
    'INSERT INTO sync_state (id, register_id, register_name, business_id, '
    'pull_cursor, initial_pull_done) '
    "VALUES (1, 'test-register', 'Kassa 1', 'test-business', 12, 1)",
  );

  await run(
    "INSERT INTO staff (id, name, role, pin_salt, pin_hash) VALUES "
    "('staff-chefin', 'Chefin', 'chef', 'salt', 'hash'), "
    "('staff-anna', 'Anna', 'staff', 'salt', 'hash')",
  );

  await run(
    "INSERT INTO categories (id, name, position) VALUES "
    "('bowls', 'Bowls', 0), ('snacks', 'Snacks', 1), ('getraenke', 'Getränke', 2)",
  );
  await run(
    'INSERT INTO items (id, name, price_cents, category_id, tax_percent, '
    'deposit_cents, tags, info, favorite, in_sale, position) VALUES '
    "('huhn-bowl', 'Huhn Bowl', 990, 'bowls', 10, 0, 'spicy', NULL, 0, 1, 0), "
    "('teigtaschen', 'Teigtaschen', 650, 'snacks', 10, 0, '', '5 Stück', 0, 0, 1), "
    "('cola', 'Cola 0,33 l', 290, 'getraenke', 20, 25, 'vegan,spicy', NULL, 1, 1, 2)",
  );

  // Zwei Tage: der erste abgeschlossen, der zweite offen.
  const day1 = 'day-1';
  const day2 = 'day-2';
  await run(
    'INSERT INTO business_days (id, opened_at, closed_at, opening_float_cents, '
    'counted_cents, left_in_drawer_cents, expected_cents, difference_cents, '
    'closed_by_name) VALUES '
    "('$day1', ${_t0 + 3600}, ${_t0 + 36000}, 10000, 11300, 10000, 11300, 0, 'Chefin')",
  );
  await run(
    'INSERT INTO business_days (id, opened_at, opening_float_cents) '
    "VALUES ('$day2', ${_t0 + 86400 + 3600}, 10000)",
  );

  await run(
    'INSERT INTO cash_movements (id, business_day_id, kind, amount_cents, '
    'reason, created_at, staff_id, staff_name) '
    "VALUES ('move-1', '$day1', 'withdrawal', 2000, 'bank', ${_t0 + 30000}, "
    "'staff-chefin', 'Chefin')",
  );

  // Zertifikat und Probe-Kette (Seriennummer und Kennung erfunden).
  await run(
    'INSERT INTO rksv_certificates (serial_hex, certificate, issuers) '
    "VALUES ('0a1b2c', x'3082', '[]')",
  );
  await run(
    'INSERT INTO rksv_chains (chain, mode, cash_box_id, zda_id, cert_serial, '
    "started_at) VALUES (1, 'probe', 'TESTKASSA1', 'AT0', '0a1b2c', ${_t0 + 90000})",
  );

  Future<void> receipt(
    String id,
    int number,
    int at,
    String kind,
    int total, {
    String? day,
    String? voids,
    String? staff,
  }) => run(
    'INSERT INTO receipts (id, number, created_at, staff_id, staff_name, '
    'business_day_id, kind, voids_receipt_id, goods_cents, deposit_cents, '
    'total_cents) VALUES ('
    "'$id', $number, $at, 'staff-anna', 'Anna', "
    "${day == null ? 'NULL' : "'$day'"}, '$kind', "
    "${voids == null ? 'NULL' : "'$voids'"}, ${total > 0 ? total - 50 : total + 50}, "
    "${total == 0 ? 0 : (total > 0 ? 50 : -50)}, $total)",
  );

  Future<void> line(String receiptId, int quantity, int price, int gross20) =>
      run(
        'INSERT INTO receipt_lines (receipt_id, position, item_id, name, '
        'unit_price_cents, quantity, unit_deposit_cents, gross20_cents) '
        "VALUES ('$receiptId', 0, 'cola', 'Cola 0,33 l', $price, $quantity, "
        '25, $gross20)',
      );

  Future<void> payment(String receiptId, String kind, int amount) => run(
    'INSERT INTO payments (receipt_id, kind, amount_cents, given_cents, '
    'change_cents, provider, provider_tx_code) VALUES '
    "('$receiptId', '$kind', $amount, ${kind == 'cash' ? 2000 : 0}, "
    "${kind == 'cash' ? 2000 - amount : 0}, "
    "${kind == 'card' ? "'sumup', 'TX-1'" : 'NULL, NULL'})",
  );

  // 1 Verkauf bar (vor der Probe), 2 Startbeleg, 3 Verkauf Karte, 4 Storno.
  await receipt('v4-bar', 1, _t0 + 7200, 'sale', 640, day: day1);
  await line('v4-bar', 2, 290, 580);
  await payment('v4-bar', 'cash', 640);

  await receipt('v4-start', 2, _t0 + 90000, 'start', 0);

  await receipt('v4-karte', 3, _t0 + 86400 + 7200, 'sale', 340, day: day2);
  await line('v4-karte', 1, 290, 290);
  await payment('v4-karte', 'card', 340);

  await receipt(
    'v4-storno',
    4,
    _t0 + 86400 + 7500,
    'voided',
    -340,
    day: day2,
    voids: 'v4-karte',
  );
  await line('v4-storno', -1, 290, -290);
  await payment('v4-storno', 'card', -340);

  // Protokoll: Startbeleg, Verkauf Karte, Storno.
  Future<void> entry(int position, String receiptId) => run(
    'INSERT INTO rksv_entries (chain, position, receipt_id, jws, damaged, '
    "cert_serial) VALUES (1, $position, '$receiptId', 'e30.e30.e30', 0, '0a1b2c')",
  );
  await entry(1, 'v4-start');
  await entry(2, 'v4-karte');
  await entry(3, 'v4-storno');

  await db.close();
  stdout.writeln('Geschrieben: $_target');
}
