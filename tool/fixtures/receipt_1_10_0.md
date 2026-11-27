# Bons von 1.10.0 als Testdateien

Hier steht, wie die Testdateien zum Punkt "Ein Bon, den 1.10.0 schon gesendet hat, kommt nach dem Update noch einmal" entstanden sind. Wer sie neu machen muss, findet hier die Befehle und das Programm dazu.

## Die drei Dateien

- `app/test/data/fixtures/kassa_v7_receipts_1_10_0.sqlite`: eine Datenbank des Tablets, Version 7 (1.10.0). Es ist eine Kopie von `app/test/data/fixtures/kassa_v7.sqlite`. Darin hat der echte Code von 1.10.0 den offenen Tag `day-2` abgeschlossen und dann zwei Bons verkauft: einen Barbon und einen Kartenbon (Huhn Bowl und Cola, Mitarbeiterin Anna).
- `shared/fixtures/sync/receipt_1_10_0_v1.json`: die zwei Bons so, wie 1.10.0 sie an den Server sendet (`v: 1`).
- `shared/fixtures/sync/receipt_1_10_0_as_v2.json`: dieselben zwei Bons so, wie die App heute sie sendet (`v: 2`), aus derselben Datenbank nach der Migration 7 zu 8.

Wer sie liest:

- `app/test/sync/receipt_1_10_0_test.dart` öffnet die Datenbank, migriert sie, baut die Sendung von heute und vergleicht sie mit `receipt_1_10_0_as_v2.json`. Mit `KASSA_WRITE_FIXTURES=1` schreibt er diese Datei neu, statt zu vergleichen.
- `server/test/push.test.ts` sendet zuerst `receipt_1_10_0_v1.json` (alles `accepted`), dann `receipt_1_10_0_as_v2.json` (alles `duplicate`, kein Bericht).

## So entstehen die Dateien

`<repo>` ist der Ordner dieses Projekts. `<ordner>` ist ein leerer Ordner außerhalb davon, für einen zweiten Arbeitsstand mit dem Code von 1.10.0 (Commit `3b1e4d4`).

1. Den Stand von 1.10.0 als zweiten Arbeitsstand holen:
   ```
   cd <repo>
   git worktree add --detach <ordner> 3b1e4d4
   ```
2. Das Programm unten als `<ordner>/app/test/make_receipt_1_10_0_test.dart` speichern. Es ist ein Wegwerf-Test: Er kommt nicht ins Projekt.
3. Das Programm mit dem Code von 1.10.0 laufen lassen. Es liest `kassa_v7.sqlite` aus `<repo>` und schreibt die Datenbank und `receipt_1_10_0_v1.json` nach `<repo>`:
   ```
   cd <ordner>/app
   KASSA_REPO=<repo> ~/flutter/bin/flutter test test/make_receipt_1_10_0_test.dart
   ```
4. Mit dem Code von heute die Datei `v: 2` schreiben und danach vergleichen:
   ```
   cd <repo>/app
   KASSA_WRITE_FIXTURES=1 ~/flutter/bin/flutter test test/sync/receipt_1_10_0_test.dart
   ~/flutter/bin/flutter test test/sync/receipt_1_10_0_test.dart
   ```
5. Am Server prüfen (Test-Datenbank vorher mit `server/tool/test-db.sh start`):
   ```
   cd <repo>/server
   npx vitest run test/push.test.ts
   ```
6. Den zweiten Arbeitsstand wieder entfernen:
   ```
   cd <repo>
   git worktree remove --force <ordner>
   ```

Wichtig:

- `kassa_v7.sqlite` gab es in `3b1e4d4` noch nicht (sie entstand beim Bau von 1.11.0). Darum liest das Programm sie aus `<repo>` und öffnet sie mit der Datenbank von 1.10.0 (Version 7, keine Migration).
- Die Bons in `kassa_v7.sqlite` und der offene Tag `day-2` haben keine UUID, der Server würde sie ablehnen. Darum schließt das Programm `day-2` zuerst und verkauft dann neu.
- Der neue Tag bekommt bei jedem Lauf eine neue, zufällige Kennung. Sie steht in der Datenbank, und beide JSON-Dateien lesen sie daraus. Nach einem neuen Lauf von Schritt 3 müssen darum beide JSON-Dateien neu geschrieben werden: `receipt_1_10_0_v1.json` schreibt Schritt 3 selbst, `receipt_1_10_0_as_v2.json` Schritt 4.
- Die Bons tragen `test: true`, weil in dieser Datenbank die Signatur aus ist. So sendet 1.10.0 sie dann auch.

## Das Programm

```dart
// Wegwerf-Test im Stand 1.10.0 (3b1e4d4): verkauft in eine Kopie von
// kassa_v7.sqlite einen Barbon und einen Kartenbon und schreibt die
// Sendungen, wie 1.10.0 sie baut.
//
// Aufruf aus app/ des Worktrees:
//   KASSA_REPO=<repo> flutter test test/make_receipt_1_10_0_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/catalog_repository.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/day_repository.dart';
import 'package:kassa/data/outbox_repository.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/sync/push_wire.dart';

void main() {
  test('Bons von 1.10.0 in eine Kopie von kassa_v7.sqlite', () async {
    final repo = Platform.environment['KASSA_REPO']!;
    final source = File('$repo/app/test/data/fixtures/kassa_v7.sqlite');
    final target = File(
      '$repo/app/test/data/fixtures/kassa_v7_receipts_1_10_0.sqlite',
    );
    source.copySync(target.path);
    final db = KassaDatabase(NativeDatabase(target));
    final clock = FixedClock(DateTime.utc(2026, 11, 21, 19));
    const chefin = Staff(id: 'staff-chefin', name: 'Chefin', role: StaffRole.chef);
    const anna = Staff(id: 'staff-anna', name: 'Anna', role: StaffRole.staff);
    final days = DayRepository(db, clock);
    final receipts = ReceiptRepository(db, clock, days);

    // Der offene Tag "day-2" hat keine UUID, die nimmt der Server nicht:
    // abschließen, der nächste Bon beginnt einen neuen Tag.
    final open = (await days.openDay())!;
    expect(open.id, 'day-2');
    await days.close(countedCents: 0, leftInDrawerCents: 0, staff: chefin);

    final catalog = (await CatalogRepository(db, clock: clock).current())!;
    final bowl = catalog.item('huhn-bowl');
    final cola = catalog.item('cola');
    final cart = const Cart.empty().add(bowl).add(cola);

    clock.value = DateTime.utc(2026, 11, 22, 9, 15);
    await receipts.finalizeCashSale(
      saleId: 'eeeeeeee-1100-4000-8000-000000000001',
      cart: cart,
      givenCents: 2000,
      staff: anna,
    );
    clock.value = DateTime.utc(2026, 11, 22, 9, 20);
    await receipts.finalizeCardSale(
      saleId: 'eeeeeeee-1100-4000-8000-000000000002',
      cart: cart,
      staff: anna,
      provider: 'sumup',
      txCode: 'TX-BEISPIEL-1100',
      cardScheme: 'VISA',
      cardLast4: '4242',
    );

    final payloads = PushPayloads(db);
    final entries = <Map<String, Object?>>[];
    for (final e in await OutboxRepository(db).nextBatch()) {
      if (e.kind == 'receipt' && e.ref.startsWith('eeeeeeee-1100')) {
        entries.add((await payloads.build(e))!);
      }
    }
    expect(entries, hasLength(2));
    await db.close();

    final out = File('$repo/shared/fixtures/sync/receipt_1_10_0_v1.json');
    out.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({'entries': entries})}\n',
    );
  });
}
```
