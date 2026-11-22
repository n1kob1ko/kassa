import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../domain/receipt.dart';
import '../../rksv/card/card_signer.dart';
import '../../rksv/dep_export.dart';
import '../../rksv/online/atrust_client.dart';
import '../../rksv/online/online_providers.dart';
import '../../rksv/rksv_providers.dart';
import '../../rksv/rksv_secrets.dart';
import '../../rksv/rksv_service.dart';
import '../../rksv/rksv_state.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import '../kassa/sale_service.dart';
import '../login/session.dart';
import '../shell/irreversible_step.dart';
import '../shell/shell_screen.dart'
    show openCardSetup, openCredentials, openSignerChoice;
import 'card_setup_screen.dart' show CardSetupPurpose;
import 'probe_question.dart';
import 'protocol_export_sheet.dart';
import 'rksv_task_row.dart';
import 'settings_rows.dart';

const _unexpected = 'Das hat nicht geklappt. Bitte noch einmal.';
const _notSaved = 'Die Datei konnte nicht gespeichert werden.';

/// Der Satz zu einem StateError des Dienstes: Der Stand hat sich geändert,
/// während die Karte noch den alten zeigte.
const staleSettingsSentence =
    'Das geht gerade nicht. Bitte die Einstellungen neu öffnen.';

/// Wie der Bildschirm "Verbindung prüfen" geöffnet wird: [enable] nach
/// "Weiter" im Blatt "Mit A-Trust ausprobieren?" (mit "Online-Probe
/// starten"), [check] aus der Zeile "Verbindung prüfen" der Online-Probe,
/// [checkLive] aus derselben Zeile in Betrieb (am echten System), [relogin]
/// aus "Erneut anmelden". Nur [relogin] zählt als Antippen des Chefs.
enum ConnectionCheckOpening { enable, check, checkLive, relogin }

/// Druckt einen Start-, Null- oder Schlussbeleg über denselben Weg wie
/// "Nochmal drucken". Wartet nicht und meldet nichts: Der Beleg steht, ob
/// der Druck gelingt oder nicht.
void printRksvReceipt(SaleService sales, Receipt receipt) {
  unawaited(sales.reprint(receipt).then<void>((_) {}, onError: (Object _) {}));
}

/// Welche Zeile eine Rückmeldung bekommt.
enum _Action {
  enable,
  zero,
  export,
  disable,
  connection,
  card,
  setup,
  cardPin,
  credentials,
  decommission,
  other,
}

/// Art der Rückmeldung: geschafft (Haken), nur zur Kenntnis (Info) oder ein
/// Problem (Warnzeichen). Das Wort sagt es immer, das Zeichen ergänzt es.
enum _Tone { done, info, problem }

typedef _Message = ({_Action action, String text, _Tone tone});

/// Die Karte "Signatur" der Einstellungen (`signature-card`): der Stand der
/// Signatur der Bons als Pille, ein Hinweis mit "Verstanden", die offenen
/// Aufgaben und für den Chef die Tasten der Probe-Signatur (Einschalten,
/// Nullbeleg, Protokoll ausgeben, Beenden). Für die Online-Probe dazu "Mit
/// A-Trust ausprobieren" (aus), "Verbindung prüfen" und bei abgelehnten
/// Zugangsdaten "Erneut anmelden"; alle drei rufen [onOpenConnectionCheck].
/// Für die Karten-Probe "Mit Karte ausprobieren" (aus), das "Karte und PIN"
/// öffnet ([openCardSetup]); läuft sie, dieselben Zeilen wie die Online-Probe
/// ohne "Verbindung prüfen".
/// Außer in Betrieb steht "Signatur einrichten" da, das die Wahl "Womit
/// signiert die Kassa?" öffnet ([openSignerChoice]). In Betrieb an A-Trust:
/// "Verbindung prüfen" am echten System, Nullbeleg, Protokoll, "Zugangsdaten"
/// und "Kassa außer Betrieb nehmen",
/// bei abgelehnten Zugangsdaten "Zugangsdaten neu eingeben". In Betrieb mit
/// der Karte: "Karte und PIN" (für eine neue PIN), Nullbeleg, Protokoll und
/// "Kassa außer Betrieb nehmen". Hat die Karte die PIN abgelehnt (gespeicherter
/// Stand der PIN oder Grund des Ausfalls), steht das einmal in der Karte, für
/// den Chef mit "PIN neu eingeben". Außer Betrieb bleiben die Aufgaben und
/// "Protokoll ausgeben" (Q15).
/// Dazu die Zeile "Karte prüfen" (`open-card-check`), die [onOpenCardCheck]
/// ruft. Ein Ausfall zeigt seinen Grund unter dem Zustand. Während eine
/// Aktion läuft, sind alle Tasten gesperrt. Start-, Null- und Schlussbeleg
/// werden danach gedruckt wie "Nochmal drucken"; ohne Drucker geschieht
/// nichts, und ein Druckfehler ändert am Beleg nichts.
class SignaturePanel extends ConsumerStatefulWidget {
  const SignaturePanel({
    super.key,
    this.announcement,
    required this.onOpenCardCheck,
    required this.onOpenConnectionCheck,
  });

  /// Das Ergebnis eines Wegs, der eben in die Einstellungen zurückgeführt
  /// hat ("Die Kassa ist in Betrieb."): steht als geschafft unten in der
  /// Karte, bis die nächste Aktion ihre eigene Rückmeldung bringt.
  final String? announcement;

  final VoidCallback onOpenCardCheck;
  final ValueChanged<ConnectionCheckOpening> onOpenConnectionCheck;

  @override
  ConsumerState<SignaturePanel> createState() => _SignaturePanelState();
}

class _SignaturePanelState extends ConsumerState<SignaturePanel> {
  bool _busy = false;
  late _Message? _message = switch (widget.announcement) {
    final text? => (action: _Action.other, text: text, tone: _Tone.done),
    null => null,
  };

  /// Der gespeicherte Stand der PIN der Karte; `null`, solange er nicht
  /// gelesen ist, ohne Kette mit Karte und wenn der Speicher nicht antwortet.
  CardPinStatus? _pinStatus;

  /// Was am Stand der Signatur zählt, als der Stand der PIN gelesen wurde.
  Object? _pinReadFor;

  /// Zählt die Lesungen: Nur die letzte setzt [_pinStatus].
  int _pinReads = 0;

  ProviderSubscription<AsyncValue<RksvState>>? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _stateSubscription = ref.listenManual(
      rksvStateProvider,
      (_, next) => _pinStatusFor(next.value),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _stateSubscription?.close();
    super.dispose();
  }

  /// Liest den Stand der PIN neu, wenn eine Kette mit Karte läuft und sich an
  /// ihr etwas geändert hat. Wartet höchstens [CardSigner.storageLimit]; das
  /// Bild wartet nie darauf.
  void _pinStatusFor(RksvState? state) {
    final key = state == null || !_cardChain(state)
        ? null
        : (state.mode, state.chain, state.unit, state.outageReason);
    if (key == _pinReadFor) return;
    _pinReadFor = key;
    final read = ++_pinReads;
    if (key == null) {
      if (_pinStatus != null && mounted) setState(() => _pinStatus = null);
      return;
    }
    unawaited(() async {
      CardPinStatus? status;
      try {
        status = await ref
            .read(rksvSecretsProvider)
            .cardPinStatus()
            .timeout(CardSigner.storageLimit);
      } catch (_) {
        // Ein Speicher, der nicht antwortet, zeigt keinen Hinweis.
        status = null;
      }
      if (!mounted || read != _pinReads) return;
      setState(() => _pinStatus = status);
    }());
  }

  static bool _cardChain(RksvState state) => switch (state.mode) {
    RksvMode.probe => state.unit == RksvUnit.cardTest,
    RksvMode.live => state.unit == RksvUnit.card,
    RksvMode.off => false,
  };

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
      // Der Stand hat sich schon geändert (etwa die Probe läuft schon). Die
      // Zeile der Aktion ist dann vielleicht schon weg, darum unten.
      message = (
        action: _Action.other,
        text: staleSettingsSentence,
        tone: _Tone.problem,
      );
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

  void _print(Receipt receipt) =>
      printRksvReceipt(ref.read(saleServiceProvider), receipt);

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

  /// "Mit A-Trust ausprobieren": einmal nachfragen, dann "Verbindung prüfen"
  /// mit "Online-Probe starten".
  Future<void> _tryOnline() async {
    if (_busy) return;
    final yes = await _ask(
      () => showProbeQuestion(context, ProbeQuestion.online),
    );
    if (!yes || !mounted) return;
    widget.onOpenConnectionCheck(ConnectionCheckOpening.enable);
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

  /// "Kassa außer Betrieb nehmen": einmal nachfragen, dann `decommission`
  /// und der Schlussbeleg gedruckt. Solange es läuft, hält die Hülle den
  /// Bildschirm ([irreversibleStepProvider]).
  Future<void> _decommission() async {
    if (_busy) return;
    final yes = await _ask(
      () => showProbeQuestion(context, ProbeQuestion.decommission),
    );
    if (!yes || !mounted) return;
    final step = ref.read(irreversibleStepProvider.notifier);
    step.set(true);
    try {
      await _run(_Action.decommission, () async {
        final staff = ref.read(sessionProvider);
        if (staff == null) return null;
        _print(await ref.read(rksvServiceProvider).decommission(staff: staff));
        return null;
      });
    } finally {
      step.set(false);
    }
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
    final live = state.mode == RksvMode.live;
    final off = state.mode == RksvMode.off;
    final online = probe && state.unit == RksvUnit.atrustTest;
    final cardProbe = probe && state.unit == RksvUnit.cardTest;
    final cardLive = live && state.unit == RksvUnit.card;
    final atrustLive = live && !cardLive;
    final notice = state.notice;
    final pinRejectedSentence = const CardSignException(
      CardSignProblem.pinRejected,
    ).sentence;
    final pinMissingSentence = const CardSignException(
      CardSignProblem.pinMissing,
    ).sentence;
    final pinStatus = _pinStatus;
    // Der Grund des Ausfalls, nach dem nur eine neue PIN hilft (wie im
    // Hinweis der Kassa): abgelehnt oder fehlt.
    final pinReason =
        state.outage &&
            (state.outageReason == pinRejectedSentence ||
                state.outageReason == pinMissingSentence)
        ? state.outageReason
        : null;
    // Abgelehnt (C4): eine beantwortete Ablehnung, zwei Prüfungen ohne
    // Antwort oder der Grund des Ausfalls (auch, wenn der PIN-Wächter die
    // PIN zurückhält); oder die PIN fehlt (B2).
    final pinRejected =
        (cardProbe || cardLive) &&
        ((pinStatus != null &&
                (pinStatus.rejected || pinStatus.unanswered >= 2)) ||
            pinReason != null);
    // Der Satz, der gilt: der des Ausfalls, sonst die Ablehnung.
    final pinSentence = pinReason ?? pinRejectedSentence;

    final String help;
    final Widget pill;
    switch (state.mode) {
      case RksvMode.probe:
        final what = online
            ? 'Signatur vom Testsystem von A-Trust, nicht für den echten '
                  'Betrieb.'
            : cardProbe
            ? 'Signatur mit der Karte, nicht für den echten Betrieb.'
            : 'Probe-Signatur, nicht für den echten Betrieb.';
        help = state.cashBoxId == null
            ? what
            : '$what Kassen-ID ${state.cashBoxId}.';
        final word = online
            ? 'Online-Probe'
            : cardProbe
            ? 'Karten-Probe'
            : 'Probe';
        pill = state.outage
            ? WarnPill('$word, Signatur ausgefallen')
            : _AccentPill(word);
      case RksvMode.live:
        final what = cardLive
            ? 'Signatur mit der Karte.'
            : 'Signatur von A-Trust.';
        help = state.cashBoxId == null
            ? what
            : '$what Kassen-ID ${state.cashBoxId}.';
        pill = state.outage
            ? const WarnPill('In Betrieb, Signatur ausgefallen')
            : const _AccentPill('In Betrieb');
      case RksvMode.off when state.decommissioned:
        help = 'Die Kassa ist außer Betrieb. Neue Bons sind Testbons.';
        pill = const NeutralPill('Außer Betrieb');
      case RksvMode.off:
        help = 'Für die Registrierkassen-Pflicht. Noch nicht eingerichtet.';
        pill = const NeutralPill('Nicht eingerichtet');
    }

    Widget card(bool rejected) => SettingsCard(
      key: const Key('signature-card'),
      title: 'Signatur',
      rows: [
        SettingsRow(
          title: 'Signatur der Bons',
          help: help,
          // Der Satz zur PIN steht nur einmal da, im Hinweis.
          note: state.outage && !(pinRejected && pinReason != null)
              ? state.outageReason
              : null,
          control: pill,
        ),
        if (notice != null)
          _NoticeRow(
            text: notice,
            onOk: isChef && !_busy ? _clearNotice : null,
            showButton: isChef,
          ),
        if (rejected)
          _WarnRow(
            key: const Key('rksv-rejected'),
            text: 'A-Trust hat die Zugangsdaten abgelehnt.',
            buttonKey: live ? 'rksv-credentials-again' : 'rksv-relogin',
            label: live ? 'Zugangsdaten neu eingeben' : 'Erneut anmelden',
            onPressed: _busy
                ? null
                : live
                ? () => openCredentials(context, edit: true)
                : () => widget.onOpenConnectionCheck(
                    ConnectionCheckOpening.relogin,
                  ),
          ),
        if (pinRejected)
          _WarnRow(
            key: const Key('rksv-card-rejected'),
            text: pinSentence,
            buttonKey: 'rksv-card-repin',
            label: 'PIN neu eingeben',
            showButton: isChef,
            onPressed: _busy
                ? null
                : () => openCardSetup(context, CardSetupPurpose.repin),
          ),
        if (state.tasks.isNotEmpty)
          RksvTaskBlock(
            tasks: state.tasks,
            practice: state.onlyProbeTasks,
            busy: _busy,
            onDone: isChef ? _completeTask : null,
          ),
        if (isChef && cardLive)
          _action(
            _Action.cardPin,
            key: 'rksv-card-pin',
            title: 'Karte und PIN',
            help: 'Kartenleser, Karte und PIN prüfen.',
            label: 'Prüfen',
            onPressed: () => openCardSetup(context, CardSetupPurpose.repin),
          ),
        if (isChef && (online || atrustLive))
          _action(
            _Action.connection,
            key: 'rksv-connection-check',
            title: 'Verbindung prüfen',
            help: 'Internet und A-Trust ausprobieren.',
            label: 'Prüfen',
            onPressed: () => widget.onOpenConnectionCheck(
              live
                  ? ConnectionCheckOpening.checkLive
                  : ConnectionCheckOpening.check,
            ),
          ),
        if (isChef && (probe || live))
          _action(
            _Action.zero,
            key: 'rksv-zero',
            title: 'Nullbeleg drucken',
            help: 'Ein Beleg über 0 Euro, zum Beispiel für eine Kontrolle.',
            label: 'Drucken',
            onPressed: _zero,
          ),
        if (isChef && (probe || live || ended))
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
        if (isChef && atrustLive)
          _action(
            _Action.credentials,
            key: 'rksv-credentials',
            title: 'Zugangsdaten',
            help: 'Benutzername und Passwort von A-Trust ändern.',
            label: 'Ändern',
            onPressed: () => openCredentials(context),
          ),
        if (isChef && live)
          _action(
            _Action.decommission,
            key: 'rksv-decommission',
            title: 'Kassa außer Betrieb nehmen',
            help:
                'Die Kassa erstellt einen Schlussbeleg. Danach sind neue Bons '
                'wieder Testbons.',
            label: 'Außer Betrieb',
            onPressed: _decommission,
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
        if (isChef && off)
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
        if (isChef && off)
          _action(
            _Action.connection,
            key: 'rksv-online-probe-on',
            title: 'Mit A-Trust ausprobieren',
            help:
                'Die Bons werden über das Testsystem von A-Trust signiert. '
                'Braucht Internet. Sie bleiben Testbons.',
            label: 'Ausprobieren',
            onPressed: _tryOnline,
          ),
        if (isChef && off)
          _action(
            _Action.card,
            key: 'rksv-card-probe-on',
            title: 'Mit Karte ausprobieren',
            help:
                'Die Signaturkarte im Kartenleser signiert die Bons. Ohne '
                'Internet. Sie bleiben Testbons.',
            label: 'Ausprobieren',
            onPressed: () => openCardSetup(context, CardSetupPurpose.probe),
          ),
        if (isChef && !live)
          _action(
            _Action.setup,
            key: 'rksv-setup',
            title: 'Signatur einrichten',
            help:
                'Für den echten Betrieb, mit Signaturkarte oder A-Trust '
                'online.',
            label: 'Einrichten',
            onPressed: () => openSignerChoice(context),
          ),
        // Ein Problem beim Erledigen einer Aufgabe oder beim Hinweis, oder
        // ein Stand, der sich inzwischen geändert hat.
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

    // Das Kennzeichen "abgelehnt" liegt im Sitzungshalter (P1), nicht im
    // Stand, je System (Q4): in der Online-Probe das des Testsystems, in
    // Betrieb das des echten. Nur der Chef kann es aufheben.
    if (!isChef || !(online || atrustLive)) return card(false);
    return ValueListenableBuilder<bool>(
      valueListenable: ref
          .watch(
            atrustKeeperProvider(
              atrustLive ? AtrustSystem.live : AtrustSystem.test,
            ),
          )
          .rejected,
      builder: (context, rejected, _) => card(rejected),
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

/// Ein Problem, das nur der Chef aufhebt, in der Warnfläche: A-Trust hat
/// die Zugangsdaten abgelehnt (`rksv-rejected`; in der Online-Probe "Erneut
/// anmelden" (`rksv-relogin`), das "Verbindung prüfen" als Antippen des Chefs
/// öffnet, in Betrieb "Zugangsdaten neu eingeben" (`rksv-credentials-again`),
/// das die Felder der Zugangsdaten öffnet), oder die Karte hat die PIN
/// abgelehnt (`rksv-card-rejected` mit "PIN neu eingeben",
/// `rksv-card-repin`). Ohne [showButton] steht nur der Satz da.
class _WarnRow extends StatelessWidget {
  const _WarnRow({
    super.key,
    required this.text,
    required this.buttonKey,
    required this.label,
    required this.onPressed,
    this.showButton = true,
  });

  final String text;
  final String buttonKey;
  final String label;
  final VoidCallback? onPressed;
  final bool showButton;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        decoration: BoxDecoration(
          color: c.warnBg,
          borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: c.warnInk,
                ),
              ),
            ),
            if (showButton) ...[
              const SizedBox(width: KassaTokens.spaceXl),
              PrimaryButton(
                key: Key(buttonKey),
                label: label,
                filled: false,
                height: 56,
                onPressed: onPressed,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pille im Akzent ("Probe", "Online-Probe", "In Betrieb"): `accentSoft` mit
/// `accentInk`.
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
