// Die Statusleiste oben und die Gestenleiste unten gehören dem Tablet. Die
// App zeichnet zwar bis an den Rand, legt aber nichts Bedienbares darunter.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/features/kassa/cart_panel.dart';
import 'package:kassa/features/setup/setup_screen.dart';
import 'package:kassa/ui/app_header.dart';
import 'package:kassa/features/login/pin_screen.dart';
import 'package:kassa/ui/tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../support/pump.dart';
import '../support/settings_pump.dart';

const _top = 32.0;
const _bottom = 24.0;

/// Systemleisten wie auf einem Tablet mit Android 15: oben die Statusleiste,
/// unten die Gestenleiste. `pumpApp` setzt das Pixelverhältnis auf 1,0.
void _withSystemBars(WidgetTester t) {
  t.view.padding = const FakeViewPadding(top: _top, bottom: _bottom);
  t.view.viewPadding = const FakeViewPadding(top: _top, bottom: _bottom);
  addTearDown(() {
    t.view.resetPadding();
    t.view.resetViewPadding();
  });
}

SystemUiOverlayStyle _overlayStyle(WidgetTester t) => t
    .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find
          .byWidgetPredicate((w) => w is AnnotatedRegion<SystemUiOverlayStyle>)
          .first,
    )
    .value;

void main() {
  testWidgets(
    'Kassa: Reiter liegen unter der Statusleiste, die Kopfleiste füllt sie aus',
    (t) async {
      _withSystemBars(t);
      await pumpAppLoggedInAsChef(t);
      final header = t.getRect(find.byType(AppHeader));
      expect(header.top, 0);
      expect(header.height, KassaTokens.headerHeight + _top);
      for (final key in const [
        'tab-Kassa',
        'tab-Abschluss',
        'staff',
        'settings',
      ]) {
        expect(
          t.getRect(find.byKey(Key(key))).top,
          greaterThanOrEqualTo(_top),
          reason: key,
        );
      }
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('Kassa: die Tasten zum Bezahlen bleiben über der Gestenleiste', (
    t,
  ) async {
    _withSystemBars(t);
    await pumpAppLoggedInAsChef(t);
    expect(
      t.getRect(find.byKey(const Key('pay-cash'))).bottom,
      lessThanOrEqualTo(800 - _bottom),
    );
    expect(
      t.getRect(find.byKey(const Key('pay-card'))).bottom,
      lessThanOrEqualTo(800 - _bottom),
    );
  });

  testWidgets('Kassa: die Bon-Spalte reicht bis an den unteren Rand', (
    t,
  ) async {
    _withSystemBars(t);
    await pumpAppLoggedInAsChef(t);
    expect(t.getRect(find.byType(CartPanel)).bottom, 800);
    expect(
      t.getRect(find.byKey(const Key('pay-cash'))).bottom,
      lessThanOrEqualTo(800 - _bottom),
    );
  });

  testWidgets('Anmeldung: die PIN-Karte bleibt zwischen den Systemleisten', (
    t,
  ) async {
    _withSystemBars(t);
    await pumpApp(t, const KassaApp(), overrides: await memoryOverrides());
    await t.pumpAndSettle();
    final card = t.getRect(find.byType(PinCard));
    expect(card.top, greaterThanOrEqualTo(_top));
    expect(card.bottom, lessThanOrEqualTo(800 - _bottom));
  });

  testWidgets('Einrichtung: der Inhalt bleibt zwischen den Systemleisten', (
    t,
  ) async {
    _withSystemBars(t);
    await pumpApp(
      t,
      const KassaApp(),
      overrides: await memoryOverrides(seeded: false),
    );
    await t.pumpAndSettle();
    final body = t.getRect(
      find.descendant(
        of: find.byType(SetupScreen),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    // Die Karte steht in der Mitte des freien Platzes, nicht des Bildschirms.
    expect(body.center.dy, closeTo((_top + 800 - _bottom) / 2, 0.5));
  });

  testWidgets('ohne Systemleisten bleibt die Kopfleiste so hoch wie bisher', (
    t,
  ) async {
    await pumpAppLoggedInAsChef(t);
    final header = t.getRect(find.byType(AppHeader));
    expect(header.top, 0);
    expect(header.height, KassaTokens.headerHeight);
  });

  testWidgets(
    'helle Ansicht: dunkle Zeichen in der Statusleiste, durchsichtige Leisten',
    (t) async {
      await pumpAppLoggedInAsChef(t);
      final style = _overlayStyle(t);
      expect(style.statusBarColor, const Color(0x00000000));
      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.systemNavigationBarColor, const Color(0x00000000));
      expect(style.systemNavigationBarIconBrightness, Brightness.dark);
    },
  );

  testWidgets('dunkle Ansicht: helle Zeichen in der Statusleiste', (t) async {
    await pumpAppLoggedInAsChef(t, brightness: Brightness.dark);
    final style = _overlayStyle(t);
    expect(style.statusBarIconBrightness, Brightness.light);
    expect(style.systemNavigationBarIconBrightness, Brightness.light);
  });
}
