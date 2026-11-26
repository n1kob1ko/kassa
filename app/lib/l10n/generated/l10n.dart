// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'l10n_ar.dart';
import 'l10n_de.dart';
import 'l10n_en.dart';
import 'l10n_tr.dart';
import 'l10n_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('tr'),
    Locale('zh'),
  ];

  /// Überschrift des Abschnitts in den Einstellungen.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get languageSectionTitle;

  /// Titel des Blatts mit den Sprachen am Anmeldebildschirm.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get languageSheetTitle;

  /// Semantik der Sprachtaste am Anmeldebildschirm.
  ///
  /// In de, this message translates to:
  /// **'Sprache ändern'**
  String get languageChangeLabel;

  /// Titel der PIN-Karte am Anmeldebildschirm.
  ///
  /// In de, this message translates to:
  /// **'PIN eingeben'**
  String get loginTitle;

  /// Hinweis unter dem Titel, solange nichts falsch ist.
  ///
  /// In de, this message translates to:
  /// **'Jede Person hat ihre eigene PIN'**
  String get loginHint;

  /// Die getippte PIN gehört zu niemandem.
  ///
  /// In de, this message translates to:
  /// **'Diese PIN kennt die Kassa nicht.'**
  String get loginWrongPin;

  /// Die Prüfung der PIN ist gescheitert (Fehler).
  ///
  /// In de, this message translates to:
  /// **'Das hat nicht geklappt. Bitte nochmal versuchen.'**
  String get loginFailed;

  /// Vorlesehilfe der vier Punkte der PIN.
  ///
  /// In de, this message translates to:
  /// **'{filled} von 4 Ziffern eingegeben'**
  String loginDigitsEntered(int filled);

  /// Reiter: der Verkauf (Kassa).
  ///
  /// In de, this message translates to:
  /// **'Kassa'**
  String get shellTabKassa;

  /// Reiter: die gespeicherten Bons.
  ///
  /// In de, this message translates to:
  /// **'Bons'**
  String get shellTabBons;

  /// Reiter: Übersicht mit Umsatz.
  ///
  /// In de, this message translates to:
  /// **'Übersicht'**
  String get shellTabOverview;

  /// Reiter: Artikel der Speisekarte.
  ///
  /// In de, this message translates to:
  /// **'Artikel'**
  String get shellTabItems;

  /// Reiter: Tages- und Monatsabschluss.
  ///
  /// In de, this message translates to:
  /// **'Abschluss'**
  String get shellTabClose;

  /// Pille in der Kopfleiste ohne Internet.
  ///
  /// In de, this message translates to:
  /// **'Kein Internet. Bar bonieren geht weiter.'**
  String get shellOffline;

  /// Vorlesehilfe der Taste mit dem Namen.
  ///
  /// In de, this message translates to:
  /// **'Mitarbeiter wechseln, angemeldet: {name}'**
  String shellSwitchStaff(String name);

  /// Vorlesehilfe der Taste Einstellungen.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get shellSettings;

  /// Taste im Hinweis unten.
  ///
  /// In de, this message translates to:
  /// **'Rückgängig'**
  String get uiUndo;

  /// Vorlesehilfe der Komma-Taste im Zahlenfeld.
  ///
  /// In de, this message translates to:
  /// **'Komma'**
  String get uiKeypadComma;

  /// Vorlesehilfe der Punkt-Taste im Zahlenfeld.
  ///
  /// In de, this message translates to:
  /// **'Punkt'**
  String get uiKeypadDot;

  /// Vorlesehilfe der Löschtaste im Zahlenfeld.
  ///
  /// In de, this message translates to:
  /// **'Letzte Ziffer löschen'**
  String get uiKeypadDelete;

  /// Vorlesehilfe des QR-Codes am Bon.
  ///
  /// In de, this message translates to:
  /// **'QR-Code des Bons'**
  String get uiReceiptQr;

  /// Trennt Namen in einer Aufzählung (Optionen, fehlende Gruppen).
  ///
  /// In de, this message translates to:
  /// **', '**
  String get uiListSeparator;

  /// Anzahl Artikel (Bon, Artikelfläche).
  ///
  /// In de, this message translates to:
  /// **'{count, plural, other{{count} Artikel}}'**
  String kassaItemCount(int count);

  /// Vorlesehilfe einer Kategorie; items ist kassaItemCount.
  ///
  /// In de, this message translates to:
  /// **'{name}, {items}'**
  String kassaCategoryLabel(String name, String items);

  /// Kategorie mit den Lieblingsartikeln.
  ///
  /// In de, this message translates to:
  /// **'Favoriten'**
  String get kassaFavorites;

  /// Umschalter der Artikelfläche.
  ///
  /// In de, this message translates to:
  /// **'Mit Bildern'**
  String get kassaWithImages;

  /// Umschalter der Artikelfläche.
  ///
  /// In de, this message translates to:
  /// **'Kompakt'**
  String get kassaCompact;

  /// Zusatz auf der Artikeltaste bei Pfand.
  ///
  /// In de, this message translates to:
  /// **'+ Pfand'**
  String get kassaPlusDeposit;

  /// Artikel ist ausgeschaltet.
  ///
  /// In de, this message translates to:
  /// **'Nicht im Verkauf'**
  String get kassaNotForSale;

  /// Vorlesehilfe: so oft liegt er auf dem Bon.
  ///
  /// In de, this message translates to:
  /// **'{count} auf dem Bon'**
  String kassaOnReceipt(int count);

  /// Kennzeichen auf der Artikeltaste.
  ///
  /// In de, this message translates to:
  /// **'VEGAN'**
  String get kassaTagVegan;

  /// Kennzeichen auf der Artikeltaste.
  ///
  /// In de, this message translates to:
  /// **'SCHARF'**
  String get kassaTagSpicy;

  /// Vorlesehilfe der Minus-Taste einer Bonzeile.
  ///
  /// In de, this message translates to:
  /// **'Eins weniger: {name}'**
  String kassaOneLess(String name);

  /// Vorlesehilfe der Plus-Taste einer Bonzeile.
  ///
  /// In de, this message translates to:
  /// **'Eins mehr: {name}'**
  String kassaOneMore(String name);

  /// Titel der Bon-Spalte.
  ///
  /// In de, this message translates to:
  /// **'Bon'**
  String get kassaReceipt;

  /// Taste im Kopf der Bon-Spalte.
  ///
  /// In de, this message translates to:
  /// **'Bon leeren'**
  String get kassaClearCart;

  /// Hinweis nach "Bon leeren".
  ///
  /// In de, this message translates to:
  /// **'Bon geleert'**
  String get kassaCartCleared;

  /// Leerer Bon, Überschrift.
  ///
  /// In de, this message translates to:
  /// **'Noch nichts boniert'**
  String get kassaEmptyTitle;

  /// Leerer Bon, Erklärung. Ohne Richtung, wo die Artikel stehen (in Arabisch rechts).
  ///
  /// In de, this message translates to:
  /// **'Tippe links auf einen Artikel. Jeder Tipp legt ihn einmal auf den Bon.'**
  String get kassaEmptyHint;

  /// Summenzeile des Bons.
  ///
  /// In de, this message translates to:
  /// **'Summe'**
  String get kassaTotal;

  /// Pfand in der Summe; amount wie "0,50 €".
  ///
  /// In de, this message translates to:
  /// **'davon Pfand {amount}'**
  String kassaDepositIncluded(String amount);

  /// Steuer in der Summe; amount wie "1,20 €".
  ///
  /// In de, this message translates to:
  /// **'inkl. {amount} MwSt'**
  String kassaTaxIncluded(String amount);

  /// Große Taste: bar bezahlen.
  ///
  /// In de, this message translates to:
  /// **'Bar'**
  String get kassaCash;

  /// Große Taste: mit Karte bezahlen.
  ///
  /// In de, this message translates to:
  /// **'Karte'**
  String get kassaCard;

  /// Zeile unter "Karte": kein Terminal.
  ///
  /// In de, this message translates to:
  /// **'nicht eingerichtet'**
  String get kassaCardNotSetUp;

  /// Zeile unter "Karte": nicht angemeldet.
  ///
  /// In de, this message translates to:
  /// **'nicht angemeldet'**
  String get kassaCardLoggedOut;

  /// Zeile unter "Karte": kein Internet.
  ///
  /// In de, this message translates to:
  /// **'kein Internet'**
  String get kassaCardNoInternet;

  /// Zeile unter "Karte": Kleinstbetrag.
  ///
  /// In de, this message translates to:
  /// **'ab {amount}'**
  String kassaCardFrom(String amount);

  /// Zusammenstellen abbrechen.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get kassaCancel;

  /// Zusammengestellten Artikel auf den Bon.
  ///
  /// In de, this message translates to:
  /// **'Auf den Bon'**
  String get kassaAddToReceipt;

  /// Taste, solange Pflichtgruppen fehlen; groups sind deren Namen.
  ///
  /// In de, this message translates to:
  /// **'Noch wählen: {groups}'**
  String kassaStillToChoose(String groups);

  /// Gruppe: genau eine Wahl.
  ///
  /// In de, this message translates to:
  /// **'eine Wahl'**
  String get kassaPickOne;

  /// Gruppe: keine oder eine Wahl.
  ///
  /// In de, this message translates to:
  /// **'höchstens eine'**
  String get kassaAtMostOne;

  /// Gruppe: Mindestzahl.
  ///
  /// In de, this message translates to:
  /// **'mindestens {min}'**
  String kassaAtLeast(int min);

  /// Gruppe: Höchstzahl.
  ///
  /// In de, this message translates to:
  /// **'bis zu {max}'**
  String kassaUpTo(int max);

  /// Gruppe: Pflichtwahl fehlt.
  ///
  /// In de, this message translates to:
  /// **'Bitte wählen'**
  String get kassaPleaseChoose;

  /// Gruppe: so viele gewählt.
  ///
  /// In de, this message translates to:
  /// **'{count} gewählt'**
  String kassaChosenCount(int count);

  /// Vorlesehilfe einer gewählten Option.
  ///
  /// In de, this message translates to:
  /// **'{name}, gewählt'**
  String kassaOptionChosen(String name);

  /// Titel der Spalte beim Barzahlen.
  ///
  /// In de, this message translates to:
  /// **'Bar bezahlen'**
  String get kassaPayCashTitle;

  /// Vorlesehilfe des Pfeils zurück.
  ///
  /// In de, this message translates to:
  /// **'Zurück zum Bon'**
  String get kassaBackToReceipt;

  /// Betrag, der zu zahlen ist.
  ///
  /// In de, this message translates to:
  /// **'Zu zahlen'**
  String get kassaAmountDue;

  /// Betrag, den der Kunde gibt.
  ///
  /// In de, this message translates to:
  /// **'Gegeben'**
  String get kassaGiven;

  /// Vorschlag: genau der Betrag.
  ///
  /// In de, this message translates to:
  /// **'Passend'**
  String get kassaExact;

  /// Taste zum Zahlenfeld.
  ///
  /// In de, this message translates to:
  /// **'Anderer Betrag'**
  String get kassaOtherAmount;

  /// Zurück zu den Vorschlägen.
  ///
  /// In de, this message translates to:
  /// **'Vorschläge zeigen'**
  String get kassaShowSuggestions;

  /// Zu wenig gegeben: so viel fehlt.
  ///
  /// In de, this message translates to:
  /// **'Fehlt noch'**
  String get kassaStillMissing;

  /// Rückgeld beim Bezahlen.
  ///
  /// In de, this message translates to:
  /// **'Rückgeld'**
  String get kassaChange;

  /// Der Bon wurde nicht gespeichert.
  ///
  /// In de, this message translates to:
  /// **'Der Bon konnte nicht gespeichert werden. Bitte noch einmal.'**
  String get kassaSaveFailed;

  /// Verkauf abschließen, ohne Drucker.
  ///
  /// In de, this message translates to:
  /// **'Abschließen'**
  String get kassaFinish;

  /// Verkauf abschließen, mit Drucker.
  ///
  /// In de, this message translates to:
  /// **'Abschließen und Bon drucken'**
  String get kassaFinishAndPrint;

  /// Titel, solange das Terminal arbeitet.
  ///
  /// In de, this message translates to:
  /// **'Warte auf Karte'**
  String get kassaWaitingForCard;

  /// Erklärung, solange das Terminal arbeitet.
  ///
  /// In de, this message translates to:
  /// **'Der Kunde hält Karte oder Handy an das Gerät.'**
  String get kassaCardHint;

  /// Verkauf fertig: Überschrift.
  ///
  /// In de, this message translates to:
  /// **'Bezahlt'**
  String get kassaPaid;

  /// Verkauf fertig: Nummer des Bons.
  ///
  /// In de, this message translates to:
  /// **'Bon Nr. {number}'**
  String kassaReceiptNumber(int number);

  /// Verkauf fertig: kein Rückgeld.
  ///
  /// In de, this message translates to:
  /// **'Passend bezahlt'**
  String get kassaPaidExact;

  /// Verkauf fertig: Rückgeld herausgeben.
  ///
  /// In de, this message translates to:
  /// **'Rückgeld geben'**
  String get kassaGiveChange;

  /// Verkauf fertig: Rückgeld, mit Geldlade.
  ///
  /// In de, this message translates to:
  /// **'Rückgeld aus der Lade geben'**
  String get kassaGiveChangeFromDrawer;

  /// Verkauf fertig: mit Karte bezahlt.
  ///
  /// In de, this message translates to:
  /// **'Mit Karte bezahlt'**
  String get kassaPaidByCard;

  /// Verkauf fertig: zurück zur leeren Kassa.
  ///
  /// In de, this message translates to:
  /// **'Nächster Kunde'**
  String get kassaNextCustomer;

  /// Der Bon wird gerade gedruckt.
  ///
  /// In de, this message translates to:
  /// **'Bon wird gedruckt …'**
  String get kassaPrinting;

  /// Der Bon ist gedruckt.
  ///
  /// In de, this message translates to:
  /// **'Bon gedruckt'**
  String get kassaPrinted;

  /// Taste nach einem Druckfehler.
  ///
  /// In de, this message translates to:
  /// **'Nochmal drucken'**
  String get kassaPrintAgain;

  /// Kartenzahlung: es läuft schon eine.
  ///
  /// In de, this message translates to:
  /// **'Es läuft schon eine Kartenzahlung.'**
  String get cardAlreadyRunning;

  /// Kartenzahlung: der Bon ist leer.
  ///
  /// In de, this message translates to:
  /// **'Der Bon ist leer.'**
  String get cardEmptyReceipt;

  /// Kartenzahlung: unter dem Kleinstbetrag.
  ///
  /// In de, this message translates to:
  /// **'Kartenzahlung geht erst ab {amount}.'**
  String cardMinimum(String amount);

  /// Kartenzahlung: ließ sich nicht starten.
  ///
  /// In de, this message translates to:
  /// **'Die Kartenzahlung konnte nicht gestartet werden.'**
  String get cardNotStarted;

  /// Kartenzahlung: nicht abgeschlossen.
  ///
  /// In de, this message translates to:
  /// **'Die Kartenzahlung wurde nicht abgeschlossen.'**
  String get cardDeclined;

  /// Kartenzahlung: abgebrochen.
  ///
  /// In de, this message translates to:
  /// **'Kartenzahlung abgebrochen.'**
  String get cardCancelled;

  /// Kartenzahlung: kein Internet.
  ///
  /// In de, this message translates to:
  /// **'Kein Internet. Kartenzahlung geht gerade nicht.'**
  String get cardNoInternet;

  /// Kartenzahlung: SumUp nicht angemeldet.
  ///
  /// In de, this message translates to:
  /// **'SumUp ist nicht angemeldet. Bitte in den Einstellungen anmelden.'**
  String get cardNotLoggedIn;

  /// Kartenzahlung: kein Kartenleser.
  ///
  /// In de, this message translates to:
  /// **'Kein Kartenleser verbunden. Bitte in den Einstellungen verbinden.'**
  String get cardNoReader;

  /// Kartenzahlung: Erlaubnis fehlt.
  ///
  /// In de, this message translates to:
  /// **'Kassa braucht die Erlaubnis für Bluetooth und Standort.'**
  String get cardPermission;

  /// Kartenzahlung: anderer Fehler.
  ///
  /// In de, this message translates to:
  /// **'Die Kartenzahlung hat nicht geklappt.'**
  String get cardFailed;

  /// Kartenzahlung: anderer Fehler; detail ist der Text des Anbieters.
  ///
  /// In de, this message translates to:
  /// **'Die Kartenzahlung hat nicht geklappt. ({detail})'**
  String cardFailedDetail(String detail);

  /// Drucker: keiner eingerichtet.
  ///
  /// In de, this message translates to:
  /// **'Kein Bondrucker eingerichtet.'**
  String get printNotSetUp;

  /// Drucker: nicht erreichbar.
  ///
  /// In de, this message translates to:
  /// **'Drucker nicht bereit. Ist er eingeschaltet und verbunden?'**
  String get printUnreachable;

  /// Drucker: Erlaubnis fehlt.
  ///
  /// In de, this message translates to:
  /// **'Kassa darf den Drucker nicht verwenden. Bitte die Erlaubnis geben.'**
  String get printNoPermission;

  /// Drucker: Papier leer.
  ///
  /// In de, this message translates to:
  /// **'Drucker nicht bereit. Das Papier ist leer.'**
  String get printPaperOut;

  /// Drucker: Deckel offen.
  ///
  /// In de, this message translates to:
  /// **'Drucker nicht bereit. Der Deckel ist offen.'**
  String get printCoverOpen;

  /// Drucker: antwortet nicht.
  ///
  /// In de, this message translates to:
  /// **'Drucker nicht bereit. Er antwortet nicht.'**
  String get printTimeout;

  /// Überschrift; since ist "13:05" oder an einem anderen Tag "16.11. 18:30".
  ///
  /// In de, this message translates to:
  /// **'Signatur ausgefallen seit {since}'**
  String outageTitle(String since);

  /// Fester Satz unter dem Grund, wenn der Grund in der Bediensprache steht.
  ///
  /// In de, this message translates to:
  /// **'Du kannst normal weiterverkaufen.'**
  String get outageSellOn;

  /// Fester Satz unter dem Grund, wenn der Grund (aus der Signatur, immer Deutsch) nicht in der Bediensprache steht.
  ///
  /// In de, this message translates to:
  /// **'Die Kassa läuft weiter. Bitte dem Chef Bescheid geben.'**
  String get outageKeepsWorking;

  /// Statt des Grunds: A-Trust lehnt ab.
  ///
  /// In de, this message translates to:
  /// **'A-Trust hat die Zugangsdaten abgelehnt. Bitte den Chef holen.'**
  String get outageRejected;

  /// Ergebnis von "Nochmal prüfen": geht nicht.
  ///
  /// In de, this message translates to:
  /// **'Geht noch nicht.'**
  String get outageNotYet;

  /// Ergebnis von "Nochmal prüfen": geht wieder.
  ///
  /// In de, this message translates to:
  /// **'Die Signatur geht wieder.'**
  String get outageBack;

  /// Taste im Hinweis.
  ///
  /// In de, this message translates to:
  /// **'Nochmal prüfen'**
  String get outageRetry;

  /// Taste im Hinweis für den Chef.
  ///
  /// In de, this message translates to:
  /// **'PIN neu eingeben'**
  String get outageRepin;

  /// Blatt zur unklaren Kartenzahlung: Frage.
  ///
  /// In de, this message translates to:
  /// **'War diese Kartenzahlung erfolgreich?'**
  String get unclearTitle;

  /// Wann und von wem; time wie "14:32".
  ///
  /// In de, this message translates to:
  /// **'Gestartet um {time} von {name}'**
  String unclearStarted(String time, String name);

  /// Weitere Zeilen des Bons, die nicht dastehen.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, other{und {count} weitere}}'**
  String unclearMore(int count);

  /// Hinweis; "Verkäufe" ist der Menüpunkt der SumUp-App in ihrer Sprache.
  ///
  /// In de, this message translates to:
  /// **'Die Kassa hat von SumUp keine Antwort bekommen. Schau in der SumUp-App unter Verkäufe nach, ob {amount} um {time} angekommen ist.'**
  String unclearNoAnswer(String amount, String time);

  /// Der Bon lässt sich nicht mehr bauen.
  ///
  /// In de, this message translates to:
  /// **'Der Bon lässt sich nicht mehr zusammenstellen, weil sich die Speisekarte geändert hat. Wähle Nein. Ist das Geld bei SumUp angekommen, buche es in der SumUp-App zurück und kassiere neu.'**
  String get unclearUnreadable;

  /// Entscheiden ist gescheitert.
  ///
  /// In de, this message translates to:
  /// **'Das hat nicht geklappt. Bitte noch einmal.'**
  String get unclearFailed;

  /// Taste: das Geld ist angekommen.
  ///
  /// In de, this message translates to:
  /// **'Ja, ist angekommen'**
  String get unclearYes;

  /// Taste: das Geld ist nicht angekommen.
  ///
  /// In de, this message translates to:
  /// **'Nein, nicht angekommen'**
  String get unclearNo;

  /// Folge von "Ja", mit Drucker.
  ///
  /// In de, this message translates to:
  /// **'Die Kassa schreibt den Bon als Kartenzahlung und druckt ihn.'**
  String get unclearEffectPaidPrint;

  /// Folge von "Ja", ohne Drucker.
  ///
  /// In de, this message translates to:
  /// **'Die Kassa schreibt den Bon als Kartenzahlung.'**
  String get unclearEffectPaid;

  /// Folge von "Nein": Artikel zurück.
  ///
  /// In de, this message translates to:
  /// **'Die Kassa verwirft die Zahlung und legt die Artikel wieder auf den Bon.'**
  String get unclearEffectRestore;

  /// Folge von "Nein": Bon bleibt.
  ///
  /// In de, this message translates to:
  /// **'Die Kassa verwirft die Zahlung. Der Bon auf der Kassa bleibt, wie er ist.'**
  String get unclearEffectDiscard;

  /// Taste: Entscheidung bestätigen.
  ///
  /// In de, this message translates to:
  /// **'Bestätigen'**
  String get unclearConfirm;

  /// Taste: zurück zur Frage.
  ///
  /// In de, this message translates to:
  /// **'Zurück'**
  String get unclearBack;

  /// Name des 1. Monats am Bildschirm (Österreich: Jänner).
  ///
  /// In de, this message translates to:
  /// **'Jänner'**
  String get dateMonthJanuary;

  /// Name des 2. Monats am Bildschirm (Österreich: Jänner).
  ///
  /// In de, this message translates to:
  /// **'Februar'**
  String get dateMonthFebruary;

  /// Name des 3. Monats am Bildschirm (Österreich: Jänner).
  ///
  /// In de, this message translates to:
  /// **'März'**
  String get dateMonthMarch;

  /// Name des 4. Monats am Bildschirm (Österreich: Jänner).
  ///
  /// In de, this message translates to:
  /// **'April'**
  String get dateMonthApril;

  /// Name des 5. Monats am Bildschirm (Österreich: Jänner).
  ///
  /// In de, this message translates to:
  /// **'Mai'**
  String get dateMonthMay;

  /// Name des 6. Monats am Bildschirm (Österreich: Jänner).
  ///
  /// In de, this message translates to:
  /// **'Juni'**
  String get dateMonthJune;

  /// Name des 7. Monats am Bildschirm (Österreich: Jänner).
  ///
  /// In de, this message translates to:
  /// **'Juli'**
  String get dateMonthJuly;

  /// Name des 8. Monats am Bildschirm (Österreich: Jänner).
  ///
  /// In de, this message translates to:
  /// **'August'**
  String get dateMonthAugust;

  /// Name des 9. Monats am Bildschirm (Österreich: Jänner).
  ///
  /// In de, this message translates to:
  /// **'September'**
  String get dateMonthSeptember;

  /// Name des 10. Monats am Bildschirm (Österreich: Jänner).
  ///
  /// In de, this message translates to:
  /// **'Oktober'**
  String get dateMonthOctober;

  /// Name des 11. Monats am Bildschirm (Österreich: Jänner).
  ///
  /// In de, this message translates to:
  /// **'November'**
  String get dateMonthNovember;

  /// Name des 12. Monats am Bildschirm (Österreich: Jänner).
  ///
  /// In de, this message translates to:
  /// **'Dezember'**
  String get dateMonthDecember;

  /// Name des 1. Wochentags (Montag zuerst).
  ///
  /// In de, this message translates to:
  /// **'Montag'**
  String get dateWeekdayMonday;

  /// Name des 2. Wochentags (Montag zuerst).
  ///
  /// In de, this message translates to:
  /// **'Dienstag'**
  String get dateWeekdayTuesday;

  /// Name des 3. Wochentags (Montag zuerst).
  ///
  /// In de, this message translates to:
  /// **'Mittwoch'**
  String get dateWeekdayWednesday;

  /// Name des 4. Wochentags (Montag zuerst).
  ///
  /// In de, this message translates to:
  /// **'Donnerstag'**
  String get dateWeekdayThursday;

  /// Name des 5. Wochentags (Montag zuerst).
  ///
  /// In de, this message translates to:
  /// **'Freitag'**
  String get dateWeekdayFriday;

  /// Name des 6. Wochentags (Montag zuerst).
  ///
  /// In de, this message translates to:
  /// **'Samstag'**
  String get dateWeekdaySaturday;

  /// Name des 7. Wochentags (Montag zuerst).
  ///
  /// In de, this message translates to:
  /// **'Sonntag'**
  String get dateWeekdaySunday;

  /// Kurzform des 1. Wochentags (Montag zuerst), z. B. in der Tagesliste.
  ///
  /// In de, this message translates to:
  /// **'Mo.'**
  String get dateWeekdayShortMonday;

  /// Kurzform des 2. Wochentags (Montag zuerst), z. B. in der Tagesliste.
  ///
  /// In de, this message translates to:
  /// **'Di.'**
  String get dateWeekdayShortTuesday;

  /// Kurzform des 3. Wochentags (Montag zuerst), z. B. in der Tagesliste.
  ///
  /// In de, this message translates to:
  /// **'Mi.'**
  String get dateWeekdayShortWednesday;

  /// Kurzform des 4. Wochentags (Montag zuerst), z. B. in der Tagesliste.
  ///
  /// In de, this message translates to:
  /// **'Do.'**
  String get dateWeekdayShortThursday;

  /// Kurzform des 5. Wochentags (Montag zuerst), z. B. in der Tagesliste.
  ///
  /// In de, this message translates to:
  /// **'Fr.'**
  String get dateWeekdayShortFriday;

  /// Kurzform des 6. Wochentags (Montag zuerst), z. B. in der Tagesliste.
  ///
  /// In de, this message translates to:
  /// **'Sa.'**
  String get dateWeekdayShortSaturday;

  /// Kurzform des 7. Wochentags (Montag zuerst), z. B. in der Tagesliste.
  ///
  /// In de, this message translates to:
  /// **'So.'**
  String get dateWeekdayShortSunday;

  /// Datum mit Wochentag und Monatsnamen, z. B. "Dienstag, 17. November". Tag als Ziffern.
  ///
  /// In de, this message translates to:
  /// **'{weekday}, {day}. {month}'**
  String dateWeekdayDayMonth(String weekday, int day, String month);

  /// Überschrift des Bereichs Bons.
  ///
  /// In de, this message translates to:
  /// **'Bons'**
  String get bonsTitle;

  /// Untertitel: der Tag der Liste ist heute; day ist bonsDayLabel.
  ///
  /// In de, this message translates to:
  /// **'Heute, {day}'**
  String bonsToday(String day);

  /// Tag der Liste im Untertitel, z. B. "Dienstag 17. November".
  ///
  /// In de, this message translates to:
  /// **'{weekday} {day}. {month}'**
  String bonsDayLabel(String weekday, int day, String month);

  /// Leere Liste: heute noch kein Bon.
  ///
  /// In de, this message translates to:
  /// **'Heute gibt es noch keine Bons.'**
  String get bonsNoneToday;

  /// Leere Liste: kein Bon passt zum Filter.
  ///
  /// In de, this message translates to:
  /// **'Keine Bons mit diesem Filter.'**
  String get bonsNoneForFilter;

  /// Filter: alle Bons.
  ///
  /// In de, this message translates to:
  /// **'Alle'**
  String get bonsFilterAll;

  /// Filter, Pille und Zahlung: bar.
  ///
  /// In de, this message translates to:
  /// **'Bar'**
  String get bonsCash;

  /// Filter, Pille und Zahlung: Karte.
  ///
  /// In de, this message translates to:
  /// **'Karte'**
  String get bonsCard;

  /// Filter und Pille: stornierter Bon.
  ///
  /// In de, this message translates to:
  /// **'Storniert'**
  String get bonsVoided;

  /// Pille eines Storno-Bons.
  ///
  /// In de, this message translates to:
  /// **'Storno'**
  String get bonsVoidReceipt;

  /// Art des Sonderbelegs (RKSV).
  ///
  /// In de, this message translates to:
  /// **'Startbeleg'**
  String get bonsKindStart;

  /// Art des Sonderbelegs (RKSV).
  ///
  /// In de, this message translates to:
  /// **'Monatsbeleg'**
  String get bonsKindMonth;

  /// Art des Sonderbelegs (RKSV).
  ///
  /// In de, this message translates to:
  /// **'Jahresbeleg'**
  String get bonsKindYear;

  /// Art des Sonderbelegs (RKSV).
  ///
  /// In de, this message translates to:
  /// **'Nullbeleg'**
  String get bonsKindZero;

  /// Art des Sonderbelegs (RKSV).
  ///
  /// In de, this message translates to:
  /// **'Sammelbeleg'**
  String get bonsKindCollective;

  /// Art des Sonderbelegs (RKSV).
  ///
  /// In de, this message translates to:
  /// **'Schlussbeleg'**
  String get bonsKindClosing;

  /// Nummer in der Liste.
  ///
  /// In de, this message translates to:
  /// **'Nr. {number}'**
  String bonsNumberShort(int number);

  /// Taste: Bon noch einmal drucken.
  ///
  /// In de, this message translates to:
  /// **'Drucken'**
  String get bonsPrint;

  /// Taste: Bon stornieren.
  ///
  /// In de, this message translates to:
  /// **'Stornieren'**
  String get bonsVoid;

  /// Spalte rechts, solange kein Bon gewählt ist.
  ///
  /// In de, this message translates to:
  /// **'Tippe auf einen Bon, um ihn anzusehen.'**
  String get bonsNothingSelected;

  /// Uhrzeit im Kopf des Bons; time ist "11:05".
  ///
  /// In de, this message translates to:
  /// **'{time} Uhr'**
  String bonsTime(String time);

  /// Zeile Pfand im Bon.
  ///
  /// In de, this message translates to:
  /// **'Pfand'**
  String get bonsDeposit;

  /// Steuerzeile im Bon.
  ///
  /// In de, this message translates to:
  /// **'{percent} % MwSt'**
  String bonsTaxRate(int percent);

  /// Zeile Zahlungsart im Bon.
  ///
  /// In de, this message translates to:
  /// **'Zahlung'**
  String get bonsPayment;

  /// Storno-Bon: zu welchem Bon; number ist die Nummer oder "?".
  ///
  /// In de, this message translates to:
  /// **'Storno zu Bon Nr. {number}'**
  String bonsVoidOf(String number);

  /// Wer den Storno-Bon gemacht hat.
  ///
  /// In de, this message translates to:
  /// **'Storniert von {name}'**
  String bonsVoidedBy(String name);

  /// Wer den Sonderbeleg erstellt hat.
  ///
  /// In de, this message translates to:
  /// **'Erstellt von {name}'**
  String bonsCreatedBy(String name);

  /// Wer den Verkauf boniert hat.
  ///
  /// In de, this message translates to:
  /// **'Boniert von {name}'**
  String bonsRungUpBy(String name);

  /// Stornierter Bon, ohne bekannten Storno-Bon.
  ///
  /// In de, this message translates to:
  /// **'Storniert. Dieser Bon zählt nicht zum Umsatz.'**
  String get bonsVoidedNotCounted;

  /// Stornierter Bon mit der Person des Stornos.
  ///
  /// In de, this message translates to:
  /// **'Storniert von {name}. Dieser Bon zählt nicht zum Umsatz.'**
  String bonsVoidedByNotCounted(String name);

  /// Kassen-ID der Signatur unter dem QR-Code.
  ///
  /// In de, this message translates to:
  /// **'Kassen-ID {id}'**
  String bonsCashBoxId(String id);

  /// Kennzeichen Testbon (Probe der Signatur).
  ///
  /// In de, this message translates to:
  /// **'Testbon'**
  String get bonsTestReceipt;

  /// Die Signatur war beim Bon ausgefallen.
  ///
  /// In de, this message translates to:
  /// **'Sicherheitseinrichtung ausgefallen'**
  String get bonsDeviceFailed;

  /// Testbon mit Probe-Signatur.
  ///
  /// In de, this message translates to:
  /// **'Testbon mit Probe-Signatur.'**
  String get bonsProbeSignature;

  /// Hinweis unter dem QR-Code.
  ///
  /// In de, this message translates to:
  /// **'Der QR-Code steht auch am gedruckten Bon.'**
  String get bonsQrOnPaper;

  /// Storno nicht gespeichert.
  ///
  /// In de, this message translates to:
  /// **'Der Storno konnte nicht gespeichert werden. Bitte noch einmal.'**
  String get bonsVoidFailed;

  /// Bon nicht in der Kette der Probe-Signatur.
  ///
  /// In de, this message translates to:
  /// **'Dieser Bon ist älter als die Probe-Signatur und kann nicht storniert werden.'**
  String get bonsVoidOlderThanProbe;

  /// Bon aus der Testzeit, Kassa in Betrieb.
  ///
  /// In de, this message translates to:
  /// **'Dieser Bon stammt aus der Testzeit und kann nicht storniert werden.'**
  String get bonsVoidFromTestTime;

  /// Rückfrage vor dem Storno.
  ///
  /// In de, this message translates to:
  /// **'Bon Nr. {number} wirklich stornieren?'**
  String bonsVoidQuestion(int number);

  /// Rückfrage, Barzahlung: Geld zurückgeben.
  ///
  /// In de, this message translates to:
  /// **'Du gibst {amount} bar zurück.'**
  String bonsVoidCashBack(String amount);

  /// Rückfrage, Kartenzahlung: in SumUp rückbuchen.
  ///
  /// In de, this message translates to:
  /// **'Das Geld geht nicht von selbst zurück. Bitte die Zahlung in der SumUp-App rückbuchen.'**
  String get bonsVoidCardHint;

  /// Taste: Storno einer Kartenzahlung bestätigen.
  ///
  /// In de, this message translates to:
  /// **'Stornieren, Rückbuchung mache ich in SumUp'**
  String get bonsVoidConfirmCard;

  /// Taste: Storno bestätigen.
  ///
  /// In de, this message translates to:
  /// **'Ja, stornieren'**
  String get bonsVoidConfirm;

  /// Überschrift des Bereichs Artikel.
  ///
  /// In de, this message translates to:
  /// **'Artikel'**
  String get itemsTitle;

  /// Zweite Zeile: Artikel mit Auswahl-Vorlage.
  ///
  /// In de, this message translates to:
  /// **'Mit Auswahl'**
  String get itemsWithChoice;

  /// Zweite Zeile: Artikel mit Pfand.
  ///
  /// In de, this message translates to:
  /// **'plus {amount} Pfand'**
  String itemsPlusDeposit(String amount);

  /// Kopf der Liste: Spalte Artikel.
  ///
  /// In de, this message translates to:
  /// **'Artikel'**
  String get itemsColumnItem;

  /// Kopf der Liste und Detail: Preis.
  ///
  /// In de, this message translates to:
  /// **'Preis'**
  String get itemsPrice;

  /// Kopf der Liste: Spalte Favorit.
  ///
  /// In de, this message translates to:
  /// **'Favorit'**
  String get itemsFavorite;

  /// Kopf der Liste: Spalte Im Verkauf.
  ///
  /// In de, this message translates to:
  /// **'Im Verkauf'**
  String get itemsInSale;

  /// Vorlesehilfe des Sterns, Artikel ist Favorit.
  ///
  /// In de, this message translates to:
  /// **'{name} aus den Favoriten nehmen'**
  String itemsFavoriteRemove(String name);

  /// Vorlesehilfe des Sterns, Artikel ist kein Favorit.
  ///
  /// In de, this message translates to:
  /// **'{name} zu den Favoriten'**
  String itemsFavoriteAdd(String name);

  /// Vorlesehilfe des Schalters Im Verkauf.
  ///
  /// In de, this message translates to:
  /// **'{name} im Verkauf'**
  String itemsInSaleLabel(String name);

  /// Taste: Preis ändern.
  ///
  /// In de, this message translates to:
  /// **'Preis ändern'**
  String get itemsChangePrice;

  /// Schalter Pfand mit dem Betrag.
  ///
  /// In de, this message translates to:
  /// **'Pfand {amount}'**
  String itemsDepositToggle(String amount);

  /// Schalter Vegan.
  ///
  /// In de, this message translates to:
  /// **'Vegan'**
  String get itemsVegan;

  /// Schalter Scharf.
  ///
  /// In de, this message translates to:
  /// **'Scharf'**
  String get itemsSpicy;

  /// Zeile Steuersatz.
  ///
  /// In de, this message translates to:
  /// **'Steuersatz'**
  String get itemsTaxRate;

  /// Überschrift: Auswahl, die beim Bonieren kommt.
  ///
  /// In de, this message translates to:
  /// **'Auswahl beim Bonieren'**
  String get itemsChoiceWhenRinging;

  /// Die Gruppen der Auswahl, mit Satzende; groups ist eine Aufzählung.
  ///
  /// In de, this message translates to:
  /// **'{groups}.'**
  String itemsChoiceGroups(String groups);

  /// Hinweis unten in der Detailspalte.
  ///
  /// In de, this message translates to:
  /// **'Namen, Fotos und neue Artikel kommen aus der Speisekarten-Datei.'**
  String get itemsFromMenuFile;

  /// Eine Änderung wurde nicht gespeichert (auch in den Einstellungen).
  ///
  /// In de, this message translates to:
  /// **'Das hat nicht geklappt. Bitte nochmal versuchen.'**
  String get itemsWriteFailed;

  /// Preiseingabe: Zeile über dem Feld.
  ///
  /// In de, this message translates to:
  /// **'Neuer Preis, bisher {amount}'**
  String itemsNewPrice(String amount);

  /// Taste: neuen Preis übernehmen.
  ///
  /// In de, this message translates to:
  /// **'Übernehmen'**
  String get itemsApply;

  /// Überschrift des Bereichs Übersicht.
  ///
  /// In de, this message translates to:
  /// **'Übersicht'**
  String get overviewTitle;

  /// Umschalter Zeitraum: heute.
  ///
  /// In de, this message translates to:
  /// **'Heute'**
  String get overviewRangeToday;

  /// Umschalter Zeitraum: 7 Tage.
  ///
  /// In de, this message translates to:
  /// **'7 Tage'**
  String get overviewRange7;

  /// Umschalter Zeitraum: 30 Tage.
  ///
  /// In de, this message translates to:
  /// **'30 Tage'**
  String get overviewRange30;

  /// Untertitel beim Zeitraum 7 Tage.
  ///
  /// In de, this message translates to:
  /// **'Letzte 7 Tage'**
  String get overviewLast7;

  /// Untertitel beim Zeitraum 30 Tage.
  ///
  /// In de, this message translates to:
  /// **'Letzte 30 Tage'**
  String get overviewLast30;

  /// Gewählter Balken am Tag: eine Stunde.
  ///
  /// In de, this message translates to:
  /// **'{from} bis {to} Uhr'**
  String overviewHourRange(int from, int to);

  /// Vergleich mit dem gleichen Wochentag der Vorwoche: gleich.
  ///
  /// In de, this message translates to:
  /// **'Gleich wie letzten {weekday}'**
  String overviewSameAsWeekday(String weekday);

  /// Vergleich mit dem gleichen Wochentag der Vorwoche: mehr.
  ///
  /// In de, this message translates to:
  /// **'{percent} % mehr als letzten {weekday}'**
  String overviewMoreThanWeekday(int percent, String weekday);

  /// Vergleich mit dem gleichen Wochentag der Vorwoche: weniger.
  ///
  /// In de, this message translates to:
  /// **'{percent} % weniger als letzten {weekday}'**
  String overviewLessThanWeekday(int percent, String weekday);

  /// Vergleich mit den Tagen davor: gleich.
  ///
  /// In de, this message translates to:
  /// **'Gleich wie in den {days} Tagen davor'**
  String overviewSameAsDaysBefore(int days);

  /// Vergleich mit den Tagen davor: mehr.
  ///
  /// In de, this message translates to:
  /// **'{percent} % mehr als in den {days} Tagen davor'**
  String overviewMoreThanDaysBefore(int percent, int days);

  /// Vergleich mit den Tagen davor: weniger.
  ///
  /// In de, this message translates to:
  /// **'{percent} % weniger als in den {days} Tagen davor'**
  String overviewLessThanDaysBefore(int percent, int days);

  /// Beschriftung Umsatz.
  ///
  /// In de, this message translates to:
  /// **'Umsatz'**
  String get overviewRevenue;

  /// Kennzahl: Anzahl Bons.
  ///
  /// In de, this message translates to:
  /// **'Bons'**
  String get overviewReceipts;

  /// Kennzahl: Umsatz pro Bon.
  ///
  /// In de, this message translates to:
  /// **'Pro Bon'**
  String get overviewPerReceipt;

  /// Kennzahl: Anzahl Stornos.
  ///
  /// In de, this message translates to:
  /// **'Stornos'**
  String get overviewVoids;

  /// Überschrift des Diagramms am Tag.
  ///
  /// In de, this message translates to:
  /// **'Umsatz pro Stunde'**
  String get overviewPerHour;

  /// Überschrift des Diagramms über Tage.
  ///
  /// In de, this message translates to:
  /// **'Umsatz pro Tag'**
  String get overviewPerDay;

  /// Diagramm ohne Bons.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Bons in diesem Zeitraum.'**
  String get overviewNoneInRange;

  /// Vorlesehilfe eines Balkens: Zeit und Betrag.
  ///
  /// In de, this message translates to:
  /// **'{label}, {amount}'**
  String overviewBarLabel(String label, String amount);

  /// Die Zahlen konnten nicht geladen werden.
  ///
  /// In de, this message translates to:
  /// **'Die Zahlen konnten nicht geladen werden.'**
  String get overviewLoadFailed;

  /// Taste nach einem Ladefehler.
  ///
  /// In de, this message translates to:
  /// **'Nochmal versuchen'**
  String get overviewRetry;

  /// Karte Zahlungsarten.
  ///
  /// In de, this message translates to:
  /// **'Zahlungsarten'**
  String get overviewPayments;

  /// Karte ohne Bons.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Bons.'**
  String get overviewNoReceipts;

  /// Karte Meistverkauft.
  ///
  /// In de, this message translates to:
  /// **'Meistverkauft'**
  String get overviewTopItems;

  /// Umsatz nach Kategorie.
  ///
  /// In de, this message translates to:
  /// **'Nach Kategorie'**
  String get overviewByCategory;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'de', 'en', 'tr', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return L10nAr();
    case 'de':
      return L10nDe();
    case 'en':
      return L10nEn();
    case 'tr':
      return L10nTr();
    case 'zh':
      return L10nZh();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
