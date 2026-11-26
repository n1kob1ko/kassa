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
}
