import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/devices/card_terminal.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_devices.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';
import '../support/settings_pump.dart';

// Bildvergleich der Kartenzahlung: Zahlleiste mit Grund, Warte auf Karte,
// Fertig mit Karte und die Einstellungen mit angemeldetem Terminal. Neu
// erzeugen mit `flutter test --update-goldens test/golden/card_golden_test.dart`.

const _ready = CardTerminalStatus(
  CardTerminalState.ready,
  merchantName: 'MH12345',
);

Future<List<Override>> _overrides(FakeCardTerminal terminal) =>
    memoryOverrides(terminal: terminal);

void main() {
  for (final (name, brightness) in [
    ('hell', Brightness.light),
    ('dunkel', Brightness.dark),
  ]) {
    testWidgets('Zahlleiste mit Grund unter "Karte" ($name)', (t) async {
      final terminal = FakeCardTerminal(
        statusValue: const CardTerminalStatus(CardTerminalState.loggedOut),
      );
      await pumpKassa(
        t,
        brightness: brightness,
        overrides: await _overrides(terminal),
      );
      await tapItem(t, 'cola');
      await tapItem(t, 'teigtaschen');
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(KassaApp),
        matchesGoldenFile('goldens/karte_zahlleiste_grund_$name.png'),
      );
    });

    testWidgets('Warte auf Karte ($name)', (t) async {
      final terminal = FakeCardTerminal(statusValue: _ready)
        ..hang = Completer();
      await pumpKassa(
        t,
        brightness: brightness,
        overrides: await _overrides(terminal),
      );
      await tapItem(t, 'cola');
      await tapItem(t, 'teigtaschen');
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('pay-card')));
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(KassaApp),
        matchesGoldenFile('goldens/karte_warten_$name.png'),
      );
    });

    testWidgets('Fertig mit Karte ($name)', (t) async {
      final terminal = FakeCardTerminal(statusValue: _ready)
        ..next = const CardPaid(
          txCode: 'TX1',
          cardScheme: 'VISA',
          cardLast4: '4242',
        );
      await pumpKassa(
        t,
        brightness: brightness,
        overrides: await _overrides(terminal),
      );
      await tapItem(t, 'cola');
      await tapItem(t, 'teigtaschen');
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('pay-card')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(KassaApp),
        matchesGoldenFile('goldens/karte_fertig_$name.png'),
      );
    });

    testWidgets('Einstellungen mit angemeldetem Terminal ($name)', (t) async {
      await pumpSettings(
        t,
        brightness: brightness,
        terminal: FakeCardTerminal(statusValue: _ready),
      );
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(KassaApp),
        matchesGoldenFile('goldens/einstellungen_karte_$name.png'),
      );
    });
  }
}
