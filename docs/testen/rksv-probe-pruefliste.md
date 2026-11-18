# Prüfliste: Probe-Signatur

Dieser Test zeigt, ob die Kassa mit der Probe-Signatur richtig arbeitet. Jeder Bon bekommt dann einen QR-Code, hängt am Bon davor und kommt in ein Protokoll, so wie später im echten Betrieb. Die Unterschrift kommt dabei aus einem Schlüssel auf dem Tablet. Die Signaturkarte brauchst du nicht, und es wird keine PIN verlangt.

Diese Liste ist zum Abhaken am echten Tablet. Bei jedem Punkt steht, was du tun sollst und was du sehen solltest. Wenn etwas anders aussieht oder nicht geht: Punkt offen lassen und kurz dazuschreiben, was passiert ist. Ein Foto vom Bildschirm hilft.

Wichtig zur Probe:

- Alle Bons bleiben Testbons. Auf dem Papier steht "TESTBON". Sie gelten nicht für das Finanzamt. Mach den Test am besten außerhalb der Öffnungszeit.
- Du musst als Chef angemeldet sein. Nur der Chef sieht die Tasten der Karte "Signatur".
- Ältere Bons von vor dem Einschalten kannst du danach nicht mehr stornieren. Das ist Absicht.
- Lösch die Kassa oder ihre Daten während des Tests nicht.
- Ein Ausfall der Signatur lässt sich mit der Probe nicht von Hand auslösen. Darum steht er nicht in dieser Liste.

## 1. Was du brauchst

- [ ] Das Tablet mit der Kassa in Version 1.4.0. Ganz unten in den Einstellungen steht "Kassa Version 1.4.0". Du musst vielleicht nach unten wischen.
- [ ] Den Bondrucker, am Strom und mit Papier.
- [ ] Ein Handy mit Kamera, um den QR-Code zu lesen.
- [ ] Optional: einen USB-Stick, um das Protokoll in Schritt 8 zu sichern.

Das solltest du sehen: Alles liegt bereit, die Kassa startet wie immer, und die Version stimmt.

## 2. Die Einstellungen ansehen

- [ ] Einstellungen öffnen (Regler-Symbol oben rechts).

Das solltest du sehen: Die Einstellungen sind jetzt anders angeordnet als früher. Links oben steht die Karte "Signatur", darunter die Karte "Kassa". Rechts stehen die Karten "Geräte an dieser Kassa", "Anzeige" und der Server.

- [ ] Prüfen, ob in der Karte "Signatur" in der Zeile "Signatur der Bons" die Pille "Nicht eingerichtet" steht.

Wenn dir die neue Anordnung unpraktisch vorkommt, schreib mir das auf.

## 3. Probe einschalten

- [ ] In der Karte "Signatur" bei "Zum Ausprobieren einschalten" auf "Einschalten" tippen.
- [ ] Im Fenster "Probe-Signatur einschalten?" noch einmal auf "Einschalten" tippen. Mit "Abbrechen" bleibt alles, wie es war.

Das solltest du sehen: Die Pille in der Zeile "Signatur der Bons" heißt jetzt "Probe". Darunter steht "Probe-Signatur, nicht für den echten Betrieb." mit einer Kassen-ID (so heißt diese Kassa innerhalb der Signatur). Die Kassa druckt einen Startbeleg. Die Karte zeigt jetzt auch "Nullbeleg drucken", "Protokoll ausgeben" und "Probe beenden".

## 4. Aufgaben ansehen

- [ ] In der Karte "Signatur" die Liste "Zu erledigen" ansehen.

Das solltest du sehen: Unter "Zu erledigen" steht der Satz "Aufgaben aus der Probe sind zum Üben." Eine der Aufgaben lautet: Startbeleg mit der App "BMF Belegcheck" prüfen. Die Aufgaben aus der Probe sind nur zum Üben. Hier schaust du nur an, was in der Liste steht. Das Antippen von "Erledigt" kommt am Ende von Schritt 6.

## 5. Zwei Verkäufe

- [ ] Einen Verkauf mit "Bar" abschließen.
- [ ] Einen zweiten Verkauf mit "Bar" abschließen, am besten mit einem anderen Artikel.
- [ ] Die beiden Bons in der Hand halten.

Das solltest du sehen: Beide Bons haben oben "TESTBON". Am Ende jedes Bons steht ein QR-Code. Er ist quadratisch. Der Verkauf ging so schnell wie immer.

Zahlen mit "Karte" gehört nicht zu diesem Test.

Wenn der QR-Code fehlt, nur aus Zeichen besteht oder unlesbar ist, geh zu Schritt 10.

## 6. QR-Code ansehen und lesen

- [ ] In der Kassa oben auf "Bons" tippen und einen der beiden Bons antippen.
- [ ] Prüfen, ob der QR-Code auch hier auf dem Bildschirm steht. Darunter steht "Testbon mit Probe-Signatur." und "Der QR-Code steht auch am gedruckten Bon."
- [ ] Den QR-Code vom gedruckten Bon mit der Kamera oder einer QR-Leser-App am Handy lesen.
- [ ] Den Text abschreiben oder ein Foto machen. Er beginnt mit `_R1-AT100_`.
- [ ] Optional: Den QR-Code mit der App "BMF Belegcheck" scannen. Sie lehnt ihn ab. Das ist richtig, denn die Probe-Signatur gehört nicht zu einer echten Registrierkasse.

Das solltest du sehen: Der Text beginnt mit `_R1-AT100_` und ist ein langer Block aus Buchstaben, Ziffern und Zeichen. Bei "BMF Belegcheck" steht ein Fehler. So soll es sein.

Zum Schluss von Schritt 6:

- [ ] In den Einstellungen in der Karte "Signatur" die Aufgabe zum Startbeleg auf "Erledigt" tippen.

Das solltest du sehen: Die Aufgabe verschwindet aus der Liste. Ist keine Aufgabe mehr übrig, verschwindet auch die Liste "Zu erledigen".

## 7. Storno und Nullbeleg

- [ ] In "Bons" den zweiten Bon ("Bar") antippen und auf "Stornieren" tippen. In der Frage "Ja, stornieren" wählen.
- [ ] In den Einstellungen, Karte "Signatur", bei "Nullbeleg drucken" auf "Drucken" tippen.

Das solltest du sehen: Der Storno-Bon hat einen QR-Code, und in der Ansicht steht "Storno zu Bon Nr. …". Der Nullbeleg ist ein Beleg über 0 Euro, er heißt "Nullbeleg" und hat auch einen QR-Code. Beide Belege sind in "Bons" zu finden.

## 8. Protokoll ausgeben

Das Protokoll ist eine Datei mit allen signierten Bons. Dieser Schritt ist noch an keinem echten Tablet ausprobiert worden. Darum ist dein Bericht hier besonders wichtig.

- [ ] Bei "Protokoll ausgeben" auf "Ausgeben" tippen.
- [ ] Im Fenster "Protokoll ausgeben" einen Zeitraum wählen: "Alles", "Dieses Vierteljahr" oder "Letztes Vierteljahr". Nimm "Alles".
- [ ] Android öffnet jetzt ein eigenes Fenster zum Speichern der Datei. Als Dateiname schlägt Android einen Namen vor, der mit `kassa-protokoll-PROBE-` beginnt. Wähle einen Ort, zum Beispiel einen USB-Stick oder "Downloads", und speichere.

Das solltest du sehen: Unter der Zeile steht "Gespeichert."

- [ ] Prüfen, ob die Datei wirklich dort angekommen ist, wo du sie gespeichert hast (am USB-Stick oder in "Downloads"). Schreib auf, ob sie da war.
- [ ] Noch einmal "Ausgeben" tippen, einen Zeitraum wählen und im Fenster von Android auf "Abbrechen" tippen. Schreib auf, was dann passiert ist. Es sollte "Nicht gespeichert." erscheinen, und es soll nichts kaputtgehen.
- [ ] Die gespeicherte Datei an mich schicken.

Die Datei enthält nur die Bons und ihre Unterschriften. Keine PIN und keinen geheimen Schlüssel.

## 9. Monat und Jahr

Du musst das jetzt nicht testen. Zur Info: Beim ersten Verkauf in einem neuen Monat entsteht ein Monatsbeleg von selbst, beim ersten Verkauf in einem neuen Jahr ein Jahresbeleg. Den Jahresbeleg druckt die Kassa von selbst vor dem Bon dieses Verkaufs. Du musst nichts tun. Ist das Erste in einem neuen Jahr aber ein Nullbeleg oder das Ende der Probe (kein Verkauf), druckt die Kassa den Jahresbeleg nicht von selbst. Du kannst ihn in "Bons" antippen und dort auf "Drucken" tippen. Fällt dir so ein Beleg beim normalen Betrieb auf, schreib mir kurz, was du gesehen hast.

## 10. Wenn der QR-Code unlesbar ist oder als Zeichensalat kommt

Nur machen, wenn der QR-Code am Bon fehlt, nur aus Zeichen besteht oder sich nicht lesen lässt.

- [ ] In den Einstellungen in der Karte "Geräte an dieser Kassa" den Schalter "QR-Code als Bild drucken" einschalten. Er steht unter "Bondrucker" und ist nur da, wenn ein Drucker eingerichtet ist.
- [ ] Noch einen Verkauf mit "Bar" machen und den Bon ansehen.

Das solltest du sehen: Der QR-Code kommt jetzt als Bild aus dem Drucker und ist lesbar. Schreib auf, ob es mit dem Schalter besser oder schlechter war.

## 11. Probe beenden

Mach diesen Schritt zuletzt. Er ist für den Test gedacht, nicht für den echten Betrieb.

- [ ] In der Karte "Signatur" bei "Probe beenden" auf "Beenden" tippen.
- [ ] Im Fenster "Probe-Signatur beenden?" noch einmal auf "Beenden" tippen.

Das solltest du sehen: Die Kassa druckt einen Schlussbeleg. Neue Bons haben dann keinen QR-Code mehr. Die Pille zeigt wieder "Nicht eingerichtet". Das Protokoll kannst du danach noch ausgeben.

## Was du mir schickst

- [ ] Den Text des QR-Codes von einem Bon (Schritt 6), und ob "BMF Belegcheck" ihn abgelehnt hat.
- [ ] Die Protokoll-Datei aus Schritt 8.
- [ ] Ob die Datei am gewählten Ort angekommen ist, und was nach "Abbrechen" im Fenster von Android passiert ist.
- [ ] Ob der QR-Code am Bon gut zu lesen war, und ob du den Schalter "QR-Code als Bild drucken" gebraucht hast.
- [ ] Ob dir die neue Anordnung der Einstellungen gefällt.
- [ ] Eine kurze Rückmeldung: Was war unklar, wo hast du gezögert, was hast du erwartet und nicht gesehen?
