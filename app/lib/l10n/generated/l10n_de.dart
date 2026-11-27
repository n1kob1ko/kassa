// ignore_for_file: deprecated_member_use

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class L10nDe extends L10n {
  L10nDe([String locale = 'de']) : super(locale);

  @override
  String get languageSectionTitle => 'Sprache';

  @override
  String get languageSheetTitle => 'Sprache';

  @override
  String get languageChangeLabel => 'Sprache ändern';

  @override
  String get loginTitle => 'PIN eingeben';

  @override
  String get loginHint => 'Jede Person hat ihre eigene PIN';

  @override
  String get loginWrongPin => 'Diese PIN kennt die Kassa nicht.';

  @override
  String get loginFailed => 'Das hat nicht geklappt. Bitte nochmal versuchen.';

  @override
  String loginDigitsEntered(int filled) {
    return '$filled von 4 Ziffern eingegeben';
  }

  @override
  String get shellTabKassa => 'Kassa';

  @override
  String get shellTabBons => 'Bons';

  @override
  String get shellTabOverview => 'Übersicht';

  @override
  String get shellTabItems => 'Artikel';

  @override
  String get shellTabClose => 'Abschluss';

  @override
  String get shellOffline => 'Kein Internet. Bar bonieren geht weiter.';

  @override
  String shellSwitchStaff(String name) {
    return 'Mitarbeiter wechseln, angemeldet: $name';
  }

  @override
  String get shellSettings => 'Einstellungen';

  @override
  String get uiUndo => 'Rückgängig';

  @override
  String get uiKeypadComma => 'Komma';

  @override
  String get uiKeypadDot => 'Punkt';

  @override
  String get uiKeypadDelete => 'Letzte Ziffer löschen';

  @override
  String get uiReceiptQr => 'QR-Code des Bons';

  @override
  String get uiListSeparator => ', ';

  @override
  String kassaItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Artikel',
    );
    return '$_temp0';
  }

  @override
  String kassaCategoryLabel(String name, String items) {
    return '$name, $items';
  }

  @override
  String get kassaFavorites => 'Favoriten';

  @override
  String get kassaWithImages => 'Mit Bildern';

  @override
  String get kassaCompact => 'Kompakt';

  @override
  String get kassaPlusDeposit => '+ Pfand';

  @override
  String get kassaNotForSale => 'Nicht im Verkauf';

  @override
  String kassaOnReceipt(int count) {
    return '$count auf dem Bon';
  }

  @override
  String get kassaTagVegan => 'VEGAN';

  @override
  String get kassaTagSpicy => 'SCHARF';

  @override
  String kassaOneLess(String name) {
    return 'Eins weniger: $name';
  }

  @override
  String kassaOneMore(String name) {
    return 'Eins mehr: $name';
  }

  @override
  String get kassaReceipt => 'Bon';

  @override
  String get kassaClearCart => 'Bon leeren';

  @override
  String get kassaCartCleared => 'Bon geleert';

  @override
  String get kassaEmptyTitle => 'Noch nichts boniert';

  @override
  String get kassaEmptyHint =>
      'Tippe links auf einen Artikel. Jeder Tipp legt ihn einmal auf den Bon.';

  @override
  String get kassaTotal => 'Summe';

  @override
  String kassaDepositIncluded(String amount) {
    return 'davon Pfand $amount';
  }

  @override
  String kassaTaxIncluded(String amount) {
    return 'inkl. $amount MwSt';
  }

  @override
  String get kassaCash => 'Bar';

  @override
  String get kassaCard => 'Karte';

  @override
  String get kassaCardNotSetUp => 'nicht eingerichtet';

  @override
  String get kassaCardLoggedOut => 'nicht angemeldet';

  @override
  String get kassaCardNoInternet => 'kein Internet';

  @override
  String kassaCardFrom(String amount) {
    return 'ab $amount';
  }

  @override
  String get kassaCancel => 'Abbrechen';

  @override
  String get kassaAddToReceipt => 'Auf den Bon';

  @override
  String kassaStillToChoose(String groups) {
    return 'Noch wählen: $groups';
  }

  @override
  String get kassaPickOne => 'eine Wahl';

  @override
  String get kassaAtMostOne => 'höchstens eine';

  @override
  String kassaAtLeast(int min) {
    return 'mindestens $min';
  }

  @override
  String kassaUpTo(int max) {
    return 'bis zu $max';
  }

  @override
  String get kassaPleaseChoose => 'Bitte wählen';

  @override
  String kassaChosenCount(int count) {
    return '$count gewählt';
  }

  @override
  String kassaOptionChosen(String name) {
    return '$name, gewählt';
  }

  @override
  String get kassaPayCashTitle => 'Bar bezahlen';

  @override
  String get kassaBackToReceipt => 'Zurück zum Bon';

  @override
  String get kassaAmountDue => 'Zu zahlen';

  @override
  String get kassaGiven => 'Gegeben';

  @override
  String get kassaExact => 'Passend';

  @override
  String get kassaOtherAmount => 'Anderer Betrag';

  @override
  String get kassaShowSuggestions => 'Vorschläge zeigen';

  @override
  String get kassaStillMissing => 'Fehlt noch';

  @override
  String get kassaChange => 'Rückgeld';

  @override
  String get kassaSaveFailed =>
      'Der Bon konnte nicht gespeichert werden. Bitte noch einmal.';

  @override
  String get kassaFinish => 'Abschließen';

  @override
  String get kassaFinishAndPrint => 'Abschließen und Bon drucken';

  @override
  String get kassaWaitingForCard => 'Warte auf Karte';

  @override
  String get kassaCardHint => 'Der Kunde hält Karte oder Handy an das Gerät.';

  @override
  String get kassaPaid => 'Bezahlt';

  @override
  String kassaReceiptNumber(int number) {
    return 'Bon Nr. $number';
  }

  @override
  String get kassaPaidExact => 'Passend bezahlt';

  @override
  String get kassaGiveChange => 'Rückgeld geben';

  @override
  String get kassaGiveChangeFromDrawer => 'Rückgeld aus der Lade geben';

  @override
  String get kassaPaidByCard => 'Mit Karte bezahlt';

  @override
  String get kassaNextCustomer => 'Nächster Kunde';

  @override
  String get kassaPrinting => 'Bon wird gedruckt …';

  @override
  String get kassaPrinted => 'Bon gedruckt';

  @override
  String get kassaPrintAgain => 'Nochmal drucken';

  @override
  String get cardAlreadyRunning => 'Es läuft schon eine Kartenzahlung.';

  @override
  String get cardEmptyReceipt => 'Der Bon ist leer.';

  @override
  String cardMinimum(String amount) {
    return 'Kartenzahlung geht erst ab $amount.';
  }

  @override
  String get cardNotStarted =>
      'Die Kartenzahlung konnte nicht gestartet werden.';

  @override
  String get cardDeclined => 'Die Kartenzahlung wurde nicht abgeschlossen.';

  @override
  String get cardCancelled => 'Kartenzahlung abgebrochen.';

  @override
  String get cardNoInternet =>
      'Kein Internet. Kartenzahlung geht gerade nicht.';

  @override
  String get cardNotLoggedIn =>
      'SumUp ist nicht angemeldet. Bitte in den Einstellungen anmelden.';

  @override
  String get cardNoReader =>
      'Kein Kartenleser verbunden. Bitte in den Einstellungen verbinden.';

  @override
  String get cardPermission =>
      'Kassa braucht die Erlaubnis für Bluetooth und Standort.';

  @override
  String get cardFailed => 'Die Kartenzahlung hat nicht geklappt.';

  @override
  String cardFailedDetail(String detail) {
    return 'Die Kartenzahlung hat nicht geklappt. ($detail)';
  }

  @override
  String get printNotSetUp => 'Kein Bondrucker eingerichtet.';

  @override
  String get printUnreachable =>
      'Drucker nicht bereit. Ist er eingeschaltet und verbunden?';

  @override
  String get printNoPermission =>
      'Kassa darf den Drucker nicht verwenden. Bitte die Erlaubnis geben.';

  @override
  String get printPaperOut => 'Drucker nicht bereit. Das Papier ist leer.';

  @override
  String get printCoverOpen => 'Drucker nicht bereit. Der Deckel ist offen.';

  @override
  String get printTimeout => 'Drucker nicht bereit. Er antwortet nicht.';

  @override
  String outageTitle(String since) {
    return 'Signatur ausgefallen seit $since';
  }

  @override
  String get outageSellOn => 'Du kannst normal weiterverkaufen.';

  @override
  String get outageKeepsWorking =>
      'Die Kassa läuft weiter. Bitte dem Chef Bescheid geben.';

  @override
  String get outageRejected =>
      'A-Trust hat die Zugangsdaten abgelehnt. Bitte den Chef holen.';

  @override
  String get outageNotYet => 'Geht noch nicht.';

  @override
  String get outageBack => 'Die Signatur geht wieder.';

  @override
  String get outageRetry => 'Nochmal prüfen';

  @override
  String get outageRepin => 'PIN neu eingeben';

  @override
  String get unclearTitle => 'War diese Kartenzahlung erfolgreich?';

  @override
  String unclearStarted(String time, String name) {
    return 'Gestartet um $time von $name';
  }

  @override
  String unclearMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'und $count weitere',
    );
    return '$_temp0';
  }

  @override
  String unclearNoAnswer(String amount, String time) {
    return 'Die Kassa hat von SumUp keine Antwort bekommen. Schau in der SumUp-App unter Verkäufe nach, ob $amount um $time angekommen ist.';
  }

  @override
  String get unclearUnreadable =>
      'Der Bon lässt sich nicht mehr zusammenstellen, weil sich die Speisekarte geändert hat. Wähle Nein. Ist das Geld bei SumUp angekommen, buche es in der SumUp-App zurück und kassiere neu.';

  @override
  String get unclearFailed => 'Das hat nicht geklappt. Bitte noch einmal.';

  @override
  String get unclearYes => 'Ja, ist angekommen';

  @override
  String get unclearNo => 'Nein, nicht angekommen';

  @override
  String get unclearEffectPaidPrint =>
      'Die Kassa schreibt den Bon als Kartenzahlung und druckt ihn.';

  @override
  String get unclearEffectPaid =>
      'Die Kassa schreibt den Bon als Kartenzahlung.';

  @override
  String get unclearEffectRestore =>
      'Die Kassa verwirft die Zahlung und legt die Artikel wieder auf den Bon.';

  @override
  String get unclearEffectDiscard =>
      'Die Kassa verwirft die Zahlung. Der Bon auf der Kassa bleibt, wie er ist.';

  @override
  String get unclearConfirm => 'Bestätigen';

  @override
  String get unclearBack => 'Zurück';

  @override
  String get dateMonthJanuary => 'Jänner';

  @override
  String get dateMonthFebruary => 'Februar';

  @override
  String get dateMonthMarch => 'März';

  @override
  String get dateMonthApril => 'April';

  @override
  String get dateMonthMay => 'Mai';

  @override
  String get dateMonthJune => 'Juni';

  @override
  String get dateMonthJuly => 'Juli';

  @override
  String get dateMonthAugust => 'August';

  @override
  String get dateMonthSeptember => 'September';

  @override
  String get dateMonthOctober => 'Oktober';

  @override
  String get dateMonthNovember => 'November';

  @override
  String get dateMonthDecember => 'Dezember';

  @override
  String get dateWeekdayMonday => 'Montag';

  @override
  String get dateWeekdayTuesday => 'Dienstag';

  @override
  String get dateWeekdayWednesday => 'Mittwoch';

  @override
  String get dateWeekdayThursday => 'Donnerstag';

  @override
  String get dateWeekdayFriday => 'Freitag';

  @override
  String get dateWeekdaySaturday => 'Samstag';

  @override
  String get dateWeekdaySunday => 'Sonntag';

  @override
  String get dateWeekdayShortMonday => 'Mo.';

  @override
  String get dateWeekdayShortTuesday => 'Di.';

  @override
  String get dateWeekdayShortWednesday => 'Mi.';

  @override
  String get dateWeekdayShortThursday => 'Do.';

  @override
  String get dateWeekdayShortFriday => 'Fr.';

  @override
  String get dateWeekdayShortSaturday => 'Sa.';

  @override
  String get dateWeekdayShortSunday => 'So.';

  @override
  String dateWeekdayDayMonth(String weekday, int day, String month) {
    return '$weekday, $day. $month';
  }

  @override
  String get bonsTitle => 'Bons';

  @override
  String bonsToday(String day) {
    return 'Heute, $day';
  }

  @override
  String bonsDayLabel(String weekday, int day, String month) {
    return '$weekday $day. $month';
  }

  @override
  String get bonsNoneToday => 'Heute gibt es noch keine Bons.';

  @override
  String get bonsNoneForFilter => 'Keine Bons mit diesem Filter.';

  @override
  String get bonsFilterAll => 'Alle';

  @override
  String get bonsCash => 'Bar';

  @override
  String get bonsCard => 'Karte';

  @override
  String get bonsCashAndCard => 'Bar + Karte';

  @override
  String get bonsVoided => 'Storniert';

  @override
  String get bonsVoidReceipt => 'Storno';

  @override
  String get bonsKindStart => 'Startbeleg';

  @override
  String get bonsKindMonth => 'Monatsbeleg';

  @override
  String get bonsKindYear => 'Jahresbeleg';

  @override
  String get bonsKindZero => 'Nullbeleg';

  @override
  String get bonsKindCollective => 'Sammelbeleg';

  @override
  String get bonsKindClosing => 'Schlussbeleg';

  @override
  String bonsNumberShort(int number) {
    return 'Nr. $number';
  }

  @override
  String get bonsPrint => 'Drucken';

  @override
  String get bonsVoid => 'Stornieren';

  @override
  String get bonsNothingSelected => 'Tippe auf einen Bon, um ihn anzusehen.';

  @override
  String bonsTime(String time) {
    return '$time Uhr';
  }

  @override
  String get bonsDeposit => 'Pfand';

  @override
  String bonsTaxRate(int percent) {
    return '$percent % MwSt';
  }

  @override
  String get bonsPayment => 'Zahlung';

  @override
  String bonsVoidOf(String number) {
    return 'Storno zu Bon Nr. $number';
  }

  @override
  String bonsVoidedBy(String name) {
    return 'Storniert von $name';
  }

  @override
  String bonsCreatedBy(String name) {
    return 'Erstellt von $name';
  }

  @override
  String bonsRungUpBy(String name) {
    return 'Boniert von $name';
  }

  @override
  String get bonsVoidedNotCounted =>
      'Storniert. Dieser Bon zählt nicht zum Umsatz.';

  @override
  String bonsVoidedByNotCounted(String name) {
    return 'Storniert von $name. Dieser Bon zählt nicht zum Umsatz.';
  }

  @override
  String bonsCashBoxId(String id) {
    return 'Kassen-ID $id';
  }

  @override
  String get bonsTestReceipt => 'Testbon';

  @override
  String get bonsDeviceFailed => 'Sicherheitseinrichtung ausgefallen';

  @override
  String get bonsProbeSignature => 'Testbon mit Probe-Signatur.';

  @override
  String get bonsQrOnPaper => 'Der QR-Code steht auch am gedruckten Bon.';

  @override
  String get bonsVoidFailed =>
      'Der Storno konnte nicht gespeichert werden. Bitte noch einmal.';

  @override
  String get bonsVoidOlderThanProbe =>
      'Dieser Bon ist älter als die Probe-Signatur und kann nicht storniert werden.';

  @override
  String get bonsVoidFromTestTime =>
      'Dieser Bon stammt aus der Testzeit und kann nicht storniert werden.';

  @override
  String bonsVoidQuestion(int number) {
    return 'Bon Nr. $number wirklich stornieren?';
  }

  @override
  String bonsVoidCashBack(String amount) {
    return 'Du gibst $amount bar zurück.';
  }

  @override
  String get bonsVoidCardHint =>
      'Das Geld geht nicht von selbst zurück. Bitte die Zahlung in der SumUp-App rückbuchen.';

  @override
  String get bonsVoidConfirmCard =>
      'Stornieren, Rückbuchung mache ich in SumUp';

  @override
  String get bonsVoidConfirm => 'Ja, stornieren';

  @override
  String get itemsTitle => 'Artikel';

  @override
  String get itemsWithChoice => 'Mit Auswahl';

  @override
  String itemsPlusDeposit(String amount) {
    return 'plus $amount Pfand';
  }

  @override
  String get itemsColumnItem => 'Artikel';

  @override
  String get itemsPrice => 'Preis';

  @override
  String get itemsFavorite => 'Favorit';

  @override
  String get itemsInSale => 'Im Verkauf';

  @override
  String itemsFavoriteRemove(String name) {
    return '$name aus den Favoriten nehmen';
  }

  @override
  String itemsFavoriteAdd(String name) {
    return '$name zu den Favoriten';
  }

  @override
  String itemsInSaleLabel(String name) {
    return '$name im Verkauf';
  }

  @override
  String get itemsChangePrice => 'Preis ändern';

  @override
  String itemsDepositToggle(String amount) {
    return 'Pfand $amount';
  }

  @override
  String get itemsVegan => 'Vegan';

  @override
  String get itemsSpicy => 'Scharf';

  @override
  String get itemsTaxRate => 'Steuersatz';

  @override
  String get itemsChoiceWhenRinging => 'Auswahl beim Bonieren';

  @override
  String itemsChoiceGroups(String groups) {
    return '$groups.';
  }

  @override
  String get itemsFromMenuFile =>
      'Namen, Fotos und neue Artikel kommen aus der Speisekarten-Datei.';

  @override
  String get itemsWriteFailed =>
      'Das hat nicht geklappt. Bitte nochmal versuchen.';

  @override
  String itemsNewPrice(String amount) {
    return 'Neuer Preis, bisher $amount';
  }

  @override
  String get itemsApply => 'Übernehmen';

  @override
  String get overviewTitle => 'Übersicht';

  @override
  String get overviewRangeToday => 'Heute';

  @override
  String get overviewRange7 => '7 Tage';

  @override
  String get overviewRange30 => '30 Tage';

  @override
  String get overviewLast7 => 'Letzte 7 Tage';

  @override
  String get overviewLast30 => 'Letzte 30 Tage';

  @override
  String overviewHourRange(int from, int to) {
    return '$from bis $to Uhr';
  }

  @override
  String overviewSameAsWeekday(String weekday) {
    return 'Gleich wie letzten $weekday';
  }

  @override
  String overviewMoreThanWeekday(int percent, String weekday) {
    return '$percent % mehr als letzten $weekday';
  }

  @override
  String overviewLessThanWeekday(int percent, String weekday) {
    return '$percent % weniger als letzten $weekday';
  }

  @override
  String overviewSameAsDaysBefore(int days) {
    return 'Gleich wie in den $days Tagen davor';
  }

  @override
  String overviewMoreThanDaysBefore(int percent, int days) {
    return '$percent % mehr als in den $days Tagen davor';
  }

  @override
  String overviewLessThanDaysBefore(int percent, int days) {
    return '$percent % weniger als in den $days Tagen davor';
  }

  @override
  String get overviewRevenue => 'Umsatz';

  @override
  String get overviewReceipts => 'Bons';

  @override
  String get overviewPerReceipt => 'Pro Bon';

  @override
  String get overviewVoids => 'Stornos';

  @override
  String get overviewPerHour => 'Umsatz pro Stunde';

  @override
  String get overviewPerDay => 'Umsatz pro Tag';

  @override
  String get overviewNoneInRange => 'Noch keine Bons in diesem Zeitraum.';

  @override
  String overviewBarLabel(String label, String amount) {
    return '$label, $amount';
  }

  @override
  String get overviewLoadFailed => 'Die Zahlen konnten nicht geladen werden.';

  @override
  String get overviewRetry => 'Nochmal versuchen';

  @override
  String get overviewPayments => 'Zahlungsarten';

  @override
  String get overviewNoReceipts => 'Noch keine Bons.';

  @override
  String get overviewTopItems => 'Meistverkauft';

  @override
  String get overviewByCategory => 'Nach Kategorie';

  @override
  String closeClockTime(String time) {
    return '$time Uhr';
  }

  @override
  String closeBonCount(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted Bons',
      one: '1 Bon',
    );
    return '$_temp0';
  }

  @override
  String get closeReasonBank => 'Bank';

  @override
  String get closeReasonPurchase => 'Einkauf';

  @override
  String get closeReasonChange => 'Wechselgeld';

  @override
  String get closeReasonOther => 'Sonstiges';

  @override
  String get closeCashIn => 'Bargeld einlegen';

  @override
  String get closeCashOut => 'Bargeld entnehmen';

  @override
  String get closeCloseSheet => 'Schließen';

  @override
  String get closeAmount => 'Betrag';

  @override
  String get closeReason => 'Grund';

  @override
  String get closeSaveCashIn => 'Einlage speichern';

  @override
  String get closeSaveCashOut => 'Entnahme speichern';

  @override
  String get closeFloatTitle => 'Wechselgeld';

  @override
  String get closeFloatQuestionDrawer =>
      'Wie viel Wechselgeld war am Morgen in der Lade?';

  @override
  String get closeFloatQuestion => 'Wie viel Wechselgeld war am Morgen da?';

  @override
  String get closeSaveFloat => 'Wechselgeld speichern';

  @override
  String get closeNothingTyped => 'Noch nichts eingetippt';

  @override
  String get closeExact => 'Stimmt genau';

  @override
  String get closeMissing => 'Es fehlen';

  @override
  String get closeTooMuchDrawer => 'Zu viel in der Lade';

  @override
  String get closeTooMuchCash => 'Zu viel Bargeld';

  @override
  String get closeCountDrawer => 'Geldlade zählen';

  @override
  String get closeCountCash => 'Bargeld zählen';

  @override
  String closeStep(int step, int total) {
    return 'Schritt $step von $total';
  }

  @override
  String get closeExpectedDrawer => 'Soll in der Lade';

  @override
  String get closeExpectedCash => 'Soll in bar';

  @override
  String get closeCounted => 'Gezählt';

  @override
  String get closeNext => 'Weiter';

  @override
  String get closeLeaveInDrawer => 'In der Lade lassen';

  @override
  String get closeFloatForTomorrow => 'Wechselgeld für morgen';

  @override
  String get closeDifferenceToExpected => 'Unterschied zum Soll';

  @override
  String get closeLeaveQuestionDrawer =>
      'Wie viel bleibt als Wechselgeld in der Lade?';

  @override
  String get closeLeaveQuestion => 'Wie viel bleibt als Wechselgeld?';

  @override
  String get closeMoreThanCounted =>
      'Mehr als gezählt kann nicht in der Lade bleiben.';

  @override
  String get closeYouTakeOut => 'Du nimmst heraus';

  @override
  String get closeBack => 'Zurück';

  @override
  String get closeCloseDay => 'Tag abschließen';

  @override
  String get closeDayClosed => 'Tag abgeschlossen';

  @override
  String get closeDayIsClosed => 'Der Tag ist abgeschlossen.';

  @override
  String get closeNoOpenDay => 'Es gibt keinen offenen Tag.';

  @override
  String get closeNextDayStarts =>
      'Der nächste Tag beginnt mit dem ersten Bon.';

  @override
  String closeTakenOut(String amount) {
    return 'Entnommen: $amount';
  }

  @override
  String closeTomorrowDrawer(String amount) {
    return 'Morgen liegen $amount Wechselgeld in der Lade.';
  }

  @override
  String closeTomorrow(String amount) {
    return 'Morgen sind $amount Wechselgeld da.';
  }

  @override
  String closeClosedBy(String name, String time) {
    return 'Abgeschlossen von $name um $time';
  }

  @override
  String get closePrintReport => 'Bericht drucken';

  @override
  String get closeToKassa => 'Zur Kassa';

  @override
  String get closeReportPrinted => 'Bericht gedruckt.';

  @override
  String get closeTitle => 'Tagesabschluss';

  @override
  String get closeDay => 'Tag';

  @override
  String get closeMonth => 'Monat';

  @override
  String get closeClosedPill => 'Abgeschlossen';

  @override
  String get closeLoadFailed =>
      'Das hat nicht geklappt. Bitte den Bereich nochmal öffnen.';

  @override
  String get closeDrawer => 'Geldlade';

  @override
  String get closeCash => 'Bargeld';

  @override
  String get closeFloatMorning => 'Wechselgeld am Morgen';

  @override
  String get closeStillOpen => 'Noch offen';

  @override
  String get closeCashTakings => 'Bar-Einnahmen';

  @override
  String closeDeposited(String reason) {
    return 'Eingelegt: $reason';
  }

  @override
  String closeWithdrawn(String reason) {
    return 'Entnommen: $reason';
  }

  @override
  String get closeDifference => 'Unterschied';

  @override
  String get closeIncome => 'Einnahmen';

  @override
  String get closeTotal => 'Gesamt';

  @override
  String get closeTax => 'Steuer';

  @override
  String get closeRevenue => 'Umsatz';

  @override
  String get closeOfWhichVat => 'davon MwSt';

  @override
  String closeVatRate(int percent) {
    return 'MwSt $percent %';
  }

  @override
  String get closeDepositNoVat => 'Pfand, ohne MwSt';

  @override
  String get closeForgotten => 'Der letzte Tag ist noch nicht abgeschlossen.';

  @override
  String get closeNow => 'Jetzt abschließen';

  @override
  String get dateMonthShortJanuary => 'Jän';

  @override
  String get dateMonthShortFebruary => 'Feb';

  @override
  String get dateMonthShortMarch => 'März';

  @override
  String get dateMonthShortApril => 'Apr';

  @override
  String get dateMonthShortMay => 'Mai';

  @override
  String get dateMonthShortJune => 'Juni';

  @override
  String get dateMonthShortJuly => 'Juli';

  @override
  String get dateMonthShortAugust => 'Aug';

  @override
  String get dateMonthShortSeptember => 'Sep';

  @override
  String get dateMonthShortOctober => 'Okt';

  @override
  String get dateMonthShortNovember => 'Nov';

  @override
  String get dateMonthShortDecember => 'Dez';

  @override
  String closeMonthYear(String month, int year) {
    return '$month $year';
  }

  @override
  String closePeriodSameYear(String from, String to, int year) {
    return '$from bis $to $year';
  }

  @override
  String closePeriodTwoYears(String from, String to) {
    return '$from bis $to';
  }

  @override
  String closePeriodDates(String from, String to) {
    return '$from bis $to';
  }

  @override
  String get closeMonthlyReport => 'Monatsabrechnung';

  @override
  String get closeReport => 'Abrechnung';

  @override
  String get closePeriod => 'Zeitraum';

  @override
  String closeFirstMonthlyReport(String date) {
    return 'Die erste Monatsabrechnung gibt es ab $date.';
  }

  @override
  String closeDayMonth(int day, String month) {
    return '$day. $month';
  }

  @override
  String get closeNoReceiptsInPeriod =>
      'In diesem Zeitraum gibt es keine Bons.';

  @override
  String get closeRangeHint => 'Ersten Monat antippen, dann den letzten.';

  @override
  String closeMonthAvailableHint(String month, String date) {
    return '$month geht ab $date, wenn der Monat vorbei ist.';
  }

  @override
  String get closeTestMode => 'Testbetrieb';

  @override
  String get closePeriodPrinted => 'Abrechnung gedruckt.';

  @override
  String get closeSignatureYear => 'Jahresbeleg der Signatur';

  @override
  String get closeSignatureMonth => 'Monatsbeleg der Signatur';

  @override
  String get closeSignatureComes => 'Kommt von selbst mit dem nächsten Bon.';

  @override
  String closeSignatureCreated(String date, String time, int number) {
    return 'Erstellt am $date um $time, Bon Nr. $number';
  }

  @override
  String get closePrint => 'Drucken';

  @override
  String get closeDays => 'Tage';

  @override
  String get closeMonths => 'Monate';

  @override
  String get closeScreenOnly => 'nur am Bildschirm, nicht am Zettel';

  @override
  String get closeAlsoOnPaper => 'stehen auch am Zettel';

  @override
  String get closeOneMonth => 'Ein Monat';

  @override
  String get closeFromTo => 'Von bis';

  @override
  String get closeYearBefore => 'Jahr davor';

  @override
  String get closeYearAfter => 'Jahr danach';

  @override
  String get closeNoPrinter => 'Kein Drucker eingerichtet.';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String settingsRegisterAt(String business) {
    return 'Kassa 1 bei $business';
  }

  @override
  String get settingsDevices => 'Geräte an dieser Kassa';

  @override
  String get settingsDrawer => 'Geldlade';

  @override
  String get settingsDrawerHelp => 'Ausschalten, wenn es keine Geldlade gibt.';

  @override
  String get settingsDeviceTest => 'Geräte testen';

  @override
  String get settingsDeviceTestHelp => 'Testdruck, Lade öffnen.';

  @override
  String get settingsDisplay => 'Anzeige';

  @override
  String get settingsImages => 'Artikel mit Bildern';

  @override
  String get settingsImagesHelp => 'Große Tasten mit Foto.';

  @override
  String get settingsView => 'Ansicht';

  @override
  String get settingsViewHelp =>
      'Dunkel ist angenehmer am Abend und in dunklen Räumen.';

  @override
  String get settingsThemeSystem => 'Wie das Tablet';

  @override
  String get settingsThemeLight => 'Hell';

  @override
  String get settingsThemeDark => 'Dunkel';

  @override
  String get settingsRegister => 'Kassa';

  @override
  String get settingsVoidChef => 'Storno nur durch den Chef';

  @override
  String get settingsVoidChefHelp =>
      'Mitarbeiter können Bons dann nicht stornieren.';

  @override
  String get settingsPayments => 'Zahlen';

  @override
  String get settingsSplitPayment => 'Teil bar, Rest Karte';

  @override
  String get settingsCardTip => 'Trinkgeld bei Kartenzahlung';

  @override
  String get settingsDiscount => 'Rabatt';

  @override
  String get settingsOpenAmount => 'Freier Betrag';

  @override
  String get settingsAccessOff => 'Aus';

  @override
  String get settingsAccessAll => 'Alle';

  @override
  String get settingsAccessChef => 'Nur Chef';

  @override
  String settingsVersion(String version) {
    return 'Kassa Version $version';
  }

  @override
  String get kitchenTitle => 'KÜCHE';

  @override
  String get kitchenVoided => 'STORNO';

  @override
  String get kitchenCopy => 'KOPIE';

  @override
  String get kitchenSample => 'PROBE';

  @override
  String get settingsKitchen => 'Küche';

  @override
  String get settingsKitchenMode => 'Küchenbon';

  @override
  String get settingsKitchenOff => 'Aus';

  @override
  String get settingsKitchenAtReceiptPrinter => 'Am Bondrucker';

  @override
  String get settingsKitchenAtKitchenPrinter => 'Am Küchendrucker';

  @override
  String get settingsKitchenLanguage => 'Sprache am Küchenbon';

  @override
  String get settingsKitchenNoPrinter =>
      'Kein Küchendrucker eingerichtet. Es kommt kein Küchenbon.';

  @override
  String get settingsKitchenCategories => 'Kategorien für die Küche';

  @override
  String get settingsKitchenCategoryOn => 'kommen auf den Küchenbon';

  @override
  String get settingsKitchenCategoryOff => 'kommen nicht auf den Küchenbon';

  @override
  String get settingsKitchenPreview => 'Vorschau';

  @override
  String get settingsKitchenSample => 'Probe drucken';

  @override
  String get settingsKitchenSamplePrinting => 'Druckt …';

  @override
  String get settingsKitchenSamplePrinted => 'Probe gedruckt.';

  @override
  String get kassaKitchenNotPrinted => 'Küchenbon nicht gedruckt';

  @override
  String get kassaKitchenPrint => 'Küchenbon drucken';

  @override
  String get kassaKitchenPrinting => 'Küchenbon wird gedruckt …';

  @override
  String get kassaKitchenPrinted => 'Küchenbon gedruckt.';

  @override
  String get bonsKitchenNothing => 'Auf diesem Bon ist nichts für die Küche.';

  @override
  String get settingsKitchenNoReceiptPrinter =>
      'Kein Bondrucker eingerichtet. Es kommt kein Küchenbon.';

  @override
  String kassaKitchenLateMore(int count) {
    return 'Weitere Küchenbons nicht gedruckt: $count';
  }

  @override
  String get kassaKitchenDismiss => 'Ausblenden';

  @override
  String get tipGuestPays => 'Gast zahlt';

  @override
  String get tipTip => 'Trinkgeld';

  @override
  String get tipNone => 'Ohne Trinkgeld';

  @override
  String tipToTerminal(String amount) {
    return 'Zum Terminal $amount';
  }

  @override
  String tipConfirm(String amount) {
    return 'Trinkgeld $amount?';
  }

  @override
  String get tipConfirmYes => 'Ja, stimmt';

  @override
  String get tipConfirmNo => 'Ändern';

  @override
  String get tipTooLow => 'Der Betrag ist kleiner als die Summe.';

  @override
  String kassaTipDone(String amount) {
    return 'davon Trinkgeld $amount';
  }

  @override
  String unclearTip(String amount) {
    return 'Davon Trinkgeld $amount';
  }

  @override
  String get closeReasonTip => 'Trinkgeld';

  @override
  String get splitWhole => 'Ganzer Betrag';

  @override
  String get splitPart => 'Teil bar';

  @override
  String get splitCashPart => 'Bar-Teil';

  @override
  String get splitRest => 'Rest mit Karte';

  @override
  String splitGo(String amount) {
    return 'Weiter zur Karte $amount';
  }

  @override
  String get splitNeedCash => 'Bar-Teil eingeben.';

  @override
  String splitRestTooSmall(String amount) {
    return 'Rest mit Karte mindestens $amount.';
  }

  @override
  String splitCardFailed(String amount) {
    return 'Karte nicht bezahlt. $amount bar zurückgeben oder noch einmal versuchen.';
  }

  @override
  String kassaCashPartDone(String amount) {
    return 'Bar-Teil $amount';
  }

  @override
  String unclearCashPart(String amount) {
    return 'Bar-Teil $amount ist schon kassiert.';
  }

  @override
  String unclearReturnCash(String amount) {
    return '$amount bar zurückgeben.';
  }

  @override
  String bonsVoidMixedCash(String amount) {
    return '$amount bar zurückgeben.';
  }

  @override
  String bonsVoidCardBack(String amount) {
    return '$amount bei SumUp zurückbuchen.';
  }

  @override
  String bonsVoidCardBackTip(String amount, String tip) {
    return '$amount bei SumUp zurückbuchen, davon $tip Trinkgeld.';
  }

  @override
  String get discountTitle => 'Rabatt';

  @override
  String discountOn(String what) {
    return 'Rabatt auf: $what';
  }

  @override
  String get discountWholeReceipt => 'ganzer Bon';

  @override
  String get discountReason => 'Grund';

  @override
  String get discountReasonRegular => 'Stammgast';

  @override
  String get discountReasonStaff => 'Mitarbeiter';

  @override
  String get discountReasonComplaint => 'Reklamation';

  @override
  String get discountReasonPromotion => 'Aktion';

  @override
  String get discountReasonInvitation => 'Einladung';

  @override
  String get discountHeight => 'Höhe';

  @override
  String get discountAmount => 'Betrag';

  @override
  String get discountNew => 'Neu';

  @override
  String get discountRemove => 'Entfernen';

  @override
  String get discountApply => 'Übernehmen';

  @override
  String get discountLineHint =>
      'Für eine einzelne Zeile die Zeile im Bon antippen.';

  @override
  String discountRowPercent(int percent, String reason) {
    return '−$percent % $reason';
  }

  @override
  String discountRowAmount(String reason) {
    return 'Rabatt $reason';
  }

  @override
  String get openAmountTitle => 'Freier Betrag';

  @override
  String get openAmountAmount => 'Betrag';

  @override
  String get openAmountTax => 'Steuersatz';

  @override
  String get openAmountAdd => 'Auf den Bon';

  @override
  String openAmountLine(int percent) {
    return 'Diverses $percent %';
  }

  @override
  String get closeDiscounts => 'Rabatte';

  @override
  String get closeCardTip => 'Trinkgeld Karte';

  @override
  String get closeCardAccount => 'Am Kartenkonto';

  @override
  String get bonsSubtotal => 'Zwischensumme';

  @override
  String get bonsTipIncluded => 'davon Trinkgeld';
}
