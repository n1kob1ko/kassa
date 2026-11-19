// Trigger und Indizes, die `KassaDatabase.onCreate` in Version 4 anlegte und
// die Version 5 (1.5.0) unverändert ließ. Die Abzüge in
// `test/data/generated_migrations/` enthalten nur Tabellen; die Werkzeuge für
// die Test-Dateien legen diese hier dazu.

/// Legt die Trigger und Indizes von Version 4 und 5 über [run] an.
Future<void> createV4Guards(Future<void> Function(String sql) run) async {
  await run(
    'CREATE UNIQUE INDEX receipts_voids_receipt_id ON receipts (voids_receipt_id)',
  );
  await run(
    'CREATE UNIQUE INDEX business_days_one_open '
    'ON business_days ((closed_at IS NULL)) WHERE closed_at IS NULL',
  );
  for (final action in const ['UPDATE', 'DELETE']) {
    final a = action.toLowerCase();
    await run(
      'CREATE TRIGGER cash_movements_no_$a BEFORE $action ON cash_movements '
      "BEGIN SELECT RAISE(ABORT, 'Bargeld-Bewegungen sind unveränderlich'); END",
    );
    for (final table in const [
      'receipts',
      'receipt_lines',
      'receipt_line_options',
      'payments',
    ]) {
      await run(
        'CREATE TRIGGER ${table}_no_$a BEFORE $action ON $table '
        "BEGIN SELECT RAISE(ABORT, 'Bons sind unveränderlich'); END",
      );
    }
    await run(
      'CREATE TRIGGER rksv_entries_no_$a BEFORE $action ON rksv_entries '
      "BEGIN SELECT RAISE(ABORT, 'Das Protokoll ist unveränderlich'); END",
    );
    await run(
      'CREATE TRIGGER rksv_certificates_no_$a '
      'BEFORE $action ON rksv_certificates '
      "BEGIN SELECT RAISE(ABORT, 'Zertifikate sind unveränderlich'); END",
    );
  }
  await run(
    'CREATE TRIGGER business_days_no_update_closed '
    'BEFORE UPDATE ON business_days WHEN OLD.closed_at IS NOT NULL BEGIN '
    "SELECT RAISE(ABORT, 'Abgeschlossene Tage sind unveränderlich'); END",
  );
  await run(
    'CREATE TRIGGER business_days_no_delete BEFORE DELETE ON business_days '
    "BEGIN SELECT RAISE(ABORT, 'Tage können nicht gelöscht werden'); END",
  );
  await run(
    'CREATE TRIGGER rksv_chains_no_update_ended '
    'BEFORE UPDATE ON rksv_chains WHEN OLD.ended_at IS NOT NULL BEGIN '
    "SELECT RAISE(ABORT, 'Beendete Ketten sind unveränderlich'); END",
  );
  await run(
    'CREATE TRIGGER rksv_chains_no_delete BEFORE DELETE ON rksv_chains '
    "BEGIN SELECT RAISE(ABORT, 'Ketten können nicht gelöscht werden'); END",
  );
}
