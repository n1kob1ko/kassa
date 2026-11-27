import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../core/money.dart';
import '../../data/providers.dart';
import '../../data/receipt_repository.dart' show VoucherBalanceException;
import '../../data/settings_repository.dart';
import '../../devices/device_providers.dart';
import '../../domain/cart.dart';
import '../../domain/cash.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/ltr.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/segmented.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../login/session.dart';
import 'card_availability.dart';
import 'cart_controller.dart';
import 'cash_inputs.dart';
import 'sale_service.dart';

/// Die Spalte rechts, in der die Bon-Spalte, das Bezahlen und die
/// Fertig-Ansicht wechseln: gleiche Breite, gleicher Rand.
class PayColumnFrame extends StatelessWidget {
  const PayColumnFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Container(
      width: KassaTokens.receiptColumnWidth,
      decoration: BoxDecoration(
        color: c.card,
        border: BorderDirectional(
          start: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: child,
    );
  }
}

/// "Bar bezahlen": Summe, gegebener Betrag (Vorschläge oder Zahlenfeld),
/// Rückgeld und Abschließen. Die `saleId` entsteht einmal beim Öffnen: ein
/// zweiter Tipp oder ein neuer Versuch nach einem Fehler schreibt denselben
/// Bon, nie einen zweiten.
///
/// Ist "Teil bar, Rest Karte" eingeschaltet und [onSplit] gesetzt, stehen oben
/// "Ganzer Betrag" (gewählt; das Blatt wie ohne Schalter) und "Teil bar": dort
/// wird der Bar-Teil getippt, der Rest geht an die Karte. "Weiter zur Karte"
/// speichert nichts, es ruft nur [onSplit].
///
/// Sind Gutscheine gewählt, rechnet das Blatt mit dem, was danach offen ist
/// (`cart.pricing.dueCents`): Vorschläge, Rückgeld und der Rest für die
/// Karte. Reicht ein Guthaben beim Abschließen nicht mehr, ist nichts
/// gespeichert, und das Blatt ruft [onVoucherChanged].
class CashSheet extends ConsumerStatefulWidget {
  const CashSheet({
    super.key,
    required this.cart,
    required this.onBack,
    required this.onPaid,
    this.onSplit,
    this.onVoucherChanged,
  });

  final Cart cart;
  final VoidCallback onBack;
  final ValueChanged<SaleResult> onPaid;

  /// Ein Guthaben hat sich geändert; nichts ist gespeichert.
  final VoidCallback? onVoucherChanged;

  /// Bar-Teil in Cent: "Weiter zur Karte".
  final ValueChanged<int>? onSplit;

  @override
  ConsumerState<CashSheet> createState() => _CashSheetState();
}

class _CashSheetState extends ConsumerState<CashSheet> {
  final String _saleId = const Uuid().v4();

  late int _given = widget.cart.pricing.dueCents;
  KeypadInput? _typing;
  bool _saving = false;
  bool _failed = false;

  /// "Teil bar" ist gewählt.
  bool _split = false;

  /// Der getippte Bar-Teil bei "Teil bar".
  KeypadInput _cashPart = const KeypadInput(maxIntDigits: 6);

  /// Was bar (oder mit "Teil bar" zusammen mit der Karte) zu zahlen ist:
  /// ohne Gutschein die Summe des Bons.
  int get _total => widget.cart.pricing.dueCents;

  /// Was nach dem Bar-Teil mit Karte bleibt, nie unter 0.
  int get _rest => _total - _cashPart.cents < 0 ? 0 : _total - _cashPart.cents;

  void _selectSplit(bool split) {
    setState(() => _split = split);
    if (split) _revealKeypad();
  }

  void _setCashPartKey(String key) =>
      setState(() => _cashPart = _cashPart.tap(key));

  void _setKey(String key) {
    final typing = _typing;
    if (typing == null) return;
    final next = typing.tap(key);
    setState(() {
      _typing = next;
      _given = next.cents;
    });
  }

  final _keypadKey = GlobalKey();

  void _showKeypad() {
    setState(() {
      _typing = const KeypadInput(maxIntDigits: 6);
      _given = 0;
    });
    _revealKeypad();
  }

  /// Auf kleinen Bildschirmen scrollt die Spalte: das Zahlenfeld soll gleich
  /// ganz zu sehen sein.
  void _revealKeypad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _keypadKey.currentContext;
      if (context != null) Scrollable.ensureVisible(context);
    });
  }

  void _showSuggestions() => setState(() {
    _typing = null;
    _given = _total;
  });

  Future<void> _finish() async {
    // Der erste Tipp sperrt sofort, noch vor dem nächsten Bild.
    if (_saving || _given < _total) return;
    final staff = ref.read(sessionProvider);
    final service = ref.read(saleServiceProvider);
    final cartCtl = ref.read(cartProvider.notifier);
    if (staff == null) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      final result = await service.completeCash(
        saleId: _saleId,
        cart: widget.cart,
        givenCents: _given,
        staff: staff,
      );
      // Der Bon ist gespeichert: der offene Bon und sein Entwurf gehen weg,
      // auch wenn die Ansicht inzwischen weg ist.
      cartCtl.clear();
      if (mounted) widget.onPaid(result);
    } on VoucherBalanceException {
      if (!mounted) return;
      final changed = widget.onVoucherChanged;
      if (changed != null) {
        changed();
      } else {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  /// Ob "Weiter zur Karte" geht, sonst der erste Grund.
  ({bool enabled, String? reason}) _splitAvailability(L10n l) {
    if (_cashPart.cents <= 0) return (enabled: false, reason: l.splitNeedCash);
    final minimum = ref.read(cardTerminalProvider).minimumCents;
    if (_total - _cashPart.cents < minimum) {
      return (
        enabled: false,
        reason: l.splitRestTooSmall(ltrIsolate(context, formatEuro(minimum))),
      );
    }
    return cardAvailability(ref, context, _rest);
  }

  void _goToCard() {
    final onSplit = widget.onSplit;
    if (onSplit == null || _saving) return;
    _saving = true;
    onSplit(_cashPart.cents);
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final typing = _typing;
    final short = _given < _total;
    final suggestions = cashSuggestions(_total);
    final settings =
        ref.watch(settingsStreamProvider).value ?? const RegisterSettings();
    final hasPrinter = settings.printerKind != PrinterKind.none;
    final canSplit = settings.splitPaymentEnabled && widget.onSplit != null;
    final split = canSplit && _split;
    final go = split ? _splitAvailability(l) : null;
    return PayColumnFrame(
      child: Column(
        children: [
          Container(
            height: KassaTokens.receiptHeaderHeight,
            padding: const EdgeInsetsDirectional.only(start: 6, end: 16),
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
                Pressable(
                  key: const Key('cash-back'),
                  onTap: _saving ? null : widget.onBack,
                  semanticLabel: l.kassaBackToReceipt,
                  minTapSize: const Size(
                    KassaTokens.minTap,
                    KassaTokens.minTap,
                  ),
                  child: Icon(
                    directionalIcon(
                      context,
                      ltr: LucideIcons.chevronLeft,
                      rtl: LucideIcons.chevronRight,
                    ),
                    size: 28,
                    color: c.ink,
                  ),
                ),
                const SizedBox(width: KassaTokens.spaceXs),
                Expanded(
                  child: Text(
                    l.kassaPayCashTitle,
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
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (canSplit) ...[
                    Segmented<bool>(
                      segments: [(false, l.splitWhole), (true, l.splitPart)],
                      selected: split,
                      expand: true,
                      keyFor: (v) =>
                          Key(v ? 'cash-mode-split' : 'cash-mode-full'),
                      onSelected: _selectSplit,
                    ),
                    const SizedBox(height: KassaTokens.spaceXl),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l.kassaAmountDue, style: text.bodyLarge),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Ltr(
                            child: Text(
                              formatEuro(_total),
                              key: const Key('cash-total'),
                              maxLines: 1,
                              style: KassaText.amount(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KassaTokens.spaceXxl),
                  if (split) ...[
                    TypedAmount(
                      input: _cashPart,
                      keypadKey: _keypadKey,
                      onKey: _setCashPartKey,
                      label: l.splitCashPart,
                    ),
                    const SizedBox(height: KassaTokens.spaceXxl),
                    _SplitRest(cents: _rest),
                  ] else if (typing == null)
                    Suggestions(
                      amounts: suggestions,
                      given: _given,
                      onGiven: (v) => setState(() => _given = v),
                      onOther: _showKeypad,
                    )
                  else
                    TypedAmount(
                      input: typing,
                      keypadKey: _keypadKey,
                      onKey: _setKey,
                      onSuggestions: _showSuggestions,
                    ),
                  if (!split) ...[
                    const SizedBox(height: KassaTokens.spaceXxl),
                    ChangeField(missing: short, cents: (_given - _total).abs()),
                  ],
                ],
              ),
            ),
          ),
          if (_failed && !split)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l.kassaSaveFailed,
                  style: text.bodyMedium!.copyWith(color: c.red),
                ),
              ),
            ),
          if (go != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrimaryButton(
                    key: const Key('split-go'),
                    label: l.splitGo(ltrIsolate(context, formatEuro(_rest))),
                    solid: true,
                    muted: !go.enabled,
                    height: KassaTokens.mainActionHeight,
                    onPressed: go.enabled && !_saving ? _goToCard : null,
                  ),
                  if (go.reason case final reason?) ...[
                    const SizedBox(height: KassaTokens.spaceSm),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        reason,
                        key: const Key('split-reason'),
                        textAlign: TextAlign.center,
                        style: text.bodyMedium!.copyWith(color: c.ink2),
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: PrimaryButton(
                key: const Key('finish-sale'),
                label: hasPrinter ? l.kassaFinishAndPrint : l.kassaFinish,
                height: KassaTokens.mainActionHeight,
                onPressed: short || _saving ? null : _finish,
              ),
            ),
        ],
      ),
    );
  }
}

/// "Rest mit Karte" bei "Teil bar", im Feld des Rückgelds.
class _SplitRest extends StatelessWidget {
  const _SplitRest({required this.cents});

  final int cents;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              L10n.of(context).splitRest,
              style: text.bodyLarge!.copyWith(color: c.accentInk),
            ),
          ),
          const SizedBox(width: KassaTokens.spaceMd),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Ltr(
                child: Text(
                  formatEuro(cents),
                  key: const Key('split-rest'),
                  maxLines: 1,
                  style: KassaText.amount(context).copyWith(color: c.ink),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
