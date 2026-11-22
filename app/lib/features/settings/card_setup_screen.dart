import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart' show rksvRepositoryProvider;
import '../../rksv/card/card_check.dart';
import '../../rksv/card/card_facts.dart';
import '../../rksv/card/card_providers.dart';
import '../../rksv/rksv_providers.dart';
import '../../rksv/rksv_service.dart';
import '../../rksv/rksv_state.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import '../kassa/sale_service.dart';
import '../login/session.dart';
import 'card_check_screen.dart';
import 'card_pin_sheet.dart';
import 'settings_rows.dart';
import 'signature_panel.dart';

const _stored = 'Karte und PIN sind gespeichert.';
const _probeRunning = 'Die Probe mit der Karte läuft.';
const _unexpected = 'Das hat nicht geklappt. Bitte noch einmal.';

/// Wozu "Karte und PIN" geöffnet ist: [probe] aus "Mit Karte ausprobieren"
/// ("Probe starten"), [live] auf dem Weg zum echten Betrieb ("Weiter"),
/// [repin] für eine laufende Kette mit Karte ("Fertig"; die Karte muss die
/// der Kette sein).
enum CardSetupPurpose { probe, live, repin }

/// Die Seite "Karte und PIN" im Bereich Einstellungen, aufgebaut wie "Karte
/// prüfen": links die fünf Zeilen von [CardCheck] mit ihren Sätzen
/// ([CardCheckRows]), rechts die Hinweise zur PIN, "Nochmal prüfen" und die
/// Haupttaste von [purpose].
///
/// Beim Öffnen liest ein Lauf die Karte (bei [CardSetupPurpose.repin] mit der
/// Seriennummer der laufenden Kette mit Karte). Ist für die gelesene Karte
/// schon eine PIN gespeichert und nicht abgelehnt, steht statt Zeile 5
/// "Karte und PIN sind gespeichert." mit "PIN neu eingeben"; für "Probe
/// starten" und "Weiter" macht [CardSetup] dann die Probe-Unterschrift mit
/// der gespeicherten PIN, ohne Zahlenfeld. Sonst fragt "PIN eingeben" einmal
/// nach der PIN, und [CardSetup.signAndStore] speichert sie, wenn Zeile 5
/// grün wird. Die Haupttaste ist erst aktiv, wenn für die gelesene Karte eine
/// PIN gespeichert und nicht abgelehnt ist (und, außer bei "Fertig", Zeile 5
/// grün ist).
///
/// Schutz der Karte: Die Seite hält keine PIN; sie geht vom Zahlenfeld
/// sofort an [CardSetup]. Während ein Lauf oder eine Probe-Unterschrift
/// läuft, ist jede Taste gesperrt, die zur Karte geht.
class CardSetupScreen extends ConsumerStatefulWidget {
  const CardSetupScreen({
    super.key,
    required this.purpose,
    required this.onBack,
    this.onLive,
    this.onProbeStarted,
  });

  final CardSetupPurpose purpose;

  /// "Weiter" bei [CardSetupPurpose.live], mit den Angaben der Karte.
  final void Function(CardFacts facts)? onLive;

  /// Zurück zur Karte "Signatur" ("Zurück", "Fertig"), bei
  /// [CardSetupPurpose.live] zur Wahl "Womit signiert die Kassa?".
  final VoidCallback onBack;

  /// Nach "Probe starten": zurück in die Einstellungen mit diesem Satz. Ohne
  /// [onProbeStarted] gilt [onBack].
  final ValueChanged<String>? onProbeStarted;

  @override
  ConsumerState<CardSetupScreen> createState() => _CardSetupScreenState();
}

class _CardSetupScreenState extends ConsumerState<CardSetupScreen> {
  StreamSubscription<CardCheckState>? _changes;
  bool _pinOpen = false;

  /// Der Lauf dieser Seite ist fertig (ob mit Haken oder Kreuz), und es
  /// steht fest, ob für die gelesene Karte eine PIN gespeichert ist.
  bool _read = false;

  /// Für die gelesene Karte ist eine PIN gespeichert und nicht abgelehnt.
  bool _storedPin = false;

  /// Der Chef hat auf dieser Seite eine PIN eingegeben: Zeile 5 zeigt dann
  /// den Stand von [CardCheck], "gespeichert" steht unter den Zeilen.
  bool _entered = false;

  /// [CardSetup] arbeitet (Probe-Unterschrift, Speichern).
  bool _working = false;
  bool _starting = false;
  String? _problem;

  CardCheck get _check => ref.read(cardCheckProvider);

  bool get _needsFacts => widget.purpose != CardSetupPurpose.repin;

  @override
  void initState() {
    super.initState();
    _changes = _check.changes.listen((_) {
      if (mounted) setState(() {});
    });
    unawaited(_readCard());
  }

  @override
  void dispose() {
    // Nur das Zuhören endet; ein laufender Lauf läuft weiter.
    _changes?.cancel();
    super.dispose();
  }

  /// Liest die Karte (Zeilen 1 bis 4) und schaut, ob für sie schon eine PIN
  /// gespeichert ist. Läuft schon ein Prüflauf, wartet die Seite auf ihn und
  /// macht danach weiter, als hätte sie ihn gestartet (C1); bei
  /// [CardSetupPurpose.repin] liest sie danach selbst, mit der Seriennummer
  /// der Kette.
  Future<void> _readCard() async {
    final check = _check;
    if (check.state.busy) {
      try {
        await check.changes.firstWhere((s) => !s.busy);
      } catch (_) {
        // Der Prüflauf ist verworfen.
        return;
      }
      if (!mounted) return;
      if (widget.purpose == CardSetupPurpose.repin) return _readCard();
    } else {
      String? serial;
      if (widget.purpose == CardSetupPurpose.repin) {
        // Ohne die Seriennummer der Kette läuft nichts zur Karte: Sonst
        // könnte die PIN einer anderen Karte die gespeicherte ersetzen (C3).
        try {
          serial = await ref.read(rksvServiceProvider).cardChainSerial();
        } catch (_) {
          serial = null;
        }
        if (!mounted) return;
        if (serial == null) {
          setState(() => _problem = _unexpected);
          return;
        }
      }
      await check.run(expectSerialHex: serial);
      if (!mounted) return;
    }
    final setup = ref.read(cardSetupProvider);
    // Hält der PIN-Wächter zurück, zeigt Zeile 5 ihn, wie "Karte prüfen".
    var stored = await setup.storedForReadCard() && !check.state.guardBlocks;
    if (!mounted) return;
    setState(() {
      _read = true;
      _storedPin = stored;
    });
    if (!stored || !_needsFacts) return;
    setState(() => _working = true);
    await setup.signWithStored();
    stored = check.facts != null && await setup.storedForReadCard();
    if (!mounted) return;
    setState(() {
      _working = false;
      _storedPin = stored;
    });
  }

  /// "Zähler ist wieder voll": danach sucht die Seite die gespeicherte PIN
  /// neu und zeigt, was sie findet. Eine Probe-Unterschrift macht sie nicht
  /// von selbst; die macht "Nochmal prüfen" oder der Chef mit
  /// "PIN eingeben" (C2).
  Future<void> _resetGuard() async {
    final check = _check;
    await check.resetGuard();
    if (!mounted || check.state.guardBlocks || !_read) return;
    final stored = await ref.read(cardSetupProvider).storedForReadCard();
    if (!mounted) return;
    setState(() {
      _storedPin = stored && !check.state.guardBlocks;
      _entered = false;
    });
  }

  /// "Nochmal prüfen".
  void _retry() {
    if (_check.state.busy || _working || _starting) return;
    setState(() {
      _read = false;
      _storedPin = false;
      _entered = false;
      _problem = null;
    });
    unawaited(_readCard());
  }

  /// "PIN eingeben" und "PIN neu eingeben".
  Future<void> _enterPin() async {
    final check = _check;
    // Erst wenn feststeht, ob eine PIN gespeichert ist (und ihre
    // Probe-Unterschrift fertig ist), fragt die Seite nach einer PIN.
    if (_pinOpen || !_read || _working || !check.state.canSign) return;
    _pinOpen = true;
    final String? pin;
    try {
      pin = await showCardPinSheet(context);
    } finally {
      _pinOpen = false;
    }
    if (pin == null || !mounted) return;
    final setup = ref.read(cardSetupProvider);
    setState(() {
      _entered = true;
      _working = true;
      _storedPin = false;
      _problem = null;
    });
    final result = await setup.signAndStore(pin);
    if (!mounted) return;
    setState(() {
      _working = false;
      _storedPin = result == null;
      _problem = result == null || result.isEmpty ? null : result;
    });
  }

  Future<void> _main(CardFacts? facts) async {
    final newPin = _entered && _storedPin;
    switch (widget.purpose) {
      case CardSetupPurpose.probe:
        if (facts == null) return;
        if (newPin) await _retryWhileStarting();
        if (!mounted) return;
        await _startProbe(facts);
      case CardSetupPurpose.live:
        if (facts == null) return;
        if (newPin) await _retryWhileStarting();
        if (!mounted) return;
        widget.onLive?.call(facts);
      case CardSetupPurpose.repin:
        // Wie "Nochmal prüfen", ohne darauf zu warten (B1).
        if (newPin) unawaited(_retryAfterNewPin());
        widget.onBack();
    }
  }

  /// Vor "Probe starten" und "Weiter": Erst endet ein Ausfall der laufenden
  /// Kette mit Karte, dann geht es weiter; die Tasten sind solange gesperrt.
  Future<void> _retryWhileStarting() async {
    if (_starting) return;
    setState(() => _starting = true);
    await _retryAfterNewPin();
    if (mounted) setState(() => _starting = false);
  }

  /// Eine neue PIN ist gespeichert: Läuft ein Ausfall einer Kette mit Karte,
  /// versucht der Dienst einmal den Sammelbeleg (B1). Fehler gehen still
  /// unter.
  Future<void> _retryAfterNewPin() async {
    try {
      final staff = ref.read(sessionProvider);
      if (staff == null) return;
      final service = ref.read(rksvServiceProvider);
      final state = await ref.read(rksvRepositoryProvider).current();
      if (!state.outage ||
          (state.unit != RksvUnit.card && state.unit != RksvUnit.cardTest)) {
        return;
      }
      await service.retrySignature(staff: staff);
    } catch (_) {
      // Der nächste Bon oder "Nochmal prüfen" versucht es wieder.
    }
  }

  /// "Probe starten": Karten-Probe mit Startbeleg von der Karte, gedruckt
  /// wie die Probe; danach zurück in die Einstellungen.
  Future<void> _startProbe(CardFacts facts) async {
    if (_starting) return;
    final staff = ref.read(sessionProvider);
    if (staff == null) return;
    final service = ref.read(rksvServiceProvider);
    final sales = ref.read(saleServiceProvider);
    setState(() {
      _starting = true;
      _problem = null;
    });
    String? problem;
    try {
      final receipt = await service.enableCardProbe(staff: staff, facts: facts);
      printRksvReceipt(sales, receipt);
    } on RksvProblem catch (e) {
      problem = e.message;
    } on StateError {
      problem = staleSettingsSentence;
    } catch (_) {
      problem = _unexpected;
    }
    if (!mounted) return;
    if (problem == null) {
      final done = widget.onProbeStarted;
      if (done == null) {
        widget.onBack();
      } else {
        done(_probeRunning);
      }
      return;
    }
    setState(() {
      _starting = false;
      _problem = problem;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final check = ref.watch(cardCheckProvider);
    final state = check.state;
    final busy = state.busy || _working || _starting;
    final facts = check.facts;
    final ready = _read && _storedPin && !busy;
    final mainEnabled = ready && (!_needsFacts || facts != null);
    final storedRow = _storedPin && !_entered;
    final storedLine = _storedPin && _entered;

    final rows = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, KassaTokens.spaceXl),
          child: Text(
            'Steck die Signaturkarte in den Kartenleser. Die Kassa liest sie '
            'und fragt dann einmal nach der PIN.',
            style: text.bodyMedium!.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
        ),
        CardCheckRows(
          state: state,
          onEnterPin: _enterPin,
          onResetGuard: _resetGuard,
          // Bis feststeht, ob eine PIN gespeichert ist, steht Zeile 5, wie
          // sie ist, aber ohne "PIN eingeben".
          signature: storedRow
              ? RowResult(_working ? RowState.running : RowState.ok, _stored)
              : !_read
              ? state.rows[CheckRow.signature]
              : null,
          signatureTrailing: storedRow
              ? KeyedSubtree(
                  key: const Key('card-setup-repin'),
                  child: PrimaryButton(
                    label: 'PIN neu eingeben',
                    filled: false,
                    height: 56,
                    labelSize: 18,
                    onPressed: busy || !state.canSign ? null : _enterPin,
                  ),
                )
              : null,
        ),
        if (storedLine)
          const Padding(
            key: Key('card-setup-stored'),
            padding: EdgeInsets.fromLTRB(4, KassaTokens.spaceXl, 4, 0),
            child: _StoredLine(),
          ),
      ],
    );

    final about = Container(
      padding: const EdgeInsets.all(KassaTokens.spaceHuge),
      decoration: checkCardDecoration(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Die PIN bleibt verschlüsselt auf diesem Tablet. So muss '
                    'sie niemand bei jedem Bon eingeben.',
                    style: text.bodyMedium!.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: KassaTokens.spaceXl),
                  Text(
                    'Nach drei falschen Eingaben sperrt sich die Karte. Gib '
                    'nur eine PIN ein, die du sicher weißt.',
                    style: text.bodyMedium!.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.45,
                      color: c.ink2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_problem case final problem?) ...[
            const SizedBox(height: KassaTokens.spaceXl),
            WarnBox(problem, key: const Key('card-setup-problem')),
          ],
          const SizedBox(height: KassaTokens.spaceXl),
          KeyedSubtree(
            key: const Key('card-setup-retry'),
            child: PrimaryButton(
              label: 'Nochmal prüfen',
              filled: false,
              height: 64,
              labelSize: 18,
              onPressed: busy ? null : _retry,
            ),
          ),
          const SizedBox(height: KassaTokens.spaceXl),
          KeyedSubtree(
            key: const Key('card-setup-main'),
            child: PrimaryButton(
              label: switch (widget.purpose) {
                CardSetupPurpose.probe => 'Probe starten',
                CardSetupPurpose.live => 'Weiter',
                CardSetupPurpose.repin => 'Fertig',
              },
              height: 76,
              labelSize: 22,
              onPressed: mainEnabled ? () => _main(facts) : null,
            ),
          ),
        ],
      ),
    );

    return Column(
      key: const Key('card-setup'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: KassaTokens.receiptHeaderHeight,
          padding: const EdgeInsets.only(left: 6, right: 16),
          child: Row(
            children: [
              Pressable(
                key: const Key('card-setup-back'),
                onTap: widget.onBack,
                semanticLabel: widget.purpose == CardSetupPurpose.live
                    ? 'Zurück zur Wahl der Signatur'
                    : 'Zurück zu den Einstellungen',
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
                  'Karte und PIN',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.headlineMedium,
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
                    key: const Key('card-setup-rows'),
                    child: rows,
                  ),
                ),
                const SizedBox(width: KassaTokens.spaceXxl),
                SizedBox(width: 468, child: about),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "Karte und PIN sind gespeichert." unter den Zeilen, mit Haken davor, wie
/// eine geschaffte Rückmeldung der Karte "Signatur".
class _StoredLine extends StatelessWidget {
  const _StoredLine();

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(LucideIcons.check, size: 18, color: c.green),
        ),
        const SizedBox(width: KassaTokens.spaceMd),
        Expanded(
          child: Text(
            _stored,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: c.ink,
            ),
          ),
        ),
      ],
    );
  }
}
