// Schreibt die Listen zum Gegenlesen der Übersetzungen. Aufruf aus `app/`:
// dart run tool/l10n_review.dart
//
// Liest die ARB-Dateien aus lib/l10n/ und schreibt je Sprache (en, zh, tr,
// ar) eine Datei nach docs/uebersetzungen/: eine Tabelle "Deutsch |
// Übersetzung | Wo" in der Reihenfolge der deutschen Datei, gegliedert nach
// Bereichen, und am Ende den Abschnitt "Unsicher". Läuft ohne Flutter und
// schreibt bei jedem Lauf dieselben Bytes (ein Test prüft, dass die Dateien
// aktuell sind).

import 'dart:convert';
import 'dart:io';

final arbDir = Directory('lib/l10n');
final reviewDir = Directory('../docs/uebersetzungen');

/// Die Sprachen der Listen, in dieser Reihenfolge, mit ihrem deutschen Namen.
const reviewLanguages = {
  'en': 'Englisch',
  'zh': 'Chinesisch',
  'tr': 'Türkisch',
  'ar': 'Arabisch',
};

/// Bereich der Kassa nach dem Vorsatz des Schlüssels ("closeStillOpen" ->
/// Abschluss).
const _areas = {
  'language': 'Sprache',
  'login': 'Anmeldung',
  'shell': 'Kopfleiste und Reiter',
  'ui': 'Allgemein',
  'date': 'Datum',
  'outage': 'Hinweis zur Signatur',
  'kassa': 'Kassa',
  'card': 'Kartenzahlung',
  'print': 'Meldungen des Druckers',
  'unclear': 'Unklare Kartenzahlung',
  'bons': 'Bons',
  'items': 'Artikel',
  'overview': 'Übersicht',
  'close': 'Abschluss',
  'settings': 'Einstellungen',
  'kitchen': 'Küchenbon',
};

/// Stellen, bei denen die Übersetzung unsicher ist, je Sprache: Schlüssel
/// und warum. Der jetzige Text kommt beim Schreiben aus der ARB-Datei.
const _unsure = <String, Map<String, String>>{
  'en': {
    'kassaStillMissing':
        'Neu "Remaining" (vorher "Still due"). Steht, wenn zu wenig Bargeld '
        'gegeben wurde, vor dem fehlenden Betrag.',
    'kassaPaidExact':
        'Neu "Exact amount" (vorher "Paid exact"). Steht bei "Verkauf fertig", '
        'wenn kein Rückgeld bleibt.',
    'shellTabKassa': 'Der Reiter "Kassa" heißt "Register". Passt das?',
  },
  'zh': {
    'closeStillOpen':
        'Steht bei "Wechselgeld am Morgen" und "Gezählt", solange noch nichts '
        'eingetragen ist. Vorschlag war "未结"; "待定" ist geblieben, weil es '
        'zu beiden Zeilen passt. Bitte entscheiden.',
    'closeSaveCashIn': 'Neu "确认存入" (vorher "保存存入"). Taste.',
    'closeSaveCashOut': 'Neu "确认取出" (vorher "保存取出"). Taste.',
    'bonsNumberShort': 'Bon-Nummer in der Liste, zum Beispiel "128 号".',
    'bonsVoidOf':
        'Neu "作废 128 号小票" (vorher "作废小票号 128"). Steht am Storno-Bon.',
    'kitchenVoided':
        'Neu "作废" (vorher "取消", das auch "Abbrechen" heißt). Überschrift '
        'STORNO am Küchenbon, wie "作废" bei "Stornieren".',
    'dateMonthNovember':
        'Monate jetzt mit Ziffern ("11月", "11月17日", "2026年11月") statt '
        '"十一月". Gilt für alle zwölf Monate.',
  },
  'tr': {
    'outageRepin':
        'Anrede: Tasten stehen in der kurzen Befehlsform ("Kaydet", "PIN\'i '
        'yeniden gir"), ganze Sätze höflich ("Lütfen tekrar deneyin"). Ist '
        'das so üblich?',
    'settingsDeviceTestHelp': 'Neu "Test baskısı, çekmeceyi açma." (vorher '
        '"…, çekmeceyi aç.").',
    'closeFloatTitle':
        'Wechselgeld (das Geld, das morgens in der Lade liegt) heißt überall '
        '"Bozuk para". Passt das, oder besser "Kasa avansı"?',
    'kassaChange': 'Rückgeld heißt überall "Para üstü".',
    'kitchenVoided': 'Überschrift STORNO am Küchenbon.',
  },
  'ar': {
    'bonsDeposit':
        'Pfand (für Flaschen) heißt überall "تأمين". Passt das für '
        'Flaschenpfand? "رهن" wäre falsch (heißt Pfand im Sinn von '
        'Verpfändung).',
    'kassaItemCount':
        'Neu: eigene Form für 0 Artikel ("لا أصناف") statt "0 صنف". Bitte '
        'alle Formen ansehen.',
    'kitchenVoided':
        'Überschrift STORNO am Küchenbon. "إلغاء" heißt auch "Abbrechen" '
        '(Taste).',
    'closeFloatTitle':
        'Wechselgeld heißt überall "الفكة", Rückgeld überall "الباقي".',
    'shellTabKassa': 'Der Reiter "Kassa" heißt "البيع" (Verkauf). Passt das?',
  },
};

/// Dateiname (`en.md` usw.) und Inhalt jeder Liste.
Map<String, String> buildReviewLists(Directory arbs) {
  final german = _readArb(File('${arbs.path}/app_de.arb'));
  return {
    for (final MapEntry(key: code, value: name) in reviewLanguages.entries)
      '$code.md': _list(
        code,
        name,
        german,
        _readArb(File('${arbs.path}/app_$code.arb')),
      ),
  };
}

/// Die Texte einer ARB-Datei in ihrer Reihenfolge, ohne die "@"-Einträge.
Map<String, String> _readArb(File file) {
  final raw = jsonDecode(utf8.decode(file.readAsBytesSync())) as Map;
  return {
    for (final MapEntry(:key, :value) in raw.entries)
      if (!(key as String).startsWith('@')) key: value as String,
  };
}

String _area(String key) {
  final prefix = RegExp('^[a-z]+').firstMatch(key)!.group(0)!;
  return _areas[prefix] ?? 'Sonstiges';
}

/// Text für eine Zelle einer Markdown-Tabelle.
String reviewCell(String text) =>
    text.replaceAll('|', r'\|').replaceAll('\n', '<br>');

String _row(List<String> cells) => '| ${cells.join(' | ')} |';

String _list(
  String code,
  String name,
  Map<String, String> german,
  Map<String, String> translated,
) {
  final out = StringBuffer()
    ..writeln('# Gegenlesen: $name')
    ..writeln()
    ..writeln(
      '<!-- Erzeugt von app/tool/l10n_review.dart aus den ARB-Dateien. '
      'Nicht von Hand ändern. -->',
    )
    ..writeln()
    ..writeln(
      'Hier stehen alle ${german.length} Texte, die die Kassa auf $name '
      'zeigt: links Deutsch, in der Mitte die Übersetzung, rechts, wo der '
      'Text steht. Ist etwas falsch, schreib den Eintrag aus "Wo" und den '
      'richtigen Text dazu. Besonders wichtig ist der Abschnitt "Unsicher" '
      'am Ende.',
    )
    ..writeln()
    ..writeln(
      'Wörter in geschweiften Klammern wie {amount} setzt die Kassa selbst '
      'ein; sie bleiben genau so stehen. Manche Texte haben mehrere Formen, '
      'je nach Anzahl: bitte jede Form ansehen.',
    );
  // Je Bereich eine Tabelle, in der Reihenfolge, in der die Bereiche in der
  // deutschen Datei zuerst vorkommen (später ergänzte Texte stehen dort
  // am Ende).
  final byArea = <String, List<String>>{};
  for (final key in german.keys) {
    byArea.putIfAbsent(_area(key), () => []).add(key);
  }
  for (final MapEntry(key: area, value: keys) in byArea.entries) {
    out
      ..writeln()
      ..writeln('## $area')
      ..writeln()
      ..writeln(_row(['Deutsch', 'Übersetzung', 'Wo']))
      ..writeln(_row(['---', '---', '---']));
    for (final key in keys) {
      final text = translated[key];
      out.writeln(
        _row([
          reviewCell(german[key]!),
          text == null ? '(fehlt)' : reviewCell(text),
          '$area: `$key`',
        ]),
      );
    }
  }

  out
    ..writeln()
    ..writeln('## Unsicher')
    ..writeln();
  final notes = _unsure[code] ?? const {};
  if (notes.isEmpty) {
    out.writeln('Keine Stellen.');
  } else {
    out
      ..writeln(_row(['Wo', 'Deutsch', 'Übersetzung', 'Warum']))
      ..writeln(_row(['---', '---', '---', '---']));
    for (final MapEntry(:key, value: why) in notes.entries) {
      final de = german[key];
      if (de == null) throw StateError('Unbekannter Schlüssel: $key');
      out.writeln(
        _row([
          '${_area(key)}: `$key`',
          reviewCell(de),
          reviewCell(translated[key] ?? '(fehlt)'),
          reviewCell(why),
        ]),
      );
    }
  }
  // Was gleich wie Deutsch ist (ohne Platzhalter und Satzzeichen), kann
  // richtig sein ("Vegan", "April") oder vergessen.
  final same = [
    for (final MapEntry(:key, value: de) in german.entries)
      if (translated[key] == de &&
          RegExp(r'\p{L}', unicode: true)
              .hasMatch(de.replaceAll(RegExp(r'\{[^{}]*\}'), '')))
        key,
  ];
  if (same.isNotEmpty) {
    out
      ..writeln()
      ..writeln(
        'Gleich wie Deutsch (bitte kurz prüfen, ob das so passt): '
        '${same.map((k) => '`$k` (${reviewCell(german[k]!)})').join(', ')}.',
      );
  }
  return out.toString();
}

void main() {
  reviewDir.createSync(recursive: true);
  for (final MapEntry(:key, :value) in buildReviewLists(arbDir).entries) {
    File('${reviewDir.path}/$key').writeAsStringSync(value);
    stdout.writeln('${reviewDir.path}/$key');
  }
}
