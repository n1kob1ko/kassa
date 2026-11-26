// Ein Küchenbon, der gescheitert ist, nachdem "Verkauf fertig" schon weg war
// ("Nächster Kunde" vor dem Ergebnis, eine bestätigte unklare
// Kartenzahlung): ein Hinweis über dem Bon der Kassa, bis jemand ihn druckt
// oder ausblendet. Sonst käme in der Küche nichts an, ohne dass es jemand
// merkt.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../devices/printer.dart';
import '../../domain/receipt.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/print_problem_text.dart';
import '../../ui/tokens.dart';
import 'kitchen_service.dart';

/// Ein Küchenbon, der nicht gedruckt ist.
class LateKitchenTicket {
  const LateKitchenTicket({
    required this.receipt,
    required this.problem,
    this.printing = false,
  });

  final Receipt receipt;
  final PrintProblem problem;

  /// "Küchenbon drucken" läuft.
  final bool printing;
}

/// Die Küchenbons, die nicht gedruckt sind, der älteste zuerst. Keiner geht
/// verloren: der Hinweis zeigt den neuesten und zählt die übrigen.
class LateKitchen extends Notifier<List<LateKitchenTicket>> {
  @override
  List<LateKitchenTicket> build() => const [];

  /// Wartet auf [kitchen], den Küchenbon zu [receipt]; scheitert er, kommt
  /// er in den Hinweis. Ist kein Küchenbon fällig (`null`) oder ist er
  /// gedruckt, geschieht nichts. Wirft nie.
  void follow(Receipt receipt, Future<PrintOutcome?> kitchen) {
    kitchen.then((outcome) {
      if (outcome != null && !outcome.ok) _add(receipt, outcome.problem!);
    }, onError: (Object _) => _add(receipt, PrintProblem.unreachable));
  }

  void _add(Receipt receipt, PrintProblem problem) {
    if (!ref.mounted) return;
    state = [
      for (final t in state)
        if (t.receipt.id != receipt.id) t,
      LateKitchenTicket(receipt: receipt, problem: problem),
    ];
  }

  /// Nimmt den Hinweis zu diesem Bon weg, ohne zu drucken.
  void dismiss(String receiptId) => state = [
    for (final t in state)
      if (t.receipt.id != receiptId) t,
  ];

  /// Druckt den Küchenbon noch einmal. Gedruckt (oder nichts mehr für die
  /// Küche): der Hinweis geht. Gescheitert: er bleibt mit dem neuen Grund.
  /// Ist der Verkauf inzwischen storniert, geht der Hinweis ohne Druck.
  Future<void> reprint(String receiptId) async {
    final ticket = state.where((t) => t.receipt.id == receiptId).firstOrNull;
    if (ticket == null || ticket.printing) return;
    _replace(
      LateKitchenTicket(
        receipt: ticket.receipt,
        problem: ticket.problem,
        printing: true,
      ),
    );
    PrintOutcome? outcome;
    try {
      // Der Bon, wie er jetzt ist: inzwischen storniert, käme eine abgesagte
      // Bestellung noch einmal in die Küche. Dann geht nur der Hinweis weg.
      Receipt current;
      try {
        current = await ref
            .read(receiptRepositoryProvider)
            .byId(ticket.receipt.id);
      } catch (_) {
        current = ticket.receipt;
      }
      if (!ref.mounted) return;
      if (current.isVoided) {
        dismiss(receiptId);
        return;
      }
      outcome = await ref.read(kitchenServiceProvider).printFor(current);
    } catch (_) {
      outcome = const PrintOutcome.failed(PrintProblem.unreachable);
    }
    if (!ref.mounted) return;
    if (outcome == null || outcome.ok) {
      dismiss(receiptId);
    } else {
      _replace(
        LateKitchenTicket(receipt: ticket.receipt, problem: outcome.problem!),
      );
    }
  }

  void _replace(LateKitchenTicket ticket) => state = [
    for (final t in state)
      if (t.receipt.id == ticket.receipt.id) ticket else t,
  ];
}

final lateKitchenProvider =
    NotifierProvider<LateKitchen, List<LateKitchenTicket>>(LateKitchen.new);

/// Der Hinweis über dem Bon der Kassa (`late-kitchen`): "Küchenbon nicht
/// gedruckt", die Bon-Nummer, der Grund in der Bediensprache, gibt es
/// mehrere, wie viele weitere; darunter "Küchenbon drucken" (64 dp, ganze
/// Breite), oben in der Ecke "Ausblenden" (ein Kreuz, 48 dp). Ohne gescheiterten Küchenbon ist er nicht da. Er erscheint
/// und geht mit einer kurzen Größenänderung (ohne bei "Bewegung reduzieren").
class LateKitchenNotice extends ConsumerWidget {
  const LateKitchenNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(lateKitchenProvider);
    final still = MediaQuery.disableAnimationsOf(context);
    return AnimatedSize(
      duration: still ? Duration.zero : KassaTokens.motionFade,
      curve: KassaTokens.motionCurve,
      alignment: AlignmentDirectional.topCenter,
      child: tickets.isEmpty
          ? const SizedBox(width: double.infinity)
          : _Notice(ticket: tickets.last, more: tickets.length - 1),
    );
  }
}

class _Notice extends ConsumerWidget {
  const _Notice({required this.ticket, required this.more});

  final LateKitchenTicket ticket;

  /// Weitere Küchenbons, die nicht gedruckt sind.
  final int more;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final mode =
        (ref.watch(settingsStreamProvider).value ?? const RegisterSettings())
            .kitchenMode;
    final notifier = ref.read(lateKitchenProvider.notifier);
    final id = ticket.receipt.id;
    final line = text.bodyLarge!.copyWith(
      fontWeight: FontWeight.w600,
      color: c.warnInk,
    );
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('late-kitchen'),
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.warnBg,
          borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                        l.kassaReceiptNumber(ticket.receipt.number),
                        style: line,
                      ),
                    ],
                  ),
                ),
                // Ausblenden: klein in der Ecke, die Hauptsache ist drucken.
                Pressable(
                  key: const Key('late-kitchen-dismiss'),
                  onTap: ticket.printing ? null : () => notifier.dismiss(id),
                  semanticLabel: l.kassaKitchenDismiss,
                  child: SizedBox.square(
                    dimension: KassaTokens.minTap,
                    child: Icon(LucideIcons.x, size: 22, color: c.warnInk),
                  ),
                ),
              ],
            ),
            Text(kitchenProblemText(l, ticket.problem, mode), style: line),
            if (more > 0) ...[
              const SizedBox(height: KassaTokens.spaceXs),
              Text(l.kassaKitchenLateMore(more), style: line),
            ],
            const SizedBox(height: KassaTokens.spaceMd),
            PrimaryButton(
              key: const Key('late-kitchen-reprint'),
              label: ticket.printing
                  ? l.kassaKitchenPrinting
                  : l.kassaKitchenPrint,
              icon: LucideIcons.printer,
              filled: false,
              height: 64,
              onPressed: ticket.printing ? null : () => notifier.reprint(id),
            ),
          ],
        ),
      ),
    );
  }
}
