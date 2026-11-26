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
}
