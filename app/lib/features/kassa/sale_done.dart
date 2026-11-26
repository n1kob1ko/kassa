import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_language.dart';
import '../../core/money.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../devices/printer.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/ltr.dart';
import '../../ui/primary_button.dart';
import '../../ui/print_problem_text.dart';
import '../../ui/tokens.dart';
import 'cash_sheet.dart';
import 'kitchen_service.dart';
import 'late_kitchen.dart';
import 'sale_service.dart';

/// Nach dem Bezahlen: "Bezahlt", die Bon-Nummer, der Stand des Druckens und
/// das Rückgeld, das die Person jetzt herausgibt. Bei einer Kartenzahlung steht
/// statt des Rückgelds "Mit Karte bezahlt" und, was bekannt ist, Kartenart und
/// die letzten vier Ziffern. "Nächster Kunde" führt zur
/// leeren Kassa zurück und ist immer sofort aktiv, auch während des Druckens.
/// Scheitert der Küchenbon, steht unter dem Druckzustand "Küchenbon nicht
/// gedruckt" mit der Meldung des Druckers und "Küchenbon drucken"; auf ihn
/// wird nie gewartet. Geht die Ansicht weg ("Nächster Kunde"), übernimmt der
/// Hinweis über dem Bon ([LateKitchenNotice]) einen Küchenbon, der noch läuft
/// oder gescheitert ist.
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

  @override
  void initState() {
    super.initState();
    _late = ref.read(lateKitchenProvider.notifier);
    _await(widget.result.print);
    _awaitKitchen(widget.result.kitchen);
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
