import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// Rahmen um die ganze App für die Leisten des Tablets.
///
/// Android zeichnet die App bis an den Rand, unter die Statusleiste oben und
/// die Gesten- oder Tastenleiste unten. Dieser Rahmen hält links und rechts
/// alles Bedienbare aus diesen Zonen heraus und stellt die Zeichen der Leisten
/// passend zur hellen oder dunklen Ansicht ein. Den Platz oben füllt jede Seite
/// selbst: die Kopfleiste mit ihrer eigenen Farbe (siehe `AppHeader`), Seiten
/// ohne Kopfleiste mit einem `SafeArea`. Den Platz unten hält jede Seite selbst
/// frei, damit die Bon-Spalte der Kassa bis an den Rand reichen kann (siehe
/// `ShellScreen` und `KassaScreen`).
class SystemBarsFrame extends StatelessWidget {
  const SystemBarsFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final icons = dark ? Brightness.light : Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: const Color(0x00000000),
        statusBarIconBrightness: icons,
        // iOS beschreibt die Leiste selbst, nicht ihre Zeichen.
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: const Color(0x00000000),
        systemNavigationBarIconBrightness: icons,
        systemNavigationBarContrastEnforced: false,
      ),
      child: ColoredBox(
        color: KassaColors.of(context).ground,
        child: SafeArea(top: false, bottom: false, child: child),
      ),
    );
  }
}
