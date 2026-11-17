import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('in der App gibt es kein Textfeld', () {
    final hits = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => RegExp(r'\b(TextField|TextFormField|EditableText)\b')
            .hasMatch(f.readAsStringSync()));
    expect(hits.map((f) => f.path), isEmpty);
  });
}
