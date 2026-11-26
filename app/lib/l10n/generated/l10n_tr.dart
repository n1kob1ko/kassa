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
}
