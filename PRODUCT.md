# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Stack

delegated: Niko hat die Technik ausdrücklich abgegeben ("ob Software oder App, weiß ich selbst nicht"). Entschieden wurde gemeinsam: App für Tablets und Kassengeräte plus Verwaltung im Browser. Die App startet auf Android, derselbe Code soll später auch auf iPad und Windows laufen können. Das konkrete Framework wird im Entwurfsdokument festgelegt.

## Users

- **Kassierende im Imbiss oder am Stand** (zum Beispiel Kebabstand). Sie stehen an der Theke, haben oft fettige oder nasse Hände, Kunden warten in der Schlange. Ihr Job: Bestellung antippen, bar oder Karte kassieren, Bon drucken, nächster Kunde.
- **Kellnerinnen und Kellner in großen Restaurants** (spätere Ausbaustufe). Mehrere Geräte, Tische, Stationen wie Küche und Bar.
- **Betreiber des Lokals.** Pflegt Artikel und Preise und sieht Umsätze, meist am PC im Browser.
- **Kunde an der Theke.** Sieht auf der Kundenanzeige, was boniert wurde, und den Gesamtpreis.

## Product Purpose

Kassa ist ein Kassensystem für die Gastronomie in Österreich, das Niko als Produkt an viele unterschiedliche Betriebe verkauft, vom Imbiss bis zum großen Restaurant. Erfolg heißt: Ein Imbiss boniert schneller und mit weniger Geräten als mit seiner alten Windows-Kassa, und derselbe Kern trägt später auch ein Restaurant mit Kellnern und Stationen.

## Positioning

Kartenzahlung in einem Schritt. Der Betrag geht von der Kassa direkt ans SumUp-Terminal, die Bestätigung kommt zurück, der Bon druckt von selbst. Der erste Pilotbetrieb braucht dafür heute ein Extra-Handy, tippt den Betrag doppelt ein und drückt danach in der Windows-Kassa noch einmal auf Kartenzahlung.

## Operating Context

- Theke mit Tablet auf Ständer oder Kassengerät mit zwei Bildschirmen, Bondrucker, Geldlade am Bondrucker, SumUp-Terminal.
- Ablauf Imbiss: Kunde bestellt, es wird boniert, dann bar oder Karte. Bei Barzahlung druckt der Bon und die Geldlade springt auf.
- Internet kann ausfallen. Bar bonieren muss dann weiter funktionieren.
- Österreich: Registrierkassenpflicht nach RKSV (Signatur, Datenerfassungsprotokoll, QR-Code am Beleg).

## Capabilities and Constraints

Version 1 (Imbiss-Modus), mit Niko abgestimmt:

- Artikel als große Tasten, sortiert nach Kategorien
- Extras und Sonderwünsche per Schalter, nie per Tastatur (zum Beispiel "ohne Zwiebel", "extra Käse")
- Auswahlgruppen pro Artikel für Menüs, Beilagenwahl und Baukasten-Artikel wie Bowls oder Sandwiches (zum Beispiel "Beilage, genau 1" oder "Toppings, bis zu 4"). Eine Auswahl wird einmal als Vorlage angelegt und hängt an vielen Artikeln, mit Vorgabe (zum Beispiel Größe Normal) und Aufpreisen pro Option
- Pfand pro Artikel, am Bon getrennt ausgewiesen
- Kennzeichen auf der Taste (zum Beispiel VEGAN, SCHARF) und Stückangaben beim Preis
- Menge ändern, Position löschen, Storno
- Bezahlen bar mit Rückgeldanzeige oder mit Karte über SumUp
- Bon drucken, Geldlade öffnet bei Barzahlung. Die Geldlade ist pro Kassa in den Einstellungen abschaltbar (Betriebe ohne Platz für eine Lade): dann kein Öffnen-Signal, das Bargeld wird beim Tagesabschluss trotzdem gezählt
- Tagesabschluss
- Zuschaltbare Kundenanzeige (zweites Gerät oder eingebauter zweiter Bildschirm)
- Verwaltung im Browser für Artikel, Preise und Umsätze
- Eigenes Konto pro Betrieb, Mitarbeiter melden sich mit PIN an

Nicht in Version 1: Tische, Kellner-Handgeräte, Küchenstationen, Lagerstand, Gutscheine, Online-Bestellungen.

Begriffe: bonieren, Bon, Storno, Tagesabschluss, Geldlade, Kundenanzeige.

Offen: genaues Framework, Fiskalisierungsdienst für die RKSV, steuerliche Behandlung von Pfand am Beleg, welches Kassengerät Niko als Komplettpaket verkauft.

## Brand Commitments

Name: Kassa. Sprache der Oberfläche: Deutsch, österreichische Begriffe. Ab 1.10.0 kann die Bedienung auch Englisch, Chinesisch, Türkisch oder Arabisch (von rechts nach links) wählen; Einrichtung, Kundenbon und Berichte bleiben Deutsch, der Küchenbon hat seine eigene Sprache. Niko hat als Vorbilder Square POS, Clover POS und Toast genannt und ein Foto einer klassischen Kasse gezeigt, bei der Kategorien links, Artikel in der Mitte und der Bon rechts stehen. Dieser Aufbau ist der Ausgangspunkt.

Stil, von Niko am 17.11.2026 über Beispielbilder vorgegeben (Tasty Station, Restroq, DineDash, ByteCaisse): hell, viel Weißraum, weiche weiße Karten mit runden Ecken, eine einzige Akzentfarbe, Produktfotos auf den Artikeltasten. Bunte Tasten pro Kategorie sind damit verworfen. Fotos sind pro Artikel freiwillig, jede Kassa kann zwischen "Mit Bildern" und "Kompakt" umschalten, Artikel ohne Foto bekommen einen ruhigen Platzhalter. Die Kundenanzeige folgt demselben Stil.

Akzentfarbe: Petrol (#0F766E). Niko hat die Wahl am 17.11.2026 abgegeben ("Farbe ist mir egal, es soll einfach angenehm zum Ansehen sein"). Schrift: Figtree. Das Aussehen des Kassenbildschirms hat Niko am selben Tag bestätigt. Noch nicht festgelegt: Logo.

Bereiche der App, als Reiter in der Kopfleiste: Kassa, Bons, Übersicht (Umsatz, Verlauf, Zahlungsarten, meistverkaufte Artikel), Artikel (Schalter und Zahlenfeld, Namen und Fotos nur im Browser) und Abschluss (Tagesabschluss mit Bargeld zählen). Dazu Einstellungen pro Kassa (Geräte, Geldlade, Kundenanzeige, Anzeige).

## Evidence on Hand

Die Speisekarte des ersten Pilotbetriebs liegt seit 17.11.2026 vor (asiatische Küche: 14 Bowls mit gleicher Auswahl aus Größe, Basis, Extra-Topping und Extra-Sauce, dazu Dumplings, Ramen, Sushi, Rolls und 21 Getränke mit Pfand, insgesamt 78 Artikel in 9 Kategorien). Die Entwürfe verwenden diese Karte. Fotos, Favoriten und MwSt-Sätze in den Entwürfen sind Annahmen. Kundenstimmen und Zahlen gibt es noch keine. Preise für Kassa selbst sind nicht festgelegt und dürfen nicht erfunden werden.

## Product Principles

1. Geschwindigkeit an der Theke schlägt alles. Jeder zusätzliche Tipp kostet in der Schlange.
2. Eine Kassa für klein und groß. Der Imbiss sieht nur, was er braucht, das Restaurant schaltet mehr dazu.
3. Vorhandene Geräte weiterverwenden, wo es geht.
4. Die Kassa darf nie stehen, auch nicht ohne Internet.
5. Rechtssicher ohne Zutun des Betriebs.
6. Alles ist für Touch gebaut. An der Theke wird nie auf einer Tastatur getippt, jede Eingabe geht über große Tasten und Schalter.

## Accessibility & Inclusion

Große Tippflächen für eilige und nicht perfekt saubere Finger. Gut lesbar bei grellem Tageslicht am Stand und bei wenig Licht am Abend. Personal mit unterschiedlichen Deutschkenntnissen: kurze, eindeutige Beschriftungen und Zahlen, die man auf einen Blick erfasst.
