import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_sync_providers.dart';
import '../../core/app_language.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/pressable.dart';
import '../../ui/tokens.dart';
import 'settings_rows.dart';

/// Die Karte "Kundenbon" der Einstellungen: wie der Kunde seinen Beleg
/// bekommt, drei Werte untereinander, jeder mit einer Zeile Erklärung. Die
/// ganze Zeile ist die Tippfläche, der gewählte Wert trägt einen Haken.
///
/// Die zwei digitalen Werte lassen sich nur wählen, wenn die Kassa mit dem
/// Server gekoppelt ist; sonst sind sie grau, und darunter steht warum. Ein
/// schon gespeicherter digitaler Wert bleibt auch ohne Kopplung stehen. Jede
/// Änderung geht über [onChange] und wird sofort gespeichert.
class ReceiptSection extends ConsumerWidget {
  const ReceiptSection({
    super.key,
    required this.settings,
    required this.onChange,
  });

  final RegisterSettings settings;
  final Future<void> Function(
    RegisterSettings Function(RegisterSettings s) change,
  )
  onChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    // Gekoppelt wie in der Karte "Server": die Kassa hat einen Platz beim
    // Server.
    final paired =
        ref.watch(hasServerProvider) &&
        (ref.watch(syncStateProvider).value?.hasRegister ?? false);
    final mode = settings.receiptMode;
    final digital = mode != ReceiptMode.alwaysPrint;

    Widget option(ReceiptMode value, String title, String info) {
      final enabled = paired || value == ReceiptMode.alwaysPrint;
      return _ModeRow(
        key: Key('receipt-mode-${value.name}'),
        title: title,
        info: info,
        selected: value == mode,
        onTap: enabled
            ? () => onChange((s) => s.copyWith(receiptMode: value))
            : null,
      );
    }

    return SettingsCard(
      key: const Key('receipt-section'),
      title: l.settingsReceiptTitle,
      rows: [
        option(
          ReceiptMode.alwaysPrint,
          l.settingsReceiptAlways,
          l.settingsReceiptAlwaysInfo,
        ),
        option(
          ReceiptMode.printAndDigital,
          l.settingsReceiptBoth,
          l.settingsReceiptBothInfo,
        ),
        option(
          ReceiptMode.digitalOnRequest,
          l.settingsReceiptDigital,
          l.settingsReceiptDigitalInfo,
        ),
        if (!paired || digital)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!paired)
                  _Note(
                    l.settingsReceiptNeedsServer,
                    key: const Key('receipt-mode-needs-server'),
                  ),
                if (!paired && digital)
                  const SizedBox(height: KassaTokens.spaceMd),
                if (digital)
                  _Note(
                    l.settingsReceiptQrHint,
                    key: const Key('receipt-mode-qr-hint'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Ein Wert der Auswahl: Zeile der Einstellungen mit Titel und Erklärung,
/// am Ende ein Kreis, gewählt gefüllt mit Haken (nicht nur Farbe). Ohne
/// [onTap] ist sie grau und reagiert nicht.
class _ModeRow extends StatelessWidget {
  const _ModeRow({
    super.key,
    required this.title,
    required this.info,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String info;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: '$title. $info',
      child: SettingsRow(
        title: title,
        help: info,
        // So breit wie die Schalter der Zeilen darüber ([RowToggle]): der
        // Kreis steht mittig unter ihnen.
        control: SizedBox(
          width: 64,
          child: Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: selected ? c.accent : null,
                shape: BoxShape.circle,
                border: selected
                    ? null
                    : Border.all(
                        color: c.ink2,
                        width: KassaTokens.borderButton,
                      ),
              ),
              child: selected
                  ? Icon(LucideIcons.check, size: 16, color: c.onAccent)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Satz unter der Auswahl, in der Schrift der Hilfezeilen.
class _Note extends StatelessWidget {
  const _Note(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: c.ink2,
      ),
    );
  }
}
