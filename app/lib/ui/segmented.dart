import 'package:material_ui/material_ui.dart';

import 'pressable.dart';
import 'tokens.dart';

/// Umschalter (Segmente), z. B. "Mit Bildern" und "Kompakt". Knöpfe sind 44 dp
/// hoch gezeichnet, ihre Antippfläche ist mindestens 48 dp hoch.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelected,
    this.keyFor,
    this.expand = false,
  });

  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T> onSelected;

  /// Schlüssel eines Segments. Ohne Angabe `segment-<Beschriftung>`.
  final Key Function(T value)? keyFor;

  /// Über die ganze Breite, alle Segmente gleich breit.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final instant = MediaQuery.disableAnimationsOf(context);
    final duration = instant ? Duration.zero : KassaTokens.motionFast;
    return Container(
      // 44 dp Knopf + 2 x 3 dp = 50 dp. Die Tippfläche (48 dp) nutzt 2 dp
      // davon, der Regler bleibt 50 dp hoch.
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: c.fill2,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) const SizedBox(width: KassaTokens.spaceXxs),
            _fill(
              Builder(
                builder: (context) {
                  final (value, label) = segments[i];
                  final active = value == selected;
                  return Pressable(
                    key: keyFor?.call(value) ?? Key('segment-$label'),
                    onTap: () => onSelected(value),
                    minTapSize: const Size(0, KassaTokens.minTap),
                    child: AnimatedContainer(
                      duration: duration,
                      curve: Curves.linear,
                      height: KassaTokens.drawnControlHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? c.card : const Color(0x00000000),
                        borderRadius: BorderRadius.circular(
                          KassaTokens.radiusMd,
                        ),
                        boxShadow: active ? c.cardShadow : null,
                      ),
                      child: Text(
                        label,
                        // Bricht eine lange Beschriftung um (drei Segmente
                        // über die ganze Breite), steht sie mittig.
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge!.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: active ? c.ink : c.ink2,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fill(Widget segment) => expand ? Expanded(child: segment) : segment;
}
