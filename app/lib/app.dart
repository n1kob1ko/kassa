import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'data/providers.dart';
import 'data/settings_repository.dart';
import 'features/login/pin_screen.dart';
import 'features/login/session.dart';
import 'features/setup/setup_screen.dart';
import 'features/shell/shell_screen.dart';
import 'ui/theme.dart';
import 'ui/tokens.dart';

/// Wurzel der App: Einrichtung, solange es keine Speisekarte und keinen Chef
/// gibt, dann Anmeldung, dann die Kassa.
class KassaApp extends ConsumerWidget {
  const KassaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Solange die Einstellungen nicht geladen sind: wie das Tablet.
    final mode = ref.watch(
      settingsStreamProvider.select((s) => s.value?.themeMode),
    );
    return MaterialApp(
      title: 'Kassa',
      debugShowCheckedModeBanner: false,
      theme: kassaTheme(Brightness.light),
      darkTheme: kassaTheme(Brightness.dark),
      themeMode: switch (mode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      builder: (context, child) {
        // Systemweite Textvergrößerung höchstens bis 1,3.
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: KassaTokens.maxTextScale,
          child: child!,
        );
      },
      home: const _Home(),
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

class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Solange die Datenbank das erste Mal gelesen wird: nur der Grund.
    final complete = ref.watch(setupCompleteProvider).value;
    if (complete == null) return const _EmptyScreen();
    if (!complete) return const SetupScreen();
    if (ref.watch(sessionProvider) == null) return const PinScreen();
    return const ShellScreen();
  }
}
