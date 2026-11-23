// Baut Druckzeilen fester Breite. Reines Dart, ohne Flutter und ohne
// Datenbank. Gemeinsam für Bons, Berichte und Testzettel.

import 'business_info.dart';
import 'print_document.dart';

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

String dateTimeText(DateTime t) =>
    '${_two(t.day)}.${_two(t.month)}.${t.year} ${_two(t.hour)}:${_two(t.minute)}';

String dateText(DateTime t) => '${_two(t.day)}.${_two(t.month)}.${t.year}';

/// Bricht [text] an Wortgrenzen um. Die erste Zeile ist höchstens [first]
/// Zeichen lang, die weiteren höchstens [rest]. Ein zu langes Wort wird hart
/// geschnitten. Liefert immer mindestens eine Zeile.
List<String> wrapText(String text, int first, int rest) {
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

class PrintBuilder {
  PrintBuilder(this.columns);

  final int columns;
  final List<PrintOp> ops = [];

  void text(
    String s, {
    PrintAlign align = PrintAlign.left,
    bool bold = false,
    PrintSize size = PrintSize.normal,
  }) => ops.add(PrintText(s, align: align, bold: bold, size: size));

  void centered(String s, {bool bold = false}) {
    for (final line in wrapText(printable(s), columns, columns)) {
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
    final lines = wrapText(
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
    final lines = wrapText(
      printable(s),
      columns - _indent.length,
      columns - _indent.length,
    );
    for (final line in lines) {
      text(_indent + line);
    }
  }

  /// Kopf wie am Bon: Name (groß, wenn er in die halbe Breite passt) und
  /// Adresse, ohne UID.
  void businessHead(BusinessInfo business) {
    final name = printable(business.name);
    if (name.length <= columns ~/ 2) {
      text(
        name,
        align: PrintAlign.center,
        bold: true,
        size: PrintSize.doubleBoth,
      );
    } else {
      centered(name, bold: true);
    }
    for (final line in business.addressLines) {
      centered(line);
    }
  }

  /// [label], [middle] endet 15 Zeichen vor dem rechten Rand, [right]
  /// rechtsbündig. Passt `label + ' ' + middle` nicht vor diese Spalte, steht
  /// [label] allein in der Zeile darüber.
  void row3(String label, String middle, String right) {
    final l = printable(label);
    final m = printable(middle);
    final r = printable(right);
    final middleEnd = columns - 15;
    var first = l;
    if (l.length + 1 + m.length > middleEnd) {
      row(l, '');
      first = '';
    }
    final line = StringBuffer(first);
    final padMiddle = middleEnd - first.length - m.length;
    line.write(' ' * (padMiddle < 0 ? 0 : padMiddle));
    line.write(m);
    final gap = columns - line.length - r.length;
    line.write(' ' * (gap < 1 ? 1 : gap));
    line.write(r);
    text(line.toString());
  }
}
