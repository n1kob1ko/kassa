# Prüfliste: Karte prüfen

Dieser Test zeigt, ob Tablet, Verteiler, Kartenleser und Signaturkarte zusammenarbeiten. Auf der Karte wird nichts verändert. Der Verkauf bleibt davon unberührt.

Diese Liste ist zum Abhaken am echten Tablet. Bei jedem Punkt steht, was du tun sollst und was du sehen solltest. Wenn etwas anders aussieht oder nicht geht: Punkt offen lassen und kurz dazuschreiben, was passiert ist. Ein Foto vom Bildschirm hilft.

Wichtig zur Karte:

- Die Signaturkarte von YICHI ist die einzige. Nach drei falschen PIN-Eingaben sperrt sie sich. Darum rät man hier nie: Wenn du die PIN nicht sicher weißt, lass Schritt 4 aus.
- Die PIN der Signaturkarte ist nicht die Chef-PIN der Kassa. Sie gehört nie in den Chat, in eine Mail oder in den Bericht. Der Bericht enthält sie auch nicht.
- Die Kassa passt auf den Zähler der Karte auf. Sie merkt sich jeden Versuch, bevor die PIN zur Karte geht, und schickt keine PIN mehr, wenn die Karte nur noch einen Versuch haben könnte. Bricht die Verbindung mitten im Versuch ab, zählt die Kassa den Versuch zur Sicherheit als verbraucht. Was du dann tust, steht in Schritt 5.

## 1. Was du brauchst

- [ ] Das Tablet mit der Kassa in Version 1.3.0. Unten in den Einstellungen steht "Kassa Version 1.3.0".
- [ ] Den Verteiler mit Stromanschluss (er muss am Strom hängen).
- [ ] Den USB-Kartenleser.
- [ ] Die Signaturkarte von YICHI und ihre PIN.
- [ ] Die Karte steckt sonst in der alten Kassa. Teste darum außerhalb der Öffnungszeit, und steck die Karte danach wieder zurück.
- [ ] Tablet, Kartenleser und Drucker hängen am selben Verteiler. Den Drucker brauchst du in Schritt 7.

Das solltest du sehen: Alles liegt bereit, die Kassa startet wie immer, und die Version stimmt.

## 2. Prüfung starten

- [ ] Einstellungen öffnen (Regler-Symbol oben rechts) und in der Karte "Signatur" auf "Karte prüfen" tippen.
- [ ] Die Karte in den Kartenleser stecken, mit dem Chip voran bis zum Anschlag, und den Leser am Verteiler anstecken.
- [ ] Auf "Jetzt prüfen" tippen.
- [ ] Beim ersten Mal fragt Android, ob die Kassa den Kartenleser verwenden darf. Das Fenster darf so lange offen bleiben, wie du brauchst. Antippen: erlauben.

Das solltest du sehen: Die Zeilen werden nacheinander geprüft. Die Zeile "Kartenleser" zeigt einen grünen Haken und den Namen deines Lesers. Die Zeile "Zugriff" zeigt einen grünen Haken und "Die Kassa darf den Kartenleser verwenden."

## 3. Zeilen 1 bis 4 ansehen

- [ ] Prüfen, ob die Zeilen "Kartenleser", "Zugriff", "Signaturkarte" und "Zertifikat" alle einen grünen Haken haben.
- [ ] In der Zeile "Signaturkarte" die Kartenart abschreiben. Sie steht dort, zum Beispiel "a.sign RK CHIP (ACOS-ID 2.1) erkannt."
- [ ] Steht darunter ein Hinweis, dass die Kartenart bis Mai 2027 getauscht werden muss: diese Zeile genau abschreiben und beim Bericht mitschicken. Daran hängt, ob YICHI eine neue Karte braucht.

Das solltest du sehen: Vier grüne Haken. Bei "Zertifikat" steht eine Seriennummer, ein Datum bei "gültig bis" und "Ausgestellt von …". Bis hierher hat die Kassa nie eine PIN zur Karte geschickt.

## 4. PIN eingeben

Nur machen, wenn du die PIN der Signaturkarte sicher weißt.

- [ ] Auf "PIN eingeben" tippen.
- [ ] Im Fenster "PIN der Signaturkarte" die PIN über die Zifferntasten eingeben und "Unterschrift erstellen" antippen.
- [ ] Geht es schief und steht "Die PIN war falsch. Noch 2 Versuche.", nicht raten. Frag im Betrieb nach der richtigen PIN, bevor du es noch einmal versuchst.

Das solltest du sehen: Im Fenster steht der gelbe Hinweis "Das ist nicht deine Chef-PIN. Nach drei falschen Versuchen sperrt sich die Karte." Die Kassa schickt die PIN genau einmal und wiederholt nichts von selbst.

## 5. Probe-Unterschrift ansehen

- [ ] Prüfen, ob die Zeile "Probe-Unterschrift" grün ist.
- [ ] Die Dauer aufschreiben. Sie steht in der Zeile: "Unterschrift erstellt und geprüft. Dauer: … Sekunden."

Das solltest du sehen: Ein grüner Haken und die Dauer in Sekunden. Die Dauer ist wichtig: Sie zeigt, ob die Karte schnell genug für jeden Bon ist.

Wenn dort stattdessen steht "Die Karte hat vermutlich nur noch einen Versuch.", hat die Kassa die Verbindung während eines Versuchs verloren und rechnet den Versuch zur Sicherheit als verbraucht. Sie schickt dann keine PIN mehr, und es erscheint die Taste "Zähler ist wieder voll". So geht es weiter:

1. Steck die Karte zurück in die alte Kassa und erstelle dort einen Bon mit der richtigen PIN. Damit ist der Zähler der Karte wieder voll.
2. Steck die Karte wieder in den Kartenleser. Tippe in der Kassa auf "Zähler ist wieder voll" und bestätige.
3. Bestätige nur, wenn du das wirklich gemacht hast. Stimmt es nicht und die nächste PIN ist falsch, kann sich die Karte sperren.

## 6. Bericht teilen

- [ ] Auf "Bericht teilen" tippen. Ein Fenster von Android öffnet sich.
- [ ] Den Text an mich schicken, in den Thread oder per Mail an dich selbst und dann hier einfügen.

Das solltest du sehen: Der Bericht ist reiner Text. Die PIN steht nicht darin. Steht "Teilen geht auf diesem Tablet nicht.", schreib mir die Zeilen vom Bildschirm ab oder mach ein Foto.

## 7. Gegenprobe: Drucker

- [ ] Den Drucker am selben Verteiler lassen, auch wenn der Kartenleser noch steckt.
- [ ] In den Einstellungen unter "Geräte testen" einen Testdruck machen.

Das solltest du sehen: Der Drucker druckt wie immer. Aufgeschrieben wird, ob er noch gedruckt hat.

## 8. Wenn eine Zeile rot ist

- [ ] Den Hinweis unter der roten Zeile lesen und befolgen (siehe die Tabelle unten).
- [ ] Einmal auf "Nochmal prüfen" tippen.
- [ ] Wenn es wieder rot ist: den Bericht teilen (Schritt 6) und mir schicken.

## Wenn etwas rot ist

| Das steht in der Zeile | Das kannst du tun |
|---|---|
| Kein Kartenleser gefunden. | Steckt der Leser am Verteiler, und hat der Verteiler Strom? |
| Die Kassa darf den Kartenleser nicht verwenden. | Tipp auf "Nochmal prüfen" und erlaube den Zugriff im Fenster von Android. |
| Keine Karte im Leser. | Steck die Karte mit dem Chip voran bis zum Anschlag hinein. |
| Die Karte antwortet nicht. | Dreh die Karte um und steck sie nochmal hinein. |
| Die Karte antwortet, aber die Kassa kennt diese Art nicht. | Die Kassa zeigt dazu eine Antwort der Karte. Teil bitte den Bericht, ich schaue es mir an. |
| Die Verbindung zur Karte ist abgebrochen. | Prüf nochmal. Bleibt es dabei, teil bitte den Bericht. |
| Die PIN war falsch. Noch 2 Versuche. | Nicht raten. Frag im Betrieb nach der richtigen PIN, bevor du es nochmal versuchst. |
| Das hat zu lange gedauert. | Prüf nochmal. Bleibt es dabei, teil bitte den Bericht. |

## Was du mir schickst

- [ ] Den Bericht (Text aus "Bericht teilen").
- [ ] Die Kartenart aus Zeile 3, und wenn dabei ein Hinweis zum Tausch bis Mai 2027 stand, auch diese Zeile.
- [ ] Die Dauer aus Zeile 5.
- [ ] Das Modell des Kartenlesers und des Verteilers. Ein Foto vom Schild genügt.
- [ ] Ob der Drucker in Schritt 7 noch gedruckt hat.
- [ ] Eine kurze Rückmeldung: Was war unklar, wo hast du gezögert, was hast du erwartet und nicht gesehen?
