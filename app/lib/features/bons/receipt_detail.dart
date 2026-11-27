import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_sync_providers.dart' show hasServerProvider;
import '../../core/app_language.dart';
import '../../core/money.dart';
import '../../data/delivery_repository.dart';
import '../../data/providers.dart';
import '../../data/receipt_repository.dart'
    show NotInCurrentChainException, VoucherSaleRedeemedException;
import '../../data/settings_repository.dart';
import '../../devices/printer.dart';
import '../../domain/cart.dart' show isDepositReturnItemId;
import '../../domain/discount.dart';
import '../../domain/receipt.dart';
import '../../domain/voucher.dart';
import '../../l10n/generated/l10n.dart';
import '../../rksv/rksv_state.dart';
import '../../ui/ltr.dart';
import '../../ui/primary_button.dart';
import '../../ui/print_problem_text.dart';
import '../../ui/qr_view.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/undo_toast.dart';
import '../customers/customer_picker.dart';
import '../kassa/cart_line_row.dart' show discountReasonText;
import '../kassa/kitchen_service.dart';
import '../kassa/late_kitchen.dart';
import '../kassa/receipt_qr.dart';
import '../kassa/sale_done.dart' show KitchenStateBox;
import '../kassa/sale_service.dart';
import '../login/session.dart';
import 'receipt_list.dart';
import 'void_question.dart';

/// Die Spalte rechts (392 dp): der gewählte Bon mit Zeilen, Steuer, Zahlung
/// und, wenn erlaubt, "Stornieren". Ist der Küchenbon eingeschaltet, hat ein
/// Verkauf daneben "Küchenbon drucken" (als Kopie), ebenso ein Storno-Bon
/// (der Zettel bleibt STORNO); ein stornierter Verkauf nicht. Scheitert der
/// STORNO-Zettel gleich nach dem Stornieren, steht über den Tasten "Küchenbon
/// nicht gedruckt" mit Grund und "Küchenbon drucken". Die Rückfrage steht an
/// Ort und Stelle.
/// [all] sind die Bons des Tages (für Namen und Nummern der Storno-Paare).
/// Der Aufrufer gibt der Spalte je Bon einen eigenen Schlüssel, damit eine
/// offene Rückfrage nicht zu einem anderen Bon wandert.
/// Ist "Rechnung an Firma" an, steht bei einem Verkauf, der gilt und kein
/// Testbon ist, die Rechnung ([InvoiceBox]) über der Signatur; "Rechnung an
/// Firma" öffnet an Stelle des Bons das Blatt "Firmenkunde wählen".
/// Gibt es Einträge, wie der Beleg erteilt wurde, steht die Zeile "Beleg"
/// mit "Gedruckt" und "Digital angeboten" und ihren Zeiten da. Ist der
/// Kundenbon digital ([effectiveReceiptMode]) und hat der Bon einen
/// Schlüssel und ist er kein Sonderbeleg, steht darunter der QR-Code seiner
/// Seite (`detail-receipt-qr`); er zählt nicht als Belegerteilung.
class ReceiptDetail extends ConsumerStatefulWidget {
  const ReceiptDetail({super.key, required this.receipt, required this.all});

  final Receipt? receipt;
  final List<Receipt> all;

  @override
  ConsumerState<ReceiptDetail> createState() => _ReceiptDetailState();
}

class _ReceiptDetailState extends ConsumerState<ReceiptDetail> {
  bool _asking = false;

  /// Ob ein Bondrucker eingerichtet ist (aus dem letzten Bild).
  bool _hasPrinter = false;

  /// Ob "Rechnung an Firma" bei diesem Bon steht (aus dem letzten Bild).
  bool _invoice = false;

  /// Wie der Beleg erteilt wurde (aus dem letzten Bild).
  List<ReceiptDelivery> _deliveries = const [];

  /// Ob der QR-Code der Seite des Bons dasteht (aus dem letzten Bild).
  bool _showQr = false;

  /// "Rechnung an Firma" ist getippt: an Stelle des Bons steht das Blatt
  /// "Firmenkunde wählen".
  bool _picking = false;

  void _pick() => setState(() => _picking = true);
  bool _busy = false;

  /// Warum der letzte Storno nicht geklappt hat, sonst `null`.
  VoidFailure? _failure;

  /// Der Storno-Bon des eben gemachten Stornos, solange sein Küchenbon
  /// gescheitert ist (oder danach nachgedruckt wurde); sonst `null`.
  Receipt? _voidReceipt;

  /// Das letzte Ergebnis seines Küchenbons.
  PrintOutcome? _voidKitchen;

  /// "Küchenbon drucken" für den Storno läuft.
  bool _voidKitchenAgain = false;

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
    // Vor dem Warten gelesen: danach kann das Detail schon weg sein.
    final lateKitchen = ref.read(lateKitchenProvider.notifier);
    try {
      final result = await ref
          .read(saleServiceProvider)
          .voidReceipt(receipt.id, staff: staff);
      // Ein abgesagter Verkauf kommt nicht mehr in die Küche: ein Hinweis
      // der Kassa zu ihm geht weg (der STORNO-Zettel hat seinen eigenen Weg).
      lateKitchen.dismiss(receipt.id);
      _announce(result.print);
      _followVoidKitchen(result.receipt, result.kitchen, retry: false);
      if (!mounted) return;
      setState(() {
        _asking = false;
        _busy = false;
      });
    } catch (e) {
      final failure = switch (e) {
        NotInCurrentChainException() => await _notInChainFailure(),
        VoucherSaleRedeemedException() => VoidFailure.voucherRedeemed,
        _ => VoidFailure.failed,
      };
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

  /// Zeigt das Ergebnis des Druckens als Hinweis unten, ohne "Rückgängig";
  /// gedruckt sagt er [okText] (ohne: "Bon gedruckt").
  Future<void> _announce(
    Future<PrintOutcome> print, {
    String Function(L10n l)? okText,
  }) async {
    final outcome = await print;
    if (!mounted) return;
    // Ohne Drucker gibt es nichts zu melden.
    if (outcome.problem == PrintProblem.notSetUp) return;
    final l = L10n.of(context);
    showUndoToast(
      context,
      message: outcome.ok
          ? (okText?.call(l) ?? l.kassaPrinted)
          : printProblemText(l, outcome.problem!),
    );
  }

  /// Zeigt einen gescheiterten Küchenbon des Stornos an. Beim ersten
  /// Ergebnis ([retry] falsch) nur, wenn er gescheitert ist; nach
  /// "Küchenbon drucken" auch, dass er gedruckt ist. Wartet nie auf ihn.
  void _followVoidKitchen(
    Receipt voidReceipt,
    Future<PrintOutcome?> kitchen, {
    required bool retry,
  }) {
    void show(PrintOutcome? outcome) {
      if (!mounted) return;
      if (!retry && (outcome == null || outcome.ok)) return;
      setState(() {
        _voidReceipt = outcome == null ? null : voidReceipt;
        _voidKitchen = outcome;
        _voidKitchenAgain = false;
      });
    }

    kitchen.then(
      show,
      onError: (Object _) =>
          show(const PrintOutcome.failed(PrintProblem.unreachable)),
    );
  }

  void _reprintVoidKitchen() {
    final voidReceipt = _voidReceipt;
    if (voidReceipt == null || _voidKitchenAgain) return;
    setState(() => _voidKitchenAgain = true);
    _followVoidKitchen(
      voidReceipt,
      ref.read(kitchenServiceProvider).printFor(voidReceipt, copy: true),
      retry: true,
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

  /// Solange ein Gutschein druckt, tun weitere Tipps darauf nichts.
  bool _printingVoucher = false;

  Future<void> _printVoucher(Receipt receipt, SoldVoucher voucher) async {
    if (_printingVoucher) return;
    _printingVoucher = true;
    try {
      await _announce(
        ref.read(saleServiceProvider).printVoucher(receipt, voucher),
        okText: (l) => l.bonsVoucherPrinted,
      );
    } finally {
      _printingVoucher = false;
    }
  }

  /// Solange "Küchenbon drucken" läuft, tun weitere Tipps darauf nichts.
  bool _printingKitchen = false;

  Future<void> _printKitchen(Receipt receipt, KitchenMode mode) async {
    if (_printingKitchen) return;
    _printingKitchen = true;
    final lateKitchen = ref.read(lateKitchenProvider.notifier);
    try {
      final outcome = await ref
          .read(kitchenServiceProvider)
          .printFor(receipt, copy: true);
      // Gedruckt: der Hinweis der Kassa zu diesem Bon ist erledigt.
      if (outcome != null && outcome.ok) lateKitchen.dismiss(receipt.id);
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
    _hasPrinter = hasPrinter;
    _invoice = receipt != null && showsInvoice(settings, receipt);
    _deliveries = receipt == null
        ? const []
        : ref.watch(receiptDeliveriesProvider(receipt.id)).value ?? const [];
    final paired =
        ref.watch(hasServerProvider) &&
        (ref.watch(syncStateProvider).value?.hasRegister ?? false);
    _showQr =
        receipt != null &&
        !receipt.kind.isSpecial &&
        receipt.publicToken != null &&
        effectiveReceiptMode(settings, paired: paired) !=
            ReceiptMode.alwaysPrint;
    final canVoid =
        receipt != null &&
        receipt.kind == ReceiptKind.sale &&
        !receipt.isVoided &&
        staff != null &&
        (staff.isChef || !settings.voidRequiresChef);
    // Ein Verkauf, der gilt (ein stornierter käme sonst noch einmal in die
    // Küche), und ein Storno-Bon: sein Zettel sagt der Küche STORNO.
    final canKitchen =
        receipt != null &&
        ((receipt.kind == ReceiptKind.sale && !receipt.isVoided) ||
            receipt.kind == ReceiptKind.voided) &&
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
          : _picking && _invoice
          ? CustomerPicker(
              receipt: receipt,
              onChosen: () => setState(() => _picking = false),
              onClose: () => setState(() => _picking = false),
            )
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
                else ...[
                  if (_voidKitchen case final kitchen?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: KitchenStateBox(
                        boxKey: const Key('void-kitchen'),
                        reprintKey: const Key('void-kitchen-reprint'),
                        outcome: kitchen,
                        mode: settings.kitchenMode,
                        printing: _voidKitchenAgain,
                        onReprint: _reprintVoidKitchen,
                      ),
                    ),
                  if (rows.isNotEmpty)
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
    final paymentKind = r.paymentKind;
    final payments = r.payments;
    // "Gegeben" und "Rückgeld" nur bei einer einzigen Bar-Zahlung, nie bei
    // einer Auszahlung.
    final cashPayment =
        r.kind == ReceiptKind.sale &&
            r.totalCents >= 0 &&
            payments.length == 1 &&
            payments.single.kind == PaymentKind.cash
        ? payments.single
        : null;
    final special = r.kind.isSpecial;
    final rksv = r.rksv;
    final d = r.createdAt;
    return ListView(
      key: const Key('detail-scroll'),
      padding: EdgeInsets.zero,
      children: [
        for (final l in r.lines) _LineRow(l),
        for (final (i, v) in r.soldVouchers.indexed)
          _VoucherRow(
            index: i,
            voucher: v,
            // Nur ein Verkauf, der gilt: ein stornierter Gutschein bekommt
            // keinen neuen Abschnitt.
            onPrint:
                state._hasPrinter && r.kind == ReceiptKind.sale && !r.isVoided
                ? () => state._printVoucher(r, v)
                : null,
          ),
        // Der Rabatt auf den ganzen Bon, über der Zwischensumme der Zeilen.
        if (r.discount case final d? when d.amountCents != 0) ...[
          _AmountRow(l.bonsSubtotal, formatEuro(r.subtotalCents)),
          _AmountRow(
            _discountText(l, d),
            formatEuro(-d.amountCents),
            amountKey: const Key('detail-discount'),
          ),
        ],
        // Nur das verlangte Pfand; das zurückgegebene steht bei seinen
        // Zeilen.
        if (r.depositCents - r.depositReturnCents != 0)
          _AmountRow(
            l.bonsDeposit,
            formatEuro(r.depositCents - r.depositReturnCents),
            strong: true,
          ),
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
              // Sonderbelege haben keine Zahlung. Ein Bon, den nur Gutscheine
              // bezahlen, hat weder bar noch Karte, aber Zahlungen.
              if (paymentKind != null || r.voucherCents != 0) ...[
                const SizedBox(height: KassaTokens.spaceMd),
                // Eine Zahlung ohne Trinkgeld: nur die Zahlungsart. Ein
                // Gutschein steht immer mit Code und Restguthaben da.
                if (payments.length == 1 &&
                    payments.single.tipCents == 0 &&
                    payments.single.kind != PaymentKind.voucher)
                  _SmallRow(
                    key: const Key('detail-payment-0'),
                    l.bonsPayment,
                    receiptPaymentLabel(l, r),
                    small,
                  )
                else ...[
                  // Mehrere Zahlungen oder Trinkgeld: die Zahlungsart, dann
                  // jede Zahlung in ihrer Reihenfolge. Die Karte mit dem
                  // gebuchten Betrag (mit Trinkgeld) wie am Bon, darunter
                  // "davon Trinkgeld".
                  _SmallRow(l.bonsPayment, receiptPaymentLabel(l, r), small),
                  for (final (i, p) in payments.indexed) ...[
                    _SmallRow(
                      key: Key('detail-payment-$i'),
                      switch (p.kind) {
                        PaymentKind.cash => l.bonsCash,
                        PaymentKind.card => l.bonsCard,
                        // "Gutschein 1234 5678", der Code von links nach
                        // rechts.
                        PaymentKind.voucher => l.voucherWithCode(
                          ltrIsolate(
                            context,
                            formatVoucherCode(p.voucherCode ?? ''),
                          ),
                        ),
                      },
                      formatEuro(
                        p.kind == PaymentKind.card
                            ? p.chargedCents
                            : p.amountCents,
                      ),
                      small,
                    ),
                    if (p.kind == PaymentKind.voucher &&
                        p.voucherBalanceAfterCents != null)
                      _SmallRow(
                        key: Key('detail-voucher-left-$i'),
                        l.bonsVoucherLeft,
                        formatEuro(p.voucherBalanceAfterCents!),
                        small,
                      ),
                    if (p.tipCents != 0)
                      _SmallRow(
                        key: const Key('detail-tip'),
                        l.bonsTipIncluded,
                        formatEuro(p.tipCents),
                        small,
                      ),
                  ],
                ],
                if (cashPayment != null) ...[
                  _SmallRow(
                    l.kassaGiven,
                    formatEuro(cashPayment.givenCents),
                    small,
                  ),
                  _SmallRow(
                    l.kassaChange,
                    formatEuro(cashPayment.changeCents),
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
                ReceiptKind.voided => l.bonsVoidedBy(
                  nameIsolateIn(context, r.staffName),
                ),
                _ when special => l.bonsCreatedBy(
                  nameIsolateIn(context, r.staffName),
                ),
                _ => l.bonsRungUpBy(nameIsolateIn(context, r.staffName)),
              }, style: small),
              if (r.isVoided)
                Padding(
                  padding: const EdgeInsets.only(top: KassaTokens.spaceSm),
                  child: Text(
                    voider == null
                        ? l.bonsVoidedNotCounted
                        : l.bonsVoidedByNotCounted(
                            nameIsolateIn(context, voider.staffName),
                          ),
                    style: small,
                  ),
                ),
            ],
          ),
        ),
        if (state._deliveries.isNotEmpty)
          Padding(
            key: const Key('detail-delivery'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.bonsDeliveryTitle,
                  style: small.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
                for (final delivery in state._deliveries)
                  _SmallRow(
                    key: Key('detail-delivery-${delivery.kind.name}'),
                    switch (delivery.kind) {
                      DeliveryKind.printed => l.bonsDeliveryPrinted,
                      DeliveryKind.digital => l.bonsDeliveryDigital,
                    },
                    l.bonsTime(receiptTime(delivery.at)),
                    small,
                  ),
              ],
            ),
          ),
        if (state._showQr)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ReceiptQr(
              receipt: r,
              qrKey: const Key('detail-receipt-qr'),
              // Ein Blick auf einen alten Bon ist keine Belegerteilung.
              recordsDelivery: false,
            ),
          ),
        if (state._invoice)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: InvoiceBox(receipt: r, onPick: state._pick),
          ),
        if (rksv != null) _SignatureBlock(rksv),
      ],
    );
  }
}

/// Unter der Zahlung: links der QR-Code (180 dp), rechts die Kassen-ID und
/// klein, was der Code ist, bzw. dass die Signatur ausgefallen war (beim
/// Testbon mit "Testbon" darüber).
/// Ein Gutschein, der auf dem Bon verkauft wurde: "Gutschein" mit Wert und
/// Code, mit [onPrint] daneben "Gutschein drucken".
class _VoucherRow extends StatelessWidget {
  const _VoucherRow({
    required this.index,
    required this.voucher,
    required this.onPrint,
  });

  final int index;
  final SoldVoucher voucher;
  final VoidCallback? onPrint;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final tabular = const [FontFeature.tabularFigures()];
    final print = onPrint;
    return Container(
      key: Key('detail-voucher-$index'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  l.kassaVoucher,
                  style: text.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.accentInk,
                  ),
                ),
              ),
              const SizedBox(width: KassaTokens.spaceMd),
              Ltr(
                child: Text(
                  formatEuro(voucher.valueCents),
                  maxLines: 1,
                  style: text.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: tabular,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KassaTokens.spaceXxs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                l.voucherCode,
                style: text.bodyMedium!.copyWith(color: c.ink2),
              ),
              const SizedBox(width: KassaTokens.spaceMd),
              Expanded(
                child: Ltr(
                  child: Text(
                    formatVoucherCode(voucher.code),
                    key: Key('detail-voucher-code-$index'),
                    textAlign: ltrAlign(context, TextAlign.end),
                    maxLines: 1,
                    style: text.titleLarge!.copyWith(
                      letterSpacing: 1,
                      fontFeatures: tabular,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (print != null) ...[
            const SizedBox(height: KassaTokens.spaceMd),
            PrimaryButton(
              key: Key('detail-voucher-print-$index'),
              label: l.voucherPrint,
              icon: LucideIcons.printer,
              filled: false,
              height: 64,
              onPressed: print,
            ),
          ],
        ],
      ),
    );
  }
}

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
    final small = text.bodySmall!.copyWith(
      fontSize: 13.5,
      fontWeight: FontWeight.w400,
      color: c.ink2,
    );
    // "Pfand zurück": in der Bediensprache, mit dem Pfand der Zeile (mit
    // Minus) statt des Warenwerts 0.
    final depositReturn = isDepositReturnItemId(line.itemId);
    // Die Namen des gespeicherten Bons, wie er gedruckt wurde.
    final sub = [
      for (final o in line.options) nameIsolateIn(context, o.optionName),
      if (line.info != null && line.info!.isNotEmpty)
        nameIsolateIn(context, line.info!),
    ].join(L10n.of(context).uiListSeparator);
    final row = Row(
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
              Text(
                depositReturn
                    ? L10n.of(context).kassaDepositReturn
                    : nameIsolateIn(context, line.name),
                style: text.bodyLarge,
              ),
              if (sub.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: KassaTokens.spaceXxs),
                  child: Text(sub, style: small),
                ),
            ],
          ),
        ),
        const SizedBox(width: KassaTokens.spaceMd),
        Ltr(
          child: Text(
            formatEuro(depositReturn ? line.depositCents : line.goodsCents),
            style: text.bodyLarge,
          ),
        ),
      ],
    );
    final discount = line.discount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: discount == null || discount.amountCents == 0
          ? row
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                row,
                // Der eigene Rabatt der Zeile, unter ihr.
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 34 + KassaTokens.spaceMd,
                    top: KassaTokens.spaceXxs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _discountText(L10n.of(context), discount),
                          style: small,
                        ),
                      ),
                      const SizedBox(width: KassaTokens.spaceMd),
                      Ltr(
                        child: Text(
                          formatEuro(-discount.amountCents),
                          key: Key('detail-line-discount-${line.position}'),
                          style: small,
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

/// "−10 % Stammgast" oder "Rabatt Stammgast" in der Bediensprache; ein
/// unbekannter Grund steht da, wie er gespeichert ist.
String _discountText(L10n l, ReceiptDiscount d) {
  final known = DiscountReason.values.where((r) => r.name == d.reason);
  final reason = known.isEmpty ? d.reason : discountReasonText(l, known.first);
  final percent = d.percent;
  return percent != null
      ? l.discountRowPercent(percent, reason)
      : l.discountRowAmount(reason);
}

class _AmountRow extends StatelessWidget {
  const _AmountRow(
    this.label,
    this.amount, {
    this.strong = false,
    this.amountKey,
  });

  final String label;
  final String amount;
  final bool strong;
  final Key? amountKey;

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
          Ltr(
            child: Text(amount, key: amountKey, style: text.bodyLarge),
          ),
        ],
      ),
    );
  }
}

class _SmallRow extends StatelessWidget {
  const _SmallRow(this.label, this.value, this.style, {super.key});

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
