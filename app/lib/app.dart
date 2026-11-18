import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app_sync_providers.dart';
import 'data/providers.dart';
import 'data/settings_repository.dart';
import 'features/login/pin_screen.dart';
import 'features/login/session.dart';
import 'features/setup/setup_screen.dart';
import 'features/shell/shell_screen.dart';
import 'ui/primary_button.dart';
import 'ui/system_bars.dart';
import 'ui/theme.dart';
import 'ui/tokens.dart';

/// Wurzel der App: Einrichtung, solange es keine Speisekarte und keinen Chef
/// gibt, dann Anmeldung, dann die Kassa.
class KassaApp extends ConsumerWidget {
  const KassaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Der Abgleich im Hintergrund beginnt, sobald die Kassa gekoppelt ist.
    if (ref.watch(hasServerProvider) &&
        ref.watch(syncStateProvider.select((s) => s.value?.paired ?? false))) {
      ref.watch(syncServiceProvider);
    }
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
          child: SystemBarsFrame(child: child!),
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

/// Das erste Lesen der Datenbank ist gescheitert: ein Satz, der Fehler und eine
/// Taste, damit die Person am Tablet etwas melden kann.
class _StartError extends StatelessWidget {
  const _StartError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Die Kassa kann nicht starten.',
                  textAlign: TextAlign.center,
                  style: text.headlineMedium,
                ),
                const SizedBox(height: KassaTokens.spaceMd),
                Text(
                  'Die Daten auf diesem Tablet lassen sich nicht lesen.',
                  textAlign: TextAlign.center,
                  style: text.bodyLarge,
                ),
                const SizedBox(height: KassaTokens.spaceMd),
                Text(
                  '${error.runtimeType}: $error',
                  key: const Key('start-error-detail'),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall!.copyWith(color: c.ink2),
                ),
                const SizedBox(height: KassaTokens.spaceXxl),
                PrimaryButton(
                  key: const Key('start-retry'),
                  label: 'Nochmal versuchen',
                  onPressed: onRetry,
                  muted: true,
                  height: KassaTokens.minTap + 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Solange die Datenbank das erste Mal gelesen wird: nur der Grund.
    final setup = ref.watch(setupCompleteProvider);
    final complete = setup.value;
    if (complete == null) {
      final error = setup.error;
      if (error == null) return const _EmptyScreen();
      return _StartError(
        error: error,
        onRetry: () {
          ref.invalidate(catalogProvider);
          ref.invalidate(setupCompleteProvider);
        },
      );
    }
    if (!complete) return const SetupScreen();
    if (ref.watch(sessionProvider) == null) return const PinScreen();
    return const ShellScreen();
  }
}
