import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// Gemeinsamer Druck-Rückmeldung für alle Tasten: beim Aufsetzen des Fingers
/// sofort Maßstab 0,97 und Helligkeit 0,95 (120 ms). Mit
/// `MediaQuery.disableAnimations` entfallen die Übergänge.
///
/// [minTapSize] vergrößert die Antippfläche unsichtbar (Hit Slop), das
/// Aussehen von [child] bleibt gleich. Ohne [onTap] ist die Fläche
/// ausgeschaltet (Deckkraft 0,4, keine Reaktion).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onTap,
    required this.child,
    this.minTapSize = Size.zero,
    this.semanticLabel,
    this.dimWhenDisabled = true,
    this.selected,
  });

  final VoidCallback? onTap;
  final Widget child;
  final Size minTapSize;
  final String? semanticLabel;

  /// Ausgeschaltet mit Deckkraft 0,4 zeigen. Wer den Zustand selbst malt,
  /// stellt das aus.
  final bool dimWhenDisabled;

  /// Für Tasten einer Auswahl: ob diese gewählt ist (Semantik).
  final bool? selected;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final instant = MediaQuery.disableAnimationsOf(context);
    final duration = instant ? Duration.zero : KassaTokens.motionFast;
    final pressed = _down && enabled;

    Widget content = AnimatedScale(
      scale: pressed ? KassaTokens.pressScale : 1.0,
      duration: duration,
      curve: KassaTokens.motionCurve,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: pressed ? KassaTokens.pressBrightness : 1.0),
        duration: duration,
        builder: (context, b, child) {
          // Immer derselbe Baum: bei b = 1 filtert Weiß nichts, so behält
          // das Kind seinen Zustand (laufende Übergänge reißen nicht ab).
          final v = (b * 255).round();
          return ColorFiltered(
            colorFilter: ColorFilter.mode(
              Color.fromARGB(255, v, v, v),
              BlendMode.modulate,
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );

    if (!enabled && widget.dimWhenDisabled) {
      content = Opacity(opacity: KassaTokens.disabledOpacity, child: content);
    }

    if (widget.minTapSize != Size.zero) {
      content = ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.minTapSize.width,
          minHeight: widget.minTapSize.height,
        ),
        child: Center(widthFactor: 1, heightFactor: 1, child: content),
      );
    }

    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onTap,
        child: content,
      ),
    );
  }
}
