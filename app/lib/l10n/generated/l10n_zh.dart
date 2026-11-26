// ignore_for_file: deprecated_member_use

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class L10nZh extends L10n {
  L10nZh([String locale = 'zh']) : super(locale);

  @override
  String get languageSectionTitle => '语言';

  @override
  String get languageSheetTitle => '语言';

  @override
  String get languageChangeLabel => '更改语言';
}
