import 'package:material_ui/material_ui.dart';

import 'pressable.dart';
import 'tokens.dart';

/// Schalter mit Beschriftung links. Antippfläche 64 x 48, Bahn 52 x 32,
/// Knopf 26 x 26 mit 3 dp Rand zur Bahn. Ohne [onChanged] ausgeschaltet.
class AppToggle extends StatelessWidget {
  const AppToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final instant = MediaQuery.disableAnimationsOf(context);
    final duration = instant ? Duration.zero : KassaTokens.motionSwitch;
    final onChanged = this.onChanged;
    // Eingeschaltet liegt der Knopf am Ende der Zeile, in Arabisch links.
    final knobRight =
        value != (Directionality.of(context) == TextDirection.rtl);

    final track = SizedBox(
      key: const Key('toggle-hit'),
      width: 64,
      height: KassaTokens.minTap,
      child: Center(
        child: AnimatedContainer(
          duration: duration,
          curve: KassaTokens.motionCurve,
          width: 52,
          height: 32,
          decoration: BoxDecoration(
            color: value ? c.accent : c.fill2,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: duration,
                curve: KassaTokens.motionCurve,
                left: knobRight ? 23 : 3,
                top: 3,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFFFF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x40101828),
                        offset: Offset(0, 1),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      toggled: value,
      label: label,
      excludeSemantics: true,
      onTap: onChanged == null ? null : () => onChanged(!value),
      child: Pressable(
        onTap: onChanged == null ? null : () => onChanged(!value),
        semanticLabel: null,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium!
                    .copyWith(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            track,
          ],
        ),
      ),
    );
  }
}
