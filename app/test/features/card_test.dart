import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/devices/card_terminal.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/features/kassa/sale_service.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:material_ui/material_ui.dart';

import '../support/cash_pump.dart';
import '../support/fake_devices.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';

PrimaryButton _button(WidgetTester t, String key) =>
    t.widget<PrimaryButton>(find.byKey(Key(key)));

bool _cardOn(WidgetTester t) => _button(t, 'pay-card').onPressed != null;

Future<List<Override>> _setup({
  CardTerminalStatus status = const CardTerminalStatus(
    CardTerminalState.ready,
    merchantName: 'MH12345',
  ),
  InternetSwitch? internet,
  FakeCardTerminal? terminal,
}) async => memoryOverrides(
  terminal: terminal ?? FakeCardTerminal(statusValue: status),
  internet: internet?.stream,
);

Future<void> _open(
  WidgetTester t,
  List<String> ids, {
  List<Override>? overrides,
  Size size = const Size(1280, 800),
  double textScale = 1.0,
}) async {
  await pumpKassa(
    t,
    overrides: overrides ?? await _setup(),
    size: size,
    textScale: textScale,
  );
  for (final id in ids) {
    await tapItem(t, id);
  }
  await t.pumpAndSettle();
}

Future<void> _tapCard(WidgetTester t) async {
  await t.tap(find.byKey(const Key('pay-card')));
  await t.pump();
}

void main() {
  testWidgets('Karte ist aktiv bei Bon, Anmeldung, Internet und mindestens '
      '1,00 €', (t) async {
    await _open(t, ['cola']);
    expect(_cardOn(t), isTrue);
    expect(find.text('nicht angemeldet'), findsNothing);
    expect(find.text('ab 1,00 €'), findsNothing);
    expect(t.getSize(find.byKey(const Key('pay-card'))).height, 80);
    expect(_button(t, 'pay-cash').onPressed, isNotNull);
  });

  group('Gründe unter der Taste', () {
    Future<void> check(
      WidgetTester t, {
      required List<Override> overrides,
      required List<String> ids,
      required String? reason,
    }) async {
      await _open(t, ids, overrides: overrides);
      expect(_cardOn(t), isFalse);
      if (reason != null) {
        expect(
          find.descendant(
            of: find.byKey(const Key('pay-card')),
            matching: find.text(reason),
          ),
          findsOneWidget,
        );
      }
      expect(_button(t, 'pay-cash').onPressed, isNotNull); // Bar nie betroffen
    }

    testWidgets('nicht eingerichtet', (t) async {
      await check(
        t,
        overrides: await _setup(
          status: const CardTerminalStatus(CardTerminalState.notConfigured),
        ),
        ids: ['cola'],
        reason: 'nicht eingerichtet',
      );
    });

    testWidgets('nicht angemeldet', (t) async {
      await check(
        t,
        overrides: await _setup(
          status: const CardTerminalStatus(CardTerminalState.loggedOut),
        ),
        ids: ['cola'],
        reason: 'nicht angemeldet',
      );
    });

    testWidgets('kein Internet', (t) async {
      await check(
        t,
        overrides: await _setup(internet: InternetSwitch(initial: false)),
        ids: ['cola'],
        reason: 'kein Internet',
      );
    });

    testWidgets('ab 1,00 €', (t) async {
      await check(
        t,
        overrides: await _setup(),
        ids: ['leitungswasser'],
        reason: 'ab 1,00 €',
      );
    });

    testWidgets('leerer Bon: keine Zeile', (t) async {
      await _open(t, []);
      expect(_cardOn(t), isFalse);
      expect(
        find.descendant(
          of: find.byKey(const Key('pay-card')),
          matching: find.byType(Text),
        ),
        findsOneWidget, // nur das Wort "Karte"
      );
    });

    testWidgets('der erste Grund gilt: nicht angemeldet vor ab 1,00 €', (
      t,
    ) async {
      await check(
        t,
        overrides: await _setup(
          status: const CardTerminalStatus(CardTerminalState.loggedOut),
        ),
        ids: ['leitungswasser'],
        reason: 'nicht angemeldet',
      );
      expect(find.text('ab 1,00 €'), findsNothing);
    });
  });

  testWidgets('bezahlt: Fertig-Ansicht "Mit Karte bezahlt", VISA **** 4242, '
      'Bon Nr. 1, Bon ist leer', (t) async {
    final terminal = FakeCardTerminal()
      ..next = const CardPaid(
        txCode: 'TX9',
        cardScheme: 'VISA',
        cardLast4: '4242',
      );
    await _open(t, ['cola'], overrides: await _setup(terminal: terminal));
    await _tapCard(t);
    await t.pumpAndSettle();
    expect(find.text('Bezahlt'), findsOneWidget);
    expect(find.text('Mit Karte bezahlt'), findsOneWidget);
    expect(find.text('VISA **** 4242'), findsOneWidget);
    expect(find.textContaining('Rückgeld'), findsNothing);
    expect(textOf(t, const Key('receipt-number')), 'Bon Nr. 1');
    expect(cartOf(t).isEmpty, isTrue);
    expect(await receiptCount(t), 1);
    expect(terminal.payments.single.amountCents, 315);

    await t.tap(find.byKey(const Key('next-customer')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('pay-card')), findsOneWidget);
    expect(find.text('Noch nichts boniert'), findsOneWidget);
  });

  testWidgets('bezahlt ohne Kartendaten: keine Zeile darunter', (t) async {
    await _open(t, ['cola']);
    await _tapCard(t);
    await t.pumpAndSettle();
    expect(find.text('Mit Karte bezahlt'), findsOneWidget);
    expect(find.byKey(const Key('card-detail')), findsNothing);
  });

  testWidgets('abgelehnt: Meldung "Die Kartenzahlung wurde nicht '
      'abgeschlossen.", der Bon '
      'steht noch da, kein Bon gespeichert', (t) async {
    final terminal = FakeCardTerminal()
      ..next = const CardFailed(CardFailure.declined);
    await _open(t, [
      'cola',
      'pommes',
    ], overrides: await _setup(terminal: terminal));
    await _tapCard(t);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('card-wait')), findsNothing);
    expect(
      textOf(t, const Key('card-message')),
      'Die Kartenzahlung wurde nicht abgeschlossen.',
    );
    expect(cartOf(t).lines.map((l) => l.item.id), ['cola', 'pommes']);
    expect(textOf(t, const Key('cart-total')), '7,05 €');
    expect(await receiptCount(t), 0);
    expect(_cardOn(t), isTrue);

    // Nach 6 Sekunden ist der Hinweis weg.
    await t.pump(const Duration(seconds: 5));
    expect(find.byKey(const Key('card-message')), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('card-message')), findsNothing);
  });

  testWidgets('unklar: zurück zur Kassa, darüber die Frage zur Zahlung', (
    t,
  ) async {
    final terminal = FakeCardTerminal()..next = const CardUnknown();
    await _open(t, ['cola'], overrides: await _setup(terminal: terminal));
    await _tapCard(t);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('card-wait')), findsNothing);
    expect(find.byKey(const Key('card-message')), findsNothing);
    expect(find.text('Bezahlt'), findsNothing);
    expect(find.byKey(const Key('unclear-card')), findsOneWidget);
    expect(find.text('Noch nichts boniert'), findsOneWidget);
  });

  testWidgets('zwei schnelle Tipps auf Karte: ein Aufruf am Terminal', (
    t,
  ) async {
    final terminal = FakeCardTerminal()..hang = Completer();
    await _open(t, ['cola'], overrides: await _setup(terminal: terminal));
    await t.tap(find.byKey(const Key('pay-card')));
    await t.tap(find.byKey(const Key('pay-card')), warnIfMissed: false);
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(terminal.payments, hasLength(1));
  });

  testWidgets('während der Zahlung steht "Warte auf Karte" mit dem Betrag', (
    t,
  ) async {
    final hang = Completer<CardPaymentResult>();
    final terminal = FakeCardTerminal()..hang = hang;
    await _open(t, [
      'cola',
      'pommes',
    ], overrides: await _setup(terminal: terminal));
    await _tapCard(t);
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('card-wait')), findsOneWidget);
    expect(find.text('Warte auf Karte'), findsOneWidget);
    expect(textOf(t, const Key('card-wait-amount')), '7,05 €');
    expect(
      find.text('Der Kunde hält Karte oder Handy an das Gerät.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('pay-card')), findsNothing);
    expect(find.byKey(const Key('pay-cash')), findsNothing);
    expect(
      t.getSize(find.byKey(const Key('card-wait-dot'))),
      const Size(14, 14),
    );

    hang.complete(const CardPaid(txCode: 'T'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('card-wait')), findsNothing);
    expect(find.text('Mit Karte bezahlt'), findsOneWidget);
  });

  testWidgets('ohne Animationen steht der Punkt still', (t) async {
    final terminal = FakeCardTerminal()..hang = Completer();
    await _open(t, ['cola'], overrides: await _setup(terminal: terminal));
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _tapCard(t);
    await t.pump(const Duration(milliseconds: 100));
    // Nichts läuft mehr: pumpAndSettle kehrt zurück.
    await t.pumpAndSettle();
    expect(find.byKey(const Key('card-wait')), findsOneWidget);
  });

  testWidgets('jeder Tipp auf Karte nimmt eine neue Kennung', (t) async {
    final terminal = FakeCardTerminal()
      ..next = const CardFailed(CardFailure.declined);
    await _open(t, ['cola'], overrides: await _setup(terminal: terminal));
    await _tapCard(t);
    await t.pumpAndSettle();
    await _tapCard(t);
    await t.pumpAndSettle();
    expect(terminal.payments, hasLength(2));
    final ids = terminal.payments.map((p) => p.paymentId).toSet();
    expect(ids, hasLength(2));
  });

  testWidgets('Internet fällt weg: Kopfzeile meldet es, Karte geht aus, Bar '
      'bleibt', (t) async {
    final net = InternetSwitch();
    await _open(t, ['cola'], overrides: await _setup(internet: net));
    expect(find.byKey(const Key('offline-pill')), findsNothing);
    expect(_cardOn(t), isTrue);

    net.set(false);
    await t.pumpAndSettle();
    expect(
      find.text('Kein Internet. Bar bonieren geht weiter.'),
      findsOneWidget,
    );
    expect(_cardOn(t), isFalse);
    expect(find.text('kein Internet'), findsOneWidget);
    expect(_button(t, 'pay-cash').onPressed, isNotNull);

    net.set(true);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('offline-pill')), findsNothing);
    expect(_cardOn(t), isTrue);
  });

  testWidgets('Kassa weckt den Kartenleser beim Öffnen und nach jedem Bon', (
    t,
  ) async {
    final terminal = FakeCardTerminal();
    await _open(t, ['cola'], overrides: await _setup(terminal: terminal));
    expect(terminal.calls, ['prepare']);
    await _tapCard(t);
    await t.pumpAndSettle();
    expect(terminal.calls, ['prepare', 'prepare']);
  });

  testWidgets('nicht angemeldet: kein Wecken', (t) async {
    final off = FakeCardTerminal(
      statusValue: const CardTerminalStatus(CardTerminalState.loggedOut),
    );
    await _open(t, ['cola'], overrides: await _setup(terminal: off));
    expect(off.calls, isEmpty);
  });

  testWidgets('kleines Tablet 960 × 600 und Schrift 1,3: Karte und Bar '
      'bleiben ganz sichtbar', (t) async {
    await _open(
      t,
      ['cola'],
      overrides: await _setup(
        status: const CardTerminalStatus(CardTerminalState.loggedOut),
      ),
      size: const Size(960, 600),
      textScale: 1.3,
    );
    expect(t.takeException(), isNull);
    for (final key in ['pay-cash', 'pay-card']) {
      final rect = t.getRect(find.byKey(Key(key)));
      expect(rect.bottom, lessThanOrEqualTo(600));
      expect(rect.right, lessThanOrEqualTo(960));
      expect(rect.height, 80);
    }
    final reason = t.getRect(find.text('nicht angemeldet'));
    final card = t.getRect(find.byKey(const Key('pay-card')));
    expect(card.contains(reason.topLeft), isTrue);
    expect(card.contains(reason.bottomRight), isTrue);
  });

  group('während einer Kartenzahlung', () {
    testWidgets('Reiter, Einstellungen und Abmelden tun nichts, danach '
        'wieder', (t) async {
      final terminal = FakeCardTerminal(
        statusValue: const CardTerminalStatus(
          CardTerminalState.ready,
          merchantName: 'MH12345',
        ),
      )..hang = Completer<CardPaymentResult>();
      await _open(t, ['cola'], overrides: await _setup(terminal: terminal));
      // Als Chef, damit es die Einstellungen gibt.
      await containerOf(t).read(sessionProvider.notifier).login('4711');
      await t.pumpAndSettle();
      await tapItem(t, 'cola');
      await _tapCard(t);
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('card-wait')), findsOneWidget);
      for (final key in ['tab-Bons', 'tab-Abschluss', 'settings', 'staff']) {
        await t.tap(find.byKey(Key(key)), warnIfMissed: false);
        await t.pump(const Duration(milliseconds: 100));
        expect(
          find.byKey(const Key('area-kassa')),
          findsOneWidget,
          reason: key,
        );
        expect(find.byKey(const Key('card-wait')), findsOneWidget, reason: key);
        expect(containerOf(t).read(sessionProvider), isNotNull, reason: key);
      }
      terminal.hang!.complete(const CardPaid(txCode: 'TX1'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('next-customer')), findsOneWidget);
      await t.tap(find.byKey(const Key('tab-Bons')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('area-bons')), findsOneWidget);
    });

    testWidgets('payByCard wirft trotzdem: zurück zum Bon, nichts hängt', (
      t,
    ) async {
      await _open(
        t,
        ['cola'],
        overrides: [
          ...await _setup(),
          saleServiceProvider.overrideWith(_ThrowingSaleService.new),
        ],
      );
      await _tapCard(t);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('card-wait')), findsNothing);
      expect(find.byKey(const Key('pay-card')), findsOneWidget);
      expect(_cardOn(t), isTrue);
    });
  });
}

/// Ein Verkaufsdienst, dessen Kartenzahlung wirft.
class _ThrowingSaleService extends SaleService {
  _ThrowingSaleService(super.ref);

  @override
  Future<CardSaleOutcome> payByCard({
    required String paymentId,
    required Cart cart,
    required Staff staff,
  }) async => throw StateError('kaputt');
}
