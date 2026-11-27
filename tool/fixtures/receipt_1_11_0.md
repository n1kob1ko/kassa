# Bon von 1.11.0 als Testdateien

Hier steht, wie die Testdateien zum Punkt "Ein Bon, den 1.11.0 schon gesendet hat, kommt nach dem Update noch einmal" entstanden sind. Wer sie neu machen muss, findet hier die Befehle und das Programm dazu. Der Weg ist derselbe wie für 1.10.0 (`tool/fixtures/receipt_1_10_0.md`).

## Die drei Dateien

- `app/test/data/fixtures/kassa_v8_receipts_1_11_0.sqlite`: eine Datenbank des Tablets, Version 8 (1.11.0). Es ist eine Kopie von `app/test/data/fixtures/kassa_v8.sqlite`. Darin hat der echte Code von 1.11.0 im offenen Tag einen Bon "Teil bar, Rest Karte" verkauft: Huhn Bowl mit 10 % Stammgast-Rabatt und Cola, 1,00 € Aktions-Rabatt auf den Bon, 5,00 € bar, der Rest mit Karte, 0,50 € Trinkgeld, Mitarbeiterin Anna.
- `shared/fixtures/sync/receipt_1_11_0_v2.json`: der Bon so, wie 1.11.0 ihn an den Server sendet (`v: 2`).
- `shared/fixtures/sync/receipt_1_11_0_as_v3.json`: derselbe Bon so, wie die App heute ihn sendet (`v: 3`), aus derselben Datenbank nach der Migration 8 zu 9. Er unterscheidet sich nur durch `v: 3` und die neuen Felder mit leerem Wert (`publicToken` null, `vouchers` leer, die Gutschein-Felder der Zahlungen null).

Wer sie liest:

- `app/test/sync/receipt_1_11_0_test.dart` öffnet die Datenbank, migriert sie, baut die Sendung von heute und vergleicht sie mit `receipt_1_11_0_as_v3.json`. Mit `KASSA_WRITE_FIXTURES=1` schreibt er diese Datei neu, statt zu vergleichen.
- `server/test/push.test.ts` sendet zuerst `receipt_1_11_0_v2.json` (`accepted`), dann `receipt_1_11_0_as_v3.json` (`duplicate`, kein Bericht).

## So entstehen die Dateien

`<repo>` ist der Ordner dieses Projekts. `<ordner>` ist ein leerer Ordner außerhalb davon, für einen zweiten Arbeitsstand mit dem Code von 1.11.0 (Commit `a06aeb3`).

1. Den Stand von 1.11.0 als zweiten Arbeitsstand holen:
   ```
   cd <repo>
   git worktree add --detach <ordner> a06aeb3
   ```
2. Das Programm unten als `<ordner>/app/test/make_receipt_1_11_0_test.dart` speichern. Es ist ein Wegwerf-Test: Er kommt nicht ins Projekt.
3. Das Programm mit dem Code von 1.11.0 laufen lassen. Es liest `kassa_v8.sqlite` aus `<repo>` und schreibt die Datenbank und `receipt_1_11_0_v2.json` nach `<repo>`:
   ```
   cd <ordner>/app
   ~/flutter/bin/flutter pub get --offline
   KASSA_REPO=<repo> ~/flutter/bin/flutter test test/make_receipt_1_11_0_test.dart
   ```
4. Mit dem Code von heute die Datei `v: 3` schreiben und danach vergleichen:
   ```
   cd <repo>/app
   KASSA_WRITE_FIXTURES=1 ~/flutter/bin/flutter test test/sync/receipt_1_11_0_test.dart
   ~/flutter/bin/flutter test test/sync/receipt_1_11_0_test.dart
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

- `kassa_v8.sqlite` gab es in `a06aeb3` noch nicht (sie entstand in Stufe 1b, Task 1, mit dem Code von 1.11.0). Darum liest das Programm sie aus `<repo>` und öffnet sie mit der Datenbank von 1.11.0 (Version 8, keine Migration).
- Anders als in `kassa_v7.sqlite` hat der offene Tag in `kassa_v8.sqlite` schon eine UUID; das Programm verkauft darum direkt in diesen Tag. Die Bons `v8-0001` bis `v8-0004` und ihr Storno haben keine UUID; das Programm nimmt nur den neuen Bon (`eeeeeeee-1110-…`).
- Der Bon trägt `test: true`, weil in dieser Datenbank die Signatur aus ist. So sendet 1.11.0 ihn dann auch.
- Alles ist erfunden: Betrieb, Mitarbeiterin, Zahlungsanbieter `demo`, Transaktion `TX-BEISPIEL-1110`, Karte `0000`.

## Das Programm

```dart
// Wegwerf-Test im Stand 1.11.0 (a06aeb3): verkauft in eine Kopie von
// kassa_v8.sqlite einen Bon "Teil bar, Rest Karte" mit Trinkgeld und Rabatt
// und schreibt die Sendung, wie 1.11.0 sie baut.
//
// Aufruf aus app/ des Worktrees:
//   KASSA_REPO=<repo> flutter test test/make_receipt_1_11_0_test.dart

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
import 'package:kassa/domain/discount.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/sync/push_wire.dart';

void main() {
  test('Bon von 1.11.0 in eine Kopie von kassa_v8.sqlite', () async {
    final repo = Platform.environment['KASSA_REPO']!;
    final source = File('$repo/app/test/data/fixtures/kassa_v8.sqlite');
    final target = File(
      '$repo/app/test/data/fixtures/kassa_v8_receipts_1_11_0.sqlite',
    );
    source.copySync(target.path);
    final db = KassaDatabase(NativeDatabase(target));
    expect(db.schemaVersion, 8);
    final clock = FixedClock(DateTime.utc(2026, 11, 26, 12, 30));
    const anna = Staff(id: 'staff-anna', name: 'Anna', role: StaffRole.staff);
    final days = DayRepository(db, clock);
    final receipts = ReceiptRepository(db, clock, days);

    // Der offene Tag hat schon eine UUID, der Bon gehört zu ihm.
    final open = (await days.openDay())!;
    expect(
      open.id,
      matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')),
    );

    final catalog = (await CatalogRepository(db, clock: clock).current())!;
    final bowl = catalog.item('huhn-bowl');
    final cola = catalog.item('cola');
    var cart = const Cart.empty()
        .add(bowl, lineId: 'e1110-line-1')
        .add(cola, lineId: 'e1110-line-2');
    cart = cart
        .setLineDiscount(
          'e1110-line-1',
          const Discount.percent(10, DiscountReason.regular),
        )
        .setReceiptDiscount(const Discount.amount(100, DiscountReason.promotion));

    await receipts.finalizeCardSale(
      saleId: 'eeeeeeee-1110-4000-8000-000000000001',
      cart: cart,
      staff: anna,
      provider: 'demo',
      txCode: 'TX-BEISPIEL-1110',
      cardScheme: 'VISA',
      cardLast4: '0000',
      cashPartCents: 500,
      tipCents: 50,
    );

    final payloads = PushPayloads(db);
    final entries = <Map<String, Object?>>[];
    for (final e in await OutboxRepository(db).nextBatch()) {
      if (e.kind == 'receipt' && e.ref.startsWith('eeeeeeee-1110')) {
        entries.add((await payloads.build(e))!);
      }
    }
    expect(entries, hasLength(1));
    await db.close();

    final out = File('$repo/shared/fixtures/sync/receipt_1_11_0_v2.json');
    out.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({'entries': entries})}\n',
    );
  });
}
```
