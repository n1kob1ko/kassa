import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/day.dart';
import '../../ui/pressable.dart';
import '../../ui/tokens.dart';
import '../overview/overview_cards.dart' show OverviewCard;

/// Name eines Grundes, wie er in Tasten und Zeilen steht.
String reasonLabel(CashReason r) => switch (r) {
  CashReason.bank => 'Bank',
  CashReason.purchase => 'Einkauf',
  CashReason.change => 'Wechselgeld',
  CashReason.other => 'Sonstiges',
};

String clockTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} Uhr';

String _bons(int n) => n == 1 ? '1 Bon' : '$n Bons';

/// Betrag mit Vorzeichen: "+1,00 €", "−0,20 €", "0,00 €".
String signedEuro(int cents) =>
    cents > 0 ? '+${formatEuro(cents)}' : formatEuro(cents);

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
        _IncomeCard(summary),
        const SizedBox(height: KassaTokens.spaceXxl),
        _DrawerCard(
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

/// Eine Zeile mit Linie darüber (Mindesthöhe 44): Beschriftung, in der Mitte
/// ein ruhiger Text, rechts der Betrag (mindestens 110 dp breit, damit die
/// Beträge untereinander am selben Rand stehen).
class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    this.middle,
    this.amount,
    this.bold = false,
    this.amountKey,
    this.amountColor,
    this.amountMuted = false,
  });

  final String label;
  final String? middle;
  final String? amount;
  final bool bold;
  final Key? amountKey;
  final Color? amountColor;
  final bool amountMuted;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: text.bodyLarge!.copyWith(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          if (middle != null) ...[
            const SizedBox(width: KassaTokens.spaceMd),
            Text(
              middle!,
              style: text.bodyMedium!.copyWith(
                fontWeight: FontWeight.w600,
                color: c.ink2,
              ),
            ),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: 110),
            child: Text(
              amount ?? '',
              key: amountKey,
              textAlign: TextAlign.end,
              style: text.bodyLarge!.copyWith(
                fontSize: 17,
                fontWeight: amountMuted ? FontWeight.w700 : FontWeight.w800,
                color: amountColor ?? (amountMuted ? c.ink2 : c.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeCard extends StatelessWidget {
  const _IncomeCard(this.s);

  final DaySummary s;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final income = _Section(
      title: 'Einnahmen',
      rows: [
        _Line(
          label: 'Bar',
          middle: _bons(s.cashReceiptCount),
          amount: formatEuro(s.cashRevenueCents),
          amountKey: const Key('income-cash'),
        ),
        _Line(
          label: 'Karte',
          middle: _bons(s.cardReceiptCount),
          amount: formatEuro(s.cardRevenueCents),
          amountKey: const Key('income-card'),
        ),
        _Line(
          label: 'Gesamt',
          middle: _bons(s.receiptCount),
          amount: formatEuro(s.revenueCents),
          bold: true,
          amountKey: const Key('income-total'),
        ),
        if (s.voidCount > 0)
          _Line(
            label: 'Storniert',
            middle: _bons(s.voidCount),
            amount: formatEuro(s.voidedCents),
            amountMuted: true,
            amountKey: const Key('left-voided'),
          ),
      ],
    );
    final tax = _Section(
      title: 'Steuer',
      headers: const ['Umsatz', 'davon MwSt'],
      rows: [
        for (final t in s.taxLines)
          _TaxLine(
            'MwSt ${t.rate.percent} %',
            formatEuro(t.grossCents),
            formatEuro(t.taxCents),
          ),
        if (s.depositCents != 0)
          _TaxLine('Pfand, ohne MwSt', formatEuro(s.depositCents), null),
      ],
    );
    return OverviewCard(
      child: LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth < 640) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                income,
                const SizedBox(height: KassaTokens.spaceHuge),
                tax,
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: income),
                Container(
                  width: KassaTokens.borderThin,
                  margin: const EdgeInsets.symmetric(
                    horizontal: KassaTokens.spaceHuge,
                  ),
                  color: c.line,
                ),
                Expanded(child: tax),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TaxLine extends StatelessWidget {
  const _TaxLine(this.label, this.gross, this.tax);

  final String label;
  final String gross;
  final String? tax;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: text.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 100),
            child: Text(
              gross,
              textAlign: TextAlign.end,
              style: text.bodyMedium!.copyWith(
                fontWeight: FontWeight.w600,
                color: c.ink2,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 96),
            child: Text(
              tax ?? '',
              textAlign: TextAlign.end,
              style: text.bodyLarge!.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Titelzeile (mit Spaltenköpfen) und darunter die Zeilen.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows, this.headers});

  final String title;
  final List<String>? headers;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final head = text.bodySmall!.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: c.ink2,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 40),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text(title, style: text.titleLarge)),
              if (headers != null) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 100),
                  child: Text(headers![0], textAlign: TextAlign.end, style: head),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 96),
                  child: Text(headers![1], textAlign: TextAlign.end, style: head),
                ),
              ],
            ],
          ),
        ),
        ...rows,
      ],
    );
  }
}

class _DrawerCard extends StatelessWidget {
  const _DrawerCard({
    required this.summary,
    required this.drawer,
    required this.movement,
    required this.canMove,
    required this.onCashIn,
    required this.onCashOut,
  });

  final DaySummary summary;
  final bool drawer;
  final bool canMove;
  final CashMovementKind? movement;
  final VoidCallback onCashIn;
  final VoidCallback onCashOut;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final s = summary;
    final day = s.day;
    final closed = !day.isOpen;
    final floatKnown = day.openingFloatCents != null;
    final diff = day.differenceCents;
    return OverviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Text(drawer ? 'Geldlade' : 'Bargeld', style: text.titleLarge),
                if (canMove)
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: KassaTokens.spaceLg,
                      runSpacing: KassaTokens.spaceMd,
                      children: [
                        _MoveButton(
                          key: const Key('cash-in'),
                          label: 'Bargeld einlegen',
                          icon: LucideIcons.plus,
                          open: movement == CashMovementKind.deposit,
                          onTap: onCashIn,
                        ),
                        _MoveButton(
                          key: const Key('cash-out'),
                          label: 'Bargeld entnehmen',
                          icon: LucideIcons.minus,
                          open: movement == CashMovementKind.withdrawal,
                          onTap: onCashOut,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          _Line(
            label: 'Wechselgeld am Morgen',
            amount: floatKnown ? formatEuro(day.openingFloatCents!) : 'Noch offen',
            amountMuted: !floatKnown,
            amountKey: const Key('left-float'),
          ),
          _Line(
            label: 'Bar-Einnahmen',
            amount: formatEuro(s.cashRevenueCents),
            amountKey: const Key('left-cash'),
          ),
          for (final m in s.movements)
            _Line(
              label:
                  '${m.kind == CashMovementKind.deposit ? 'Eingelegt' : 'Entnommen'}: ${reasonLabel(m.reason)}',
              middle: clockTime(m.createdAt),
              amount: formatEuro(
                m.kind == CashMovementKind.deposit
                    ? m.amountCents
                    : -m.amountCents,
              ),
            ),
          _Line(
            label: drawer ? 'Soll in der Lade' : 'Soll in bar',
            amount: formatEuro(s.expectedCashCents),
            bold: true,
            amountKey: const Key('left-expected'),
          ),
          _Line(
            label: 'Gezählt',
            amount: closed ? formatEuro(day.countedCents ?? 0) : 'Noch offen',
            amountMuted: !closed,
            amountKey: const Key('left-counted'),
          ),
          _Line(
            label: 'Unterschied',
            amount: closed && diff != null
                ? (diff == 0 ? formatEuro(0) : signedEuro(diff))
                : null,
            amountColor: diff == 0 ? c.green : c.red,
            amountKey: const Key('left-difference'),
          ),
        ],
      ),
    );
  }
}

class _MoveButton extends StatelessWidget {
  const _MoveButton({
    super.key,
    required this.label,
    required this.icon,
    required this.open,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final fg = open ? c.accentInk : c.ink;
    return Pressable(
      onTap: onTap,
      child: Semantics(
        selected: open,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: open ? c.accentSoft : c.card,
            borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
            border: Border.all(
              color: open ? c.accent : c.line,
              width: KassaTokens.borderButton,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: KassaTokens.spaceLg),
              Text(
                label,
                maxLines: 1,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
