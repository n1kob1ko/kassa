// Zählt Verkäufe und Stornos mit ihren Zahlungen zusammen: für den
// Tagesabschluss und die Monatsabrechnung, nach denselben Regeln wie der
// Server.

import '../domain/day.dart' show StaffTip;
import '../domain/receipt.dart';
import 'database.dart';

/// Ein Verkauf zählt eins hoch, ein Storno eins herunter; die Beträge eines
/// Stornos stehen schon mit Minus in der Datenbank. Der Aufrufer gibt nur
/// Verkäufe und Stornos hinein, Sonderbelege nicht.
class ReceiptTally {
  /// Verkaufs-Bons minus Storno-Bons.
  int count = 0;

  /// Bons mit mindestens einer Zahlung bar bzw. mit Karte. Ein gemischter
  /// Bon zählt bei beiden, in [count] einmal.
  int cashCount = 0;
  int cardCount = 0;

  /// Anzahl der Storno-Bons und Summe der stornierten Bons (positiv).
  int voidCount = 0;
  int voidedCents = 0;

  /// Summe der Bons mit Pfand, ohne Trinkgeld.
  int revenueCents = 0;

  /// Summe der Zahlungen bar bzw. mit Karte, ohne Trinkgeld.
  int cashCents = 0;
  int cardCents = 0;
  int depositCents = 0;

  /// Bons mit Rabatt und die Summe ihrer Rabatte.
  int discountCount = 0;
  int discountCents = 0;

  /// Trinkgeld der Kartenzahlungen.
  int cardTipCents = 0;

  /// Kleinste und größte Nummer, `null` ohne Bon.
  int? firstNumber;
  int? lastNumber;

  final Map<String, _Tip> _tips = {};

  void add(ReceiptRow r, Iterable<PaymentRow> payments) {
    final n = r.number;
    if (firstNumber == null || n < firstNumber!) firstNumber = n;
    if (lastNumber == null || n > lastNumber!) lastNumber = n;
    final isVoid = r.kind == ReceiptKind.voided.name;
    final step = isVoid ? -1 : 1;
    count += step;
    if (isVoid) {
      voidCount++;
      voidedCents -= r.totalCents;
    }
    revenueCents += r.totalCents;
    depositCents += r.depositCents;
    if (r.discountCents != 0) discountCount += step;
    discountCents += r.discountCents;
    // Bar und Karte aus den Zahlungen, ohne Trinkgeld. Ein gemischter Bon
    // zählt bei beiden Arten.
    var hasCash = false;
    var hasCard = false;
    for (final p in payments) {
      if (p.kind == PaymentKind.cash.name) {
        cashCents += p.amountCents;
        hasCash = true;
      } else if (p.kind == PaymentKind.card.name) {
        cardCents += p.amountCents;
        hasCard = true;
        cardTipCents += p.tipCents;
        if (p.tipCents != 0) _addTip(r, p);
      }
    }
    if (hasCash) cashCount += step;
    if (hasCard) cardCount += step;
  }

  /// Je Person nach `tip_staff_id`. Der Name ist der der spätesten Zahlung
  /// (nach Zeit, dann Id des Bons, wie am Server).
  void _addTip(ReceiptRow r, PaymentRow p) {
    final id = p.tipStaffId ?? '';
    final old = _tips[id];
    final cents = (old?.cents ?? 0) + p.tipCents;
    if (old == null ||
        r.createdAt.isAfter(old.at) ||
        (r.createdAt == old.at && r.id.compareTo(old.receiptId) > 0)) {
      _tips[id] = _Tip(
        cents: cents,
        name: p.tipStaffName ?? '',
        at: r.createdAt,
        receiptId: r.id,
      );
    } else {
      _tips[id] = _Tip(
        cents: cents,
        name: old.name,
        at: old.at,
        receiptId: old.receiptId,
      );
    }
  }

  /// Karten-Trinkgeld je Person, nach Name (bei gleichem Namen nach Betrag);
  /// Personen mit 0 fehlen.
  List<StaffTip> get tipsByStaff =>
      [
        for (final e in _tips.entries)
          if (e.value.cents != 0)
            StaffTip(
              staffId: e.key,
              staffName: e.value.name,
              cents: e.value.cents,
            ),
      ]..sort((a, b) {
        final n = a.staffName.compareTo(b.staffName);
        return n != 0 ? n : a.cents.compareTo(b.cents);
      });
}

class _Tip {
  const _Tip({
    required this.cents,
    required this.name,
    required this.at,
    required this.receiptId,
  });

  final int cents;
  final String name;
  final DateTime at;
  final String receiptId;
}
