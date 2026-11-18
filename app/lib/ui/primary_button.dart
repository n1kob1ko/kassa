import 'package:material_ui/material_ui.dart';

import 'pressable.dart';
import 'tokens.dart';

/// Hauptaktion. [filled] ist der Akzent (Petrol, weiße Schrift), sonst die
/// ruhige Fläche (`fill`, `ink`). [solid] ist die dunkle Aktion (`solid`,
/// `solidInk`), z. B. "Karte". [muted] ist der Zustand "es fehlt noch etwas":
/// `fill` mit `ink2`, ohne Abdunkeln. Ohne [onPressed] ausgeschaltet (Deckkraft
/// 0,4). Höhe 72, für Bezahlen und Abschließen [KassaTokens.mainActionHeight].
/// [icon] steht links neben der Beschriftung, [labelSize] überschreibt die
/// Schriftgröße (Bar und Karte: 22).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.sublabel,
    this.filled = true,
    this.solid = false,
    this.muted = false,
    this.icon,
    this.leading,
    this.labelSize,
    this.height = KassaTokens.primaryActionHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? sublabel;
  final bool filled;
  final bool solid;
  final bool muted;
  final IconData? icon;

  /// Eigenes Zeichen links statt [icon], z. B. ein Fortschrittsring.
  final Widget? leading;
  final double? labelSize;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final Color bg;
    final Color fg;
    if (muted) {
      bg = c.fill;
      fg = c.ink2;
    } else if (solid) {
      bg = c.solid;
      fg = c.solidInk;
    } else if (filled) {
      bg = c.accent;
      fg = c.onAccent;
    } else {
      bg = c.fill;
      fg = c.ink;
    }
    final base = Theme.of(context).textTheme.titleLarge!;
    final strong = filled || solid || muted;
    final labelStyle = strong
        ? base.copyWith(
            fontSize: labelSize ?? 20,
            fontWeight: FontWeight.w800,
            color: fg,
          )
        : base.copyWith(
            fontSize: labelSize ?? 17,
            fontWeight: FontWeight.w700,
            color: fg,
          );
    final text = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: labelStyle,
    );
    return Pressable(
      key: Key('primary-$label'),
      onTap: onPressed,
      dimWhenDisabled: !muted,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: KassaTokens.spaceXxl),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon == null && leading == null)
              text
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  leading ?? Icon(icon, size: 26, color: fg),
                  const SizedBox(width: KassaTokens.spaceLg),
                  Flexible(child: text),
                ],
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
