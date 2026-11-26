import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/receipt.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/ltr.dart';
import '../../ui/pressable.dart';
import '../../ui/tokens.dart';

/// Welche Bons die Liste zeigt.
enum BonFilter {
  all('alle'),
  cash('bar'),
  card('karte'),
  voided('storniert');

  const BonFilter(this.id);

  /// Teil der Schlüssel `filter-<id>`, in jeder Sprache gleich.
  final String id;

  String label(L10n l) => switch (this) {
    BonFilter.all => l.bonsFilterAll,
    BonFilter.cash => l.bonsCash,
    BonFilter.card => l.bonsCard,
    BonFilter.voided => l.bonsVoided,
  };

  /// "Bar" und "Karte" zeigen Verkäufe dieser Zahlung, die nicht storniert
  /// sind. "Storniert" zeigt stornierte Bons und Storno-Bons. Sonderbelege
  /// stehen nur unter "Alle".
  bool matches(Receipt r) {
    switch (this) {
      case BonFilter.all:
        return true;
      case BonFilter.cash:
        return _isLiveSale(r) && r.cashPayment != null;
      case BonFilter.card:
        return _isLiveSale(r) && r.cardPayment != null;
      case BonFilter.voided:
        return r.isVoided || r.kind == ReceiptKind.voided;
    }
  }

  static bool _isLiveSale(Receipt r) =>
      r.kind == ReceiptKind.sale && !r.isVoided;
}

/// "11:05"
String receiptTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Zahl mit echtem Minuszeichen, wie [formatEuro] es schreibt.
String signedCount(int n) => n < 0 ? '−${-n}' : '$n';

/// Die Zeilen einzeilig: "2 × Cola, Pommes". Die Namen sind die des
/// gespeicherten Bons, wie er gedruckt wurde.
String receiptSummary(BuildContext context, Receipt r) => [
  for (final line in r.lines)
    line.quantity.abs() > 1
        ? '${line.quantity.abs()} × ${nameIsolateIn(context, line.name)}'
        : nameIsolateIn(context, line.name),
].join(L10n.of(context).uiListSeparator);

/// Bezeichnung eines Sonderbelegs am Bildschirm, sonst `null`
/// ([ReceiptKindX.specialTitle] bleibt die deutsche Fassung des Zettels).
String? specialTitleText(L10n l, ReceiptKind kind) => switch (kind) {
  ReceiptKind.sale || ReceiptKind.voided => null,
  ReceiptKind.start => l.bonsKindStart,
  ReceiptKind.month => l.bonsKindMonth,
  ReceiptKind.year => l.bonsKindYear,
  ReceiptKind.zero => l.bonsKindZero,
  ReceiptKind.collective => l.bonsKindCollective,
  ReceiptKind.closing => l.bonsKindClosing,
};

/// Was die Pille zeigt: "Storno" (Storno-Bon), "Storniert", die Bezeichnung
/// eines Sonderbelegs oder die Zahlung.
String receiptPillLabel(L10n l, Receipt r) {
  if (r.kind == ReceiptKind.voided) return l.bonsVoidReceipt;
  if (r.isVoided) return l.bonsVoided;
  final special = specialTitleText(l, r.kind);
  if (special != null) return special;
  return r.paymentKind == ReceiptPaymentKind.cash ? l.bonsCash : l.bonsCard;
}

/// Status-Pille: Zahlungsart ruhig, Storno und Storniert in Rot, die
/// Bezeichnung eines Sonderbelegs in der Akzentfarbe.
class ReceiptPill extends StatelessWidget {
  const ReceiptPill(this.receipt, {super.key});

  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final red = receipt.kind == ReceiptKind.voided || receipt.isVoided;
    final special = receipt.kind.isSpecial;
    final (bg, fg) = red
        ? (c.spicyBg, c.spicyFg)
        : special
        ? (c.accentSoft, c.accentInk)
        : (c.fill, c.ink);
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(KassaTokens.radiusPill),
      ),
      child: Text(
        receiptPillLabel(L10n.of(context), receipt),
        maxLines: 1,
        style: Theme.of(context).textTheme.labelLarge!
            .copyWith(fontSize: 12.5, color: fg),
      ),
    );
  }
}

/// Die Bonliste als Karte. [receipts] kommen schon gefiltert und in der
/// Reihenfolge, in der sie stehen sollen. [emptyText] steht, wenn keine da sind.
class ReceiptList extends StatelessWidget {
  const ReceiptList({
    super.key,
    required this.receipts,
    required this.selectedId,
    required this.onSelect,
    required this.emptyText,
  });

  final List<Receipt> receipts;
  final String? selectedId;
  final ValueChanged<Receipt> onSelect;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final radius = BorderRadius.circular(KassaTokens.radiusCard);
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: radius,
        border: Border.all(color: c.line, width: KassaTokens.borderThin),
        boxShadow: c.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: receipts.isEmpty
            ? Align(
                alignment: AlignmentDirectional.topStart,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 28,
                  ),
                  child: Text(
                    emptyText,
                    style: Theme.of(context).textTheme.bodyMedium!
                        .copyWith(fontWeight: FontWeight.w600, color: c.ink2),
                  ),
                ),
              )
            : ListView.builder(
                key: const Key('receipt-list'),
                itemCount: receipts.length,
                itemBuilder: (context, i) {
                  final r = receipts[i];
                  return _ReceiptRow(
                    key: Key('receipt-${r.number}'),
                    receipt: r,
                    selected: r.id == selectedId,
                    onTap: () => onSelect(r),
                  );
                },
              ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    super.key,
    required this.receipt,
    required this.selected,
    required this.onTap,
  });

  final Receipt receipt;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final struck = receipt.isVoided;
    final ink = struck ? c.ink2 : c.ink;
    const gap = SizedBox(width: 14);
    return Pressable(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: selected ? c.accentSoft : null,
          border: Border(
            bottom: BorderSide(color: c.line, width: KassaTokens.borderThin),
          ),
        ),
        child: Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 58),
              child: Text(
                l.bonsNumberShort(receipt.number),
                maxLines: 1,
                style: text.bodyMedium!.copyWith(
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                ),
              ),
            ),
            gap,
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 46),
              child: Ltr(
                child: Text(
                  receiptTime(receipt.createdAt),
                  maxLines: 1,
                  textAlign: ltrAlign(context, TextAlign.start),
                  style: text.bodyMedium!.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.ink2,
                  ),
                ),
              ),
            ),
            gap,
            Expanded(
              child: Text(
                receiptSummary(context, receipt),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
            ),
            gap,
            ReceiptPill(receipt),
            gap,
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 78),
              child: Ltr(
                child: Text(
                  formatEuro(receipt.totalCents),
                  maxLines: 1,
                  textAlign: ltrAlign(context, TextAlign.end),
                  style: text.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w800,
                    color: ink,
                    decoration: struck ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
