// ignore_for_file: deprecated_member_use

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get languageSectionTitle => 'Language';

  @override
  String get languageSheetTitle => 'Language';

  @override
  String get languageChangeLabel => 'Change language';

  @override
  String get loginTitle => 'Enter PIN';

  @override
  String get loginHint => 'Everyone has their own PIN';

  @override
  String get loginWrongPin => 'This PIN is not registered.';

  @override
  String get loginFailed => 'That didn\'t work. Please try again.';

  @override
  String loginDigitsEntered(int filled) {
    return '$filled of 4 digits entered';
  }

  @override
  String get shellTabKassa => 'Register';

  @override
  String get shellTabBons => 'Receipts';

  @override
  String get shellTabOverview => 'Overview';

  @override
  String get shellTabItems => 'Items';

  @override
  String get shellTabClose => 'Closing';

  @override
  String get shellOffline => 'No internet. Cash sales still work.';

  @override
  String shellSwitchStaff(String name) {
    return 'Switch staff, signed in: $name';
  }

  @override
  String get shellSettings => 'Settings';

  @override
  String get uiUndo => 'Undo';

  @override
  String get uiKeypadComma => 'Comma';

  @override
  String get uiKeypadDot => 'Dot';

  @override
  String get uiKeypadDelete => 'Delete last digit';

  @override
  String get uiReceiptQr => 'Receipt QR code';

  @override
  String get uiListSeparator => ', ';
}
