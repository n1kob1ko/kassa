// Setzt einen gespeicherten Bon zu Druckzeilen fester Breite. Reines Dart,
// ohne Flutter und ohne Datenbank.

import 'business_info.dart';
import 'pricing.dart';
import 'print_document.dart';
import 'receipt.dart';

/// Einrückung der Folgezeilen und der Zeilen unter einer Bon-Zeile.
const String _indent = '    ';

final Set<int> _printableRunes = pc858Characters.runes.toSet();

/// Zeichen, die schlicht ersetzt werden.
const Map<String, String> _simple = {
  '\t': ' ',
  '\n': ' ',
  '\r': ' ',
  ' ': ' ',
  ' ': ' ',
  ' ': ' ',
  '“': '"',
  '”': '"',
  '„': '"',
  '‘': "'",
  '’': "'",
  '‚': "'",
  '–': '-',
  '—': '-',
  '‐': '-',
  '−': '-',
  '…': '...',
  'Œ': 'OE',
  'œ': 'oe',
  'Ł': 'L',
  'ł': 'l',
  'Đ': 'D',
  'đ': 'd',
  'ı': 'i',
  'İ': 'I',
  'Ŋ': 'N',
  'ŋ': 'n',
  'Ħ': 'H',
  'ħ': 'h',
  'Ŧ': 'T',
  'ŧ': 't',
};

/// Grundbuchstabe und die Buchstaben mit Akzent, die zu ihm werden.
const Map<String, String> _accented = {
  'a': 'āăąǎǟǡǻȁȃȧạảấầẩẫậắằẳẵặ',
  'A': 'ĀĂĄǍǞǠǺȀȂȦẠẢẤẦẨẪẬẮẰẲẴẶ',
  'c': 'ćĉċč',
  'C': 'ĆĈĊČ',
  'd': 'ďḍḏ',
  'D': 'ĎḌḎ',
  'e': 'ēĕėęěȅȇȩẹẻẽếềểễệ',
  'E': 'ĒĔĖĘĚȄȆȨẸẺẼẾỀỂỄỆ',
  'g': 'ĝğġģǧǵ',
  'G': 'ĜĞĠĢǦǴ',
  'h': 'ĥḥ',
  'H': 'ĤḤ',
  'i': 'ĩīĭįǐȉȋỉị',
  'I': 'ĨĪĬĮǏȈȊỈỊ',
  'j': 'ĵǰ',
  'J': 'Ĵ',
  'k': 'ķǩ',
  'K': 'ĶǨ',
  'l': 'ĺļľḷ',
  'L': 'ĹĻĽḶ',
  'n': 'ńņňǹṇ',
  'N': 'ŃŅŇǸṆ',
  'o': 'ōŏőơǒǫǭȍȏȫȯȱọỏốồổỗộớờởỡợ',
  'O': 'ŌŎŐƠǑǪǬȌȎȪȮȰỌỎỐỒỔỖỘỚỜỞỠỢ',
  'r': 'ŕŗřȑȓṛ',
  'R': 'ŔŖŘȐȒṚ',
  's': 'śŝşšșṣ',
  'S': 'ŚŜŞŠȘṢ',
  't': 'ţťțṭ',
  'T': 'ŢŤȚṬ',
  'u': 'ũūŭůűųưǔǖǘǚǜȕȗụủứừửữự',
  'U': 'ŨŪŬŮŰŲƯǓǕǗǙǛȔȖỤỦỨỪỬỮỰ',
  'w': 'ŵẁẃẅ',
  'W': 'ŴẀẂẄ',
  'y': 'ŷȳỳỵỷỹ',
  'Y': 'ŶŸȲỲỴỶỸ',
  'z': 'źżžẓ',
  'Z': 'ŹŻŽẒ',
};

final Map<int, String> _baseLetter = {
  for (final e in _accented.entries)
    for (final r in e.value.runes) r: e.key,
};

/// Beschränkt [text] auf Zeichen, die der Drucker kann: Zeichen aus PC858
/// bleiben, typografische Zeichen werden schlicht, Akzente fallen weg, alles
/// Übrige wird `?` (ein Zeichen je Zeichen des Textes).
String printable(String text) {
  final out = StringBuffer();
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    if (_printableRunes.contains(rune)) {
      out.write(ch);
    } else {
      out.write(_simple[ch] ?? _baseLetter[rune] ?? '?');
    }
  }
  return out.toString();
}

/// Betrag in Cent als "18,20", "-2,90", "1.234,50", ohne Euro-Zeichen.
String amount(int cents) {
  final abs = cents.abs();
  final whole = (abs ~/ 100).toString();
  final grouped = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) grouped.write('.');
    grouped.write(whole[i]);
  }
  final frac = (abs % 100).toString().padLeft(2, '0');
  return '${cents < 0 ? '-' : ''}$grouped,$frac';
}

String _two(int n) => n.toString().padLeft(2, '0');

String _dateTime(DateTime t) =>
    '${_two(t.day)}.${_two(t.month)}.${t.year} ${_two(t.hour)}:${_two(t.minute)}';

/// Bricht [text] an Wortgrenzen um. Die erste Zeile ist höchstens [first]
/// Zeichen lang, die weiteren höchstens [rest]. Ein zu langes Wort wird hart
/// geschnitten. Liefert immer mindestens eine Zeile.
List<String> _wrap(String text, int first, int rest) {
  var width = first < 1 ? 1 : first;
  // Passt alles in die erste Zeile, bleibt der Text unverändert.
  if (text.length <= width) return [text];
  final lines = <String>[];
  var current = '';
  void flush() {
    lines.add(current);
    current = '';
    width = rest < 1 ? 1 : rest;
  }

  for (var word in text.split(' ').where((w) => w.isNotEmpty)) {
    if (current.isNotEmpty && current.length + 1 + word.length <= width) {
      current = '$current $word';
      continue;
    }
    if (current.isNotEmpty) flush();
    while (word.length > width) {
      current = word.substring(0, width);
      word = word.substring(width);
      flush();
    }
    current = word;
  }
  if (current.isNotEmpty || lines.isEmpty) flush();
  return lines;
}

class _Builder {
  _Builder(this.columns);

  final int columns;
  final List<PrintOp> ops = [];

  void text(
    String s, {
    PrintAlign align = PrintAlign.left,
    bool bold = false,
    PrintSize size = PrintSize.normal,
  }) => ops.add(PrintText(s, align: align, bold: bold, size: size));

  void centered(String s, {bool bold = false}) {
    for (final line in _wrap(printable(s), columns, columns)) {
      text(line, align: PrintAlign.center, bold: bold);
    }
  }

  void rule() => text('-' * columns);

  void blank() => ops.add(const PrintFeed(1));

  /// Links [left], rechts [right]. Passt [left] nicht daneben, wird am Wort
  /// umbrochen: der Betrag steht in der ersten Zeile, Folgezeilen sind
  /// eingerückt.
  void row(
    String left,
    String right, {
    bool bold = false,
    PrintSize size = PrintSize.normal,
  }) {
    final l = printable(left);
    final r = printable(right);
    final lines = _wrap(
      l,
      r.isEmpty ? columns : columns - r.length - 1,
      columns - _indent.length,
    );
    final gap = columns - lines.first.length - r.length;
    text(
      r.isEmpty ? lines.first : lines.first + ' ' * (gap < 1 ? 1 : gap) + r,
      bold: bold,
      size: size,
    );
    for (final line in lines.skip(1)) {
      text(_indent + line, bold: bold, size: size);
    }
  }

  /// Eingerückte Zeile ohne Betrag, bei Bedarf umbrochen.
  void indented(String s) {
    final lines = _wrap(
      printable(s),
      columns - _indent.length,
      columns - _indent.length,
    );
    for (final line in lines) {
      text(_indent + line);
    }
  }
}

String _optionText(ReceiptLineOption o) {
  if (o.surchargeCents == 0) return o.optionName;
  final sign = o.surchargeCents > 0 ? '+' : '';
  return '${o.optionName} ($sign${amount(o.surchargeCents)})';
}

String _taxText(TaxLine t) =>
    '${t.rate.percent} % MwSt ${amount(t.taxCents)}  '
    'Netto ${amount(t.netCents)}';

/// Setzt [r] zu Druckzeilen für Papier mit [columns] Zeichen je Zeile.
/// [voidedNumber] ist bei einem Storno-Bon die Nummer des stornierten Bons.
List<PrintOp> layoutReceipt(
  Receipt r,
  BusinessInfo business, {
  int columns = 48,
  int? voidedNumber,
}) {
  final b = _Builder(columns);

  // 1. Kopf
  final name = printable(business.name);
  if (name.length <= columns ~/ 2) {
    b.text(
      name,
      align: PrintAlign.center,
      bold: true,
      size: PrintSize.doubleBoth,
    );
  } else {
    b.centered(name, bold: true);
  }
  for (final line in business.addressLines) {
    b.centered(line);
  }
  final vatId = business.vatId;
  if (vatId != null && vatId.isNotEmpty) b.centered('UID $vatId');
  b.rule();

  // 3. Storno oder Sonderbeleg
  // Das Wort steht immer da, die Nummer des stornierten Bons nur, wenn sie
  // bekannt ist.
  final special = r.kind.specialTitle;
  if (r.kind == ReceiptKind.voided) {
    b.text('STORNO', align: PrintAlign.center, bold: true);
    if (voidedNumber != null) {
      b.text('zu Bon Nr. $voidedNumber', align: PrintAlign.center);
    }
  } else if (special != null) {
    b.text(special.toUpperCase(), align: PrintAlign.center, bold: true);
  }

  // 4. Bon-Kopf
  b.row('Bon Nr. ${r.number}', _dateTime(r.createdAt));
  b.row('Bedienung: ${r.staffName}', '');
  final rksv = r.rksv;
  if (rksv != null) b.row('Kassen-ID: ${rksv.cashBoxId}', '');
  b.rule();

  // 5. Zeilen
  for (final line in r.lines) {
    final label = line.info == null || line.info!.isEmpty
        ? line.name
        : '${line.name} ${line.info}';
    b.row('${line.quantity} x $label', amount(line.goodsCents));
    if (line.quantity > 1 || line.quantity < -1) {
      b.indented('je ${amount(line.unitPriceCents)}');
    }
    for (final o in line.options) {
      b.indented(_optionText(o));
    }
  }

  // 6. Pfand und Summe. Ein Sonderbeleg hat keine Zeilen: die Linie unter
  // dem Bon-Kopf genügt.
  if (!r.kind.isSpecial) b.rule();
  if (r.depositCents != 0) b.row('Pfand', amount(r.depositCents));
  b.row(
    'SUMME EUR',
    amount(r.totalCents),
    bold: true,
    size: PrintSize.doubleHeight,
  );
  b.rule();

  // 7. Steuer
  for (final t in r.taxLines) {
    b.row(_taxText(t), amount(t.grossCents));
  }

  // 8. Zahlung, bei Sonderbelegen keine
  final p = r.payment;
  if (p != null) {
    switch (p.kind) {
      case PaymentKind.cash:
        b.row('Bar', amount(p.amountCents));
        if (p.givenCents != p.amountCents) {
          b.row('Gegeben', amount(p.givenCents));
          b.row('Rückgeld', amount(p.changeCents));
        }
      case PaymentKind.card:
        b.row('Karte', amount(p.amountCents));
        final scheme = p.cardScheme;
        final last4 = p.cardLast4;
        if (last4 != null && last4.isNotEmpty) {
          b.indented(
            scheme == null || scheme.isEmpty
                ? '**** $last4'
                : '$scheme **** $last4',
          );
        }
        final tx = p.providerTxCode;
        if (tx != null && tx.isNotEmpty) b.indented('Beleg $tx');
    }
  }

  // QR-Code der Signatur, bei Sonderbelegen nach der Summe
  if (rksv != null) {
    b.blank();
    b.ops.add(PrintQr(rksv.qrText));
    if (rksv.damaged) {
      b.text('Sicherheitseinrichtung ausgefallen', align: PrintAlign.center);
    }
  }

  // 9. Schlusstext
  final footer = business.receiptFooter;
  if (footer != null && footer.trim().isNotEmpty) {
    b.blank();
    b.centered(footer);
  }

  // 10. Testbon: ohne Eintrag im Protokoll und bei der Probe-Signatur
  if (rksv == null || rksv.probe) {
    b.blank();
    b.text('TESTBON', align: PrintAlign.center, bold: true);
    b.text('Keine gültige Rechnung', align: PrintAlign.center);
  }

  // 11. Ende
  b.ops
    ..add(const PrintFeed(3))
    ..add(const PrintCut());
  return b.ops;
}

/// Ein Testdruck: Betrieb, Zeit, ein Lineal über die volle Breite und die
/// Umlaute.
List<PrintOp> layoutTestPrint(
  BusinessInfo business,
  DateTime now, {
  int columns = 48,
}) {
  final b = _Builder(columns);
  b.text('Testdruck', align: PrintAlign.center, bold: true);
  b.centered(business.name);
  b.centered(_dateTime(now));
  b.rule();
  b.text([for (var i = 1; i <= columns; i++) i % 10].join());
  b.text('ä ö ü ß € sind lesbar');
  b.ops
    ..add(const PrintFeed(3))
    ..add(const PrintCut());
  return b.ops;
}
