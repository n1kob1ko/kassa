import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../devices/device_providers.dart';
import '../../ui/app_header.dart';
import '../../ui/tokens.dart';
import '../bons/bons_screen.dart';
import '../close/close_screen.dart';
import '../close/forgotten_close_banner.dart';
import '../items/items_screen.dart';
import '../kassa/kassa_screen.dart';
import '../kassa/sale_service.dart';
import '../kassa/unclear_card_payment.dart';
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

  /// Die Seite "Geräte testen" ersetzt die Karten der Einstellungen.
  bool _testingDevices = false;

  /// "Zurück" des Tablets schließt die oberste offene Ebene: erst "Geräte
  /// testen", dann die Einstellungen. An der Kassa tut es nichts, die App
  /// verlässt man nur mit der Home-Geste. Das Blatt zur unklaren Kartenzahlung
  /// hat ein eigenes `PopScope`; jedes `PopScope` einer Route bekommt den Ruf,
  /// darum rührt dieser hier nichts an, solange das Blatt offen ist.
  void _onBack(bool didPop, Object? result) {
    if (didPop) return;
    if (ref.read(unclearCardPaymentsProvider).isNotEmpty) return;
    if (_testingDevices) {
      setState(() => _testingDevices = false);
    } else if (_settingsOpen) {
      setState(() => _settingsOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(sessionProvider);
    final c = KassaColors.of(context);
    if (staff == null) return Scaffold(backgroundColor: c.ground);
    final blocked = ref.watch(unclearCardPaymentsProvider).isNotEmpty;
    // Während eine Kartenzahlung läuft, bleibt die Kassa stehen: kein anderer
    // Bereich, keine Einstellungen, kein Abmelden. Sonst ginge das Ergebnis
    // der Zahlung an einer Kassa verloren, die es nicht mehr gibt.
    final paying = ref.watch(activeCardPaymentProvider) != null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onBack,
      child: Scaffold(
        backgroundColor: c.ground,
        body: Stack(
          children: [
            // Solange das Blatt zur unklaren Kartenzahlung offen ist, erreicht
            // nichts darunter Tipps, Tastatur oder Vorlesehilfe.
            ExcludeSemantics(
              excluding: blocked,
              child: ExcludeFocus(
                excluding: blocked,
                child: Column(
                  children: [
                    AppHeader(
                      area: _area,
                      settingsActive: _settingsOpen,
                      onArea: (a) {
                        if (paying) return;
                        setState(() {
                          _area = a;
                          _settingsOpen = false;
                          _testingDevices = false;
                        });
                      },
                      staffName: staff.name,
                      isChef: staff.isChef,
                      onStaff: () {
                        if (paying) return;
                        ref.read(sessionProvider.notifier).logout();
                      },
                      onSettings: () {
                        if (paying) return;
                        setState(() {
                          _settingsOpen = !_settingsOpen;
                          _testingDevices = false;
                        });
                      },
                      businessName: ref
                          .watch(catalogProvider)
                          .value
                          ?.businessName,
                      offline: !(ref.watch(internetProvider).value ?? true),
                    ),
                    if (_settingsOpen || _area != AppArea.close)
                      ForgottenCloseBanner(
                        isChef: staff.isChef,
                        onClose: () {
                          if (paying) return;
                          setState(() {
                            _area = AppArea.close;
                            _settingsOpen = false;
                            _testingDevices = false;
                          });
                        },
                      ),
                    Expanded(
                      child: _settingsOpen && staff.isChef
                          ? _AboveBottomBar(
                              child: SettingsScreen(
                                key: const Key('area-settings'),
                                testingDevices: _testingDevices,
                                onTestingDevices: (v) =>
                                    setState(() => _testingDevices = v),
                              ),
                            )
                          : _areaWidget(
                              _area,
                              () => setState(() => _area = AppArea.kassa),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const Positioned.fill(child: UnclearCardOverlay()),
          ],
        ),
      ),
    );
  }
}

/// Hier wird das Bild eines Bereichs gewählt. [toKassa] wechselt zur Kassa.
Widget _areaWidget(AppArea area, VoidCallback toKassa) {
  switch (area) {
    // Die Kassa hält den Platz unten selbst frei, damit die Bon-Spalte bis an
    // den Rand reicht.
    case AppArea.kassa:
      return const KassaScreen(key: Key('area-kassa'));
    case AppArea.bons:
      return const _AboveBottomBar(child: BonsScreen(key: Key('area-bons')));
    case AppArea.overview:
      return const _AboveBottomBar(
        child: OverviewScreen(key: Key('area-overview')),
      );
    case AppArea.items:
      return const _AboveBottomBar(child: ItemsScreen(key: Key('area-items')));
    case AppArea.close:
      return _AboveBottomBar(
        child: CloseScreen(key: const Key('area-close'), onToKassa: toKassa),
      );
  }
}

/// Hält alles Bedienbare über der Gesten- oder Tastenleiste des Tablets.
class _AboveBottomBar extends StatelessWidget {
  const _AboveBottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SafeArea(top: false, left: false, right: false, child: child);
}
