// Android sichert die Daten der App nicht und überträgt sie nicht auf ein
// neues Gerät (Schlussprüfung S2b, C1, Entwurf 12.3 B18): Eine
// zurückgespielte Datenbank ohne ihre Schlüssel im Keystore wäre eine Kassa,
// die nicht verkaufen kann.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AndroidManifest: allowBackup false, Regeln für die Übertragung', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final application = RegExp(r'<application\b[^>]*>')
        .firstMatch(manifest)!
        .group(0)!;
    expect(application, contains('android:allowBackup="false"'));
    expect(
      application,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
  });

  test('data_extraction_rules: jeder Bereich ausgeschlossen, für Sicherung '
      'und Übertragung', () {
    final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml')
        .readAsStringSync();
    for (final part in ['cloud-backup', 'device-transfer']) {
      final body = RegExp(
        '<$part>(.*?)</$part>',
        dotAll: true,
      ).firstMatch(rules)!.group(1)!;
      for (final domain in [
        'root',
        'file',
        'database',
        'sharedpref',
        'external',
      ]) {
        expect(
          body,
          contains('<exclude domain="$domain" path="." />'),
          reason: '$part $domain',
        );
      }
      expect(body, isNot(contains('<include')), reason: part);
    }
  });
}
