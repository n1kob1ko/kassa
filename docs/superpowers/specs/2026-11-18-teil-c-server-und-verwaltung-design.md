# Kassa Teil C: Server und Verwaltung im Browser

Stand: 18.11.2026. Entwurf von Claude, Freigabe durch Niko steht aus.

Dieses Dokument ergänzt den Hauptentwurf `2026-11-17-kassa-design.md` (dort die Abschnitte 5.1, 5.5, 5.9, 5.10, 5.12, 5.13 und 5.14). Wo sich beide widersprechen, gilt für Teil C dieses Dokument. Alles, was hier nicht steht, gilt weiter wie im Hauptentwurf, in `PRODUCT.md`, `DESIGN.md` und `docs/design-regeln.md`.

## 1. Worum es geht

Bis jetzt lebt Kassa auf einem einzigen Tablet. Das hat fünf Folgen, die Teil C behebt:

1. Geht das Tablet kaputt oder verloren, sind Bons und Speisekarte weg.
2. Namen, Fotos und neue Artikel lassen sich nur über eine Datei ändern, die Claude von Hand schreibt.
3. Fehler am Tablet muss Niko abtippen oder fotografieren, damit Claude sie sieht.
4. Die Installationsdatei mit dem SumUp-Schlüssel hat keinen privaten Weg zu Niko, weil das Repo öffentlich ist.
5. Ein zweiter Betrieb lässt sich nicht einrichten.

Niko am 18.11.2026: nach Teil B kommen Server und Browser-Verwaltung, danach die RKSV-Signatur. Die Verwaltung für den Chef rückt damit vor die Signatur. Im Hauptentwurf stand sie in Schritt 4.

**Erfolg heißt:** Niko meldet sich im Browser an, legt YICHI aus der Speisekarten-Datei an, erzeugt einen Code und tippt ihn am Tablet ein. Danach kommen Speisekarte, Mitarbeiter und Fotos vom Server, und jeder Bon liegt kurz nach dem Kassieren auch am Server. Ändert der Chef im Browser einen Preis, gilt er wenig später an der Kassa. Fällt das Internet aus, merkt man an der Theke nichts, außer dass Karte gesperrt ist.

## 2. Ziele, Nicht-Ziele, Anti-Ziele

**Ziele**

- Ein Server bei Railway, der die Daten aller Betriebe getrennt hält.
- Anmeldung im Browser mit E-Mail und Passwort. Zwei Rollen: Anbieter (Niko, alle Betriebe) und Chef (ein Betrieb).
- Anbieter: Betrieb aus der Speisekarten-Datei anlegen und neu einspielen, Chef-Zugang anlegen.
- Kassa koppeln: Code in der Verwaltung erzeugen, am Tablet über das Zahlenfeld eingeben.
- Abgleich: Speisekarte, Mitarbeiter, Betriebsdaten und Fotos kommen vom Server aufs Tablet. Bons, Zahlungen, Tage und Bargeld-Bewegungen gehen vom Tablet zum Server. Änderungen an Artikeln gehen in beide Richtungen.
- Fehlerberichte und Ergebnisse von "Geräte testen" gehen an den Server.
- Die Installationsdatei kommt über einen geheimen Link vom Server.
- Verwaltung für den Chef: Artikel, Kategorien, Auswahl-Vorlagen, Preise, Fotos, Mitarbeiter und PINs, Kassen, Bons, Umsätze, Tagesabschlüsse, Betriebsdaten und Logo.

**Nicht-Ziele von Teil C** (bewusst später)

- KI-Vorschlag aus der Speisekarte als PDF, Fotos in einem Schwung zuordnen (Schritt 4 des Hauptentwurfs).
- Kundenanzeige.
- RKSV: Signatur, Protokoll, Ausgabe des Protokolls.
- Logo am gedruckten Bon. Das Drucken von Bildern ist an keinem echten Drucker geprüft. Das Logo erscheint in Teil C in der Kopfleiste der Kassa und am Anmeldebildschirm.
- Selbstanmeldung von Betrieben, Abo-Abrechnung, E-Mail-Versand (auch "Passwort vergessen" per E-Mail), eigene Internet-Adresse.
- Sofortige Übertragung in Echtzeit. Der Abgleich läuft in kurzen Abständen.
- Einstellungen der Kassa (Drucker, Geldlade, Ansicht) vom Server aus ändern. Sie bleiben am Tablet.
- Mehrere Kassen in einem Betrieb als geprüfter Fall. Die Daten lassen es zu, getestet und zugesagt wird es mit dem Restaurant-Modus.
- Updates über den Google Play Store.

**Anti-Ziele**

- Die Kassa wartet an der Theke nie auf den Server. Einzige Ausnahme ist das Koppeln selbst.
- Der Server ändert oder löscht nie einen Bon.
- Kein Betrieb sieht je Daten eines anderen.
- Zugangsdaten, Schlüssel und Daten von Betrieben stehen nie im Repo (Ausnahme laut Niko: Name und Speisekarte von YICHI).
- Am Tablet wird weiter nichts getippt. Der Kopplungscode besteht nur aus Ziffern.

## 3. Rahmenbedingungen

- **Railway**, in Nikos Konto, neues Projekt "kassa" (von Niko am 18.11.2026 freigegeben, Preis vorher nennen). Region in der EU. Die vier vorhandenen Projekte werden nicht angefasst.
- **Geheimnisse** (Datenbank-Zugang, Zugang zur Ablage, Einmal-Schlüssel) liegen nur in den Variablen des Railway-Projekts.
- **Claude hat kein Gerät in der Hand.** Der Server wird mit einer echten PostgreSQL-Datenbank getestet, die in der Bau-Umgebung läuft. Das Zusammenspiel von App und Server wird ohne Tablet getestet (siehe 5.13).
- **Die App ist übergeben.** Jede Änderung an der Datenbank am Tablet braucht eine Migration mit Test. Der Test-Schlüssel der Installationsdatei bleibt derselbe.
- **Die Bau-Umgebung** erreicht den Server erst, wenn Niko die Adresse freischaltet (`*.up.railway.app`).
- **Niko ist kein Entwickler.** Was er freigibt, bekommt er in einfachen Worten und als Bild.

## 4. Wege, die zur Wahl standen

Niko hat die Technik abgegeben. Die Wahl ist Claudes Entscheidung.

**Abgleich zwischen Tablet und Server**

| Weg | Was es wäre | Abwägung |
|---|---|---|
| **1** | **Eigener, schlanker Abgleich: Das Tablet führt eine Liste "noch zu senden". Der Server zählt jede Änderung an der Speisekarte durch, das Tablet fragt "was ist neu seit Nummer X?".** | **Gewählt.** Wenig Teile, jede Regel für Geld-Daten liegt bei uns und ist testbar. Bons gehen nur in eine Richtung und ändern sich nie, das macht den Abgleich einfach. Preis: selbst zu bauen und zu testen. |
| 2 | Fertiger Abgleich-Dienst (zum Beispiel PowerSync oder ElectricSQL) | Weniger eigener Code, aber ein weiterer Dienst mit eigenen Kosten, und die Regeln bei gleichzeitigen Änderungen liegen nicht mehr bei uns. Zu viel für Daten, die fast nur in eine Richtung fließen. |
| 3 | Tablet arbeitet direkt auf dem Server | Verworfen. Ohne Internet stünde die Kassa. |

**Zuschnitt des Servers**

| Weg | Abwägung |
|---|---|
| **Ein Dienst liefert die Schnittstelle für Tablets und die Seiten der Verwaltung** | **Gewählt.** Eine Auslieferung, eine Adresse, einfache Anmeldung, geringste Kosten. |
| Schnittstelle bei Railway, Seiten getrennt (zum Beispiel Netlify) | Zwei Auslieferungen, Anmeldung über zwei Adressen ist heikler. Bringt bei dieser Größe nichts. |

**Trennung der Betriebe**

| Weg | Abwägung |
|---|---|
| **Jede Tabelle trägt den Betrieb, jede Abfrage ist darauf beschränkt, und die Datenbank selbst sperrt zusätzlich (Row Level Security)** | **Gewählt.** Vergisst der Code einmal die Einschränkung, liefert die Datenbank trotzdem nichts Fremdes. |
| Nur der Code schränkt ein | Eine vergessene Bedingung zeigt fremde Umsätze. |
| Eigene Datenbank pro Betrieb | Stärkste Trennung, aber jeder neue Betrieb wäre ein eigener Aufbau. Zu schwer für den Anfang. |

**Verwaltung im Browser**

| Weg | Abwägung |
|---|---|
| **Eine Web-Anwendung von Anfang an im endgültigen Stil, die in Stufen wächst** | **Gewählt.** Seit Niko die Verwaltung vorgezogen hat, wäre eine schlichte Wegwerf-Seite doppelte Arbeit. |
| Erst schlichte Anbieter-Seite ohne Entwurf, später neu (Hauptentwurf 5.10) | War richtig, solange die Verwaltung erst in Schritt 4 kam. |

## 5. Was gebaut wird

### 5.1 Teile und Ordner

Das Repo bekommt zwei Ordner neben `app/`:

- `server/`: der Server. TypeScript auf Node, Datenbank PostgreSQL.
- `web/`: die Verwaltung. TypeScript mit React. Sie wird beim Bau zu festen Dateien, die der Server ausliefert.

Bei Railway sind es ein Dienst (der Server mit den Seiten), eine PostgreSQL-Datenbank und eine Ablage für Dateien (Fotos, Logos, Installationsdateien).

Adressen am Server: `/api/auth/...` für die Anmeldung im Browser, `/api/admin/...` für die Verwaltung, `/api/device/...` für Tablets, `/laden/...` für die Installationsdatei, `/healthz` für die Betriebsprüfung, alles andere sind die Seiten der Verwaltung.

### 5.2 Stufen

Jede Stufe bekommt einen eigenen Umsetzungsplan und endet mit etwas, das Niko ausprobieren kann.

| Stufe | Inhalt | Was Niko danach ausprobiert |
|---|---|---|
| **C1** Server, Anmeldung, Kopplung | Server-Grundgerüst mit Trennung der Betriebe, Anmeldung, Betrieb aus Datei anlegen, Mitarbeiter und PINs, Kopplungscode, Tablet koppeln und Speisekarte, Mitarbeiter, Betriebsdaten holen, Installationsdatei über geheimen Link, Auslieferung bei Railway | Im Browser anmelden, YICHI anlegen, Code erzeugen, Tablet koppeln, mit der PIN aus der Verwaltung anmelden. Die Installationsdatei mit SumUp-Schlüssel kommt über den geheimen Link. |
| **C2** Abgleich | Bons, Zahlungen, Tage, Bargeld-Bewegungen zum Server. Artikel-Änderungen in beide Richtungen. Fotos und Logo aufs Tablet. Fehlerberichte. Nächtliche Sicherung der Datenbank. | Bonieren und den Bon im Browser sehen. Preis im Browser ändern und am Tablet sehen, und umgekehrt. Foto hochladen und auf der Artikel-Taste sehen. Ohne Internet bonieren, Internet wieder an, alles kommt nach. |
| **C3** Verwaltung für den Chef | Die gestalteten Seiten aus 5.10, Chef-Zugang | YICHI vollständig im Browser pflegen und die Umsätze ansehen. |
| **C4** Kartenzahlung nachschlagen | Der Server fragt bei SumUp nach, ob eine unklare Kartenzahlung durchging | Unklare Zahlung klärt sich von selbst. |

Die Bildschirme der Verwaltung (C3) bekommt Niko als Bilder zur Freigabe, bevor C3 gebaut wird. C4 braucht einen Zugangsschlüssel zur SumUp-Schnittstelle des Betriebs und wird erst geplant, wenn Claude die Schnittstelle geprüft hat (siehe 7).

In C1 und C2 gibt es von der Verwaltung schon die Seiten, die für die Stufe nötig sind (Anmelden, Betriebe, Mitarbeiter, Kassen, Installationsdateien, in C2 dazu Bons und Fehlerberichte als einfache Listen). Sie tragen von Anfang an Farben, Schrift und Abstände aus `DESIGN.md`.

### 5.3 Konten und Anmeldung im Browser

- **Rollen:** Anbieter (Niko) sieht und pflegt alle Betriebe. Chef sieht und pflegt genau einen Betrieb. Mitarbeiter haben keinen Zugang zur Verwaltung.
- **Anmeldung** mit E-Mail und Passwort. Das Passwort hat mindestens 10 Zeichen, sonst keine Regeln. Es wird nur als Prüfwert gespeichert, mit einem Verfahren, das für Passwörter gemacht ist.
- **Sitzung:** Nach der Anmeldung setzt der Server ein Cookie, das die Seite selbst nicht lesen kann und das nur über eine verschlüsselte Verbindung geht. Eine Sitzung gilt 30 Tage ab der letzten Benutzung. "Abmelden" beendet sie sofort.
- **Fehlversuche:** Nach 5 falschen Passwörtern für dieselbe E-Mail wächst die Wartezeit (1, 2, 4 Minuten, höchstens 15).
- **Erstes Anbieter-Konto:** Es gibt keine Selbstanmeldung. Der Server kennt einen Einmal-Schlüssel aus den Railway-Variablen. Niko öffnet einen Link mit diesem Schlüssel und trägt dort seine E-Mail und sein Passwort selbst ein. Claude sieht das Passwort nie. Jeder Schlüssel gilt genau einmal. Vergisst Niko sein Passwort, setzt Claude einen neuen Schlüssel und schickt den neuen Link.
- **Chef-Zugang:** Der Anbieter legt ihn mit der E-Mail des Chefs an und bekommt einen Link, der 7 Tage gilt. Der Chef setzt darüber sein Passwort. Derselbe Weg dient als "Passwort vergessen".
- **Wer im Betrieb arbeitet:** Die Seiten eines Betriebs liegen unter `/b/<Betrieb>/...`. Der Chef landet nach der Anmeldung in seinem Betrieb. Der Anbieter landet in der Liste der Betriebe und geht von dort hinein.

### 5.4 Kopplung

- In der Verwaltung unter "Kassen": "Kassa koppeln" fragt nach einem Namen (Vorgabe "Kassa 1") und zeigt einen **Code aus 8 Ziffern**, der 15 Minuten gilt und genau einmal verwendet werden kann.
- Am Tablet wird der Code über das Zahlenfeld eingegeben. Der Server antwortet mit der Kennung der Kassa und einem geheimen Geräte-Schlüssel. Das Tablet legt ihn im geschützten Speicher von Android ab. Der Server speichert davon nur einen Prüfwert.
- Jede Anfrage des Tablets trägt den Geräte-Schlüssel. Daraus kennt der Server Kassa und Betrieb. Das Tablet schickt nie selbst eine Betriebs-Kennung, der der Server glauben müsste.
- **Sperren:** In der Verwaltung lässt sich eine Kassa sperren, zum Beispiel wenn das Tablet verloren geht. Solange sie gesperrt ist, nimmt der Server von ihr nichts an und gibt ihr nichts. Das Tablet zeigt in den Einstellungen "Diese Kassa wurde in der Verwaltung gesperrt". Bonieren geht weiter, weil die Kassa nie stehen bleiben darf. Was in dieser Zeit boniert wird, wartet am Tablet.
- **Sperre aufheben:** Die Sperre lässt sich in der Verwaltung wieder aufheben. Derselbe Geräte-Schlüssel gilt dann wieder, und alles, was gewartet hat, wird nachgesendet.
- **Falsche Codes:** Höchstens 10 Versuche in 15 Minuten von derselben Internet-Adresse.
- **Adresse des Servers:** Sie wird beim Bau der Installationsdatei eingesetzt (Datei `server.properties` neben `sumup.properties` im Projekt-Ordner, nicht im Repo). Fehlt sie, bricht der Bau ab, außer mit `KASSA_ALLOW_NO_SERVER=1`. Eine so gebaute App zeigt statt der Kopplung "Diese Version hat keinen Server".

**Ein schon eingerichtetes Tablet koppeln** (Nikos Redmi Pad mit der YICHI-Karte aus der Datei):

- Die Speisekarte und die Mitarbeiter des Servers ersetzen die am Tablet. Artikel, die es am Server nicht gibt, werden am Tablet stillgelegt, nicht gelöscht. Alte Bons bleiben lesbar, weil jeder Bon Namen und Preise selbst trägt.
- Die Bons, Tage und Bargeld-Bewegungen, die schon am Tablet liegen, werden hochgeladen und gehören dann zu diesem Betrieb.
- Ein offener, noch nicht kassierter Bon wird geleert. Die angemeldete Person wird abgemeldet, weil ab jetzt die PINs vom Server gelten.
- Vor dem Koppeln steht das alles in einer Rückfrage.
- Ein Tablet, das einmal gekoppelt war, lässt sich nur wieder mit demselben Betrieb koppeln. Sonst landeten Bons eines Betriebs bei einem anderen. Für einen anderen Betrieb müssen die App-Daten gelöscht werden. Wird ein Tablet ein zweites Mal mit demselben Betrieb gekoppelt, entsteht am Server ein neuer Eintrag "Kassa". Das Tablet zählt seine Bon-Nummern weiter, und was noch wartet, geht unter dem neuen Eintrag hinauf.

**Ein Tablet geht kaputt und wird ersetzt.** In Teil C beginnt das neue Tablet als neue Kassa: eigener Eintrag, Bon-Nummern ab 1, Wechselgeld wird beim ersten Öffnen des Abschlusses neu eingegeben, so wie am allerersten Tag. Die Bons des alten Tablets liegen am Server und sind in der Verwaltung zu sehen, sie kommen nicht auf das neue Tablet. Ein Tag, der am alten Tablet offen war, bleibt am Server als "nicht abgeschlossen" stehen. Die Übernahme einer Kassa samt Nummern und Zählerstand wird erst mit der RKSV-Signatur nötig und dort entworfen.

**Die Einrichtung aus der Datei bleibt** als zweiter Weg am ersten Bildschirm, für Vorführungen und Tests ohne Server.

### 5.5 Daten am Server

Jede Tabelle trägt den Betrieb. Kennungen von Kategorien, Artikeln und Vorlagen sind nur innerhalb eines Betriebs eindeutig (zwei Betriebe dürfen beide einen Artikel `cola` haben). Geldbeträge sind ganze Cent.

| Was | Wichtigste Angaben | Wer schreibt |
|---|---|---|
| Betrieb | Name, Adresszeilen, UID-Nummer, Text am Bon-Ende, Logo | Verwaltung |
| Benutzer | E-Mail, Prüfwert des Passworts, Rolle, Betrieb (beim Chef) | Verwaltung |
| Sitzung, Einmal-Link | Prüfwert, Ablauf | Server |
| Kassa | Name, Prüfwert des Geräte-Schlüssels, gekoppelt am, zuletzt gesehen, App-Version, gesperrt am | Verwaltung, Server |
| Kopplungscode | Prüfwert, Name der Kassa, Ablauf, verwendet am | Verwaltung |
| Kategorie, Artikel | wie am Tablet, dazu Änderungs-Nummer, stillgelegt, bei Artikeln Zeitpunkt der letzten Änderung pro Feld, das am Tablet änderbar ist | Verwaltung, Tablet (nur die änderbaren Felder) |
| Auswahl-Vorlage | Name, Gruppen und Optionen als ein Stück, Änderungs-Nummer | Verwaltung |
| Mitarbeiter | Name, Rolle, PIN als Prüfwert, stillgelegt, Änderungs-Nummer | Verwaltung |
| Datei | Schlüssel in der Ablage, Art, Größe | Verwaltung |
| Bon mit Zeilen, Optionen und Zahlung | alles wie am Tablet, dazu Kassa, Prüfsumme des Inhalts und das Merkmal "Testbon" | nur Tablet, nur anlegen |
| Tag (Tagesabschluss) | wie am Tablet, dazu Kassa | nur Tablet, bis er abgeschlossen ist |
| Bargeld-Bewegung | wie am Tablet, dazu Kassa | nur Tablet, nur anlegen |
| Bericht vom Gerät | Art (Fehler, Geräte-Test), Zeitpunkt, App-Version, Gerät, Inhalt | nur Tablet, nur anlegen |
| Installationsdatei | Version, Datei, Prüfsumme, geheimer Teil des Links | Anbieter |
| Verlauf | wer hat wann was in der Verwaltung getan: Anmeldung, Mitarbeiter und PINs, Kassen koppeln und sperren, Einspielen | Server |

Regeln:

- **Bons am Server lassen sich nicht ändern und nicht löschen.** Die Datenbank sperrt das selbst, so wie am Tablet. Dasselbe gilt für Bargeld-Bewegungen, Berichte und abgeschlossene Tage.
- **Testbons.** Jeder Bon trägt das Merkmal "Testbon", solange die Kassa keine Signatur hat. In Teil C sind das alle Bons, auch die, die beim Koppeln schon am Tablet liegen. Die App bekommt dafür ein eigenes Feld (bei vorhandenen Bons: ja). Die Auswertungen der Verwaltung zählen Testbons mit, solange ein Betrieb nur Testbons hat, und zeigen dann den Hinweis "Testbetrieb". Sobald es den ersten echten Bon gibt, zählen Auswertungen nur noch echte Bons. In der Liste der Bons bleiben Testbons sichtbar und gekennzeichnet. So muss vor dem echten Betrieb nichts gelöscht werden.
- **Nichts aus der Speisekarte wird gelöscht.** Was entfernt wird, wird stillgelegt. So erfährt jedes Tablet davon.
- **Eine Vorlage ist ein Stück.** Ändert der Chef eine Gruppe oder Option, bekommt das Tablet die ganze Vorlage neu und ersetzt sie.
- **PINs:** Der Server erzeugt den Prüfwert genauso wie das Tablet heute, damit die Anmeldung am Tablet ohne Internet weiter geht. Zwei Mitarbeiter eines Betriebs dürfen nicht dieselbe PIN haben, der Server prüft das beim Speichern. Eine PIN aus vier Ziffern ist ein Schutz gegen Versehen, kein starkes Geheimnis. Die Prüfwerte gehen deshalb nur an Kassen desselben Betriebs und erscheinen in keiner Antwort an den Browser.
- **Neu einspielen** der Speisekarten-Datei gilt wie am Tablet (von Niko am 17.11.2026 bestätigt): Die Datei gewinnt bei allem, was in ihr steht, auch bei Preisen. Favorit, "Im Verkauf" und Fotos bleiben. Artikel, die in der neuen Datei fehlen, werden stillgelegt. Mitarbeiter legt das Einspielen nie an. Die Prüfregeln für die Datei sind dieselben wie am Tablet, und beide Seiten werden gegen dieselben Beispieldateien getestet.

### 5.6 Abgleich

**Grundsatz.** Die App liest und schreibt weiter nur ihre eigene Datenbank. Der Abgleich läuft daneben und darf scheitern, ohne dass an der Theke etwas hängt.

**Vom Server zum Tablet** (Speisekarte, Vorlagen, Mitarbeiter, Betriebsdaten, Verweise auf Fotos):

- Jede Änderung an diesen Daten bekommt am Server eine fortlaufende Änderungs-Nummer.
- Das Tablet merkt sich die höchste Nummer, die es verarbeitet hat, und fragt "was ist neu seit dieser Nummer?". Beim ersten Mal ist das alles.
- Die Antwort wird am Tablet in einem Schritt übernommen: ganz oder gar nicht.
- Änderungen eines Betriebs werden am Server nacheinander geschrieben (eine Sperre pro Betrieb). Sonst könnte ein Tablet eine Änderung überspringen, die mit kleinerer Nummer später fertig wird. Dafür gibt es einen eigenen Test.

**Vom Tablet zum Server** (Bons mit Zahlung, Tage, Bargeld-Bewegungen, Artikel-Änderungen, Berichte):

- Das Tablet führt eine Liste "noch zu senden". Ein Eintrag entsteht im selben Schritt wie die Sache selbst. Stürzt die App ab, ist entweder beides da oder keines.
- Gesendet wird in Paketen, in der Reihenfolge der Liste. Der Server antwortet pro Eintrag: angenommen, schon vorhanden oder abgelehnt mit Grund.
- **Derselbe Bon wird nie zweimal angenommen.** Kommt eine Kennung noch einmal mit demselben Inhalt, gilt sie als schon vorhanden. Kommt sie mit anderem Inhalt, lehnt der Server ab, behält seine Fassung und schreibt einen Bericht. Das Tablet markiert den Eintrag als abgelehnt und sendet die nächsten weiter. Ein abgelehnter Eintrag hält nie die Liste auf.
- Ein offener Tag wird bei jeder Änderung neu gesendet und am Server überschrieben. Ein abgeschlossener Tag ist endgültig.
- Beim Koppeln werden alle vorhandenen Bons, Tage und Bewegungen einmal in die Liste gestellt.

**Artikel-Änderungen in beide Richtungen.** Am Tablet änderbar sind Preis, "Im Verkauf", Favorit, Pfand und Kennzeichen. In der Verwaltung ist alles änderbar. Alle diese Angaben gelten für den ganzen Betrieb, nicht pro Kassa: Was an einer Kassa als ausverkauft oder als Favorit gesetzt wird, gilt an jeder. Kennzeichen sind die feste Liste, die das Tablet kennt (VEGAN, SCHARF). Eigene Kennzeichen gibt es in Teil C nicht.

- Das Tablet sendet pro Änderung: Artikel, Feld, neuer Wert, Zeitpunkt der Änderung.
- Der Server merkt sich pro Feld den Zeitpunkt der letzten Änderung. **Es gilt pro Feld die spätere Änderung.** Eine Uhrzeit vom Tablet, die in der Zukunft liegt, wird auf die Uhrzeit des Servers gekürzt.
- Solange am Tablet für ein Feld noch eine eigene Änderung wartet, überschreibt eine Antwort vom Server dieses Feld nicht. Nach dem Senden bringt die nächste Abfrage den Wert, der gewonnen hat.

**Wann abgeglichen wird:** beim Start der App und wenn sie wieder nach vorn kommt, kurz nach jedem fertigen Bon, jeder Bargeld-Bewegung, jedem Tagesabschluss und jeder Artikel-Änderung, alle 5 Minuten, sobald das Internet zurück ist, und über die Taste "Jetzt abgleichen". Scheitert ein Versuch, wächst der Abstand (30 Sekunden, 1 Minute, 2 Minuten, höchstens 15 Minuten). Im Hintergrund, während die App geschlossen ist, wird nicht abgeglichen.

**Größen:** Ein Paket hat höchstens 100 Einträge. Ein Tablet, das eine Woche ohne Internet war, holt in mehreren Paketen auf.

**Mehrere Kassen in einem Betrieb:** Jede Kassa zählt ihre Bons selbst. Am Server ist die Bon-Nummer pro Kassa eindeutig. Auswertungen fassen alle Kassen eines Betriebs zusammen.

### 5.7 Fotos und Logo

- In der Verwaltung lädt man pro Artikel oder Kategorie ein Foto hoch (JPEG, PNG oder WebP, höchstens 10 MB) und für den Betrieb ein Logo.
- Der Server prüft, dass es wirklich ein Bild ist, rechnet es auf höchstens 800 Pixel Breite herunter, entfernt eingebettete Angaben wie den Aufnahmeort und legt es in der Ablage unter dem Betrieb ab.
- Das Tablet erfährt beim Abgleich, welches Foto zu welchem Artikel gehört, lädt fehlende Dateien über den Server herunter und hält sie auf dem Gerät. Die Kassa zeigt nie ein Foto direkt aus dem Internet.
- Der Server gibt eine Datei nur an Kassen und Benutzer des Betriebs heraus, dem sie gehört.
- Wird ein Foto ersetzt, bekommt es einen neuen Namen. Das Tablet lädt das neue und räumt das alte weg.

### 5.8 Fehlerberichte

- Die App fängt unerwartete Fehler ab und legt sie in ihre Datenbank. Dazu kommt das Ergebnis jedes Laufs von "Geräte testen". Beides geht mit dem Abgleich an den Server.
- Ein Bericht enthält: Art, Zeitpunkt, App-Version, Android-Version, Gerätemodell, bei Fehlern die Art des Fehlers, die ersten 500 Zeichen der Meldung und die Aufrufliste (höchstens 8.000 Zeichen), bei "Geräte testen" pro Gerät das Ergebnis und den angezeigten Text.
- Ein Bericht enthält nie Bon-Zeilen, Beträge, Namen von Mitarbeitern oder Kartendaten. Der Bericht wird aus festen Feldern gebaut, nicht aus einem Abbild des Bildschirms.
- Höchstens 50 Berichte pro Tag und Kassa. Derselbe Fehler in Folge wird gezählt statt wiederholt.
- Der Anbieter sieht die Berichte pro Kassa in der Verwaltung. Zusätzlich schreibt der Server jeden Bericht als eine Zeile in sein Protokoll bei Railway. Dort liest Claude sie, ohne Nikos Zugang zur Verwaltung zu brauchen.

### 5.9 Installationsdatei

- Der Server hält die Installationsdateien in der Ablage. Jede hat einen Link mit einem langen, zufälligen Teil, zum Beispiel `/laden/<zufällig>/kassa-1.2.0.apk`. Wer den Link nicht kennt, kommt nicht an die Datei.
- Hochgeladen wird über eine eigene Adresse, die ein Geheimnis aus den Railway-Variablen verlangt. Es gilt dauerhaft und lässt sich dort austauschen. Claude lädt nach jedem Bau hoch und schickt Niko den Link.
- Der Anbieter sieht in der Verwaltung alle Dateien mit Version, Datum, Prüfsumme und Link und kann eine Datei zurückziehen. Der Link gilt dann nicht mehr.
- Damit ist die offene Entscheidung aus Teil B lösbar: Die Datei mit SumUp-Schlüssel muss nicht ins öffentliche Repo.

### 5.10 Verwaltung im Browser

Hier darf getippt werden. Gleiche Farben, Schrift und Formen wie die App (`DESIGN.md`), aber für Maus, Tastatur und auch das Handy gebaut: Der Chef soll Umsätze am Handy ansehen können.

Seiten für den Chef (und für den Anbieter in jedem Betrieb):

| Seite | Was sie kann |
|---|---|
| Übersicht | Umsatz heute, 7 Tage, 30 Tage, nach Stunde oder Tag, Zahlungsarten, meistverkaufte Artikel, Umsatz nach Kategorie. Zahlen aus den Bons am Server, über alle Kassen. |
| Artikel | Liste nach Kategorie mit Suche. Artikel anlegen und ändern: Name, Preis, Kategorie, Steuersatz, Pfand, Kennzeichen, Zusatzangabe, Favorit, "Im Verkauf", Foto, Auswahl-Vorlage. Stilllegen und wieder aktivieren. |
| Kategorien | Anlegen, umbenennen, Reihenfolge, Foto, stilllegen. |
| Auswahl-Vorlagen | Gruppen mit mindestens und höchstens, Optionen mit Aufpreis und Vorgabe. |
| Mitarbeiter | Anlegen, Name, Rolle, PIN setzen, stilllegen. |
| Kassen | Kassa koppeln (Code), Zustand, zuletzt gesehen, App-Version, sperren. |
| Bons | Liste mit Filter nach Tag, Zahlungsart und Storno, Bon im Detail. Nur ansehen. |
| Tagesabschlüsse | Liste, Abschluss im Detail. Nur ansehen. |
| Betrieb | Name, Adresse, UID-Nummer, Text am Bon-Ende, Logo. |

Seiten nur für den Anbieter: Betriebe (Liste, anlegen aus Datei, neu einspielen, Chef-Zugang anlegen), Fehlerberichte, Installationsdateien.

Verhalten, das für alle Seiten gilt:

- Änderungen werden sofort sichtbar und im Hintergrund gespeichert. Scheitert das Speichern, springt der Wert zurück und eine Meldung sagt warum.
- Löschen heißt stilllegen und lässt sich rückgängig machen.
- Jede Liste hat einen leeren Zustand, der sagt, was als Nächstes zu tun ist, und einen Ladezustand in der Form des späteren Inhalts.
- Bei jedem Artikel steht, wann er zuletzt an die Kassen ging ("an der Kassa seit 14:02" oder "wartet auf die Kassa").

Die Bilder dieser Seiten gehen vor dem Bau von C3 zu Niko.

### 5.11 Neue Bildschirme am Tablet

Alle folgen den vorhandenen Bausteinen (Zahlenfeld wie bei der PIN, Karten, Haupttaste). Niko sieht sie zuerst als Skizze im Dokument zur Freigabe und danach als Bild im Entwurf, bevor der Tablet-Teil von C1 gebaut wird. Der Server-Teil von C1 hängt nicht daran und beginnt vorher. Die Seiten der Verwaltung in C1 und C2 gehen ohne eigene Freigabe nach `DESIGN.md`, die Seiten von C3 bekommt Niko als Bilder.

1. **Erster Start.** Zwei Wege: "Mit Code koppeln" als Haupttaste, darunter "Speisekarte aus Datei einspielen".
2. **Code eingeben.** Überschrift "Kopplungscode eingeben", acht Felder, Zahlenfeld, Hinweis "Den Code findest du in der Verwaltung unter Kassen". Zustände: wird geprüft, "Der Code stimmt nicht oder ist abgelaufen.", "Keine Verbindung zum Internet.", "Zu viele Versuche. Bitte in 15 Minuten nochmal."
3. **Verbunden.** "Verbunden mit <Betrieb>", darunter der Fortschritt "Speisekarte wird geladen", dann weiter zur Anmeldung mit PIN. Hat der Betrieb noch keinen Mitarbeiter: "Lege in der Verwaltung zuerst einen Mitarbeiter mit PIN an." mit der Taste "Nochmal prüfen". Der Schritt "Chef-PIN festlegen" entfällt bei gekoppelten Tablets.
4. **Einstellungen, neue Karte "Server".** Gekoppelt: "Verbunden mit <Betrieb> als <Kassa>", "Zuletzt abgeglichen vor 2 Minuten", "Wartet noch: 3", Taste "Jetzt abgleichen". Nicht gekoppelt: Taste "Mit Server verbinden", die nach der Rückfrage aus 5.4 zur Code-Eingabe führt. Gesperrt: der Hinweis aus 5.4.
5. **Einstellungen, "Speisekarte neu einspielen"** verschwindet bei gekoppelten Tablets. Dort steht "Die Speisekarte kommt vom Server."
6. **Kopfleiste und Anmeldung** zeigen das Logo des Betriebs, wenn es eines gibt.

Der Abgleich selbst hat keinen eigenen Hinweis in der Kopfleiste. Dort steht weiter nur "Kein Internet".

### 5.12 Sicherheit und Datenschutz

- Jede Verbindung ist verschlüsselt. Der Server nimmt nichts Unverschlüsseltes an.
- Passwörter, Geräte-Schlüssel, Sitzungen, Kopplungscodes und Einmal-Links liegen am Server nur als Prüfwert.
- Jede Adresse der Verwaltung und der Tablets hat einen Test mit einem zweiten Betrieb, der nichts sehen und nichts ändern darf. Die Datenbank sperrt zusätzlich selbst (siehe 4).
- Der Server-Dienst arbeitet in der Datenbank mit einem Benutzer, für den diese Sperre gilt. Nur das Einrichten der Tabellen läuft mit mehr Rechten.
- Anfragen, die etwas ändern, werden nur von der eigenen Adresse angenommen (Schutz davor, dass eine fremde Seite im Namen des angemeldeten Benutzers handelt).
- Hochgeladene Dateien haben Grenzen für Größe und Art. Bilder werden neu erzeugt, nie unverändert ausgeliefert. Die Speisekarten-Datei darf höchstens 1 MB groß sein.
- Der Server speichert keine Kartendaten. Von einer Kartenzahlung kennt er, was der Bon trägt: Art, Betrag, Kennung bei SumUp, Kartenart, letzte vier Ziffern.
- Personenbezogen sind: E-Mail der Benutzer, Namen der Mitarbeiter. Die Daten liegen in der EU. Der Vertrag zur Auftragsverarbeitung bleibt offen wie im Hauptentwurf.
- Das Protokoll des Servers enthält keine Passwörter, Schlüssel, PINs oder Bon-Inhalte.

### 5.13 Tests

- Testgetrieben wie bisher.
- **Server:** gegen eine echte PostgreSQL-Datenbank. Schwerpunkte: Trennung der Betriebe für jede Adresse, Anmeldung und Sitzungen, Kopplung (abgelaufen, schon verwendet, zu viele Versuche, gesperrt), Abgleich (derselbe Bon mehrfach, anderer Inhalt unter derselben Kennung, Abbruch mitten im Paket, Reihenfolge der Änderungs-Nummern bei gleichzeitigen Änderungen, spätere Änderung gewinnt pro Feld), Sperren gegen Ändern von Bons.
- **App:** Migration der Datenbank mit Test. Abgleich gegen einen nachgebauten Server: ohne Internet, Abbruch, Wiederholung, abgelehnter Eintrag, gesperrte Kassa, wartende eigene Änderung.
- **Gemeinsame Beispiele:** Die Form der Nachrichten zwischen App und Server liegt als Beispieldateien im Repo. App und Server werden beide dagegen getestet, damit sie sich nicht auseinanderentwickeln. Dasselbe gilt für die Speisekarten-Datei und ihre Fehlerfälle.
- **Zusammenspiel:** Ein Lauf startet den echten Server mit Datenbank in der Bau-Umgebung und lässt den Abgleich-Teil der App (ohne Oberfläche) dagegen arbeiten: koppeln, holen, senden, Änderung in beide Richtungen.
- **Verwaltung:** Die Hauptwege laufen in einem echten Browser durch: anmelden, Betrieb anlegen, Mitarbeiter, Code erzeugen.
- **Vor der Übergabe jeder Stufe:** eine Prüfliste für Niko mit Tablet und Browser.

### 5.14 Betrieb bei Railway und Kosten

- Projekt "kassa" mit Server-Dienst, PostgreSQL und Ablage, Region EU.
- Der Dienst wird aus dem Repo gebaut. Beim Start richtet er fehlende Tabellen selbst ein.
- Railway rechnet nach Verbrauch ab (Preisliste von docs.railway.com, gelesen am 18.11.2026): Arbeitsspeicher 10 Dollar pro GB und Monat, Rechenleistung 20 Dollar pro Kern und Monat, Datenbank-Speicher 0,15 Dollar pro GB und Monat, Ablage 0,015 Dollar pro GB und Monat, ausgehender Verkehr 0,05 Dollar pro GB. Der Tarif Hobby kostet 5 Dollar im Monat und enthält 5 Dollar Verbrauch, Pro 20 Dollar mit 20 Dollar Verbrauch, jeweils für das ganze Konto.
- **Schätzung für Kassa mit einem Betrieb: 3 bis 7 Dollar Verbrauch im Monat.** Gerechnet mit 150 bis 250 MB Arbeitsspeicher für den Server und 100 bis 250 MB für die Datenbank, kaum Rechenleistung, 1 GB Speicher. Die Speicher-Werte sind Claudes Annahme und zeigen sich erst im Betrieb. Ob das im enthaltenen Verbrauch von Nikos Tarif Platz hat, hängt von seinen vier anderen Projekten ab. Das kann Claude nicht sehen.
- Eine Obergrenze für die Kosten lässt sich bei Railway im Konto einstellen. Das macht Niko selbst.
- **Sicherung** (Teil von C2, sobald echte Daten fließen): Jede Nacht legt der Server eine Kopie der ganzen Datenbank in die Ablage und behält die letzten 14. Das Zurückspielen wird einmal in der Bau-Umgebung geprobt und beschrieben. Das ist unabhängig davon, was Nikos Tarif bei Railway an Sicherungen kann.

## 6. Dem Bau überlassen

- Bibliotheken innerhalb der gewählten Technik (Server-Gerüst, Datenbankzugriff, Prüfung der Eingaben, Bildverkleinerung, Zugriff auf die Ablage, Gerüst und Bausteine der Web-Anwendung, Netzwerk und geschützter Speicher in der App).
- Genaue Tabellen, Felder und Adressen über 5.1 und 5.5 hinaus, Form der Nachrichten.
- Ob Bon-Zeilen am Server eigene Tabellen sind oder als ein Stück am Bon hängen, solange die Auswertungen aus 5.10 damit gehen.
- Wie der Dienst bei Railway aus dem Repo gebaut wird.
- Reihenfolge der Arbeit innerhalb einer Stufe.

## 7. Offene Punkte

**Braucht Niko**

1. Die Adresse des Servers in der Bau-Umgebung freischalten (`*.up.railway.app`), sobald das Projekt angelegt ist. Claude legt die Karte dafür vor.
2. Einmal den Link öffnen und das eigene Anbieter-Konto anlegen.
3. Den SumUp-Schlüssel (offen aus Teil B). Mit C1 kommt die Datei dann über den geheimen Link.
4. Wer bei YICHI den Chef-Zugang bekommt (E-Mail), sobald C3 da ist.

**Klärt Claude**

5. Was Nikos Tarif bei Railway zusätzlich an Sicherungen kann. Die eigene nächtliche Sicherung aus 5.14 hängt nicht davon ab.
6. SumUp-Schnittstelle für C4: ob sich eine Zahlung über die Kennung von Kassa nachschlagen lässt und welchen Zugang der Betrieb dafür geben muss.
7. In welcher Region Railway die Ablage anlegt. Die Preisseite sagt dazu nichts.

## 8. Claudes Entscheidungen zum Gegenprüfen

- Die Verwaltung für den Chef gehört zu Teil C (aus Nikos "Server und Browser-Verwaltung"), als dritte Stufe nach Kopplung und Abgleich.
- Eine Web-Anwendung im endgültigen Stil statt der schlichten Anbieter-Seite aus dem Hauptentwurf.
- Kopplungscode: 8 Ziffern, 15 Minuten, einmal verwendbar.
- Ein schon eingerichtetes Tablet behält beim Koppeln seine Bons und lädt sie hoch. Speisekarte und Mitarbeiter kommen danach vom Server.
- Die Einrichtung aus der Datei bleibt als zweiter Weg.
- Eine gesperrte Kassa boniert weiter und gleicht nur nicht mehr ab.
- Bei gleichzeitigen Änderungen gilt pro Feld die spätere, gemessen an der Uhr des Geräts, gekürzt auf die Uhr des Servers.
- Kein Logo am gedruckten Bon in Teil C.
- Kein E-Mail-Versand: Zugänge und "Passwort vergessen" laufen über Links, die Niko weitergibt.
- Die Adresse des Servers steht nicht im Repo.
- Die Verwaltung funktioniert auch am Handy.
- Fehlerberichte stehen zusätzlich im Protokoll bei Railway, damit Claude sie lesen kann.

Nach dem Gegenlesen durch einen zweiten Prüfer am 18.11.2026 dazugekommen:

- Bons ohne Signatur tragen das Merkmal "Testbon" und fallen aus den Auswertungen, sobald es echte Bons gibt. Gelöscht wird nichts.
- Ein Ersatz-Tablet beginnt in Teil C als neue Kassa. Die Übernahme einer Kassa kommt mit der RKSV-Signatur.
- Eine Sperre lässt sich aufheben. Was während der Sperre boniert wurde, wird dann nachgesendet.
- Favorit und "Im Verkauf" gelten für den ganzen Betrieb, nicht pro Kassa. Eine Trennung pro Kassa wäre später ein Umbau an Server und Tablet.
- Kennzeichen bleiben die feste Liste VEGAN und SCHARF.
- Das Geheimnis zum Hochladen der Installationsdatei gilt dauerhaft.
- Eigene nächtliche Sicherung der Datenbank in C2.
- Die neuen Tablet-Bildschirme sieht Niko als Skizze und als Bild, bevor ihr Teil gebaut wird.

## 9. Abweichungen beim Bau der Stufe C1 (2026-11-18)

Beim Bau von C1 sind folgende Entscheidungen dazugekommen, wo dieser Entwurf schweigt oder etwas anderes sagt:

- Die Adresse des Aufrufers für die Grenze bei falschen Codes wird nie aus Kopfzeilen wie `X-Forwarded-For` gelesen, denn jeder Client kann sie fälschen. Die Einstellung `CLIENT_IP_HEADER` nennt die eine Kopfzeile, die die Plattform selbst setzt. Ohne sie zählt die Adresse der Verbindung.
- Eine gesperrte Kassa wird am Tablet mit dem Vermerk "blocked" festgehalten. Darum rückt "Zuletzt abgeglichen" während der Sperre nicht weiter.
- Beim Koppeln speichert das Tablet zuerst die Kassa und ganz zuletzt den Geräte-Schlüssel. So kann ein Abgleich im Hintergrund nie einen neuen Schlüssel mit einem alten Stand verbinden.
- Eine spätere Seite vom Server wird nur eingespielt, wenn sie zum gespeicherten Stand und zur gespeicherten Kassa passt. Sonst wird sie leise verworfen.
- Kommt ein Artikel vor seiner Kategorie an, legt das Tablet eine versteckte Platzhalter-Kategorie an. Die echte überschreibt sie im selben Lauf.
- Fehler am Tablet selbst (Datenbank, geschützter Speicher, eine Seite lässt sich nicht einspielen) werden als "local" festgehalten.
- Ein Tablet gilt erst als eingerichtet, wenn es eine Speisekarte und mindestens einen Chef hat. Ein Betrieb nur mit Mitarbeitern genügt nicht.
- Scheitert das Laden der Speisekarte nach dem Koppeln, bietet der Bildschirm neben "Nochmal versuchen" auch "Mit neuem Code koppeln" an.
- Die Verwaltung bietet bei stillgelegten Mitarbeitern "Wieder einsetzen" an.
- Einen Kopplungscode gibt es nur für einen Betrieb mit mindestens einem aktiven Chef. Ohne ihn antwortet der Server mit "Lege zuerst einen Chef mit PIN an." Die Verwaltung führt nach dem Anlegen eines Betriebs zuerst zu den Mitarbeitern und zeigt unter "Kassen" diesen Satz statt "Kassa koppeln", solange kein Chef da ist.
- Ein Tablet, das schon verkauft (es hat einen Chef), wird nicht ersetzt, wenn der Betrieb am Server keinen aktiven Chef hat. Speisekarte, PINs, Anmeldung und offener Bon bleiben, das Tablet zeigt "Lege in der Verwaltung zuerst einen Mitarbeiter mit PIN an." mit "Nochmal prüfen" und "Zurück zur Kassa". Ein leeres Tablet lädt wie bisher und wartet danach auf einen Chef.
- Die Karte einer gesperrten Kassa hat die ruhige Taste "Nochmal prüfen". Sie gleicht sofort ab, damit niemand nach dem Aufheben der Sperre bis zu 5 Minuten warten muss.
- Fehlt der Geräte-Schlüssel beim Laden der Speisekarte oder lehnt der Server ihn ab, zeigt die Karte "Der Server kennt diese Kassa nicht mehr." mit "Neu koppeln". Neues Koppeln löscht diesen Vermerk.
- Die Anmeldung im Browser hat neben der Wartezeit pro E-Mail eine Grenze pro Adresse: 30 Versuche in 15 Minuten, gezählt, bevor das Passwort gerechnet wird. Alte Fehlversuche (älter als 24 Stunden) und abgelaufene Sitzungen löscht der Server einmal pro Stunde.
- Wie der Bucket angesprochen wird, ist eine Einstellung: `S3_URL_STYLE` mit `virtual` (Vorgabe, so arbeitet Railway) oder `path`.
- `PUBLIC_URL` wird auf die Herkunft gekürzt, `DATABASE_URL` wird beim Start geprüft, `SETUP_TOKEN` und `RELEASE_TOKEN` brauchen mindestens 32 Zeichen. Keine Fehlermeldung nennt dabei den Wert.
