# Kassa Website

Die Seite, mit der Kassa Betrieben gezeigt wird. Eine einzige Seite, ohne Server, ohne Tracking, ohne fremde Schriften.

## Aufbau

- `src/page.html` ist die Quelle (Stil, Inhalt, Skript in einer Datei).
- `build.mjs` setzt die Symbole ein (Phosphor, Schnitt bold, über `{{i:name}}`) und schreibt `index.html`.
- `fonts/` Figtree als woff2 (aus `app/assets/fonts`), `img/` Fotos und Bildschirmfotos (Quellen in `img/QUELLEN.md`).

## Bauen

```
npm install
node build.mjs                 # schreibt index.html
node build.mjs vorschau.html   # zusätzlich eine Fassung mit eingebetteter Schrift für die Vorschau
```

Zum Hosten reichen `index.html`, `fonts/` und `img/`.

## Gestaltung

Die Seite ist wie der Kassenbildschirm gebaut: Kategorien links, Inhalt in der Mitte, Bon rechts. Farben, Schrift und Rundungen kommen aus `DESIGN.md`. Ganz oben ist eine kleine Kassa zum Antippen (Bestellung, Bar oder Karte, Bon).

## Online

Die Seite läuft als eigener Dienst `kassa-website` im Railway-Projekt `kassa` (Ordner `website/`, `Dockerfile` mit Caddy, liefert nur `index.html`, `fonts/` und `img/` aus). Der Dienst ist auf einen Commit festgelegt: ein Push stellt nichts online, ausgerollt wird bewusst.

## Noch offen

- Telefon und E-Mail im Abschnitt Kontakt (dort steht "folgt in Kürze").
- Impressum und Datenschutz.
- Solange das fehlt, steht im Kopf `<meta name="robots" content="noindex">`, damit Suchmaschinen die Seite noch nicht aufnehmen.
- Preise stehen bewusst keine auf der Seite.
