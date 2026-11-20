import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../rksv/online/connection_check.dart';
import '../../rksv/rksv_providers.dart';
import '../../rksv/rksv_service.dart';
import '../../rksv/rksv_state.dart';
import '../../rksv/setup_facts.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import '../kassa/sale_service.dart';
import '../login/session.dart';
import 'card_check_screen.dart' show checkCardDecoration;
import 'go_live_question.dart';
import 'settings_rows.dart';
import 'signature_panel.dart'
    show irreversibleStepProvider, printRksvReceipt, staleSettingsSentence;

const _unexpected = 'Das hat nicht geklappt. Bitte noch einmal.';

const _steps = [
  'An der alten Kassa den Schlussbeleg erstellen und sie bei FinanzOnline '
      'abmelden.',
  'Signatureinheit und Kassa bei FinanzOnline anmelden, spätestens eine '
      'Woche nach dem Start.',
  'Den Startbeleg mit der App "BMF Belegcheck" prüfen und den Ausdruck '
      'aufheben.',
];

/// Der Bildschirm "Angaben für FinanzOnline" (Entwurf 6.7, Schritte 3 bis 5):
/// links die Angaben, die der Chef bei FinanzOnline einträgt, rechts "Bevor
/// du startest", "Angaben drucken" und "Jetzt in Betrieb nehmen".
///
/// Beim Öffnen holt er die Angaben mit `prepareSetup` zu [facts]; bis sie da
/// sind, stehen ruhige Platzhalter, scheitert es, der Satz mit "Nochmal
/// versuchen". Die Werte bleiben im geschützten Speicher (Q2), darum zeigt
/// jedes Öffnen dieselben. Die Inbetriebnahme verwendet dieselben [facts]
/// (dasselbe Zertifikat) ohne neue Prüfung, fragt einmal nach, druckt den
/// Startbeleg wie den der Probe und ruft dann [onLive]. Scheitert sie, steht
/// ihr Satz da, und der Bildschirm bleibt offen.
///
/// Der AES-Schlüssel ist ein Geheimnis: Er steht nur hier am Bildschirm und
/// auf dem Zettel, nie in einer Fehlermeldung, und lässt sich nicht kopieren.
class SetupFactsScreen extends ConsumerStatefulWidget {
  const SetupFactsScreen({
    super.key,
    required this.facts,
    required this.onBack,
    required this.onLive,
  });

  /// Die Angaben von "Verbindung prüfen" am echten System.
  final ConnectionFacts facts;

  /// Zurück zu den Zugangsdaten.
  final VoidCallback onBack;

  /// Die Kassa ist in Betrieb.
  final VoidCallback onLive;

  @override
  ConsumerState<SetupFactsScreen> createState() => _SetupFactsScreenState();
}

class _SetupFactsScreenState extends ConsumerState<SetupFactsScreen> {
  SetupFacts? _setup;
  bool _loading = true;
  String? _loadProblem;

  bool _printing = false;
  String? _printProblem;

  /// Die Nachfrage ist offen.
  bool _asking = false;

  /// `goLive` läuft.
  bool _going = false;
  String? _goProblem;

  bool get _busy => _working || _asking;

  /// Etwas läuft: Die Tasten sind gesperrt. Während der Nachfrage bleiben sie
  /// hell (die Abdunkelung liegt darüber), Tippen tut dann aber nichts.
  bool get _working => _loading || _printing || _going;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _setup = null;
    super.dispose();
  }

  Future<void> _load() async {
    SetupFacts? setup;
    String? problem;
    try {
      setup = await ref
          .read(rksvServiceProvider)
          .prepareSetup(facts: widget.facts);
    } on RksvProblem catch (e) {
      problem = e.message;
    } on StateError {
      problem = staleSettingsSentence;
    } catch (_) {
      problem = _unexpected;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _setup = setup;
      _loadProblem = problem;
    });
  }

  void _retry() {
    if (_busy) return;
    setState(() {
      _loading = true;
      _loadProblem = null;
    });
    unawaited(_load());
  }

  Future<void> _print() async {
    final setup = _setup;
    if (_busy || setup == null) return;
    final sales = ref.read(saleServiceProvider);
    setState(() {
      _printing = true;
      _printProblem = null;
      _goProblem = null;
    });
    final outcome = await sales.printSetupFacts(setup);
    if (!mounted) return;
    setState(() {
      _printing = false;
      _printProblem = outcome.ok ? null : outcome.message;
    });
  }

  Future<void> _goLive() async {
    if (_busy || _setup == null) return;
    final probe =
        (ref.read(rksvStateProvider).value ?? const RksvState()).mode ==
        RksvMode.probe;
    setState(() {
      _asking = true;
      _goProblem = null;
      _printProblem = null;
    });
    bool yes;
    try {
      yes = await showGoLiveQuestion(context, probe: probe);
    } finally {
      if (mounted) setState(() => _asking = false);
    }
    if (!yes || !mounted) return;
    final staff = ref.read(sessionProvider);
    if (staff == null) return;
    final service = ref.read(rksvServiceProvider);
    final sales = ref.read(saleServiceProvider);
    final going = ref.read(irreversibleStepProvider.notifier);
    setState(() => _going = true);
    going.set(true);
    String? problem;
    try {
      // Dieselben Angaben wie für `prepareSetup`: Die Seriennummer bei
      // FinanzOnline ist die der Kette.
      final start = await service.goLive(staff: staff, facts: widget.facts);
      printRksvReceipt(sales, start);
    } on RksvProblem catch (e) {
      problem = e.message;
    } on StateError {
      problem = staleSettingsSentence;
    } catch (_) {
      problem = _unexpected;
    } finally {
      going.set(false);
    }
    if (!mounted) return;
    if (problem == null) {
      widget.onLive();
      return;
    }
    setState(() {
      _going = false;
      _goProblem = problem;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final setup = _setup;

    return Column(
      key: const Key('setup-facts'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: KassaTokens.receiptHeaderHeight,
          padding: const EdgeInsets.only(left: 6, right: 16),
          child: Row(
            children: [
              Pressable(
                key: const Key('setup-facts-back'),
                onTap: _going ? null : widget.onBack,
                semanticLabel: 'Zurück zu den Zugangsdaten',
                minTapSize: const Size(KassaTokens.minTap, KassaTokens.minTap),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.chevronLeft, size: 28, color: c.ink),
                    Text(
                      'Zurück',
                      style: text.titleMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KassaTokens.spaceXxl),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Angaben für FinanzOnline',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.headlineMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    key: const Key('setup-facts-scroll'),
                    child: _factsCard(context, setup),
                  ),
                ),
                const SizedBox(width: KassaTokens.spaceXxl),
                SizedBox(width: 500, child: _startCard(context)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _factsCard(BuildContext context, SetupFacts? setup) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final problem = _loadProblem;
    final Widget body;
    if (setup != null) {
      final key = setup.aesKeyBase64;
      final half = (key.length + 1) ~/ 2;
      body = Column(
        key: const Key('setup-facts-values'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FactRow(
            name: 'Art der Sicherheitseinrichtung',
            valueKey: const Key('setup-value-kind'),
            values: [setup.kind],
            plain: true,
          ),
          _FactRow(
            name: 'Anbieter',
            valueKey: const Key('setup-value-provider'),
            values: [setup.provider],
          ),
          _FactRow(
            name: 'Seriennummer des Zertifikats',
            valueKey: const Key('setup-value-serial'),
            values: [setup.certSerialHex],
            note: 'dezimal ${setup.certSerialDecimal}',
          ),
          _FactRow(
            name: 'Kassenidentifikationsnummer',
            valueKey: const Key('setup-value-cashbox'),
            values: [setup.cashBoxId],
          ),
          _FactRow(
            name: 'AES-Schlüssel',
            valueKey: const Key('setup-value-aes'),
            values: [key.substring(0, half), key.substring(half)],
          ),
          _FactRow(
            name: 'Prüfwert',
            valueKey: const Key('setup-value-checksum'),
            values: [setup.aesChecksum],
          ),
        ],
      );
    } else if (problem != null) {
      body = Padding(
        padding: const EdgeInsets.only(top: KassaTokens.spaceXxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WarnBox(problem, key: const Key('setup-facts-problem')),
            const SizedBox(height: KassaTokens.spaceXl),
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 200),
                child: PrimaryButton(
                  key: const Key('setup-facts-retry'),
                  label: 'Nochmal versuchen',
                  filled: false,
                  height: 56,
                  onPressed: _working ? null : _retry,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Ruhige Platzhalter, bis die Werte da sind.
      body = Semantics(
        key: const Key('setup-facts-loading'),
        label: 'Die Angaben werden geladen.',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (name, lines, width) in const [
                ('Art der Sicherheitseinrichtung', 1, 300.0),
                ('Anbieter', 1, 120.0),
                ('Seriennummer des Zertifikats', 2, 140.0),
                ('Kassenidentifikationsnummer', 1, 120.0),
                ('AES-Schlüssel', 2, 230.0),
                ('Prüfwert', 1, 50.0),
              ])
                _FactRow(name: name, placeholder: (lines, width)),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        KassaTokens.spaceHuge,
        KassaTokens.spaceHuge,
        KassaTokens.spaceHuge,
        KassaTokens.spaceSm,
      ),
      decoration: checkCardDecoration(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Diese Angaben trägst du bei FinanzOnline ein, wenn du die '
            'Signatureinheit und die Kassa anmeldest.',
            style: text.bodyMedium!.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
          const SizedBox(height: KassaTokens.spaceXl),
          body,
        ],
      ),
    );
  }

  Widget _startCard(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final ready = _setup != null;
    return Container(
      padding: const EdgeInsets.all(KassaTokens.spaceHuge),
      decoration: checkCardDecoration(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Bevor du startest',
                    style: text.titleMedium!.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  for (var i = 0; i < _steps.length; i++) ...[
                    const SizedBox(height: KassaTokens.spaceXl),
                    _Step(number: i + 1, text: _steps[i]),
                  ],
                ],
              ),
            ),
          ),
          if (_printProblem case final problem?) ...[
            const SizedBox(height: KassaTokens.spaceXl),
            WarnBox(problem, key: const Key('setup-print-problem')),
          ],
          if (_goProblem case final problem?) ...[
            const SizedBox(height: KassaTokens.spaceXl),
            WarnBox(problem, key: const Key('setup-go-live-problem')),
          ],
          const SizedBox(height: KassaTokens.spaceXl),
          KeyedSubtree(
            key: const Key('setup-print'),
            child: PrimaryButton(
              label: 'Angaben drucken',
              filled: false,
              icon: LucideIcons.printer,
              leading: _printing ? _Spinner(color: c.ink) : null,
              height: 64,
              labelSize: 18,
              onPressed: _working || !ready ? null : _print,
            ),
          ),
          const SizedBox(height: KassaTokens.spaceXl),
          KeyedSubtree(
            key: const Key('setup-go-live'),
            child: PrimaryButton(
              label: 'Jetzt in Betrieb nehmen',
              leading: _going ? _Spinner(color: c.onAccent) : null,
              height: 76,
              labelSize: 22,
              onPressed: _working || !ready ? null : _goLive,
            ),
          ),
        ],
      ),
    );
  }
}

/// Werte, die der Chef abschreibt (Kennungen, Seriennummer, Schlüssel): die
/// Schrift mit gleich breiten Zeichen ([KassaTokens.monoFontFamily]), in der
/// sich 0 und O, I, l und 1 deutlich unterscheiden.
TextStyle _mono(TextStyle base, {required double size, required Color color}) =>
    base.copyWith(
      fontFamily: KassaTokens.monoFontFamily,
      fontSize: size,
      fontWeight: FontWeight.w600,
      height: 1.35,
      letterSpacing: 0,
      color: color,
    );

/// Eine Angabe: links der Name, rechts der Wert (eine oder mehrere Zeilen,
/// in Ziffern-Schrift mit gleich breiten Zeichen), darunter eine [note].
/// Mit [placeholder] stehen statt der Werte ruhige Balken (Zeilen, Breite).
class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.name,
    this.valueKey,
    this.values = const [],
    this.note,
    this.plain = false,
    this.placeholder,
  });

  final String name;
  final Key? valueKey;
  final List<String> values;
  final String? note;

  /// Ein Wert aus Wörtern (die Art der Sicherheitseinrichtung): normale
  /// Schrift statt der Ziffern-Schrift.
  final bool plain;
  final (int, double)? placeholder;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final valueStyle = plain
        ? text.titleMedium!.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.3,
            color: c.ink,
          )
        : _mono(text.titleMedium!, size: 17, color: c.ink);
    final bars = placeholder;
    final Widget value;
    if (bars != null) {
      value = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < bars.$1; i++)
            Container(
              width: i == 0 ? bars.$2 : bars.$2 * 0.8,
              height: 16,
              margin: EdgeInsets.only(top: i == 0 ? 3 : 8),
              decoration: BoxDecoration(
                color: c.fill,
                borderRadius: BorderRadius.circular(KassaTokens.radiusXs),
              ),
            ),
        ],
      );
    } else {
      value = Column(
        key: valueKey,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final v in values)
            Text(v, textAlign: TextAlign.right, style: valueStyle),
          if (note case final note?)
            Padding(
              padding: const EdgeInsets.only(top: KassaTokens.spaceXxs),
              child: Text(
                note,
                textAlign: TextAlign.right,
                style: _mono(text.bodyMedium!, size: 14, color: c.ink2),
              ),
            ),
        ],
      );
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              name,
              style: text.bodyMedium!.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.ink2,
              ),
            ),
          ),
          const SizedBox(width: KassaTokens.spaceHuge),
          Expanded(child: value),
        ],
      ),
    );
  }
}

/// Ein Punkt von "Bevor du startest": Nummer im Kreis und Satz.
class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final style = Theme.of(context).textTheme.bodyMedium!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: style.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: c.accentInk,
              ),
            ),
          ),
        ),
        const SizedBox(width: KassaTokens.spaceXl),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: style.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: c.ink,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Kleiner Ring in einer Taste, solange etwas läuft. Mit "Bewegung
/// reduzieren" steht er still.
class _Spinner extends StatelessWidget {
  const _Spinner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Läuft',
      excludeSemantics: true,
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          strokeCap: StrokeCap.round,
          value: still ? 0.3 : null,
          color: color,
        ),
      ),
    );
  }
}
