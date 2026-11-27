import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/cart.dart';
import '../../domain/voucher.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/ltr.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/segmented.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../close/amount_entry.dart' show AmountEntry, FieldLabel;
import 'cart_controller.dart';
import 'cash_inputs.dart' show GivenKey;
import 'cash_sheet.dart' show PayColumnFrame;
import 'more_sheet.dart' show SheetHeader;
import 'voucher_code_entry.dart';

enum _Tab { sell, check }

/// "Gutschein": die rechte Spalte mit den Reitern "Verkaufen" und "Prüfen"
/// (Spec 5.5).
///
/// Verkaufen: je Vorschlag aus [voucherPresetCents] eine Taste, darunter
/// "Anderer Betrag" mit dem Zahlenfeld. "Auf den Bon" legt eine Zeile
/// "Gutschein" mit dem Wert an und schließt das Blatt; außerhalb 1,00 bis
/// 500,00 € ist die Taste grau und sagt darunter, warum, ebenso, wenn am Bon
/// Gutscheine zum Bezahlen gewählt sind.
///
/// Prüfen: den Code tippen ([VoucherCodeEntry]); die Kassa zeigt Wert,
/// Guthaben, Zustand und die Bewegungen, neueste oben.
class VoucherSheet extends ConsumerStatefulWidget {
  const VoucherSheet({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<VoucherSheet> createState() => _VoucherSheetState();
}

class _VoucherSheetState extends ConsumerState<VoucherSheet> {
  _Tab _tab = _Tab.sell;

  /// Der gewählte Vorschlag in Cent; `null` ohne Wahl.
  int? _preset;

  /// Gesetzt, solange "Anderer Betrag" gewählt ist: das Zahlenfeld steht da.
  KeypadInput? _other;

  /// Der Gutschein, den "Prüfen" gefunden hat.
  Voucher? _checked;

  /// Nach dem ersten Tipp auf "Auf den Bon": ein zweiter tut nichts.
  bool _done = false;

  final _otherKey = GlobalKey();
  final _resultKey = GlobalKey();
  final _entryKey = GlobalKey();
  final _displayKey = GlobalKey();
  final _keypadKey = GlobalKey();

  /// Platz am Ende der Spalte, damit das Rollen zum Ergebnis an einem Anfang
  /// eines Teils enden kann ([revealWholeBlocks]); 0 ohne Ergebnis.
  double _endSpace = 0;

  int get _valueCents => _other?.cents ?? _preset ?? 0;

  void _choosePreset(int cents) => setState(() {
    _preset = cents;
    _other = null;
  });

  void _chooseOther() {
    setState(() {
      _preset = null;
      _other ??= const KeypadInput(maxIntDigits: 3);
    });
    // Auf kleinen Bildschirmen scrollt die Spalte: das Zahlenfeld soll gleich
    // ganz zu sehen sein.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _otherKey.currentContext;
      if (context != null) Scrollable.ensureVisible(context);
    });
  }

  void _add(int cents) {
    if (_done) return;
    _done = true;
    ref.read(cartProvider.notifier).addVoucherSale(valueCents: cents);
    widget.onClose();
  }

  void _found(Voucher voucher) {
    setState(() => _checked = voucher);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Das Ergebnis ganz zeigen, ohne Beschriftung oder Feld halb unter
      // dem oberen Rand.
      revealWholeBlocks(
        _resultKey,
        [_entryKey, _displayKey, _keypadKey],
        addSpace: (extra) {
          if (mounted) setState(() => _endSpace += extra);
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return PayColumnFrame(
      child: Column(
        key: const Key('voucher-sheet'),
        children: [
          SheetHeader(
            title: l.kassaVoucher,
            backKey: const Key('voucher-back'),
            onBack: widget.onClose,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Segmented<_Tab>(
              expand: true,
              segments: [
                (_Tab.sell, l.voucherSell),
                (_Tab.check, l.voucherCheck),
              ],
              selected: _tab,
              keyFor: (tab) => Key(switch (tab) {
                _Tab.sell => 'voucher-tab-sell',
                _Tab.check => 'voucher-tab-check',
              }),
              // Der Code beginnt im anderen Reiter leer: ein altes Ergebnis
              // gehört nicht mehr darunter.
              onSelected: (tab) => setState(() {
                _tab = tab;
                _checked = null;
                _endSpace = 0;
              }),
            ),
          ),
          Expanded(
            child: switch (_tab) {
              _Tab.sell => _sell(context),
              _Tab.check => _check(context),
            },
          ),
        ],
      ),
    );
  }

  Widget _sell(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final cart = ref.watch(cartProvider);
    final cents = _valueCents;
    final inRange = cents >= voucherMinCents && cents <= voucherMaxCents;
    final paidByVoucher = cart.vouchers.isNotEmpty;
    final reason = paidByVoucher
        ? l.voucherNotWithRedeem
        : inRange
        ? null
        : l.voucherRange(
            ltrIsolate(context, formatEuro(voucherMinCents)),
            ltrIsolate(context, formatEuro(voucherMaxCents)),
          );
    final other = _other;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FieldLabel(l.voucherValue),
                const SizedBox(height: KassaTokens.spaceMd),
                Row(
                  children: [
                    for (final (i, preset) in voucherPresetCents.indexed) ...[
                      if (i > 0) const SizedBox(width: KassaTokens.spaceMd),
                      Expanded(
                        child: GivenKey(
                          key: Key('voucher-preset-$preset'),
                          label: formatEuro(preset).replaceFirst(',00', ''),
                          selected: other == null && _preset == preset,
                          onTap: () => _choosePreset(preset),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: KassaTokens.spaceMd),
                _OtherKey(selected: other != null, onTap: _chooseOther),
                if (other != null) ...[
                  const SizedBox(height: KassaTokens.spaceMd),
                  KeyedSubtree(
                    key: _otherKey,
                    child: AmountEntry(
                      input: other,
                      over: !other.isEmpty && !inRange,
                      onKey: (key) => setState(() => _other = other.tap(key)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrimaryButton(
                key: const Key('voucher-add'),
                label: l.voucherAdd,
                icon: LucideIcons.plus,
                height: KassaTokens.mainActionHeight,
                onPressed: reason == null ? () => _add(cents) : null,
              ),
              // Außerhalb der scrollenden Fläche: der Grund steht immer da.
              if (reason != null) ...[
                const SizedBox(height: KassaTokens.spaceSm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    reason,
                    key: const Key('voucher-add-reason'),
                    textAlign: TextAlign.center,
                    style: text.bodyMedium!.copyWith(color: c.ink2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _check(BuildContext context) {
    final checked = _checked;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VoucherCodeEntry(
            key: _entryKey,
            displayKey: _displayKey,
            keypadKey: _keypadKey,
            onFound: _found,
            onCleared: () => setState(() {
              _checked = null;
              _endSpace = 0;
            }),
          ),
          if (checked != null) ...[
            const SizedBox(height: KassaTokens.spaceXxl),
            _CheckResult(key: _resultKey, voucher: checked),
          ],
          if (_endSpace > 0) SizedBox(height: _endSpace),
        ],
      ),
    );
  }
}

/// "Anderer Betrag": öffnet das Zahlenfeld; gewählt mit Rand in der
/// Akzentfarbe.
class _OtherKey extends StatelessWidget {
  const _OtherKey({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Pressable(
      key: const Key('voucher-other'),
      onTap: onTap,
      selected: selected,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(
          horizontal: KassaTokens.spaceXl,
          vertical: KassaTokens.spaceSm,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.fill,
          borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
          border: Border.all(
            color: selected ? c.accent : c.fill,
            width: KassaTokens.borderStrong,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.calculator, size: 22, color: c.ink),
            const SizedBox(width: KassaTokens.spaceLg),
            Flexible(
              child: Text(
                L10n.of(context).voucherOther,
                textAlign: TextAlign.center,
                style: text.titleLarge!.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Der Zustand eines Gutscheins in der Bediensprache.
String voucherStateText(L10n l, VoucherState state) => switch (state) {
  VoucherState.active => l.voucherStateActive,
  VoucherState.empty => l.voucherStateEmpty,
  VoucherState.voided => l.voucherStateVoided,
  VoucherState.overdrawn => l.voucherStateOverdrawn,
};

/// Die Art einer Bewegung in der Bediensprache.
String voucherMovementText(L10n l, VoucherMovementKind kind) => switch (kind) {
  VoucherMovementKind.sale => l.voucherMoveSale,
  VoucherMovementKind.redeem => l.voucherMoveRedeem,
  VoucherMovementKind.voidSale => l.voucherMoveVoidSale,
  VoucherMovementKind.voidRedeem => l.voucherMoveVoidRedeem,
  VoucherMovementKind.unknown => l.voucherMoveOther,
};

/// Was "Prüfen" zeigt: Wert, Guthaben, Zustand (dazu "Übungs-Gutschein")
/// und die Bewegungen mit Datum, Art und Betrag, neueste oben.
class _CheckResult extends StatelessWidget {
  const _CheckResult({super.key, required this.voucher});

  final Voucher voucher;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final state = voucher.state;
    final warn =
        state == VoucherState.overdrawn || state == VoucherState.voided;
    final tabular = const [FontFeature.tabularFigures()];
    final movements = voucher.movements.reversed.toList();
    Widget amountRow(String label, int cents, Key key, {bool big = false}) =>
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: text.bodyLarge!.copyWith(color: c.accentInk),
              ),
            ),
            const SizedBox(width: KassaTokens.spaceMd),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: Ltr(
                  child: Text(
                    formatEuro(cents),
                    key: key,
                    maxLines: 1,
                    style: big
                        ? KassaText.amount(context).copyWith(color: c.ink)
                        : text.titleLarge!.copyWith(fontFeatures: tabular),
                  ),
                ),
              ),
            ),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(KassaTokens.spaceXxl),
          decoration: BoxDecoration(
            color: c.accentSoft,
            borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              amountRow(
                l.voucherValue,
                voucher.valueCents,
                const Key('voucher-check-value'),
              ),
              const SizedBox(height: KassaTokens.spaceMd),
              amountRow(
                l.voucherBalance,
                voucher.balanceCents,
                const Key('voucher-check-balance'),
                big: true,
              ),
              const SizedBox(height: KassaTokens.spaceXl),
              Wrap(
                spacing: KassaTokens.spaceMd,
                runSpacing: KassaTokens.spaceSm,
                children: [
                  _Pill(
                    label: voucherStateText(l, state),
                    textKey: const Key('voucher-check-state'),
                    bg: warn ? c.warnBg : c.card,
                    fg: warn ? c.warnInk : c.ink,
                  ),
                  if (voucher.isTest)
                    _Pill(
                      label: l.voucherIsTest,
                      textKey: const Key('voucher-check-test'),
                      bg: c.warnBg,
                      fg: c.warnInk,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: KassaTokens.spaceMd),
        for (final (i, m) in movements.indexed)
          Container(
            key: Key('voucher-check-movement-$i'),
            constraints: const BoxConstraints(minHeight: KassaTokens.minTap),
            padding: const EdgeInsets.symmetric(vertical: KassaTokens.spaceSm),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: c.line,
                  width: KassaTokens.borderThin,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voucherMovementText(l, m.kind),
                        style: text.bodyLarge!.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Ltr(
                        child: Text(
                          '${voucherDateText(m.createdAt)} '
                          '${m.createdAt.hour.toString().padLeft(2, '0')}:'
                          '${m.createdAt.minute.toString().padLeft(2, '0')}',
                          textAlign: ltrAlign(context, TextAlign.start),
                          style: text.bodySmall!.copyWith(
                            fontWeight: FontWeight.w400,
                            color: c.ink2,
                            fontFeatures: tabular,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: KassaTokens.spaceMd),
                Ltr(
                  child: Text(
                    formatEuro(m.amountCents),
                    maxLines: 1,
                    style: text.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: tabular,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Ein kleines Schild ("Gültig", "Übungs-Gutschein").
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.textKey,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Key textKey;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KassaTokens.spaceLg,
        vertical: KassaTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(KassaTokens.radiusPill),
      ),
      child: Text(
        label,
        key: textKey,
        style: Theme.of(context).textTheme.labelLarge!
            .copyWith(fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
