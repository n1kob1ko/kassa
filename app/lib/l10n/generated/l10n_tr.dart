// ignore_for_file: deprecated_member_use

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class L10nTr extends L10n {
  L10nTr([String locale = 'tr']) : super(locale);

  @override
  String get languageSectionTitle => 'Dil';

  @override
  String get languageSheetTitle => 'Dil';

  @override
  String get languageChangeLabel => 'Dili değiştir';

  @override
  String get loginTitle => 'PIN girin';

  @override
  String get loginHint => 'Herkesin kendi PIN\'i var';

  @override
  String get loginWrongPin => 'Bu PIN kayıtlı değil.';

  @override
  String get loginFailed => 'Olmadı. Lütfen tekrar deneyin.';

  @override
  String loginDigitsEntered(int filled) {
    return '4 haneden $filled tanesi girildi';
  }

  @override
  String get shellTabKassa => 'Kasa';

  @override
  String get shellTabBons => 'Fişler';

  @override
  String get shellTabOverview => 'Genel bakış';

  @override
  String get shellTabItems => 'Ürünler';

  @override
  String get shellTabClose => 'Kapanış';

  @override
  String get shellOffline => 'İnternet yok. Nakit satış devam ediyor.';

  @override
  String shellSwitchStaff(String name) {
    return 'Personel değiştir, giriş yapan: $name';
  }

  @override
  String get shellSettings => 'Ayarlar';

  @override
  String get uiUndo => 'Geri al';

  @override
  String get uiKeypadComma => 'Virgül';

  @override
  String get uiKeypadDot => 'Nokta';

  @override
  String get uiKeypadDelete => 'Son haneyi sil';

  @override
  String get uiReceiptQr => 'Fiş QR kodu';

  @override
  String get uiListSeparator => ', ';
}
