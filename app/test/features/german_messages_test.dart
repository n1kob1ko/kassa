// Auf Deutsch sagen die übersetzten Meldungen genau das, was die Kassa vor
// den Sprachen sagte: den deutschen Text der Meldung (`message`).

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/devices/card_terminal.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/features/kassa/kassa_screen.dart';
import 'package:kassa/features/kassa/sale_service.dart';
import 'package:kassa/l10n/generated/l10n.dart';
import 'package:kassa/ui/print_problem_text.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('printProblemText: auf Deutsch genau die Meldung des Druckers', () {
    final de = lookupL10n(const Locale('de'));
    for (final p in PrintProblem.values) {
      expect(
        printProblemText(de, p),
        PrintOutcome.failed(p).message,
        reason: p.name,
      );
    }
  });

  testWidgets('cardSaleFailedText: auf Deutsch genau die Meldung', (t) async {
    late BuildContext context;
    await t.pumpWidget(
      Localizations(
        locale: const Locale('de'),
        delegates: const [L10n.delegate, DefaultWidgetsLocalizations.delegate],
        child: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final cases = [
      const CardSaleFailed(CardSaleProblem.alreadyRunning),
      const CardSaleFailed(CardSaleProblem.emptyCart),
      const CardSaleFailed(CardSaleProblem.belowMinimum, minimumCents: 100),
      const CardSaleFailed(CardSaleProblem.notStarted),
      for (final failure in CardFailure.values)
        CardSaleFailed(CardSaleProblem.terminal, terminal: CardFailed(failure)),
      const CardSaleFailed(
        CardSaleProblem.terminal,
        terminal: CardFailed(CardFailure.other, detail: 'Karte gesperrt'),
      ),
    ];
    for (final f in cases) {
      expect(
        cardSaleFailedText(context, f),
        f.message,
        reason: '${f.problem.name} ${f.terminal?.failure.name ?? ''}',
      );
    }
  });
}
