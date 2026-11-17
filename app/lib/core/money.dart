// Geld-Hilfen der App. Beträge sind ganze Cent, Preise sind Bruttopreise.
// Reines Dart, ohne Flutter.

/// Formatiert Cent als deutschen Euro-Betrag, z. B. `1.284,60 €`.
String formatEuro(int cents) {
  final sign = cents < 0 ? '−' : '';
  final absCents = cents.abs();
  final euros = (absCents ~/ 100).toString();
  final rest = (absCents % 100).toString().padLeft(2, '0');

  final grouped = StringBuffer();
  for (var i = 0; i < euros.length; i++) {
    if (i > 0 && (euros.length - i) % 3 == 0) grouped.write('.');
    grouped.write(euros[i]);
  }
  return '$sign$grouped,$rest €';
}

/// Eingabe über das Zahlenfeld. Unveränderlich: [tap] liefert eine neue Instanz.
///
/// Tasten: `'0'` bis `'9'`, `','` und `'back'`.
/// Höchstens [maxIntDigits] Stellen vor dem Komma und zwei danach.
class KeypadInput {
  const KeypadInput({this.text = '', this.maxIntDigits = 4});

  final String text;
  final int maxIntDigits;

  static final _digit = RegExp(r'^[0-9]$');

  KeypadInput tap(String key) {
    if (key == 'back') {
      if (text.isEmpty) return this;
      return _copy(text.substring(0, text.length - 1));
    }
    if (key == ',') {
      if (text.contains(',')) return this;
      return _copy(text.isEmpty ? '0,' : '$text,');
    }
    if (!_digit.hasMatch(key)) return this;

    if (text == '0') return _copy(key);

    final commaIndex = text.indexOf(',');
    if (commaIndex >= 0) {
      final decimals = text.length - commaIndex - 1;
      if (decimals >= 2) return this;
    } else if (text.length >= maxIntDigits) {
      return this;
    }
    return _copy('$text$key');
  }

  /// Betrag in ganzen Cent. Leeres Feld ergibt 0.
  int get cents {
    if (text.isEmpty) return 0;
    final commaIndex = text.indexOf(',');
    final intPart = commaIndex < 0 ? text : text.substring(0, commaIndex);
    final decPart = commaIndex < 0 ? '' : text.substring(commaIndex + 1);
    final paddedDec = decPart.padRight(2, '0');
    return int.parse(intPart) * 100 + int.parse(paddedDec);
  }

  bool get isEmpty => text.isEmpty;

  KeypadInput _copy(String newText) =>
      KeypadInput(text: newText, maxIntDigits: maxIntDigits);
}
