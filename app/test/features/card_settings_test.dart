import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/devices/card_terminal.dart';
import 'package:kassa/ui/tokens.dart';

import '../support/fake_devices.dart';
import '../support/pump.dart';
import '../support/settings_pump.dart';

Future<void> _settings(
  WidgetTester t, {
  required CardTerminalStatus status,
  CardTerminalStatus? afterLogin,
  InternetSwitch? internet,
  Brightness brightness = Brightness.light,
}) async {
  final terminal = FakeCardTerminal(statusValue: status)
    ..statusAfterLogin = afterLogin;
  await pumpSettings(
    t,
    brightness: brightness,
    terminal: terminal,
    internet: internet?.stream,
  );
}

const _ready = CardTerminalStatus(
  CardTerminalState.ready,
  merchantName: 'MH12345',
);
const _out = CardTerminalStatus(CardTerminalState.loggedOut);
const _none = CardTerminalStatus(CardTerminalState.notConfigured);

String _text(WidgetTester t, String key) {
  final f = find.byKey(Key(key));
  final w = t.widget(f);
  return (w is Text
          ? w
          : t.widget<Text>(find.descendant(of: f, matching: find.byType(Text))))
      .data!;
}

Future<void> _openTest(WidgetTester t) async {
  await t.ensureVisible(find.byKey(const Key('open-device-test')));
  await t.tap(find.byKey(const Key('open-device-test')));
  await t.pumpAndSettle();
}

Future<void> _check(WidgetTester t) async {
  await t.tap(find.byKey(const Key('test-card')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Einstellungen: nicht eingerichtet, ruhig und ohne Taste', (
    t,
  ) async {
    await _settings(t, status: _none);
    expect(find.byKey(const Key('card-row')), findsOneWidget);
    expect(find.text('Diese Version wurde ohne SumUp gebaut.'), findsOneWidget);
    // Drucker, Karte, Signatur der Bons.
    expect(find.text('Nicht eingerichtet'), findsNWidgets(3));
    expect(find.byKey(const Key('card-login')), findsNothing);
    expect(find.byKey(const Key('card-logout')), findsNothing);
    expect(find.text('Kommt mit einem späteren Update.'), findsNothing);
  });

  testWidgets('Einstellungen: Anmelden ruft login und zeigt danach den '
      'Händler', (t) async {
    await _settings(t, status: _out, afterLogin: _ready);
    expect(find.text('Nicht angemeldet'), findsOneWidget);
    expect(find.byKey(const Key('card-logout')), findsNothing);
    expect(
      t.getSize(find.byKey(const Key('card-login'))).height,
      greaterThanOrEqualTo(48),
    );
    await t.ensureVisible(find.byKey(const Key('card-login')));
    await t.tap(find.byKey(const Key('card-login')));
    await t.pumpAndSettle();
    expect(terminalOf(t).calls, contains('login'));
    expect(find.text('MH12345'), findsOneWidget);
    expect(find.text('Nicht angemeldet'), findsNothing);
    expect(find.byKey(const Key('card-login')), findsNothing);
    expect(find.byKey(const Key('card-reader')), findsOneWidget);
    expect(find.byKey(const Key('card-logout')), findsOneWidget);
  });

  testWidgets('Einstellungen: abgebrochene Anmeldung lässt alles stehen', (
    t,
  ) async {
    await _settings(t, status: _out);
    await t.ensureVisible(find.byKey(const Key('card-login')));
    await t.tap(find.byKey(const Key('card-login')));
    await t.pumpAndSettle();
    expect(find.text('Nicht angemeldet'), findsOneWidget);
    expect(find.byKey(const Key('card-login')), findsOneWidget);
  });

  testWidgets('Einstellungen: ohne Namen steht "Angemeldet"', (t) async {
    await _settings(
      t,
      status: const CardTerminalStatus(CardTerminalState.ready),
    );
    expect(find.text('Angemeldet'), findsOneWidget);
  });

  testWidgets('Einstellungen: Abmelden fragt nach, Doch nicht lässt alles '
      'stehen', (t) async {
    await _settings(t, status: _ready);
    await t.ensureVisible(find.byKey(const Key('card-logout')));
    await t.tap(find.byKey(const Key('card-logout')));
    await t.pumpAndSettle();
    expect(find.text('Wirklich abmelden?'), findsOneWidget);
    expect(terminalOf(t).calls, isNot(contains('logout')));

    await t.tap(find.byKey(const Key('card-logout-no')));
    await t.pumpAndSettle();
    expect(find.text('Wirklich abmelden?'), findsNothing);
    expect(terminalOf(t).calls, isNot(contains('logout')));
    expect(find.text('MH12345'), findsOneWidget);
    expect(find.byKey(const Key('card-logout')), findsOneWidget);

    await t.tap(find.byKey(const Key('card-logout')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('card-logout-yes')));
    await t.pumpAndSettle();
    expect(terminalOf(t).calls, contains('logout'));
    expect(find.text('Nicht angemeldet'), findsOneWidget);
    expect(find.text('MH12345'), findsNothing);
    expect(find.byKey(const Key('card-login')), findsOneWidget);
  });

  testWidgets('Einstellungen: Kartenleser verbinden öffnet die Seite von '
      'SumUp', (t) async {
    await _settings(t, status: _ready);
    await t.ensureVisible(find.byKey(const Key('card-reader')));
    await t.tap(find.byKey(const Key('card-reader')));
    await t.pumpAndSettle();
    expect(terminalOf(t).calls, contains('readerSettings'));
  });

  testWidgets('Einstellungen: beim Zurückkommen in die App wird der Stand '
      'neu geholt', (t) async {
    await _settings(t, status: _out);
    expect(find.text('Nicht angemeldet'), findsOneWidget);
    // Die Anmeldung geschah auf der Seite von SumUp, außerhalb der App.
    terminalOf(t).statusValue = _ready;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(find.text('MH12345'), findsOneWidget);
    expect(find.text('Nicht angemeldet'), findsNothing);
  });

  group('Geräte testen', () {
    testWidgets('die vier Ergebnisse', (t) async {
      final net = InternetSwitch();
      await _settings(t, status: _none, internet: net);
      await _openTest(t);
      expect(find.byKey(const Key('result-card')), findsNothing);
      expect(
        t.getSize(find.byKey(const Key('test-card'))).height,
        greaterThanOrEqualTo(48),
      );

      await _check(t);
      expect(_text(t, 'result-card'), 'Nicht eingerichtet.');

      terminalOf(t).statusValue = _out;
      await _check(t);
      expect(_text(t, 'result-card'), 'Nicht bei SumUp angemeldet.');

      terminalOf(t).statusValue = _ready;
      net.set(false);
      await t.pumpAndSettle();
      await _check(t);
      expect(_text(t, 'result-card'), 'Kein Internet.');

      net.set(true);
      await t.pumpAndSettle();
      await _check(t);
      expect(
        _text(t, 'result-card'),
        'Angemeldet als MH12345. Für einen echten Test 1,00 € mit Karte '
        'bonieren und danach stornieren.',
      );
    });

    testWidgets('"Nicht eingerichtet." ist ruhig: neutrale Fläche, kein grüner '
        'Punkt', (t) async {
      await _settings(t, status: _none);
      await _openTest(t);
      await _check(t);
      final box = t.widget<Container>(find.byKey(const Key('result-card')));
      expect((box.decoration! as BoxDecoration).color, KassaColors.light.fill);
      expect(
        find.descendant(
          of: find.byKey(const Key('result-card')),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).shape == BoxShape.circle,
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('"Nicht bei SumUp angemeldet." bleibt in der Warnfläche', (
      t,
    ) async {
      await _settings(t, status: _out);
      await _openTest(t);
      await _check(t);
      final box = t.widget<Container>(
        find
            .descendant(
              of: find.byKey(const Key('result-card')),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (box.decoration! as BoxDecoration).color,
        KassaColors.light.warnBg,
      );
    });
  });
}
