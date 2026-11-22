import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/pressable.dart';
import '../../ui/tokens.dart';
import 'card_check_screen.dart' show checkCardDecoration;

/// Die Seite "Womit signiert die Kassa?" im Bereich Einstellungen, geöffnet
/// mit "Signatur einrichten": zwei große Flächen nebeneinander, links die
/// Signaturkarte ([onCard], weiter zu "Karte und PIN"), rechts A-Trust
/// online ([onOnline], weiter zu den Zugangsdaten von A-Trust).
class SignerChoiceScreen extends StatelessWidget {
  const SignerChoiceScreen({
    super.key,
    required this.onCard,
    required this.onOnline,
    required this.onBack,
  });

  final VoidCallback onCard;
  final VoidCallback onOnline;

  /// Zurück zu den Einstellungen.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      key: const Key('signer-choice'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: KassaTokens.receiptHeaderHeight,
          padding: const EdgeInsets.only(left: 6, right: 16),
          child: Row(
            children: [
              Pressable(
                key: const Key('signer-choice-back'),
                onTap: onBack,
                semanticLabel: 'Zurück zu den Einstellungen',
                minTapSize: const Size(KassaTokens.minTap, KassaTokens.minTap),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.chevronLeft, size: 28, color: c.ink),
                    Text(
                      'Zurück',
                      style: text.titleMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KassaTokens.spaceXxl),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Womit signiert die Kassa?',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.headlineMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _Choice(
                      key: const Key('signer-choice-card'),
                      icon: LucideIcons.creditCard,
                      title: 'Signaturkarte am Kartenleser',
                      help:
                          'Ohne Internet. Die Karte muss immer im Leser '
                          'stecken.',
                      onTap: onCard,
                    ),
                  ),
                  const SizedBox(width: KassaTokens.spaceXxl),
                  Expanded(
                    child: _Choice(
                      key: const Key('signer-choice-online'),
                      icon: LucideIcons.globe,
                      title: 'A-Trust online',
                      help:
                          'Braucht Internet und die Zugangsdaten von '
                          'A-Trust.',
                      onTap: onOnline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Eine der zwei Flächen: Zeichen, Titel, Hilfe und Pfeil, ganz antippbar.
class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.icon,
    required this.title,
    required this.help,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String help;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      semanticLabel: '$title. $help',
      child: Container(
        constraints: const BoxConstraints(minHeight: 160),
        padding: const EdgeInsets.all(KassaTokens.spaceHuge),
        decoration: checkCardDecoration(c),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: c.accentInk),
              ),
            ),
            const SizedBox(width: KassaTokens.spaceHuge),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: text.titleLarge!.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: KassaTokens.spaceMd),
                  Text(
                    help,
                    style: text.bodyMedium!.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                      color: c.ink2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: KassaTokens.spaceXl),
            Icon(LucideIcons.chevronRight, size: 28, color: c.ink2),
          ],
        ),
      ),
    );
  }
}
