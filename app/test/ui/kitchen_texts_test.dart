import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/ui/kitchen_texts.dart';

void main() {
  test('Texte des Küchenbons in allen fünf Sprachen', () {
    const expected = {
      AppLanguage.de: ('KÜCHE', 'STORNO', 'KOPIE', 'PROBE'),
      AppLanguage.en: ('KITCHEN', 'VOID', 'COPY', 'SAMPLE'),
      AppLanguage.zh: ('厨房', '作废', '副本', '测试'),
      AppLanguage.tr: ('MUTFAK', 'İPTAL', 'KOPYA', 'DENEME'),
      AppLanguage.ar: ('المطبخ', 'إلغاء', 'نسخة', 'تجربة'),
    };
    for (final language in AppLanguage.values) {
      final t = kitchenTextsFor(language);
      expect((t.title, t.voided, t.copy, t.sample), expected[language]);
    }
  });
}
