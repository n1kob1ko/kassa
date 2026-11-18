// Die Statusleiste oben und die Gestenleiste unten gehören dem Tablet. Die
// App zeichnet zwar bis an den Rand, legt aber nichts Bedienbares darunter.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/devices/card_terminal.dart';
import 'package:kassa/features/kassa/cart_panel.dart';
import 'package:kassa/features/kassa/sale_done.dart';
import 'package:kassa/ui/pressable.dart';
import 'package:kassa/features/setup/setup_screen.dart';
import 'package:kassa/ui/app_header.dart';
import 'package:kassa/features/login/pin_screen.dart';
import 'package:kassa/ui/tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_devices.dart';
import '../support/kassa_pump.dart';
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

/// Alles Antippbare liegt zwischen den Systemleisten: nichts beginnt über der
/// Statusleiste, nichts reicht unter die Gestenleiste. Was in einer Liste
/// zum Scrollen steht, zählt mit dem sichtbaren Ausschnitt der Liste.
void _expectTappablesBetweenBars(WidgetTester t, String area) {
  final all = find.byType(Pressable);
  expect(all, findsWidgets, reason: area);
  const screen = Rect.fromLTWH(0, 0, 1280, 800);
  for (final e in all.evaluate()) {
    final target = find.byElementPredicate((x) => x == e);
    var rect = t.getRect(target);
    if (!rect.overlaps(screen)) continue; // gar nicht sichtbar
    final scroll = find.ancestor(of: target, matching: find.byType(Scrollable));
    if (scroll.evaluate().isNotEmpty) {
      final view = t.getRect(scroll.first);
      expect(view.bottom, lessThanOrEqualTo(800 - _bottom), reason: area);
      rect = rect.intersect(view);
      if (rect.isEmpty) continue;
    }
    final label = '$area: ${e.widget.key ?? 'Taste ohne Schlüssel'} $rect';
    expect(rect.top, greaterThanOrEqualTo(_top), reason: label);
    expect(rect.bottom, lessThanOrEqualTo(800 - _bottom), reason: label);
  }
}

Future<FakeCardTerminal> _loggedInWithBars(
  WidgetTester t, {
  Completer<CardPaymentResult>? hang,
}) async {
  _withSystemBars(t);
  final terminal = FakeCardTerminal(
    statusValue: const CardTerminalStatus(
      CardTerminalState.ready,
      merchantName: 'MH12345',
    ),
  )..hang = hang;
  await pumpAppLoggedInAsChef(t, terminal: terminal);
  return terminal;
}

Future<void> _tapKey(WidgetTester t, String key) async {
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

/// Der Bereich selbst endet über der Gestenleiste. Für Bereiche, in denen mit
/// den Daten der Tests nichts Antippbares bis an den unteren Rand reicht:
/// sonst bliebe ein Fehlen des Abstands unbemerkt.
void _expectAboveBottomBar(WidgetTester t, Finder area, String name) {
  expect(area, findsOneWidget, reason: name);
  expect(
    t.getRect(area).bottom,
    lessThanOrEqualTo(800 - _bottom),
    reason: '$name endet unter der Gestenleiste',
  );
}

void main() {
  for (final (name, key, area) in const [
    ('Bons', 'tab-Bons', 'area-bons'),
    ('Übersicht', 'tab-Übersicht', 'area-overview'),
  ]) {
    testWidgets('$name: der Bereich endet über der Gestenleiste', (t) async {
      await _loggedInWithBars(t);
      await _tapKey(t, key);
      _expectAboveBottomBar(t, find.byKey(Key(area)), name);
    });
  }

  for (final (name, key) in const [
    ('Bons', 'tab-Bons'),
    ('Übersicht', 'tab-Übersicht'),
    ('Artikel', 'tab-Artikel'),
    ('Abschluss', 'tab-Abschluss'),
    ('Einstellungen', 'settings'),
  ]) {
    testWidgets('$name: alles Antippbare liegt zwischen den Systemleisten', (
      t,
    ) async {
      await _loggedInWithBars(t);
      await _tapKey(t, key);
      _expectTappablesBetweenBars(t, name);
    });
  }

  testWidgets('Geräte testen: alles Antippbare liegt zwischen den '
      'Systemleisten', (t) async {
    await _loggedInWithBars(t);
    await _tapKey(t, 'settings');
    await t.ensureVisible(find.byKey(const Key('open-device-test')));
    await _tapKey(t, 'open-device-test');
    expect(find.byKey(const Key('device-test')), findsOneWidget);
    _expectTappablesBetweenBars(t, 'Geräte testen');
  });

  testWidgets('Kassa mit Bon: alles Antippbare liegt zwischen den '
      'Systemleisten', (t) async {
    await _loggedInWithBars(t);
    await tapItem(t, 'cola');
    _expectTappablesBetweenBars(t, 'Kassa');
  });

  testWidgets('Blatt "Bar bezahlen" und Fertig-Ansicht (bar): alles '
      'Antippbare liegt zwischen den Systemleisten', (t) async {
    await _loggedInWithBars(t);
    await tapItem(t, 'cola');
    await _tapKey(t, 'pay-cash');
    expect(find.byKey(const Key('finish-sale')), findsOneWidget);
    _expectTappablesBetweenBars(t, 'Bar bezahlen');
    await _tapKey(t, 'finish-sale');
    expect(find.byKey(const Key('next-customer')), findsOneWidget);
    _expectTappablesBetweenBars(t, 'Fertig (bar)');
    _expectAboveBottomBar(t, find.byType(SaleDone), 'Fertig (bar)');
  });

  testWidgets('Warten auf Karte und Fertig-Ansicht (Karte): alles Antippbare '
      'liegt zwischen den Systemleisten', (t) async {
    final hang = Completer<CardPaymentResult>();
    await _loggedInWithBars(t, hang: hang);
    await tapItem(t, 'cola');
    await t.tap(find.byKey(const Key('pay-card')));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('card-wait')), findsOneWidget);
    _expectTappablesBetweenBars(t, 'Warte auf Karte');
    hang.complete(const CardPaid(txCode: 'T1'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('next-customer')), findsOneWidget);
    _expectTappablesBetweenBars(t, 'Fertig (Karte)');
    _expectAboveBottomBar(t, find.byType(SaleDone), 'Fertig (Karte)');
  });

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
