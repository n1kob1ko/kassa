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
}
