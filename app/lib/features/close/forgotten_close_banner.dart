import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../ui/pressable.dart';
import '../../ui/tokens.dart';

/// Streifen unter der Kopfleiste, solange der letzte Tag nicht abgeschlossen
/// ist. Der Chef hat dazu die Taste "Jetzt abschließen" ([onClose]),
/// Mitarbeiter sehen nur den Text. Bonieren bleibt möglich.
class ForgottenCloseBanner extends ConsumerWidget {
  const ForgottenCloseBanner({
    super.key,
    required this.isChef,
    required this.onClose,
  });

  final bool isChef;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(forgottenCloseProvider)) return const SizedBox.shrink();
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      key: const Key('forgotten-close'),
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: c.warnBg,
      child: Row(
        children: [
          Icon(LucideIcons.triangleAlert, size: 20, color: c.warnInk),
          const SizedBox(width: KassaTokens.spaceLg),
          Expanded(
            child: Text(
              'Der letzte Tag ist noch nicht abgeschlossen.',
              style: text.bodyMedium!.copyWith(color: c.warnInk),
            ),
          ),
          if (isChef) ...[
            const SizedBox(width: KassaTokens.spaceXl),
            Pressable(
              key: const Key('forgotten-close-go'),
              onTap: onClose,
              child: Container(
                height: KassaTokens.minTap,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.warnInk,
                  borderRadius: BorderRadius.circular(KassaTokens.radiusLg),
                ),
                child: Text(
                  'Jetzt abschließen',
                  maxLines: 1,
                  style: text.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w800,
                    color: c.warnBg,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
