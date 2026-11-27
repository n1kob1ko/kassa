// Rechnung an Firma (Spec 5.3): Firmenkunden, der Empfänger der Rechnung zu
// einem Bon und die Regeln dazu. Reines Dart.

import 'receipt.dart';

/// Über 400,00 € zeigt "Verkauf fertig" einen Hinweis zur Rechnung.
const invoiceHintAboveCents = 40000;

/// Über 10.000,00 € braucht die Rechnung die UID des Kunden.
const invoiceVatIdRequiredAboveCents = 1000000;

/// Höchstlänge von Name und jeder Adress-Zeile, in Zeichen.
const customerTextMax = 80;

/// Höchstlänge der UID, in Zeichen.
const customerVatIdMax = 20;

/// Ein Firmenkunde. [lastUsedAt] ist leer, solange er auf keiner Rechnung
/// stand; eine Verwendung zählt nicht als Änderung ([updatedAt]).
class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.addressLine1,
    required this.addressLine2,
    required this.vatId,
    required this.archived,
    required this.updatedAt,
    required this.lastUsedAt,
  });

  final String id;
  final String name;
  final String addressLine1;
  final String addressLine2;
  final String? vatId;
  final bool archived;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;
}

/// Der Empfänger der Rechnung zu einem Bon, eine Fassung (ab 0). Name,
/// Adresse und UID sind eine Kopie: Ändert sich der Firmenkunde später,
/// bleibt die Rechnung, wie sie war. [customerId] ist leer ohne Firmenkunde.
class ReceiptRecipient {
  const ReceiptRecipient({
    required this.receiptId,
    required this.version,
    required this.customerId,
    required this.name,
    required this.addressLine1,
    required this.addressLine2,
    required this.vatId,
    required this.createdAt,
    required this.staffId,
    required this.staffName,
  });

  final String receiptId;
  final int version;
  final String? customerId;
  final String name;
  final String addressLine1;
  final String addressLine2;
  final String? vatId;
  final DateTime createdAt;
  final String staffId;
  final String staffName;
}

/// Was an einem Empfänger fehlt oder nicht passt.
enum RecipientProblem { nameMissing, addressMissing, vatIdMissing, tooLong }

/// Die Probleme des Empfängers, leer, wenn er passt. Jedes Feld zählt ohne
/// Leerzeichen vorn und hinten. Die UID ist Pflicht erst, wenn die Summe des
/// Bons über [invoiceVatIdRequiredAboveCents] liegt.
Set<RecipientProblem> checkRecipient({
  required String name,
  required String addressLine1,
  required String addressLine2,
  required String vatId,
  required int receiptTotalCents,
}) => {
  for (final f in recipientFieldProblems(
    name: name,
    addressLine1: addressLine1,
    addressLine2: addressLine2,
    vatId: vatId,
    receiptTotalCents: receiptTotalCents,
  ).values)
    ?f,
};

/// Ein Feld des Empfängers.
enum RecipientField { name, addressLine1, addressLine2, vatId }

/// Wie [checkRecipient], aber je Feld: das Problem dieses Felds oder `null`.
/// So steht der Grund unter dem Feld, zu dem er gehört.
Map<RecipientField, RecipientProblem?> recipientFieldProblems({
  required String name,
  required String addressLine1,
  required String addressLine2,
  required String vatId,
  required int receiptTotalCents,
}) {
  RecipientProblem? text(String value, RecipientProblem missing) {
    final v = value.trim();
    if (v.isEmpty) return missing;
    return v.length > customerTextMax ? RecipientProblem.tooLong : null;
  }

  final vat = vatId.trim();
  return {
    RecipientField.name: text(name, RecipientProblem.nameMissing),
    RecipientField.addressLine1: text(
      addressLine1,
      RecipientProblem.addressMissing,
    ),
    RecipientField.addressLine2: text(
      addressLine2,
      RecipientProblem.addressMissing,
    ),
    RecipientField.vatId: vat.length > customerVatIdMax
        ? RecipientProblem.tooLong
        : vat.isEmpty && receiptTotalCents > invoiceVatIdRequiredAboveCents
        ? RecipientProblem.vatIdMissing
        : null,
  };
}

/// Die Rechnungsnummer: Kassen-ID und Bon-Nummer ("KASSA-1 / 1042"), weil
/// Bon-Nummern je Kassa zählen; ohne Kassen-ID nur die Nummer.
String invoiceNumber(Receipt r) {
  final cashBoxId = r.rksv?.cashBoxId;
  return cashBoxId == null || cashBoxId.isEmpty
      ? '${r.number}'
      : '$cashBoxId / ${r.number}';
}

/// Ob [r] ein Testbon ist: ohne Eintrag im Protokoll oder mit der
/// Probe-Signatur. Er trägt den Vermerk TESTBON ([layoutReceipt]).
bool isTestReceipt(Receipt r) {
  final rksv = r.rksv;
  return rksv == null || rksv.probe;
}

/// Ob [r] eine Rechnung bekommen kann: ein Verkauf, der nicht storniert ist
/// und kein Testbon. Ein Storno-Bon und Sonderbelege nicht.
bool invoiceAllowed(Receipt r) =>
    r.kind == ReceiptKind.sale && !r.isVoided && !isTestReceipt(r);

final _letter = RegExp(r'\p{L}', unicode: true);

/// Der Anfangsbuchstabe von [name] für die Tasten der Firmenkunden: das erste
/// Zeichen ohne Leerzeichen davor, groß; beginnt der Name mit einer Ziffer
/// oder einem Zeichen (oder ist er leer), `#`.
String customerInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '#';
  final first = String.fromCharCode(trimmed.runes.first);
  if (!_letter.hasMatch(first)) return '#';
  final upper = first.toUpperCase();
  // "ß" würde zu "SS": dann bleibt das Zeichen, wie es ist.
  return upper.runes.length == 1 ? upper : first;
}

/// Ordnet Anfangsbuchstaben: Buchstaben nach dem Alphabet, `#` zuletzt.
int compareInitials(String a, String b) {
  if (a == b) return 0;
  if (a == '#') return 1;
  if (b == '#') return -1;
  return a.compareTo(b);
}
