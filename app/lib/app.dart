import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'ui/theme.dart';
import 'ui/tokens.dart';

/// Wurzel der App. Spätere Aufgaben hängen Einrichtung, Anmeldung und die
/// Bereiche ein.
class KassaApp extends ConsumerWidget {
  const KassaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Kassa',
      debugShowCheckedModeBanner: false,
      theme: kassaTheme(Brightness.light),
      darkTheme: kassaTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      builder: (context, child) {
        // Systemweite Textvergrößerung höchstens bis 1,3.
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: KassaTokens.maxTextScale,
          child: child!,
        );
      },
      home: const _EmptyScreen(),
    );
  }
}

class _EmptyScreen extends StatelessWidget {
  const _EmptyScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: KassaColors.of(context).ground);
  }
}
