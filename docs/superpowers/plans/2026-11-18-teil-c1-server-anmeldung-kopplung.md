# Teil C1: Server, Anmeldung, Kopplung Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein Server bei Railway mit getrennten Daten pro Betrieb, eine Verwaltung im Browser, in der Niko sich anmeldet, einen Betrieb aus der Speisekarten-Datei anlegt, Mitarbeiter und einen Kopplungscode erzeugt, und ein Tablet, das sich mit diesem Code koppelt und Speisekarte, Mitarbeiter und Betriebsdaten vom Server holt. Dazu die Installationsdatei über einen geheimen Link.

**Architecture:** Neuer Ordner `server/` (TypeScript auf Node, Fastify, PostgreSQL über `pg` mit SQL-Dateien, kein ORM) und `web/` (React mit Vite). Der Server liefert die Schnittstelle und die fertig gebauten Seiten aus einem Dienst. Jede Tabelle mit Betriebsdaten trägt `business_id` und ist zusätzlich durch Row Level Security gesperrt, der Dienst arbeitet mit einer Datenbank-Rolle, für die diese Sperre gilt. Die App bekommt einen Ordner `lib/sync/` mit Server-Zugang, Kopplung und "holen". Sie liest und schreibt weiter nur ihre eigene Datenbank.

**Tech Stack:** Node 22, TypeScript 7.0, Fastify 5.12 mit `@fastify/cookie` 11 und `@fastify/static` 10, `pg` 8.23, `zod` 4.6, `vitest` 5.1, `tsx` 4.23, `@aws-sdk/client-s3` 3. Web: React 19.3, Vite 8.3, `react-router` 8.5, `@tanstack/react-query` 5.108, `@playwright/test` genau 1.63.0 (passt zum vorinstallierten Chromium). App: Flutter 3.50.0 wie bisher, neu `http` und `flutter_secure_storage`. Mehrere dieser Versionen sind neuer als gewohnt: bei jeder Bibliothek vor dem Benutzen in deren aktueller Dokumentation nachsehen, nicht aus dem Gedächtnis schreiben.

**Spec:** `docs/superpowers/specs/2026-11-18-teil-c-server-und-verwaltung-design.md` (Stufe C1 aus 5.2, dazu 5.1, 5.3, 5.4, 5.5, 5.9, 5.11, 5.12, 5.13). Dahinter der Hauptentwurf `docs/superpowers/specs/2026-11-17-kassa-design.md`, `PRODUCT.md`, `DESIGN.md`, `docs/design-regeln.md`.

## Wo dieser Plan steht

| Plan | Inhalt | Stand |
|---|---|---|
| **C1 (dieser Plan)** | Server, Anmeldung, Betrieb aus Datei, Mitarbeiter, Kopplung, holen, Installationsdatei | geschrieben |
| C2 | Bons und Tage zum Server, Artikel-Änderungen in beide Richtungen, Fotos, Fehlerberichte, Sicherung | nach C1 |
| C3 | Verwaltung für den Chef | nach C2, Bilder vorher zu Niko |
| C4 | Kartenzahlung bei SumUp nachschlagen | nach Prüfung der Schnittstelle |

Nicht in C1: alles, was vom Tablet zum Server geht (Bons, Tage, Bargeld, Artikel-Änderungen, Berichte), Fotos und Logo, Chef-Zugang, Seiten Übersicht, Artikel, Kategorien, Vorlagen, Bons, Tagesabschlüsse, Betrieb. Bekannte Folge: Ändert jemand an einem gekoppelten Tablet einen Preis, geht das in C1 nicht zum Server, und ein späteres "holen" desselben Artikels überschreibt ihn. Das steht in der Prüfliste.

## Global Constraints

- Das Repo ist öffentlich. Zugangsdaten, Schlüssel, die Adresse des Servers und Daten von Betrieben kommen nie hinein (Ausnahme: `pilot/yichi-speisekarte.json`). Tests und Beispiele verwenden den erfundenen "Beispiel-Imbiss" und die Adresse `beispiel@example.com`.
- Bezeichner im Code englisch, alle Texte für Menschen deutsch in der Du-Form. Wörterbuch zusätzlich zu Teil A: Kopplung = `pairing`, Kopplungscode = `PairingCode`, Kassa (Gerät) = `Register`, Betrieb = `Business`, Anbieter = `provider`, Chef (Benutzer) = `chef`, Verwaltung = `admin`, holen = `pull`, stillgelegt = `archived`, gesperrt = `blocked`, Installationsdatei = `Release`, Verlauf = `audit`.
- Geldbeträge sind ganze Cent (`int` in Dart, `integer` in PostgreSQL, `number` in TypeScript). Nie Kommazahlen.
- Jede Antwort mit Fehler hat die Form `{"error":{"code":"<snake_case>","message":"<deutscher Satz>"}}`, bei der Speisekarte zusätzlich `"problems":[…]`. Die App und die Seiten entscheiden nach `code`, nie nach `message`.
- Trennung der Betriebe: Jede Abfrage auf Betriebsdaten läuft durch `withBusiness` oder `withBusinessWrite` (Task 2). Für jede Adresse unter `/api/admin/businesses/:b/…` und `/api/device/…` gibt es einen Test mit einem zweiten Betrieb, der nichts sieht und nichts ändert. Ein fremder oder unbekannter Betrieb ergibt 404 `not_found`, nie 403.
- Geheimnisse am Server (Sitzung, Geräte-Schlüssel, Kopplungscode, verbrauchte Einmal-Schlüssel) liegen nur als SHA-256 in der Datenbank. Passwörter mit scrypt. Nichts davon steht im Protokoll.
- Antworten an den Browser enthalten nie `pinSalt` oder `pinHash`.
- Kopplungscode: genau 8 Ziffern, gilt 15 Minuten, einmal verwendbar. Falsche Codes: höchstens 10 Versuche in 15 Minuten pro Internet-Adresse. Sitzung: 30 Tage ab letzter Benutzung. Passwort: mindestens 10 Zeichen. Speisekarten-Datei: höchstens 1 MB. Installationsdatei: höchstens 200 MB.
- App: kein Textfeld (der Test `no_text_field_test.dart` bleibt grün), Tippflächen mindestens 48 dp, Maße und Farben aus `DESIGN.md`, jede Änderung an der Datenbank mit Migration und Test, Netzwerk-Anfragen mit 10 Sekunden Zeitgrenze, und kein Bildschirm an der Theke wartet auf den Server. Einzige Ausnahme ist das Koppeln.
- Web: Farben, Schrift und Formen aus `DESIGN.md`, funktioniert ab 360 px Breite ohne waagrechtes Scrollen, alle Eingaben mit sichtbarem Fokus und Beschriftung, keine Schrift und kein Skript von fremden Adressen.
- Gebaut wird testgetrieben. Commits auf `claude/project-thread-xtooco`, ohne Pull Request, Commit-Texte deutsch. Nur die Dateien formatieren, die man anfasst.
- Befehle: Server aus `server/`, Web aus `web/`, App aus `app/` mit `export PATH="$HOME/flutter/bin:$PATH"`.

## Nachrichtenformen

Diese Formen gelten zwischen Server und App. Beispieldateien dazu liegen unter `shared/fixtures/` und werden von beiden Seiten getestet.

```jsonc
// POST /api/device/pair  (Anfrage, Antwort)
{ "code": "48201937", "previousBusinessId": null, "appVersion": "1.2.0", "deviceModel": "Redmi Pad Pro" }
{ "registerId": "<uuid>", "registerName": "Kassa 1", "businessId": "<uuid>", "businessName": "Beispiel-Imbiss", "token": "<43 Zeichen base64url>" }

// GET /api/device/sync/pull?since=0   (Authorization: Bearer <token>)
{
  "next": 57, "more": false,
  "business": { "name": "Beispiel-Imbiss", "addressLines": ["Musterstraße 1", "1010 Wien"], "vatId": "ATU12345678", "receiptFooter": "Danke und bis bald!" },
  "categories": [ { "id": "bowls", "name": "Bowls", "position": 0, "archived": false } ],
  "items": [ { "id": "huhn-bowl", "name": "Huhn Bowl", "priceCents": 990, "categoryId": "bowls", "taxPercent": 10, "depositCents": 0, "tags": ["spicy"], "info": null, "templateId": "bowl", "favorite": false, "inSale": true, "position": 0, "archived": false } ],
  "templates": [ { "id": "bowl", "name": "bowl", "archived": false, "groups": [ { "id": "bowl/0", "name": "Größe", "min": 1, "max": 1, "options": [ { "id": "bowl/0/0", "name": "Normal", "surchargeCents": 0, "isDefault": true, "taxPercent": null, "depositCents": null } ] } ] } ],
  "staff": [ { "id": "<uuid>", "name": "Chefin", "role": "chef", "pinSalt": "<hex>", "pinHash": "<hex>", "archived": false } ]
}
```

`business` fehlt, wenn sich die Betriebsdaten seit `since` nicht geändert haben. `tags` verwendet die Namen der App (`vegan`, `spicy`), `role` ist `chef` oder `staff`. `next` ist die höchste Änderungs-Nummer in der Antwort, oder `since`, wenn nichts kam.

## Review Focus

Diese Fälle folgen aus dem Entwurf und treffen einen Menschen am ehesten. Jeder hat seinen Test in der genannten Aufgabe.

1. Zwei Betriebe aus derselben Datei haben dieselben Artikel-Kennungen. Keiner sieht Preise oder Mitarbeiter des anderen, auch nicht über das Tablet (Task 2, 5, 8).
2. Ein Code wird zweimal oder nach 15 Minuten eingetippt, oder zwei Tablets tippen ihn gleichzeitig. Genau eines gewinnt, das andere liest "Der Code stimmt nicht oder ist abgelaufen." (Task 7, 8, 14).
3. Das Internet bricht nach dem Koppeln mitten im Laden der Speisekarte ab. Das Tablet behält seine alte Speisekarte vollständig, zeigt "Nochmal versuchen" und braucht keinen neuen Code (Task 13, 14).
4. Ein Betrieb hat beim Koppeln noch keinen Mitarbeiter, oder der letzte Chef soll stillgelegt werden. Das Tablet sagt, was zu tun ist, und der Server lässt den letzten Chef nicht verschwinden (Task 6, 14).
5. Die Speisekarte wird neu eingespielt, während ein Tablet gerade holt. Das Tablet überspringt keine Änderung und hat danach genau den Stand des Servers, stillgelegte Artikel eingeschlossen (Task 2, 5, 8, 13).

---

### Task 1: Server-Gerüst und Test-Datenbank

**Files:**
- Create: `package.json` (Wurzel, `workspaces: ["server","web"]`, `private: true`), `server/package.json`, `server/tsconfig.json`, `server/vitest.config.ts`, `server/src/main.ts`, `server/src/app.ts`, `server/src/config.ts`, `server/src/errors.ts`, `server/src/db/db.ts`, `server/src/db/migrate.ts`, `server/migrations/0000_roles.sql`, `server/tool/test-db.sh`, `server/test/support/global_setup.ts`, `server/test/support/db.ts`, `server/test/support/app.ts`, `server/README.md`
- Modify: `.gitignore` (dazu `node_modules/`, `dist/`, `server.properties`, `.env`)
- Test: `server/test/config.test.ts`, `server/test/health.test.ts`, `server/test/migrate.test.ts`

**Interfaces:**
- Produces:
  - `loadConfig(env: NodeJS.ProcessEnv): Config`. Felder: `databaseUrl`, `appDbPassword`, `port` (Vorgabe 3000), `publicUrl` (Herkunft ohne Schrägstrich am Ende), `setupToken?`, `releaseToken?`, `fileDir?`, `s3?: {endpoint, bucket, accessKeyId, secretAccessKey, region}`, `webDir?`, `passwordCost` (Vorgabe 131072). Wirft einen Fehler, der alle fehlenden Pflicht-Variablen in einem Satz nennt. Variablen: `DATABASE_URL`, `APP_DB_PASSWORD`, `PORT`, `PUBLIC_URL`, `SETUP_TOKEN`, `RELEASE_TOKEN`, `FILE_DIR`, `S3_ENDPOINT`, `S3_BUCKET`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, `S3_REGION`, `WEB_DIR`. Genau eines von `FILE_DIR` und den `S3_`-Variablen muss gesetzt sein.
  - `type Db = { pool: pg.Pool }` (Verbindungen der Rolle `kassa_app`), `openDb(config): Db`, `closeDb(db)`.
  - `migrate(ownerUrl: string, opts: { appPassword: string }): Promise<string[]>` wendet `server/migrations/*.sql` in Namensreihenfolge an, jede in einer Transaktion, vermerkt sie in `schema_migrations(name, applied_at)`, hält dabei `pg_advisory_lock(7417)` und gibt die neu angewendeten Namen zurück. `0000_roles.sql` legt die Rolle `kassa_app` an (`LOGIN`, kein `BYPASSRLS`, kein `SUPERUSER`). Das Passwort setzt `migrate` danach mit `ALTER ROLE` aus `opts.appPassword`.
  - `type AppDeps = { config: Config; db: Db; files: FileStore; now: () => Date }` (`FileStore` kommt in Task 9, bis dahin `unknown`), `buildApp(deps): Promise<FastifyInstance>` mit `trustProxy: true`, Grenze für Anfragen 1 MB.
  - `class ApiError extends Error { constructor(status: number, code: string, message: string, extra?: object) }` und ein Fehler-Handler, der die Form aus den Global Constraints erzeugt. Unbekannte Fehler: 500 `internal`, "Das hat nicht geklappt. Bitte nochmal versuchen.", Einzelheiten nur ins Protokoll.
  - `server/tool/test-db.sh start|stop|url`: Cluster in `/var/tmp/kassa-test-pg`, Port 54329, Superuser `kassa`, `--auth=trust`, Programme aus `/usr/lib/postgresql/16/bin`, als Benutzer `postgres` über `su`, wenn das Skript als root läuft. `start` ist ohne Wirkung, wenn der Cluster schon läuft.
  - `createTestDb(): Promise<{ db: Db; ownerUrl: string; drop(): Promise<void> }>` legt pro Testdatei eine Datenbank aus der Vorlage `kassa_template` an (die Vorlage migriert `global_setup.ts` einmal). `testApp(overrides?): Promise<{ app, db, now: { value: Date }, close() }>` baut die App mit fester Uhr `2026-11-18T10:00:00Z`, `publicUrl: "http://localhost"`, `passwordCost: 1024`, `fileDir` in einem Temp-Ordner.

- [ ] **Step 1: Tests schreiben**

```ts
// config.test.ts
test('nennt alle fehlenden Variablen auf einmal', () => {
  expect(() => loadConfig({})).toThrow(/DATABASE_URL.*APP_DB_PASSWORD.*PUBLIC_URL/s);
});
test('FILE_DIR und S3 zusammen ist ein Fehler', …);
test('PUBLIC_URL verliert den Schrägstrich am Ende', …);
// health.test.ts
test('GET /healthz antwortet 200 {ok:true}', …);
test('unbekannte Adresse unter /api antwortet 404 mit code not_found', …);
test('ein geworfener Fehler wird 500 internal ohne Einzelheiten', …);
// migrate.test.ts
test('zweiter Lauf wendet nichts mehr an', …);          // Rückgabe []
test('kassa_app ist weder Superuser noch BYPASSRLS', …); // pg_roles
```

- [ ] **Step 2: Tests laufen lassen, sie schlagen fehl.** Run: `tool/test-db.sh start && npx vitest run`. Expected: FAIL, Module fehlen.
- [ ] **Step 3: Gerüst bauen.** `main.ts`: `loadConfig`, `migrate(config.databaseUrl, …)`, `openDb` (Adresse wie `DATABASE_URL`, aber Benutzer `kassa_app` und `appDbPassword`), `buildApp`, `listen({ host: "0.0.0.0", port })`. Skripte in `server/package.json`: `dev` (`tsx watch src/main.ts`), `build` (`tsc -p .`), `start` (`node dist/main.js`), `test` (`vitest run`), `typecheck` (`tsc --noEmit`). `README.md`: lokal starten in fünf Zeilen.
- [ ] **Step 4: Tests grün.** Run: `npx vitest run && npm run typecheck`. Expected: PASS.
- [ ] **Step 5: Commit** `Server: Gerüst, Einstellungen, Migrationen, Test-Datenbank`

### Task 2: Schema und Trennung der Betriebe

**Files:**
- Create: `server/migrations/0001_init.sql`, `server/src/db/tenant.ts`
- Test: `server/test/tenant.test.ts`, `server/test/schema.test.ts`

**Interfaces:**
- Consumes: `Db`, `createTestDb` (Task 1).
- Produces:
  - `withSystem<T>(db, fn: (c: pg.PoolClient) => Promise<T>): Promise<T>`: eine Transaktion ohne Betrieb.
  - `withBusiness<T>(db, businessId: string, fn): Promise<T>`: Transaktion mit `select set_config('app.business_id', $1, true)`.
  - `withBusinessWrite<T>(db, businessId, fn): Promise<T>`: wie `withBusiness`, nimmt davor `pg_advisory_xact_lock(hashtextextended($1, 0))`.
  - `nextChangeSeq(c): Promise<number>` aus der Sequenz `change_seq`. Nur innerhalb von `withBusinessWrite` aufrufen.
  - Tabellen ohne Sperre (System): `businesses(id uuid pk, name text, address_lines text[] default '{}', vat_id text, receipt_footer text, change_seq bigint not null, created_at timestamptz)`, `users(id uuid pk, email text, password_hash text, role text check in ('provider','chef'), business_id uuid null references businesses, disabled_at timestamptz, created_at timestamptz)` mit eindeutigem Index auf `lower(email)` und der Bedingung "chef hat einen Betrieb, provider keinen", `sessions(id_hash bytea pk, user_id uuid references users on delete cascade, created_at, last_seen_at, expires_at)`, `used_secrets(secret_hash bytea pk, used_at)`, `login_failures(email_hash bytea, at timestamptz)`, `audit_log(id bigserial pk, at, user_id uuid null, business_id uuid null, action text, detail jsonb)`, `releases(id uuid pk, version text, build int, file_key text, sha256 text, size bigint, link_secret text unique, uploaded_at, withdrawn_at, unique(version, build))`.
  - Tabellen mit Sperre (`ENABLE` und `FORCE ROW LEVEL SECURITY`, Regel `business_id = nullif(current_setting('app.business_id', true), '')::uuid` für lesen und schreiben): `registers(id uuid pk, business_id, name, token_hash bytea unique, paired_at, last_seen_at, app_version text, device_model text, blocked_at)`, `pairing_codes(code_hash bytea pk, business_id, register_name text, expires_at, used_at, created_by uuid)`, `categories(business_id, id text, name, position int, archived bool default false, change_seq bigint, primary key (business_id, id))`, `items(business_id, id text, name, price_cents int, category_id text, tax_percent int check in (20,10,13,0,19), deposit_cents int default 0, tags text default '', info text, template_id text, favorite bool default false, in_sale bool default true, photo_file text, position int, archived bool default false, change_seq bigint, price_changed_at, in_sale_changed_at, favorite_changed_at, deposit_changed_at, tags_changed_at timestamptz default now(), primary key (business_id, id), foreign key (business_id, category_id) references categories)`, `modifier_templates(business_id, id text, name, groups jsonb, archived bool default false, change_seq bigint, primary key (business_id, id))`, `staff(business_id, id uuid, name, role text check in ('chef','staff'), pin_salt text, pin_hash text, archived bool default false, change_seq bigint, primary key (business_id, id))`.
  - Funktionen `SECURITY DEFINER` mit festem `search_path`, weil sie vor der Kenntnis des Betriebs gebraucht werden: `find_register_by_token(hash bytea) returns table(id uuid, business_id uuid, name text, blocked_at timestamptz)` und `claim_pairing_code(hash bytea, at timestamptz) returns table(business_id uuid, register_name text)` (setzt `used_at` in einer einzigen `UPDATE … WHERE used_at IS NULL AND expires_at > at RETURNING`).
  - Rechte: `kassa_app` bekommt `SELECT, INSERT, UPDATE, DELETE` auf alle Tabellen, `USAGE` auf die Sequenzen und `EXECUTE` auf die zwei Funktionen. Besitzer bleibt die Rolle aus `DATABASE_URL`.

- [ ] **Step 1: Tests schreiben**

```ts
// tenant.test.ts   (A und B sind zwei Betriebe, beide mit Kategorie und Artikel "cola")
test('ohne Betrieb liefert jede gesperrte Tabelle 0 Zeilen', …);     // alle sechs Tabellen
test('withBusiness(A) sieht nur Zeilen von A', …);
test('in withBusiness(A) scheitert ein INSERT mit business_id von B', …);
test('in withBusiness(A) ändert ein UPDATE ohne WHERE nur Zeilen von A', …);
test('kassa_app kann die Sperre nicht abschalten', …);               // ALTER TABLE … DISABLE → Fehler
test('zwei withBusinessWrite auf denselben Betrieb laufen nacheinander', async () => {
  // tx1 nimmt eine Nummer und wartet; tx2 startet; ein Leser sieht währenddessen keine Zeile von tx2;
  // nach commit von tx1 läuft tx2; die Nummer von tx2 ist größer.
});
test('withBusinessWrite auf zwei verschiedene Betriebe blockiert sich nicht', …);
// schema.test.ts
test('claim_pairing_code gibt einen Code genau einmal her', …);      // zwei gleichzeitige Aufrufe: einer bekommt 1 Zeile, der andere 0
test('claim_pairing_code gibt abgelaufene Codes nicht her', …);
test('ein Chef ohne Betrieb und ein Anbieter mit Betrieb sind verboten', …);
test('E-Mail ist ohne Groß-/Kleinschreibung eindeutig', …);
```

- [ ] **Step 2: Fehlschlag sehen.** Run: `npx vitest run test/tenant.test.ts test/schema.test.ts`. Expected: FAIL.
- [ ] **Step 3: `0001_init.sql` und `tenant.ts` schreiben.** `pg` liefert `bigint` als Text: `nextChangeSeq` wandelt in `number` um.
- [ ] **Step 4: Tests grün.** Run: `npx vitest run`. Expected: PASS.
- [ ] **Step 5: Commit** `Server: Tabellen, Sperre pro Betrieb, Änderungs-Nummern`

### Task 3: Anmeldung im Browser

**Files:**
- Create: `server/src/auth/secrets.ts`, `server/src/auth/passwords.ts`, `server/src/auth/sessions.ts`, `server/src/auth/login_throttle.ts`, `server/src/auth/guards.ts`, `server/src/auth/routes.ts`, `server/src/audit.ts`
- Modify: `server/src/app.ts`
- Test: `server/test/auth.test.ts`, `server/test/passwords.test.ts`, `server/test/login_throttle.test.ts`, `server/test/support/users.ts`

**Interfaces:**
- Consumes: `withSystem`, `ApiError`, `Config`.
- Produces:
  - `randomToken(bytes = 32): string` (base64url), `sha256(s: string): Buffer`, `safeEqual(a: string, b: string): boolean`.
  - `hashPassword(pw: string, cost: number): Promise<string>` im Format `scrypt$<N>$8$1$<salt base64>$<hash base64>`, `verifyPassword(pw, stored): Promise<boolean>`.
  - `createSession(c, userId, now): Promise<string>`, `findSessionUser(c, cookieValue, now): Promise<SessionUser | null>` (verlängert `expires_at` auf jetzt plus 30 Tage, schreibt `last_seen_at` höchstens einmal pro Stunde, liefert `null` bei abgelaufener Sitzung oder gesperrtem Benutzer), `deleteSession(c, cookieValue)`. `type SessionUser = { id: string; email: string; role: 'provider' | 'chef'; businessId: string | null }`.
  - `loginWait(c, email, now): Promise<number>` (Sekunden, 0 heißt erlaubt), `recordLoginFailure(c, email, now)`, `clearLoginFailures(c, email)`. Regel: gezählt werden Fehlversuche der letzten 24 Stunden. Ab dem 5. gilt ab dem letzten Fehlversuch eine Wartezeit von 1, 2, 4, 8, dann immer 15 Minuten.
  - Guards, die `ApiError` werfen: `requireUser(req): SessionUser` (401 `unauthorized`), `requireProvider(req)` (404 `not_found` für andere), `requireBusinessAccess(req, businessId): Promise<SessionUser>` (Anbieter: Betrieb muss existieren, Chef: nur der eigene, sonst 404 `not_found`).
  - `audit(c, entry: { userId?: string; businessId?: string; action: string; detail?: object }, now)`.
  - Adressen: `GET /api/auth/setup?token=` → `{valid}`. `POST /api/auth/setup {token,email,password}` → 201 `{user}` plus Cookie. `POST /api/auth/login {email,password}` → 200 `{user}` plus Cookie. `POST /api/auth/logout` → 204. `GET /api/auth/me` → `{user}` oder 401.
  - Cookie: Name `__Host-kassa_session`, wenn `publicUrl` mit `https://` beginnt, sonst `kassa_session`. `HttpOnly`, `SameSite=Lax`, `Path=/`, `Secure` bei https, `Max-Age` 30 Tage.
  - Schutz für alle Anfragen außer GET unter `/api/auth` und `/api/admin`: Kopfzeile `X-Kassa-Request: 1` fehlt → 403 `csrf`. Kopfzeile `Origin` vorhanden und ungleich `publicUrl` → 403 `csrf`.
  - Fehler: Einmal-Schlüssel falsch, schon verbraucht oder keiner gesetzt → 403 `setup_invalid`. Passwort unter 10 Zeichen → 422 `password_too_short`. E-Mail ohne `@` oder über 254 Zeichen → 422 `email_invalid`. E-Mail vergeben → 409 `email_taken`. Anmeldung falsch → 401 `login_failed` "E-Mail oder Passwort stimmt nicht." (derselbe Text für unbekannte E-Mail, und auch dann wird ein Passwort gerechnet). Wartezeit → 429 `too_many_attempts` mit `retryAfterSeconds`.
  - Testhilfe `createProvider(app, db)` und `createChef(db, businessId)` liefern `{ user, cookie }`, `authed(cookie)` liefert die Kopfzeilen für Anfragen.

- [ ] **Step 1: Tests schreiben**

```ts
// auth.test.ts
test('Einrichten mit richtigem Schlüssel legt den Anbieter an und meldet an', …);
test('derselbe Schlüssel gilt kein zweites Mal', …);                       // 403 setup_invalid
test('ohne SETUP_TOKEN ist Einrichten immer 403', …);
test('Passwort mit 9 Zeichen: 422 password_too_short', …);
test('Anmelden setzt ein HttpOnly-Cookie mit SameSite=Lax', …);
test('falsches Passwort und unbekannte E-Mail geben dieselbe Antwort', …);
test('E-Mail in Großbuchstaben meldet denselben Benutzer an', …);
test('me ohne Cookie: 401, mit Cookie: der Benutzer ohne password_hash', …);
test('Abmelden macht das Cookie wertlos', …);
test('Sitzung läuft nach 30 Tagen ohne Benutzung ab, Benutzung am Tag 29 verlängert', …);
test('POST ohne X-Kassa-Request: 403 csrf', …);
test('POST mit fremdem Origin: 403 csrf', …);
test('Anmeldung und Einrichten stehen im Verlauf, das Passwort nicht', …);
// login_throttle.test.ts
test('5 Fehlversuche: 60 s warten, 6: 120 s, 9 und mehr: 900 s', …);
test('nach der Wartezeit geht ein Versuch, ein Erfolg löscht die Zählung', …);
test('während der Wartezeit zählt auch das richtige Passwort nicht', …);
// passwords.test.ts
test('gleiches Passwort ergibt zwei verschiedene Prüfwerte, beide gelten', …);
test('Prüfwert trägt seine Kosten, ein alter mit N=1024 gilt weiter', …);
```

- [ ] **Step 2: Fehlschlag sehen.** Run: `npx vitest run test/auth.test.ts`. Expected: FAIL.
- [ ] **Step 3: Bauen.** `scrypt` aus `node:crypto` mit `maxmem` passend zu `N`. Das Cookie über `@fastify/cookie`.
- [ ] **Step 4: Tests grün.** Run: `npx vitest run && npm run typecheck`. Expected: PASS.
- [ ] **Step 5: Commit** `Server: Einrichten, Anmelden, Sitzungen, Schutz vor Fehlversuchen`

### Task 4: Speisekarten-Datei am Server lesen

**Files:**
- Create: `server/src/menu/parse_menu.ts`, `shared/fixtures/menu/inputs/*.json`, `shared/fixtures/menu/expected/*.json`, `app/tool/menu_fixture.dart`, `app/lib/sync/wire.dart` (nur `catalogToWire`), `app/test/sync/menu_fixture_test.dart`
- Test: `server/test/parse_menu.test.ts`

**Interfaces:**
- Consumes: `app/lib/domain/menu_import.dart` (die Regeln und Meldungen dort sind die Vorgabe und bleiben unverändert).
- Produces:
  - `parseMenuFile(text: string): ParsedMenu`, wirft `MenuImportError` mit `problems: string[]`. `ParsedMenu = { business: {name, addressLines, vatId, receiptFooter}, categories, items, templates, staffSeeds }` in genau der Form von "Nachrichtenformen" (ohne `archived`, `favorite`, `inSale`), `staffSeeds: {name, pin, role}[]`.
  - Dart: `Map<String, Object?> catalogToWire(Catalog c)` in derselben Form.
  - `app/tool/menu_fixture.dart`: liest jede Datei aus `shared/fixtures/menu/inputs/`, ruft `parseMenuFile` der App und schreibt nach `expected/<name>.json` entweder `{"problems":[…]}` oder `{"menu":{…}}`, Schlüssel sortiert, zwei Leerzeichen Einzug. Aufruf: `dart run tool/menu_fixture.dart`.
  - Mindestens 30 Eingaben: der Beispiel-Imbiss aus Anhang A des Hauptentwurfs, je eine Datei pro Meldung in `menu_import.dart` (jede Meldung dort kommt in mindestens einer `expected`-Datei vor), dazu: Datei mit BOM am Anfang, kein JSON, JSON-Liste statt Objekt, `kennzeichen` als Liste, `max: null`, mehrere Probleme in einer Datei (Reihenfolge der Meldungen zählt), Mitarbeiter in der Datei.

- [ ] **Step 1: Eingaben schreiben, `expected` mit dem Dart-Werkzeug erzeugen.** Run aus `app/`: `dart run tool/menu_fixture.dart`. Expected: eine `expected`-Datei pro Eingabe.
- [ ] **Step 2: Tests schreiben**

```ts
// parse_menu.test.ts
for (const name of inputs) test(`Beispiel ${name}`, () => {
  // expected.problems: toThrow(MenuImportError) und problems toEqual
  // expected.menu: parseMenuFile(text) toEqual
});
test('jede Meldung aus menu_import.dart kommt in einem Beispiel vor', …); // liest die Dart-Datei, sucht die festen Textteile
```
```dart
// menu_fixture_test.dart
test('expected-Dateien sind aktuell', …); // erzeugt im Speicher neu und vergleicht mit den Dateien
```

- [ ] **Step 3: Fehlschlag sehen.** Run: `npx vitest run test/parse_menu.test.ts`. Expected: FAIL.
- [ ] **Step 4: `parse_menu.ts` schreiben**, Zeile für Zeile nach `menu_import.dart`: gleiche Reihenfolge der Prüfungen, gleiche Texte, Kennungen der Gruppen `"<vorlage>/<g>"` und der Optionen `"<vorlage>/<g>/<o>"`, Name der Vorlage ist ihre Kennung. Ganze Zahl heißt `Number.isInteger`.
- [ ] **Step 5: Tests grün.** Run: `npx vitest run` und aus `app/`: `flutter test test/sync/menu_fixture_test.dart`. Expected: PASS.
- [ ] **Step 6: Commit** `Speisekarten-Datei: gleiche Regeln am Server, gemeinsame Beispiele`

### Task 5: Betriebe anlegen und neu einspielen

**Files:**
- Create: `server/src/menu/import_menu.ts`, `server/src/admin/businesses.ts`
- Modify: `server/src/app.ts`
- Test: `server/test/businesses.test.ts`, `server/test/import_menu.test.ts`, `server/test/support/businesses.ts`

**Interfaces:**
- Consumes: `parseMenuFile`, `withBusinessWrite`, `nextChangeSeq`, Guards, `audit`.
- Produces:
  - `importMenu(c, businessId, menu: ParsedMenu, now): Promise<ImportSummary>` mit `ImportSummary = { categories: Counts; items: Counts; templates: Counts }` und `Counts = { added: number; changed: number; archived: number }`. Regeln: Die Datei gewinnt bei Name, Preis, Kategorie, Steuersatz, Pfand, Kennzeichen, Zusatzangabe, Vorlage, Reihenfolge und bei den Betriebsdaten. `favorite`, `in_sale`, `photo_file` bleiben. Was in der Datei fehlt, wird `archived = true`. Was wieder auftaucht, wird `archived = false`. Nur Zeilen, die sich wirklich ändern, bekommen eine neue Änderungs-Nummer, alle Zeilen eines Laufs eigene aufsteigende Nummern. Ändert ein Lauf den Preis, das Pfand oder die Kennzeichen eines Artikels, setzt er auch den zugehörigen `…_changed_at` auf `now`. `staffSeeds` werden nie angelegt.
  - `GET /api/admin/businesses` (Anbieter) → `{businesses:[{id,name,counts:{items,staff,registers}}]}` nach Name sortiert.
  - `POST /api/admin/businesses {menuFile: string}` (Anbieter) → 201 `{business:{id,name}, summary}`. Legt Betrieb und Speisekarte in einer Transaktion an.
  - `GET /api/admin/businesses/:b` → `{business:{id,name,addressLines,vatId,receiptFooter,counts:{categories,items,templates,staff,registers}}, categories:[{id,name,itemCount,archived}]}`.
  - `POST /api/admin/businesses/:b/menu {menuFile}` (Anbieter) → 200 `{summary, ignoredStaff: number}`.
  - Fehler: `menuFile` über 1 MB → 413 `file_too_large`. Datei ungültig → 422 `menu_invalid` mit `problems`.
  - Testhilfe `createBusiness(app, cookie, fixtureName = 'beispiel-imbiss'): Promise<{id, name}>`.

- [ ] **Step 1: Tests schreiben**

```ts
// import_menu.test.ts
test('erstes Einspielen: alles added, Nummern steigen in Datei-Reihenfolge', …);
test('gleiche Datei nochmal: summary überall 0, keine Änderungs-Nummer bewegt sich', …);
test('Preis in der Datei geändert: genau dieser Artikel changed, neue Nummer, price_changed_at = now', …);
test('Artikel fehlt in der neuen Datei: archived, taucht er wieder auf: nicht mehr archived', …);
test('favorite, in_sale und photo_file überleben das Einspielen', …);
test('Betriebsdaten aus der Datei ersetzen die alten, auch wenn sie leer werden', …);
test('Mitarbeiter in der Datei werden nicht angelegt, ignoredStaff zählt sie', …);
// businesses.test.ts
test('Anlegen aus der Beispieldatei: 201, 3 Artikel, 2 Kategorien, 1 Vorlage', …);
test('ungültige Datei: 422 menu_invalid mit denselben problems wie parseMenuFile', …);
test('Datei mit 1 MB und einem Byte: 413 file_too_large', …);
test('zwei Betriebe aus derselben Datei: jeder hat seine eigene "cola"', …);
test('Chef von A: Liste 404, Betrieb B 404, Betrieb A 200, neu einspielen 404', …);
test('ohne Anmeldung: 401', …);
test('Anlegen und Einspielen stehen im Verlauf', …);
```

- [ ] **Step 2: Fehlschlag sehen.** Run: `npx vitest run test/import_menu.test.ts test/businesses.test.ts`. Expected: FAIL.
- [ ] **Step 3: Bauen.** Vergleich "ändert sich wirklich" über die Felder der Datei, nicht über die ganze Zeile. Vorlagen werden als ganzes `groups`-Stück verglichen.
- [ ] **Step 4: Tests grün.** Run: `npx vitest run && npm run typecheck`. Expected: PASS.
- [ ] **Step 5: Commit** `Server: Betrieb aus der Speisekarten-Datei anlegen und neu einspielen`

### Task 6: Mitarbeiter und PINs

**Files:**
- Create: `server/src/admin/staff.ts`, `shared/fixtures/pin_hash.json`, `app/test/sync/pin_hash_fixture_test.dart`
- Modify: `server/src/app.ts`
- Test: `server/test/staff.test.ts`

**Interfaces:**
- Consumes: `withBusiness`, `withBusinessWrite`, `nextChangeSeq`, Guards, `audit`. In der App: `StaffRepository.findByPin`, Tabelle `StaffRows`.
- Produces:
  - `pinHash(salt: string, pin: string): string` = SHA-256 über `salt + pin` als UTF-8, klein geschriebenes Hex. So rechnet `app/lib/data/staff_repository.dart` heute. Salz am Server: 16 zufällige Bytes als Hex.
  - `GET /api/admin/businesses/:b/staff` → `{staff:[{id,name,role,archived}]}`, aktive zuerst, dann nach Name.
  - `POST /api/admin/businesses/:b/staff {name, role, pin}` → 201 `{staff}`.
  - `PATCH /api/admin/businesses/:b/staff/:id {name?, role?, pin?, archived?}` → 200 `{staff}`.
  - Regeln und Fehler: Name nach dem Kürzen 1 bis 40 Zeichen → sonst 422 `name_invalid`. Rolle `chef` oder `staff` → sonst 422 `role_invalid`. PIN `^[0-9]{4}$` → sonst 422 `pin_invalid` "Die PIN muss aus genau vier Ziffern bestehen.". PIN bei einem anderen aktiven Mitarbeiter desselben Betriebs vergeben → 409 `pin_taken` "Diese PIN ist schon vergeben.". Der erste Mitarbeiter eines Betriebs muss Chef sein → 422 `first_must_be_chef`. Den letzten aktiven Chef stilllegen oder zum Mitarbeiter machen → 409 `last_chef` "Mindestens ein Chef muss bleiben.". Wieder aktivieren prüft die PIN erneut. Jede Änderung gibt eine neue Änderungs-Nummer und einen Eintrag im Verlauf (ohne PIN).
  - `shared/fixtures/pin_hash.json`: `{"salt":"00112233445566778899aabbccddeeff","pin":"1234","hash":"<berechnet>"}`.

- [ ] **Step 1: Tests schreiben**

```ts
// staff.test.ts
test('pinHash trifft den Wert aus shared/fixtures/pin_hash.json', …);
test('erster Mitarbeiter als staff: 422 first_must_be_chef', …);
test('anlegen: 201, Antwort und Liste enthalten weder pinSalt noch pinHash', …);
test('PIN 12a4, 123, 12345: 422 pin_invalid', …);
test('gleiche PIN im selben Betrieb: 409 pin_taken, in einem anderen Betrieb erlaubt', …);
test('PIN eines stillgelegten Mitarbeiters ist wieder frei', …);
test('wieder aktivieren mit inzwischen vergebener PIN: 409 pin_taken', …);
test('letzten Chef stilllegen oder herabstufen: 409 last_chef, mit zweitem Chef erlaubt', …);
test('jede Änderung erhöht change_seq des Mitarbeiters', …);
test('Chef von B kann Mitarbeiter von A weder sehen noch ändern: 404', …);
test('Verlauf nennt staff.create und staff.update ohne PIN', …);
```
```dart
// pin_hash_fixture_test.dart
test('PIN vom Server meldet am Tablet an', () async {
  // StaffRow mit salt und hash aus der Datei einfügen, findByPin('1234') liefert die Person, findByPin('1235') null
});
```

- [ ] **Step 2: Fehlschlag sehen.** Run: `npx vitest run test/staff.test.ts`. Expected: FAIL.
- [ ] **Step 3: Bauen.** Eindeutigkeit der PIN: für jeden aktiven Mitarbeiter `pinHash(dessenSalz, neuePin)` mit dessen `pin_hash` vergleichen.
- [ ] **Step 4: Tests grün.** Run: `npx vitest run` und aus `app/`: `flutter test test/sync/pin_hash_fixture_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `Server: Mitarbeiter und PINs, gleicher Prüfwert wie am Tablet`

### Task 7: Kassen: Kopplungscode, Liste, Sperren

**Files:**
- Create: `server/src/admin/registers.ts`
- Modify: `server/src/app.ts`
- Test: `server/test/registers.test.ts`

**Interfaces:**
- Consumes: `withBusiness`, Guards, `sha256`, `audit`.
- Produces:
  - `POST /api/admin/businesses/:b/pairing-codes {name}` → 201 `{code, expiresAt}`. `code` sind 8 Ziffern aus `crypto.randomInt(0, 100_000_000)`, links mit Nullen aufgefüllt. In der Datenbank steht nur `sha256(code)`. Name nach dem Kürzen 1 bis 30 Zeichen → sonst 422 `name_invalid`. Ältere Codes bleiben gültig.
  - `GET /api/admin/businesses/:b/registers` → `{registers:[{id,name,pairedAt,lastSeenAt,appVersion,deviceModel,blocked}]}`, neueste zuerst.
  - `POST /api/admin/businesses/:b/registers/:id/block` und `…/unblock` → 200 `{register}`. Zweimal sperren ist kein Fehler.
  - Verlauf: `pairing_code.create`, `register.block`, `register.unblock`. Der Code selbst steht nie im Verlauf.

- [ ] **Step 1: Tests schreiben**

```ts
test('Code hat genau 8 Ziffern, expiresAt ist jetzt plus 15 Minuten', …);
test('in der Datenbank steht nur der Prüfwert, nicht der Code', …);
test('100 Codes: alle 8 Zeichen lang, auch die mit führender Null', …); // randomInt gestubbt auf 42 → "00000042"
test('Liste zeigt keine Geräte-Schlüssel', …);
test('sperren setzt blocked, aufheben nimmt es weg, beides im Verlauf', …);
test('Chef von B: Code für A 404, Liste von A 404, Sperren 404', …);
```

- [ ] **Step 2: Fehlschlag sehen.** Run: `npx vitest run test/registers.test.ts`. Expected: FAIL.
- [ ] **Step 3: Bauen.**
- [ ] **Step 4: Tests grün.** Run: `npx vitest run && npm run typecheck`. Expected: PASS.
- [ ] **Step 5: Commit** `Server: Kopplungscode erzeugen, Kassen auflisten und sperren`

### Task 8: Tablet-Schnittstelle: koppeln und holen

**Files:**
- Create: `server/src/device/guard.ts`, `server/src/device/pair.ts`, `server/src/device/pull.ts`, `server/src/rate_limit.ts`, `shared/fixtures/sync/pair_request.json`, `shared/fixtures/sync/pair_response.json`, `shared/fixtures/sync/pull_full.json`, `shared/fixtures/sync/pull_delta.json`, `shared/fixtures/sync/errors.json`
- Modify: `server/src/app.ts`
- Test: `server/test/pair.test.ts`, `server/test/pull.test.ts`, `server/test/sync_fixtures.test.ts`, `server/test/support/device.ts`

**Interfaces:**
- Consumes: `claim_pairing_code`, `find_register_by_token`, `withBusiness`, `randomToken`, `sha256`, `importMenu`, Testhilfen aus Task 3, 5, 6, 7.
- Produces:
  - `class SlidingWindow { constructor(limit: number, windowMs: number); hit(key: string, now: Date): boolean }` (im Speicher, `false` heißt Grenze erreicht).
  - `POST /api/device/pair` nach "Nachrichtenformen". Ablauf in einer Transaktion: Code einlösen, bei gesetztem und abweichendem `previousBusinessId` alles zurückrollen (der Code bleibt gültig) und 409 `other_business`, sonst Kassa mit `sha256(token)` anlegen, `paired_at` und `last_seen_at` = jetzt. Unbekannt, abgelaufen oder verbraucht → 404 `invalid_code` "Der Code stimmt nicht oder ist abgelaufen." Jeder Fehlversuch zählt pro `req.ip`, ab dem 11. in 15 Minuten → 429 `too_many_attempts`. `code` muss `^[0-9]{8}$` sein, sonst 404 `invalid_code` (zählt ebenfalls). Eintrag im Verlauf `register.pair`.
  - `requireRegister(req): Promise<{ id: string; businessId: string; name: string }>`: liest `Authorization: Bearer <token>`. Fehlt oder unbekannt → 401 `unauthorized`. Gesperrt → 403 `register_blocked`. Schreibt `last_seen_at` höchstens einmal pro Minute und `app_version` aus der Kopfzeile `X-Kassa-App-Version`.
  - `GET /api/device/sync/pull?since=<n>&limit=<n>` (Vorgabe 500, höchstens 1000) → `PullResponse`. Enthält alle Zeilen aus `categories`, `items`, `modifier_templates`, `staff` und die Betriebsdaten mit `change_seq > since`, nach Nummer aufsteigend, höchstens `limit` Stück. `more` ist `true`, wenn danach noch Zeilen offen sind. Stillgelegte Zeilen kommen mit. `since` fehlt oder ist keine ganze Zahl ab 0 → 422 `since_invalid`.
  - Testhilfe `pairDevice(app, cookie, businessId): Promise<{ token, registerId }>`.
  - Beispieldateien: Der Test baut einen Betrieb aus `beispiel-imbiss` mit einer Chefin (Salz und PIN aus `pin_hash.json`), ersetzt in der echten Antwort alle UUIDs durch `"<uuid>"` und den Schlüssel durch `"<token>"` und vergleicht mit der Datei. `pull_delta.json`: Antwort nach einer Preisänderung und einem stillgelegten Artikel. `errors.json`: je ein Beispiel für `invalid_code`, `too_many_attempts`, `other_business`, `unauthorized`, `register_blocked`.

- [ ] **Step 1: Tests schreiben**

```ts
// pair.test.ts
test('richtiger Code: Antwort wie pair_response.json, Kassa steht in der Liste', …);
test('derselbe Code ein zweites Mal: 404 invalid_code', …);
test('zwei Anfragen gleichzeitig mit demselben Code: genau eine 200, eine 404', …);
test('Code nach 15 Minuten und einer Sekunde: 404 invalid_code', …);
test('previousBusinessId eines anderen Betriebs: 409 other_business, der Code gilt danach noch', …);
test('previousBusinessId desselben Betriebs: 200, zweiter Eintrag Kassa', …);
test('11. Fehlversuch derselben Adresse in 15 Minuten: 429, nach 15 Minuten wieder 404', …);
test('Code mit Buchstaben oder 7 Ziffern: 404 invalid_code', …);
test('der Schlüssel steht nicht in der Datenbank und nicht im Verlauf', …);
// pull.test.ts
test('since=0 liefert die ganze Speisekarte wie pull_full.json', …);
test('since=next liefert nichts: leere Listen, next unverändert, kein business', …);
test('nach Preisänderung und Stilllegung wie pull_delta.json', …);
test('limit=2: seitenweise bis more=false ergibt jede Zeile genau einmal', …);
test('Kassa von A sieht nichts von B, obwohl beide "cola" haben', …);
test('staff trägt pinSalt und pinHash', …);
test('ohne Schlüssel 401, mit falschem 401, gesperrt 403, Sperre aufgehoben 200', …);
test('neu einspielen während eines seitenweisen Holens: am Ende hat das Tablet den Stand des Servers', async () => {
  // Seite 1 holen, importMenu mit geänderter Datei, weiterholen bis more=false,
  // die gesammelten Zeilen (spätere überschreiben frühere) entsprechen der Datenbank
});
test('last_seen_at und app_version werden gesetzt', …);
```

- [ ] **Step 2: Fehlschlag sehen.** Run: `npx vitest run test/pair.test.ts test/pull.test.ts`. Expected: FAIL.
- [ ] **Step 3: Bauen.** `pull` liest alles in einer `withBusiness`-Transaktion mit `REPEATABLE READ`, damit die fünf Abfragen denselben Stand sehen.
- [ ] **Step 4: Tests grün.** Run: `npx vitest run && npm run typecheck`. Expected: PASS.
- [ ] **Step 5: Commit** `Server: Tablet koppeln und Speisekarte, Mitarbeiter, Betriebsdaten holen`

### Task 9: Installationsdateien

**Files:**
- Create: `server/src/storage/file_store.ts`, `server/src/storage/local_file_store.ts`, `server/src/storage/s3_file_store.ts`, `server/src/admin/releases.ts`
- Modify: `server/src/app.ts`, `server/src/main.ts`
- Test: `server/test/releases.test.ts`, `server/test/local_file_store.test.ts`

**Interfaces:**
- Consumes: `Config`, `safeEqual`, `randomToken`, Guards.
- Produces:
  - `interface FileStore { put(key: string, body: Readable, contentType: string): Promise<void>; get(key: string): Promise<{ body: Readable; size: number } | null>; delete(key: string): Promise<void> }`. `LocalFileStore(dir)` lehnt Schlüssel mit `..` oder führendem `/` ab. `S3FileStore(cfg)` mit `forcePathStyle: true`. `createFileStore(config): FileStore`.
  - `PUT /api/releases/:version?build=<n>`, Kopfzeile `Authorization: Bearer <RELEASE_TOKEN>`, Inhalt `application/vnd.android.package-archive` als Strom, höchstens 200 MB. → 201 `{id, version, build, sha256, size, downloadPath}` mit `downloadPath = "/laden/<secret>/kassa-<version>.apk"`. SHA-256 und Größe werden beim Durchreichen gerechnet. Kein `RELEASE_TOKEN` gesetzt → 404 `not_found`. Schlüssel falsch → 401 `unauthorized`. Version nicht `^\d+\.\d+\.\d+$` oder `build` keine ganze Zahl ab 1 → 422 `version_invalid`. Version und Build schon vorhanden → 409 `release_exists`. Inhalt beginnt nicht mit `PK\x03\x04` → 422 `not_an_apk`, und in der Ablage bleibt nichts liegen.
  - `GET /laden/:secret/:filename` → die Datei mit `Content-Type: application/vnd.android.package-archive`, `Content-Disposition: attachment; filename="kassa-<version>.apk"`, `Content-Length`, `Cache-Control: private, no-store`, `X-Robots-Tag: noindex`. Unbekannt oder zurückgezogen → 404 als schlichter Text "Diese Datei gibt es nicht."
  - `GET /api/admin/releases` (Anbieter) → `{releases:[{id,version,build,sha256,size,uploadedAt,withdrawn,downloadPath}]}`, neueste zuerst. `DELETE /api/admin/releases/:id` (Anbieter) → 204, setzt `withdrawn_at` und löscht die Datei.

- [ ] **Step 1: Tests schreiben**

```ts
// releases.test.ts
test('hochladen und über den Link wieder laden: gleiche Bytes, sha256 und size stimmen', …);
test('Link mit einem falschen Zeichen im geheimen Teil: 404', …);
test('ohne Schlüssel 401, ohne RELEASE_TOKEN in den Einstellungen 404', …);
test('kein APK: 422 not_an_apk, die Ablage ist danach leer', …);
test('gleiche Version und Build nochmal: 409 release_exists', …);
test('zurückgezogen: Link 404, Datei aus der Ablage weg, in der Liste withdrawn', …);
test('Liste nur für den Anbieter: Chef 404, ohne Anmeldung 401', …);
test('Antwort des Links trägt no-store und noindex', …);
// local_file_store.test.ts
test('Schlüssel mit .. wird abgelehnt', …);
test('get für unbekannten Schlüssel ist null', …);
```

- [ ] **Step 2: Fehlschlag sehen.** Run: `npx vitest run test/releases.test.ts`. Expected: FAIL.
- [ ] **Step 3: Bauen.** Für diese eine Adresse den Inhalt nicht einlesen, sondern als Strom durchreichen und die Grenze von 200 MB setzen.
- [ ] **Step 4: Tests grün.** Run: `npx vitest run && npm run typecheck`. Expected: PASS.
- [ ] **Step 5: Commit** `Server: Installationsdatei hochladen, über geheimen Link ausliefern, zurückziehen`

### Task 10: Web-Gerüst, Bausteine, Einrichten und Anmelden

**Files:**
- Create: `web/package.json`, `web/vite.config.ts`, `web/tsconfig.json`, `web/index.html`, `web/public/fonts/` (Figtree aus `app/assets/fonts/`), `web/src/main.tsx`, `web/src/routes.tsx`, `web/src/api/client.ts`, `web/src/api/auth.ts`, `web/src/styles/tokens.css`, `web/src/styles/base.css`, `web/src/ui/{Button,TextField,Card,Dialog,Toast,EmptyState,Skeleton,PageHeader,AppShell}.tsx` mit je einer `.module.css`, `web/src/pages/{SetupPage,LoginPage}.tsx`, `web/playwright.config.ts`, `web/e2e/support/server.ts`, `web/e2e/auth.spec.ts`, `server/src/web.ts`
- Modify: `server/src/app.ts`, `DESIGN.md` (neuer Abschnitt "Verwaltung im Browser")
- Test: `web/src/api/client.test.ts`, `web/e2e/auth.spec.ts`, `server/test/web.test.ts`

**Interfaces:**
- Consumes: die Adressen aus Task 3.
- Produces:
  - `api.get<T>(path)`, `api.post<T>(path, body?)`, `api.patch<T>(path, body)`, `api.del(path)`: senden `X-Kassa-Request: 1` und `credentials: "same-origin"`, werfen `ApiError { status, code, message, problems?, retryAfterSeconds? }`. Bei 401 außerhalb der Anmeldeseiten: weiter nach `/anmelden`.
  - `useMe()` (react-query) und `<RequireUser>` als Wächter der Routen.
  - Bausteine mit diesen Eigenschaften: `Button({ variant: 'primary' | 'secondary' | 'danger' | 'quiet', busy?, ...button })`, `TextField({ label, error?, hint?, ...input })`, `Dialog({ title, open, onClose, children, actions })` (Fokus bleibt im Dialog, Escape schließt), `toast.show(message, { undo?: () => void })`, `EmptyState({ title, text, action? })`, `Skeleton({ lines })`, `AppShell({ nav: { to, label, icon }[], children })` mit Seitenleiste ab 1024 px und Leiste unten darunter.
  - `registerWeb(app, webDir)`: liefert `webDir` aus, für jede GET-Anfrage außerhalb von `/api`, `/laden` und `/healthz` ohne passende Datei die `index.html`. Setzt für alle Antworten `X-Content-Type-Options: nosniff`, `Referrer-Policy: same-origin`, `X-Frame-Options: DENY`, `Content-Security-Policy: default-src 'self'; img-src 'self' data: blob:; object-src 'none'; base-uri 'self'; frame-ancestors 'none'`, bei https dazu `Strict-Transport-Security: max-age=31536000`. Dateien unter `/assets/` bekommen `Cache-Control: public, max-age=31536000, immutable`, `index.html` bekommt `no-cache`.
  - Seiten: `/einrichten?token=…` (prüft den Schlüssel, zeigt E-Mail, Passwort, Passwort wiederholen, danach weiter nach `/betriebe`. Bei ungültigem Schlüssel: "Dieser Link gilt nicht mehr. Bitte einen neuen anfordern."), `/anmelden` (E-Mail, Passwort, bei 429 "Zu viele Versuche. Bitte in <n> Minuten nochmal."), `/` leitet je nach Anmeldung weiter.
  - `DESIGN.md`, Abschnitt "Verwaltung im Browser": dieselben Farben, dieselbe Schrift und dieselben Radien wie die App als CSS-Variablen, Umbruchstellen 640 und 1024 px, Eingabefelder 44 px hoch mit Beschriftung darüber, Fokusring 2 px Petrol mit 2 px Abstand, Listen werden unter 640 px zu Karten, Bewegung 120 bis 320 ms und aus bei `prefers-reduced-motion`, helle und dunkle Ansicht nach Systemeinstellung.
  - `web/e2e/support/server.ts`: startet für die Browser-Tests die Test-Datenbank, eine frische Datenbank, den gebauten Server auf einem freien Port mit `SETUP_TOKEN=e2e-setup-token`, `RELEASE_TOKEN=e2e-release-token`, `FILE_DIR` in einem Temp-Ordner und `WEB_DIR=web/dist`.

- [ ] **Step 1: Tests schreiben**

```ts
// client.test.ts
test('POST trägt X-Kassa-Request und Content-Type JSON', …);
test('Fehlerantwort wird zu ApiError mit code, message, problems', …);
// server/test/web.test.ts
test('GET /betriebe liefert index.html, GET /api/x bleibt 404 JSON, GET /laden/x/y bleibt 404 Text', …);
test('jede Antwort trägt die Sicherheits-Kopfzeilen', …);
// e2e/auth.spec.ts
test('Einrichten: Konto anlegen und auf "Betriebe" landen', …);
test('Einrichten mit verbrauchtem Link zeigt "Dieser Link gilt nicht mehr."', …);
test('Passwort mit 9 Zeichen zeigt die Meldung am Feld, nichts wird gesendet', …);
test('Abmelden, falsches Passwort zeigt "E-Mail oder Passwort stimmt nicht.", richtiges meldet an', …);
test('ohne Anmeldung führt /betriebe nach /anmelden', …);
test('bei 390 px Breite gibt es kein waagrechtes Scrollen', …); // scrollWidth <= clientWidth
```

- [ ] **Step 2: Fehlschlag sehen.** Run aus `web/`: `npx vitest run && npx playwright test --trace off`. Expected: FAIL.
- [ ] **Step 3: Bauen.** Skripte in `web/package.json`: `dev` (Vite mit Weiterleitung von `/api` und `/laden` an `http://localhost:3000`), `build`, `test`, `e2e`, `typecheck`. Die Seite "Betriebe" ist in dieser Aufgabe nur die Überschrift im `AppShell`.
- [ ] **Step 4: Tests grün, dann ansehen.** Run: `npm run build && npx vitest run && npx playwright test --trace off`. Expected: PASS. Danach je ein Bildschirmfoto von `/anmelden` und `/einrichten` in 1280 und 390 px, hell und dunkel, nach `web/e2e/shots/` (nicht einchecken) und im Bericht nennen.
- [ ] **Step 5: Commit** `Verwaltung: Gerüst, Bausteine, Einrichten und Anmelden`

### Task 11: Seiten für Betriebe, Mitarbeiter, Kassen, Installationsdateien

**Files:**
- Create: `web/src/api/{businesses,staff,registers,releases}.ts`, `web/src/pages/{BusinessesPage,BusinessLayout,MenuPage,StaffPage,RegistersPage,ReleasesPage}.tsx` mit `.module.css`, `web/src/ui/{FileDrop,CodeDisplay,StatusChip,ConfirmDialog}.tsx`, `web/src/format.ts`, `web/e2e/flow.spec.ts`
- Modify: `web/src/routes.tsx`
- Test: `web/src/format.test.ts`, `web/e2e/flow.spec.ts`

**Interfaces:**
- Consumes: die Adressen aus Task 5 bis 9, die Bausteine aus Task 10, `shared/fixtures/menu/inputs/beispiel-imbiss.json` und eine ungültige Eingabe.
- Produces (Routen und ihr Verhalten):
  - `/betriebe` (Anbieter): Karten mit Name, "<n> Artikel", "<n> Kassen". Leer: "Noch kein Betrieb" mit der Taste "Betrieb anlegen". Anlegen: Dialog mit `FileDrop` ("Speisekarten-Datei hierher ziehen oder auswählen", nur `.json`). Bei `menu_invalid`: "Die Datei hat <n> Probleme" und jede Zeile aus `problems`. Bei Erfolg weiter nach `/b/<id>/kassen`.
  - `/b/:b/…` mit Leiste: Kassen, Mitarbeiter, Speisekarte, für den Anbieter dazu "Alle Betriebe". Unbekannter Betrieb: "Diesen Betrieb gibt es nicht."
  - `/b/:b/speisekarte`: Zahl der Artikel, Kategorien und Vorlagen, Liste der Kategorien mit Artikelzahl. Taste "Speisekarte neu einspielen" (nur Anbieter) mit Rückfrage "Die Datei gewinnt bei allem, was in ihr steht, auch bei Preisen. Favoriten, "Im Verkauf" und Fotos bleiben.", danach Meldung "<a> neu, <c> geändert, <x> stillgelegt".
  - `/b/:b/mitarbeiter`: Liste mit Name, Rolle (Chef oder Mitarbeiter), stillgelegte am Ende und blass. "Mitarbeiter anlegen": Name, Rolle, PIN (`inputMode="numeric"`, `maxLength=4`, `autoComplete="off"`). Bearbeiten: Name, Rolle, "PIN neu setzen". Stilllegen mit Meldung und "Rückgängig". Fehler `pin_taken`, `last_chef`, `first_must_be_chef` erscheinen am Feld oder als Meldung mit dem Text des Servers. Leer: "Noch kein Mitarbeiter. Lege zuerst einen Chef an."
  - `/b/:b/kassen`: Liste mit Name, `StatusChip` ("Verbunden", "Gesperrt"), "zuletzt gesehen vor <Dauer>" oder "noch nie", App-Version. "Kassa koppeln": Dialog fragt den Namen (Vorgabe "Kassa <n+1>"), zeigt dann den Code groß als `4820 1937`, darunter "gilt noch 14:32" herunterzählend und "Am Tablet: Mit Code koppeln". Nach Ablauf: "Der Code ist abgelaufen." mit "Neuen Code erzeugen". Solange der Dialog offen ist, wird die Liste alle 3 Sekunden neu geladen, und sobald eine neue Kassa erscheint, steht dort "Verbunden". Sperren mit Rückfrage "Diese Kassa gleicht dann nicht mehr ab. Bonieren geht am Tablet weiter.", "Sperre aufheben" ohne Rückfrage. Leer: "Noch keine Kassa gekoppelt."
  - `/installationsdateien` (Anbieter): Liste mit Version, Build, Datum, Größe in MB, den ersten 12 Zeichen der Prüfsumme, "Link kopieren" (ganze Adresse mit `window.location.origin`), "Zurückziehen" mit Rückfrage. Leer: "Noch keine Installationsdatei."
  - `format.ts`: `ago(date, now): string` ("gerade eben", "vor 5 Minuten", "vor 2 Stunden", "vor 3 Tagen"), `megabytes(bytes): string` ("24,1 MB"), `codeGroups(code): string`, `countdown(ms): string` ("14:32").
  - Jede Liste hat einen Ladezustand aus `Skeleton` und einen Fehlerzustand mit "Nochmal versuchen".

- [ ] **Step 1: Tests schreiben**

```ts
// format.test.ts: ago, megabytes (deutsches Komma), codeGroups('48201937') === '4820 1937', countdown(872000) === '14:32'
// e2e/flow.spec.ts (ein durchgehender Weg, danach Einzelfälle)
test('Betrieb anlegen, Chef anlegen, Kassa koppeln', async () => {
  // Einrichten → leere Liste → Beispieldatei hochladen → Kassen leer → Mitarbeiter: Chefin, PIN 1234
  // → Kassen: koppeln, Code hat die Form /^\d{4} \d{4}$/ → den Code per fetch an /api/device/pair senden
  // → im offenen Dialog erscheint "Verbunden", die Liste zeigt "Kassa 1"
});
test('ungültige Datei zeigt die Zahl und den Wortlaut der Probleme', …);
test('zweite Person mit PIN 1234 zeigt "Diese PIN ist schon vergeben."', …);
test('einzigen Chef stilllegen zeigt "Mindestens ein Chef muss bleiben."', …);
test('stilllegen und "Rückgängig" stellt die Person wieder her', …);
test('sperren zeigt "Gesperrt", aufheben zeigt wieder "Verbunden"', …);
test('Installationsdatei: nach dem Hochladen über die Schnittstelle steht sie in der Liste, zurückziehen entfernt den Link', …);
test('alle fünf Seiten bei 390 px ohne waagrechtes Scrollen', …);
```

- [ ] **Step 2: Fehlschlag sehen.** Run: `npx vitest run && npx playwright test --trace off`. Expected: FAIL.
- [ ] **Step 3: Bauen.** Daten über react-query, Änderungen sofort in der Liste und bei Fehler zurück.
- [ ] **Step 4: Tests grün, dann ansehen.** Run: `npm run build && npx vitest run && npx playwright test --trace off && npm run typecheck`. Expected: PASS. Bildschirmfotos aller fünf Seiten in 1280 und 390 px, hell und dunkel, nach `web/e2e/shots/`, im Bericht nennen.
- [ ] **Step 5: Commit** `Verwaltung: Betriebe, Speisekarte, Mitarbeiter, Kassen, Installationsdateien`

### Task 12: App: Datenbank Version 3 und Zugang zum Server

**Files:**
- Create: `app/lib/sync/server_api.dart`, `app/lib/sync/token_store.dart`, `app/lib/data/sync_state_repository.dart`, `app/drift_schemas/drift_schema_v3.json`, `app/test/data/generated_migrations/schema_v3.dart`, `app/test/data/fixtures/kassa_v2.sqlite`
- Modify: `app/pubspec.yaml` (dazu `http`, `flutter_secure_storage`), `app/lib/data/database.dart` (Tabelle `SyncStateRows`, `schemaVersion => 3`, Migration), `app/lib/data/database.g.dart`, `app/lib/data/providers.dart`, `app/lib/core/app_info.dart`, `app/lib/sync/wire.dart`, `app/test/data/generated_migrations/schema.dart`, `app/test/data/migration_test.dart`
- Test: `app/test/data/migration_test.dart`, `app/test/data/sync_state_repository_test.dart`, `app/test/sync/wire_test.dart`, `app/test/sync/server_api_test.dart`

**Interfaces:**
- Consumes: `shared/fixtures/sync/*.json` (Task 8), `catalogToWire` (Task 4).
- Produces:
  - `const serverUrl = String.fromEnvironment('KASSA_SERVER_URL');` und `bool get hasServer => serverUrl.isNotEmpty;` in `app_info.dart`.
  - Tabelle `SyncStateRows` (genau eine Zeile, `id = 1`): `registerId` Text oder leer, `registerName`, `businessId`, `pullCursor` int Vorgabe 0, `initialPullDone` bool Vorgabe false, `lastPullAt` Zeitpunkt oder leer, `lastError` Text oder leer, `blocked` bool Vorgabe false.
  - `class SyncState { registerId, registerName, businessId, pullCursor, initialPullDone, lastPullAt, lastError, blocked; bool get hasRegister => registerId != null; bool get paired => hasRegister && initialPullDone; }`.
  - `class SyncStateRepository { Future<SyncState> current(); Stream<SyncState> watch(); Future<void> saveRegister({required String registerId, required String registerName, required String businessId}); Future<void> setResult({required DateTime at, String? error, bool? blocked}); }`. `saveRegister` setzt `pullCursor = 0`, `initialPullDone = false`, `blocked = false`. Cursor und `initialPullDone` schreibt nur Task 13 zusammen mit den Daten.
  - `wire.dart`: `class PullResponse { int next; bool more; BusinessInfo? business; List<WireCategory> categories; List<WireItem> items; List<WireTemplate> templates; List<WireStaff> staff; factory PullResponse.fromJson(Map<String, dynamic>) }`, `class PairResponse { registerId, registerName, businessId, businessName, token }`. Unbekannte Felder werden überlesen. Fehlt ein Pflichtfeld oder kommt ein unbekanntes Kennzeichen oder ein nicht erlaubter Steuersatz, wirft `fromJson` eine `FormatException`.
  - `enum ServerFailure { offline, timeout, invalidCode, tooManyAttempts, otherBusiness, unauthorized, blocked, server }`, `class ServerException implements Exception { final ServerFailure failure; }`.
  - `class ServerApi { ServerApi({required String baseUrl, required http.Client client, required String appVersion, Duration timeout = const Duration(seconds: 10)}); Future<PairResponse> pair({required String code, String? previousBusinessId, String? deviceModel}); Future<PullResponse> pull({required String token, required int since}); }`. Zuordnung: Fehler beim Verbinden → `offline`, Zeitgrenze → `timeout`, `code` der Antwort `invalid_code`, `too_many_attempts`, `other_business`, `unauthorized`, `register_blocked` → das passende Glied, alles andere (auch unlesbare Antwort) → `server`. Jede Anfrage trägt `X-Kassa-App-Version`.
  - `abstract class TokenStore { Future<String?> read(); Future<void> write(String token); Future<void> clear(); }`, `SecureTokenStore` (Schlüssel `kassa_device_token`), `MemoryTokenStore`.
  - Provider: `syncStateRepositoryProvider`, `syncStateProvider` (Stream), `tokenStoreProvider`, `httpClientProvider`, `serverApiProvider`.

- [ ] **Step 1: Schema-Abbild und echte Datei der Version 2 sichern, bevor die Tabelle dazukommt.** `kassa_v2.sqlite`: mit dem Stand vor dieser Aufgabe erzeugt, enthält den Beispiel-Imbiss, eine Chefin, einen Bar-Bon und geänderte Drucker-Einstellungen. Der Weg steht in `docs/superpowers/plans/2026-11-18-teil-b-bondruck-und-kartenzahlung.md` bei der Migration auf Version 2.
- [ ] **Step 2: Tests schreiben**

```dart
// migration_test.dart
test('Schema: Version 2 wird zu Version 3', …);            // SchemaVerifier
test('echte Datei von Version 2: Bon, Chefin und Drucker bleiben, SyncState ist leer und nicht gekoppelt', …);
test('Trigger gegen das Ändern von Bons gelten nach der Migration', …);
// sync_state_repository_test.dart
test('frische Datenbank: nicht gekoppelt, Cursor 0', …);
test('saveRegister setzt Cursor und initialPullDone zurück', …);
test('watch meldet jede Änderung', …);
// wire_test.dart
test('pull_full.json und pull_delta.json werden gelesen', …);   // Zahl und ein Feld je Art prüfen
test('pair_response.json wird gelesen', …);
test('unbekannte Felder stören nicht, fehlendes Pflichtfeld ist FormatException', …);
test('Kennzeichen "neu" und Steuersatz 7 sind FormatException', …);
// server_api_test.dart   (MockClient aus package:http/testing.dart)
test('pair sendet code, previousBusinessId, appVersion wie pair_request.json', …);
test('jedes Beispiel aus errors.json ergibt das passende ServerFailure', …);
test('SocketException ergibt offline, zu späte Antwort ergibt timeout', …);
test('Antwort 200 mit Unsinn ergibt server', …);
test('pull sendet Authorization: Bearer und since', …);
```

- [ ] **Step 3: Fehlschlag sehen.** Run: `flutter test test/data/migration_test.dart test/sync`. Expected: FAIL.
- [ ] **Step 4: Bauen.** `dart run build_runner build`, Schema-Abbild Version 3 ablegen. Baut `flutter build apk --debug` mit `flutter_secure_storage` nicht, hier anhalten und mit der Fehlermeldung berichten, nichts umgehen.
- [ ] **Step 5: Tests grün.** Run: `flutter test && flutter analyze`. Expected: PASS, keine Warnung.
- [ ] **Step 6: Commit** `App: Datenbank Version 3, Zugang zum Server, Geräte-Schlüssel im geschützten Speicher`

### Task 13: App: koppeln und Daten vom Server übernehmen

**Files:**
- Create: `app/lib/sync/server_changes.dart`, `app/lib/sync/pairing_service.dart`, `app/lib/sync/sync_service.dart`
- Modify: `app/lib/data/providers.dart`, `app/lib/main.dart` oder `app/lib/app.dart` (Start des Abgleichs)
- Test: `app/test/sync/server_changes_test.dart`, `app/test/sync/pairing_service_test.dart`, `app/test/sync/sync_service_test.dart`, `app/test/support/fake_server.dart`

**Interfaces:**
- Consumes: `ServerApi`, `TokenStore`, `SyncStateRepository`, `PullResponse`, `KassaDatabase`, `SettingsRepository.writeDraft`, `Clock`, der Internet-Zustand aus `lib/devices/internet.dart`.
- Produces:
  - `class ServerChanges { ServerChanges(KassaDatabase db); Future<void> replaceAll(List<PullResponse> pages, {required DateTime at}); Future<void> applyPage(PullResponse page, {required DateTime at}); }`.
    - `replaceAll` (erstes Holen nach dem Koppeln), alles in einer Transaktion: alle Kategorien und Artikel am Tablet stilllegen, dann alle Seiten der Reihe nach übernehmen, Vorlagen samt Gruppen und Optionen, die in keiner Seite vorkommen, löschen, alle Mitarbeiter löschen und die vom Server einfügen, Betriebsdaten setzen, den offenen Bon leeren (`receiptDraft = null`), `pullCursor = letzte Seite.next`, `initialPullDone = true`, `lastPullAt = at`, `lastError = null`. Scheitert irgendetwas, bleibt das Tablet genau wie vorher.
    - `applyPage` (jedes spätere Holen), in einer Transaktion: Kategorien und Artikel nach Kennung einfügen oder überschreiben, samt `archived`. `photoPath` am Tablet bleibt unberührt. Eine Vorlage ersetzt ihre Gruppen und Optionen ganz, eine stillgelegte Vorlage wird gelöscht. Mitarbeiter einfügen oder überschreiben, stillgelegte löschen. Betriebsdaten setzen, wenn `business` da ist. `pullCursor = page.next`, `lastPullAt = at`.
    - Reihenfolge innerhalb einer Seite: Kategorien vor Artikeln, Vorlagen vor Artikeln.
  - `enum PairingStep { idle, checking, loading, done }` und `class PairingService { Future<PairResponse> pair(String code); Future<void> loadInitial(); }`. `pair`: ruft `ServerApi.pair` mit dem `businessId` aus dem `SyncState` als `previousBusinessId`, schreibt zuerst den Schlüssel in den `TokenStore`, dann `saveRegister`. `loadInitial`: holt seitenweise ab `since = 0` bis `more == false` in den Speicher, ruft dann `replaceAll` und meldet die angemeldete Person ab. Beide werfen `ServerException` weiter. `loadInitial` lässt sich beliebig oft wiederholen und braucht keinen neuen Code.
  - `class SyncService { Future<void> syncNow(); void start(); void dispose(); Stream<bool> get running; }`. `syncNow`: nichts tun ohne Kassa, ohne `initialPullDone` oder wenn schon ein Lauf läuft (der zweite Aufruf wartet auf den ersten). Sonst seitenweise `pull` ab `pullCursor` und `applyPage`, bis `more == false`. Ergebnis: Erfolg → `setResult(at, error: null, blocked: false)`. `blocked` → `setResult(blocked: true)`. `unauthorized` → `setResult(error: 'unauthorized')`. Alles andere → `setResult(error: failure.name)`. `syncNow` wirft nie. `start`: sofort ein Lauf, dann alle 5 Minuten, außerdem wenn die App wieder nach vorn kommt und wenn das Internet zurückkommt. Nach einem Fehler folgt der nächste Versuch nach 30 Sekunden, 1, 2, 4, 8, dann immer 15 Minuten, ein Erfolg setzt das zurück. Bei `blocked` und `unauthorized` gibt es keine schnellen Wiederholungen, nur den Lauf alle 5 Minuten.
  - Provider: `serverChangesProvider`, `pairingServiceProvider`, `syncServiceProvider` (startet in `KassaApp`, sobald `syncState.paired`).
  - `FakeServer` für Tests: ein `http.Client`, der `pair` und `pull` aus einer Liste von Zeilen mit Nummern beantwortet, Seiten bildet und sich pro Anfrage auf "offline", "blocked" oder "bricht nach Seite n ab" stellen lässt.

- [ ] **Step 1: Tests schreiben**

```dart
// server_changes_test.dart
test('replaceAll auf leerem Tablet: Speisekarte, Chefin, Betriebsdaten sind da, Cursor = next', …);
test('replaceAll auf eingerichtetem Tablet: Artikel, die der Server nicht hat, sind stillgelegt, nicht gelöscht', …);
test('replaceAll: ein alter Bon bleibt lesbar und zeigt seine Namen und Preise', …);
test('replaceAll: Mitarbeiter vom Tablet sind weg, die vom Server melden mit ihrer PIN an', …);
test('replaceAll: der offene Bon ist geleert', …);
test('replaceAll scheitert mitten drin: Speisekarte, Mitarbeiter, Cursor und Entwurf sind unverändert', …); // Seite 2 verweist auf eine Kategorie, die es nicht gibt
test('applyPage: Preis ändert sich, photoPath bleibt', …);
test('applyPage: stillgelegter Artikel verschwindet aus dem Verkauf, taucht mit archived=false wieder auf', …);
test('applyPage: Vorlage mit einer Option weniger hat danach genau die neuen Optionen', …);
test('applyPage: stillgelegte Mitarbeiterin kann sich nicht mehr anmelden', …);
test('applyPage scheitert: Cursor bleibt, nichts ist halb übernommen', …);
// pairing_service_test.dart
test('pair legt Schlüssel und Kassa ab, die Speisekarte ist noch die alte', …);
test('falscher Code: ServerException invalidCode, nichts gespeichert', …);
test('loadInitial holt alle Seiten und meldet ab', …);
test('Internet bricht nach Seite 1 ab: alte Speisekarte vollständig, loadInitial nochmal ohne neuen Code gelingt', …);
test('zweites Koppeln sendet die Kennung des bisherigen Betriebs mit', …);
// sync_service_test.dart   (fake_async)
test('nicht gekoppelt: syncNow fragt den Server nicht', …);
test('Lauf holt alle Seiten und merkt sich den Zeitpunkt', …);
test('zwei syncNow gleichzeitig: nur ein Lauf', …);
test('offline: lastError gesetzt, nächste Versuche nach 30 s, 1 min, 2 min, höchstens 15 min, Erfolg setzt zurück', …);
test('gesperrt: blocked = true, kein schnelles Wiederholen, nach dem Aufheben wieder false', …);
test('unauthorized: lastError = unauthorized', …);
test('syncNow wirft auch bei unlesbarer Antwort nicht', …);
test('alle 5 Minuten ein Lauf, und einer, wenn das Internet zurückkommt', …);
```

- [ ] **Step 2: Fehlschlag sehen.** Run: `flutter test test/sync`. Expected: FAIL.
- [ ] **Step 3: Bauen.**
- [ ] **Step 4: Tests grün.** Run: `flutter test && flutter analyze`. Expected: PASS, keine Warnung.
- [ ] **Step 5: Commit** `App: koppeln, Speisekarte vom Server übernehmen, im Hintergrund holen`

### Task 14: App: Bildschirme zum Koppeln

**Files:**
- Create: `app/lib/features/setup/pairing_view.dart`, `app/lib/features/setup/pairing_controller.dart`, `app/lib/ui/code_boxes.dart`
- Modify: `app/lib/features/setup/setup_screen.dart`, `app/lib/data/providers.dart` (`setupCompleteProvider`)
- Test: `app/test/features/pairing_test.dart`, `app/test/golden/pairing_golden_test.dart`, `app/test/features/setup_test.dart`

**Interfaces:**
- Consumes: `PairingService`, `SyncService.syncNow`, `SyncState`, `hasServer`, `ui/keypad.dart`, `PrimaryButton`, Maße aus `DESIGN.md`. Wortlaut und Aufbau: Entwurf 5.11, Punkte 1 bis 3.
- Produces:
  - Erster Bildschirm (`_Step.start`): Überschrift "Kassa einrichten", Haupttaste "Mit Code koppeln" (`Key('setup-pair')`), darunter als zweite Taste "Speisekarte aus Datei einspielen" (`Key('setup-file')`, bisheriger Weg unverändert). Ohne Server (`!hasServer`) ist die Haupttaste aus und darunter steht "Diese Version hat keinen Server."
  - `CodeBoxes({required String value, int length = 8, bool error = false})`: acht Felder, nach dem vierten ein etwas größerer Abstand.
  - `PairingView`: Überschrift "Kopplungscode eingeben", `CodeBoxes`, Zahlenfeld, Hinweis "Den Code findest du in der Verwaltung unter Kassen.", Taste "Koppeln" (`Key('pair-submit')`, erst bei 8 Ziffern aktiv), "Zurück" (`Key('pair-back')`). Zustände: prüfen (Taste zeigt Fortschritt, Zahlenfeld gesperrt), Fehler unter den Feldern (die Felder leeren sich): `invalidCode` → "Der Code stimmt nicht oder ist abgelaufen.", `offline` und `timeout` → "Keine Verbindung zum Internet.", `tooManyAttempts` → "Zu viele Versuche. Bitte in 15 Minuten nochmal.", `otherBusiness` → "Dieses Tablet gehört zu einem anderen Betrieb.", `server` → "Das hat nicht geklappt. Bitte nochmal versuchen."
  - Nach dem Koppeln: "Verbunden mit <Betrieb>", darunter "Speisekarte wird geladen" mit Fortschritt. Scheitert das Laden: "Die Speisekarte konnte nicht geladen werden." mit "Nochmal versuchen" (`Key('pair-retry')`, ruft `loadInitial`).
  - Hat der Betrieb keinen Mitarbeiter: "Lege in der Verwaltung zuerst einen Mitarbeiter mit PIN an." mit "Nochmal prüfen" (`Key('pair-recheck')`, ruft `syncNow`). Sobald einer da ist, erscheint die Anmeldung mit PIN.
  - Start der App auf einem Tablet ohne Speisekarte: Hat es eine Kassa, aber `initialPullDone == false`, öffnet `SetupScreen` gleich bei "Speisekarte wird geladen" und versucht es. Ein Tablet, das schon eine Speisekarte aus der Datei hat, startet wie immer und lädt nie von selbst nach (das geschieht nur über die Einstellungen, Task 15, weil dabei abgemeldet wird). Bei gekoppelten Tablets entfällt "Chef-PIN festlegen".
  - `setupCompleteProvider` bleibt "Speisekarte da und mindestens ein Mitarbeiter", hängt jetzt aber an den Strömen, damit ein Mitarbeiter vom Server den Bildschirm von selbst weiterschaltet.

- [ ] **Step 1: Tests schreiben**

```dart
// pairing_test.dart
testWidgets('erster Start zeigt beide Wege, "Mit Code koppeln" öffnet die Code-Eingabe', …);
testWidgets('ohne Server ist die Taste aus und der Hinweis steht da', …);
testWidgets('"Koppeln" ist erst bei 8 Ziffern aktiv, die 9. Ziffer wird nicht angenommen', …);
testWidgets('falscher Code zeigt den Satz und leert die Felder', …);
testWidgets('ohne Internet zeigt "Keine Verbindung zum Internet."', …);
testWidgets('richtiger Code: "Verbunden mit Beispiel-Imbiss", dann die Anmeldung mit PIN, PIN 1234 meldet an', …);
testWidgets('Laden scheitert: "Nochmal versuchen" gelingt ohne neuen Code', …);
testWidgets('Betrieb ohne Mitarbeiter: Hinweis, nach "Nochmal prüfen" mit Mitarbeiter erscheint die PIN', …);
testWidgets('App startet mit Kassa, aber ohne geladene Speisekarte: lädt von selbst weiter', …);
testWidgets('"Zurück" führt zum ersten Bildschirm, der Weg über die Datei geht wie bisher', …);
// pairing_golden_test.dart: Start, Code leer, Code mit 4 Ziffern, Fehler, Laden, kein Mitarbeiter, je hell und dunkel, 1280 × 800
```

- [ ] **Step 2: Fehlschlag sehen.** Run: `flutter test test/features/pairing_test.dart`. Expected: FAIL.
- [ ] **Step 3: Bauen.** Kein Textfeld. Tippflächen und Abstände wie auf dem PIN-Bildschirm.
- [ ] **Step 4: Tests grün, Bilder ansehen.** Run: `flutter test --update-goldens test/golden/pairing_golden_test.dart`, die neuen Bilder ansehen und im Bericht beschreiben, dann `flutter test && flutter analyze`. Expected: PASS, keine Warnung.
- [ ] **Step 5: Commit** `App: Bildschirme zum Koppeln mit Code`

### Task 15: App: Einstellungen "Server"

**Files:**
- Create: `app/lib/features/settings/server_panel.dart`, `app/lib/features/settings/pair_question.dart`
- Modify: `app/lib/features/settings/settings_screen.dart`, `app/lib/features/settings/reimport_panel.dart`
- Test: `app/test/features/server_settings_test.dart`, `app/test/golden/settings_golden_test.dart`, `app/test/features/settings_test.dart`

**Interfaces:**
- Consumes: `syncStateProvider`, `SyncService`, `PairingView` (Task 14), `Clock`, die Bausteine der Einstellungen (`settings_rows.dart`). Wortlaut: Entwurf 5.11, Punkte 4 und 5, und 5.4.
- Produces:
  - Karte "Server" in den Einstellungen, fünf Zustände:
    - Gekoppelt: "Verbunden mit <Betrieb> als <Kassa>", "Zuletzt abgeglichen <Dauer>" ("gerade eben", "vor 2 Minuten", "vor 3 Stunden", "noch nie"), Taste "Jetzt abgleichen" (`Key('server-sync')`, zeigt während des Laufs Fortschritt). Ist der letzte Versuch gescheitert: darunter "Der letzte Abgleich hat nicht geklappt. Die Kassa versucht es von selbst wieder."
    - Gesperrt: "Diese Kassa wurde in der Verwaltung gesperrt." und "Bonieren geht weiter. Abgeglichen wird erst wieder, wenn die Sperre aufgehoben ist."
    - Dem Server unbekannt (`lastError == 'unauthorized'`): "Der Server kennt diese Kassa nicht mehr." mit der Taste "Neu koppeln".
    - Kassa da, Speisekarte noch nicht geladen (`hasRegister && !initialPullDone`): "Die Verbindung steht. Die Speisekarte ist noch nicht geladen." mit der Taste "Speisekarte laden" (`Key('server-load')`, zeigt die Rückfrage und ruft dann `loadInitial`).
    - Nicht gekoppelt: "Nicht mit dem Server verbunden." mit der Taste "Mit Server verbinden" (`Key('server-pair')`). Ohne Server in dieser Version: "Diese Version hat keinen Server.", keine Taste.
  - `PairQuestion`: Rückfrage vor dem Koppeln eines eingerichteten Tablets. Titel "Mit dem Server verbinden?". Text: "Die Speisekarte und die Mitarbeiter kommen danach vom Server. Die Bons auf diesem Tablet bleiben. Ein offener Bon wird geleert, und du meldest dich neu an." Tasten "Verbinden" und "Abbrechen". "Verbinden" öffnet `PairingView` als ganzen Bildschirm, nach Erfolg erscheint die Anmeldung mit PIN.
  - "Speisekarte neu einspielen" zeigt bei gekoppelten Tablets statt der Taste den Satz "Die Speisekarte kommt vom Server."
  - Während einer laufenden Kartenzahlung (`activeCardPaymentProvider != null`) ist "Mit Server verbinden" gesperrt.

- [ ] **Step 1: Tests schreiben**

```dart
testWidgets('nicht gekoppelt: Taste da, Rückfrage erscheint, "Abbrechen" ändert nichts', …);
testWidgets('"Verbinden" und richtiger Code: neue Speisekarte, abgemeldet, offener Bon leer, alte Bons noch da', …);
testWidgets('gekoppelt: Betrieb, Kassa und "Zuletzt abgeglichen vor 2 Minuten"', …);
testWidgets('"Jetzt abgleichen" holt und zeigt danach "gerade eben"', …);
testWidgets('gescheiterter Abgleich zeigt den Hinweis, die Kassa bleibt bedienbar', …);
testWidgets('gesperrt zeigt beide Sätze und keine Taste', …);
testWidgets('unauthorized zeigt "Neu koppeln"', …);
testWidgets('Kassa da, Speisekarte nicht geladen: "Speisekarte laden" holt sie ohne neuen Code', …);
testWidgets('gekoppelt: statt "Speisekarte neu einspielen" steht "Die Speisekarte kommt vom Server."', …);
testWidgets('während einer Kartenzahlung ist "Mit Server verbinden" gesperrt', …);
// settings_golden_test.dart: Karte "Server" in den fünf Zuständen, hell und dunkel
```

- [ ] **Step 2: Fehlschlag sehen.** Run: `flutter test test/features/server_settings_test.dart`. Expected: FAIL.
- [ ] **Step 3: Bauen.**
- [ ] **Step 4: Tests grün, Bilder ansehen.** Run: `flutter test --update-goldens test/golden/settings_golden_test.dart`, Bilder ansehen und beschreiben, dann `flutter test && flutter analyze`. Expected: PASS, keine Warnung.
- [ ] **Step 5: Commit** `App: Einstellungen "Server" mit Koppeln, Abgleich und Sperre`

### Task 16: Zusammenspiel, Bau-Skript, Version 1.2.0, Prüfliste

**Files:**
- Create: `tool/e2e.sh`, `server/src/dev/seed.ts`, `app/test_e2e/pair_and_pull_test.dart`, `Dockerfile`, `.dockerignore`, `docs/testen/teil-c1-pruefliste.md`
- Modify: `tool/build_apk.sh`, `app/pubspec.yaml` (`version: 1.2.0+4`), `app/lib/core/app_info.dart` (`appVersion = '1.2.0'`), `docs/superpowers/specs/2026-11-18-teil-c-server-und-verwaltung-design.md` (nur, wo der Bau vom Entwurf abweicht, mit Datum)
- Test: `app/test_e2e/pair_and_pull_test.dart`, `tool/e2e.sh`

**Interfaces:**
- Consumes: alles Vorige.
- Produces:
  - `server/src/dev/seed.ts`: legt in einer leeren Datenbank einen Anbieter, den Beispiel-Imbiss, eine Chefin mit PIN 1234 und einen Kopplungscode an und gibt `{"businessId":…, "code":…, "cookie":…}` als eine Zeile JSON aus. Weigert sich, wenn `PUBLIC_URL` nicht mit `http://127.0.0.1` oder `http://localhost` beginnt.
  - `tool/e2e.sh`: startet die Test-Datenbank, baut Web und Server, startet den Server auf einem freien Port, ruft `seed`, lässt `flutter test test_e2e --dart-define=E2E_SERVER=<Adresse> --dart-define=E2E_CODE=<Code> --dart-define=E2E_COOKIE=<Cookie> --dart-define=E2E_BUSINESS=<Kennung>` laufen und räumt auf, auch nach einem Fehler. Endet mit dem Ergebnis des Tests.
  - `pair_and_pull_test.dart` (echtes Netzwerk, `HttpOverrides.global = null`, Datenbank im Speicher): koppeln, alles holen, Speisekarte und Chefin sind da, PIN 1234 meldet an. Dann über die Verwaltung (mit dem Cookie) die Chefin umbenennen und einen zweiten Mitarbeiter anlegen, `syncNow`, beides ist am Tablet. Dann die Kassa sperren, `syncNow` → `blocked`, Sperre aufheben, `syncNow` → wieder frei. Derselbe Code ein zweites Mal → `invalidCode`.
  - `tool/build_apk.sh`: liest `serverUrl=` aus `$KASSA_BUILD_DIR/server.properties` (oder `KASSA_SERVER_PROPERTIES`) und gibt es als `--dart-define=KASSA_SERVER_URL=…` weiter. Fehlt die Datei oder ist der Wert leer oder beginnt er nicht mit `https://`, bricht der Bau mit einem Satz ab, außer mit `KASSA_ALLOW_NO_SERVER=1`. Die Ausgabe nennt am Ende, ob die Datei Server und Kartenzahlung hat.
  - `Dockerfile` (zwei Stufen auf `node:22-slim`): baut `web/` und `server/`, das Abbild enthält nur `server/dist`, `server/migrations`, `server/node_modules` ohne Entwicklungs-Pakete und `web/dist`, startet `node server/dist/main.js` mit `WEB_DIR=/app/web/dist` als Benutzer `node`. `.dockerignore` schließt `app/`, `download/`, `pilot/`, `docs/`, `.git`, `node_modules` aus.
  - `docs/testen/teil-c1-pruefliste.md` für Niko, in einfachen Worten, zum Abhaken: 0. Version 1.2.0 über den geheimen Link laden und über 1.1.0 installieren, Bons und Einstellungen sind noch da. 1. Im Browser anmelden. 2. YICHI aus der Datei anlegen. 3. Chef mit PIN anlegen. 4. Code erzeugen. 5. Am Tablet "Einstellungen, Server, Mit Server verbinden", Rückfrage lesen, Code eintippen. 6. Mit der PIN aus der Verwaltung anmelden. 7. Mitarbeiter im Browser anlegen, am Tablet "Jetzt abgleichen", mit dessen PIN anmelden. 8. Falschen Code probieren. 9. Kassa sperren und Sperre aufheben. 10. WLAN aus: bonieren geht, "Jetzt abgleichen" meldet den Fehler ruhig. Dazu der Hinweis: Preisänderungen am Tablet gehen erst mit der nächsten Stufe zum Server.

- [ ] **Step 1: `pair_and_pull_test.dart` und `tool/e2e.sh` schreiben, Fehlschlag sehen.** Run: `tool/e2e.sh`. Expected: FAIL.
- [ ] **Step 2: `seed.ts`, Bau-Skript, Version, Dockerfile bauen.**
- [ ] **Step 3: Alles grün.** Run: `tool/e2e.sh`, in `server/`: `npx vitest run && npm run typecheck`, in `web/`: `npx vitest run && npx playwright test --trace off`, in `app/`: `flutter test && flutter analyze`. Expected: PASS überall. Das Bau-Skript prüfen: ohne `server.properties` bricht es mit dem Satz ab, mit `KASSA_ALLOW_NO_SERVER=1 KASSA_ALLOW_NO_SUMUP=1` baut es.
- [ ] **Step 4: Prüfliste schreiben.**
- [ ] **Step 5: Commit** `Teil C1: Zusammenspiel-Test, Bau mit Server-Adresse, Version 1.2.0, Prüfliste`

### Task 17: Auslieferung bei Railway (macht Claude selbst, nicht ein Helfer)

Diese Aufgabe ändert Dinge außerhalb des Repos und braucht Niko an zwei Stellen. Sie beginnt, sobald Task 1 bis 11 und 16 fertig und geprüft sind.

- [ ] **Step 1:** Railway-Projekt "kassa" im Workspace "n1kob1ko's Projects" anlegen, Region EU. Die vier vorhandenen Projekte nicht anfassen.
- [ ] **Step 2:** PostgreSQL und Ablage anlegen. Dienst `kassa-server` aus dem Repo, Zweig `claude/project-thread-xtooco`, `Dockerfile` in der Wurzel. Variablen: `DATABASE_URL` als Verweis auf die Datenbank, `APP_DB_PASSWORD`, `SETUP_TOKEN`, `RELEASE_TOKEN` als von Railway erzeugte Geheimnisse, `S3_…` aus der Ablage, `PUBLIC_URL` mit der erzeugten Adresse. Kein Wert davon kommt ins Repo, in den Chat oder in eine Datei unter `/mnt/project-files/`, außer der Adresse des Servers in `kassa-build/server.properties`.
- [ ] **Step 3:** Niko die Karte zum Freischalten von `*.up.railway.app` vorlegen. Danach `/healthz` prüfen.
- [ ] **Step 4:** Niko den Link zum Einrichten seines Kontos schicken (enthält den Einmal-Schlüssel, deshalb nur in den Thread mit ihm, und der Schlüssel ist nach der Benutzung wertlos).
- [ ] **Step 5:** Installationsdatei 1.2.0 mit Server-Adresse bauen (mit SumUp-Schlüssel, wenn Niko ihn bis dahin abgelegt hat), über `/api/releases/1.2.0?build=4` hochladen, den geheimen Link und die Prüfliste an Niko.
- [ ] **Step 6:** Im Protokoll bei Railway nachsehen, dass der Start sauber ist und keine Geheimnisse darin stehen.
