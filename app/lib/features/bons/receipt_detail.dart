import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../devices/printer.dart';
import '../../domain/receipt.dart';
import '../../ui/primary_button.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/undo_toast.dart';
import '../kassa/sale_service.dart';
import '../login/session.dart';
import 'receipt_list.dart';
import 'void_question.dart';

/// Die Spalte rechts (392 dp): der gewählte Bon mit Zeilen, Steuer, Zahlung
/// und, wenn erlaubt, "Stornieren". Die Rückfrage steht an Ort und Stelle.
/// [all] sind die Bons des Tages (für Namen und Nummern der Storno-Paare).
/// Der Aufrufer gibt der Spalte je Bon einen eigenen Schlüssel, damit eine
/// offene Rückfrage nicht zu einem anderen Bon wandert.
class ReceiptDetail extends ConsumerStatefulWidget {
  const ReceiptDetail({super.key, required this.receipt, required this.all});

  final Receipt? receipt;
  final List<Receipt> all;

  @override
  ConsumerState<ReceiptDetail> createState() => _ReceiptDetailState();
}

class _ReceiptDetailState extends ConsumerState<ReceiptDetail> {
  bool _asking = false;
  bool _busy = false;
  bool _failed = false;

  Receipt? _find(String? id) {
    for (final r in widget.all) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> _confirm(Receipt receipt) async {
    if (_busy) return; // ein zweiter Tipp, bevor die Knöpfe grau sind
    final staff = ref.read(sessionProvider);
    if (staff == null) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final result = await ref
          .read(saleServiceProvider)
          .voidReceipt(receipt.id, staff: staff);
      _announce(result.print);
      if (!mounted) return;
      setState(() {
        _asking = false;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failed = true;
      });
    }
  }

  /// Zeigt das Ergebnis des Druckens als Hinweis unten, ohne "Rückgängig".
  Future<void> _announce(Future<PrintOutcome> print) async {
    final outcome = await print;
    if (!mounted) return;
    // Ohne Drucker gibt es nichts zu melden.
    if (outcome.problem == PrintProblem.notSetUp) return;
    showUndoToast(
      context,
      message: outcome.ok ? 'Bon gedruckt' : outcome.message,
    );
  }

  /// Solange "Drucken" läuft, tun weitere Tipps darauf nichts.
  bool _printing = false;

  Future<void> _print(Receipt receipt) async {
    if (_printing) return;
    _printing = true;
    try {
      await _announce(ref.read(saleServiceProvider).reprint(receipt));
    } finally {
      _printing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final receipt = widget.receipt;
    final staff = ref.watch(sessionProvider);
    final settings =
        ref.watch(settingsStreamProvider).value ?? const RegisterSettings();
    final hasPrinter = settings.printerKind != PrinterKind.none;
    final canVoid =
        receipt != null &&
        receipt.kind == ReceiptKind.sale &&
        !receipt.isVoided &&
        staff != null &&
        (staff.isChef || !settings.voidRequiresChef);
    return Container(
      width: KassaTokens.receiptColumnWidth,
      decoration: BoxDecoration(
        color: c.card,
        border: Border(
          left: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: receipt == null
          ? const _NothingSelected()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(receipt),
                Expanded(child: _Body(receipt, this)),
                _Total(receipt),
                if (canVoid && _asking)
                  VoidQuestion(
                    receipt: receipt,
                    busy: _busy,
                    failed: _failed,
                    onCancel: () => setState(() {
                      _asking = false;
                      _failed = false;
                    }),
                    onConfirm: () => _confirm(receipt),
                  )
                else if (canVoid || hasPrinter)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      children: [
                        if (hasPrinter)
                          Expanded(
                            child: PrimaryButton(
                              key: const Key('print-receipt'),
                              label: 'Drucken',
                              icon: LucideIcons.printer,
                              filled: false,
                              height: KassaTokens.secondaryActionHeight,
                              onPressed: () => _print(receipt),
                            ),
                          ),
                        if (hasPrinter && canVoid)
                          const SizedBox(width: KassaTokens.spaceMd),
                        if (canVoid)
                          Expanded(
                            child: BonsActionButton(
                              key: const Key('void-receipt'),
                              label: 'Stornieren',
                              height: KassaTokens.secondaryActionHeight,
                              radius: KassaTokens.radiusXxl,
                              border: c.line,
                              fg: c.red,
                              onTap: () => setState(() => _asking = true),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _NothingSelected extends StatelessWidget {
  const _NothingSelected();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KassaTokens.spaceHuge),
        child: Text(
          'Tippe auf einen Bon, um ihn anzusehen.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontWeight: FontWeight.w600,
            color: KassaColors.of(context).ink2,
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.receipt);

  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      height: KassaTokens.receiptHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Bon Nr. ${receipt.number}',
            maxLines: 1,
            style: text.headlineMedium,
          ),
          const SizedBox(width: KassaTokens.spaceLg),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '${receiptTime(receipt.createdAt)} Uhr',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelLarge!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: c.ink2,
                ),
              ),
            ),
          ),
          const SizedBox(width: KassaTokens.spaceLg),
          ReceiptPill(receipt),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.receipt, this.state);

  final Receipt receipt;
  final _ReceiptDetailState state;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final small = text.bodySmall!.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: c.ink2,
    );
    final r = receipt;
    final pair = r.kind == ReceiptKind.voided
        ? state._find(r.voidsReceiptId)
        : null;
    final voider = r.isVoided ? state._find(r.voidedByReceiptId) : null;
    final payment = r.payment;
    final cash =
        r.kind == ReceiptKind.sale && payment?.kind == PaymentKind.cash;
    final special = r.kind.specialTitle;
    final d = r.createdAt;
    return ListView(
      key: const Key('detail-scroll'),
      padding: EdgeInsets.zero,
      children: [
        for (final l in r.lines) _LineRow(l),
        if (r.depositCents != 0)
          _AmountRow('Pfand', formatEuro(r.depositCents), strong: true),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final t in r.taxLines)
                _SmallRow(
                  '${t.rate.percent} % MwSt',
                  formatEuro(t.taxCents),
                  small,
                ),
              // Sonderbelege haben keine Zahlung.
              if (payment != null) ...[
                const SizedBox(height: KassaTokens.spaceMd),
                _SmallRow(
                  'Zahlung',
                  payment.kind == PaymentKind.cash ? 'Bar' : 'Karte',
                  small,
                ),
                if (cash) ...[
                  _SmallRow('Gegeben', formatEuro(payment.givenCents), small),
                  _SmallRow('Rückgeld', formatEuro(payment.changeCents), small),
                ],
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (r.kind == ReceiptKind.voided)
                Text(
                  'Storno zu Bon Nr. ${pair?.number ?? '?'}',
                  style: small.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                )
              else if (special != null)
                Text(
                  special.toUpperCase(),
                  style: small.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
              Text(
                '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}',
                style: small,
              ),
              Text(
                r.kind == ReceiptKind.voided
                    ? 'Storniert von ${r.staffName}'
                    : 'Boniert von ${r.staffName}',
                style: small,
              ),
              if (r.isVoided)
                Padding(
                  padding: const EdgeInsets.only(top: KassaTokens.spaceSm),
                  child: Text(
                    voider == null
                        ? 'Storniert. Dieser Bon zählt nicht zum Umsatz.'
                        : 'Storniert von ${voider.staffName}. Dieser Bon zählt nicht zum Umsatz.',
                    style: small,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow(this.line);

  final ReceiptLine line;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final sub = [
      for (final o in line.options) o.optionName,
      if (line.info != null && line.info!.isNotEmpty) line.info!,
    ].join(', ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 34),
            child: Text(
              '${signedCount(line.quantity)} ×',
              style: text.bodyMedium!.copyWith(color: c.ink2),
            ),
          ),
          const SizedBox(width: KassaTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: text.bodyLarge),
                if (sub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: KassaTokens.spaceXxs),
                    child: Text(
                      sub,
                      style: text.bodySmall!.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        color: c.ink2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: KassaTokens.spaceMd),
          Text(formatEuro(line.goodsCents), style: text.bodyLarge),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow(this.label, this.amount, {this.strong = false});

  final String label;
  final String amount;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: text.bodyMedium!.copyWith(color: c.ink2)),
          Text(amount, style: text.bodyLarge),
        ],
      ),
    );
  }
}

class _SmallRow extends StatelessWidget {
  const _SmallRow(this.label, this.value, this.style);

  final String label;
  final String value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total(this.receipt);

  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Summe', style: text.bodyLarge),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatEuro(receipt.totalCents),
                key: const Key('detail-total'),
                maxLines: 1,
                style: KassaText.amount(context).copyWith(
                  decoration: receipt.isVoided
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
