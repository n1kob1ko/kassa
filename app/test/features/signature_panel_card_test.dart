// Die Karte "Signatur" mit einer Kette der Signaturkarte: Karten-Probe, in
// Betrieb, Ausfall, abgelehnte PIN und außer Betrieb. Der Stand steht fest in
// der Datenbank (erfundene Kassen-ID), der Stand der PIN im geschützten
// Speicher im Speicher.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/features/settings/card_setup_screen.dart';
import 'package:kassa/features/settings/signature_panel.dart';
import 'package:kassa/rksv/card/card_signer.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/rksv_state.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:material_ui/material_ui.dart';

import '../support/pump.dart';
import '../support/settings_pump.dart';
import '../support/signature_pump.dart';

Finder _key(String key) => find.byKey(Key(key));

Finder _inCard(Finder f) =>
    find.descendant(of: _key('signature-card'), matching: f);

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(_key(key));
  await t.pumpAndSettle();
  await t.tap(_key(key));
  await t.pumpAndSettle();
}

String _sentence(CardSignProblem p) => CardSignException(p).sentence;

final _pinRejected = _sentence(CardSignProblem.pinRejected);

const _cardPinHelp = 'Kartenleser, Karte und PIN prüfen.';

/// Alle Tasten-Zeilen der Karte, die es je nach Stand gibt.
const _allRows = [
  'rksv-card-pin',
  'rksv-connection-check',
  'rksv-zero',
  'rksv-export',
  'rksv-credentials',
  'rksv-decommission',
  'rksv-probe-off',
  'rksv-probe-on',
  'rksv-online-probe-on',
  'rksv-card-probe-on',
  'rksv-setup',
];

/// Genau die Zeilen [present] aus [_allRows] stehen da, dazu "Karte prüfen".
void _expectRows(List<String> present) {
  for (final k in _allRows) {
    expect(
      _key(k),
      present.contains(k) ? findsOneWidget : findsNothing,
      reason: k,
    );
  }
  expect(_key('open-card-check'), findsOneWidget);
}

/// Ein geschützter Speicher, dessen Stand der PIN nie antwortet.
class _SilentPinStatus extends MemoryRksvSecrets {
  @override
  Future<CardPinStatus> cardPinStatus() => Completer<CardPinStatus>().future;
}

Future<void> _settings(
  WidgetTester t, {
  MemoryRksvSecrets? secrets,
  Brightness brightness = Brightness.light,
}) => pumpSettings(
  t,
  size: const Size(1280, 960),
  brightness: brightness,
  extra: signatureOverrides(secrets: secrets),
);

/// Die Karte "Signatur" allein, angemeldet als Anna (ohne Recht des Chefs).
Future<ProviderContainer> _asStaff(
  WidgetTester t, {
  MemoryRksvSecrets? secrets,
}) async {
  await pumpApp(
    t,
    SingleChildScrollView(
      child: SignaturePanel(
        onOpenCardCheck: () {},
        onOpenConnectionCheck: (_) {},
      ),
    ),
    size: const Size(1280, 960),
    overrides: [
      ...await memoryOverrides(),
      ...signatureOverrides(secrets: secrets),
    ],
  );
  final c = ProviderScope.containerOf(t.element(find.byType(SignaturePanel)));
  await c.read(sessionProvider.notifier).login('1234');
  await t.pumpAndSettle();
  return c;
}

Future<MemoryRksvSecrets> _rejectedSecrets({
  bool rejected = true,
  int unanswered = 0,
}) async {
  final secrets = MemoryRksvSecrets();
  await secrets.writeCardPinStatus(
    CardPinStatus(rejected: rejected, unanswered: unanswered),
  );
  return secrets;
}

void main() {
  group('Karten-Probe', () {
    testWidgets('Hilfe, Pille "Karten-Probe", Zeilen wie die Online-Probe '
        'ohne "Verbindung prüfen"', (t) async {
      await _settings(t);
      await seedProbe(t, unit: RksvUnit.cardTest);
      expect(
        _inCard(
          find.text(
            'Signatur mit der Karte, nicht für den echten Betrieb. '
            'Kassen-ID $fixedCashBoxId.',
          ),
        ),
        findsOneWidget,
      );
      expect(_inCard(find.text('Karten-Probe')), findsOneWidget);
      _expectRows(['rksv-zero', 'rksv-export', 'rksv-probe-off', 'rksv-setup']);
      expect(find.text(_pinRejected), findsNothing);
    });

    testWidgets('Ausfall: Pille und Grund der Karte', (t) async {
      await _settings(t);
      await seedProbe(
        t,
        unit: RksvUnit.cardTest,
        outageSince: DateTime(2026, 11, 17, 13, 5),
        outageReason: _sentence(CardSignProblem.noCard),
      );
      expect(
        _inCard(find.text('Karten-Probe, Signatur ausgefallen')),
        findsOneWidget,
      );
      expect(
        _inCard(find.text(_sentence(CardSignProblem.noCard))),
        findsOneWidget,
      );
    });

    testWidgets('abgelehnte PIN: Hinweis mit "PIN neu eingeben"', (t) async {
      await _settings(t, secrets: await _rejectedSecrets());
      await seedProbe(t, unit: RksvUnit.cardTest);
      expect(_inCard(find.text(_pinRejected)), findsOneWidget);
      expect(_key('rksv-card-repin'), findsOneWidget);
    });
  });

  group('in Betrieb mit Karte', () {
    testWidgets('Hilfe, Pille und genau die Zeilen der Karte', (t) async {
      await _settings(t);
      await seedLive(t, unit: RksvUnit.card, tasks: liveTasks);
      expect(
        _inCard(
          find.text('Signatur mit der Karte. Kassen-ID $fixedLiveCashBoxId.'),
        ),
        findsOneWidget,
      );
      expect(_inCard(find.text('In Betrieb')), findsOneWidget);
      _expectRows([
        'rksv-card-pin',
        'rksv-zero',
        'rksv-export',
        'rksv-decommission',
      ]);
      expect(_inCard(find.text('Karte und PIN')), findsOneWidget);
      expect(_inCard(find.text(_cardPinHelp)), findsOneWidget);
      expect(t.widget<PrimaryButton>(_key('rksv-card-pin')).label, 'Prüfen');
      expect(t.getSize(_key('rksv-card-pin')).height, 56);
      expect(_inCard(find.text(rksvTaskText(liveTasks.first))), findsOneWidget);
      expect(find.text(_pinRejected), findsNothing);
      // Die Zeilen von A-Trust fehlen, auch mit abgelehnten Zugangsdaten.
      expect(_key('rksv-rejected'), findsNothing);
    });

    testWidgets('"Karte und PIN" öffnet "Karte und PIN" für eine neue PIN', (
      t,
    ) async {
      await _settings(t);
      await seedLive(t, unit: RksvUnit.card);
      await _tap(t, 'rksv-card-pin');
      expect(find.byType(CardSetupScreen), findsOneWidget);
      expect(
        t.widget<CardSetupScreen>(find.byType(CardSetupScreen)).purpose,
        CardSetupPurpose.repin,
      );
    });

    testWidgets('Ausfall: Pille und Grund der Karte', (t) async {
      await _settings(t);
      await seedLive(
        t,
        unit: RksvUnit.card,
        outageSince: DateTime(2026, 11, 17, 13, 5),
        outageReason: _sentence(CardSignProblem.noCard),
      );
      expect(
        _inCard(find.text('In Betrieb, Signatur ausgefallen')),
        findsOneWidget,
      );
      expect(
        _inCard(find.text(_sentence(CardSignProblem.noCard))),
        findsOneWidget,
      );
      expect(find.text(_pinRejected), findsNothing);
      _expectRows([
        'rksv-card-pin',
        'rksv-zero',
        'rksv-export',
        'rksv-decommission',
      ]);
    });
  });

  group('abgelehnte PIN', () {
    for (final (name, rejected, unanswered) in [
      ('abgelehnt', true, 0),
      ('zweimal ohne Antwort', false, 2),
    ]) {
      testWidgets('$name: Hinweis einmal, "PIN neu eingeben" öffnet "Karte '
          'und PIN"', (t) async {
        await _settings(
          t,
          secrets: await _rejectedSecrets(
            rejected: rejected,
            unanswered: unanswered,
          ),
        );
        await seedLive(t, unit: RksvUnit.card);
        expect(_inCard(find.text(_pinRejected)), findsOneWidget);
        expect(_key('rksv-card-repin'), findsOneWidget);
        expect(
          find.descendant(
            of: _key('rksv-card-repin'),
            matching: find.text('PIN neu eingeben'),
          ),
          findsOneWidget,
        );
        expect(t.getSize(_key('rksv-card-repin')).height, 56);
        await _tap(t, 'rksv-card-repin');
        expect(
          t.widget<CardSetupScreen>(find.byType(CardSetupScreen)).purpose,
          CardSetupPurpose.repin,
        );
      });
    }

    testWidgets('einmal ohne Antwort: kein Hinweis', (t) async {
      await _settings(
        t,
        secrets: await _rejectedSecrets(rejected: false, unanswered: 1),
      );
      await seedLive(t, unit: RksvUnit.card);
      expect(find.text(_pinRejected), findsNothing);
      expect(_key('rksv-card-repin'), findsNothing);
    });

    testWidgets('nur der Grund des Ausfalls: Hinweis einmal', (t) async {
      await _settings(t);
      await seedLive(
        t,
        unit: RksvUnit.card,
        outageSince: DateTime(2026, 11, 17, 13, 5),
        outageReason: _pinRejected,
      );
      expect(
        _inCard(find.text('In Betrieb, Signatur ausgefallen')),
        findsOneWidget,
      );
      expect(find.text(_pinRejected), findsOneWidget);
      expect(_key('rksv-card-repin'), findsOneWidget);
    });

    testWidgets('Grund und gespeicherter Stand: Hinweis trotzdem einmal', (
      t,
    ) async {
      await _settings(t, secrets: await _rejectedSecrets());
      await seedLive(
        t,
        unit: RksvUnit.card,
        outageSince: DateTime(2026, 11, 17, 13, 5),
        outageReason: _pinRejected,
      );
      expect(find.text(_pinRejected), findsOneWidget);
      expect(_key('rksv-card-repin'), findsOneWidget);
    });

    testWidgets('ein Speicher ohne Antwort: kein Hinweis, die Karte steht', (
      t,
    ) async {
      await _settings(t, secrets: _SilentPinStatus());
      await seedLive(t, unit: RksvUnit.card);
      expect(_key('rksv-card-pin'), findsOneWidget);
      await t.pump(CardSigner.storageLimit + const Duration(seconds: 1));
      await t.pumpAndSettle();
      expect(find.text(_pinRejected), findsNothing);
      expect(_key('rksv-card-repin'), findsNothing);
      expect(_key('rksv-card-pin'), findsOneWidget);
    });

    testWidgets('Mitarbeiter: Hinweis ohne Taste, keine Tasten des Chefs', (
      t,
    ) async {
      final c = await _asStaff(t, secrets: await _rejectedSecrets());
      await seedLive(t, unit: RksvUnit.card, container: c);
      expect(find.text(_pinRejected), findsOneWidget);
      expect(find.text('In Betrieb'), findsOneWidget);
      expect(_key('rksv-card-repin'), findsNothing);
      expect(find.text('PIN neu eingeben'), findsNothing);
      _expectRows([]);
    });
  });

  testWidgets('Mitarbeiter in Betrieb mit Karte: keine Tasten des Chefs', (
    t,
  ) async {
    final c = await _asStaff(t);
    await seedLive(t, unit: RksvUnit.card, container: c);
    expect(
      find.text('Signatur mit der Karte. Kassen-ID $fixedLiveCashBoxId.'),
      findsOneWidget,
    );
    _expectRows([]);
  });

  testWidgets('außer Betrieb nach Karte: Aufgaben, Protokoll und die Zeilen '
      'von aus, nichts der Karte', (t) async {
    await _settings(t, secrets: await _rejectedSecrets());
    await seedLive(
      t,
      unit: RksvUnit.card,
      tasks: decommissionTasks,
      decommissioned: true,
    );
    expect(_inCard(find.text('Außer Betrieb')), findsOneWidget);
    expect(
      _inCard(find.text(rksvTaskText(decommissionTasks.first))),
      findsOneWidget,
    );
    _expectRows([
      'rksv-export',
      'rksv-probe-on',
      'rksv-online-probe-on',
      'rksv-card-probe-on',
      'rksv-setup',
    ]);
    expect(find.text(_pinRejected), findsNothing);
    expect(_key('rksv-card-repin'), findsNothing);
  });
}
