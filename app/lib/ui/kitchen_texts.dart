// Die festen Texte des Küchenbons in der Küchensprache, unabhängig von der
// Bediensprache.

import '../core/app_language.dart';
import '../domain/kitchen_ticket.dart';
import '../l10n/generated/l10n.dart';

KitchenTexts kitchenTextsFor(AppLanguage language) {
  final l10n = lookupL10n(language.locale);
  return KitchenTexts(
    title: l10n.kitchenTitle,
    voided: l10n.kitchenVoided,
    copy: l10n.kitchenCopy,
    sample: l10n.kitchenSample,
  );
}
