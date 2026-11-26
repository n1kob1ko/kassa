// ignore_for_file: deprecated_member_use

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class L10nAr extends L10n {
  L10nAr([String locale = 'ar']) : super(locale);

  @override
  String get languageSectionTitle => 'اللغة';

  @override
  String get languageSheetTitle => 'اللغة';

  @override
  String get languageChangeLabel => 'تغيير اللغة';

  @override
  String get loginTitle => 'أدخل رمز PIN';

  @override
  String get loginHint => 'لكل شخص رمز PIN خاص به';

  @override
  String get loginWrongPin => 'رمز PIN هذا غير مسجَّل.';

  @override
  String get loginFailed => 'لم ينجح ذلك. يرجى المحاولة مرة أخرى.';

  @override
  String loginDigitsEntered(int filled) {
    return 'تم إدخال $filled من 4 أرقام';
  }

  @override
  String get shellTabKassa => 'البيع';

  @override
  String get shellTabBons => 'الفواتير';

  @override
  String get shellTabOverview => 'نظرة عامة';

  @override
  String get shellTabItems => 'الأصناف';

  @override
  String get shellTabClose => 'الإقفال';

  @override
  String get shellOffline => 'لا يوجد إنترنت. البيع نقدًا مستمر.';

  @override
  String shellSwitchStaff(String name) {
    return 'تبديل الموظف، المسجَّل حاليًا: $name';
  }

  @override
  String get shellSettings => 'الإعدادات';

  @override
  String get uiUndo => 'تراجع';

  @override
  String get uiKeypadComma => 'فاصلة';

  @override
  String get uiKeypadDot => 'نقطة';

  @override
  String get uiKeypadDelete => 'حذف آخر رقم';

  @override
  String get uiReceiptQr => 'رمز QR للفاتورة';

  @override
  String get uiListSeparator => '، ';
}
