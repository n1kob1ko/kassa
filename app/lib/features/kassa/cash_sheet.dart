import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../core/money.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../domain/cart.dart';
import '../../domain/cash.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../login/session.dart';
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
        border: Border(
          left: BorderSide(color: c.line, width: KassaTokens.borderThin),
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
class CashSheet extends ConsumerStatefulWidget {
  const CashSheet({
    super.key,
    required this.cart,
    required this.onBack,
    required this.onPaid,
  });

  final Cart cart;
  final VoidCallback onBack;
  final ValueChanged<SaleResult> onPaid;

  @override
  ConsumerState<CashSheet> createState() => _CashSheetState();
}

class _CashSheetState extends ConsumerState<CashSheet> {
  final String _saleId = const Uuid().v4();

  late int _given = widget.cart.totalCents;
  KeypadInput? _typing;
  bool _saving = false;
  bool _failed = false;

  int get _total => widget.cart.totalCents;

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
    // Auf kleinen Bildschirmen scrollt die Spalte: das Zahlenfeld soll
    // gleich ganz zu sehen sein.
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
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final typing = _typing;
    final short = _given < _total;
    final suggestions = cashSuggestions(_total);
    final hasPrinter =
        (ref.watch(settingsStreamProvider).value ?? const RegisterSettings())
            .printerKind !=
        PrinterKind.none;
    return PayColumnFrame(
      child: Column(
        children: [
          Container(
            height: KassaTokens.receiptHeaderHeight,
            padding: const EdgeInsets.only(left: 6, right: 16),
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
                  child: Icon(LucideIcons.chevronLeft, size: 28, color: c.ink),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l.kassaAmountDue, style: text.bodyLarge),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatEuro(_total),
                            key: const Key('cash-total'),
                            maxLines: 1,
                            style: KassaText.amount(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KassaTokens.spaceXxl),
                  if (typing == null)
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
                  const SizedBox(height: KassaTokens.spaceXxl),
                  ChangeField(missing: short, cents: (_given - _total).abs()),
                ],
              ),
            ),
          ),
          if (_failed)
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
