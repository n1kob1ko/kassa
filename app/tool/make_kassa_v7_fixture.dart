// Erzeugt test/data/fixtures/kassa_v7.sqlite: eine Datenbank im Stand der
// ausgelieferten Version 1.10.0 (Datenbank Version 7). Das Schema kommt aus
// dem Abzug schema_v7.dart, nicht aus dem heutigen Code. Aufruf aus `app/`:
//
//   dart run tool/make_kassa_v7_fixture.dart
//
// Inhalt (alles erfunden, keine echten Namen, keine Schlüssel): ein Imbiss mit
// Einstellungen, die von den Vorgaben abweichen (Schublade aus, dunkel,
// Netzwerk-Drucker, Sprache Türkisch, Küchenbon am Bondrucker), ein
// gekoppeltes Tablet (Stand 40, erster Abgleich fertig), zwei Tage (einer
// abgeschlossen), eine Bargeld-Bewegung und sechs Bons mit Zeilen, Auswahl und
// Zahlung (einer mit Karte, einer storniert). Dazu eine offene Kartenzahlung
// und ein Entwurf des offenen Bons, beide in der Form von 1.10.0. Die Liste
// der Sendungen füllen die Trigger von Version 7 mit.

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';

import '../test/data/generated_migrations/schema_v7.dart';
import 'fixture_guards.dart';

const _target = 'test/data/fixtures/kassa_v7.sqlite';

/// 2026-11-20 06:00:00 UTC in Sekunden.
const _t0 = 1795154400;
const _day = 86400;

/// Die Trigger der Liste, wie `_createOutboxTriggers` sie in Version 6 und 7
/// anlegt.
const _outboxTriggers = [
  ('receipts', 'INSERT', 'receipt', 'NEW.id'),
  ('rksv_entries', 'INSERT', 'receipt', 'NEW.receipt_id'),
  ('business_days', 'INSERT', 'day', 'NEW.id'),
  ('business_days', 'UPDATE', 'day', 'NEW.id'),
  ('cash_movements', 'INSERT', 'cash_movement', 'NEW.id'),
  ('rksv_certificates', 'INSERT', 'rksv_certificate', 'NEW.serial_hex'),
  ('rksv_chains', 'INSERT', 'rksv_chain', 'NEW.chain'),
  ('rksv_chains', 'UPDATE', 'rksv_chain', 'NEW.chain'),
  ('reports', 'INSERT', 'report', 'NEW.id'),
  ('reports', 'UPDATE', 'report', 'NEW.id'),
];

/// Ein Bon mit einer Huhn Bowl und einer Cola (mit Pfand), wie ihn
/// `Cart.toJson` in 1.10.0 schreibt.
String _cartJson(String prefix) => jsonEncode({
  'lines': [
    {
      'lineId': '$prefix-line-1',
      'itemId': 'huhn-bowl',
      'quantity': 1,
      'optionIds': <String>[],
    },
    {
      'lineId': '$prefix-line-2',
      'itemId': 'cola',
      'quantity': 1,
      'optionIds': <String>[],
    },
  ],
});

Future<void> main() async {
  final file = File(_target);
  if (file.existsSync()) file.deleteSync();
  final db = DatabaseAtV7(NativeDatabase(file));

  Future<void> run(String sql) => db.customStatement(sql);
  String quote(String s) => "'${s.replaceAll("'", "''")}'";

  // Löst onCreate des Abzugs aus: alle Tabellen von Version 7.
  await run('SELECT 1');
  await createV4Guards(run);
  await run(
    'CREATE UNIQUE INDEX outbox_entity ON outbox (kind, ref) '
    "WHERE kind <> 'item_change'",
  );
  for (final (table, event, kind, ref) in _outboxTriggers) {
    await run(
      'CREATE TRIGGER outbox_${table}_${event.toLowerCase()} '
      'AFTER $event ON $table BEGIN '
      'UPDATE outbox SET rev = rev + 1 '
      "WHERE kind = '$kind' AND kind <> 'item_change' AND ref = $ref; "
      "INSERT OR IGNORE INTO outbox (kind, ref) VALUES ('$kind', $ref); END",
    );
  }

  await run(
    'INSERT INTO business (id, name, address_lines, receipt_footer) VALUES '
    "(1, 'Beispiel-Imbiss', 'Musterstraße 1\n1010 Wien', 'Danke!')",
  );
  await run(
    'INSERT INTO settings (id, cash_drawer_enabled, show_images, theme_mode, '
    'void_requires_chef, receipt_draft, printer_kind, printer_address, '
    'printer_name, printer_columns, printer_qr_as_image, language, '
    'kitchen_mode) VALUES '
    "(1, 0, 1, 'dark', 1, ${quote(_cartJson('draft'))}, 'network', "
    "'192.168.1.50:9100', 'Bondrucker', 42, 1, 'tr', 'receiptPrinter')",
  );
  // Gekoppelt, keine Adresse, nur Platzhalter.
  await run(
    'INSERT INTO sync_state (id, register_id, register_name, business_id, '
    'pull_cursor, initial_pull_done, last_pull_at, device_id) VALUES '
    "(1, 'test-register', 'Kassa 1', 'test-business', 40, 1, "
    "${_t0 + _day}, 'test-device')",
  );
  await run(
    'INSERT INTO staff (id, name, role, pin_salt, pin_hash) VALUES '
    "('staff-chefin', 'Chefin', 'chef', 'salt', 'hash'), "
    "('staff-anna', 'Anna', 'staff', 'salt', 'hash')",
  );
  await run(
    'INSERT INTO categories (id, name, position) VALUES '
    "('bowls', 'Bowls', 0), ('getraenke', 'Getränke', 1)",
  );
  await run(
    'INSERT INTO items (id, name, price_cents, category_id, tax_percent, '
    'deposit_cents, tags, favorite, in_sale, position) VALUES '
    "('huhn-bowl', 'Huhn Bowl', 1090, 'bowls', 10, 0, '', 0, 1, 0), "
    "('cola', 'Cola 0,33 l', 320, 'getraenke', 20, 25, '', 1, 1, 1)",
  );

  const total = 1090 + 320 + 25;
  for (final (d, closed) in const [(0, true), (1, false)]) {
    final morning = _t0 + d * _day;
    await run(
      'INSERT INTO business_days (id, opened_at, opening_float_cents) '
      "VALUES ('day-${d + 1}', ${morning + 1800}, 10000)",
    );
    for (var s = 0; s < 3; s++) {
      final n = d * 3 + s + 1;
      final id = 'v7-${n.toString().padLeft(4, '0')}';
      final at = morning + 3600 + s * 300;
      final voided = d == 0 && s == 0;
      final card = d == 1 && s == 1;
      await run(
        'INSERT INTO receipts (id, number, created_at, staff_id, staff_name, '
        'business_day_id, kind, goods_cents, deposit_cents, total_cents) '
        "VALUES ('$id', $n, $at, 'staff-anna', 'Anna', 'day-${d + 1}', "
        "'${voided ? 'voided' : 'sale'}', ${1090 + 320}, 25, $total)",
      );
      await run(
        'INSERT INTO receipt_lines (receipt_id, position, item_id, name, '
        'unit_price_cents, quantity, unit_deposit_cents, gross10_cents) '
        "VALUES ('$id', 0, 'huhn-bowl', 'Huhn Bowl', 1090, 1, 0, 1090)",
      );
      await run(
        'INSERT INTO receipt_lines (receipt_id, position, item_id, name, '
        'unit_price_cents, quantity, unit_deposit_cents, gross20_cents) '
        "VALUES ('$id', 1, 'cola', 'Cola 0,33 l', 320, 1, 25, 320)",
      );
      await run(
        'INSERT INTO receipt_line_options (receipt_id, line_position, '
        'position, group_name, option_name, surcharge_cents) '
        "VALUES ('$id', 0, 0, 'Größe', 'Normal', 0)",
      );
      if (card) {
        await run(
          'INSERT INTO payments (receipt_id, kind, amount_cents, given_cents, '
          'change_cents, provider, provider_tx_code, card_scheme, '
          "card_last4) VALUES ('$id', 'card', $total, 0, 0, 'demo', "
          "'TX-DEMO-0001', 'VISA', '0000')",
        );
      } else {
        await run(
          'INSERT INTO payments (receipt_id, kind, amount_cents, given_cents, '
          "change_cents) VALUES ('$id', 'cash', $total, 1500, ${1500 - total})",
        );
      }
    }
    await run(
      'INSERT INTO cash_movements (id, business_day_id, kind, amount_cents, '
      'reason, created_at, staff_id, staff_name) VALUES '
      "('move-${d + 1}', 'day-${d + 1}', 'deposit', 500, 'change', "
      "${morning + 5 * 3600}, 'staff-chefin', 'Chefin')",
    );
    if (closed) {
      await run(
        'UPDATE business_days SET closed_at = ${morning + 14 * 3600}, '
        'counted_cents = 14500, left_in_drawer_cents = 10000, '
        'expected_cents = 14500, difference_cents = 0, '
        "closed_by_name = 'Chefin' WHERE id = 'day-${d + 1}'",
      );
    }
  }

  // Eine Kartenzahlung, die am Terminal gestartet, aber noch kein Bon ist.
  await run(
    'INSERT INTO pending_card_payments (id, cart_json, amount_cents, '
    'staff_id, staff_name, started_at, state) VALUES '
    "('v7-pending-0001', ${quote(_cartJson('pending'))}, $total, "
    "'staff-anna', 'Anna', ${_t0 + _day + 6 * 3600}, 'started')",
  );

  await run("INSERT INTO rksv_state (id, mode) VALUES (1, 'off')");
  await run('VACUUM');
  await db.close();
  stdout.writeln('Geschrieben: $_target (6 Bons)');
}
