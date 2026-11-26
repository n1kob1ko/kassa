import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/l10n_review.dart';

void main() {
  test('die Listen zum Gegenlesen sind aktuell', () {
    final fresh = buildReviewLists(arbDir);
    expect(fresh.keys, ['en.md', 'zh.md', 'tr.md', 'ar.md']);
    for (final MapEntry(key: name, value: text) in fresh.entries) {
      final file = File('${reviewDir.path}/$name');
      expect(
        file.existsSync() ? file.readAsStringSync() : null,
        text,
        reason: '$name ist veraltet. Aufruf: dart run tool/l10n_review.dart',
      );
    }
  });

  test('zweimal erzeugt gibt dieselben Bytes', () {
    expect(buildReviewLists(arbDir), buildReviewLists(arbDir));
  });

  test('jeder Text steht einmal in der Tabelle, mit Bereich und Schlüssel', () {
    final tr = buildReviewLists(arbDir)['tr.md']!;
    expect(tr, contains('| Deutsch | Übersetzung | Wo |'));
    expect(tr, contains('| PIN eingeben | PIN girin | Anmeldung: `loginTitle` |'));
    expect(tr, contains('## Unsicher'));
    expect(
      RegExp(r'`kassaKitchenPrint` \|').allMatches(tr),
      hasLength(1),
    );
  });

  test('Tabellenzellen: senkrechter Strich und Zeilenumbruch', () {
    expect(reviewCell('a|b'), r'a\|b');
    expect(reviewCell('eins\nzwei'), 'eins<br>zwei');
  });
}
