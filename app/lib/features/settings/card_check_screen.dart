import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../rksv/card/card_check.dart';
import '../../rksv/card/card_providers.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import 'card_pin_sheet.dart';
import 'settings_rows.dart';

const _shareSubject = 'Kassa: Bericht Karte prüfen';

const _titles = {
  CheckRow.reader: 'Kartenleser',
  CheckRow.access: 'Zugriff',
  CheckRow.card: 'Signaturkarte',
  CheckRow.certificate: 'Zertifikat',
  CheckRow.signature: 'Probe-Unterschrift',
};

/// Die Seite "Karte prüfen" im Bereich Einstellungen: links die fünf Zeilen
/// des Prüflaufs, rechts was geprüft wird, "Bericht teilen" und die
/// Hauptaktion. Die Texte der Zeilen kommen unverändert aus [CardCheck].
///
/// Schutz der Karte: Das Öffnen startet nichts. Während ein Lauf oder eine
/// Probe-Unterschrift läuft, ist jede Taste gesperrt, die zur Karte geht. Die
/// PIN kommt aus dem PIN-Fenster und geht sofort an [CardCheck.sign]; die
/// Seite hält sie nirgends. Wer die Seite verlässt, beendet keinen Lauf: er
/// läuft zu Ende und gibt den Leser frei, die Seite zeigt beim Zurückkommen
/// den Stand.
class CardCheckScreen extends ConsumerStatefulWidget {
  const CardCheckScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<CardCheckScreen> createState() => _CardCheckScreenState();
}

class _CardCheckScreenState extends ConsumerState<CardCheckScreen> {
  StreamSubscription<CardCheckState>? _changes;
  bool _pinOpen = false;
  bool _confirmReset = false;
  bool _sharing = false;
  bool _shareFailed = false;

  CardCheck get _check => ref.read(cardCheckProvider);

  @override
  void initState() {
    super.initState();
    _changes = _check.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    // Nur das Zuhören endet; ein laufender Lauf läuft weiter.
    _changes?.cancel();
    super.dispose();
  }

  void _run() {
    if (_check.state.busy) return;
    setState(() {
      _confirmReset = false;
      _shareFailed = false;
    });
    unawaited(_check.run());
  }

  Future<void> _enterPin() async {
    final check = _check;
    if (_pinOpen || !check.state.canSign) return;
    _pinOpen = true;
    final String? pin;
    try {
      pin = await showCardPinSheet(context);
    } finally {
      _pinOpen = false;
    }
    if (pin == null) return;
    unawaited(check.sign(pin));
  }

  Future<void> _resetGuard() async {
    setState(() => _confirmReset = false);
    await _check.resetGuard();
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() {
      _sharing = true;
      _shareFailed = false;
    });
    bool shown;
    try {
      shown = await ref
          .read(shareSheetProvider)
          .text(subject: _shareSubject, text: _check.state.report);
    } catch (_) {
      shown = false;
    }
    if (!mounted) return;
    setState(() {
      _sharing = false;
      _shareFailed = !shown;
    });
  }

  /// "Zähler ist wieder voll" hilft nur, wenn die Karte noch einen Versuch
  /// hat; einer gesperrten Karte hilft es nicht.
  static bool _canResetGuard(CardCheckState state) =>
      state.guardBlocks && !state.cardLocked;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final state = ref.watch(cardCheckProvider).state;
    final busy = state.busy;
    final reader = state.rows[CheckRow.reader]!.state;
    final started = reader != RowState.waiting;
    final finished = reader == RowState.ok || reader == RowState.problem;
    final signature = state.rows[CheckRow.signature]!;
    final showPin = state.canSign && signature.state != RowState.ok;
    final showReset = _canResetGuard(state);

    final rows = <Widget>[
      for (final row in CheckRow.values)
        _CheckRowView(
          key: Key('card-check-row-${row.name}'),
          row: row,
          result: state.rows[row]!,
          trailing: row == CheckRow.signature && showPin
              ? KeyedSubtree(
                  key: const Key('card-check-pin'),
                  child: PrimaryButton(
                    label: 'PIN eingeben',
                    height: 56,
                    labelSize: 18,
                    onPressed: busy ? null : _enterPin,
                  ),
                )
              : null,
          below: row == CheckRow.signature && showReset
              ? (_confirmReset
                    ? _ResetQuestion(
                        onConfirm: busy ? null : _resetGuard,
                        onCancel: () => setState(() => _confirmReset = false),
                      )
                    : UnconstrainedBox(
                        alignment: Alignment.centerLeft,
                        child: KeyedSubtree(
                          key: const Key('card-check-reset-guard'),
                          child: PrimaryButton(
                            label: 'Zähler ist wieder voll',
                            filled: false,
                            height: 56,
                            onPressed: busy
                                ? null
                                : () => setState(() => _confirmReset = true),
                          ),
                        ),
                      ))
              : null,
        ),
    ];

    final checks = Container(
      padding: const EdgeInsets.symmetric(horizontal: KassaTokens.spaceHuge),
      decoration: _cardDecoration(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(
                        top: BorderSide(
                          color: c.line,
                          width: KassaTokens.borderThin,
                        ),
                      ),
              ),
              child: rows[i],
            ),
        ],
      ),
    );

    final about = Container(
      padding: const EdgeInsets.all(KassaTokens.spaceHuge),
      decoration: _cardDecoration(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Was hier geprüft wird',
                    style: text.titleMedium!.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: KassaTokens.spaceXl),
                  Text(
                    'Hier siehst du, ob Tablet, Verteiler, Kartenleser und '
                    'Signaturkarte zusammenarbeiten. Auf der Karte wird nichts '
                    'verändert.',
                    style: text.bodyMedium!.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: KassaTokens.spaceXl),
                  Text(
                    'Steckt die Karte sonst in der alten Kassa, kann dort in '
                    'dieser Zeit kein Bon erstellt werden.',
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
          if (_shareFailed) ...[
            const SizedBox(height: KassaTokens.spaceXl),
            const WarnBox(
              'Teilen geht auf diesem Tablet nicht.',
              key: Key('card-check-share-failed'),
            ),
          ],
          if (finished) ...[
            const SizedBox(height: KassaTokens.spaceXl),
            KeyedSubtree(
              key: const Key('card-check-share'),
              child: PrimaryButton(
                label: 'Bericht teilen',
                filled: false,
                icon: LucideIcons.share,
                height: 64,
                labelSize: 18,
                onPressed: busy || _sharing ? null : _share,
              ),
            ),
          ],
          const SizedBox(height: KassaTokens.spaceXl),
          KeyedSubtree(
            key: const Key('card-check-run'),
            child: PrimaryButton(
              label: started ? 'Nochmal prüfen' : 'Jetzt prüfen',
              height: 76,
              labelSize: 22,
              onPressed: busy ? null : _run,
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: KassaTokens.receiptHeaderHeight,
          padding: const EdgeInsets.only(left: 6, right: 16),
          child: Row(
            children: [
              Pressable(
                key: const Key('card-check-back'),
                onTap: widget.onBack,
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
                  'Karte prüfen',
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
                    key: const Key('card-check-rows'),
                    child: checks,
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

  static BoxDecoration _cardDecoration(KassaColors c) => BoxDecoration(
    color: c.card,
    borderRadius: BorderRadius.circular(KassaTokens.radiusCard),
    border: Border.all(color: c.line, width: KassaTokens.borderThin),
    boxShadow: c.cardShadow,
  );
}

/// Eine Zeile: Zeichen für den Zustand, Titel, `message` und `hint` wie sie
/// kommen. Bei einem Fehler stehen beide in der Warnfläche. [trailing] steht
/// rechts (PIN eingeben), [below] unter dem Text (Zähler ist wieder voll).
class _CheckRowView extends StatelessWidget {
  const _CheckRowView({
    super.key,
    required this.row,
    required this.result,
    this.trailing,
    this.below,
  });

  final CheckRow row;
  final RowResult result;
  final Widget? trailing;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final instant = MediaQuery.disableAnimationsOf(context);
    final state = result.state;
    final quiet = state == RowState.waiting || state == RowState.locked;
    final hint = result.hint;

    final Widget details;
    if (state == RowState.problem) {
      final style = text.bodyMedium!.copyWith(
        fontSize: 15,
        height: 1.35,
        color: c.warnInk,
      );
      details = Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: KassaTokens.spaceMd),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: c.warnBg,
          borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.message,
              style: style.copyWith(fontWeight: FontWeight.w700),
            ),
            if (hint != null) ...[
              const SizedBox(height: KassaTokens.spaceXxs),
              Text(hint, style: style.copyWith(fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      );
    } else {
      details = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: KassaTokens.spaceXxs),
          Text(
            result.message,
            style: text.bodyMedium!.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: quiet ? c.ink2 : c.ink,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: KassaTokens.spaceXxs),
            Text(
              hint,
              style: text.bodyMedium!.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.35,
                color: c.ink2,
              ),
            ),
          ],
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KassaTokens.spaceXxl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RowSign(
            key: Key('card-check-sign-${row.name}'),
            number: row.index + 1,
            state: state,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _titles[row]!,
                            style: text.titleMedium!.copyWith(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: quiet ? c.ink2 : c.ink,
                            ),
                          ),
                          // Ein neuer Stand blendet ruhig über den alten; ein
                          // weiterer Wechsel unterbricht das sofort.
                          AnimatedSwitcher(
                            duration: instant
                                ? Duration.zero
                                : KassaTokens.motionFade,
                            switchInCurve: KassaTokens.motionCurve,
                            switchOutCurve: KassaTokens.motionCurve,
                            layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.topLeft,
                              children: [...previous, ?current],
                            ),
                            child: KeyedSubtree(
                              key: ValueKey((state, result.message, hint)),
                              child: details,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: KassaTokens.spaceXxl),
                      trailing!,
                    ],
                  ],
                ),
                if (below != null) ...[
                  const SizedBox(height: KassaTokens.spaceXl),
                  below!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Das Zeichen einer Zeile, nie nur Farbe: Nummer im Kreis (wartet), ruhiger
/// Fortschritt (läuft), Haken (in Ordnung), Kreuz (Fehler), Schloss
/// (gesperrt). Die Semantik sagt den Zustand als Wort.
class _RowSign extends StatelessWidget {
  const _RowSign({super.key, required this.number, required this.state});

  final int number;
  final RowState state;

  static const double size = 40;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final instant = MediaQuery.disableAnimationsOf(context);
    final (label, Widget sign) = switch (state) {
      RowState.waiting => (
        'wartet',
        _circle(
          border: c.line,
          child: Text(
            '$number',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: c.ink2,
            ),
          ),
        ),
      ),
      RowState.running => (
        'läuft',
        _circle(
          color: c.accentSoft,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              value: instant ? 0.3 : null,
              color: c.accent,
              backgroundColor: c.accentSoft,
            ),
          ),
        ),
      ),
      RowState.ok => (
        'in Ordnung',
        _circle(
          color: c.veganBg,
          child: Icon(LucideIcons.check, size: 22, color: c.veganFg),
        ),
      ),
      RowState.problem => (
        'Fehler',
        _circle(
          color: c.spicyBg,
          child: Icon(LucideIcons.x, size: 22, color: c.spicyFg),
        ),
      ),
      RowState.locked => (
        'gesperrt',
        _circle(
          color: c.fill,
          child: Icon(LucideIcons.lock, size: 18, color: c.ink2),
        ),
      ),
    };
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: AnimatedSwitcher(
          duration: instant ? Duration.zero : KassaTokens.motionFade,
          switchInCurve: KassaTokens.motionCurve,
          switchOutCurve: KassaTokens.motionCurve,
          child: KeyedSubtree(key: ValueKey(state), child: sign),
        ),
      ),
    );
  }

  static Widget _circle({Color? color, Color? border, required Widget child}) =>
      Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: border == null
              ? null
              : Border.all(color: border, width: KassaTokens.borderButton),
        ),
        child: child,
      );
}

/// Rückfrage vor "Zähler ist wieder voll", in der Zeile, ohne Dialog.
class _ResetQuestion extends StatelessWidget {
  const _ResetQuestion({required this.onConfirm, required this.onCancel});

  final VoidCallback? onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Container(
      key: const Key('card-check-reset-question'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
        border: Border.all(color: c.line, width: KassaTokens.borderButton),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Wurde die Karte seit dem Fehlversuch in der alten Kassa mit der '
            'richtigen PIN verwendet? Ist die nächste PIN falsch, sperrt sich '
            'die Karte.',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: KassaTokens.spaceXl),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  key: const Key('card-check-reset-cancel'),
                  label: 'Abbrechen',
                  filled: false,
                  height: 60,
                  onPressed: onCancel,
                ),
              ),
              const SizedBox(width: KassaTokens.spaceLg),
              Expanded(
                flex: 3,
                child: PrimaryButton(
                  key: const Key('card-check-reset-confirm'),
                  label: 'Ja, Zähler ist wieder voll',
                  height: 60,
                  labelSize: 17,
                  onPressed: onConfirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
