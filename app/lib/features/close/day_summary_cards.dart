import 'package:material_ui/material_ui.dart';

import '../../domain/day.dart';
import '../../ui/tokens.dart';
import 'drawer_card.dart';
import 'income_card.dart';

/// Die linke Seite des Abschlusses: Karte "Einnahmen | Steuer" und Karte
/// "Geldlade" (oder "Bargeld"). Zeigt den offenen Tag oder, nach dem
/// Abschluss, den letzten abgeschlossenen. Die Tasten für Einlage und Entnahme
/// gibt es nur am offenen Tag, die gewählte ist hervorgehoben.
class DaySummaryCards extends StatelessWidget {
  const DaySummaryCards({
    super.key,
    required this.summary,
    required this.drawer,
    required this.movement,
    required this.canMove,
    required this.onCashIn,
    required this.onCashOut,
  });

  final DaySummary summary;
  final bool drawer;

  /// Die Tasten für Einlage und Entnahme: nur am offenen Tag, dessen
  /// Wechselgeld bekannt ist.
  final bool canMove;

  /// Welches Formular offen ist, falls eines.
  final CashMovementKind? movement;
  final VoidCallback onCashIn;
  final VoidCallback onCashOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IncomeCard(IncomeFigures.ofDay(summary)),
        const SizedBox(height: KassaTokens.spaceXxl),
        DrawerCard(
          summary: summary,
          drawer: drawer,
          movement: movement,
          canMove: canMove,
          onCashIn: onCashIn,
          onCashOut: onCashOut,
        ),
      ],
    );
  }
}
