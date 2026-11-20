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
import 'card_check_screen.dart';
import 'card_panel.dart';
import 'connection_check_screen.dart';
import 'credentials_screen.dart';
import 'device_test_screen.dart';
import 'printer_panel.dart';
import 'reimport_panel.dart';
import 'server_panel.dart';
import 'settings_rows.dart';
import 'signature_panel.dart';

/// Der Bereich Einstellungen (nur Chef): links Signatur und Kassa, rechts
/// Geräte, Anzeige und Server (Signatur oben links wie im Entwurf `s1b-2`).
/// Jede Änderung wird sofort gespeichert, der Bildschirm folgt dem Strom der
/// Einstellungen.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    super.key,
    required this.testingDevices,
    required this.onTestingDevices,
    required this.checkingCard,
    required this.onCheckingCard,
    required this.checkingConnection,
    required this.onCheckingConnection,
    required this.credentials,
    required this.onCredentials,
  });

  /// Die Seite "Geräte testen" ersetzt die Karten, bis sie geschlossen wird.
  /// Der Zustand liegt in der Kopfleiste-Hülle (`ShellScreen`), damit auch
  /// "Zurück" des Tablets sie schließen kann.
  final bool testingDevices;
  final ValueChanged<bool> onTestingDevices;

  /// Die Seite "Karte prüfen" ersetzt die Karten wie "Geräte testen".
  final bool checkingCard;
  final ValueChanged<bool> onCheckingCard;

  /// Die Seite "Verbindung prüfen" ersetzt die Karten wie "Karte prüfen",
  /// geöffnet wie angegeben; `null` zeigt die Karten.
  final ConnectionCheckOpening? checkingConnection;
  final ValueChanged<ConnectionCheckOpening?> onCheckingConnection;

  /// Der Weg "Zugangsdaten von A-Trust" ersetzt die Karten wie "Verbindung
  /// prüfen"; `null` zeigt die Karten.
  final CredentialsRoute? credentials;
  final ValueChanged<CredentialsRoute?> onCredentials;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _failed = false;

  /// Das Ergebnis eines Wegs, der eben geschlossen hat ("Die Kassa ist in
  /// Betrieb."), für die Karte "Signatur". Geht weg, sobald eine Seite an
  /// Stelle der Karten öffnet.
  String? _announcement;

  @override
  void didUpdateWidget(SettingsScreen old) {
    super.didUpdateWidget(old);
    if (widget.testingDevices ||
        widget.checkingCard ||
        widget.checkingConnection != null ||
        widget.credentials != null) {
      _announcement = null;
    }
  }

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
    if (widget.checkingCard) {
      return CardCheckScreen(
        key: const Key('card-check'),
        onBack: () => widget.onCheckingCard(false),
      );
    }
    if (widget.checkingConnection case final opening?) {
      return ConnectionCheckScreen(
        key: const Key('connection-check-screen'),
        opening: opening,
        onBack: () => widget.onCheckingConnection(null),
      );
    }
    if (widget.credentials case final route?) {
      return CredentialsScreen(
        key: const Key('credentials-screen'),
        edit: route.edit,
        checking: route.check,
        onChecking: (check) =>
            widget.onCredentials(CredentialsRoute(check: check)),
        setup: route.setup,
        onSetup: (facts) => widget.onCredentials(
          facts == null
              ? const CredentialsRoute()
              : CredentialsRoute(setup: facts),
        ),
        onLive: () {
          setState(() => _announcement = 'Die Kassa ist in Betrieb.');
          widget.onCredentials(null);
        },
        onBack: () => widget.onCredentials(null),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SignaturePanel(
                      announcement: _announcement,
                      onOpenCardCheck: () => widget.onCheckingCard(true),
                      onOpenConnectionCheck: widget.onCheckingConnection,
                    ),
                    gap,
                    register,
                  ],
                ),
              ),
              const SizedBox(width: KassaTokens.spaceXxl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [devices, gap, display, gap, const ServerPanel()],
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
