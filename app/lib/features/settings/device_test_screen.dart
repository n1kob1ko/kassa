import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../devices/card_terminal.dart';
import '../../devices/device_providers.dart';
import '../../devices/printer.dart';
import '../../ui/pressable.dart';
import '../../ui/tokens.dart';
import 'settings_rows.dart';

/// Ergebnis eines Geräte-Tests: [message] sagt in einem Satz, was geschehen
/// ist. [ok] heißt, der Befehl ging hinaus; ob Papier kommt oder die Lade
/// aufgeht, sieht die Person selbst.
///
/// [calm] ist ein Stand ohne Alarm ("Nicht eingerichtet."): ruhige Fläche, kein
/// grüner Punkt.
class DeviceTestResult {
  const DeviceTestResult.ok(this.message) : ok = true, calm = false;
  const DeviceTestResult.problem(this.message) : ok = false, calm = false;
  const DeviceTestResult.calm(this.message) : ok = false, calm = true;

  final String message;
  final bool ok;
  final bool calm;
}

/// Die eigene Seite "Geräte testen" im Bereich Einstellungen: je Gerät eine
/// Zeile (88 dp) mit Titel, Hilfe und Taste, darunter das Ergebnis.
class DeviceTestScreen extends ConsumerWidget {
  const DeviceTestScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  Future<DeviceTestResult> _fromOutcome(
    Future<PrintOutcome> Function() call,
    String okMessage,
  ) async {
    PrintOutcome outcome;
    try {
      outcome = await call();
    } catch (_) {
      outcome = const PrintOutcome.failed(PrintProblem.unreachable);
    }
    return outcome.ok
        ? DeviceTestResult.ok(okMessage)
        : DeviceTestResult.problem(outcome.message);
  }

  Future<DeviceTestResult> _checkCard(WidgetRef ref) async {
    final status = await ref.read(cardTerminalProvider).status();
    switch (status.state) {
      case CardTerminalState.notConfigured:
        return const DeviceTestResult.calm('Nicht eingerichtet.');
      case CardTerminalState.loggedOut:
        return const DeviceTestResult.problem('Nicht bei SumUp angemeldet.');
      case CardTerminalState.ready:
        if (!(ref.read(internetProvider).value ?? true)) {
          return const DeviceTestResult.problem('Kein Internet.');
        }
        final name = status.merchantName;
        final who = name == null || name.isEmpty
            ? 'Angemeldet'
            : 'Angemeldet als $name';
        return DeviceTestResult.ok(
          '$who. Für einen echten Test 1,00 € mit Karte bonieren und danach '
          'stornieren.',
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final s =
        ref.watch(settingsStreamProvider).value ?? const RegisterSettings();
    final printer = ref.watch(receiptPrinterProvider);
    final reports = ref.read(reportRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: KassaTokens.receiptHeaderHeight,
          padding: const EdgeInsets.only(left: 6, right: 16),
          child: Row(
            children: [
              Pressable(
                key: const Key('device-test-back'),
                onTap: onBack,
                semanticLabel: 'Zurück zu den Einstellungen',
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
                child: Text(
                  'Geräte testen',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.headlineMedium,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SettingsCard(
              title: 'Geräte an dieser Kassa',
              rows: [
                DeviceTestRow(
                  id: 'printer',
                  onFinished: reports.addDeviceTest,
                  title: 'Bondrucker',
                  help: 'Druckt einen kurzen Zettel zur Probe.',
                  action: 'Testdruck',
                  run: () => _fromOutcome(
                    printer.testPrint,
                    'Testdruck geschickt. Kommt Papier?',
                  ),
                ),
                DeviceTestRow(
                  id: 'drawer',
                  onFinished: reports.addDeviceTest,
                  title: 'Geldlade',
                  help: 'Die Lade öffnet sich über den Bondrucker.',
                  action: 'Lade öffnen',
                  run: s.cashDrawerEnabled
                      ? () => _fromOutcome(
                          printer.openDrawer,
                          'Befehl geschickt. Ist die Lade aufgegangen?',
                        )
                      : null,
                  offLabel: 'Ausgeschaltet',
                ),
                DeviceTestRow(
                  id: 'card',
                  onFinished: reports.addDeviceTest,
                  title: 'Kartenterminal',
                  help: 'Prüft die Anmeldung bei SumUp und das Internet.',
                  action: 'Prüfen',
                  run: () => _checkCard(ref),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Eine Zeile der Seite, 88 dp hoch: Titel, ein Satz Hilfe, rechts die Taste
/// (64 dp). Der Schlüssel der Taste ist `test-<id>`, der des Ergebnisses
/// `result-<id>`.
///
/// Ohne [run] gibt es keine Taste: mit [offLabel] steht dort eine neutrale
/// Pille ("Ausgeschaltet"), sonst nichts. Während ein Test läuft, zeigt die Taste einen
/// Fortschrittsring und nimmt keinen zweiten Tipp an.
class DeviceTestRow extends StatefulWidget {
  const DeviceTestRow({
    super.key,
    required this.id,
    required this.title,
    required this.help,
    this.action,
    this.run,
    this.offLabel,
    this.onFinished,
  });

  final String id;
  final String title;
  final String help;
  final String? action;
  final Future<DeviceTestResult> Function()? run;
  final String? offLabel;

  /// Bekommt nach jedem Lauf die Zeile, wie der Bildschirm sie zeigt (für den
  /// Bericht an den Server). Darf nichts werfen.
  final Future<void> Function(List<({String device, bool ok, String text})>)?
  onFinished;

  @override
  State<DeviceTestRow> createState() => _DeviceTestRowState();
}

class _DeviceTestRowState extends State<DeviceTestRow> {
  bool _running = false;
  DeviceTestResult? _result;

  Future<void> _tap() async {
    final run = widget.run;
    if (run == null || _running) return;
    setState(() {
      _running = true;
      _result = null;
    });
    DeviceTestResult result;
    try {
      result = await run();
    } catch (_) {
      result = const DeviceTestResult.problem(
        'Der Test hat nicht geklappt. Bitte nochmal versuchen.',
      );
    }
    unawaited(
      widget.onFinished?.call([
        (device: widget.id, ok: result.ok, text: result.message),
      ]),
    );
    if (!mounted) return;
    setState(() {
      _running = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final result = _result;
    final hasButton = widget.run != null && widget.action != null;

    Widget? control;
    if (hasButton) {
      control = _TestButton(
        key: Key('test-${widget.id}'),
        label: widget.action!,
        running: _running,
        onTap: _tap,
      );
    } else if (widget.offLabel != null) {
      control = NeutralPill(widget.offLabel!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: Key('device-row-${widget.id}'),
          height: 88,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: text.bodyMedium!.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: KassaTokens.spaceXxs),
                    Text(
                      widget.help,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium!.copyWith(
                        fontSize: 14,
                        height: 1.3,
                        color: c.ink2,
                      ),
                    ),
                  ],
                ),
              ),
              if (control != null) ...[
                const SizedBox(width: KassaTokens.spaceXl),
                control,
              ],
            ],
          ),
        ),
        if (result != null)
          Padding(
            padding: const EdgeInsets.only(bottom: KassaTokens.spaceXxl),
            child: _ResultNote(result, resultKey: Key('result-${widget.id}')),
          ),
      ],
    );
  }
}

/// Taste einer Zeile: 64 dp hoch, mit Ring statt Beschriftung, solange der
/// Test läuft.
class _TestButton extends StatelessWidget {
  const _TestButton({
    super.key,
    required this.label,
    required this.running,
    required this.onTap,
  });

  final String label;
  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Pressable(
      onTap: running ? null : onTap,
      dimWhenDisabled: false,
      semanticLabel: running ? '$label läuft' : label,
      child: Container(
        width: 190,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
        ),
        child: running
            ? SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: c.onAccent,
                ),
              )
            : Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: c.onAccent,
                ),
              ),
      ),
    );
  }
}

/// Ergebnis unter der Zeile: in Ordnung mit grünem Punkt auf `fill`, ein
/// ruhiger Stand ohne Punkt auf `fill`, ein Problem in der Warnfläche. Die Fläche trägt den Schlüssel [resultKey].
class _ResultNote extends StatelessWidget {
  const _ResultNote(this.result, {required this.resultKey});

  final DeviceTestResult result;
  final Key resultKey;

  @override
  Widget build(BuildContext context) {
    if (!result.ok && !result.calm) {
      return WarnBox(result.message, key: resultKey);
    }
    final c = KassaColors.of(context);
    return Container(
      key: resultKey,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.fill,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
      ),
      child: Row(
        children: [
          if (!result.calm) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: c.green, shape: BoxShape.circle),
            ),
            const SizedBox(width: KassaTokens.spaceMd),
          ],
          Expanded(
            child: Text(
              result.message,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: c.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
