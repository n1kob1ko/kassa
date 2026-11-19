# Prüfliste Teil C2: Abgleich, Fotos, Umsätze

Diese Liste ist zum Abhaken am echten Tablet und am Computer, ein paar Punkte auch am Handy. Bei jedem Punkt steht, was du tun sollst und was du sehen solltest. Wenn etwas anders aussieht oder nicht geht: Punkt offen lassen und kurz dazuschreiben, was passiert ist. Ein Foto vom Bildschirm hilft.

Was neu ist: Die Bons, die Tagesabschlüsse, das Bargeld und das Protokoll der Signatur gehen jetzt vom Tablet zum Server. Du siehst sie im Browser, auch am Handy. Preise, "Im Verkauf" und Favoriten gleichen sich in beide Richtungen ab. Im Browser lädst du Fotos für die Artikel und ein Logo hoch, das Tablet zeigt sie. Fehler und "Geräte testen" schickt das Tablet als Bericht an den Server. Und der Server sichert seine Daten jede Nacht.

Wichtig zum Test:

- Die Kassa wartet nie auf den Server. Bonieren, Stornieren und Abschließen gehen immer sofort, auch ohne Internet. Was noch nicht beim Server ist, kommt später nach.
- Alle Bons bleiben Testbons. Auf dem Papier steht weiter "TESTBON". Mach den Test am besten außerhalb der Öffnungszeit.
- Verkaufe nur mit "Bar". Zahlen mit "Karte" gehört nicht zu diesem Test.
- Für einige Punkte musst du am Tablet als Chef angemeldet sein.

Du brauchst: das Tablet mit der Kassa (Version 1.5.0 ist installiert, mit der Online-Probe aus der letzten Liste), den Bondrucker, einen Computer mit Browser, dein Handy, die Adresse der Verwaltung, den geheimen Link zum Laden der neuen Version (von mir), ein Foto von einem Gericht und ein Logo als Bild auf dem Computer (JPEG, PNG oder WebP, bis 10 MB), WLAN.

## 0. Update von 1.5.0 einspielen

- [ ] Bevor du anfängst: am Tablet unter "Bons" nachsehen, wie viele Bons von heute und von gestern da sind, und unter "Artikel" bei zwei Artikeln den Preis aufschreiben.
  Du hast eine kleine Notiz mit Zahlen und Preisen. Damit vergleichst du gleich.
- [ ] Den geheimen Link zum Laden am Tablet öffnen, die Datei laden und antippen. Android fragt, ob die App aktualisiert werden soll: ja.
  Die Kassa startet wie vorher. Deine Bons, Artikel, Preise und Einstellungen sind noch da.
- [ ] Einstellungen öffnen (Regler-Symbol oben rechts) und ganz nach unten sehen.
  Unten links steht "Kassa Version 1.6.0".
- [ ] In der Karte "Server" nachsehen.
  Dort steht "Verbunden mit YICHI als Theke" (oder wie deine Kassa heißt) und "Zuletzt abgeglichen …". Kurz nach dem Start kann darunter "Wartet noch: …" mit einer Zahl stehen. Die Zahl wird kleiner und verschwindet nach ein, zwei Minuten ganz. Bleibt sie stehen: einmal "Jetzt abgleichen" tippen.
- [ ] In der Karte "Signatur" die Pille ansehen und einen Artikel bonieren und bar bezahlen.
  Die Pille zeigt weiter "Online-Probe". Der Bon kommt aus dem Drucker mit QR-Code und "TESTBON", so wie vorher.
- [ ] Im Browser anmelden, YICHI öffnen und auf "Bons" klicken.
  Die Bons, die schon vor dem Update am Tablet waren, stehen da, die neuesten zuerst, jeder mit "Testbon". Die Zahl für heute und gestern passt zu deiner Notiz (dazu kommt der Bon von eben).
- [ ] Auf "Tagesabschlüsse" klicken (am Handy heißt es "Tage").
  Die Tage vom Tablet stehen da, die abgeschlossenen mit "Abschluss" und der Uhrzeit, der laufende mit "offen".
- [ ] Auf "Kassen" klicken.
  Bei deiner Kassa steht "Version 1.6.0" und "Letzter Bon gerade eben" (oder "vor … Minuten"). Darunter "Protokoll der Signatur" mit "Kassen-ID …" und der Zahl der Einträge, dazu "Probe".
- [ ] Auf "Speisekarte" klicken und die zwei Artikel von deiner Notiz suchen.
  Die Preise sind die vom Tablet. Das Update hat nichts zurückgedreht.

Ein Tablet mit Version 1.4.0 lässt sich genauso direkt auf 1.6.0 bringen. Dabei passiert dasselbe.

## 1. Bonieren und im Browser sehen

- [ ] Am Tablet zwei, drei Artikel bonieren und bar bezahlen.
  Alles geht wie immer, ohne Warten.
- [ ] Ein paar Sekunden warten. Dann im Browser die Seite "Bons" neu laden.
  Der neue Bon steht ganz oben, mit Uhrzeit, Kassa, Mitarbeiter und Betrag. Er ist kurz nach dem Bonieren da, ohne dass du am Tablet etwas tippst.
- [ ] Den Bon anklicken.
  Du siehst die Zeilen mit den Optionen, die Summe, "Bar" mit "Gegeben" und "Rückgeld", die Kassa und das Zeichen "Testbon". Bei der Signatur steht "Probe".

## 2. Storno

- [ ] Am Tablet unter "Bons" den Bon aus Punkt 1 öffnen und "Stornieren" tippen, dann bestätigen.
  Der Storno-Bon kommt aus dem Drucker.
- [ ] Im Browser auf "Bons" kurz warten, neu laden und "Nur Stornos" wählen.
  Du siehst zwei Bons: den Storno-Bon und den stornierten Verkauf. Im Detail steht beim einen "Storno" mit dem Link "Zum stornierten Bon", beim anderen "Storniert" mit "Zum Storno-Bon".

## 3. Bargeld-Bewegung

Mach diesen Punkt vor dem Tagesabschluss, dann steht die Bewegung beim selben Tag.

- [ ] Am Tablet oben auf "Abschluss" tippen, dann auf "Bargeld entnehmen" tippen, einen Betrag eintippen (zum Beispiel 20,00 €), als Grund "Bank" wählen und "Entnahme speichern" tippen.
  In der Karte steht "Entnommen: Bank" mit dem Betrag. Das Soll in bar ist um den Betrag kleiner.
- [ ] Im Browser auf "Tagesabschlüsse" den heutigen Tag anklicken.
  Unter "Bewegungen" steht "Entnommen", "Bank", der Betrag, die Uhrzeit und dein Name.

## 4. Tagesabschluss

- [ ] Am Tablet unter "Abschluss" das Bargeld zählen, den gezählten Betrag eintippen, "Weiter" tippen, das Wechselgeld für morgen eintippen und "Tag abschließen" tippen.
  Es steht "Tag abgeschlossen" mit dem Betrag, der entnommen wird, und dem Wechselgeld für morgen.
- [ ] Im Browser auf "Tagesabschlüsse" kurz warten und neu laden.
  Der Tag steht da mit "Abschluss" und der Uhrzeit. Im Detail siehst du "Wechselgeld", "Erwartet", "Gezählt", "Differenz", "In der Lade gelassen" und die Bewegung aus Punkt 3. Die Zahlen sind dieselben wie am Tablet.

## 5. Umsätze am Handy

- [ ] Am Handy die Adresse der Verwaltung öffnen, anmelden und YICHI öffnen.
  Du landest auf "Umsätze". Unten stehen vier Bereiche und "Mehr".
- [ ] "Heute", "7 Tage" und "30 Tage" antippen.
  Du siehst den Umsatz, den Vergleich zum Zeitraum davor (bei "Heute": "… als letzten <Wochentag>"), die Zahl der Bons und Stornos, Balken pro Stunde oder Tag, "Bar und Karte", die meistverkauften Artikel und den Umsatz nach Kategorie. Oben steht "Testbetrieb: Alle Bons sind Testbons." Der Storno aus Punkt 2 zieht den Betrag wieder ab.
- [ ] Auf einen Balken tippen.
  Der Betrag zu diesem Balken erscheint.
- [ ] "Mehr" antippen.
  Ein Blatt mit den übrigen Bereichen geht auf, zum Beispiel "Kassen", "Mitarbeiter" und "Betrieb".

## 6. Preis im Browser ändern und am Tablet sehen

- [ ] Im Browser auf "Speisekarte" bei einem Artikel in das Preisfeld klicken, einen neuen Preis eintippen und Enter drücken.
  Der neue Preis bleibt stehen. Darunter steht kurz "Kommt beim nächsten Abgleich an die Kassa."
- [ ] Am Tablet in den Einstellungen in der Karte "Server" auf "Jetzt abgleichen" tippen.
  Die Taste dreht kurz, dann steht "Zuletzt abgeglichen gerade eben".
- [ ] Zur Kassa gehen und den Artikel ansehen, dann bonieren.
  Die Taste zeigt den neuen Preis, und der Bon rechnet damit. Ohne Tippen kommt der Preis spätestens nach 5 Minuten von selbst.

## 7. Preis am Tablet ändern und im Browser sehen

- [ ] Am Tablet unter "Artikel" einen anderen Artikel öffnen, "Preis ändern" tippen, einen neuen Preis eintippen und "Übernehmen" tippen.
  Der neue Preis steht beim Artikel.
- [ ] Ein paar Sekunden warten. Dann im Browser die Seite "Speisekarte" neu laden.
  Beim Artikel steht der Preis vom Tablet.
- [ ] Am Tablet unter "Artikel" bei einem Artikel "Im Verkauf" ausschalten, kurz warten und im Browser neu laden.
  Im Browser ist "Im Verkauf" bei diesem Artikel auch aus. Danach am Tablet wieder einschalten.

## 8. Foto hochladen

- [ ] Am Tablet in den Einstellungen in der Karte "Anzeige" nachsehen, ob "Artikel mit Bildern" aus ist. Wenn es an ist: ausschalten.
  Der Schalter ist aus. Die Kassa zeigt die Artikel als Tasten ohne Foto.
- [ ] Im Browser auf "Speisekarte" auf das Kamera-Symbol (oder das Foto) beim Artikel klicken, das Foto wählen und "Speichern" klicken.
  Erst siehst du eine Vorschau, dann einen Balken beim Hochladen. Danach steht das Foto in der Zeile des Artikels.
- [ ] Am Tablet "Jetzt abgleichen" tippen und kurz warten. Dann zur Kassa gehen.
  Der Schalter "Artikel mit Bildern" hat sich ein Mal von selbst eingeschaltet. Die Taste des Artikels zeigt das Foto. Es ist scharf und nicht verzerrt.
- [ ] Im Browser das Foto ersetzen (wieder auf das Kamera-Symbol oder das Foto beim Artikel klicken, ein anderes Bild wählen, "Speichern"), am Tablet "Jetzt abgleichen".
  Am Tablet ist das neue Foto zu sehen. Es gibt nie ein halbes oder kaputtes Bild, bis dahin bleibt das alte.
- [ ] Wenn du möchtest: "Artikel mit Bildern" am Tablet wieder ausschalten und noch ein Foto hochladen.
  Der Schalter bleibt jetzt aus. Er schaltet sich nur beim allerersten Foto von selbst ein.

## 9. Logo

- [ ] Im Browser unter "Betrieb" (am Handy unter "Mehr") auf "Logo hinzufügen" klicken, das Logo wählen und "Speichern" klicken.
  Das Logo steht in der Karte "Logo" und oben neben dem Namen von YICHI.
- [ ] Am Tablet "Jetzt abgleichen" tippen und kurz warten.
  Das Logo steht oben in der Kopfleiste der Kassa.
- [ ] Am Tablet oben auf deinen Namen tippen (das meldet dich ab).
  Auch beim Anmelden mit der PIN steht das Logo.

## 10. Ohne Internet bonieren und nachkommen lassen

- [ ] Am Tablet das WLAN ausschalten (und mobile Daten, falls es welche gibt). Zwei Artikel bonieren und bar bezahlen.
  Bonieren geht wie immer. Weil die Online-Probe A-Trust ohne Internet nicht erreicht, ist es wie in der Liste zur Online-Probe: Der erste Verkauf kann ein Mal bis zu 6 Sekunden dauern, oben steht der gelbe Hinweis "Signatur ausgefallen seit …", und unter dem QR-Code steht "Sicherheitseinrichtung ausgefallen". Das ist ohne Internet richtig.
- [ ] In den Einstellungen die Karte "Server" ansehen.
  Dort steht "Wartet noch: …" mit einer Zahl. Nach "Jetzt abgleichen" steht ruhig da: "Der letzte Abgleich hat nicht geklappt. Die Kassa versucht es von selbst wieder."
- [ ] Im Browser die Seite "Bons" neu laden.
  Die zwei Bons sind noch nicht da.
- [ ] Am Tablet das WLAN wieder einschalten und ein, zwei Minuten warten, ohne in der Karte "Server" etwas zu tippen.
  "Wartet noch" verschwindet, der Hinweis in der Karte "Server" ist weg, "Zuletzt abgeglichen" steht auf "gerade eben". Im Browser sind die zwei Bons nach dem Neuladen da.
- [ ] In der Kassa im gelben Hinweis auf "Nochmal prüfen" tippen, bis "Die Signatur geht wieder." erscheint. Ein paar Sekunden warten und im Browser "Bons" neu laden.
  Am Tablet gibt es jetzt einen "Sammelbeleg". Er steht kurz danach auch im Browser.

## 11. Probe-Signatur und Protokoll im Browser

Läuft die Online-Probe noch (Pille "Online-Probe" in der Karte "Signatur"), lass sie laufen und mach gleich beim zweiten Kästchen weiter. Steht "Nicht eingerichtet", schalte zuerst die Probe ein.

- [ ] Nur wenn "Nicht eingerichtet" steht: als Chef in der Karte "Signatur" bei "Zum Ausprobieren einschalten" auf "Einschalten" tippen und einen Artikel bonieren.
  Die Kassa druckt einen Startbeleg. Die Pille zeigt "Probe", der Bon hat einen QR-Code.
- [ ] Im Browser auf "Kassen" (am Handy unter "Mehr") nachsehen.
  Unter "Protokoll der Signatur" steht die Kette mit "Kassen-ID …", der Zahl der Einträge und "Probe". Eine beendete Kette trägt zusätzlich "Beendet".
- [ ] Bei der laufenden Kette auf "Protokoll herunterladen" klicken.
  Der Browser speichert eine Datei mit dem Namen "kassa-protokoll-<Kassen-ID>-kette-<Zahl>.json". Sie ist nicht leer.
- [ ] Am Tablet in der Karte "Signatur" "Protokoll ausgeben" tippen und "Alles" wählen. Die Datei auf den Computer bringen, wenn das leicht geht.
  Wenn du beide Dateien hast: Sie enthalten dieselben Einträge. Wenn das Vergleichen zu mühsam ist, schick mir einfach beide Dateien.

## 12. "Geräte testen" und den Bericht im Browser sehen

- [ ] Am Tablet in den Einstellungen in der Karte "Geräte an dieser Kassa" auf "Geräte testen" tippen. Beim Bondrucker "Testdruck" tippen, bei der Geldlade "Lade öffnen".
  Der Testzettel kommt aus dem Drucker, die Lade geht auf. Bei jeder Zeile steht ein kurzer Satz, wie es gelaufen ist.
- [ ] Ein paar Sekunden warten. Im Browser auf "Alle Betriebe" klicken (am Handy unter "Mehr") und dann auf "Fehlerberichte".
  Oben stehen Zeilen mit "Geräte-Test", "YICHI · Theke" (oder wie deine Kassa heißt) und "1.6.0". Machst du denselben Test mehrmals am Tag, steht eine Zahl wie "×2" dabei.
- [ ] Eine Zeile anklicken.
  Sie klappt auf und zeigt die Geräte mit dem Satz, den das Tablet gezeigt hat. Es stehen keine Bons, Beträge oder Namen von Mitarbeitern darin.

## 13. Letzte Sicherung am nächsten Morgen

- [ ] Am nächsten Morgen (nach 3 Uhr) im Browser über "Alle Betriebe" die Seite "Fehlerberichte" öffnen.
  Oben steht die Karte "Sicherung" mit "Letzte Sicherung: heute, 03:…" und der Größe der Datei. Sie ist ruhig, ohne Warnfarbe.
- [ ] Steht dort "Die letzte Sicherung ist älter als 36 Stunden." oder "Letzter Fehler: …" in Warnfarbe: ein Foto davon an mich.
  Dann schaue ich mir die Sicherung am Server an.

## Was in Stufe 2 bewusst noch nicht geht

- Eine Kassa auf ein Ersatz-Tablet übernehmen (Bons, Nummern, Zählerstand, Kette der Signatur). Der Server sichert schon alles, was dafür nötig ist. Die Übernahme selbst kommt als eigener Schritt vor dem Start bei YICHI.
- Im Browser Artikel anlegen, umbenennen oder verschieben, Kategorien und Auswahl-Vorlagen ändern, Name und Adresse des Betriebs ändern, einen eigenen Zugang für den Chef. Das kommt mit Stufe 3. Bis dahin geht es über "Speisekarte neu einspielen".
- Pfand und Kennzeichen (vegan, scharf) lassen sich nur am Tablet ändern. Sie kommen aber auch beim Server an.
- Fotos für Kategorien.
- Das Logo auf dem gedruckten Bon, eine Anzeige für die Kunden, der Steuersatz 4,9 %.
- Mehrere Kassen in einem Betrieb. Die Daten lassen es zu, geprüft ist es noch nicht.
- Abgleich in Echtzeit oder bei geschlossener App. Die Kassa gleicht ab, solange sie offen ist: kurz nach jedem Bon, alle 5 Minuten, wenn das Internet zurückkommt und wenn du "Jetzt abgleichen" tippst.

## Zum Schluss

- [ ] Eine kurze Rückmeldung an mich: Was war unklar, wo hast du gezögert, was hast du erwartet und nicht gesehen? Auch ein Punkt, der "nur komisch aussah", ist wichtig.
