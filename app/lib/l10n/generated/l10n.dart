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
