# Prüfliste Teil C1: Server, Anmeldung und Koppeln

Diese Liste ist zum Abhaken am echten Tablet und am Computer. Bei jedem Punkt steht, was du tun sollst und was du sehen solltest. Wenn etwas anders aussieht oder nicht geht: Punkt offen lassen und kurz dazuschreiben, was passiert ist. Ein Foto vom Bildschirm hilft.

Was neu ist: Die Kassa kann sich mit einem Server verbinden. Im Browser legst du den Betrieb, die Mitarbeiter und die Kassen an, und das Tablet holt Speisekarte und Mitarbeiter von dort. Das Bonieren bleibt wie bisher, auch ohne Internet.

Wichtig: Noch gehen nur Daten vom Server zum Tablet. Preise, die du am Tablet änderst, und die Bons am Tablet gehen erst mit der nächsten Stufe zum Server. Im Browser kannst du Preise in dieser Stufe auch nicht einzeln ändern, nur mit einer geänderten Speisekarten-Datei über "Speisekarte neu einspielen". Ändere Preise darum vorerst gar nicht. Beim Verbinden in Punkt 5 ersetzt das Tablet seine Speisekarte durch die vom Server: Preise, Favoriten und "Im Verkauf", die du am Tablet eingestellt hast, sind danach so, wie sie in der Datei stehen. Und der Bon trägt weiter den Vermerk "TESTBON": bitte noch nicht für echte Verkäufe verwenden.

Du brauchst: das Tablet mit der Kassa (Version 1.1.0 ist installiert), einen Computer mit Browser, die Adresse, die du von mir bekommst (sie führt zur Verwaltung), den geheimen Link zum Laden der neuen Version und den Link zum Einrichten deines Kontos (beide bekommst du ebenfalls von mir), die Datei `pilot/yichi-speisekarte.json` auf dem Computer, WLAN. Ein zweites Android-Gerät ist für Punkt 8 gut, aber kein Muss. In dieser Liste heißt es "Beispiel", wo du etwas Eigenes eintippst.

## 0. Neue Version installieren

- [ ] Den geheimen Link zum Laden am Tablet öffnen, die Datei laden und antippen. Android fragt, ob die App aktualisiert werden soll: ja.
  Die Kassa startet wie vorher. Deine Bons, Artikel und Einstellungen sind noch da, nichts ist verloren.
- [ ] Oben rechts das Regler-Symbol antippen und ganz nach unten sehen.
  Unten links steht "Kassa Version 1.2.0". In der Karte "Server" steht "Nicht mit dem Server verbunden." und die Taste "Mit Server verbinden".
- [ ] Ein paar Artikel bonieren und bezahlen.
  Es geht alles wie in Version 1.1.0. Wenn die Kassa sich sofort wieder schließt: aufhören und mir Bescheid geben.

## 1. Im Browser anmelden

- [ ] Auf dem Computer den Link zum Einrichten deines Kontos öffnen. Er gilt nur einmal.
  Du siehst "Konto einrichten" mit E-Mail und Passwort.
- [ ] Deine E-Mail-Adresse eintippen, ein Passwort mit mindestens 10 Zeichen (zum Beispiel ein Satz, den du dir merken kannst) und es noch einmal eintippen.
  Du bist angemeldet und siehst die Seite "Betriebe". Noch ist kein Betrieb da.
- [ ] Oben auf "Abmelden" klicken, dann die Adresse der Verwaltung noch einmal öffnen und mit deiner E-Mail und dem Passwort anmelden.
  Beim Anmelden steht "Anmelden" über den Feldern. Danach bist du wieder bei den Betrieben.

## 2. YICHI aus der Datei anlegen

- [ ] Auf "Betrieb anlegen" klicken und die Datei `yichi-speisekarte.json` wählen.
  Die Datei wird geprüft und eingespielt. Wenn etwas in der Datei nicht stimmt, steht eine Liste mit den Stellen da: bitte ein Foto davon.
- [ ] Nachsehen, wo du gelandet bist.
  Du siehst die Seite "Mitarbeiter" von YICHI mit der Meldung "Noch kein Mitarbeiter. Lege zuerst einen Chef an." Unten oder an der Seite stehen "Kassen", "Mitarbeiter" und "Speisekarte". Zuerst kommt der Chef, dann die Kassa: ohne Chef könnte sich am Tablet niemand anmelden.
- [ ] Auf "Speisekarte" klicken.
  Dort stehen die Zahlen: wie viele Artikel, Kategorien und Vorlagen. Sie passen zu deiner Datei.
- [ ] Auf "Kassen" klicken.
  Dort steht "Noch keine Kassa gekoppelt." und "Lege zuerst einen Chef mit PIN an." mit dem Knopf "Zu den Mitarbeitern". "Kassa koppeln" gibt es erst, wenn ein Chef da ist.

## 3. Chef mit PIN anlegen

- [ ] Auf "Zu den Mitarbeitern" (oder auf "Mitarbeiter") klicken.
  Dort steht "Noch kein Mitarbeiter. Lege zuerst einen Chef an."
- [ ] "Mitarbeiter anlegen" anklicken, einen Namen eintippen, bei "Rolle" den Chef wählen, eine PIN aus vier Ziffern eintippen (nimm eine, die du dir merkst, zum Beispiel 4711) und "Anlegen" anklicken.
  Der Chef steht in der Liste. Eine PIN, die schon jemand hat, nimmt die Verwaltung nicht an.

## 4. Code erzeugen

- [ ] Auf "Kassen" klicken und "Kassa koppeln" anklicken.
  Jetzt, mit dem Chef, ist der Knopf da. Ein Fenster fragt nach einem Namen für die Kassa.
- [ ] Einen Namen eintippen, zum Beispiel "Theke", und "Code erzeugen" anklicken.
  Ein Code aus acht Ziffern steht da, dazu die Zeit, die er noch gilt (15 Minuten). Darunter zwei Zeilen: "Neues Tablet: Mit Code koppeln" und "Tablet mit Speisekarte: Einstellungen, Server, Mit Server verbinden". Dein Tablet hat schon eine Speisekarte, für dich gilt also die zweite Zeile. Das Fenster offen lassen.

## 5. Am Tablet koppeln

- [ ] Am Tablet Einstellungen öffnen (Regler-Symbol oben rechts), in der Karte "Server" auf "Mit Server verbinden" tippen.
  Eine Frage erscheint: "Mit dem Server verbinden?". Darunter steht: "Die Speisekarte und die Mitarbeiter kommen danach vom Server. Die Bons auf diesem Tablet bleiben. Ein offener Bon wird geleert, und du meldest dich neu an."
- [ ] Die Frage lesen und "Verbinden" antippen.
  Du siehst "Kopplungscode eingeben" mit acht Feldern und dem Hinweis "Den Code findest du in der Verwaltung unter Kassen."
- [ ] Zuerst einen falschen Code eintippen, zum Beispiel 00000000, und "Koppeln" antippen.
  Es steht rot: "Der Code stimmt nicht oder ist abgelaufen." Das Tablet ist nicht verbunden, nichts hat sich geändert.
- [ ] Jetzt den richtigen Code aus dem Browser eintippen und "Koppeln" antippen.
  Kurz dreht sich ein Kreis auf der Taste, dann steht "Speisekarte wird geladen", dann "Verbunden mit YICHI" und "Dieses Tablet ist jetzt Theke." (oder wie du die Kassa genannt hast). Steht stattdessen "Lege in der Verwaltung zuerst einen Mitarbeiter mit PIN an.", fehlt der Chef aus Punkt 3: Das Tablet hat dann nichts ersetzt. Tippe "Zurück zur Kassa" (die Kassa geht mit der alten Speisekarte und der alten PIN weiter), lege im Browser den Chef an und tippe in der Karte "Server" auf "Speisekarte laden" und dann auf "Laden".
- [ ] Im Browser auf das Fenster mit dem Code sehen.
  Es hat sich geändert: "Kassa gekoppelt", der Name der Kassa und "Verbunden". Auf "Fertig" klicken. In der Liste steht die Kassa mit "Verbunden" und der Version 1.2.0.

## 6. Mit der PIN aus der Verwaltung anmelden

- [ ] Am Tablet weitergehen, bis die Anmeldung mit der PIN kommt. Die PIN des Chefs aus Punkt 3 eintippen.
  Die Kassa geht auf. Oben steht der Name von YICHI, die Speisekarte ist die aus der Datei. Die alte PIN von vorher gilt nicht mehr, nur noch die aus der Verwaltung.
- [ ] Einstellungen öffnen und die Karte "Server" ansehen.
  Dort steht "Verbunden mit YICHI als Theke", "Zuletzt abgeglichen gerade eben" (oder "vor … Minuten") und die Taste "Jetzt abgleichen". Bei "Speisekarte neu einspielen" gibt es keine Taste "Datei wählen" mehr, dort steht "Die Speisekarte kommt vom Server."
- [ ] Einen Artikel bonieren und bezahlen.
  Alles geht wie immer. Die alten Bons von vorher sind noch in der Liste der Bons.

## 7. Mitarbeiter im Browser anlegen und abgleichen

- [ ] Im Browser unter "Mitarbeiter" noch eine Person anlegen: Name, Rolle "Mitarbeiter", eine andere PIN aus vier Ziffern, "Anlegen".
  Die Person steht in der Liste.
- [ ] Am Tablet in den Einstellungen in der Karte "Server" auf "Jetzt abgleichen" tippen.
  Die Taste dreht kurz. Dann steht bei "Zuletzt abgeglichen" wieder "gerade eben".
- [ ] Am Tablet oben auf deinen Namen tippen (das meldet dich ab) und mit der PIN der neuen Person anmelden.
  Die Anmeldung klappt, und oben steht ihr Name. Wenn die PIN nicht geht: einmal mit "Jetzt abgleichen" nachsehen und es mir sagen.
- [ ] Zur Probe im Browser den Namen der neuen Person ändern ("Bearbeiten", neuen Namen, "Speichern"), am Tablet "Jetzt abgleichen" tippen und neu anmelden.
  Oben steht der neue Name.

## 8. Falschen oder benutzten Code ausprobieren

- [ ] Den falschen Code hast du schon in Punkt 5 probiert. Hier der zweite Fall, am besten auf einem zweiten Android-Gerät, auf dem die Kassa 1.2.0 noch nicht verbunden ist: dort den Code aus Punkt 4 eintippen, der schon benutzt wurde.
  Es steht: "Der Code stimmt nicht oder ist abgelaufen." Ein Code gilt nur einmal und nur 15 Minuten.
- [ ] Wenn du kein zweites Gerät hast: diesen Punkt auslassen und kurz dazuschreiben.
  Das ist in Ordnung.

## 9. Kassa sperren und Sperre aufheben

- [ ] Im Browser unter "Kassen" bei deiner Kassa "Sperren" anklicken.
  Eine Frage erscheint: "Theke sperren?" mit dem Satz "Diese Kassa gleicht dann nicht mehr ab. Bonieren geht am Tablet weiter."
- [ ] "Sperren" bestätigen.
  In der Liste steht bei der Kassa "Gesperrt".
- [ ] Am Tablet in den Einstellungen "Jetzt abgleichen" tippen.
  Die Karte "Server" zeigt "Gesperrt" und den Satz "Diese Kassa wurde in der Verwaltung gesperrt." dazu "Bonieren geht weiter. Abgeglichen wird erst wieder, wenn die Sperre aufgehoben ist." Darunter steht die Taste "Nochmal prüfen".
- [ ] Am Tablet einen Artikel bonieren und bezahlen.
  Das geht ganz normal weiter.
- [ ] Im Browser bei der Kassa "Sperre aufheben" anklicken. Am Tablet in der Karte "Server" auf "Nochmal prüfen" tippen.
  Im Browser steht wieder "Verbunden". Am Tablet dreht die Taste kurz, dann zeigt die Karte wieder "Verbunden mit YICHI als Theke" und "Zuletzt abgeglichen gerade eben". Ohne Tippen merkt das Tablet es spätestens nach 5 Minuten von selbst.

## 10. Ohne Internet

- [ ] Am Tablet das WLAN ausschalten (und mobile Daten, falls es welche gibt). Einen Artikel bonieren und bezahlen.
  Bonieren und Bezahlen gehen wie immer. Die Kassa meldet nichts Auffälliges, außer dass Karte ohne Internet nicht geht.
- [ ] In den Einstellungen in der Karte "Server" auf "Jetzt abgleichen" tippen.
  Es kommt kein Absturz und kein langes Warten. Ruhig steht da: "Der letzte Abgleich hat nicht geklappt. Die Kassa versucht es von selbst wieder." "Zuletzt abgeglichen" bleibt bei der alten Zeit stehen.
- [ ] Das WLAN wieder einschalten, ein, zwei Minuten warten und noch einmal "Jetzt abgleichen" tippen.
  Der Hinweis ist weg, "Zuletzt abgeglichen" steht auf "gerade eben".

## Zum Schluss

- [ ] Eine kurze Rückmeldung an mich: Was war unklar, wo hast du gezögert, was hast du erwartet und nicht gesehen? Auch ein Punkt, der "nur komisch aussah", ist wichtig.
