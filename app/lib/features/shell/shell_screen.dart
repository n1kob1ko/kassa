import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../ui/app_header.dart';
import '../../ui/tokens.dart';
import '../bons/bons_screen.dart';
import '../close/close_screen.dart';
import '../close/forgotten_close_banner.dart';
import '../items/items_screen.dart';
import '../kassa/kassa_screen.dart';
import '../login/session.dart';
import '../overview/overview_screen.dart';
import '../settings/settings_screen.dart';

/// Kopfleiste und der gewählte Bereich darunter.
class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  AppArea _area = AppArea.kassa;

  /// Die Einstellungen stehen an Stelle des Bereichs. [_area] bleibt, damit
  /// der Knopf dorthin zurückführt.
  bool _settingsOpen = false;

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(sessionProvider);
    final c = KassaColors.of(context);
    if (staff == null) return Scaffold(backgroundColor: c.ground);
    return Scaffold(
      backgroundColor: c.ground,
      body: Column(
        children: [
          AppHeader(
            area: _area,
            settingsActive: _settingsOpen,
            onArea: (a) => setState(() {
              _area = a;
              _settingsOpen = false;
            }),
            staffName: staff.name,
            isChef: staff.isChef,
            onStaff: ref.read(sessionProvider.notifier).logout,
            onSettings: () => setState(() => _settingsOpen = !_settingsOpen),
            businessName: ref.watch(catalogProvider).value?.businessName,
          ),
          if (_settingsOpen || _area != AppArea.close)
            ForgottenCloseBanner(
              isChef: staff.isChef,
              onClose: () => setState(() {
                _area = AppArea.close;
                _settingsOpen = false;
              }),
            ),
          Expanded(
            child: _settingsOpen && staff.isChef
                ? const SettingsScreen(key: Key('area-settings'))
                : _areaWidget(
                    _area,
                    () => setState(() => _area = AppArea.kassa),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Hier wird das Bild eines Bereichs gewählt. [toKassa] wechselt zur Kassa.
Widget _areaWidget(AppArea area, VoidCallback toKassa) {
  switch (area) {
    case AppArea.kassa:
      return const KassaScreen(key: Key('area-kassa'));
    case AppArea.bons:
      return const BonsScreen(key: Key('area-bons'));
    case AppArea.overview:
      return const OverviewScreen(key: Key('area-overview'));
    case AppArea.items:
      return const ItemsScreen(key: Key('area-items'));
    case AppArea.close:
      return CloseScreen(key: const Key('area-close'), onToKassa: toKassa);
  }
}
