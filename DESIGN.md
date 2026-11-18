---
name: Kassa
description: Kassensystem für Imbisse und Stände in Österreich. Hell, ruhig, große Tasten, eine Akzentfarbe (Petrol).
colors:
  accent: "#0F766E"
  accentSoft: "#E7F1F1"
  accentInk: "#0C615A"
  accentSnack: "#A4CBC8"
  ground: "#F3F4F6"
  card: "#FFFFFF"
  fill: "#F1F2F4"
  fill2: "#E7E9ED"
  line: "#E2E5E9"
  ink: "#14171A"
  ink2: "#5B6470"
  solid: "#14171A"
  solidInk: "#FFFFFF"
  onAccent: "#FFFFFF"
  red: "#B42318"
  green: "#15803D"
  warnBg: "#FFF1CC"
  warnInk: "#6B4200"
  veganBg: "#DDF3E4"
  veganFg: "#14592B"
  spicyBg: "#FDE3DF"
  spicyFg: "#A1201A"
  dark-accent: "#0F766E"
  dark-accentSoft: "#173233"
  dark-accentInk: "#9AC5C2"
  dark-accentSnack: "#0D645E"
  dark-ground: "#0E1012"
  dark-card: "#191C20"
  dark-fill: "#22262B"
  dark-fill2: "#2B3036"
  dark-line: "#2C3138"
  dark-ink: "#F2F4F6"
  dark-ink2: "#A3ACB6"
  dark-solid: "#F2F4F6"
  dark-solidInk: "#14171A"
  dark-onAccent: "#FFFFFF"
  dark-red: "#FF8A80"
  dark-green: "#3DBB6E"
  dark-warnBg: "#3D2E00"
  dark-warnInk: "#FFD77A"
  dark-veganBg: "#173B24"
  dark-veganFg: "#B9F0CB"
  dark-spicyBg: "#4A1A16"
  dark-spicyFg: "#FFC9C2"
typography:
  display:
    fontFamily: "Figtree, Roboto, sans-serif"
    fontSize: "60px"
    fontWeight: 800
    lineHeight: 1
    letterSpacing: "-0.03em"
  amount:
    fontFamily: "Figtree, Roboto, sans-serif"
    fontSize: "40px"
    fontWeight: 800
    lineHeight: 1
    letterSpacing: "-0.02em"
    fontFeature: "tnum"
  headline:
    fontFamily: "Figtree, Roboto, sans-serif"
    fontSize: "22px"
    fontWeight: 800
    lineHeight: 1.25
    letterSpacing: "-0.01em"
  title:
    fontFamily: "Figtree, Roboto, sans-serif"
    fontSize: "16px"
    fontWeight: 800
    lineHeight: 1.25
  body:
    fontFamily: "Figtree, Roboto, sans-serif"
    fontSize: "15px"
    fontWeight: 700
    lineHeight: 1.25
  label:
    fontFamily: "Figtree, Roboto, sans-serif"
    fontSize: "13px"
    fontWeight: 600
    lineHeight: 1.25
  tag:
    fontFamily: "Figtree, Roboto, sans-serif"
    fontSize: "10.5px"
    fontWeight: 800
    lineHeight: 1.25
    letterSpacing: "0.04em"
rounded:
  xs: "5px"
  sm: "7px"
  md: "10px"
  lg: "12px"
  xl: "14px"
  xxl: "16px"
  card: "20px"
  pill: "999px"
spacing:
  xxs: "2px"
  xs: "4px"
  sm: "6px"
  md: "8px"
  lg: "10px"
  xl: "12px"
  xxl: "16px"
  huge: "24px"
components:
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.onAccent}"
    rounded: "{rounded.xxl}"
    height: "80px"
  button-solid:
    backgroundColor: "{colors.solid}"
    textColor: "{colors.solidInk}"
    rounded: "{rounded.xxl}"
    height: "80px"
  button-secondary:
    backgroundColor: "{colors.fill}"
    textColor: "{colors.ink}"
    rounded: "{rounded.xxl}"
    height: "72px"
  tab-active:
    backgroundColor: "{colors.accentSoft}"
    textColor: "{colors.accentInk}"
    rounded: "{rounded.lg}"
    height: "44px"
  category-button:
    backgroundColor: "{colors.card}"
    textColor: "{colors.ink}"
    rounded: "{rounded.xl}"
    height: "52px"
  item-tile-image:
    backgroundColor: "{colors.card}"
    textColor: "{colors.ink}"
    rounded: "{rounded.xxl}"
    height: "157px"
  item-tile-compact:
    backgroundColor: "{colors.card}"
    textColor: "{colors.ink}"
    rounded: "{rounded.xl}"
    height: "90px"
  keypad-key:
    backgroundColor: "{colors.card}"
    textColor: "{colors.ink}"
    rounded: "{rounded.xl}"
    height: "56px"
  toast:
    backgroundColor: "{colors.solid}"
    textColor: "{colors.solidInk}"
    rounded: "{rounded.xxl}"
    height: "60px"
---

# Design System: Kassa

Quelle dieses Dokuments ist der freigegebene Bildschirmentwurf (gezeichnet für 1280 × 800, Querformat). Alle Maße sind in dp angegeben, 1 Pixel des Entwurfs ist 1 dp. Werte, die der Entwurf nicht festlegt, sind als "nicht im Entwurf festgelegt" markiert. Die Namen der Farben sind Dart-Namen: `ui/tokens.dart` hat zwei Paletten (hell und dunkel) mit denselben Namen. Im Kopf der Datei tragen die dunklen Werte die Vorsilbe `dark-`, im Code ist das die zweite Palette.

## Overview

**Creative North Star: "Die ruhige Theke"**

Kassa sieht aus wie eine aufgeräumte Theke: heller Grund, weiße weiche Karten, eine einzige Akzentfarbe (Petrol), große Tasten, die man mit nassen oder fettigen Fingern trifft. Der Kassenbildschirm folgt dem Aufbau klassischer Kassen: Kategorien links, Artikel in der Mitte, Bon rechts. Nichts blinkt, nichts lenkt ab. Die Schlange wartet, also gewinnt Geschwindigkeit vor Schmuck.

Farbe zeigt Zustand und Aktion, nie Dekoration. Es gibt keine bunten Tasten pro Kategorie. Produktfotos sind freiwillig; ohne Foto zeigt die Taste einen ruhigen Platzhalter. Zahlen stehen in gleich breiten Ziffern, damit Beträge untereinander sauber ausgerichtet sind.

**Key Characteristics:**
- Eine Akzentfarbe, Petrol (#0F766E), in einer hellen und einer dunklen Ansicht.
- Weiße Karten mit runden Ecken (14 bis 20 dp), 1 bis 1,5 dp feine Linie, kaum Schatten.
- Tippflächen mindestens 48 dp, Hauptaktionen 64 bis 80 dp hoch.
- Schrift Figtree, Gewichte 600, 700, 800. Beträge in Tabellenziffern.
- Kurze Bewegung (120 bis 320 ms) nur, um Zustand zu zeigen.

## Colors

Zwei Paletten mit gleichen Namen. Die helle Ansicht hat einen hellgrauen Grund mit weißen Karten, die dunkle einen fast schwarzen Grund mit dunkelgrauen Karten. Der Akzent bleibt in beiden Ansichten #0F766E. Die Rechenregel für Mischfarben: `color-mix(in srgb, A p%, B)` ist p % von A plus (100 minus p) % von B je Farbkanal, gerundet.

### Akzent

| Token | Hell | Dunkel | Verwendung |
|---|---|---|---|
| `accent` | #0F766E | #0F766E | Hauptaktion "Bar" und "Abschließen", gewählte Tasten (Rand), Mengen-Marke, eingeschalteter Schalter, Eingabefeld-Rand, Fokusring, Balken im Diagramm |
| `accentSoft` | #E7F1F1 | #173233 | Mischung: hell 10 % Akzent auf Weiß, dunkel 24 % Akzent auf Karte. Aktiver Reiter, aktive Kategorie, Foto-Platzhalter, gewählte Extras, Rückgeld-Feld, Zeile in der Bonliste, kurzes Aufleuchten neuer Bon-Zeilen |
| `accentInk` | #0C615A | #9AC5C2 | Mischung: hell 82 % Akzent auf Schwarz, dunkel 42 % Akzent auf Weiß. Schrift und Symbole auf `accentSoft`, Preise auf den Tasten, gewählter Balken |
| `accentSnack` | #A4CBC8 | #0D645E | Mischung: hell 38 % Akzent auf Weiß, dunkel 85 % Akzent auf Schwarz. Nur die Aktion "Rückgängig" im Hinweis (der Hinweis ist in beiden Ansichten umgekehrt dunkel bzw. hell) |
| `onAccent` | #FFFFFF | #FFFFFF | Schrift und Symbole auf `accent` (immer Weiß) |

### Neutral

| Token | Hell | Dunkel | Verwendung |
|---|---|---|---|
| `ground` | #F3F4F6 | #0E1012 | Hintergrund der ganzen App |
| `card` | #FFFFFF | #191C20 | Kopfleiste, Bon-Spalte, Artikeltasten, Karten, Zahlenfeld-Tasten, Eingabefeld |
| `fill` | #F1F2F4 | #22262B | Ruhige Flächen: Plus/Minus, Abbrechen, Komma- und Löschtaste, Status-Pillen, Preisfeld |
| `fill2` | #E7E9ED | #2B3036 | Bahn eines ausgeschalteten Schalters, Grund des Segment-Reglers, leere Balkenspur |
| `line` | #E2E5E9 | #2C3138 | Trennlinien, Kartenränder, Ränder nicht gewählter Tasten |
| `ink` | #14171A | #F2F4F6 | Haupttext |
| `ink2` | #5B6470 | #A3ACB6 | Zweittext: Zusatzzeilen, Stückangaben, nicht aktive Reiter |
| `solid` | #14171A | #F2F4F6 | Aktion "Karte", "Nächster Kunde", Hinweis mit Rückgängig, Kartenanteil im Diagramm (im Entwurf `--dunkel`) |
| `solidInk` | #FFFFFF | #14171A | Schrift auf `solid` (im Entwurf `--dunkel-tinte`) |

### Zustandsfarben

| Token | Hell | Dunkel | Verwendung |
|---|---|---|---|
| `red` | #B42318 | #FF8A80 | "Bon leeren", "Stornieren", Fehlmenge bei Auswahlgruppen, "Ja, stornieren" (Fläche) |
| `green` | #15803D | #3DBB6E | Punkt "verbunden/bereit", Haken bei "Bezahlt" und "Tag abgeschlossen" |
| `warnBg` | #FFF1CC | #3D2E00 | Hinweis "Kein Internet", "Fehlt noch", Gerät mit Problem |
| `warnInk` | #6B4200 | #FFD77A | Schrift und Punkt auf `warnBg` |
| `veganBg` | #DDF3E4 | #173B24 | Marke VEGAN, "Stimmt genau", Pille "Abgeschlossen", Vergleich im Plus |
| `veganFg` | #14592B | #B9F0CB | Schrift auf `veganBg` |
| `spicyBg` | #FDE3DF | #4A1A16 | Marke SCHARF, Pille "Storniert", Rückfrage beim Stornieren |
| `spicyFg` | #A1201A | #FFC9C2 | Schrift auf `spicyBg` |

### Named Rules

**The One Voice Rule.** Petrol ist die einzige Akzentfarbe. Hauptaktionen und gewählte Zustände nutzen sie, alles andere bleibt neutral. Die anderen Akzentfarben im Entwurf (Paprika, Blau, Rot) sind nur Probeansichten und gehören nicht in die App.

**The Both Themes Rule.** Jede Farbe gibt es hell und dunkel. Hartcodierte Farben in Widgets sind verboten, außer `onAccent` (Weiß) und die Schattenfarbe.

**The Never Only Colour Rule.** Zustand wird nie allein durch Farbe gezeigt: ein gewählter Artikel hat Rand und Mengen-Marke, eine gewählte Option hat Haken, ein Schalter hat Position und Farbe.

## Typography

**Schrift:** Figtree (Roboto als Ersatz, danach Systemschrift). Gewichte 600, 700 und 800 (Fließtext in Hinweisen hat im Entwurf kein eigenes Gewicht, also Normalgewicht 400). Grundgröße 16 dp, Zeilenhöhe 1,25. Tabellenziffern (`FontFeature.tabularFigures()`) sind für die ganze App eingeschaltet. Ausnahme: die große Umsatzzahl in der Übersicht (56 dp) nutzt normale Ziffern.

**Character:** Rund, freundlich, gut lesbar auch aus einem Meter Abstand. Schwere Gewichte für Beträge und Titel, mittlere für Fließtext.

### Hierarchy

Abgestufte Skala aus den Größen, die der Entwurf wirklich nutzt:

| Stufe | Größe, Gewicht | Zeilenhöhe, Abstand | Wo |
|---|---|---|---|
| `display` | 60 dp, 800 | 1, -0,03 em | Rückgeld nach dem Bezahlen. Umsatzzahl 56 dp, 800, -0,03 em |
| `amount` | 40 dp, 800 | 1, -0,02 em | Summe im Bon, "Zu zahlen", "Soll" im Abschluss, "Rückgeld" im Bargeldfeld |
| `headlineL` | 32 dp, 800 | -0,02 em | "Tag abgeschlossen", Rest im Abschluss. 30 dp, 800 für "Bezahlt", Eingabefeld des Zahlenfelds (-0,01 em) und Preis im Artikel-Detail (-0,02 em) |
| `headline` | 22 dp, 800 | -0,01 em | Bereichstitel (Bon, Bons, Artikel), Wortmarke "Kassa" (-0,02 em), Betrag im Zusammenstell-Bildschirm |
| `titleL` | 20 dp, 800 | 1,25 | Hauptaktion "Abschließen und Bon drucken", "Nächster Kunde", "Noch nichts boniert". 19 dp, 800 für die Gegeben-Tasten |
| `title` | 16 dp, 800 | 1,25 | Abschnittstitel in Karten (Einnahmen, Zahlungsarten), Namen der Auswahlgruppen. 17 dp, 700 bis 800 für "Rückgängig"-Zeile, "Warte auf Karte", Abbrechen |
| `bodyStrong` | 14,5 dp bis 16 dp, 700 | 1,2 | Artikelname auf der Taste (14,5), Name in der Bon-Zeile (16), Kategorie (14,5, Zeilenhöhe 1,12) |
| `body` | 13 dp bis 15 dp, 600 oder normal | 1,2 bis 1,4 | Zusatzzeile in der Bon-Zeile (13), Beschreibungen (14,5 bis 15), Tab (15, 700) |
| `label` | 12 dp bis 14 dp, 600 bis 700 | 1,25 | Stückangabe "5 Stück" (12, 600), Anzahl in der Kategorie (13, 700), Status-Pille (12,5, 700), Spaltenkopf (12,5, 700) |
| `tag` | 10,5 dp, 800, +0,04 em, Großbuchstaben | | Marken VEGAN und SCHARF auf der Bildtaste. 10 dp auf der kompakten Taste |
| `key` | 24 dp, 700 | | Ziffern im Zahlenfeld |

### Named Rules

**The Tabular Rule.** Alle Beträge, Mengen und Uhrzeiten in Tabellenziffern. Beträge werden deutsch geschrieben: `9,90 €`, mit Punkt bei Tausendern (`1.234,50 €`), das Eurozeichen nach einem Leerzeichen.

**The Three Weights Rule.** Nur 600, 700 und 800. 800 für Beträge und Titel, 700 für Bedienelemente, 600 für Zusatzinformation.

## Layout

Gezeichnet für 1280 × 800 (Querformat, Tablet 10 bis 13 Zoll). Die Fläche ist ein Spaltenaufbau unter einer Kopfleiste.

| Bereich | Maß |
|---|---|
| Kopfleiste | Höhe 60, Innenabstand links 16, rechts 12, Abstand zwischen Elementen 12, unten 1 dp `line` |
| Kategorie-Spalte | Breite 196 (fest), Innenabstand 12 links/oben/unten, 0 rechts, Abstand zwischen Tasten 6 |
| Bon-Spalte | Breite 392 (fest), links 1 dp `line`, Hintergrund `card` |
| Artikelfläche | Rest: 1280 − 196 − 392 = 692 dp, Innenabstand 16 links/rechts |
| Titelzeile der Artikelfläche | Höhe 56 (Kassa), 64 in den anderen Bereichen |
| Artikelraster | 4 Spalten bei 1280, Abstand 10, Zeilenhöhe 157 (mit Bild) oder 90 (kompakt), Innenabstand 8 oben, 16 seitlich und unten. Spaltenbreite ca. 157,5 |
| Bon-Kopf | Höhe 64 |
| Bon-Zeile | Mindesthöhe 64, Innenabstand 6 / 14 / 6 / 8 |
| Summenblock | Innenabstand 14 / 16 / 12, oben 1 dp `line` |
| Zahlleiste (Bar, Karte) | Zwei Tasten je halbe Breite, Abstand 10, Höhe 80, Außenabstand 0 / 12 / 12 |
| Zahlenfeld | 3 Spalten, Abstand 8, Tastenhöhe 56, darüber Eingabefeld Höhe 60 |
| Zusammenstell-Leiste unten | Raster 180 dp (Abbrechen) + Rest ("Auf den Bon"), Abstand 10, Höhe 68, Innenabstand 12 / 16, oben 1 dp `line` |

Andere Bereiche (Bons, Artikel, Abschluss) behalten die Spalte rechts mit 392 dp. Bons und Artikel haben statt der Kategorie-Spalte eine Liste bzw. dieselbe Kategorie-Spalte (196). Übersicht hat zwei Karten, rechts eine feste Spalte von 376 dp, Abstand 16. Einstellungen sind zwei gleich breite Karten, Abstand 16.

**Regel für andere Größen.** Die Kategorie-Spalte (196) und die Bon-Spalte (392) bleiben fest. Die Artikelfläche bekommt mehr oder weniger Spalten (Richtwert: Spaltenbreite um 157, Abstand 10). Zeilenhöhen (157 und 90) bleiben gleich. Die Raster-Spaltenzahl bei bestimmten Breiten ist nicht im Entwurf festgelegt. Ein Hochformat ist nicht vorgesehen.

**Abstandsskala** (aus dem Entwurf): 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 24. Üblich sind 8 (kleine Abstände, Zahlenfeld), 10 (Tastenraster, Zahlleiste), 12 (Innenabstand von Leisten), 16 (Seitenrand), 24 (Karteninnenrand).

## Elevation & Depth

Fast flach. Tiefe entsteht durch Fläche (`card` auf `ground`), feine Linien und, nur in der hellen Ansicht, einen kaum sichtbaren Schatten.

### Shadow Vocabulary

- **Karte** (`0 1px 2px rgba(16,24,40,.06), 0 1px 1px rgba(16,24,40,.03)`): Artikeltasten, Kategorie-Tasten, Karten, Auswahlgruppen. Im Dunkelmodus kein Schatten (`none`).
- **Hinweis** (`0 12px 32px rgba(16,24,40,.28)`): schwebender Hinweis mit Rückgängig.
- **Schalter-Knopf** (`0 1px 3px rgba(16,24,40,.25)`): der weiße Knopf im Schalter.
- **Ring um die Mengen-Marke** (`0 0 0 2px` in `card`, auf der kompakten Taste in `ground`): trennt die Marke vom Foto oder von der Kartenkante.

### Named Rules

**The Flat-By-Default Rule.** Keine Schatten außer den vier oben. Gewählt wird durch Rand und Farbe, nicht durch Höhe.

## Shapes

Weiche, große Rundungen, je größer die Fläche, desto größer die Rundung.

| Token | dp | Wo |
|---|---|---|
| `xs` | 5 bis 6 | Marken VEGAN und SCHARF (6, kompakt 5), Balken-Spitze 4 |
| `sm` | 7 | Haken-Kästchen bei Extras |
| `md` | 10 | Logo-Symbol, Kategorie-Bild, Segment-Knopf, Bon-Zeile (Antippfläche) |
| `lg` | 11 bis 13 | Reiter (12), Plus/Minus (12), Extras (12), Foto auf Bildtaste (11), Segment-Regler außen (13), Preis-Ändern (13) |
| `xl` | 14 | Kategorie-Taste, kompakte Taste, Zahlenfeld-Taste, Gegeben-Taste, Eingabefeld, Auswahloption (12) |
| `xxl` | 16 | Bildtaste, Hauptaktionen, Hinweis, Rückgeld-Feld, Auswahlgruppe, große Karten im Abschluss |
| `card` | 20 | Karten in Bons, Übersicht, Artikel, Abschluss, Einstellungen |
| `pill` | volle Rundung | Status-Pillen (Höhe 26 bis 34), Mengen-Marke (Höhe 28), Schalter (Bahn 16), Mitarbeiter-Knopf (24) |

**Ränder:** 1 dp `line` auf Karten, Leisten und Spalten. 1,5 dp auf Tasten (Rand `line`, gewählt `accent`). 2 dp `accent` am Eingabefeld des Zahlenfelds. 2 dp Rand des Schalter-Haken-Kästchens (aus, `ink2`; an, `accent`). Fokusring (Tastatur oder Schalter-Bedienung): 3 dp `accent`, Abstand 2 dp.

## Components

### Kopfleiste mit Reitern

Höhe 60, `card`, unten `line`. Von links: Logo-Symbol (34 × 34, Rundung 10, `accent`, weißes Symbol 20 dp), Wortmarke "Kassa" (22, 800), Name des Betriebs (15, 600, `ink2`), dann die Reiter, rechts die Status-Pillen, der Mitarbeiter-Knopf und der Einstellungen-Knopf.

- **Reiter** (Kassa, Bons, Übersicht, Artikel, Abschluss): Höhe 44, Innenabstand 14, Rundung 12, Schrift 15 dp 700, Abstand 2. Aktiv: `accentSoft` mit `accentInk`. Nicht aktiv: transparent mit `ink2`. Der Entwurf zeichnet die Höhe 44; die Antippfläche in der App wird auf 48 vergrößert (Hit Slop, siehe Tippflächen).
- **Status-Pille Netz** ("SumUp verbunden", "Drucker bereit"): Höhe 34, Rundung 17, `fill`, Schrift 13 dp 600, grüner Punkt 8 dp. Bei Ausfall eine Pille in `warnBg` mit `warnInk` (Schrift 13, 700): "Kein Internet. Bar bonieren geht weiter."
- **Mitarbeiter-Knopf:** Höhe 48, Rundung 24, Kreis 34 mit Anfangsbuchstabe (`accentSoft`, `accentInk`, 15 dp 800), daneben der Vorname (15, 700).
- **Einstellungen-Knopf:** 48 × 48, Rundung 12. Aktiv `accentSoft`, sonst transparent.

### Kategorie-Taste

Höhe 52, Rundung 14, Innenabstand links 8, rechts 10, Rand 1,5 dp, Schatten Karte. Links ein Bild oder (bei Favoriten) ein Stern-Quadrat (36 × 36, Rundung 10), dann der Name (14,5 dp 700), rechts die Anzahl (13 dp 700, `ink2`).

- **Nicht aktiv:** `card`, Rand `line`, Name `ink`.
- **Aktiv:** `accentSoft`, Rand `accent`, Name `accentInk`.
- **Gedrückt:** auf 97 % verkleinert und 5 % dunkler (siehe Bewegung).

### Artikeltaste mit Bild

Größe aus dem Raster (ca. 157 × 157), Rundung 16, `card`, Rand 1,5 dp, Schatten Karte, Innenabstand 6. Oben ein Foto-Feld (Höhe 80, Rundung 11, `accentSoft`). Ohne Foto steht darin ein Besteck-Symbol (30 dp, `accentInk`, Deckkraft 0,55). Darunter Name (14,5 dp 700, Zeilenhöhe 1,2, Innenabstand 6) und unten eine Zeile mit Preis links (15 dp 800, `accentInk`) und Zusatz rechts (12 dp 600, `ink2`).

- **Marke:** VEGAN (`veganBg` / `veganFg`) oder SCHARF (`spicyBg` / `spicyFg`), oben links im Foto-Feld bei 11 / 11, Höhe 20, Innenabstand 7, Rundung 6, Schrift Tag (10,5 dp 800, +0,04 em).
- **Zusatz:** Stückangabe wie "5 Stück" oder "+ Pfand" (12 dp 600, `ink2`).
- **Im Bon:** Rand `accent` statt `line`, oben rechts bei 11 / 11 eine Mengen-Marke (mindestens 28 × 28, Höhe 28, Rundung 14, `accent`, Weiß 14 dp 800, Ring 2 dp `card`).
- **Nicht im Verkauf:** Taste ist ausgeschaltet (Deckkraft 0,4, nicht antippbar), Preis wird nicht angezeigt, als Zusatz steht "Nicht im Verkauf".
- **Gedrückt:** Maßstab 0,97, Helligkeit 0,95.
- **Ohne Foto-Rückfall:** Die Taste bleibt gleich hoch, der Platzhalter ersetzt das Foto.

### Artikeltaste kompakt

Zeilenhöhe 90, Rundung 14, Innenabstand 11 oben, 12 seitlich, 10 unten. Oben der Name (15 dp 700, Zeilenhöhe 1,15), unten eine Zeile: Preis (15 dp 800, `accentInk`), Marke (Höhe 18, Innenabstand 6, Rundung 5, Schrift 10 dp 800, +0,04 em), Abstand, Zusatz rechts (12 dp 600, `ink2`). Die Mengen-Marke sitzt über der Ecke bei oben −7 / rechts −7 (Größe wie oben, Ring 2 dp in `ground`). Gewählt, ausgeschaltet und gedrückt wie bei der Bildtaste.

### Umschalter Bilder/Kompakt (Segmente)

Regler: Rundung 13, Innenabstand 3, Abstand 2, Hintergrund `fill2`. Knopf: Höhe 44, Innenabstand 14, Rundung 10, Schrift 14 dp 700. Aktiv: `card`, `ink`, Schatten Karte. Nicht aktiv: transparent, `ink2`. Gleiches Muster für Bons-Filter und Zeitraum in der Übersicht. Beschriftung im Kassenbildschirm: "Mit Bildern" und "Kompakt".

### Schalter

Antippfläche 64 × 48, Bahn 52 × 32 (Rundung 16), Knopf 26 × 26 (weiß, Schatten Schalter-Knopf) mit 3 dp Rand zur Bahn, Weg 20 dp nach rechts. Aus: Bahn `fill2`. An: Bahn `accent`. Umschalten 160 ms. Beschriftung links in 15 dp 600 (Zeilen in den Einstellungen und im Artikel-Detail mindestens 56 bzw. 76 dp hoch). Wird für "Im Verkauf", Pfand, Vegan, Scharf und Geräte-Schalter verwendet.

### Bon-Zeile

Mindesthöhe 64, unten 1 dp `line`. Von links: Name (16 dp 700) mit Zusatzzeile darunter (13 dp, `ink2`, z. B. Auswahl oder "5 Stück"), Pfeil nach unten (18 dp) falls Extras vorhanden, Minus-Knopf (44 × 44, Rundung 12, `fill`), Menge (17 dp 800, Breite 24), Plus-Knopf (44 × 44), Zeilenpreis (16 dp 700, rechtsbündig, mindestens 62 dp breit). Die Antippfläche für den Namen ist mindestens 52 dp hoch. Eine neu gelegte Zeile leuchtet 700 ms von `accentSoft` auf transparent.

- **Aufgeklappt:** zeigt zwei Spalten von Extras (Abstand 8). Ein Extra ist ein Schalter-Knopf (mindestens 52 hoch, Rundung 12, Rand 1,5 dp) mit Haken-Kästchen 24 × 24 (Rundung 7). Aus: `card`, Rand `line`. An: `accentSoft`, Rand `accent`, Schrift `accentInk`, Kästchen `accent` mit weißem Haken.
- **Leer:** "Noch nichts boniert" (20 dp 800) und Hilfetext (15, `ink2`).

### Zahlenfeld

3 Spalten, Abstand 8, Tastenhöhe 56, Rundung 14, Schrift 24 dp 700. Anordnung: 1 bis 9, dann Komma, 0, Löschen (Löschen und Komma haben `fill` und keinen Rand, Ziffern `card` mit Rand 1,5 dp `line`). Eingabefeld darüber: Höhe 60, Rundung 14, Rand 2 dp `accent`, Zahl rechtsbündig (30 dp 800), leer als "0 €" in `ink2`. Ziffern: höchstens 4 vor dem Komma, 2 danach. Es gibt nie eine Systemtastatur.

### Hauptaktion

- **Bar** (Zahlleiste links): Höhe 80, Rundung 16, `accent`, Weiß, Schrift 22 dp 800, Symbol 26 dp links neben dem Text, Abstand 10.
- **Karte** (Zahlleiste rechts): wie Bar, aber `solid` mit `solidInk`.
- **Abschließen und Bon drucken**, **Tag abschließen**: Höhe 80, volle Breite, `accent`, 20 dp 800. **Nächster Kunde**, **Zur Kassa**: Höhe 80, `solid`.
- **Abbrechen** (in der Karten-Ansicht): Höhe 64, `fill`, 17 dp 700. Im Zusammenstellen Höhe 68, Preis-Dialog 72.
- **Bons-Knöpfe:** Drucken und Stornieren, Höhe 72, Rundung 16, 16 dp 700. Stornieren hat Rand 1,5 dp `line` und `red`.
- **Rückfrage Stornieren:** Fläche `spicyBg` mit Text `spicyFg`, zwei Knöpfe, Höhe 60, Rundung 14. "Ja, stornieren" in `red` mit `card` als Schrift.
- **Ausgeschaltet:** Deckkraft 0,4. Beim Zahlen auf Karte ohne Internet ist Karte ausgeschaltet, Bar bleibt.
- **Gedrückt:** Maßstab 0,97, Helligkeit 0,95.
- **Gegeben-Tasten (Bargeld):** 3 Spalten, Abstand 8, Höhe 66, Rundung 14, 19 dp 800. "Passend" und Scheine. Gewählt: `accent` mit Weiß. Sonst `card` mit Rand `line`.
- **Anderer Betrag:** Höhe 60, `fill`, 17 dp 700 mit Symbol.
- **Rückgeld-Feld:** Fläche `accentSoft` (Text `accentInk`, Zahl 40 dp 800). Wenn der gegebene Betrag zu klein ist: `warnBg` mit `warnInk`, Beschriftung "Fehlt noch". Dann ist "Abschließen" ausgeschaltet.

### Hinweis mit Rückgängig

Schwebt unten mittig in der Artikelfläche (unten 20), Höhe 60, Rundung 16, `solid` mit `solidInk`, Schatten Hinweis, Schrift 16 dp 700. Links der Text ("Bon geleert"), rechts der Knopf "Rückgängig" (Höhe 48, Rundung 12, `accentSnack`, 16 dp 800). Erscheint in 220 ms von unten (12 dp) und mit Einblenden. Bleibt 7 Sekunden stehen. Statt Rückfrage vor jedem Löschen: ausführen und Rückgängig anbieten.

### Status-Pille

Höhe 26 (in Listen) oder 30 (Abschluss, Geräte), Innenabstand 10, volle Rundung, Schrift 12,5 dp 700. Zahlungsart "Bar" oder "Karte": `fill` mit `ink`. "Storniert": `spicyBg` mit `spicyFg`. "Abgeschlossen": `veganBg` mit `veganFg`. Gerät in Ordnung: `fill`, `ink`, grüner Punkt (8 dp). Gerät mit Problem: `warnBg`, `warnInk`, Punkt `warnInk`.

### Weitere Muster

- **Bonliste:** Karte (Rundung 20), Zeilen 60 hoch, 1 dp `line` dazwischen, Nummer (15 dp 800, Breite 58), Uhrzeit (14 dp 600, Breite 46), Inhalt einzeilig mit Auslassung, Pille, Betrag rechts (16 dp 800, Breite 78, durchgestrichen bei Storno). Gewählte Zeile `accentSoft`.
- **Artikelliste (Bereich Artikel):** Zeilen 64 hoch, Bild 44 × 44 (Rundung 12), Name 15 dp 700, Preis 16 dp 800 (Breite 84), Stern-Knopf 48 × 48, Schalter in Spalte 72 dp breit.
- **Auswahlgruppe beim Zusammenstellen:** Karte (Rundung 16, Rand 1 dp `line`), Kopf 36 hoch mit Name (16 dp 800), Hinweis (13 dp 600), Status rechts (13 dp 800, bei Fehlmenge `red`). Optionen: Höhe 52, Rundung 12, Rand 1,5 dp, Name 14 dp 700, Aufpreis 12,5 dp 600. Gewählt: `accentSoft`, Rand `accent`, Haken-Kreis 18 dp oben rechts bei 5 / 5. Die Taste "Auf den Bon" ist `accent`, solange etwas fehlt `fill` mit `ink2` und der Text "Noch wählen: ...".
- **Warte auf Karte:** Karte `accentSoft` mit pulsierendem Punkt (14 dp, `accent`), Titel 17 dp 800, Hinweis 14,5 dp.
- **Bezahlt:** Kreis 64 dp `green` mit Haken, Titel 30 dp 800, Rückgeld-Karte `accentSoft` mit Zahl 60 dp.
- **Summenblock:** "Summe" (16 dp 700) links, Betrag 40 dp 800 rechts. Darunter links "davon Pfand" und rechts "inkl. MwSt" (13 dp, `ink2`).

## Motion

Bewegung zeigt nur Zustand, nie Dekoration. Dauer 120 bis 320 ms, Kurve `cubic-bezier(.2, .8, .2, 1)` (schneller Start, weiches Ende), Farbübergänge linear.

| Wo | Dauer |
|---|---|
| Druck auf Taste (Maßstab 0,97, Helligkeit 0,95) | 120 ms |
| Farbwechsel Rand und Fläche (Taste, Zeile) | 120 ms, linear |
| Schalter (Bahn und Knopf) | 160 ms |
| Pfeil in der Bon-Zeile dreht sich | 160 ms |
| Artikelfläche wird beim Bezahlen halb ausgeblendet (Deckkraft 0,5) | 180 ms |
| Hinweis erscheint | 220 ms |
| Balken im Diagramm wachsen | 320 ms |

Zwei Animationen im Entwurf sind länger und sind keine Übergänge, sondern Zustandsanzeigen: das Aufleuchten einer neuen Bon-Zeile (700 ms, einmal) und das Pulsieren des Punkts bei "Warte auf Karte" (1,2 s, Schleife, Deckkraft 1 bis 0,3). Beides läuft nie länger, als der Zustand dauert.

**Reduzierte Bewegung.** Wenn das System "Animationen reduzieren" meldet (`MediaQuery.disableAnimations`), entfallen Druck-Übergänge, Aufleuchten, Pulsieren und Einblenden des Hinweises (der Hinweis erscheint sofort). Zustände bleiben an Farbe, Rand und Haken erkennbar.

**Keine Wartezeit.** Die Kassa reagiert auf Tippen sofort (unter 400 ms). Bewegung darf nie ein Tippen verzögern.

## Tippflächen

- Mindestens 48 dp, Hauptaktionen 64 bis 80 dp hoch.
- Abstand zwischen Tippflächen mindestens 6 dp.

Maße, die der Entwurf tatsächlich zeichnet:

| Element | Höhe (Breite) |
|---|---|
| Bar, Karte | 80 |
| Abschließen, Tag abschließen, Nächster Kunde, Zur Kassa | 80 |
| Bons-Knöpfe Drucken, Stornieren | 72 |
| Zusammenstellen: Abbrechen, Auf den Bon | 68 |
| Abbrechen bei Kartenzahlung | 64 |
| Gegeben-Tasten | 66 |
| Anderer Betrag, Storno-Rückfrage | 60 |
| Eingabefeld des Zahlenfelds | 60 (keine Tippfläche) |
| Zahlenfeld-Taste | 56 |
| Artikeltaste mit Bild | 157 (ca. 157 breit) |
| Artikeltaste kompakt | 90 |
| Kategorie-Taste | 52 |
| Auswahloption, Extra in der Bon-Zeile | 52 |
| Bon-Zeile | mindestens 64 (Name-Fläche 52) |
| Mitarbeiter-Knopf, Einstellungen-Knopf, Stern-Knopf, Hinweis-Knopf | 48 (Einstellungen und Stern 48 breit) |
| Schalter | 48 (64 breit), Bahn 32 × 52 |
| Reiter | 44 |
| Segmente (Mit Bildern, Kompakt) | 44 |
| Plus und Minus in der Bon-Zeile | 44 × 44 |
| "Vorschläge zeigen", "Bon leeren" | 44 und 48 |

**Abweichung vom Ziel.** Reiter, Segmente und Plus/Minus sind im Entwurf 44 dp hoch, "Vorschläge zeigen" ebenfalls. Die App erreicht die 48 dp mit Hit Slop: die Antippfläche wird unsichtbar auf 48 dp erweitert, das Aussehen bleibt gleich. Das Gleiche gilt für die Status-Pillen (34 und 26 dp), die nur anzeigen und nicht angetippt werden.

## Icons

Der Entwurf zeichnet Symbole als eingebettetes SVG (24er Raster, Linie, runde Enden). Die App nutzt dafür die Lucide-Symbole (Strichstärke 2, in der Kopfleiste 2,2 bis 2,4; so zeichnet es der Entwurf). Zuordnung:

| Symbol im Entwurf | Lucide | Wo | Größe |
|---|---|---|---|
| Beleg mit zwei Zeilen | `receipt` | Logo in der Kopfleiste | 20 |
| Stern | `star` | Kategorie Favoriten, Favoriten-Knopf im Artikelbereich (gefüllt bei an) | 20 und 24 |
| Regler | `sliders-horizontal` | Einstellungen-Knopf | 24 |
| Pfeil nach unten (Winkel) | `chevron-down` | Bon-Zeile aufklappen | 18 |
| Minus | `minus` | Bon-Zeile weniger | 18 |
| Plus | `plus` | Bon-Zeile mehr | 18 |
| Geldschein | `banknote` | Aktion Bar | 26 |
| Karte | `credit-card` | Aktion Karte | 26 |
| Taschenrechner | `calculator` | "Anderer Betrag" | 22 |
| Rückwärts-Löschen (Pfeil mit X) | `delete` | Löschtaste im Zahlenfeld | 26 |
| Pfeil nach links (Winkel) | `chevron-left` | Zurück zum Bon aus Bar-Ansicht | 24 |
| Haken | `check` | Extra an, Option gewählt, Bezahlt, Tag abgeschlossen | 11 bis 34 |
| Pfeil nach oben | `arrow-up` | Vergleich in der Übersicht (Umsatz) | 16 |
| Drucker | `printer` | Bons: "Drucken" | 22 |
| Messer und Gabel | `utensils` | Platzhalter, wenn ein Artikel kein Foto hat (Deckkraft 0,55) | 19 bis 39 |

Symbole sind Beiwerk. Jeder Knopf mit Symbol hat eine Beschriftung oder ein semantisches Label (Screenreader), Symbole allein tragen nie Bedeutung außer Plus, Minus, Löschen und Zurück.

## Verwaltung im Browser

Die Verwaltung (`web/`) ist ein Werkzeug für Maus, Tastatur und Handy. Sie nutzt dieselben Farben, dieselbe Schrift und dieselben Radien wie die App, als CSS-Variablen in `web/src/styles/tokens.css` (Namen wie in `ui/tokens.dart`, in Bindestrich-Schreibweise: `accentSoft` heißt `--accent-soft`). Hier darf getippt werden, darum gibt es Eingabefelder.

- **Farben:** beide Paletten aus "Colors", helle und dunkle Ansicht nach Systemeinstellung (`prefers-color-scheme`), dieselben Namen in beiden. Petrol nur für Hauptaktion, aktiven Bereich und Fokus. Schatten "Karte" nur hell.
- **Schrift:** Figtree aus `web/public/fonts/` (Kopie von `app/assets/fonts/`, nie von einer fremden Adresse), Gewichte 600, 700, 800. Tabellenziffern auf der ganzen Seite. Fließtext 15 px 600, Beschriftungen 14 px 700, Seitentitel 26 px 800 (unter 640 px 22 px), Titel in Karten 24 px 800.
- **Radien:** Bedienelemente von 44 px (Knöpfe, Eingabefelder, Bereiche) `lg` 12, Hinweis `xxl` 16, Karten und Dialog `card` 20.
- **Umbruchstellen:** 640 und 1024 px. Ab 1024 px eine Seitenleiste (248 px, `card`, rechts 1 px `line`) mit Logo, Bereichen und dem Konto unten. Darunter oben eine Kopfzeile (56 px) mit Logo und "Abmelden" und unten eine Leiste (64 px) mit den Bereichen, jeweils mit Abstand für die Ränder des Telefons (`env(safe-area-inset-*)`). Seitenrand 16 px, ab 640 px 24 px, ab 1024 px 40 px. Ab 360 px Breite gibt es kein waagrechtes Scrollen.
- **Eingabefelder:** 44 px hoch, Beschriftung darüber (immer sichtbar, nie nur als Platzhalter), Rand 1,5 px `line`, Hinweis oder Meldung darunter (13 px). Eine Meldung steht in `red` mit Symbol am Feld, nie nur als Farbe, und sagt, was zu tun ist. Meldungen, die zu keinem Feld gehören, stehen über dem Knopf auf `spicyBg` mit `spicyFg`.
- **Knöpfe:** 44 px hoch (Hauptaktion eines Formulars 48 px), vier Arten: `primary` (`accent`), `secondary` (`fill`), `danger` (`card`, Rand `line`, Schrift `red`, wie "Stornieren"), `quiet` (durchsichtig, `ink2`). Beschäftigt zeigt ein Knopf einen Kreis und behält seine Breite.
- **Tippflächen:** mindestens 44 px.
- **Fokusring:** 2 px Petrol mit 2 px Abstand, bei Tastatur-Bedienung an jedem Bedienelement; ein Eingabefeld zeigt ihn, solange es den Fokus hat.
- **Listen** werden unter 640 px zu Karten (eine Karte pro Zeile), damit nichts seitlich scrollt.
- **Laden und leer:** Platzhalter in der Form des späteren Inhalts (Skeleton), kein Kreisel mitten im Inhalt. Eine leere Liste sagt, was als Nächstes zu tun ist.
- **Löschen** heißt stilllegen, danach ein Hinweis mit "Rückgängig" (wie "Hinweis mit Rückgängig", 7 Sekunden), statt vorher zu fragen. Ein Dialog nur, wo etwas nicht rückgängig zu machen ist; unter 640 px kommt er als Blatt von unten.
- **Bewegung:** 120 bis 320 ms mit derselben Kurve wie die App, nur für Zustand (Druck 120 ms, Farbe 120 ms, Hinweis und Dialog 220 ms). Bei `prefers-reduced-motion` aus.
- **Sicherheit:** keine Schrift, kein Skript, kein Stil von fremden Adressen und nichts eingebettet (`Content-Security-Policy: default-src 'self'`). Stile kommen nur als CSS-Module aus dem Bau, nie als `style`-Attribut im HTML.

## Do's and Don'ts

### Do:
- **Do** Petrol (`accent`) nur für Hauptaktionen, gewählte Zustände und die Mengen-Marke einsetzen.
- **Do** Beträge in Tabellenziffern setzen und deutsch schreiben (`9,90 €`).
- **Do** Hauptaktionen 64 bis 80 dp hoch machen und alle Tippflächen mindestens 48 dp (Hit Slop, wo das Aussehen kleiner ist).
- **Do** Löschen und Stornieren mit Rückgängig anbieten statt mit Rückfrage, wo der Entwurf es so zeigt (Bon leeren). Stornieren eines abgeschlossenen Bons braucht die Rückfrage.
- **Do** beide Ansichten (hell und dunkel) mit denselben Token-Namen bauen.
- **Do** bei fehlendem Internet "Karte" ausschalten und "Bar" offen lassen.

### Don't:
- **Don't** bunte Tasten pro Kategorie verwenden. Verworfen.
- **Don't** eine Systemtastatur an der Theke öffnen. Alles läuft über Tasten, Schalter und das Zahlenfeld.
- **Don't** Schatten oder Verläufe zur Dekoration setzen.
- **Don't** Zustand nur über Farbe zeigen.
- **Don't** Bewegung länger als 320 ms für Übergänge einsetzen oder bei reduzierter Bewegung beibehalten.
- **Don't** Gewichte außer 600, 700, 800 verwenden.
