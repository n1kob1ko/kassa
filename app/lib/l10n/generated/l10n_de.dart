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
}
