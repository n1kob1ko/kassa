import 'package:material_ui/material_ui.dart';

import 'pressable.dart';
import 'tokens.dart';

/// Hauptaktion. [filled] ist der Akzent (Petrol, weiße Schrift), sonst die
/// ruhige Fläche (`fill`, `ink`). Ohne [onPressed] ausgeschaltet (Deckkraft
/// 0,4). Höhe 72, für Bezahlen und Abschließen [KassaTokens.mainActionHeight].
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.sublabel,
    this.filled = true,
    this.height = KassaTokens.primaryActionHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? sublabel;
  final bool filled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final fg = filled ? c.onAccent : c.ink;
    final base = Theme.of(context).textTheme.titleLarge!;
    final labelStyle = filled
        ? base.copyWith(fontSize: 20, fontWeight: FontWeight.w800, color: fg)
        : base.copyWith(fontSize: 17, fontWeight: FontWeight.w700, color: fg);
    return Pressable(
      key: Key('primary-$label'),
      onTap: onPressed,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: KassaTokens.spaceXxl),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? c.accent : c.fill,
          borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
            if (sublabel != null)
              Text(
                sublabel!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: fg.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
