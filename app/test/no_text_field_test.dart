import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Die einzigen Dateien mit Tastatur: "Zugangsdaten von A-Trust" (Plan Q3)
/// und "Kassen-ID ändern" (Plan C9).
const _allowed = [
  'lib/features/settings/credentials_screen.dart',
  'lib/features/settings/cash_box_id_sheet.dart',
  'lib/features/customers/customer_form.dart',
];

final _textField = RegExp(r'\b(TextField|TextFormField|EditableText)\b');

/// Die Dateien unter [root] mit einem Textfeld, außer denen in [_allowed]; Pfade mit
/// `/`, ab dem Ordner der App.
List<String> textFieldFiles(Directory root) => [
  for (final f in root.listSync(recursive: true).whereType<File>())
    if (f.path.endsWith('.dart') && _textField.hasMatch(f.readAsStringSync()))
      f.path.replaceAll(r'\', '/'),
]..removeWhere((p) => _allowed.any((a) => p == a || p.endsWith('/$a')));

void main() {
  test('in der App gibt es kein Textfeld außer den Zugangsdaten und der '
      'Kassen-ID', () {
    expect(textFieldFiles(Directory('lib')), isEmpty);
    for (final file in _allowed) {
      expect(
        File(file).readAsStringSync(),
        contains('TextField'),
        reason: 'Die Ausnahme gilt nur, solange es $file mit Feldern gibt.',
      );
    }
  });

  test('ein Textfeld in einer anderen Datei fällt auf', () {
    final root = Directory.systemTemp.createTempSync('kassa_no_text_field');
    addTearDown(() => root.deleteSync(recursive: true));
    final lib = Directory('${root.path}/lib/features/settings')
      ..createSync(recursive: true);
    File('${lib.path}/credentials_screen.dart').writeAsStringSync('TextField');
    File('${lib.path}/cash_box_id_sheet.dart').writeAsStringSync('TextField');
    File('${lib.path}/settings_screen.dart').writeAsStringSync('TextField');
    File('${root.path}/lib/other.dart').writeAsStringSync('EditableText');
    File('${root.path}/lib/fine.dart').writeAsStringSync('Text');
    final hits = textFieldFiles(Directory('${root.path}/lib'));
    expect(hits, hasLength(2));
    expect(hits.any((p) => p.endsWith('/settings_screen.dart')), isTrue);
    expect(hits.any((p) => p.endsWith('/lib/other.dart')), isTrue);
  });
}
