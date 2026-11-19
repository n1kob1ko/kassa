# Sicherung zurückspielen

Der Server sichert die Datenbank jede Nacht, kurz nach 3 Uhr Wiener Zeit. Diese Anleitung zeigt, wie Du eine Sicherung holst und in eine leere Datenbank zurückspielst. Spiele nie in die laufende Datenbank zurück: Nimm immer eine leere.

In dieser Anleitung stehen nur Platzhalter in spitzen Klammern, zum Beispiel `<DATABASE_URL>`. Setze die echten Werte aus den Einstellungen Deines Dienstes ein. Schreibe sie nie in eine Datei, die ins Repository kommt.

## Wo die Dateien liegen

- In der Ablage des Servers (Ordner `FILE_DIR` oder der Bucket), im Ordner `backups/`.
- Eine Datei pro Tag: `backups/kassa-<Jahr>-<Monat>-<Tag>.dump`, zum Beispiel `backups/kassa-2026-11-19.dump`. Der Tag ist der Wiener Tag.
- Die letzten 14 gelungenen Sicherungen bleiben, ältere löscht der Server.
- Die Sicherung enthält die Datenbank (Betriebe, Bons, Tage, Berichte, Dateien-Liste). Die Fotos und Logos selbst sind nicht dabei: Sie liegen in der Ablage unter `businesses/` und sind nicht Teil der Sicherung. Die Installationsdateien (`releases/`) auch nicht.

Ob die letzte Sicherung gelungen ist, siehst Du in der Verwaltung beim Anbieter, oder über die Adresse `/api/admin/backups/latest` (Tag, Zeit, Größe, und der letzte Fehler, wenn danach keine gelungen ist).

## Eine Sicherung holen

- Liegt die Ablage in einem Ordner: Kopiere die Datei aus `<FILE_DIR>/backups/`.
- Liegt sie in einem Bucket: Lade `backups/kassa-<Tag>.dump` mit dem Werkzeug Deines Anbieters herunter (zum Beispiel mit der Oberfläche des Buckets).

Prüfe die Datei: Sie ist nicht leer und beginnt mit den Buchstaben `PGDMP`.

```bash
head -c 5 kassa-2026-11-19.dump
```

Die Ausgabe ist `PGDMP`.

## In eine leere Datenbank zurückspielen

Du brauchst `pg_restore` in der gleichen Hauptversion wie `pg_dump` des Servers oder in einer neueren (`pg_restore --version` zeigt sie).

1. Lege eine neue, leere Datenbank an. Verbinde Dich als Besitzer der Datenbank, nicht als `kassa_app`:

   ```bash
   psql "<DATABASE_URL_ZUM_SERVER_OHNE_DATENBANK>" -c "create database kassa_wiederherstellung"
   ```

2. Spiele die Sicherung ein:

   ```bash
   pg_restore --no-owner --exit-on-error --dbname="<URL_DER_NEUEN_DATENBANK>" kassa-2026-11-19.dump
   ```

   Bei Erfolg gibt `pg_restore` nichts aus und endet mit dem Wert 0 (`echo $?` zeigt `0`). Eine Meldung mit `error:` heißt: Es ist etwas schiefgegangen. Dann ist die Datenbank nicht brauchbar. Lege sie neu an und versuche es noch einmal.

   Die Rolle `kassa_app` muss auf dem Server existieren, bevor Du die Sicherung einspielst. Auf einem neuen Server legt `migrate` sie beim Start an.

## Was Du danach prüfst

1. Zähle die Zeilen in der alten und in der neuen Datenbank und vergleiche sie. Sie müssen gleich sein, nur `backups` darf in der Quelle eine Zeile mehr haben, wenn die Sicherung danach eine Zeile bekam:

   ```bash
   psql "<URL>" -Atc "select count(*) from businesses"
   psql "<URL>" -Atc "select count(*) from receipts"
   ```

   Beim Probelauf mit der Test-Datenbank stand bei beiden Datenbanken `2` bei `businesses`.

2. Eine Tabelle mit `0` Zeilen, die vorher Zeilen hatte, ist ein Fehler. Die Tabellen haben Zeilensperren; eine Sicherung als falsche Rolle wird leer. Der Server nimmt dafür `DATABASE_URL` mit der Besitzer-Rolle.
3. Starte den Server mit der neuen Datenbank (`DATABASE_URL` auf die neue Datenbank) und melde Dich an.
4. Die Bilder fehlen nur, wenn die Ablage verloren ging. Bleibt die Ablage bestehen, sind die Fotos wieder da.

## Probelauf

Spiele die Sicherung einmal im Quartal in eine leere Datenbank, auch wenn nichts kaputt ist. Eine Sicherung, die niemand zurückgespielt hat, ist nicht sicher.
