import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/app_sync_providers.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/sync/server_api.dart';
import 'package:kassa/sync/token_store.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_server.dart';
import '../support/pump.dart';

// Bildvergleich der Bildschirme zum Koppeln mit Code, hell und dunkel,
// 1280 × 800. Neu erzeugen mit
// `flutter test --update-goldens test/golden/pairing_golden_test.dart`.

Future<FakeServer> _start(
  WidgetTester t,
  Brightness brightness, {
  FakeServer? server,
}) async {
  final s = server ?? FakeServer.beispiel();
  final List<Override> overrides = [
    ...await memoryOverrides(seeded: false),
    hasServerProvider.overrideWithValue(true),
    tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
    serverApiProvider.overrideWithValue(
      ServerApi(baseUrl: 'https://kassa.example', client: s, appVersion: '1'),
    ),
  ];
  await pumpApp(
    t,
    const KassaApp(),
    overrides: overrides,
    brightness: brightness,
  );
  await t.pumpAndSettle();
  return s;
}

Future<void> _toCode(WidgetTester t) async {
  await t.tap(find.byKey(const Key('setup-pair')));
  await t.pumpAndSettle();
}

Future<void> _submit(WidgetTester t, [String code = FakeServer.code]) async {
  await tapKeys(t, code.split('').join(' '));
  await t.tap(find.byKey(const Key('pair-submit')));
  await t.pumpAndSettle();
}

Future<void> _golden(WidgetTester t, String name) async {
  expect(t.takeException(), isNull);
  await expectLater(
    find.byType(KassaApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  for (final (suffix, brightness) in [
    ('hell', Brightness.light),
    ('dunkel', Brightness.dark),
  ]) {
    testWidgets('Koppeln: erster Start ($suffix)', (t) async {
      await _start(t, brightness);
      await _golden(t, 'koppeln_start_$suffix');
    });

    testWidgets('Koppeln: Code leer ($suffix)', (t) async {
      await _start(t, brightness);
      await _toCode(t);
      await _golden(t, 'koppeln_code_leer_$suffix');
    });

    testWidgets('Koppeln: Code mit 4 Ziffern ($suffix)', (t) async {
      await _start(t, brightness);
      await _toCode(t);
      await tapKeys(t, '4 8 2 0');
      await t.pump(const Duration(milliseconds: 300));
      await _golden(t, 'koppeln_code_vier_$suffix');
    });

    testWidgets('Koppeln: falscher Code ($suffix)', (t) async {
      await _start(t, brightness);
      await _toCode(t);
      await _submit(t, '11111111');
      await _golden(t, 'koppeln_fehler_$suffix');
    });

    testWidgets('Koppeln: Speisekarte wird geladen ($suffix)', (t) async {
      final server = FakeServer.beispiel();
      final gate = Completer<void>();
      server.beforeNextPage = () => gate.future;
      await _start(t, brightness, server: server);
      await _toCode(t);
      await tapKeys(t, FakeServer.code.split('').join(' '));
      await t.tap(find.byKey(const Key('pair-submit')));
      await t.pump();
      await t.pump();
      await t.pump(const Duration(milliseconds: 350));
      await _golden(t, 'koppeln_laedt_$suffix');
      gate.complete();
      await t.pumpAndSettle();
    });

    testWidgets('Koppeln: Laden gescheitert ($suffix)', (t) async {
      final server = FakeServer.beispiel()..breakAfterPages = 1;
      await _start(t, brightness, server: server);
      await _toCode(t);
      await _submit(t);
      await _golden(t, 'koppeln_laden_gescheitert_$suffix');
    });

    testWidgets('Koppeln: noch kein Mitarbeiter ($suffix)', (t) async {
      final server = FakeServer.beispiel();
      server.archive('staff', '<uuid>');
      await _start(t, brightness, server: server);
      await _toCode(t);
      await _submit(t);
      await _golden(t, 'koppeln_kein_mitarbeiter_$suffix');
    });
  }
}
