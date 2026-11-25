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

## Noch offen (Platzhalter)

- Telefon und E-Mail im Abschnitt Kontakt (`+43 660 000 00 00`, `hallo@kassa.example`).
- Impressum und Datenschutz.
- Preise stehen bewusst keine auf der Seite.
