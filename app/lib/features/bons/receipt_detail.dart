import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_language.dart';
import '../../core/money.dart';
import '../../data/providers.dart';
import '../../data/receipt_repository.dart' show NotInCurrentChainException;
import '../../data/settings_repository.dart';
import '../../devices/printer.dart';
import '../../domain/receipt.dart';
import '../../l10n/generated/l10n.dart';
import '../../rksv/rksv_state.dart';
import '../../ui/ltr.dart';
import '../../ui/primary_button.dart';
import '../../ui/print_problem_text.dart';
import '../../ui/qr_view.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/undo_toast.dart';
import '../kassa/kitchen_service.dart';
import '../kassa/sale_service.dart';
import '../login/session.dart';
import 'receipt_list.dart';
import 'void_question.dart';

/// Die Spalte rechts (392 dp): der gewählte Bon mit Zeilen, Steuer, Zahlung
/// und, wenn erlaubt, "Stornieren". Ist der Küchenbon eingeschaltet, hat ein
/// Verkauf daneben "Küchenbon drucken" (als Kopie). Die Rückfrage steht an Ort und Stelle.
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

  /// Warum der letzte Storno nicht geklappt hat, sonst `null`.
  VoidFailure? _failure;

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
      _failure = null;
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
    } catch (e) {
      final failure = e is NotInCurrentChainException
          ? await _notInChainFailure()
          : VoidFailure.failed;
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failure = failure;
      });
    }
  }

  /// Der Grund, wenn der Bon nicht zur laufenden Kette gehört: in Betrieb
  /// stammt er aus der Testzeit, sonst ist er älter als die Probe.
  Future<VoidFailure> _notInChainFailure() async {
    try {
      final state = await ref.read(rksvRepositoryProvider).current();
      if (state.mode == RksvMode.live) return VoidFailure.fromTestTime;
    } catch (_) {
      // Ohne Stand bleibt der bisherige Satz.
    }
    return VoidFailure.olderThanProbe;
  }

  /// Zeigt das Ergebnis des Druckens als Hinweis unten, ohne "Rückgängig".
  Future<void> _announce(Future<PrintOutcome> print) async {
    final outcome = await print;
    if (!mounted) return;
    // Ohne Drucker gibt es nichts zu melden.
    if (outcome.problem == PrintProblem.notSetUp) return;
    final l = L10n.of(context);
    showUndoToast(
      context,
      message: outcome.ok
          ? l.kassaPrinted
          : printProblemText(l, outcome.problem!),
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

  /// Solange "Küchenbon drucken" läuft, tun weitere Tipps darauf nichts.
  bool _printingKitchen = false;

  Future<void> _printKitchen(Receipt receipt, KitchenMode mode) async {
    if (_printingKitchen) return;
    _printingKitchen = true;
    try {
      final outcome = await ref
          .read(kitchenServiceProvider)
          .printFor(receipt, copy: true);
      if (!mounted) return;
      final l = L10n.of(context);
      showUndoToast(
        context,
        // `null`: keine Zeile des Bons gehört in die Küche.
        message: outcome == null
            ? l.bonsKitchenNothing
            : outcome.ok
            ? l.kassaKitchenPrinted
            : kitchenProblemText(l, outcome.problem!, mode),
      );
    } finally {
      _printingKitchen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final l = L10n.of(context);
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
    // Nur ein Verkauf, der gilt: ein stornierter käme sonst noch einmal in
    // die Küche.
    final canKitchen =
        receipt != null &&
        receipt.kind == ReceiptKind.sale &&
        !receipt.isVoided &&
        settings.kitchenMode != KitchenMode.off;
    final printButton = receipt == null || !hasPrinter
        ? null
        : PrimaryButton(
            key: const Key('print-receipt'),
            label: l.bonsPrint,
            icon: LucideIcons.printer,
            filled: false,
            height: KassaTokens.secondaryActionHeight,
            onPressed: () => _print(receipt),
          );
    final kitchenButton = !canKitchen
        ? null
        : PrimaryButton(
            key: const Key('print-kitchen'),
            label: l.kassaKitchenPrint,
            filled: false,
            height: KassaTokens.secondaryActionHeight,
            onPressed: () => _printKitchen(receipt, settings.kitchenMode),
          );
    final voidButton = !canVoid
        ? null
        : BonsActionButton(
            key: const Key('void-receipt'),
            label: l.bonsVoid,
            height: KassaTokens.secondaryActionHeight,
            radius: KassaTokens.radiusXxl,
            border: c.line,
            fg: c.red,
            onTap: () => setState(() => _asking = true),
          );
    // Die Druck-Tasten stehen nebeneinander, "Küchenbon drucken" mit mehr
    // Platz für die längere Beschriftung; "Stornieren" steht dann darunter.
    // Ohne Küchenbon bleibt es eine Reihe: "Drucken" und "Stornieren".
    final rows = <List<(Widget, int)>>[
      if (kitchenButton == null)
        [
          if (printButton != null) (printButton, 1),
          if (voidButton != null) (voidButton, 1),
        ]
      else ...[
        [if (printButton != null) (printButton, 2), (kitchenButton, 3)],
        [if (voidButton != null) (voidButton, 1)],
      ],
    ]..removeWhere((row) => row.isEmpty);

    return Container(
      width: KassaTokens.receiptColumnWidth,
      decoration: BoxDecoration(
        color: c.card,
        border: BorderDirectional(
          start: BorderSide(color: c.line, width: KassaTokens.borderThin),
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
                    failure: _failure,
                    onCancel: () => setState(() {
                      _asking = false;
                      _failure = null;
                    }),
                    onConfirm: () => _confirm(receipt),
                  )
                else if (rows.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < rows.length; i++) ...[
                          if (i > 0)
                            const SizedBox(height: KassaTokens.spaceMd),
                          Row(
                            children: [
                              for (var j = 0; j < rows[i].length; j++) ...[
                                if (j > 0)
                                  const SizedBox(width: KassaTokens.spaceMd),
                                Expanded(
                                  flex: rows[i][j].$2,
                                  child: rows[i][j].$1,
                                ),
                              ],
                            ],
                          ),
                        ],
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
          L10n.of(context).bonsNothingSelected,
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
    final l = L10n.of(context);
    // Ein Sonderbeleg heißt nach seiner Art; die Pille sagte dasselbe.
    final special = specialTitleText(l, receipt.kind);
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
            special ?? l.kassaReceiptNumber(receipt.number),
            maxLines: 1,
            style: text.headlineMedium,
          ),
          const SizedBox(width: KassaTokens.spaceLg),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                l.bonsTime(ltrIsolate(context, receiptTime(receipt.createdAt))),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelLarge!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: c.ink2,
                ),
              ),
            ),
          ),
          if (special == null) ...[
            const SizedBox(width: KassaTokens.spaceLg),
            ReceiptPill(receipt),
          ],
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
    final l = L10n.of(context);
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
    final special = r.kind.isSpecial;
    final rksv = r.rksv;
    final d = r.createdAt;
    return ListView(
      key: const Key('detail-scroll'),
      padding: EdgeInsets.zero,
      children: [
        for (final l in r.lines) _LineRow(l),
        if (r.depositCents != 0)
          _AmountRow(l.bonsDeposit, formatEuro(r.depositCents), strong: true),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final t in r.taxLines)
                _SmallRow(
                  l.bonsTaxRate(t.rate.percent),
                  formatEuro(t.taxCents),
                  small,
                ),
              // Sonderbelege haben keine Zahlung.
              if (payment != null) ...[
                const SizedBox(height: KassaTokens.spaceMd),
                _SmallRow(
                  l.bonsPayment,
                  payment.kind == PaymentKind.cash ? l.bonsCash : l.bonsCard,
                  small,
                ),
                if (cash) ...[
                  _SmallRow(
                    l.kassaGiven,
                    formatEuro(payment.givenCents),
                    small,
                  ),
                  _SmallRow(
                    l.kassaChange,
                    formatEuro(payment.changeCents),
                    small,
                  ),
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
                  l.bonsVoidOf('${pair?.number ?? '?'}'),
                  style: small.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
              Ltr(
                child: Text(
                  '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}',
                  textAlign: ltrAlign(context, TextAlign.start),
                  style: small,
                ),
              ),
              Text(switch (r.kind) {
                ReceiptKind.voided => l.bonsVoidedBy(r.staffName),
                _ when special => l.bonsCreatedBy(r.staffName),
                _ => l.bonsRungUpBy(r.staffName),
              }, style: small),
              if (r.isVoided)
                Padding(
                  padding: const EdgeInsets.only(top: KassaTokens.spaceSm),
                  child: Text(
                    voider == null
                        ? l.bonsVoidedNotCounted
                        : l.bonsVoidedByNotCounted(voider.staffName),
                    style: small,
                  ),
                ),
            ],
          ),
        ),
        if (rksv != null) _SignatureBlock(rksv),
      ],
    );
  }
}

/// Unter der Zahlung: links der QR-Code (180 dp), rechts die Kassen-ID und
/// klein, was der Code ist, bzw. dass die Signatur ausgefallen war (beim
/// Testbon mit "Testbon" darüber).
class _SignatureBlock extends StatelessWidget {
  const _SignatureBlock(this.stamp);

  final RksvStamp stamp;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final small = text.bodySmall!.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.35,
      color: c.ink2,
    );
    return Padding(
      key: const Key('receipt-signature'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        children: [
          QrView(data: stamp.qrText),
          const SizedBox(width: KassaTokens.spaceXxl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.bonsCashBoxId(stamp.cashBoxId),
                  style: text.bodyMedium!.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: KassaTokens.spaceXs),
                if (stamp.damaged) ...[
                  // Ein Testbon bleibt ein Testbon, auch mit Ausfall-Vermerk.
                  if (stamp.probe) Text(l.bonsTestReceipt, style: small),
                  Text(l.bonsDeviceFailed, style: small),
                ] else if (stamp.probe) ...[
                  Text(l.bonsProbeSignature, style: small),
                  Text(l.bonsQrOnPaper, style: small),
                ],
              ],
            ),
          ),
        ],
      ),
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
    // Die Namen des gespeicherten Bons, wie er gedruckt wurde.
    final sub = [
      for (final o in line.options) nameIsolateIn(context, o.optionName),
      if (line.info != null && line.info!.isNotEmpty)
        nameIsolateIn(context, line.info!),
    ].join(L10n.of(context).uiListSeparator);
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
                Text(nameIsolateIn(context, line.name), style: text.bodyLarge),
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
          Ltr(child: Text(formatEuro(line.goodsCents), style: text.bodyLarge)),
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
          Ltr(child: Text(amount, style: text.bodyLarge)),
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
          // Meist ein Betrag; ein Wort ("Bar") steht so gleich.
          Ltr(child: Text(value, style: style)),
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
          Text(L10n.of(context).kassaTotal, style: text.bodyLarge),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Ltr(
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
          ),
        ],
      ),
    );
  }
}
