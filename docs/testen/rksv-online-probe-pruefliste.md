# Prüfliste: Online-Probe mit A-Trust

Dieser Test zeigt, ob die Kassa ihre Bons über das Testsystem von A-Trust signieren kann. A-Trust ist die Firma, die später die echte Signatur liefert. Jeder Bon bekommt einen QR-Code, so wie später im echten Betrieb. Die Unterschrift kommt aber nicht mehr aus dem Tablet, sondern über das Internet von A-Trust. Du brauchst dafür kein Passwort und keine Zugangsdaten. Die Kassa kennt den öffentlichen Test-Zugang von A-Trust selbst.

Diese Liste ist zum Abhaken am echten Tablet. Bei jedem Punkt steht, was du tun sollst und was du sehen solltest. Wenn etwas anders aussieht oder nicht geht: Punkt offen lassen und kurz dazuschreiben, was passiert ist. Ein Foto vom Bildschirm hilft.

Wichtig zum Test:

- Alle Bons bleiben Testbons. Auf dem Papier steht "TESTBON". Sie gelten nicht für das Finanzamt. Mach den Test am besten außerhalb der Öffnungszeit.
- Du musst als Chef angemeldet sein. Nur der Chef sieht die Tasten der Karte "Signatur".
- Diese Version hat keinen Schlüssel für SumUp. Verkaufe darum nur mit "Bar". Zahlen mit "Karte" gehört nicht zu diesem Test.
- Ältere Bons von vor dem Einschalten kannst du danach nicht mehr stornieren. Das ist Absicht.
- Lösch die Kassa oder ihre Daten während des Tests nicht.
- Du musst nichts bei FinanzOnline anmelden. Dieser Test ist nur zum Ausprobieren.

## 1. Was du brauchst

- [ ] Das Tablet mit der Kassa in Version 1.5.0. Ganz unten in den Einstellungen steht "Kassa Version 1.5.0". Du musst vielleicht nach unten wischen.
- [ ] Den Bondrucker, am Strom und mit Papier.
- [ ] Ein Handy mit Kamera, um den QR-Code zu lesen.
- [ ] WLAN am Tablet, das du ausschalten und wieder einschalten kannst (Schritt 7).
- [ ] Ein Blatt Papier oder das Handy zum Aufschreiben.
- [ ] Optional: einen USB-Stick, um das Protokoll in Schritt 11 zu sichern.

Das solltest du sehen: Alles liegt bereit, die Kassa startet wie immer, und die Version stimmt.

## 2. Läuft noch eine Probe?

- [ ] Einstellungen öffnen (Regler-Symbol oben rechts) und in der Karte "Signatur" in der Zeile "Signatur der Bons" die Pille ansehen.

Steht dort "Nicht eingerichtet": weiter mit Schritt 3.

Steht dort "In Betrieb": Stopp, mach den Test nicht. Schreib mir, was dort steht.

Steht dort "Probe" oder "Online-Probe": Du musst die Probe zuerst beenden.

- [ ] In der Karte "Signatur" bei "Probe beenden" auf "Beenden" tippen.
- [ ] Im Fenster "Probe-Signatur beenden?" noch einmal auf "Beenden" tippen.

Das solltest du sehen: Die Kassa druckt einen Schlussbeleg. Die Pille zeigt "Nicht eingerichtet".

## 3. Mit A-Trust ausprobieren

- [ ] In der Karte "Signatur" bei "Mit A-Trust ausprobieren" auf "Ausprobieren" tippen. Die Zeile heißt: "Die Bons werden über das Testsystem von A-Trust signiert. Braucht Internet. Sie bleiben Testbons."
- [ ] Im Fenster "Mit A-Trust ausprobieren?" auf "Weiter" tippen. Mit "Abbrechen" bleibt alles, wie es war.

Das solltest du sehen: Es öffnet sich die Seite "Verbindung prüfen" mit vier Zeilen: "A-Trust", "Zertifikat", "Anmeldung" und "Probe-Unterschrift". Sie werden nacheinander grün, jede mit einem Haken und einem kurzen Satz.

- [ ] Warten, bis alle vier Zeilen einen Haken haben.
- [ ] Aufschreiben, wie lange "A-Trust" und "Probe-Unterschrift" laut Text gedauert haben (zum Beispiel "0,1 Sekunden"). Es steht in Sekunden in der Zeile.

Bei der Zeile "Zertifikat" steht, dass das Test-Zertifikat von A-Trust abgelaufen ist. Das ist für den Test in Ordnung und kein Fehler.

Hat eine Zeile ein Kreuz statt eines Hakens: Foto machen, aufschreiben, welche Zeile es war, und unten auf "Bericht teilen" tippen (wie in Schritt 10). Die Online-Probe fängt dann gar nicht erst an. Danach ist der Test für heute zu Ende.

## 4. Online-Probe starten

- [ ] Unten rechts auf "Online-Probe starten" tippen.

Das solltest du sehen: Die Seite schließt sich, du bist wieder in den Einstellungen. Die Pille in der Zeile "Signatur der Bons" heißt jetzt "Online-Probe". Darunter steht "Signatur vom Testsystem von A-Trust, nicht für den echten Betrieb." mit einer Kassen-ID. Die Kassa druckt einen Startbeleg.

- [ ] Den Startbeleg in die Hand nehmen und ansehen.

Das solltest du sehen: Am Ende des Belegs steht ein quadratischer QR-Code und darunter, ganz zum Schluss, "TESTBON" und "Keine gültige Rechnung".

Die Karte zeigt jetzt auch "Verbindung prüfen", "Nullbeleg drucken", "Protokoll ausgeben" und "Probe beenden".

## 5. Ein Verkauf mit Bon

- [ ] Einen Verkauf mit "Bar" abschließen und den Bon drucken lassen.
- [ ] Den Bon in der Hand halten.

Das solltest du sehen: Am Ende des Bons steht ein quadratischer QR-Code und darunter, ganz zum Schluss, "TESTBON" und "Keine gültige Rechnung".

- [ ] In der Kassa oben auf "Bons" tippen und den Bon antippen.

Das solltest du sehen: Der QR-Code steht auch am Bildschirm, mit dem Satz "Testbon mit Probe-Signatur."

- [ ] Den QR-Code vom gedruckten Bon mit der Kamera oder einer QR-Leser-App am Handy lesen. Der Text beginnt mit `_R1-AT1_`. Ein Foto davon reicht.

Wenn der QR-Code fehlt, nur aus Zeichen besteht oder unlesbar ist: Schalter "QR-Code als Bild drucken" in der Karte "Geräte an dieser Kassa" einschalten (er steht unter "Bondrucker") und noch einen Verkauf machen. Schreib auf, ob es besser wurde.

## 6. Ist der Verkauf langsamer?

- [ ] Noch drei Verkäufe mit "Bar" abschließen und darauf achten, wie lange es nach dem Antippen dauert, bis der Bon da ist.
- [ ] Aufschreiben: War es so schnell wie in der Version vorher, ein bisschen langsamer oder deutlich langsamer? Wie lange ungefähr?

Das solltest du sehen: Der Verkauf geht fast so schnell wie immer. Eine Signatur von A-Trust dauert nur etwa eine Zehntelsekunde.

## 7. WLAN aus: Verkauf ohne Signatur

Jetzt prüfst du, was passiert, wenn A-Trust nicht erreichbar ist. Das Warten beim ersten Mal ist normal:

- Der erste Verkauf, nachdem das Internet weg ist, kann ein Mal bis zu 6 Sekunden warten. Die Kassa gibt A-Trust so lange Zeit zu antworten.
- Alle weiteren Verkäufe während des Ausfalls warten nur etwa 1 Sekunde.

Der Verkauf klappt in jedem Fall, er dauert nur etwas länger.

- [ ] Das WLAN am Tablet ausschalten.
- [ ] Einen Verkauf mit "Bar" abschließen. Mit der Uhr oder dem Handy mitzählen, wie lange es dauert, und aufschreiben.
- [ ] Noch einen Verkauf mit "Bar" abschließen. Auch hier die Dauer aufschreiben.

Das solltest du sehen: Beide Verkäufe gehen durch, der Bon wird gedruckt. In der Kassa steht oben ein gelber Hinweis. Er beginnt mit "Signatur ausgefallen seit" und der Uhrzeit. Darunter steht der Grund, zum Beispiel "Kein Internet.", und der Satz "Du kannst normal weiterverkaufen." Rechts im Hinweis ist die Taste "Nochmal prüfen".

- [ ] Den gedruckten Bon ansehen.

Das solltest du sehen: Unter dem QR-Code steht "Sicherheitseinrichtung ausgefallen", und ganz zum Schluss steht "TESTBON". Die Unterschrift von A-Trust fehlt, darum der Vermerk.

- [ ] Einstellungen öffnen und in der Karte "Signatur" ansehen, ob die Pille jetzt "Online-Probe, Signatur ausgefallen" heißt und der Grund darunter steht.

## 8. WLAN an: Sammelbeleg

- [ ] Das WLAN am Tablet einschalten und warten, bis das Tablet wieder im Netz ist.
- [ ] In der Kassa im gelben Hinweis auf "Nochmal prüfen" tippen.

Das solltest du sehen: Es steht kurz "Die Signatur geht wieder." in einem grünen Hinweis, nach ein paar Sekunden verschwindet er. Steht stattdessen "Geht noch nicht.", warte einen Augenblick und tippe noch einmal. Schreib auf, wie oft du tippen musstest.

- [ ] In "Bons" nachsehen, ob es jetzt einen "Sammelbeleg" gibt.

Das solltest du sehen: Ein Sammelbeleg ist da. Er fasst die Bons ohne Signatur zusammen und ist von A-Trust signiert. Der gelbe Hinweis ist weg, und die Pille in den Einstellungen heißt wieder "Online-Probe".

- [ ] Einen weiteren Verkauf mit "Bar" abschließen. Der Bon hat wieder einen normalen QR-Code, ohne "Sicherheitseinrichtung ausgefallen".

## 9. Die App schließen und wieder öffnen

- [ ] Die Kassa ganz schließen (zum Beispiel über die Übersicht der laufenden Apps nach oben wischen).
- [ ] Die Kassa neu öffnen und als Chef anmelden.
- [ ] Einen Verkauf mit "Bar" abschließen.

Das solltest du sehen: Der Verkauf geht wie vorher, der Bon hat einen QR-Code, und die Pille heißt immer noch "Online-Probe".

## 10. Verbindung prüfen und Bericht teilen

- [ ] In den Einstellungen in der Karte "Signatur" bei "Verbindung prüfen" auf "Prüfen" tippen.

Das solltest du sehen: Die Seite "Verbindung prüfen" mit vier Haken, wie in Schritt 3.

- [ ] Unten auf "Bericht teilen" tippen.
- [ ] Im Fenster von Android eine App wählen und den Text an mich schicken, hier im Chat an mich oder per Mail an dich selbst und dann hier einfügen.

Das solltest du sehen: Der Bericht geht ab. Er enthält die Zeilen, die Zeiten und das Zertifikat von A-Trust, aber kein Passwort. Steht "Teilen geht auf diesem Tablet nicht.", schreib das auf.

- [ ] Auf "Zurück" tippen, um in die Einstellungen zurückzukommen.

## 11. Protokoll ausgeben

Das Protokoll ist eine Datei mit allen signierten Bons.

- [ ] In der Karte "Signatur" bei "Protokoll ausgeben" auf "Ausgeben" tippen.
- [ ] Im Fenster "Protokoll ausgeben" einen Zeitraum wählen. Nimm "Alles".
- [ ] Im Fenster von Android die Datei speichern. Der Name beginnt mit `kassa-protokoll-`. Wähle einen Ort, zum Beispiel einen USB-Stick oder "Downloads".

Das solltest du sehen: Unter der Zeile steht "Gespeichert."

- [ ] Die gespeicherte Datei an mich schicken: hier im Chat als Anhang an eine Nachricht, am Tablet oder nachdem du sie auf das Handy oder den Computer kopiert hast.

Die Datei enthält nur die Bons und ihre Unterschriften. Kein Passwort, keine PIN und keinen geheimen Schlüssel.

## 12. Probe beenden

Mach diesen Schritt zuletzt.

- [ ] In der Karte "Signatur" bei "Probe beenden" auf "Beenden" tippen.
- [ ] Im Fenster "Probe-Signatur beenden?" noch einmal auf "Beenden" tippen.

Das solltest du sehen: Die Kassa druckt einen Schlussbeleg. Neue Bons haben dann keinen QR-Code mehr. Die Pille zeigt wieder "Nicht eingerichtet". Das Protokoll kannst du danach noch ausgeben.

## Was du mir schickst

Hier im Chat:

- [ ] Den Text aus "Bericht teilen" (Schritt 10).
- [ ] Die Protokoll-Datei aus "Protokoll ausgeben" (Schritt 11).
- [ ] Die Dauer aus Schritt 3 ("A-Trust" und "Probe-Unterschrift") und aus Schritt 7 (beide Verkäufe ohne WLAN).
- [ ] Ob die Verkäufe in Schritt 6 langsamer waren als vorher.
- [ ] Wie oft du in Schritt 8 auf "Nochmal prüfen" tippen musstest.
- [ ] Ob der QR-Code am Bon gut zu lesen war.
- [ ] Eine kurze Rückmeldung: Was war unklar, wo hast du gezögert, was hast du erwartet und nicht gesehen?

Du musst mir kein Passwort und keine Zugangsdaten schicken. Die Online-Probe braucht keine.
