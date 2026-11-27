import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_language.dart';
import '../../core/money.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../devices/printer.dart';
import '../../domain/receipt.dart';
import '../../domain/voucher.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/ltr.dart';
import '../../ui/primary_button.dart';
import '../../ui/print_problem_text.dart';
import '../../ui/tokens.dart';
import '../customers/customer_picker.dart';
import 'cash_sheet.dart';
import 'kitchen_service.dart';
import 'late_kitchen.dart';
import 'sale_service.dart';

/// Nach dem Bezahlen: "Bezahlt", die Bon-Nummer, der Stand des Druckens und
/// das Rückgeld, das die Person jetzt herausgibt. Bei einer Kartenzahlung steht
/// statt des Rückgelds "Mit Karte bezahlt" und, was bekannt ist, Kartenart und
/// die letzten vier Ziffern; nach einer Auszahlung (Bon unter 0, etwa Pfand
/// zurück) "Auszahlen" mit dem Betrag. "Nächster Kunde" führt zur
/// leeren Kassa zurück und ist immer sofort aktiv, auch während des Druckens.
/// Scheitert der Küchenbon, steht unter dem Druckzustand "Küchenbon nicht
/// gedruckt" mit der Meldung des Druckers und "Küchenbon drucken"; auf ihn
/// wird nie gewartet. Geht die Ansicht weg ("Nächster Kunde"), übernimmt der
/// Hinweis über dem Bon ([LateKitchenNotice]) einen Küchenbon, der noch läuft
/// oder gescheitert ist.
///
/// Je verkauftem Gutschein steht unter dem Rückgeld eine Reihe
/// `sold-voucher-<n>` mit Wert und Code ("1234 5678"), mit Drucker dazu
/// "Gutschein drucken"; scheitert ein Abschnitt, steht der Grund in seiner
/// Reihe. Ohne Drucker schreibt der Betrieb den Code von hier ab.
///
/// Ist der Bon ganz mit Gutschein bezahlt, steht statt des Rückgelds "Mit
/// Gutschein bezahlt" (`paid-by-voucher`); die Lade ist zu. Je
/// Gutschein-Zahlung steht darunter eine Reihe `voucher-left-<n>` mit dem
/// Code und dem, was am Gutschein bleibt.
///
/// Ist "Rechnung an Firma" an und der Bon kein Testbon, steht darunter die
/// Rechnung ([InvoiceBox], über 400 € mit Hinweis); "Rechnung an Firma"
/// öffnet an Stelle der Ansicht das Blatt "Firmenkunde wählen".
class SaleDone extends ConsumerStatefulWidget {
  const SaleDone({super.key, required this.result, required this.onNext});

  final SaleResult result;
  final VoidCallback onNext;

  @override
  ConsumerState<SaleDone> createState() => _SaleDoneState();
}

class _SaleDoneState extends ConsumerState<SaleDone> {
  /// `null`, solange gedruckt wird.
  PrintOutcome? _outcome;

  /// Das letzte Ergebnis des Küchenbons; `null`, solange er läuft oder wenn
  /// keiner fällig ist.
  PrintOutcome? _kitchen;

  /// "Küchenbon drucken" wurde getippt und läuft.
  bool _kitchenAgain = false;

  /// "Küchenbon drucken" wurde schon getippt: erst dann sagt die Zeile auch
  /// "Küchenbon gedruckt.".
  bool _kitchenRetried = false;

  /// Der letzte Küchenbon dieses Verkaufs (der erste oder ein Nachdruck).
  late Future<PrintOutcome?> _currentKitchen;

  /// Übernimmt beim Weggehen den Küchenbon; beim Aufräumen darf das Widget
  /// `ref` nicht mehr lesen.
  late final LateKitchen _late;

  /// Je verkauftem Gutschein das letzte Ergebnis seines Abschnitts; `null`,
  /// solange keiner gedruckt ist oder er gerade druckt.
  late final List<PrintOutcome?> _voucherOutcomes = List.filled(
    widget.result.receipt.soldVouchers.length,
    null,
  );

  /// Die Gutscheine, deren "Gutschein drucken" gerade läuft.
  final Set<int> _voucherPrinting = {};

  /// "Rechnung an Firma" ist getippt: an Stelle der Ansicht steht das Blatt
  /// "Firmenkunde wählen".
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _late = ref.read(lateKitchenProvider.notifier);
    _await(widget.result.print);
    _awaitKitchen(widget.result.kitchen);
    widget.result.voucherPrints.then((outcomes) {
      if (!mounted) return;
      setState(() {
        for (final (i, o) in outcomes.indexed) {
          if (i < _voucherOutcomes.length && !_voucherPrinting.contains(i)) {
            _voucherOutcomes[i] = o;
          }
        }
      });
    }, onError: (Object _) {});
  }

  Future<void> _printVoucher(int index, SoldVoucher voucher) async {
    if (_voucherPrinting.contains(index)) return;
    setState(() {
      _voucherPrinting.add(index);
      _voucherOutcomes[index] = null;
    });
    final outcome = await ref
        .read(saleServiceProvider)
        .printVoucher(widget.result.receipt, voucher);
    if (!mounted) return;
    setState(() {
      _voucherPrinting.remove(index);
      _voucherOutcomes[index] = outcome;
    });
  }

  @override
  void dispose() {
    // Gedruckt oder keiner fällig: nichts. Läuft er noch oder ist er
    // gescheitert, steht er danach über dem Bon der Kassa.
    _late.follow(widget.result.receipt, _currentKitchen);
    super.dispose();
  }

  void _awaitKitchen(Future<PrintOutcome?> kitchen) {
    _currentKitchen = kitchen;
    kitchen.then(
      (outcome) {
        if (!mounted) return;
        setState(() {
          _kitchen = outcome;
          _kitchenAgain = false;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _kitchen = const PrintOutcome.failed(PrintProblem.unreachable);
          _kitchenAgain = false;
        });
      },
    );
  }

  void _reprintKitchen() {
    if (_kitchenAgain) return;
    setState(() {
      _kitchenAgain = true;
      _kitchenRetried = true;
    });
    _awaitKitchen(
      ref.read(kitchenServiceProvider).printFor(widget.result.receipt),
    );
  }

  void _await(Future<PrintOutcome> print) {
    print.then((outcome) {
      if (mounted) setState(() => _outcome = outcome);
    });
  }

  void _reprint() {
    setState(() => _outcome = null);
    _await(ref.read(saleServiceProvider).printAgain(widget.result.receipt));
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final settings =
        ref.watch(settingsStreamProvider).value ?? const RegisterSettings();
    final drawer = settings.cashDrawerEnabled;
    final number = widget.result.receipt.number;
    // Ein Verkauf hat immer eine Zahlung, nur Sonderbelege haben keine.
    final receipt = widget.result.receipt;
    final card = receipt.cardPayment;
    final changeCents = receipt.cashPayment?.changeCents ?? 0;
    // Eine Auszahlung: die Bar-Zahlung liegt unter 0.
    final payoutCents = -(receipt.cashPayment?.amountCents ?? 0);
    final voucherPayments = [
      for (final p in receipt.payments)
        if (p.kind == PaymentKind.voucher) p,
    ];
    // Nur Gutscheine, weder bar noch Karte.
    final onlyVoucher =
        voucherPayments.isNotEmpty &&
        card == null &&
        receipt.cashPayment == null;
    final outcome = _outcome;
    final showPrint =
        settings.printerKind != PrinterKind.none &&
        outcome?.problem != PrintProblem.notSetUp;
    final invoice = showsInvoice(settings, receipt);
    if (_picking && invoice) {
      return PayColumnFrame(
        child: CustomerPicker(
          receipt: receipt,
          onChosen: () => setState(() => _picking = false),
          onClose: () => setState(() => _picking = false),
        ),
      );
    }
    return PayColumnFrame(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
              child: Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: c.green,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.check,
                          size: 34,
                          color: c.onAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l.kassaPaid,
                      style: text.headlineLarge!.copyWith(fontSize: 30),
                    ),
                    const SizedBox(height: KassaTokens.spaceXs),
                    Text(
                      l.kassaReceiptNumber(number),
                      key: const Key('receipt-number'),
                      style: text.bodyLarge!.copyWith(
                        fontWeight: FontWeight.w400,
                        color: c.ink2,
                      ),
                    ),
                    if (showPrint) ...[
                      const SizedBox(height: KassaTokens.spaceMd),
                      _PrintState(outcome: outcome, onReprint: _reprint),
                    ],
                    // Gescheitert immer, auch ohne Küchendrucker: sonst
                    // käme nie ein Küchenbon, ohne dass es jemand merkt.
                    if (_kitchen case final kitchen?
                        when !kitchen.ok || _kitchenRetried) ...[
                      const SizedBox(height: KassaTokens.spaceMd),
                      KitchenStateBox(
                        outcome: kitchen,
                        mode: settings.kitchenMode,
                        printing: _kitchenAgain,
                        onReprint: _reprintKitchen,
                      ),
                    ],
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.accentSoft,
                        borderRadius: BorderRadius.circular(
                          KassaTokens.radiusXxl,
                        ),
                      ),
                      child: card != null
                          ? _CardPaid(
                              scheme: card.cardScheme,
                              last4: card.cardLast4,
                              tipCents: card.tipCents,
                              cashPartCents: receipt.cashCents,
                            )
                          : onlyVoucher
                          ? Text(
                              l.kassaPaidByVoucher,
                              key: const Key('paid-by-voucher'),
                              style: text.titleLarge!.copyWith(
                                color: c.accentInk,
                              ),
                            )
                          : payoutCents > 0
                          ? _BigAmount(
                              label: l.kassaPayOutDone,
                              cents: payoutCents,
                              amountKey: const Key('payout-done'),
                            )
                          : changeCents == 0
                          ? Text(
                              l.kassaPaidExact,
                              style: text.titleLarge!.copyWith(
                                color: c.accentInk,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  drawer
                                      ? l.kassaGiveChangeFromDrawer
                                      : l.kassaGiveChange,
                                  style: text.bodyLarge!.copyWith(
                                    color: c.accentInk,
                                  ),
                                ),
                                const SizedBox(height: KassaTokens.spaceXs),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Ltr(
                                    child: Text(
                                      formatEuro(changeCents),
                                      key: const Key('change-done'),
                                      maxLines: 1,
                                      style: text.displayLarge!.copyWith(
                                        color: c.ink,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    for (final (i, p) in voucherPayments.indexed) ...[
                      const SizedBox(height: KassaTokens.spaceMd),
                      _VoucherLeftRow(index: i, payment: p),
                    ],
                    for (final (i, v) in receipt.soldVouchers.indexed) ...[
                      const SizedBox(height: KassaTokens.spaceXl),
                      _SoldVoucherRow(
                        index: i,
                        voucher: v,
                        canPrint: settings.printerKind != PrinterKind.none,
                        printing: _voucherPrinting.contains(i),
                        outcome: _voucherOutcomes[i],
                        onPrint: () => _printVoucher(i, v),
                      ),
                    ],
                    if (invoice) ...[
                      const SizedBox(height: KassaTokens.spaceXl),
                      InvoiceBox(
                        receipt: receipt,
                        showHint: true,
                        onPick: () => setState(() => _picking = true),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: PrimaryButton(
              key: const Key('next-customer'),
              label: l.kassaNextCustomer,
              filled: false,
              solid: true,
              height: KassaTokens.mainActionHeight,
              onPressed: widget.onNext,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ein verkaufter Gutschein in "Verkauf fertig": "Gutschein" mit dem Wert,
/// darunter groß der Code; mit [canPrint] "Gutschein drucken", über der Taste
/// der Grund, wenn der letzte Abschnitt gescheitert ist.
class _SoldVoucherRow extends StatelessWidget {
  const _SoldVoucherRow({
    required this.index,
    required this.voucher,
    required this.canPrint,
    required this.printing,
    required this.outcome,
    required this.onPrint,
  });

  final int index;
  final SoldVoucher voucher;
  final bool canPrint;
  final bool printing;
  final PrintOutcome? outcome;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final problem = outcome?.problem;
    final tabular = const [FontFeature.tabularFigures()];
    return Container(
      key: Key('sold-voucher-$index'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: problem == null ? c.card : c.warnBg,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
        border: Border.all(
          color: problem == null ? c.line : c.warnBg,
          width: KassaTokens.borderButton,
        ),
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
                  style: text.bodyLarge!.copyWith(color: c.accentInk),
                ),
              ),
              const SizedBox(width: KassaTokens.spaceMd),
              Ltr(
                child: Text(
                  formatEuro(voucher.valueCents),
                  maxLines: 1,
                  style: text.titleLarge!.copyWith(fontFeatures: tabular),
                ),
              ),
            ],
          ),
          const SizedBox(height: KassaTokens.spaceXs),
          Text(
            l.voucherCode,
            style: text.bodySmall!.copyWith(
              fontWeight: FontWeight.w600,
              color: c.ink2,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Ltr(
              child: Text(
                formatVoucherCode(voucher.code),
                key: Key('sold-voucher-code-$index'),
                maxLines: 1,
                style: text.displayLarge!.copyWith(
                  fontSize: 34,
                  letterSpacing: 1.5,
                  color: c.ink,
                  fontFeatures: tabular,
                ),
              ),
            ),
          ),
          if (problem != null) ...[
            const SizedBox(height: KassaTokens.spaceSm),
            Semantics(
              liveRegion: true,
              child: Text(
                printProblemText(l, problem),
                key: Key('sold-voucher-problem-$index'),
                style: text.bodyLarge!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.warnInk,
                ),
              ),
            ),
          ],
          if (canPrint) ...[
            const SizedBox(height: KassaTokens.spaceMd),
            PrimaryButton(
              key: Key('sold-voucher-print-$index'),
              label: l.voucherPrint,
              icon: LucideIcons.printer,
              filled: false,
              height: 64,
              onPressed: printing ? null : onPrint,
            ),
          ],
        ],
      ),
    );
  }
}

/// Eine Gutschein-Zahlung in "Verkauf fertig": "Gutschein 1234 5678" und
/// "Bleibt am Gutschein" mit dem Guthaben nach diesem Bon.
class _VoucherLeftRow extends StatelessWidget {
  const _VoucherLeftRow({required this.index, required this.payment});

  final int index;
  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final tabular = const [FontFeature.tabularFigures()];
    return Container(
      key: Key('voucher-left-$index'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
        border: Border.all(color: c.line, width: KassaTokens.borderButton),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.voucherWithCode(
              ltrIsolate(context, formatVoucherCode(payment.voucherCode ?? '')),
            ),
            style: text.bodyLarge!.copyWith(
              color: c.accentInk,
              fontFeatures: tabular,
            ),
          ),
          const SizedBox(height: KassaTokens.spaceXs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  l.voucherLeft,
                  style: text.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: KassaTokens.spaceMd),
              Ltr(
                child: Text(
                  formatEuro(payment.voucherBalanceAfterCents ?? 0),
                  key: Key('voucher-left-amount-$index'),
                  maxLines: 1,
                  style: text.titleLarge!.copyWith(fontFeatures: tabular),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ein Satz und darunter groß ein Betrag, etwa "Auszahlen" und "0,75 €".
class _BigAmount extends StatelessWidget {
  const _BigAmount({
    required this.label,
    required this.cents,
    required this.amountKey,
  });

  final String label;
  final int cents;
  final Key amountKey;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.bodyLarge!.copyWith(color: c.accentInk)),
        const SizedBox(height: KassaTokens.spaceXs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Ltr(
            child: Text(
              formatEuro(cents),
              key: amountKey,
              maxLines: 1,
              style: text.displayLarge!.copyWith(
                color: c.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Mit Karte bezahlt", darunter mit Bar-Teil "Bar-Teil 5,00 €", mit
/// Trinkgeld "davon Trinkgeld 0,35 €" und z. B. "VISA **** 4242" (was fehlt,
/// entfällt).
class _CardPaid extends StatelessWidget {
  const _CardPaid({
    required this.scheme,
    required this.last4,
    required this.tipCents,
    required this.cashPartCents,
  });

  final String? scheme;
  final String? last4;
  final int tipCents;
  final int cashPartCents;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final digits = last4 == null || last4!.isEmpty ? null : '**** $last4';
    final detail = [
      if (scheme != null && scheme!.isNotEmpty) scheme!,
      ?digits,
    ].join(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          L10n.of(context).kassaPaidByCard,
          key: const Key('paid-by-card'),
          style: text.titleLarge!.copyWith(color: c.accentInk),
        ),
        if (cashPartCents > 0) ...[
          const SizedBox(height: KassaTokens.spaceXs),
          Text(
            L10n.of(
              context,
            ).kassaCashPartDone(ltrIsolate(context, formatEuro(cashPartCents))),
            key: const Key('cash-part-done'),
            style: text.bodyLarge!.copyWith(color: c.accentInk),
          ),
        ],
        if (tipCents > 0) ...[
          const SizedBox(height: KassaTokens.spaceXs),
          Text(
            L10n.of(context)
                .kassaTipDone(ltrIsolate(context, formatEuro(tipCents))),
            key: const Key('tip-done'),
            style: text.bodyLarge!.copyWith(color: c.accentInk),
          ),
        ],
        if (detail.isNotEmpty) ...[
          const SizedBox(height: KassaTokens.spaceXs),
          // "VISA **** 4242" wie auf der Karte.
          Ltr(
            child: Text(
              detail,
              key: const Key('card-detail'),
              style: text.bodyLarge!.copyWith(color: c.ink),
            ),
          ),
        ],
      ],
    );
  }
}

/// Die Zeile unter der Bon-Nummer: "Bon wird gedruckt …", "Bon gedruckt" oder
/// die Meldung des Druckers in `warnBg` mit "Nochmal drucken".
class _PrintState extends StatelessWidget {
  const _PrintState({required this.outcome, required this.onReprint});

  /// `null`, solange gedruckt wird.
  final PrintOutcome? outcome;
  final VoidCallback onReprint;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final line = text.bodyLarge!.copyWith(
      fontWeight: FontWeight.w600,
      color: c.ink2,
    );
    final l = L10n.of(context);
    final o = outcome;
    if (o == null) {
      return Text(l.kassaPrinting, key: const Key('print-state'), style: line);
    }
    if (o.ok) {
      return Text(l.kassaPrinted, key: const Key('print-state'), style: line);
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.warnBg,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            printProblemText(l, o.problem!),
            key: const Key('print-state'),
            style: text.bodyLarge!.copyWith(
              fontWeight: FontWeight.w700,
              color: c.warnInk,
            ),
          ),
          const SizedBox(height: KassaTokens.spaceMd),
          PrimaryButton(
            key: const Key('reprint'),
            label: l.kassaPrintAgain,
            icon: LucideIcons.printer,
            filled: false,
            height: 64,
            onPressed: onReprint,
          ),
        ],
      ),
    );
  }
}

/// Der Küchenbon nach dem Verkauf (und nach einem Storno im Bon-Detail):
/// gescheitert die Zeile "Küchenbon nicht gedruckt" mit der Meldung des
/// Druckers in `warnBg` und "Küchenbon drucken"; nach einem Nachdruck, der
/// geklappt hat, "Küchenbon gedruckt.". [boxKey] und [reprintKey] sind die
/// Schlüssel des Ganzen und der Taste.
class KitchenStateBox extends StatelessWidget {
  const KitchenStateBox({
    super.key,
    required this.outcome,
    required this.mode,
    required this.printing,
    required this.onReprint,
    this.boxKey = const Key('kitchen-state'),
    this.reprintKey = const Key('kitchen-reprint'),
  });

  final Key boxKey;
  final Key reprintKey;

  final PrintOutcome outcome;

  /// Der Ort des Küchenbons: ohne Küchendrucker sagt die Meldung "Kein
  /// Küchendrucker", nicht "Kein Bondrucker".
  final KitchenMode mode;

  /// Der Nachdruck läuft: die Taste sagt es und nimmt keinen Tipp an.
  final bool printing;
  final VoidCallback onReprint;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final problem = outcome.problem;
    if (problem == null) {
      return Text(
        l.kassaKitchenPrinted,
        key: boxKey,
        style: text.bodyLarge!.copyWith(
          fontWeight: FontWeight.w600,
          color: c.ink2,
        ),
      );
    }
    return Container(
      key: boxKey,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.warnBg,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.kassaKitchenNotPrinted,
            style: text.bodyLarge!.copyWith(
              fontWeight: FontWeight.w800,
              color: c.warnInk,
            ),
          ),
          const SizedBox(height: KassaTokens.spaceXxs),
          Text(
            kitchenProblemText(l, problem, mode),
            style: text.bodyLarge!.copyWith(
              fontWeight: FontWeight.w600,
              color: c.warnInk,
            ),
          ),
          const SizedBox(height: KassaTokens.spaceMd),
          PrimaryButton(
            key: reprintKey,
            label: printing ? l.kassaKitchenPrinting : l.kassaKitchenPrint,
            icon: LucideIcons.printer,
            filled: false,
            height: 64,
            onPressed: printing ? null : onReprint,
          ),
        ],
      ),
    );
  }
}
