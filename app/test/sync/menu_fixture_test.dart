import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/menu_fixture.dart';

void main() {
  test('expected-Dateien sind aktuell', () {
    final fresh = buildMenuFixtures(fixtureRoot);
    expect(fresh.length, greaterThanOrEqualTo(30));
    final expectedDir = Directory('${fixtureRoot.path}/expected');
    final onDisk = {
      for (final f in expectedDir.listSync().whereType<File>())
        f.uri.pathSegments.last: f.readAsStringSync(),
    };
    expect(
      onDisk.keys.toSet(),
      fresh.keys.toSet(),
      reason: 'Dateien fehlen oder sind übrig. Aufruf: dart run tool/menu_fixture.dart',
    );
    for (final name in fresh.keys) {
      expect(
        onDisk[name],
        fresh[name],
        reason: '$name ist veraltet. Aufruf: dart run tool/menu_fixture.dart',
      );
    }
  });
}
