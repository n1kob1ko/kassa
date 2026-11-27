// Helfer für Tests des digitalen Bons (Spec 5.4): eine Kassa mit Server und
// Platz beim Server ("gekoppelt"), ohne dass der Abgleich läuft. Was der
// Server bestätigt, nimmt der Test selbst aus "noch zu senden".

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app_sync_providers.dart';
import 'package:kassa/data/outbox_repository.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/ui/qr_view.dart';
import 'package:material_ui/material_ui.dart';

import 'kassa_pump.dart';
import 'pump.dart';

/// Die erfundene Adresse des Servers in diesen Tests.
const testServerUrl = 'https://kassa.example';

/// [base] (Standard: [memoryOverrides]) mit einer Adresse des Servers.
Future<List<Override>> serverKassaOverrides({List<Override>? base}) async => [
  ...base ?? await memoryOverrides(),
  hasServerProvider.overrideWithValue(true),
  serverUrlProvider.overrideWithValue(testServerUrl),
];

/// Gibt der Kassa einen Platz beim Server, wie nach dem Koppeln. Die Daten
/// des Betriebs gelten als nicht geladen: der Abgleich beginnt nicht.
Future<void> pairRegister(WidgetTester t) async {
  await containerOf(t)
      .read(syncStateRepositoryProvider)
      .saveRegister(
        registerId: 'kassa-1',
        registerName: 'Kassa 1',
        businessId: 'betrieb-1',
      );
  await t.pump();
}

/// Der Server hat den Bon [receiptId] bestätigt: sein Eintrag `receipt`
/// geht aus "noch zu senden".
Future<void> serverConfirms(WidgetTester t, String receiptId) async {
  final outbox = containerOf(t).read(outboxRepositoryProvider);
  for (final OutboxEntry e in await outbox.nextBatch(limit: 1000)) {
    if (e.kind == 'receipt' && e.ref == receiptId) {
      await outbox.remove(e.id, rev: e.rev);
    }
  }
  await t.pump();
}

/// Die Id des zuletzt gespeicherten Bons.
Future<String> lastReceiptId(WidgetTester t) async {
  final row = await containerOf(t)
      .read(databaseProvider)
      .customSelect('SELECT id FROM receipts ORDER BY number DESC LIMIT 1')
      .getSingle();
  return row.read<String>('id');
}

/// Der zuletzt gespeicherte Bon.
Future<Receipt> lastReceipt(WidgetTester t) async => (await containerOf(
  t,
).read(receiptRepositoryProvider).find(await lastReceiptId(t)))!;

/// Der Text im QR-Code mit dem Schlüssel [key].
String qrTextOf(WidgetTester t, String key) =>
    t.widget<QrView>(find.byKey(Key(key))).data;
