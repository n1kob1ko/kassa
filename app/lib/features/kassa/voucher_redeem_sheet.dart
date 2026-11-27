import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../core/money.dart';
import '../../data/providers.dart';
import '../../data/receipt_repository.dart' show VoucherBalanceException;
import '../../domain/cart.dart';
import '../../domain/receipt.dart' show isTestChainMode;
import '../../domain/voucher.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/ltr.dart';
import '../../ui/pressable.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../login/session.dart';
import 'cart_controller.dart';
import 'cash_sheet.dart' show PayColumnFrame;
import 'more_sheet.dart' show SheetHeader;
import 'sale_service.dart';
import 'voucher_code_entry.dart';

/// Warum sich ein Gutschein nicht einlösen lässt, in der Bediensprache.
String voucherRedeemProblemText(L10n l, VoucherRedeemProblem p) => switch (p) {
  VoucherRedeemProblem.alreadyOnReceipt => l.voucherAlreadyOnReceipt,
  VoucherRedeemProblem.voided => l.voucherVoided,
  VoucherRedeemProblem.testOnly => l.voucherTestOnly,
  VoucherRedeemProblem.liveOnly => l.voucherLiveOnly,
  VoucherRedeemProblem.empty => l.voucherEmpty,
};

/// "Gutschein einlösen" (Spec 5.5): oben, was zu zahlen ist
/// (`cart.pricing.dueCents`), darunter der Code ([VoucherCodeEntry]). Nach
/// dem Treffer stehen Guthaben, was eingelöst wird (höchstens, was zu zahlen
/// ist) und was am Gutschein bleibt, dazu "Einlösen". Lässt sich der
/// Gutschein nicht einlösen (aufgebraucht, storniert, Übung und echt
/// gemischt, schon am Bon), steht statt der Zahlen der Grund.
///
/// Reicht das Guthaben für alles, schließt "Einlösen" den Bon ab
/// ([SaleService.completeVoucher], die Lade bleibt zu) und ruft [onPaid].
/// Sonst kommt der Gutschein auf den Bon und das Blatt schließt ([onClose]).
/// Hat sich das Guthaben beim Abschließen geändert, ruft es
/// [onVoucherChanged]; gespeichert ist dann nichts. Ein zweiter Tipp auf
/// "Einlösen" tut nichts.
class VoucherRedeemSheet extends ConsumerStatefulWidget {
  const VoucherRedeemSheet({
    super.key,
    required this.onClose,
    required this.onPaid,
    required this.onVoucherChanged,
  });

  final VoidCallback onClose;
  final ValueChanged<SaleResult> onPaid;
  final VoidCallback onVoucherChanged;

  @override
  ConsumerState<VoucherRedeemSheet> createState() => _VoucherRedeemSheetState();
}

class _VoucherRedeemSheetState extends ConsumerState<VoucherRedeemSheet> {
  /// Die Kennung des Bons, wenn "Einlösen" ihn abschließt: ein neuer Versuch
  /// nach einem Fehler schreibt denselben Bon.
  final String _saleId = const Uuid().v4();

  /// Der gefundene Gutschein; `null` ohne Treffer.
  Voucher? _found;

  /// Warum er nicht geht; nur gültig, wenn [_checked].
  VoucherRedeemProblem? _problem;

  /// Die Prüfung des Treffers ist fertig.
  bool _checked = false;

  /// Zählt die Treffer: eine ältere Prüfung meldet nicht mehr.
  int _generation = 0;

  /// Ab dem ersten Tipp auf "Einlösen": ein zweiter tut nichts.
  bool _busy = false;
  bool _failed = false;

  final _resultKey = GlobalKey();

  Future<void> _onFound(Voucher voucher) async {
    final generation = ++_generation;
    setState(() {
      _found = voucher;
      _problem = null;
      _checked = false;
      _failed = false;
    });
    bool onTest;
    try {
      onTest = await ref.read(receiptRepositoryProvider).isTestReceiptNow();
    } catch (_) {
      // Lieber als Übung: das Abschließen prüft ohnehin noch einmal.
      onTest = isTestChainMode(null);
    }
    if (!mounted || generation != _generation) return;
    final cart = ref.read(cartProvider);
    setState(() {
      _problem = voucherRedeemProblem(
        voucher,
        onTestReceipt: onTest,
        chosenIds: [for (final v in cart.vouchers) v.voucherId],
      );
      _checked = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _resultKey.currentContext;
      if (context != null) Scrollable.ensureVisible(context);
    });
  }

  void _onCleared() {
    _generation++;
    setState(() {
      _found = null;
      _problem = null;
      _checked = false;
      _failed = false;
    });
  }

  Future<void> _redeem(Voucher voucher, int dueCents) async {
    // Der erste Tipp sperrt sofort, noch vor dem nächsten Bild.
    if (_busy) return;
    final staff = ref.read(sessionProvider);
    if (staff == null) return;
    final before = ref.read(cartProvider);
    if (before.isEmpty || before.hasVoucherSale) {
      widget.onClose();
      return;
    }
    _busy = true;
    final cartCtl = ref.read(cartProvider.notifier);
    cartCtl.applyVoucher(
      AppliedVoucher(
        voucherId: voucher.id,
        code: voucher.code,
        balanceCents: voucher.balanceCents,
      ),
    );
    if (voucher.balanceCents < dueCents) {
      widget.onClose();
      return;
    }
    setState(() => _failed = false);
    final service = ref.read(saleServiceProvider);
    try {
      final result = await service.completeVoucher(
        saleId: _saleId,
        cart: ref.read(cartProvider),
        staff: staff,
      );
      // Der Bon ist gespeichert: der offene Bon und sein Entwurf gehen weg,
      // auch wenn die Ansicht inzwischen weg ist.
      cartCtl.clear();
      if (mounted) widget.onPaid(result);
    } on VoucherBalanceException {
      if (mounted) widget.onVoucherChanged();
    } catch (_) {
      // Der Gutschein liegt am Bon; ein neuer Tipp schreibt denselben Bon.
      if (mounted) {
        setState(() {
          _busy = false;
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
    final cart = ref.watch(cartProvider);
    final due = cart.pricing.dueCents;
    final found = _found;
    final problem = _checked ? _problem : null;
    final ready = found != null && _checked && problem == null;
    final balance = found?.balanceCents ?? 0;
    final use = balance < due ? balance : due;
    return PayColumnFrame(
      child: Column(
        key: const Key('voucher-redeem-sheet'),
        children: [
          SheetHeader(
            title: l.voucherRedeemTitle,
            backKey: const Key('voucher-redeem-back'),
            onBack: _busy ? () {} : widget.onClose,
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
                    children: [
                      Expanded(
                        child: Text(l.voucherDue, style: text.bodyLarge),
                      ),
                      const SizedBox(width: KassaTokens.spaceMd),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerEnd,
                          child: Ltr(
                            child: Text(
                              formatEuro(due),
                              key: const Key('voucher-redeem-due'),
                              maxLines: 1,
                              style: KassaText.amount(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KassaTokens.spaceXxl),
                  VoucherCodeEntry(
                    onFound: _onFound,
                    onCleared: _onCleared,
                    problem: problem == null
                        ? null
                        : voucherRedeemProblemText(l, problem),
                  ),
                  if (ready) ...[
                    const SizedBox(height: KassaTokens.spaceXxl),
                    _RedeemResult(
                      key: _resultKey,
                      balanceCents: balance,
                      useCents: use,
                    ),
                  ],
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
                  key: const Key('voucher-redeem-failed'),
                  style: text.bodyMedium!.copyWith(color: c.red),
                ),
              ),
            ),
          if (ready)
            Padding(
              padding: const EdgeInsets.all(12),
              child: VoucherActionButton(
                key: const Key('voucher-redeem-go'),
                label: use >= due
                    ? l.voucherRedeemAll(ltrIsolate(context, formatEuro(use)))
                    : l.voucherRedeemPart(
                        ltrIsolate(context, formatEuro(use)),
                        ltrIsolate(context, formatEuro(due - use)),
                      ),
                onPressed: () => _redeem(found, due),
              ),
            ),
        ],
      ),
    );
  }
}

/// Eine Hauptaktion der Gutscheine ("Einlösen ...", "Mit Gutschein
/// abschließen"): sieht aus wie ein gefüllter `PrimaryButton` mit 80 dp,
/// bricht aber in eine zweite Zeile um, statt zu kürzen; die Texte sind in
/// manchen Sprachen und bei großer Schrift länger als die Spalte. Ohne
/// [onPressed] ist sie grau.
class VoucherActionButton extends StatelessWidget {
  const VoucherActionButton({
    required Key key,
    required this.label,
    required this.onPressed,
  }) : super(key: key);

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: onPressed,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: KassaTokens.mainActionHeight,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: KassaTokens.spaceXxl,
          vertical: KassaTokens.spaceMd,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.gift, size: 26, color: c.onAccent),
            const SizedBox(width: KassaTokens.spaceLg),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: text.titleLarge!.copyWith(
                  fontSize: 20,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: c.onAccent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nach dem Treffer: Guthaben, was eingelöst wird, was am Gutschein bleibt.
class _RedeemResult extends StatelessWidget {
  const _RedeemResult({
    super.key,
    required this.balanceCents,
    required this.useCents,
  });

  final int balanceCents;
  final int useCents;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    Widget row(String label, int cents, Key key, {bool big = false}) => Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
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
                    : text.titleLarge!.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(KassaTokens.spaceXxl),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(
            l.voucherBalance,
            balanceCents,
            const Key('voucher-redeem-balance'),
          ),
          const SizedBox(height: KassaTokens.spaceMd),
          row(
            l.voucherUse,
            useCents,
            const Key('voucher-redeem-use'),
            big: true,
          ),
          const SizedBox(height: KassaTokens.spaceMd),
          row(
            l.voucherLeft,
            balanceCents - useCents,
            const Key('voucher-redeem-left'),
          ),
        ],
      ),
    );
  }
}
