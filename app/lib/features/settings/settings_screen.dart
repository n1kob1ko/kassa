import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_info.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../ui/pressable.dart';
import '../../ui/segmented.dart';
import '../../ui/tokens.dart';
import '../items/item_detail.dart' show FailedHint;
import 'card_panel.dart';
import 'device_test_screen.dart';
import 'printer_panel.dart';
import 'reimport_panel.dart';
import 'settings_rows.dart';

/// Der Bereich Einstellungen (nur Chef): Geräte, Anzeige und Kassa in Karten.
/// Jede Änderung wird sofort gespeichert, der Bildschirm folgt dem Strom der
/// Einstellungen.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    super.key,
    required this.testingDevices,
    required this.onTestingDevices,
  });

  /// Die Seite "Geräte testen" ersetzt die Karten, bis sie geschlossen wird.
  /// Der Zustand liegt in der Kopfleiste-Hülle (`ShellScreen`), damit auch
  /// "Zurück" des Tablets sie schließen kann.
  final bool testingDevices;
  final ValueChanged<bool> onTestingDevices;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _failed = false;

  Future<void> _change(
    RegisterSettings Function(RegisterSettings s) change,
  ) async {
    final repo = ref.read(settingsRepositoryProvider);
    try {
      await repo.save(change(await repo.current()));
      if (mounted && _failed) setState(() => _failed = false);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.testingDevices) {
      return DeviceTestScreen(
        key: const Key('device-test'),
        onBack: () => widget.onTestingDevices(false),
      );
    }
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final s =
        ref.watch(settingsStreamProvider).value ?? const RegisterSettings();
    final business = ref.watch(catalogStreamProvider).value?.businessName;
    const gap = SizedBox(height: KassaTokens.spaceXxl);

    final devices = SettingsCard(
      title: 'Geräte an dieser Kassa',
      rows: [
        const PrinterPanel(),
        const CardPanel(),
        SettingsRow(
          title: 'Geldlade',
          help: 'Ausschalten, wenn es keine Geldlade gibt.',
          control: RowToggle(
            key: const Key('toggle-drawer'),
            label: 'Geldlade',
            value: s.cashDrawerEnabled,
            onChanged: (v) => _change((s) => s.copyWith(cashDrawerEnabled: v)),
          ),
        ),
        Pressable(
          key: const Key('open-device-test'),
          onTap: () => widget.onTestingDevices(true),
          semanticLabel: 'Geräte testen',
          child: SettingsRow(
            title: 'Geräte testen',
            help: 'Testdruck, Lade öffnen.',
            control: Icon(LucideIcons.chevronRight, size: 24, color: c.ink2),
          ),
        ),
      ],
    );
    final display = SettingsCard(
      title: 'Anzeige',
      rows: [
        SettingsRow(
          title: 'Artikel mit Bildern',
          help: 'Große Tasten mit Foto.',
          control: RowToggle(
            key: const Key('toggle-images'),
            label: 'Artikel mit Bildern',
            value: s.showImages,
            onChanged: (v) => _change((s) => s.copyWith(showImages: v)),
          ),
        ),
        SettingsRow(
          title: 'Ansicht',
          help: 'Dunkel ist angenehmer am Abend und in dunklen Räumen.',
          below: Align(
            alignment: Alignment.centerLeft,
            child: Segmented<AppThemeMode>(
              segments: const [
                (AppThemeMode.system, 'Wie das Tablet'),
                (AppThemeMode.light, 'Hell'),
                (AppThemeMode.dark, 'Dunkel'),
              ],
              selected: s.themeMode,
              keyFor: (m) => Key('theme-${m.name}'),
              onSelected: (m) => _change((s) => s.copyWith(themeMode: m)),
            ),
          ),
        ),
      ],
    );
    final register = SettingsCard(
      title: 'Kassa',
      rows: [
        SettingsRow(
          title: 'Storno nur durch den Chef',
          help: 'Mitarbeiter können Bons dann nicht stornieren.',
          control: RowToggle(
            key: const Key('toggle-void-chef'),
            label: 'Storno nur durch den Chef',
            value: s.voidRequiresChef,
            onChanged: (v) => _change((s) => s.copyWith(voidRequiresChef: v)),
          ),
        ),
        const ReimportPanel(),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: KassaTokens.receiptHeaderHeight,
            child: Row(
              children: [
                Text('Einstellungen', style: text.headlineMedium),
                const SizedBox(width: KassaTokens.spaceLg),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      business == null ? 'Kassa 1' : 'Kassa 1 bei $business',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelLarge!.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.ink2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_failed) const FailedHint(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: devices),
              const SizedBox(width: KassaTokens.spaceXxl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [display, gap, register],
                ),
              ),
            ],
          ),
          const SizedBox(height: KassaTokens.spaceXxl),
          Text(
            'Kassa Version $appVersion',
            key: const Key('app-version'),
            style: text.bodySmall!.copyWith(color: c.ink2),
          ),
        ],
      ),
    );
  }
}
