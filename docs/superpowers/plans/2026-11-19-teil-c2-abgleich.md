# Teil C2: Abgleich, Fotos, Umsätze Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bons, Tage, Bargeld-Bewegungen und das Protokoll der Signatur gehen vom Tablet zum Server, Artikel-Änderungen gleichen sich in beide Richtungen ab, Fotos und Logo kommen vom Browser aufs Tablet, die Verwaltung zeigt Umsätze, Bons und Tagesabschlüsse, Fehler vom Tablet landen am Server, und der Server sichert sich jede Nacht.

**Architecture:** Am Tablet schreibt die Datenbank selbst (SQLite-Trigger) eine Liste "noch zu senden" (`outbox`). Der `SyncService` bekommt vor dem Holen einen Schritt "senden" (`POST /api/device/sync/push`, höchstens 100 Einträge) und danach einen Schritt "Dateien laden". Der Server legt jeden Bon einmal als Original (`payload jsonb`) und daneben in Spalten ab, erkennt Wiederholungen an einer Prüfsumme und lehnt so wenig wie möglich ab. Protokoll der Signatur und Tage hängen an einer Geräte-Kennung, nicht am Eintrag "Kassa". Auswertungen rechnet der Server nach denselben Regeln wie `app/lib/data/stats_repository.dart`, geprüft gegen ein gemeinsames Beispiel.

**Tech Stack:** wie C1 (Node 22, TypeScript 7.0, Fastify 5.12, `pg` 8.23, `zod` 4.6, `vitest` 5.1; React 19.3, Vite 8.3, `react-router` 8.5, `@tanstack/react-query` 5.108, Playwright 1.63.0; Flutter 3.50.0, drift, riverpod, `http`). Neu am Server: `sharp` (Bilder). Neu in der App: `path_provider` und `device_info_plus`, falls noch nicht vorhanden. Bei jeder neuen Bibliothek die aktuelle Version und ihre Dokumentation nachsehen, nicht aus dem Gedächtnis schreiben. Diagramme in der Verwaltung ohne Bibliothek (Balken aus SVG oder CSS, Regeln aus dem Skill `dataviz`).

**Spec:** `docs/superpowers/specs/2026-11-19-teil-c2-abgleich-design.md`. Dahinter `docs/superpowers/specs/2026-11-18-teil-c-server-und-verwaltung-design.md` (vor allem 5.5 bis 5.8, 5.10 bis 5.13), `docs/superpowers/specs/2026-11-18-rksv-signatur-design.md` (6.11), `PRODUCT.md`, `DESIGN.md`, `docs/design-regeln.md`.

## Wo dieser Plan steht

| Plan | Inhalt | Stand |
|---|---|---|
| C1 | Server, Anmeldung, Kopplung, holen, Installationsdatei | fertig, übergeben (1.2.0) |
| **C2 (dieser Plan)** | senden, Artikel-Änderungen, Fotos, Seiten Umsätze/Bons/Tage, Berichte, Sicherung | geschrieben |
| C3 | Verwaltung für den Chef | nach C2, Bilder vorher zu Niko |
| Übernahme auf ein Ersatz-Tablet | eigener Schritt vor S3 der Signatur | nicht geplant |

Reihenfolge der Aufgaben: Server für das Senden (1 bis 4), App (5 bis 11), Server für die Verwaltung (12 bis 15), Seiten (16 bis 19), Zusammenspiel und Übergabe (20, 21). Die App-Aufgabe 6 schreibt zwei gemeinsame Beispiele, die Aufgaben 12 und 13 am Server brauchen.

## Global Constraints

- Alles aus den Global Constraints von C1 gilt weiter (`docs/superpowers/plans/2026-11-18-teil-c1-server-anmeldung-kopplung.md`): öffentliches Repo, Bezeichner englisch und Texte deutsch in der Du-Form, ganze Cent, Fehlerform `{"error":{"code","message"}}`, `withBusiness`/`withBusinessWrite`, 404 `not_found` für fremde Betriebe, App ohne Textfeld, Web ab 360 px.
- Wörterbuch dazu: noch zu senden = `outbox`, senden = `push`, Bericht = `report`, Sicherung = `backup`, Datei = `file`, Geräte-Kennung = `deviceId`, Umsätze = `overview`, Tag/Tagesabschluss = `day`, Testbon = `test`/`is_test`, Protokoll-Datei = `dep`.
- Die Kassa wartet nie auf den Abgleich. Kein Code in `features/kassa`, `features/close`, `features/bons` ruft den Server oder wartet auf den `SyncService`.
- Der Server ändert und löscht nie: Bon, Bon-Zeile, Bargeld-Bewegung, Bericht, Eintrag und Zertifikat der Signatur, abgeschlossener Tag, beendete Kette. Die Datenbank weist es selbst ab (Trigger), nicht nur der Code.
- Nichts an der Signatur ändert sein Verhalten. Dateien unter `app/lib/rksv/` werden nicht geändert. `receipt_repository.dart`, `day_repository.dart` und `rksv_journal.dart` werden nicht geändert (die Liste entsteht über Trigger).
- AES-Schlüssel der Signatur und Geräte-Schlüssel gehen in keine Nachricht, kein Protokoll, keinen Bericht.
- Grenzen: Paket höchstens 100 Einträge und 2 MB. Bild höchstens 10 MB, Ausgabe WebP mit höchstens 800 Pixel Breite. Berichte höchstens 50 pro Tag und Kassa, Meldung höchstens 500 Zeichen, Aufrufliste höchstens 8.000 Zeichen. Sicherung täglich nach 3 Uhr Wiener Zeit, die letzten 14 bleiben. Abgleich 2 Sekunden nach dem letzten neuen Eintrag.
- Jede neue Adresse unter `/api/admin/businesses/:b/…` und `/api/device/…` hat einen Test mit einem zweiten Betrieb, der nichts sieht und nichts ändert.
- Zeiten gehen als ISO 8601 in UTC mit Millisekunden über die Leitung (`2026-11-19T08:00:00.000Z`).
- App: Datenbank Version 5 mit Migration und Test. Version 1.5.0, Build 7. Lange Läufe (alle Tests der App) laufen auf GitHub in der Prüfung `app`; hier laufen nur die Tests der Aufgabe.
- Commits auf `claude/project-thread-r30ofv`, ohne Pull Request, Commit-Texte deutsch. Nur die Dateien formatieren, die man anfasst.
- Befehle: Server aus `server/` (Test-Datenbank: `tool/test-db.sh start`), Web aus `web/`, App aus `app/` mit `export PATH="$HOME/flutter/bin:$PATH"`.

## Nachrichtenformen

Beispieldateien dazu unter `shared/fixtures/sync/`, von App und Server getestet.

```jsonc
// POST /api/device/sync/push   (Authorization: Bearer <token>, höchstens 100 Einträge, 2 MB)
{
  "deviceId": "<uuid>",
  "entries": [
    { "seq": 1, "kind": "rksv_certificate", "certificate": { "serialHex": "1a2b", "certificate": "<base64 DER>", "issuers": ["<base64>"] } },
    { "seq": 2, "kind": "rksv_chain", "chain": { "chain": 1, "mode": "probe", "cashBoxId": "KASSA1", "zdaId": "AT0", "certSerial": "1a2b", "startedAt": "2026-11-19T07:59:00.000Z", "endedAt": null } },
    { "seq": 3, "kind": "day", "day": { "id": "<uuid>", "openedAt": "2026-11-19T08:00:00.000Z", "closedAt": null, "openingFloatCents": 10000, "countedCents": null, "leftInDrawerCents": null, "expectedCents": null, "differenceCents": null, "closedByName": null } },
    { "seq": 4, "kind": "cash_movement", "movement": { "id": "<uuid>", "businessDayId": "<uuid>", "kind": "withdrawal", "amountCents": 2000, "reason": "bank", "createdAt": "2026-11-19T09:00:00.000Z", "staffId": "<text>", "staffName": "Chefin" } },
    { "seq": 5, "kind": "receipt", "receipt": {
        "v": 1, "id": "<uuid>", "number": 1, "createdAt": "2026-11-19T08:05:00.000Z", "staffId": "<text>", "staffName": "Chefin",
        "businessDayId": "<uuid>", "kind": "sale", "voidsReceiptId": null,
        "goodsCents": 990, "depositCents": 0, "totalCents": 990, "test": true,
        "lines": [ { "position": 0, "itemId": "huhn-bowl", "name": "Huhn Bowl", "info": null, "unitPriceCents": 990, "quantity": 1, "unitDepositCents": 0,
                     "gross": { "20": 0, "10": 990, "13": 0, "0": 0, "19": 0 },
                     "options": [ { "groupName": "Größe", "optionName": "Normal", "surchargeCents": 0 } ] } ],
        "payment": { "kind": "cash", "amountCents": 990, "givenCents": 1000, "changeCents": 10, "provider": null, "providerTxCode": null, "cardScheme": null, "cardLast4": null },
        "rksv": { "chain": 1, "position": 2, "jws": "<kompakte JWS>", "damaged": false, "certSerial": "1a2b" } } },
    { "seq": 6, "kind": "item_change", "change": { "itemId": "huhn-bowl", "field": "priceCents", "value": 1090, "changedAt": "2026-11-19T08:10:00.000Z" } },
    { "seq": 7, "kind": "report", "report": { "id": "<uuid>", "kind": "error", "at": "2026-11-19T08:11:00.000Z", "appVersion": "1.5.0", "androidVersion": "14", "deviceModel": "Redmi Pad Pro", "count": 1,
        "error": { "type": "RangeError", "message": null, "stack": "<höchstens 8000 Zeichen>" }, "devices": null } }
  ]
}
// Antwort 200
{ "results": [ { "seq": 1, "status": "accepted" }, { "seq": 5, "status": "duplicate" }, { "seq": 6, "status": "rejected", "reason": "unknown_item" }, { "seq": 7, "status": "error" } ] }
```

- `kind` eines Bons: `sale`, `voided`, `start`, `month`, `year`, `zero`, `collective`, `closing`. `payment` und `businessDayId` sind bei Sonderbelegen `null`, `rksv` ist `null` ohne Eintrag im Protokoll.
- `field` einer Artikel-Änderung: `priceCents` (Zahl ab 0), `inSale` (bool), `favorite` (bool), `depositCents` (Zahl ab 0), `tags` (Liste aus `vegan`, `spicy`).
- `report.kind`: `error` (dann `error` gefüllt, `devices` null) oder `device_test` (dann `devices: [{ "device": "printer", "ok": true, "text": "…" }]`, `error` null).
- `status`: `accepted`, `duplicate`, `rejected` (mit `reason`: `conflict`, `invalid`, `unknown_item`), `error` (vorübergehend, später wieder).
- Fehler der ganzen Anfrage: 401 `unauthorized`, 403 `register_blocked` (wie beim Holen), 413 `payload_too_large`, 422 `push_invalid` (Hülle unlesbar: `deviceId` fehlt, `entries` keine Liste, mehr als 100, ein Eintrag ohne `seq` oder `kind`).

```jsonc
// GET /api/device/sync/pull: dazu bei jedem Artikel und beim Betrieb
"items": [ { "id": "huhn-bowl", …, "photo": { "id": "<uuid>", "color": "#a1b2c3" } } ],   // oder "photo": null
"business": { "name": …, "logo": { "id": "<uuid>", "color": "#ffffff" } }                 // oder "logo": null

// GET /api/device/files/<id>   (Authorization: Bearer <token>)  ->  200 image/webp, sonst 404 not_found
```

## Review Focus

Diese Fälle folgen aus dem Entwurf und treffen einen Menschen am ehesten. Jeder hat seinen Test in der genannten Aufgabe.

1. Die Antwort auf ein Paket geht verloren (der Server hat angenommen, das Tablet weiß es nicht). Beim nächsten Lauf kommt alles noch einmal: nichts ist doppelt, kein Umsatz zählt zweimal (Task 2, 7).
2. Ein Tag ändert sich, während er gerade gesendet wird (Wechselgeld gesetzt, Tag abgeschlossen). Die Änderung geht nicht verloren, der Server hat am Ende den abgeschlossenen Tag (Task 5, 7).
3. Ein Tablet mit falscher Uhr oder nach Stunden ohne Internet schickt eine Preisänderung, während im Browser inzwischen auch geändert wurde. Pro Feld gilt die spätere Änderung, eine Uhr in der Zukunft gewinnt nicht für immer (Task 3, 8).
4. Ein Foto lädt nur halb, ist kaputt oder verschwindet am Server, während das Tablet lädt. Die Kassa zeigt das alte oder kein Bild, nie ein kaputtes, und stürzt nicht ab (Task 4, 9).
5. Update von 1.4.0 auf einem gekoppelten Tablet mit einigen hundert Bons und laufender Probe-Kette. Alles kommt in mehreren Paketen in der richtigen Reihenfolge an, die Kassa ist dabei benutzbar, und die Preise vom Tablet bleiben (Task 5, 7, 20).

---

### Task 1: Server: Tabellen für Stufe 2

**Files:**
- Create: `server/migrations/0002_sync.sql`
- Modify: `server/test/schema.test.ts`, `server/test/migrate.test.ts`

**Interfaces:**
- Produces (Tabellen, alle mit `business_id uuid not null references businesses (id)` und der Sperre `business_isolation` wie in `0001_init.sql`):
  - `business_days (business_id, id uuid, register_id uuid, device_id uuid, opened_at timestamptz, closed_at timestamptz, opening_float_cents int, counted_cents int, left_in_drawer_cents int, expected_cents int, difference_cents int, closed_by_name text, content_hash bytea not null, received_at timestamptz not null default now(), primary key (business_id, id))`
  - `cash_movements (business_id, id uuid, register_id uuid, business_day_id uuid, kind text check in ('deposit','withdrawal'), amount_cents int, reason text, created_at timestamptz, staff_id text, staff_name text, content_hash bytea, received_at, primary key (business_id, id))`
  - `receipts (business_id, id uuid, register_id uuid, device_id uuid, number int, created_at timestamptz, kind text, staff_id text, staff_name text, business_day_id uuid, voids_receipt_id uuid, goods_cents int, deposit_cents int, total_cents int, payment_kind text, is_test boolean not null, content_hash bytea not null, payload jsonb not null, received_at, primary key (business_id, id))`, Indizes `(business_id, created_at desc)` und `(business_id, register_id, number)`. Tag und stornierter Bon bewusst ohne Fremdschlüssel.
  - `receipt_lines (business_id, receipt_id uuid, position int, item_id text, name text, info text, unit_price_cents int, quantity int, unit_deposit_cents int, gross20_cents int, gross10_cents int, gross13_cents int, gross0_cents int, gross19_cents int, options jsonb not null default '[]', primary key (business_id, receipt_id, position), foreign key (business_id, receipt_id) references receipts)`
  - `rksv_certificates (business_id, device_id uuid, serial_hex text, certificate bytea, issuers jsonb, register_id uuid, content_hash bytea, received_at, primary key (business_id, device_id, serial_hex))`
  - `rksv_chains (business_id, device_id uuid, chain int, mode text check in ('probe','live'), cash_box_id text, zda_id text, cert_serial text, started_at timestamptz, ended_at timestamptz, register_id uuid, content_hash bytea, received_at, primary key (business_id, device_id, chain))`
  - `rksv_entries (business_id, device_id uuid, chain int, position int, receipt_id uuid, jws text, damaged boolean, cert_serial text, register_id uuid, received_at, primary key (business_id, device_id, chain, position), unique (business_id, receipt_id))`
  - `reports (business_id, id uuid, register_id uuid, source text check in ('device','server'), kind text, at timestamptz, app_version text, android_version text, device_model text, count int not null default 1, content jsonb not null, received_at, primary key (business_id, id))`, Index `(business_id, register_id, received_at)`
  - `files (business_id, id uuid default gen_random_uuid(), kind text check in ('item_photo','logo'), storage_key text not null, size int, width int, height int, color text, created_at, primary key (business_id, id))`
  - ohne Betrieb: `backups (id bigserial primary key, day date not null, storage_key text, size bigint, ok boolean not null, error text, started_at timestamptz not null, finished_at timestamptz)`
  - neue Spalten: `registers.device_id uuid`, `businesses.logo_file_id uuid`, `businesses.time_zone text not null default 'Europe/Vienna'`, `items.photo_file_id uuid`; `items.photo_file` entfällt.
  - Funktion `list_reports(lim int, before timestamptz)` (`security definer`, wie `find_register_by_token`): Berichte aller Betriebe mit Name des Betriebs und der Kassa, neueste zuerst. Nur `kassa_app` darf sie ausführen.
- Rechte für `kassa_app`: `select, insert` auf `receipts, receipt_lines, cash_movements, reports, rksv_certificates, rksv_entries`; `select, insert, update` auf `business_days, rksv_chains, backups`; `select, insert, delete` auf `files`.

- [ ] **Step 1: Tests schreiben** in `schema.test.ts`: (a) für jede neue Tabelle mit Betrieb: ohne `app.business_id` keine Zeile, mit fremdem Betrieb keine Zeile, Einfügen für einen fremden Betrieb scheitert; (b) `update` und `delete` auf `receipts`, `receipt_lines`, `cash_movements`, `reports`, `rksv_entries`, `rksv_certificates` scheitern mit einer Meldung, die "unveränderlich" enthält, auch als Besitzer; (c) `update` auf `business_days` geht, solange `closed_at` leer ist, und scheitert danach; dasselbe für `rksv_chains` mit `ended_at`; `delete` scheitert bei beiden immer; (d) `list_reports` liefert als `kassa_app` Berichte zweier Betriebe, ein direktes `select` ohne Betrieb liefert keine. In `migrate.test.ts`: eine Datenbank auf Stand 0001 mit einem Artikel bekommt 0002 ohne Fehler, der Artikel ist noch da.
- [ ] **Step 2: Laufen lassen.** `npx vitest run test/schema.test.ts test/migrate.test.ts`. Erwartet: neue Tests scheitern (Tabellen fehlen).
- [ ] **Step 3: `0002_sync.sql` schreiben.** Sperre über dieselbe Schleife wie in 0001. Die Unveränderlichkeit über `before update or delete`-Trigger, die eine Ausnahme werfen.
- [ ] **Step 4: Laufen lassen.** Erwartet: alles grün, dazu `npx vitest run` ganz (C1 darf nicht brechen).
- [ ] **Step 5: Commit** "Server: Tabellen für Bons, Tage, Protokoll, Berichte, Dateien, Sicherung".

### Task 2: Server: senden (Tage, Bewegungen, Bons, Protokoll)

**Files:**
- Create: `server/src/device/push.ts`, `server/src/device/push_schema.ts`, `server/src/device/content_hash.ts`, `server/src/reports.ts`, `server/test/push.test.ts`, `server/test/content_hash.test.ts`, `server/test/support/push.ts`, `shared/fixtures/sync/push_request.json`, `shared/fixtures/sync/push_response.json`
- Modify: `server/src/app.ts` (Route anmelden), `server/test/sync_fixtures.test.ts`

**Interfaces:**
- Consumes: Tabellen aus Task 1, `requireRegister` (`server/src/device/guard.ts`), `withBusiness`.
- Produces:
  - `installPushRoutes(app: FastifyInstance): void`, Adresse `POST /api/device/sync/push`, `bodyLimit` 2 MB.
  - `contentHash(value: unknown): Buffer`: SHA-256 über JSON mit sortierten Schlüsseln.
  - `writeServerReport(c: pg.PoolClient, r: { businessId: string; registerId: string | null; kind: string; content: object }, at: Date): Promise<void>` in `reports.ts` (`source = 'server'`), schreibt zusätzlich eine Zeile ins Protokoll.
  - `type EntryHandler = (c: pg.PoolClient, ctx: { register: Register; deviceId: string; at: Date }, body: unknown) => Promise<{ status: 'accepted' | 'duplicate' } | { status: 'rejected'; reason: 'conflict' | 'invalid' | 'unknown_item' }>` und eine Tabelle `handlers: Record<string, EntryHandler>`, in die Task 3 `item_change` und `report` einträgt. Unbekanntes `kind`: `rejected/invalid`.
  - Test-Helfer `pushEntries(app, token, deviceId, entries): Promise<{ status: number; results: PushResult[] }>` und `sampleReceipt(overrides?)`, `sampleDay(overrides?)` in `test/support/push.ts`.

Regeln (Entwurf 5.2):
- Jeder Eintrag läuft in einer eigenen Transaktion (`withBusiness`). Ein unerwarteter Fehler in einem Eintrag ergibt für ihn `error`, wird protokolliert und hält die anderen nicht auf.
- `zod` liest jeden Eintrag streng nach den Nachrichtenformen und entfernt unbekannte Schlüssel. Die Prüfsumme wird über das gelesene Objekt gebildet, beim Bon ohne `rksv`. Unlesbar: `rejected/invalid`.
- Bon: neu → `receipts` (mit `payload` = gelesenes Objekt samt `rksv`), `receipt_lines`, bei `rksv` der Eintrag. Kennung da und Prüfsumme gleich → `duplicate`; fehlt dabei der Eintrag der Signatur noch, wird er nachgetragen. Prüfsumme anders → `rejected/conflict` und `writeServerReport(kind: 'receipt_conflict')`. Ein Eintrag der Signatur, der an seiner Stelle schon anders steht, ändert nichts am Bon-Ergebnis und ergibt `writeServerReport(kind: 'rksv_conflict')`.
- Summen: `goodsCents + depositCents != totalCents`, Summe der `gross` aller Zeilen `!= goodsCents`, oder bei `sale` `payment.amountCents != totalCents` → trotzdem annehmen und `writeServerReport(kind: 'receipt_sums')`.
- Tag und Kette: solange am Server offen, überschreibt die Sendung (Ergebnis `accepted`). Am Server abgeschlossen oder beendet: gleiche Prüfsumme `duplicate`, sonst `rejected/conflict` mit Bericht.
- Zertifikat und Bewegung: nur anlegen; da und gleich `duplicate`, da und anders `rejected/conflict`.
- `registers.device_id` wird auf die `deviceId` des Pakets gesetzt, wenn sie abweicht.

- [ ] **Step 1: `content_hash.test.ts`**: gleiche Objekte mit anderer Schlüsselfolge ergeben dieselbe Prüfsumme; ein geänderter Betrag eine andere; verschachtelte Listen behalten ihre Reihenfolge.
- [ ] **Step 2: `push_request.json` von Hand schreiben**: die sieben Einträge aus "Nachrichtenformen" mit festen Kennungen (keine `<uuid>`-Platzhalter in der Anfrage) für den Betrieb aus `fixtureBusiness`, `item_change` und `report` eingeschlossen.
- [ ] **Step 3: `push.test.ts` schreiben**, mindestens:
  - `test('Paket aus push_request.json wird angenommen und liegt am Server')`: Antwort wie `push_response.json` (für `item_change` und `report` vorerst `rejected/invalid`, Task 3 schreibt die Datei neu); `receipts`, `receipt_lines`, `business_days`, `cash_movements`, `rksv_*` enthalten die Werte.
  - `test('dasselbe Paket noch einmal: alles duplicate, nichts doppelt')` (Review Focus 1): Zeilenzahlen unverändert.
  - `test('gleicher Bon mit anderem Betrag: rejected/conflict, Server behält seine Fassung, Bericht receipt_conflict')`.
  - `test('Bon mit unbekanntem Tag wird angenommen')`, `test('Summen passen nicht: angenommen, Bericht receipt_sums')`.
  - `test('offener Tag wird überschrieben, abgeschlossener ist endgültig')`.
  - `test('ein unlesbarer Eintrag in der Mitte: rejected/invalid, die anderen accepted')`.
  - `test('ein Eintrag scheitert unerwartet: error, die anderen accepted')` (Handler im Test durch einen ersetzen, der wirft).
  - `test('Bon kam ohne rksv, kommt später mit: duplicate und Eintrag nachgetragen')`.
  - `test('Kette läuft nach neuem Koppeln unter neuer Kassa weiter: ein Protokoll pro deviceId')`: zwei Kassen desselben Betriebs, dieselbe `deviceId`, Einträge 1 bis 2 über die erste, 3 über die zweite.
  - `test('101 Einträge: 422 push_invalid')`, `test('über 2 MB: 413')`, `test('ohne Schlüssel 401, gesperrt 403')`.
  - `test('zweiter Betrieb sieht nichts')`: derselbe Bon (gleiche Kennung) über eine Kassa eines zweiten Betriebs ist dort `accepted` und ändert beim ersten nichts.
- [ ] **Step 4: Laufen lassen**, erwartet rot. **Step 5: umsetzen.** **Step 6: grün**, dazu `KASSA_WRITE_FIXTURES=1 npx vitest run test/sync_fixtures.test.ts` für `push_response.json` und danach ohne die Variable.
- [ ] **Step 7: Commit** "Server: Bons, Tage, Bewegungen und Protokoll annehmen".

### Task 3: Server: Artikel-Änderungen und Berichte annehmen

**Files:**
- Create: `server/src/device/push_item_change.ts`, `server/src/device/push_report.ts`, `server/test/push_item_change.test.ts`, `server/test/push_report.test.ts`
- Modify: `server/src/device/push.ts` (Handler eintragen), `shared/fixtures/sync/push_response.json`

**Interfaces:**
- Consumes: `handlers`, `EntryHandler` aus Task 2; `withBusinessWrite`, `nextChangeSeq` (`server/src/db/tenant.ts`).
- Produces: `applyItemField(c: pg.PoolClient, businessId: string, itemId: string, field: ItemField, value: unknown, changedAt: Date): Promise<'applied' | 'older' | 'unknown_item'>` mit `type ItemField = 'priceCents' | 'inSale' | 'favorite' | 'depositCents' | 'tags'`. Task 13 ruft dieselbe Funktion für den Browser.

Regeln (Entwurf 5.4, Teil C 5.6): `changedAt` in der Zukunft wird auf die Uhr des Servers gekürzt. Ist `changedAt` später als `<feld>_changed_at`, wird Wert und Zeitpunkt gesetzt und eine neue Änderungs-Nummer gezogen. Sonst bleibt alles. Beides ergibt `accepted`. `item_change` läuft in `withBusinessWrite` (die anderen Arten nicht). Berichte: höchstens 50 pro Kassa und Kalendertag (UTC); weitere ergeben `accepted` und werden nicht gespeichert. Jeder gespeicherte Bericht schreibt eine Zeile `bericht` ins Protokoll mit Betrieb, Kassa, Art, App-Version und bei Fehlern der Fehlerart.

- [ ] **Step 1: Tests**: `test('späterer Preis vom Tablet gewinnt und kommt beim Holen')` (neue Änderungs-Nummer, `pull` liefert den Artikel); `test('älterer Preis vom Tablet verliert, accepted, nichts ändert sich')`; `test('Uhr eine Woche in der Zukunft: gilt als jetzt, eine spätere Änderung im Browser gewinnt wieder')` (Review Focus 3, mit `applyItemField` als Browser-Seite); `test('pro Feld: Preis vom Tablet und Favorit vom Server bleiben beide')`; `test('tags: ["spicy","vegan"] wird "spicy,vegan"')`; `test('unbekannter Artikel: rejected/unknown_item')`; `test('priceCents -1 oder "abc": rejected/invalid')`; `test('Artikel eines anderen Betriebs mit gleicher Kennung bleibt unberührt')`. Berichte: `test('Bericht liegt mit festen Feldern am Server und im Protokoll')`, `test('der 51. Bericht des Tages wird angenommen und nicht gespeichert')`, `test('Bericht mit unbekanntem Feld "receipt": das Feld wird nicht gespeichert')`.
- [ ] **Step 2: rot. Step 3: umsetzen. Step 4: grün**, `push_response.json` neu schreiben lassen (alle sieben `accepted`).
- [ ] **Step 5: Commit** "Server: Artikel-Änderungen und Berichte vom Tablet".

### Task 4: Server: Fotos und Logo

**Files:**
- Create: `server/src/files/images.ts`, `server/src/files/routes.ts`, `server/test/images.test.ts`, `server/test/files.test.ts`, `server/test/fixtures/images/` (kleine Testbilder: JPEG mit EXIF-Drehung und Ortsangabe, PNG mit durchsichtigem Hintergrund, WebP, eine Textdatei mit Endung `.jpg`)
- Modify: `server/package.json` (`sharp`), `server/src/app.ts`, `server/src/device/pull.ts`, `shared/fixtures/sync/pull_full.json`, `shared/fixtures/sync/pull_delta.json`, `server/test/pull.test.ts`

**Interfaces:**
- Consumes: `FileStore` (`server/src/storage/file_store.ts`), Tabelle `files`, `withBusinessWrite`, `nextChangeSeq`, `audit`.
- Produces:
  - `processImage(input: Buffer): Promise<{ data: Buffer; width: number; height: number; color: string }>`; wirft `ApiError(422, 'image_invalid', 'Das ist kein Bild, das Kassa lesen kann. Nimm JPEG, PNG oder WebP.')`. Ausgabe WebP, höchstens 800 breit, nie vergrößert, nach EXIF gedreht, ohne Metadaten, `color` als `#rrggbb` (mittlere Farbe). Eingaben über 50 Millionen Pixel werden abgelehnt.
  - Adressen: `PUT` und `DELETE /api/admin/businesses/:b/items/:id/photo`, `PUT` und `DELETE /api/admin/businesses/:b/logo`, `GET /api/admin/businesses/:b/files/:id`, `GET /api/device/files/:id`. `PUT` nimmt den rohen Inhalt (`image/jpeg`, `image/png`, `image/webp`), höchstens 10 MB (sonst 413), und antwortet `{ "file": { "id", "color", "width", "height" } }`.
  - Ablage-Schlüssel `businesses/<b>/files/<id>.webp`. Auslieferung mit `Content-Type: image/webp`, `X-Content-Type-Options: nosniff`, `Cache-Control: private, max-age=31536000, immutable`.
  - `pull` liefert `photo` am Artikel und `logo` am Betrieb (siehe Nachrichtenformen).

Regeln: Ersetzen legt eine neue Datei mit neuer Kennung an, zieht eine Änderungs-Nummer am Artikel (beim Logo am Betrieb) und löscht nach dem Commit die alte Zeile und das alte Objekt. Scheitert das Löschen in der Ablage, bleibt das Objekt liegen und es steht im Protokoll; die Anfrage gelingt trotzdem. Jede Änderung steht im Verlauf (`item.photo_set`, `item.photo_removed`, `business.logo_set`, `business.logo_removed`). Eine Datei im `GET` gibt es nur, solange ein Artikel oder der Betrieb auf sie zeigt.

- [ ] **Step 1: `images.test.ts`**: JPEG 1600 breit wird 800 breit WebP; 400 breit bleibt 400; gedrehtes JPEG kommt aufrecht heraus (Breite und Höhe getauscht); Ausgabe enthält keine EXIF-Daten; PNG behält den durchsichtigen Hintergrund; Textdatei, leere Datei und abgeschnittenes JPEG ergeben `image_invalid`; `color` passt auf `/^#[0-9a-f]{6}$/`.
- [ ] **Step 2: `files.test.ts`**: Foto hochladen, `pull` zeigt `photo` mit neuer Änderungs-Nummer, Tablet lädt die Datei; ersetzen: neue Kennung, alte Kennung 404, altes Objekt aus der Ablage weg; entfernen: `photo: null`; Logo genauso; 11 MB ergibt 413; `image/gif` ergibt 415 `unsupported_media_type`; Chef des Betriebs darf, Chef eines anderen Betriebs und nicht angemeldet bekommen 404 bzw. 401; Tablet eines zweiten Betriebs bekommt für die Kennung 404 (Review Focus 4, Server-Seite); gesperrte Kassa 403; Artikel unbekannt 404.
- [ ] **Step 3: rot. Step 4: umsetzen. Step 5: grün.** Beispieldateien `pull_full.json` und `pull_delta.json` neu schreiben lassen (`photo: null`, `logo: null`), danach in `app/`: `flutter test test/sync` (die bestehende App muss die neuen Schlüssel vertragen).
- [ ] **Step 6: Commit** "Server: Fotos und Logo hochladen, ausliefern, beim Holen nennen".

### Task 5: App: Datenbank Version 5 und die Liste "noch zu senden"

**Files:**
- Create: `app/lib/data/outbox_repository.dart`, `app/test/data/outbox_repository_test.dart`, `app/test/data/outbox_trigger_test.dart`, `app/test/data/fixtures/kassa_v4.sqlite`, `app/test/data/generated_migrations/schema_v5.dart`
- Modify: `app/lib/data/database.dart`, `app/lib/data/database.g.dart` (erzeugt), `app/lib/data/sync_state_repository.dart`, `app/lib/data/providers.dart`, `app/test/data/migration_test.dart`, `app/test/data/generated_migrations/schema.dart`

**Interfaces:**
- Produces:
  - Tabelle `outbox` (`OutboxRows`): `id` (autoIncrement), `kind` text, `ref` text, `field` text?, `value` text? (JSON), `changedAt` DateTime?, `rev` int default 0, `state` text default `pending` (`pending`, `rejected`), `reason` text?. Eindeutiger Index `outbox_entity ON outbox (kind, ref) WHERE kind <> 'item_change'`.
  - Tabelle `reports` (`ReportRows`): `id` text, `kind` text, `at` DateTime, `appVersion` text, `androidVersion` text?, `deviceModel` text?, `count` int default 1, `signature` text, `content` text (JSON).
  - Neue Spalten: `items.photo_file_id`, `items.photo_color`; `business.logo_file_id`, `business.logo_path`, `business.logo_color`; `sync_state.device_id`, `sync_state.last_push_at`, `sync_state.photos_auto_enabled` (bool, default false).
  - Trigger (in `onCreate` und in der Migration, eigene Methode `_createOutboxTriggers()`), jeweils zwei Anweisungen: `UPDATE outbox SET rev = rev + 1 WHERE kind = … AND ref = …;` dann `INSERT OR IGNORE INTO outbox (kind, ref) VALUES (…, …);`
    - `receipts` nach INSERT → `('receipt', NEW.id)`; `rksv_entries` nach INSERT → `('receipt', NEW.receipt_id)`
    - `business_days` nach INSERT und nach UPDATE → `('day', NEW.id)`
    - `cash_movements` nach INSERT → `('cash_movement', NEW.id)`
    - `rksv_certificates` nach INSERT → `('rksv_certificate', NEW.serial_hex)`
    - `rksv_chains` nach INSERT und nach UPDATE → `('rksv_chain', NEW.chain)`
    - `reports` nach INSERT und nach UPDATE → `('report', NEW.id)`
  - `class OutboxEntry { int id; String kind; String ref; String? field; String? value; DateTime? changedAt; int rev; }`
  - `class OutboxCounts { int pending; int rejected; }`
  - `class OutboxRepository(KassaDatabase)`: `Future<List<OutboxEntry>> nextBatch({int limit = 100})` (nur `pending`, nach `id`); `Future<void> remove(int id, {required int rev})` (löscht nur bei gleichem `rev`); `Future<void> markRejected(int id, String reason)`; `Stream<OutboxCounts> watchCounts()`; `Future<void> addItemChange({required String itemId, required String field, required Object value, required DateTime changedAt})`; `Future<Map<String, Set<String>>> pendingItemFields()` (Artikel → Felder); `Future<void> clearItemChanges()`.
  - `SyncStateRepository.deviceId(): Future<String>` (liest oder erzeugt mit `Uuid().v4()` und speichert), `SyncState.lastPushAt`, `SyncStateRepository.setPushed(DateTime at)`.
  - `outboxRepositoryProvider`, `outboxCountsProvider` (StreamProvider) in `providers.dart`.

Migration 4 → 5 (Entwurf 5.1): Tabellen und Spalten anlegen, Index, Trigger, dann einstellen in dieser Reihenfolge: Zertifikate, Ketten nach `chain`, Tage nach `opened_at`, Bewegungen nach `created_at`, Bons nach `number`. Ist `sync_state.register_id` gesetzt, zusätzlich für jeden Artikel fünf Zeilen `item_change` (`priceCents`, `inSale`, `favorite`, `depositCents`, `tags`) mit dem aktuellen Wert als JSON und `changed_at` = jetzt.

- [ ] **Step 1: `kassa_v4.sqlite` erzeugen** wie die bisherigen Dateien (siehe Kopf von `migration_test.dart`): Datenbank Version 4 mit zwei Tagen (einer abgeschlossen), einer Bewegung, vier Bons (Verkauf bar, Verkauf Karte, Storno, Startbeleg), einer Probe-Kette mit Zertifikat und drei Einträgen, drei Artikeln, `sync_state` gekoppelt. Schema Version 5 mit `drift_dev` ausgeben wie bei Version 4.
- [ ] **Step 2: Tests schreiben.**
  - `migration_test.dart`: `test('4 → 5: Schema stimmt, alle Daten da')`; `test('4 → 5: Vorhandenes steht in der Liste, in der Reihenfolge Zertifikat, Kette, Tage, Bewegung, Bons nach Nummer')`; `test('4 → 5 gekoppelt: 3 Artikel ergeben 15 Artikel-Änderungen')`; `test('4 → 5 nicht gekoppelt: keine Artikel-Änderung')`; `test('4 → 5: Trigger der Unveränderlichkeit greifen weiter')`.
  - `outbox_trigger_test.dart` (über die echten Repositories): Verkauf bar ergibt genau einen Eintrag `receipt`, der Tag davor einen Eintrag `day`; Storno ergibt einen zweiten `receipt`; Sonderbeleg ergibt `receipt`; `setOpeningFloat` und `close` erhöhen `rev` des Tages statt einer zweiten Zeile; `addMovement` ergibt `cash_movement`; Probe einschalten ergibt `rksv_certificate` und `rksv_chain`; `test('Transaktion bricht ab: weder Bon noch Eintrag')`; `test('abgelehnter Eintrag bleibt abgelehnt, auch wenn sich der Tag ändert')`.
  - `outbox_repository_test.dart`: `nextBatch` liefert in Reihenfolge und höchstens `limit`; `test('remove mit altem rev löscht nicht')` (Review Focus 2); `markRejected` nimmt den Eintrag aus `nextBatch` und zählt ihn in `watchCounts`; `pendingItemFields`; `clearItemChanges` lässt andere Arten stehen; `deviceId()` ist beim zweiten Aufruf dieselbe.
- [ ] **Step 3: rot. Step 4: umsetzen** (`dart run build_runner build` für `database.g.dart`). **Step 5: grün**: `flutter test test/data`.
- [ ] **Step 6: Commit** "App: Datenbank Version 5 mit der Liste noch zu senden".

### Task 6: App: Nachrichten zum Senden und gemeinsame Beispiele

**Files:**
- Create: `app/lib/sync/push_wire.dart`, `app/test/sync/push_wire_test.dart`, `app/test/sync/shared_fixtures_test.dart`, `shared/fixtures/stats/overview.json`, `shared/fixtures/rksv/dep.json`
- Modify: `app/lib/sync/server_api.dart`, `app/test/sync/server_api_test.dart`

**Interfaces:**
- Consumes: `OutboxEntry` (Task 5), `KassaDatabase`.
- Produces:
  - `class PushPayloads(KassaDatabase)`: `Future<Map<String, Object?>?> build(OutboxEntry e)`: der Eintrag in der Form der Nachrichtenformen (`seq` = `e.id`), gelesen aus den Tabellen; `null`, wenn es die Sache nicht mehr gibt. `test` eines Bons ist `false` nur, wenn sein Eintrag in einer Kette mit `mode = 'live'` steht.
  - `enum PushStatus { accepted, duplicate, rejected, error }`, `class PushResult { int seq; PushStatus status; String? reason; }`
  - `ServerApi.push({required String token, required String deviceId, required List<Map<String, Object?>> entries}): Future<List<PushResult>>`. Neuer `ServerFailure.rejected` für 400, 413 und 422 der ganzen Anfrage.
  - `shared/fixtures/stats/overview.json`: `{ "now", "timeZone": "UTC", "categories", "items", "receipts": [Bons in der Form der Nachrichtenformen], "expected": { "today": {…}, "days7": {…}, "days30": {…} } }`, `expected` in den Feldern von `Overview` (`app/lib/domain/stats.dart`), geschrieben aus `StatsRepository.overview`.
  - `shared/fixtures/rksv/dep.json`: `{ "certificates", "chain", "entries", "expected": <Ausgabe von buildDepExport als Objekt> }`.

- [ ] **Step 1: Tests.** `push_wire_test.dart`: eine Datenbank, gefüllt mit genau den Daten aus `shared/fixtures/sync/push_request.json`, ergibt über `PushPayloads.build` für jeden Eintrag genau das Objekt aus der Datei (`test('App baut dieselbe Anfrage wie die Beispieldatei')`); Sonderbeleg hat `payment: null` und `businessDayId: null`; Bon ohne Protokoll hat `rksv: null`; Bon in einer echten Kette hat `test: false`; fehlender Bon ergibt `null`. `server_api_test.dart`: `push` schickt Schlüssel und Körper, liest `push_response.json`; 422 ergibt `ServerFailure.rejected`, 401 `unauthorized`, 403 `blocked`, Zeitgrenze `timeout`.
- [ ] **Step 2: `shared_fixtures_test.dart`**: füllt eine Datenbank mit 14 Bons über 40 Tage (bar, Karte, Storno, Pfand, zwei Steuersätze, ein Sonderbeleg, ein Artikel ohne Kategorie am Tablet, ein Bon kurz vor und einer kurz nach Mitternacht) bei fester Uhr, und einer Probe-Kette mit zwei Zertifikaten in Folge. Mit `KASSA_WRITE_FIXTURES=1` schreibt er beide Beispieldateien, sonst vergleicht er.
- [ ] **Step 3: rot. Step 4: umsetzen. Step 5: Beispiele schreiben** (`KASSA_WRITE_FIXTURES=1 flutter test test/sync/shared_fixtures_test.dart`), dann **grün** ohne die Variable.
- [ ] **Step 6: Commit** "App: Nachrichten zum Senden, Beispiele für Umsätze und Protokoll-Datei".

### Task 7: App: senden im Abgleich

**Files:**
- Modify: `app/lib/sync/sync_service.dart`, `app/lib/app_sync_providers.dart`, `app/test/sync/sync_service_test.dart`

**Interfaces:**
- Consumes: `OutboxRepository`, `PushPayloads`, `ServerApi.push`, `SyncStateRepository.deviceId()` und `setPushed`.
- Produces: `SyncService` nimmt zusätzlich `outbox`, `payloads`; neue Methode `void poke()` (ein Lauf 2 Sekunden nach dem letzten Aufruf, `static const pokeDelay = Duration(seconds: 2)`). Ein Lauf ist: senden, dann holen (Dateien kommen in Task 9 dazu). `syncServiceProvider` hört auf `outboxCountsProvider` und ruft `poke()`, wenn `pending` steigt.

Regeln (Entwurf 5.2, 5.3): Pakete zu höchstens 100, bis `nextBatch` leer ist. `accepted` und `duplicate`: `remove(id, rev: …)` mit dem `rev`, das beim Bauen gelesen wurde. `rejected`: `markRejected`. `error`: stehen lassen, der Lauf endet nach dem Holen mit "bald nochmal". Baut `PushPayloads.build` `null`, wird der Eintrag entfernt. `ServerFailure.rejected` für ein ganzes Paket: dieselben Einträge einzeln senden; scheitert einer auch einzeln so, `markRejected(id, 'invalid')`. `offline`, `timeout`, `server`: Lauf endet wie bisher mit Fehler. `blocked`, `unauthorized`: wie beim Holen. Ein Paket, in dem nur `error` steht, wird in diesem Lauf nicht noch einmal gesendet (keine Endlosschleife). `lastPullAt` ("Zuletzt abgeglichen") rückt nur weiter, wenn Senden und Holen ohne Fehler waren.

- [ ] **Step 1: Tests** (nachgebauter Server wie bisher in `sync_service_test.dart`): `test('250 Einträge gehen in drei Paketen in Reihenfolge hinauf')` (Review Focus 5); `test('Antwort geht verloren: beim nächsten Lauf kommt alles noch einmal, danach ist die Liste leer')` (Review Focus 1); `test('Tag ändert sich zwischen Bauen und Antwort: Eintrag bleibt und geht im nächsten Lauf mit dem neuen Stand hinauf')` (Review Focus 2); `test('abgelehnter Eintrag hält die anderen nicht auf')`; `test('Paket scheitert mit 422: einzeln senden, der kaputte wird abgelehnt, der Rest kommt an')`; `test('error: Eintrag bleibt, Holen läuft trotzdem, nächster Lauf nach 30 Sekunden')`; `test('ohne Internet: nichts gelöscht, Zuletzt abgeglichen rückt nicht')`; `test('gesperrt: kein Holen, Liste bleibt')`; `test('poke: fünf Aufrufe in einer Sekunde ergeben einen Lauf nach 2 Sekunden')`; `test('nicht gekoppelt: senden tut nichts')`.
- [ ] **Step 2: rot. Step 3: umsetzen. Step 4: grün**: `flutter test test/sync`.
- [ ] **Step 5: Commit** "App: der Abgleich sendet vor dem Holen".

### Task 8: App: Artikel-Änderungen in beide Richtungen

**Files:**
- Modify: `app/lib/data/catalog_repository.dart`, `app/lib/sync/server_changes.dart`, `app/lib/sync/pairing_service.dart`, `app/lib/sync/push_wire.dart`, `app/lib/data/providers.dart`, `app/test/data/catalog_repository_test.dart`, `app/test/sync/server_changes_test.dart`, `app/test/sync/pairing_service_test.dart`, `app/test/features/kassa_test.dart`

**Interfaces:**
- Consumes: `OutboxRepository.addItemChange`, `pendingItemFields`, `clearItemChanges` (Task 5).
- Produces: `CatalogRepository(KassaDatabase db, {Clock clock})`; `updateItem` schreibt in einer Transaktion den Artikel und, wenn `sync_state.register_id` gesetzt ist, pro Feld, dessen Wert sich wirklich ändert, eine Zeile `item_change` (`field` wie in den Nachrichtenformen, `value` als JSON, `changedAt` = Uhr). `PushPayloads.build` baut daraus `{ "seq", "kind": "item_change", "change": {…} }`.

Regeln (Entwurf 5.4): `ServerChanges.applyPage` lässt bei einem vorhandenen Artikel jedes Feld aus, für das `pendingItemFields()` einen wartenden Eintrag nennt; ein neuer Artikel wird ganz geschrieben. `ServerChanges.replaceAll` ruft in derselben Transaktion `clearItemChanges()`. `PairingService.pair` wirft `ServerException(ServerFailure.otherBusiness)`, bevor es etwas speichert, wenn das Tablet schon einen Betrieb kennt und die Antwort einen anderen nennt.

- [ ] **Step 1: Tests.** `test('gekoppelt: Preis ändern schreibt genau einen Eintrag priceCents mit Zeitpunkt')`; `test('gekoppelt: Preis und Favorit zusammen ergeben zwei Einträge')`; `test('gleicher Wert noch einmal: kein Eintrag')`; `test('nicht gekoppelt: kein Eintrag')`; `test('Artikel fehlt: StateError, kein Eintrag')`; `test('wartende Preisänderung: Seite vom Server lässt den Preis, übernimmt aber den Namen')`; `test('nach dem Senden bringt die nächste Seite den Preis vom Server')`; `test('Koppeln löscht wartende Artikel-Änderungen und lässt Bons in der Liste')`; `test('Antwort beim Koppeln nennt anderen Betrieb: otherBusiness, nichts gespeichert')`.
- [ ] **Step 2: Offenen Bon festhalten** (Entwurf 5.4): Test in `kassa_test.dart`, der einen Artikel in den Bon legt, dann (a) den Preis über `CatalogRepository.updateItem` und (b) über `ServerChanges.applyPage` ändert, und für beide dasselbe Verhalten des offenen Bons erwartet. Zuerst nur (a) schreiben und sehen, was die App heute tut; dieses Verhalten ist die Erwartung für (b). Weichen beide ab, wird (b) angeglichen (derselbe Aufruf wie nach (a), in `app_sync_providers.dart`).
- [ ] **Step 3: rot. Step 4: umsetzen. Step 5: grün**: `flutter test test/data/catalog_repository_test.dart test/sync test/features/kassa_test.dart test/features/items_test.dart`.
- [ ] **Step 6: Commit** "App: Artikel-Änderungen gehen zum Server und schützen ihr Feld".

### Task 9: App: Fotos und Logo

**Files:**
- Create: `app/lib/sync/file_sync.dart`, `app/lib/ui/business_logo.dart`, `app/test/sync/file_sync_test.dart`
- Modify: `app/lib/sync/wire.dart`, `app/lib/sync/server_changes.dart`, `app/lib/sync/server_api.dart`, `app/lib/sync/sync_service.dart`, `app/lib/app_sync_providers.dart`, `app/lib/data/catalog_repository.dart` und `app/lib/domain/business_info.dart` (Logo lesen), `app/lib/ui/app_header.dart`, `app/lib/features/login/pin_screen.dart`, `app/lib/features/kassa/item_tile.dart`, `app/lib/features/items/item_row.dart`, `app/pubspec.yaml` (`path_provider`), Tests dazu und Vergleichsbilder

**Interfaces:**
- Consumes: Spalten aus Task 5, `GET /api/device/files/<id>` (Task 4).
- Produces:
  - `WireItem.photo` und `PullResponse.business.logo` als `WireFile? { String id; String color; }`. Fehlt der Schlüssel ganz (alter Server), gilt `null`.
  - `ServerApi.downloadFile({required String token, required String id}): Future<Uint8List>`; mehr als 2 MB oder kein `image/webp` ergibt `ServerFailure.server`.
  - `class FileSync(KassaDatabase db, ServerApi api, Future<Directory> Function() dir)`: `Future<bool> run(String token)` lädt für jeden Artikel und den Betrieb, deren `…FileId` gesetzt ist und deren Pfad fehlt oder zu einer anderen Kennung gehört, die Datei nach `<dir>/<id>.webp` (erst `<id>.part`, dann umbenennen), setzt danach `photoPath` bzw. `logoPath`, löscht Dateien im Ordner, auf die keine Zeile mehr zeigt, und gibt zurück, ob sich etwas geändert hat. Wirft nie; ein Fehler bei einer Datei hält die anderen nicht auf.
  - `SyncService` ruft nach dem Holen `FileSync.run`. Das Ergebnis ändert "Zuletzt abgeglichen" nicht.
  - `BusinessLogo({required double size})`: zeigt das Logo des Betriebs aus der Datei, sonst `KassaLogo`.

Regeln (Entwurf 5.5): `ServerChanges` schreibt `photoFileId` und `photoColor`; wird die Kennung leer, wird auch `photoPath` geleert; wechselt sie, bleibt `photoPath` bis zum fertigen Laden stehen. Setzt `FileSync` zum ersten Mal ein Foto und ist `sync_state.photos_auto_enabled` falsch, schaltet es `showImages` ein und setzt das Merkmal. Jede Stelle, die ein Bild aus einer Datei zeigt, hat einen `errorBuilder`, der auf die Taste ohne Bild bzw. `KassaLogo` zurückfällt.

- [ ] **Step 1: Tests.** `file_sync_test.dart` mit nachgebautem Server und Temp-Ordner: `test('lädt das Foto und setzt den Pfad')`; `test('Abbruch mitten im Laden: kein Pfad, keine halbe Datei außer .part, nächster Lauf lädt neu')` (Review Focus 4); `test('404 für eine Datei: Artikel bleibt ohne Bild, die anderen laden')`; `test('Foto ersetzt: altes Bild bleibt bis das neue da ist, danach ist die alte Datei weg')`; `test('Foto entfernt: Pfad leer, Datei weg')`; `test('erstes Foto schaltet Bilder anzeigen ein, ein späteres nach dem Ausschalten nicht mehr')`; `test('Logo genauso')`. `wire_test.dart`: Seite ohne `photo` und Seite mit `photo: null` lesen beide. Widget-Test: `test('kaputte Bilddatei: Taste ohne Bild, kein Fehler')`. Vergleichsbilder: Kopfleiste und Anmeldung mit Logo, Artikel-Taste mit Foto.
- [ ] **Step 2: rot. Step 3: umsetzen. Step 4: grün**: `flutter test test/sync test/features/kassa_test.dart test/features/login_test.dart test/golden/kassa_golden_test.dart`.
- [ ] **Step 5: Commit** "App: Fotos und Logo vom Server laden und zeigen".

### Task 10: App: Fehlerberichte

**Files:**
- Create: `app/lib/data/report_repository.dart`, `app/lib/core/error_capture.dart`, `app/test/data/report_repository_test.dart`, `app/test/core/error_capture_test.dart`
- Modify: `app/lib/main.dart`, `app/lib/features/settings/device_test_screen.dart`, `app/lib/sync/push_wire.dart`, `app/lib/data/providers.dart`, `app/pubspec.yaml` (`device_info_plus`, falls das Gerätemodell heute anders gelesen wird: denselben Weg wie `PairingService` verwenden)

**Interfaces:**
- Consumes: Tabelle `reports` und ihr Trigger (Task 5).
- Produces:
  - `class ReportRepository(KassaDatabase db, Clock clock, {required String appVersion, String? androidVersion, String? deviceModel})`: `Future<void> addError(Object error, StackTrace? stack)`, `Future<void> addDeviceTest(List<({String device, bool ok, String text})> results)`. Beide werfen nie.
  - `void installErrorCapture(ReportRepository Function() reports)`: setzt `FlutterError.onError` (ruft den bisherigen Handler weiter), `PlatformDispatcher.instance.onError` (gibt `true` zurück). `main` läuft in `runZonedGuarded`.
  - `PushPayloads.build` für `report` (Form siehe Nachrichtenformen).

Regeln (Entwurf 5.7, Teil C 5.8): `error.type` ist `error.runtimeType.toString()`. `message` nur für `TimeoutException`, `RangeError`, `TypeError`, `NoSuchMethodError`, `AssertionError`, `UnsupportedError`, `UnimplementedError`, `MissingPluginException` und bei `PlatformException` nur `code`; sonst `null`. Höchstens 500 Zeichen. `stack` höchstens 8.000 Zeichen. `signature` = Art plus die ersten fünf Zeilen der Aufrufliste. Hat der jüngste Bericht dieselbe `signature` und wartet er noch in der Liste (noch nicht gesendet), wird sein `count` erhöht statt eines neuen. Ein schon gesendeter Bericht wird nie mehr geändert: der Server nimmt Berichte nur neu an. Höchstens 50 neue Berichte pro Kalendertag, weitere werden verworfen. Ein Fehler beim Schreiben eines Berichts wird geschluckt (kein Bericht über den Bericht).

- [ ] **Step 1: Tests.** `test('StateError mit Artikelname in der Meldung: message ist null, type und stack sind da')`; `test('TimeoutException: message ist da und höchstens 500 Zeichen')`; `test('derselbe Fehler dreimal: ein Bericht mit count 3, die Liste hat einen Eintrag report')`; `test('derselbe Fehler nach dem Senden: ein neuer Bericht, der alte bleibt unverändert')`; `test('51 verschiedene Fehler an einem Tag: 50 Berichte')`; `test('Datenbank geschlossen: addError wirft nicht')`; `test('Geräte testen: ein Bericht device_test mit den Zeilen des Bildschirms')`; `test('Bericht enthält keine Schlüssel außer denen der Nachrichtenform')`; `error_capture_test.dart`: `test('Fehler in einem Widget landet als Bericht und der bisherige Handler läuft weiter')`, `test('Fehler in einem Future außerhalb der Oberfläche landet als Bericht')`.
- [ ] **Step 2: rot. Step 3: umsetzen. Step 4: grün.**
- [ ] **Step 5: Commit** "App: unerwartete Fehler und Geräte-Tests als Bericht".

### Task 11: App: Einstellungen "Server" und Rückfrage vor dem Koppeln

**Files:**
- Modify: `app/lib/features/settings/server_panel.dart`, die Rückfrage vor dem Koppeln (`PairQuestion`, in `app/lib/features/settings/` oder `app/lib/features/setup/`), `app/test/features/server_settings_test.dart`, `app/test/features/pairing_test.dart`, `app/test/golden/settings_golden_test.dart`, `app/test/golden/pairing_golden_test.dart`

**Interfaces:**
- Consumes: `outboxCountsProvider` (Task 5).

Texte (Entwurf 5.11), genau so:
- unter "Zuletzt abgeglichen …", nur wenn `pending > 0`: `Wartet noch: <n>`
- nur wenn `rejected > 0`, ruhige Warnfarbe: `1 Eintrag wurde vom Server abgelehnt. Niko weiß Bescheid.` bzw. `<n> Einträge wurden vom Server abgelehnt. Niko weiß Bescheid.`
- in der Rückfrage vor dem Koppeln ein Satz mehr: `Preise, Favoriten und "Im Verkauf" von diesem Tablet werden durch den Stand des Servers ersetzt.`

- [ ] **Step 1: Tests**: Karte ohne wartende Einträge zeigt keine der Zeilen; mit 3 wartenden `Wartet noch: 3`; mit 1 und mit 2 abgelehnten den jeweiligen Satz; die Rückfrage enthält den neuen Satz; Vergleichsbilder der Karte (wartend, abgelehnt) und der Rückfrage neu. Der Text passt bei größter Schrift ohne Überlauf.
- [ ] **Step 2: rot. Step 3: umsetzen. Step 4: grün.**
- [ ] **Step 5: Commit** "App: Karte Server zeigt Wartendes, Rückfrage nennt die Preise".

### Task 12: Server: Umsätze, Bons und Tage für die Verwaltung

**Files:**
- Create: `server/src/admin/overview.ts`, `server/src/admin/receipts.ts`, `server/src/admin/days.ts`, `server/test/overview.test.ts`, `server/test/receipts.test.ts`, `server/test/days.test.ts`
- Modify: `server/src/app.ts`

**Interfaces:**
- Consumes: `shared/fixtures/stats/overview.json` (Task 6), `pushEntries` (Task 2), `requireBusinessAccess`.
- Produces:
  - `GET /api/admin/businesses/:b/overview?range=today|days7|days30` → `{ "range", "testMode": bool, "revenueCents", "previousRevenueCents", "receiptCount", "voidCount", "buckets": [{ "label", "start", "cents" }], "cashCents", "cardCents", "topItems": [{ "name", "quantity", "cents" }], "byCategory": [{ "name", "cents" }] }`
  - `GET /api/admin/businesses/:b/receipts?day=YYYY-MM-DD&payment=cash|card&voided=1&before=<Kennung>` → `{ "receipts": [{ "id", "number", "registerName", "createdAt", "kind", "staffName", "totalCents", "paymentKind", "test", "voided": bool }], "next": <Kennung oder null> }`, 50 pro Seite, neueste zuerst.
  - `GET /api/admin/businesses/:b/receipts/:id` → Kopf wie oben, dazu `lines` (mit `options`), `payment`, `goodsCents`, `depositCents`, `voidsReceiptId`, `voidedByReceiptId`, `rksv: { "cashBoxId", "damaged", "probe" } | null`.
  - `GET /api/admin/businesses/:b/days` → `{ "days": [{ "id", "registerName", "openedAt", "closedAt", "expectedCents", "countedCents", "differenceCents", "closedByName" }] }`, neueste zuerst, höchstens 100; `GET …/days/:id` dazu `openingFloatCents`, `leftInDrawerCents`, `movements: [{ "kind", "amountCents", "reason", "createdAt", "staffName" }]`, `receiptCount`, `revenueCents`.

Regeln (Entwurf 5.10, Teil C 5.5): Die Auswertung ist `app/lib/data/stats_repository.dart` nachgebaut: Kalendertage in `businesses.time_zone`, nur `sale` und `voided`, Vergleichszeitraum, höchstens fünf Artikel nach Menge, Kategorien nach dem heutigen Stand von `items` und `categories` (unbekannt: "Sonstiges"), Pfand als eigene Zeile am Ende. Zuerst die Datei lesen, dann nachbauen. `testMode` ist wahr, solange der Betrieb keinen Bon mit `is_test = false` hat; dann zählen alle Bons. Sonst zählen nur echte.

- [ ] **Step 1: Tests.** `overview.test.ts`: `test('gemeinsames Beispiel: dieselben Zahlen wie die App')` (Bons aus `overview.json` über `pushEntries` einspielen, `time_zone` auf den Wert der Datei, Uhr auf `now`, alle drei Zeiträume gegen `expected`); `test('Europe/Vienna: ein Bon um 23:30 UTC zählt zum nächsten Tag')`; `test('nur Testbons: testMode wahr, sie zählen')`; `test('ein echter Bon: testMode falsch, Testbons zählen nicht mehr')`; `test('zwei Kassen: Summe über beide')`; `test('kein Bon: alles 0, leere Listen')`; `test('range unbekannt: 422')`. `receipts.test.ts`: Liste, Seiten über `before`, jeder Filter, Storno-Paar zeigt aufeinander, Detail mit Optionen, unbekannte Kennung 404. `days.test.ts`: offener und abgeschlossener Tag, Bewegungen im Detail. Für alle drei: zweiter Betrieb sieht nichts (404 bzw. leere Liste), Chef des Betriebs darf, nicht angemeldet 401. Keine Antwort enthält `staffId`, `payload` oder `content_hash`.
- [ ] **Step 2: rot. Step 3: umsetzen. Step 4: grün.**
- [ ] **Step 5: Commit** "Server: Umsätze, Bons und Tagesabschlüsse für die Verwaltung".

### Task 13: Server: Artikel in der Verwaltung, Protokoll-Datei, Kassen

**Files:**
- Create: `server/src/admin/items.ts`, `server/src/admin/dep.ts`, `server/test/items.test.ts`, `server/test/dep.test.ts`
- Modify: `server/src/admin/registers.ts`, `server/test/registers.test.ts`, `server/src/app.ts`

**Interfaces:**
- Consumes: `applyItemField` (Task 3), `shared/fixtures/rksv/dep.json` (Task 6), `audit`.
- Produces:
  - `GET /api/admin/businesses/:b/items` → `{ "categories": [{ "id", "name", "archived", "items": [{ "id", "name", "priceCents", "inSale", "favorite", "archived", "photo": { "id", "color" } | null }] }] }` in der Reihenfolge der Speisekarte.
  - `PATCH /api/admin/businesses/:b/items/:id` mit `{ "priceCents"?, "inSale"?, "favorite"? }` (mindestens eines, sonst 422 `nothing_to_change`; andere Schlüssel 422) → der Artikel wie in der Liste. Jedes Feld über `applyItemField` mit der Uhr des Servers. Verlauf `item.update` mit den geänderten Feldern.
  - `buildDep(c: pg.PoolClient, deviceId: string, chain: number): Promise<object | null>` in der Form des Finanzministeriums, gleiche Gruppierung wie `buildDepExport` in `app/lib/rksv/dep_export.dart` (diese Datei zuerst lesen).
  - `GET /api/admin/businesses/:b/registers/:r/dep?chain=<n>` → die Datei als Download, `Content-Disposition: attachment; filename="kassa-protokoll-<cashBoxId>-kette-<n>.json"`. Verlauf `rksv.dep_download`. Unbekannte Kassa oder Kette: 404.
  - Die Liste der Kassen (`GET …/registers`) nennt pro Kassa zusätzlich `lastReceiptAt` und `chains: [{ "chain", "mode", "cashBoxId", "startedAt", "endedAt", "entries": <Anzahl> }]` (über `registers.device_id`; Kassen mit derselben Geräte-Kennung zeigen dieselben Ketten).

- [ ] **Step 1: Tests.** `items.test.ts`: Liste nach Kategorie; `test('Preis ändern: neue Änderungs-Nummer, Tablet holt den Preis')`; `test('Preis im Browser nach einer Änderung vom Tablet: der Browser gewinnt, weil er später ist')`; `test('priceCents -1, 1.5 oder "9": 422')`; `test('name im Körper: 422, nichts geändert')`; unbekannter Artikel 404; zweiter Betrieb 404; Verlauf enthält den Eintrag. `dep.test.ts`: `test('gemeinsames Beispiel: dieselbe Datei wie die App')` (Einträge aus `dep.json` einspielen, Ausgabe gleich `expected`); Kette eines anderen Geräts desselben Betriebs kommt nicht mit; Download steht im Verlauf; zweiter Betrieb 404; Probe-Kette wird geliefert. `registers.test.ts`: `lastReceiptAt` und `chains` nach einem Paket; zwei Kassen mit derselben Geräte-Kennung.
- [ ] **Step 2: rot. Step 3: umsetzen. Step 4: grün.**
- [ ] **Step 5: Commit** "Server: Preis und Schalter im Browser, Protokoll-Datei, Kassen mit Ketten".

### Task 14: Server: Fehlerberichte in der Verwaltung und nächtliche Sicherung

**Files:**
- Create: `server/src/admin/reports.ts`, `server/src/backup/backup.ts`, `server/test/reports.test.ts`, `server/test/backup.test.ts`, `docs/betrieb/sicherung-zurueckspielen.md`
- Modify: `server/src/config.ts` (`PG_DUMP_PATH`, Vorgabe `pg_dump`; `BACKUP_DISABLED=1` schaltet ab), `server/src/main.ts`, `server/src/app.ts`, `server/README.md`, `server/test/config.test.ts`

**Interfaces:**
- Consumes: `list_reports` und `backups` (Task 1), `FileStore`.
- Produces:
  - `GET /api/admin/reports?before=<ISO-Zeit>` (nur Anbieter, Chef 404) → `{ "reports": [{ "id", "businessName", "registerName", "source", "kind", "at", "appVersion", "deviceModel", "count", "content" }], "next" }`, 50 pro Seite.
  - `GET /api/admin/backups/latest` (nur Anbieter) → `{ "latest": { "day", "finishedAt", "size" } | null, "lastError": { "at", "error" } | null }`.
  - `runBackupIfDue(deps: AppDeps, opts?: { pgDumpPath?: string }): Promise<'done' | 'not_due' | 'failed'>`: fällig, wenn es in Europe/Vienna 3 Uhr oder später ist und `backups` für den heutigen Wiener Tag keine Zeile mit `ok` hat. Ruft `pg_dump --format=custom` mit `DATABASE_URL` auf, schreibt nach `backups/kassa-<YYYY-MM-DD>.dump`, trägt die Zeile ein, löscht alle gelungenen bis auf die 14 jüngsten (Zeile und Objekt). Wirft nie; ein Fehler ergibt eine Zeile mit `ok = false` und eine Zeile `sicherung gescheitert` im Protokoll. Die Fehlermeldung nennt nie `DATABASE_URL`.
  - `checkPgDump(deps): Promise<string | null>`: `null`, wenn die Hauptversion von `pg_dump` mindestens die der Datenbank ist, sonst ein Satz für das Protokoll. `main.ts` ruft es beim Start, dann `runBackupIfDue` nach einer Minute und danach jede Stunde.

- [ ] **Step 1: Tests.** `reports.test.ts`: Berichte zweier Betriebe erscheinen beim Anbieter, neueste zuerst, mit Namen; Chef bekommt 404; Seiten über `before`. `backup.test.ts` (mit `pgDumpPath` auf `/usr/lib/postgresql/16/bin/pg_dump`; fehlt die Datei, den Test überspringen und das im Ergebnis sagen): `test('vor 3 Uhr Wiener Zeit: not_due')`; `test('nach 3 Uhr ohne Sicherung: done, Datei in der Ablage, Zeile ok')`; `test('zweiter Aufruf am selben Tag: not_due')`; `test('16 Tage hintereinander: 14 Dateien bleiben')`; `test('pg_dump fehlt: failed, Zeile mit Fehler, kein Wurf, kein Passwort in der Meldung')`; `test('Zurückspielen: die Sicherung in eine leere Datenbank spielen ergibt dieselbe Zeilenzahl in jeder Tabelle')` (mit `pg_restore`). `config.test.ts`: die neuen Variablen.
- [ ] **Step 2: rot. Step 3: umsetzen. Step 4: grün.**
- [ ] **Step 5: Anleitung schreiben** `docs/betrieb/sicherung-zurueckspielen.md`: wo die Dateien liegen, wie man eine holt, der Befehl zum Zurückspielen in eine leere Datenbank, was danach zu prüfen ist, dass Fotos nicht dabei sind. Die Schritte einmal von Hand gegen die Test-Datenbank durchgehen und die echten Ausgaben einsetzen.
- [ ] **Step 6: Commit** "Server: Fehlerberichte für den Anbieter, nächtliche Sicherung".

### Task 15: Server: Grenzen aus Stufe 1

**Files:**
- Modify: `server/src/rate_limit.ts`, `server/src/client_address.ts`, `server/src/device/pair.ts`, `server/src/app.ts`, `server/src/main.ts`, `server/test/pair.test.ts`, `server/test/health.test.ts`, eigener Test `server/test/rate_limit.test.ts` (anlegen, falls es ihn nicht gibt)

**Interfaces:**
- Produces: `rateKey(address: string): string` in `client_address.ts`: IPv4 unverändert, IPv6 auf das Netz /64 gekürzt (`2001:db8:1:2::/64`), IPv4 in IPv6-Schreibweise (`::ffff:1.2.3.4`) als IPv4.

Regeln (Entwurf 5.12): Falsche Kopplungscodes zählen zusätzlich über alle Adressen: höchstens 200 in 15 Minuten, danach 429 `too_many_attempts` für alle, bis das Fenster weiterrückt. Richtige Codes zählen nicht. Die Grenzen pro Adresse (Koppeln, Anmelden) verwenden `rateKey`. Der Server beendet eine Anfrage, deren Körper nicht binnen 30 Sekunden ankommt, und eine Verbindung, die 60 Sekunden nichts schickt (Einstellungen von Fastify bzw. Node; nachsehen, wie sie in Fastify 5.12 heißen).

- [ ] **Step 1: Tests**: `rateKey` für die drei Fälle und für Unsinn (bleibt, wie es ist); zehn falsche Codes von zehn Adressen im selben /64 sperren die elfte; 200 falsche Codes von 200 IPv4-Adressen sperren eine neue Adresse, ein richtiger Code vorher geht durch; eine Anfrage, die ihren Körper nie beendet, bekommt ihre Verbindung geschlossen (mit kurzer Grenze im Test).
- [ ] **Step 2: rot. Step 3: umsetzen. Step 4: grün**, dazu `npx vitest run` ganz.
- [ ] **Step 5: Commit** "Server: Grenze für Koppel-Versuche über alle Adressen, IPv6 pro Netz, Zeitgrenzen".

### Task 16: Web: Umsätze

**Files:**
- Create: `web/src/pages/OverviewPage.tsx`, `web/src/pages/OverviewPage.module.css`, `web/src/api/overview.ts`, `web/src/ui/BarChart.tsx`, `web/src/ui/BarChart.module.css`, `web/src/ui/Segmented.tsx` (falls es keinen Umschalter gibt), `web/e2e/overview.spec.ts`
- Modify: `web/src/routes.tsx` (Weg `/b/:b/umsaetze`, erster Punkt der Leiste "Umsätze", `BusinessIndex` führt dorthin), `web/src/ui/icons.tsx`, `web/src/format.ts` und `web/src/format.test.ts` (Geld, Prozent-Vergleich), `web/e2e/support/fixtures.ts` (Bons über die Tablet-Schnittstelle einspielen), `web/e2e/shots.spec.ts`

**Interfaces:**
- Consumes: `GET …/overview` (Task 12).
- Produces: `useOverview(b: string, range: 'today' | 'days7' | 'days30')`; `BarChart({ buckets, label })`; `money(cents: number): string` (`12,90 €`, Tabellenziffern über CSS), in `format.ts`, falls noch nicht da.

Vor dem Bau die Skills `impeccable`, `design-taste-frontend`, `emil-design-eng` und `dataviz` lesen und `DESIGN.md` befolgen. Aufbau der Seite (ein Bildschirm am Handy ohne waagrechtes Scrollen, am Rechner zwei Spalten):
- Kopf "Umsätze" mit Umschalter Heute, 7 Tage, 30 Tage (bleibt beim Wechsel stehen, die Zahlen darunter wechseln ohne Sprung im Layout).
- Große Zahl Umsatz, darunter der Vergleich ("12 % mehr als in den 7 Tagen davor", "weniger", oder nichts, wenn der Vergleichszeitraum 0 ist), daneben Bons und Stornos.
- Balken nach Stunde (heute) oder Tag. Jeder Balken ist mit Tastatur erreichbar und nennt Zeit und Betrag als Text. Kein Balken ohne Wert verschwindet aus der Achse.
- Bar und Karte als zwei Zahlen mit Anteil. Die fünf meistverkauften Artikel als Liste mit Menge und Betrag. Umsatz nach Kategorie als Liste mit Betrag.
- Hinweis `Testbetrieb: Alle Bons sind Testbons.` solange `testMode`.
- Leerer Zustand: `Noch kein Bon. Sobald an der Kassa boniert wird, erscheinen die Umsätze hier.` Ladezustand als Skelett in der Form der Seite. Fehler mit "Nochmal versuchen".
- Die Seite lädt alle 60 Sekunden still nach, solange sie sichtbar ist, und zeigt dabei die alten Zahlen weiter.

- [ ] **Step 1: Tests**: `format.test.ts` für `money` (0, 5, 1290, 123456789, negativ) und den Vergleichssatz. `overview.spec.ts` im echten Browser: Betrieb ohne Bons zeigt den leeren Zustand; nach drei eingespielten Bons stehen Umsatz, Zahl der Bons, bar und Karte und der meistverkaufte Artikel da; Wechsel auf 7 Tage; bei 360 px Breite kein waagrechtes Scrollen (`scrollWidth <= clientWidth`); Chef sieht die Seite seines Betriebs. Bilder in `shots.spec.ts`: Handy und Rechner, hell und dunkel.
- [ ] **Step 2: rot. Step 3: umsetzen. Step 4: grün** (`npm test`, `npm run e2e -- overview.spec.ts`), die Bilder ansehen und gegen `DESIGN.md` prüfen.
- [ ] **Step 5: Commit** "Web: Seite Umsätze".

### Task 17: Web: Bons und Tagesabschlüsse

**Files:**
- Create: `web/src/pages/ReceiptsPage.tsx` (+ `.module.css`), `web/src/pages/DaysPage.tsx` (+ `.module.css`), `web/src/api/receipts.ts`, `web/src/api/days.ts`, `web/e2e/receipts.spec.ts`
- Modify: `web/src/routes.tsx` (`/b/:b/bons`, `/b/:b/bons/:id`, `/b/:b/tage`, `/b/:b/tage/:id`, Leiste "Bons", "Tagesabschlüsse"), `web/src/ui/icons.tsx`, `web/e2e/shots.spec.ts`

**Interfaces:**
- Consumes: Adressen aus Task 12, `DataList`, `DataRow`, `StatusChip`, `Dialog`, `Skeleton`, `EmptyState`, `money`.

Verhalten (Entwurf 5.10): Bons: Filter als Zeile über der Liste (Tag als Datumsfeld mit "Heute" als Vorgabe leer = alle, Zahlungsart, "Nur Stornos"); die Filter stehen in der Adresse, damit Zurück und Neuladen sie behalten. Zeile: Nummer, Uhrzeit, Kassa, Mitarbeiter, Betrag rechts, Merkmale "Testbon", "Storno", "Storniert". "Mehr laden" am Ende. Ein Bon öffnet als eigene Adresse (am Rechner als Blatt von rechts, am Handy ganze Seite): Zeilen mit Optionen eingerückt, Pfand, Summe, Zahlung (bar: gegeben und Rückgeld; Karte: Kartenart und letzte vier Ziffern), Signatur ("Probe", "ausgefallen"), Verweis auf Storno bzw. stornierten Bon. Sonderbelege zeigen ihren Namen (Startbeleg, Monatsbeleg, Jahresbeleg, Nullbeleg, Sammelbeleg, Schlussbeleg) statt eines Betrags. Tage: Liste mit Datum, Kassa, "offen" oder Abschlusszeit, Umsatz, Differenz (in Warnfarbe, wenn nicht 0); Detail mit Wechselgeld, erwartet, gezählt, Differenz, in der Lade gelassen, Bewegungen. Nichts ist änderbar. Leere Zustände: `Noch kein Bon.` mit dem Satz aus Task 16; mit Filter: `Kein Bon passt zu diesem Filter.` und der Taste "Filter zurücksetzen".

- [ ] **Step 1: Tests** `receipts.spec.ts`: Liste zeigt eingespielte Bons neueste zuerst; Filter "Karte" und "Nur Stornos"; Filter bleibt nach Neuladen; Bon öffnen zeigt Zeilen, Option und Rückgeld; Zurück führt zur gefilterten Liste; Tage: abgeschlossener Tag mit Differenz und Bewegung; 360 px ohne waagrechtes Scrollen; alles mit Tastatur erreichbar (Tab bis zum Bon, Eingabe öffnet, Escape schließt). Bilder: Liste und Detail, Handy und Rechner.
- [ ] **Step 2: rot. Step 3: umsetzen. Step 4: grün.**
- [ ] **Step 5: Commit** "Web: Seiten Bons und Tagesabschlüsse".

### Task 18: Web: Speisekarte mit Preis, Schaltern und Foto, Seite Betrieb mit Logo

**Files:**
- Create: `web/src/api/items.ts`, `web/src/api/files.ts`, `web/src/pages/BusinessPage.tsx` (+ `.module.css`), `web/src/ui/Switch.tsx` (+ `.module.css`), `web/src/ui/PhotoButton.tsx` (+ `.module.css`), `web/src/ui/PriceField.tsx` (+ `.module.css`), `web/e2e/menu.spec.ts`
- Modify: `web/src/pages/MenuPage.tsx` (+ `.module.css`), `web/src/routes.tsx` (`/b/:b/betrieb`, Leiste "Betrieb"), `web/src/ui/FileDrop.tsx` (Bilder), `web/src/pages/validate.ts`, `web/e2e/shots.spec.ts`

**Interfaces:**
- Consumes: Adressen aus Task 4 und 13.
- Produces: `useItems(b)`, `usePatchItem(b)` (optimistisch: der Wert steht sofort da, bei Fehler springt er zurück und `toast` nennt den Grund), `useSetPhoto(b)`, `useRemovePhoto(b)`, `useSetLogo(b)`, `useRemoveLogo(b)`; `parsePrice(text: string): number | null` in `validate.ts` (`9,90`, `9.90`, `9`, `9,9` → Cent; negativ, drei Nachkommastellen, Buchstaben, leer → `null`; Obergrenze 99.999,99 €).

Verhalten (Entwurf 5.5, 5.10): Speisekarte zeigt die Artikel nach Kategorie (stillgelegte Kategorien und Artikel am Ende, gedämpft, ohne Bedienelemente). Zeile: Foto-Feld (56 px, Platzhalter in `color`, ohne Foto ein Kamera-Zeichen), Name, Preisfeld, Schalter "Im Verkauf", Stern für Favorit. Preis: Eingabe speichert bei Enter oder Verlassen des Felds, Escape verwirft; unlesbare Eingabe zeigt `Gib einen Preis wie 9,90 ein.` am Feld und speichert nicht. Foto-Feld öffnet ein Fenster: Datei wählen oder hineinziehen, Vorschau, "Speichern", bei vorhandenem Foto "Foto entfernen". Vor dem Hochladen prüft die Seite Art (JPEG, PNG, WebP) und Größe (10 MB) und sagt es in einem Satz; Fehler des Servers (`image_invalid`, 413) erscheinen als derselbe Satz. Während des Hochladens zeigt das Feld Fortschritt und bleibt bedienbar. Die Kopfzeile eines Betriebs in der Verwaltung zeigt das Logo neben dem Namen, sobald es eines gibt. Seite Betrieb: Logo (hochladen, ersetzen, entfernen, gleiche Bausteine), darunter Name, Adresse, UID, Text am Bon-Ende nur zur Ansicht mit dem Satz `Ändern kommt mit der nächsten Stufe. Bis dahin: Speisekarte neu einspielen.` (nur für den Anbieter sichtbar). Nach jeder Änderung an Artikel oder Foto der Hinweis `Kommt beim nächsten Abgleich an die Kassa.` als ruhige Meldung, höchstens einmal pro Besuch der Seite.

- [ ] **Step 1: Tests**: Einheiten für `parsePrice` (alle Fälle oben). `menu.spec.ts`: Preis ändern und nach Neuladen steht der neue Preis; unlesbarer Preis zeigt den Satz und ändert nichts; Schalter "Im Verkauf" aus und Favorit an, beide bleiben nach Neuladen; Server antwortet 500 (Anfrage im Test abfangen): Wert springt zurück, Meldung erscheint; Foto hochladen (Testbild), Feld zeigt das Bild, ersetzen, entfernen; Textdatei mit Endung `.jpg`: Satz vom Server; Logo hochladen und entfernen; Chef darf alles auf diesen Seiten außer "Neu einspielen"; 360 px ohne waagrechtes Scrollen; Preisfeld und Schalter haben Beschriftungen für Vorleseprogramme. Bilder: Speisekarte und Foto-Fenster, Handy und Rechner.
- [ ] **Step 2: rot. Step 3: umsetzen. Step 4: grün.**
- [ ] **Step 5: Commit** "Web: Preis, Schalter und Foto in der Speisekarte, Logo auf der Seite Betrieb".

### Task 19: Web: Kassen mit Protokoll, Fehlerberichte, Leiste

**Files:**
- Create: `web/src/pages/ReportsPage.tsx` (+ `.module.css`), `web/src/api/reports.ts`, `web/e2e/reports.spec.ts`
- Modify: `web/src/pages/RegistersPage.tsx` (+ `.module.css`), `web/src/api/registers.ts`, `web/src/routes.tsx` (`/fehlerberichte`, nur Anbieter, in `providerNav`), `web/e2e/flow.spec.ts`, `web/e2e/shots.spec.ts`

**Interfaces:**
- Consumes: Adressen aus Task 13 und 14.

Verhalten: Kassen: pro Kassa zusätzlich "Letzter Bon vor 5 Minuten" (oder "Noch kein Bon"), und pro Kette eine Zeile `Kassen-ID <cashBoxId> · <n> Einträge` mit Merkmal "Probe" und der Taste "Protokoll herunterladen" (ein gewöhnlicher Download-Link, der die Datei speichert). Ohne Kette steht dort nichts. Fehlerberichte: oben die Karte `Letzte Sicherung: heute, 03:12` (oder `Noch keine Sicherung.`; in Warnfarbe mit dem Satz `Die letzte Sicherung ist älter als 36 Stunden.`, wenn es so ist; bei `lastError` der Zeitpunkt des letzten Fehlers). Darunter die Liste: Zeit, Betrieb, Kassa, Art ("Fehler", "Geräte-Test", "Server"), App-Version, Zähler als "×3"; Antippen klappt den Inhalt auf (Fehlerart, Meldung, Aufrufliste in fester Schrift, bei Geräte-Tests die Zeilen). "Mehr laden". Leerer Zustand: `Keine Berichte. Das ist gut.`

- [ ] **Step 1: Tests** `reports.spec.ts`: Anbieter sieht Berichte zweier Betriebe und klappt einen auf; Chef kommt über die Adresse nicht auf die Seite; Karte der Sicherung in den drei Zuständen (Antwort im Test abfangen). `flow.spec.ts` erweitern: nach einem eingespielten Paket mit Kette zeigt die Kasse Kassen-ID und Taste, der Download liefert eine Datei mit dem Schlüssel `Belege-Gruppe`. Bilder.
- [ ] **Step 2: rot. Step 3: umsetzen. Step 4: grün**, dazu `npm run e2e` ganz (ohne `shots.spec.ts`, die läuft allein).
- [ ] **Step 5: Commit** "Web: Protokoll herunterladen, Fehlerberichte mit Stand der Sicherung".

### Task 20: Zusammenspiel, Version 1.5.0, Prüfliste

**Files:**
- Create: `app/test_e2e/push_and_sync_test.dart`, `docs/testen/teil-c2-pruefliste.md`
- Modify: `tool/e2e.sh` (falls nötig), `server/src/dev/seed.ts` (ein Artikel-Foto anlegen können), `app/pubspec.yaml` (1.5.0+7), `app/lib/core/app_info.dart`, `docs/superpowers/specs/2026-11-19-teil-c2-abgleich-design.md` (Abschnitt "Abweichungen beim Bau"), `server/README.md`

- [ ] **Step 1: `push_and_sync_test.dart`** gegen den echten Server (wie `pair_and_pull_test.dart`): koppeln; über die echten Repositories einen Tag öffnen, bar verkaufen, stornieren, eine Bewegung buchen, den Tag abschließen; `syncNow()`; über die Adressen der Verwaltung (Anmeldung aus dem Seed) prüfen: zwei Bons, ein abgeschlossener Tag, eine Bewegung, Umsatz 0 mit einem Storno. Dann: Preis am Server ändern (`PATCH`), `syncNow()`, Preis am Tablet ist neu; Preis am Tablet ändern, `syncNow()`, Preis am Server ist der vom Tablet; Foto am Server setzen, `syncNow()`, Datei liegt am Tablet und `photoPath` zeigt darauf; 250 Bons erzeugen, `syncNow()`, die Liste ist leer und der Server hat 252 (Review Focus 5); `syncNow()` noch einmal ändert nichts (Review Focus 1).
- [ ] **Step 2: `tool/e2e.sh` laufen lassen.** Erwartet: alle Tests in `app/test_e2e` grün.
- [ ] **Step 3: Version erhöhen** auf 1.5.0 (Build 7) in `pubspec.yaml` und `app_info.dart`. Zweig hochladen und die Prüfung `app` auf GitHub abwarten (alle Tests und `flutter analyze`). Server und Web ganz: `npx vitest run` in `server/`, `npm test` und `npm run e2e` in `web/`.
- [ ] **Step 4: Prüfliste schreiben** für Niko, in einfachen Worten, mit Kästchen, in der Reihenfolge: Update von 1.4.0 einspielen (Bons vom Tablet erscheinen im Browser, Preise vom Tablet bleiben), bonieren und im Browser sehen, Storno, Tagesabschluss, Bargeld-Bewegung, Umsätze am Handy, Preis im Browser ändern und am Tablet sehen (mit "Jetzt abgleichen"), Preis am Tablet ändern und im Browser sehen, Foto hochladen ("Bilder anzeigen" schaltet sich ein), Logo, ohne Internet bonieren und nachkommen lassen ("Wartet noch"), Probe-Signatur einschalten und Protokoll im Browser herunterladen, "Geräte testen" und den Bericht im Browser sehen, Letzte Sicherung am nächsten Morgen. Zu jedem Punkt, was zu sehen sein soll. Am Ende: was in Stufe 2 bewusst nicht geht (aus den Nicht-Zielen).
- [ ] **Step 5: Abweichungen** beim Bau in den Entwurf nachtragen (neuer Abschnitt 9), wie in Teil C Abschnitt 9.
- [ ] **Step 6: Commit** "Zusammenspiel für Stufe 2, Version 1.5.0 (Build 7), Prüfliste".

### Task 21: Auslieferung (macht Claude selbst, nicht ein Helfer)

**Files:**
- Modify: `Dockerfile` (im zweiten Abschnitt `postgresql-client-18` aus dem Paketverzeichnis von PostgreSQL, vor `USER node`), `.dockerignore` falls nötig

- [ ] **Step 1: Abbild.** `pg_dump` in Version 18 ins Abbild. Geht das bei Railway nicht, gilt der zweite Weg aus dem Entwurf (Abschnitt 4, Sicherung): eigene Sicherung in Node. Dann Task 14 anpassen und Niko sagen.
- [ ] **Step 2: Vor dem Ausrollen** bei Railway prüfen (ohne Werte von Variablen zu lesen): Dienst, Datenbank, Ablage laufen; Stand der Datenbank ist 0001. Die Railway-Sicherung des Volumes anstoßen, falls Nikos Tarif sie hat.
- [ ] **Step 3: Ausrollen** mit `connect-service-source` auf den Commit dieses Plans (siehe Projektnotiz `kassa-railway`). Im Protokoll nachsehen: Migration `0002_sync.sql` angewendet, `checkPgDump` meldet nichts, `/healthz` antwortet.
- [ ] **Step 4: Am echten Server prüfen**, soweit es ohne Konto in der Verwaltung geht (Claude hat keines und legt keines an): `/healthz`, das Protokoll des Dienstes ohne Fehler, eine Anfrage an `POST /api/device/sync/push` ohne Schlüssel ergibt 401. Die erste Sicherung zeigt sich nach 3 Uhr im Protokoll. Alles Weitere prüft Niko mit der Prüfliste; was am echten Server ungeprüft bleibt, steht in der Übergabe.
- [ ] **Step 5: Installationsdatei** 1.5.0 bauen (`tool/build_apk.sh arm64`, siehe Projektnotiz `kassa-apk-bau`; ohne SumUp-Schlüssel mit `KASSA_ALLOW_NO_SUMUP=1`, solange Niko keinen geliefert hat), Signatur prüfen, über `PUT /api/releases/1.5.0?build=7` hochladen, den geheimen Link an Niko.
- [ ] **Step 6: Übergabe** an Niko: Link zur Installationsdatei, Prüfliste, Bilder der neuen Seiten, die Liste der Entscheidungen beim Bau als Claude Doc, was ungeprüft ist. Projektnotizen `kassa-teil-c`, `kassa-build`, `kassa-railway` nachführen.
