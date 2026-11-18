import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/pressable.dart';
import '../../ui/tokens.dart';
import 'settings_rows.dart';

/// Die Karte "Signatur" der Einstellungen (`signature-card`): der Stand der
/// Signatur der Bons und die Zeile "Karte prüfen" (`open-card-check`), die
/// [onOpenCardCheck] ruft.
class SignaturePanel extends StatelessWidget {
  const SignaturePanel({super.key, required this.onOpenCardCheck});

  final VoidCallback onOpenCardCheck;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return SettingsCard(
      key: const Key('signature-card'),
      title: 'Signatur',
      rows: [
        const SettingsRow(
          title: 'Signatur der Bons',
          help: 'Für die Registrierkassen-Pflicht. Noch nicht eingerichtet.',
          control: NeutralPill('Nicht eingerichtet'),
        ),
        Pressable(
          key: const Key('open-card-check'),
          onTap: onOpenCardCheck,
          semanticLabel: 'Karte prüfen',
          child: SettingsRow(
            title: 'Karte prüfen',
            help: 'Kartenleser und Signaturkarte ausprobieren.',
            control: Icon(LucideIcons.chevronRight, size: 24, color: c.ink2),
          ),
        ),
      ],
    );
  }
}
