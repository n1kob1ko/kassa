import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../app.dart' show appLanguageProvider;
import '../core/app_language.dart';
import '../data/providers.dart';
import '../l10n/generated/l10n.dart';
import 'pressable.dart';
import 'tokens.dart';

/// Fünf große Tasten nebeneinander, eine je Sprache, jede mit ihrem Namen in
/// der eigenen Schrift. Die gewählte ist Petrol mit Haken. Schlüssel der
/// Tasten: `<keyPrefix>-<Kürzel>`, zum Beispiel `language-en`.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.keyPrefix = 'language',
  });

  final AppLanguage value;
  final ValueChanged<AppLanguage> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final l in AppLanguage.values) ...[
          if (l.index > 0) const SizedBox(width: KassaTokens.spaceMd),
          Expanded(
            child: _LanguageButton(
              key: Key('$keyPrefix-${l.name}'),
              language: l,
              selected: l == value,
              onTap: () => onChanged(l),
            ),
          ),
        ],
      ],
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    super.key,
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final instant = MediaQuery.disableAnimationsOf(context);
    final ink = selected ? c.onAccent : c.ink;
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: language.nativeName,
      child: AnimatedContainer(
        duration: instant ? Duration.zero : KassaTokens.motionFast,
        curve: Curves.linear,
        height: KassaTokens.languageButtonHeight,
        padding: const EdgeInsets.symmetric(horizontal: KassaTokens.spaceMd),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.accent : c.fill,
          borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gewählt nicht nur durch Farbe: der Haken.
            if (selected) ...[
              Icon(LucideIcons.check, size: 18, color: ink),
              const SizedBox(width: KassaTokens.spaceSm),
            ],
            Flexible(
              child: Text(
                language.nativeName,
                // Der Name steht in seiner eigenen Sprache, auch auf einem
                // deutschen Bildschirm: Schrift und Zeichen wählt Flutter
                // nach dieser Sprache.
                locale: language.locale,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontFamily: KassaTokens.fontFamily,
                  fontFamilyFallback: KassaTokens.fontFallback,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Öffnet die fünf Tasten als Blatt von unten (Anmeldebildschirm). Es lässt
/// sich nach unten wischen und mit einem Tipp daneben schließen. Ein Tipp auf
/// eine Sprache schließt es und stellt sofort um.
Future<void> showLanguageSheet(BuildContext context, WidgetRef ref) {
  final c = KassaColors.of(context);
  final instant = MediaQuery.disableAnimationsOf(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.card,
    barrierColor: KassaTokens.scrim,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(KassaTokens.radiusCard),
      ),
    ),
    sheetAnimationStyle: instant
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: KassaTokens.motionSnack,
            reverseDuration: KassaTokens.motionFade,
            curve: KassaTokens.motionCurve,
          ),
    builder: (context) => const _LanguageSheet(),
  );
}

class _LanguageSheet extends ConsumerWidget {
  const _LanguageSheet();

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    AppLanguage language,
  ) async {
    final repo = ref.read(settingsRepositoryProvider);
    Navigator.of(context).pop();
    try {
      await repo.save((await repo.current()).copyWith(language: language));
    } catch (_) {
      // Gescheitert: die Taste zeigt weiter die bisherige Sprache.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        KassaTokens.spaceHuge,
        0,
        KassaTokens.spaceHuge,
        KassaTokens.spaceHuge + bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            L10n.of(context).languageSheetTitle,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: KassaTokens.spaceXxl),
          LanguagePicker(
            value: ref.watch(appLanguageProvider),
            onChanged: (l) => _choose(context, ref, l),
          ),
        ],
      ),
    );
  }
}
