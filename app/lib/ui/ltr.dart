// Inhalte, die in jeder Sprache von links nach rechts stehen: Ziffernfelder,
// Beträge, Uhrzeiten, das Diagramm der Übersicht und die Bildschirme, die
// Deutsch bleiben.

import 'package:material_ui/material_ui.dart';

import '../core/app_language.dart';

/// Stellt [child] von links nach rechts, auch wenn die Bediensprache von
/// rechts nach links liest (Arabisch). Die Ausrichtung des Ganzen in seiner
/// Zeile bestimmt weiter das Elternteil.
class Ltr extends StatelessWidget {
  const Ltr({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Directionality(textDirection: TextDirection.ltr, child: child);
}

/// [value] (ein Betrag, ein Datum, eine Uhrzeit) als eigener Abschnitt von
/// links nach rechts in einem Satz der Bediensprache. Nur in einer Sprache,
/// die von rechts nach links liest; sonst bleibt der Text Zeichen für Zeichen
/// gleich.
String ltrIsolate(BuildContext context, String value) {
  final language = AppLanguage.byCode(
    Localizations.localeOf(context).languageCode,
  );
  if (!language.isRtl) return value;
  // LEFT-TO-RIGHT ISOLATE … POP DIRECTIONAL ISOLATE
  return '\u2066$value\u2069';
}

/// [align] (Anfang oder Ende der Zeile in der Leserichtung von [context]) als
/// feste Seite, für einen Text in einem [Ltr]: ein Betrag am Ende der Zeile
/// steht auf Deutsch rechts, auf Arabisch links.
TextAlign ltrAlign(BuildContext context, TextAlign align) {
  final rtl = Directionality.of(context) == TextDirection.rtl;
  return switch (align) {
    TextAlign.start => rtl ? TextAlign.right : TextAlign.left,
    TextAlign.end => rtl ? TextAlign.left : TextAlign.right,
    _ => align,
  };
}

/// Ein Pfeil oder Winkel, der "zurück" oder "weiter" zeigt: [ltr] in einer
/// Sprache von links nach rechts, sonst das gespiegelte Gegenstück [rtl].
IconData directionalIcon(
  BuildContext context, {
  required IconData ltr,
  required IconData rtl,
}) => Directionality.of(context) == TextDirection.rtl ? rtl : ltr;

/// Ein Name der Speisekarte in einer Sprache von rechts nach links: ein
/// eigener Abschnitt, dessen Richtung sein erster Buchstabe bestimmt. So
/// bleibt ein deutscher Name wie "3 Stück" in einer arabischen Zeile
/// "3 Stück", eine arabische Übersetzung liest von rechts. In den anderen
/// Sprachen bleibt [name] Zeichen für Zeichen gleich.
String nameIsolate(AppLanguage language, String name) =>
    // FIRST STRONG ISOLATE … POP DIRECTIONAL ISOLATE
    language.isRtl ? '\u2068$name\u2069' : name;

/// [nameIsolate] in der Bediensprache von [context].
String nameIsolateIn(BuildContext context, String name) => nameIsolate(
  AppLanguage.byCode(Localizations.localeOf(context).languageCode),
  name,
);
