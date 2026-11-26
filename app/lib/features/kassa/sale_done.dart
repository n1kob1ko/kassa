import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../devices/printer.dart';
import '../../domain/receipt.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/primary_button.dart';
import '../../ui/print_problem_text.dart';
import '../../ui/tokens.dart';
import 'cash_sheet.dart';
import 'sale_service.dart';

/// Nach dem Bezahlen: "Bezahlt", die Bon-Nummer, der Stand des Druckens und
/// das Rückgeld, das die Person jetzt herausgibt. Bei einer Kartenzahlung steht
/// statt des Rückgelds "Mit Karte bezahlt" und, was bekannt ist, Kartenart und
/// die letzten vier Ziffern. "Nächster Kunde" führt zur
/// leeren Kassa zurück und ist immer sofort aktiv, auch während des Druckens.
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

  @override
  void initState() {
    super.initState();
    _await(widget.result.print);
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
    final payment = widget.result.receipt.payment;
    final changeCents = payment?.changeCents ?? 0;
    final byCard = payment?.kind == PaymentKind.card;
    final outcome = _outcome;
    final showPrint =
        settings.printerKind != PrinterKind.none &&
        outcome?.problem != PrintProblem.notSetUp;
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
                      alignment: Alignment.centerLeft,
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
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.accentSoft,
                        borderRadius: BorderRadius.circular(
                          KassaTokens.radiusXxl,
                        ),
                      ),
                      child: byCard
                          ? _CardPaid(
                              scheme: payment?.cardScheme,
                              last4: payment?.cardLast4,
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
                                  alignment: Alignment.centerLeft,
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
                              ],
                            ),
                    ),
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

/// "Mit Karte bezahlt", darunter z. B. "VISA **** 4242" (was fehlt, entfällt).
class _CardPaid extends StatelessWidget {
  const _CardPaid({required this.scheme, required this.last4});

  final String? scheme;
  final String? last4;

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
        if (detail.isNotEmpty) ...[
          const SizedBox(height: KassaTokens.spaceXs),
          Text(
            detail,
            key: const Key('card-detail'),
            style: text.bodyLarge!.copyWith(color: c.ink),
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
