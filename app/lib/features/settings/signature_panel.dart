import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../domain/receipt.dart';
import '../../rksv/dep_export.dart';
import '../../rksv/rksv_providers.dart';
import '../../rksv/rksv_service.dart';
import '../../rksv/rksv_state.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import '../kassa/sale_service.dart';
import '../login/session.dart';
import 'probe_question.dart';
import 'protocol_export_sheet.dart';
import 'rksv_task_row.dart';
import 'settings_rows.dart';

const _unexpected = 'Das hat nicht geklappt. Bitte noch einmal.';
const _notSaved = 'Die Datei konnte nicht gespeichert werden.';

/// Welche Zeile eine Rückmeldung bekommt.
enum _Action { enable, zero, export, disable, other }

/// Art der Rückmeldung: geschafft (Haken), nur zur Kenntnis (Info) oder ein
/// Problem (Warnzeichen). Das Wort sagt es immer, das Zeichen ergänzt es.
enum _Tone { done, info, problem }

typedef _Message = ({_Action action, String text, _Tone tone});

/// Die Karte "Signatur" der Einstellungen (`signature-card`): der Stand der
/// Signatur der Bons als Pille, ein Hinweis mit "Verstanden", die offenen
/// Aufgaben und für den Chef die Tasten der Probe-Signatur (Einschalten,
/// Nullbeleg, Protokoll ausgeben, Beenden). Dazu die Zeile "Karte prüfen"
/// (`open-card-check`), die [onOpenCardCheck] ruft. Während eine Aktion läuft,
/// sind alle Tasten gesperrt. Start-, Null- und Schlussbeleg werden danach
/// gedruckt wie "Nochmal drucken"; ohne Drucker geschieht nichts, und ein
/// Druckfehler ändert am Beleg nichts.
class SignaturePanel extends ConsumerStatefulWidget {
  const SignaturePanel({super.key, required this.onOpenCardCheck});

  final VoidCallback onOpenCardCheck;

  @override
  ConsumerState<SignaturePanel> createState() => _SignaturePanelState();
}

class _SignaturePanelState extends ConsumerState<SignaturePanel> {
  bool _busy = false;
  _Message? _message;

  /// Sperrt die Tasten, führt [body] aus und zeigt danach dessen Satz unter
  /// der Zeile von [action]. RksvProblem zeigt seinen Satz, eine andere
  /// Ausnahme nie ihren eigenen Text.
  Future<void> _run(
    _Action action,
    Future<({String text, _Tone tone})?> Function() body,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    _Message? message;
    try {
      final result = await body();
      if (result != null) {
        message = (action: action, text: result.text, tone: result.tone);
      }
    } on RksvProblem catch (e) {
      message = (action: action, text: e.message, tone: _Tone.problem);
    } on StateError {
      // Der Stand hat sich schon geändert (etwa die Probe läuft schon); die
      // Karte folgt dem Strom des Stands.
    } catch (_) {
      message = (action: action, text: _unexpected, tone: _Tone.problem);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
    });
  }

  /// Öffnet eine Rückfrage oder ein Blatt, gesperrt wie eine Aktion, damit
  /// doppeltes Antippen nur eines öffnet.
  Future<T> _ask<T>(Future<T> Function() open) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      return await open();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Druckt [receipt] über denselben Weg wie "Nochmal drucken". Wartet nicht
  /// und meldet nichts: Der Beleg steht, ob der Druck gelingt oder nicht.
  void _print(Receipt receipt) {
    unawaited(
      ref
          .read(saleServiceProvider)
          .reprint(receipt)
          .then<void>((_) {}, onError: (Object _) {}),
    );
  }

  Future<void> _enable() async {
    if (_busy) return;
    final yes = await _ask(
      () => showProbeQuestion(context, ProbeQuestion.enable),
    );
    if (!yes || !mounted) return;
    await _run(_Action.enable, () async {
      final staff = ref.read(sessionProvider);
      if (staff == null) return null;
      _print(await ref.read(rksvServiceProvider).enableProbe(staff: staff));
      return null;
    });
  }

  Future<void> _disable() async {
    if (_busy) return;
    final yes = await _ask(
      () => showProbeQuestion(context, ProbeQuestion.disable),
    );
    if (!yes || !mounted) return;
    await _run(_Action.disable, () async {
      final staff = ref.read(sessionProvider);
      if (staff == null) return null;
      _print(await ref.read(rksvServiceProvider).disableProbe(staff: staff));
      return null;
    });
  }

  Future<void> _zero() => _run(_Action.zero, () async {
    final staff = ref.read(sessionProvider);
    if (staff == null) return null;
    _print(await ref.read(rksvServiceProvider).zeroReceipt(staff: staff));
    return null;
  });

  Future<void> _export() async {
    if (_busy) return;
    final now = ref.read(clockProvider).now();
    final range = await _ask(() => showProtocolExportSheet(context, now: now));
    if (range == null || !mounted) return;
    await _run(_Action.export, () async {
      final ExportOutcome outcome;
      try {
        outcome = await ref
            .read(rksvServiceProvider)
            .exportProtocol(range, now: ref.read(clockProvider).now());
      } on RksvProblem {
        rethrow;
      } catch (_) {
        throw const RksvProblem(_notSaved);
      }
      return switch (outcome) {
        ExportOutcome.saved => (text: 'Gespeichert.', tone: _Tone.done),
        ExportOutcome.cancelled => (
          text: 'Nicht gespeichert.',
          tone: _Tone.info,
        ),
        ExportOutcome.empty => (
          text: 'In diesem Zeitraum gibt es keine Einträge.',
          tone: _Tone.info,
        ),
      };
    });
  }

  Future<void> _completeTask(RksvTask task) => _run(_Action.other, () async {
    await ref.read(rksvRepositoryProvider).completeTask(task.id);
    return null;
  });

  Future<void> _clearNotice() => _run(_Action.other, () async {
    await ref.read(rksvRepositoryProvider).clearNotice();
    return null;
  });

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final state = ref.watch(rksvStateProvider).value ?? const RksvState();
    final isChef = ref.watch(sessionProvider)?.isChef ?? false;
    final ended = ref.watch(rksvHasEndedChainProvider).value ?? false;
    final probe = state.mode == RksvMode.probe;
    final notice = state.notice;

    final String help;
    final Widget pill;
    switch (state.mode) {
      case RksvMode.probe:
        help = state.cashBoxId == null
            ? 'Probe-Signatur, nicht für den echten Betrieb.'
            : 'Probe-Signatur, nicht für den echten Betrieb. '
                  'Kassen-ID ${state.cashBoxId}.';
        pill = state.outage
            ? const WarnPill('Probe, Signatur ausgefallen')
            : const _AccentPill('Probe');
      case RksvMode.live:
        help = state.cashBoxId == null
            ? 'Für die Registrierkassen-Pflicht.'
            : 'Für die Registrierkassen-Pflicht. '
                  'Kassen-ID ${state.cashBoxId}.';
        pill = const NeutralPill('In Betrieb');
      case RksvMode.off:
        help = 'Für die Registrierkassen-Pflicht. Noch nicht eingerichtet.';
        pill = const NeutralPill('Nicht eingerichtet');
    }

    return SettingsCard(
      key: const Key('signature-card'),
      title: 'Signatur',
      rows: [
        SettingsRow(title: 'Signatur der Bons', help: help, control: pill),
        if (notice != null)
          _NoticeRow(
            text: notice,
            onOk: isChef && !_busy ? _clearNotice : null,
            showButton: isChef,
          ),
        if (state.tasks.isNotEmpty)
          RksvTaskBlock(
            tasks: state.tasks,
            probe: probe,
            busy: _busy,
            onDone: isChef ? _completeTask : null,
          ),
        if (isChef && state.mode == RksvMode.off)
          _action(
            _Action.enable,
            key: 'rksv-probe-on',
            title: 'Zum Ausprobieren einschalten',
            help:
                'Bons bekommen einen QR-Code und kommen ins Protokoll, wie '
                'später im echten Betrieb. Sie bleiben Testbons.',
            label: 'Einschalten',
            onPressed: _enable,
          ),
        if (isChef && probe)
          _action(
            _Action.zero,
            key: 'rksv-zero',
            title: 'Nullbeleg drucken',
            help: 'Ein Beleg über 0 Euro, zum Beispiel für eine Kontrolle.',
            label: 'Drucken',
            onPressed: _zero,
          ),
        if (isChef && (probe || ended))
          _action(
            _Action.export,
            key: 'rksv-export',
            title: 'Protokoll ausgeben',
            help:
                'Speichert die signierten Bons als Datei, zum Beispiel auf '
                'einen USB-Stick.',
            label: 'Ausgeben',
            onPressed: _export,
          ),
        if (isChef && probe)
          _action(
            _Action.disable,
            key: 'rksv-probe-off',
            title: 'Probe beenden',
            help:
                'Die Kassa erstellt einen Schlussbeleg. Neue Bons haben dann '
                'keinen QR-Code mehr.',
            label: 'Beenden',
            onPressed: _disable,
          ),
        // Ein Problem beim Erledigen einer Aufgabe oder beim Hinweis.
        if (_message case final m? when m.action == _Action.other)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _MessageLine(m),
          ),
        Pressable(
          key: const Key('open-card-check'),
          onTap: widget.onOpenCardCheck,
          semanticLabel: 'Karte prüfen',
          child: SettingsRow(
            title: 'Karte prüfen',
            help: 'Kartenleser und Signaturkarte ausprobieren.',
            control: Icon(LucideIcons.chevronRight, size: 24, color: c.ink2),
          ),
        ),
      ],
    );
  }

  /// Eine Zeile mit Titel, Hilfe und rechts der Taste (56 dp, neutral). Die
  /// Rückmeldung der Aktion steht darunter.
  Widget _action(
    _Action action, {
    required String key,
    required String title,
    required String help,
    required String label,
    required VoidCallback onPressed,
  }) {
    final message = _message;
    final row = SettingsRow(
      title: title,
      help: help,
      control: PrimaryButton(
        key: Key(key),
        label: label,
        filled: false,
        height: 56,
        onPressed: _busy ? null : onPressed,
      ),
    );
    if (message == null || message.action != action) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [row, _MessageLine(message)],
    );
  }
}

/// Ruhige Zeile unter einer Aktion: das Ergebnis ("Gespeichert.") oder bei
/// einem Problem dessen Satz mit einem Warnzeichen davor.
class _MessageLine extends StatelessWidget {
  const _MessageLine(this.message);

  final _Message message;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Padding(
      key: const Key('rksv-message'),
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              switch (message.tone) {
                _Tone.done => LucideIcons.check,
                _Tone.info => LucideIcons.info,
                _Tone.problem => LucideIcons.triangleAlert,
              },
              size: 18,
              color: switch (message.tone) {
                _Tone.done => c.green,
                _Tone.info => c.ink2,
                _Tone.problem => c.warnInk,
              },
            ),
          ),
          const SizedBox(width: KassaTokens.spaceMd),
          Expanded(
            child: Text(
              message.text,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
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

/// Der Hinweis für den Chef (`state.notice`) mit "Verstanden"
/// (`rksv-notice-ok`).
class _NoticeRow extends StatelessWidget {
  const _NoticeRow({
    required this.text,
    required this.onOk,
    required this.showButton,
  });

  final String text;
  final VoidCallback? onOk;
  final bool showButton;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Container(
      key: const Key('rksv-notice'),
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(LucideIcons.info, size: 20, color: c.ink2),
          const SizedBox(width: KassaTokens.spaceLg),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: c.ink,
              ),
            ),
          ),
          if (showButton) ...[
            const SizedBox(width: KassaTokens.spaceXl),
            PrimaryButton(
              key: const Key('rksv-notice-ok'),
              label: 'Verstanden',
              filled: false,
              height: 56,
              onPressed: onOk,
            ),
          ],
        ],
      ),
    );
  }
}

/// Pille im Akzent ("Probe"): `accentSoft` mit `accentInk`.
class _AccentPill extends StatelessWidget {
  const _AccentPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(KassaTokens.radiusPill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge!.copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: c.accentInk,
        ),
      ),
    );
  }
}
