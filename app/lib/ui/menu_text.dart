// Namen der Speisekarte am Bildschirm in der Bediensprache.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app.dart' show appLanguageProvider;
import '../core/app_language.dart';
import '../data/providers.dart';
import '../domain/menu_dictionary.dart';
import 'ltr.dart';

/// Schlägt Namen der Speisekarte in der Bediensprache nach. Ohne Treffer, auf
/// Deutsch und solange das Wörterbuch noch nicht gelesen ist: der Name aus der
/// Speisekarte. Nur für die Anzeige; gespeichert und gedruckt wird immer der
/// Name aus der Speisekarte. In Arabisch steht der Name als eigener Abschnitt
/// ([nameIsolate]), damit ein deutscher Name in der Zeile richtig herum steht.
final menuTextProvider = Provider<String Function(String source)>((ref) {
  final language = ref.watch(appLanguageProvider);
  // Deutsch ist die Sprache der Speisekarte: kein Blick ins Wörterbuch.
  if (language == AppLanguage.de) return (source) => source;
  final dictionary =
      ref.watch(menuDictionaryProvider).value ?? MenuDictionary.empty;
  return (source) => nameIsolate(language, dictionary.text(source, language));
});

/// Ein Name der Speisekarte in einem Feld fester Größe: [maxLines] Zeilen in
/// voller Größe. Passt er so nicht ganz (lange Namen, andere Sprachen), wird
/// die Schrift kleiner und er darf so viele Zeilen nehmen, wie das Feld hoch
/// ist: gekürzt wird er erst, wenn er auch in der kleinsten Stufe nicht
/// passt. Braucht ein Feld mit fester Höhe.
class FittingName extends StatelessWidget {
  const FittingName(
    this.name, {
    super.key,
    required this.maxLines,
    required this.style,
    this.alignment = AlignmentDirectional.topStart,
  });

  final String name;
  final int maxLines;
  final TextStyle style;

  /// Wo der Name im Feld steht; die Artikeltaste: oben am Anfang der Zeile.
  final AlignmentGeometry alignment;

  /// Stufen der Schrift, die volle Größe zuerst.
  static const _steps = [1.0, 0.9, 0.8];

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        bool fits(TextStyle s, int? lines) {
          final painter = TextPainter(
            text: TextSpan(text: name, style: s),
            textDirection: direction,
            textScaler: scaler,
            locale: locale,
            maxLines: lines,
          )..layout(maxWidth: box.maxWidth);
          final ok =
              !painter.didExceedMaxLines && painter.height <= box.maxHeight;
          painter.dispose();
          return ok;
        }

        var shown = style;
        int? lines = maxLines;
        if (!fits(style, maxLines)) {
          final smaller = [
            for (final f in _steps.skip(1))
              style.copyWith(fontSize: style.fontSize! * f),
          ];
          final fitting = smaller.where((s) => fits(s, null)).firstOrNull;
          if (fitting != null) {
            shown = fitting;
            lines = null;
          } else {
            // Auch in der kleinsten Stufe zu lang: so viele Zeilen, wie
            // Platz haben, der Rest wird gekürzt.
            shown = smaller.last;
            final line = scaler.scale(shown.fontSize!) * (shown.height ?? 1);
            lines = (box.maxHeight / line).floor().clamp(1, 99);
          }
        }
        return Align(
          alignment: alignment,
          child: Text(
            name,
            maxLines: lines,
            // Ellipse ohne Zeilengrenze hieße: nur eine Zeile.
            overflow: lines == null ? TextOverflow.clip : TextOverflow.ellipsis,
            style: shown,
          ),
        );
      },
    );
  }
}
