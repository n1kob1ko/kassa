import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../ui/tokens.dart';
import 'cash_sheet.dart';

/// "Warte auf Karte": die rechte Spalte, solange das Terminal die Zahlung
/// annimmt. SumUp legt seinen eigenen Bildschirm darüber, abgebrochen wird dort;
/// darum hat die Spalte keine Taste.
class CardWait extends StatelessWidget {
  const CardWait({super.key, required this.amountCents});

  final int amountCents;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return PayColumnFrame(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          key: const Key('card-wait'),
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: c.accentSoft,
            borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
          ),
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _PulsingDot(),
                    const SizedBox(width: KassaTokens.spaceLg),
                    Flexible(
                      child: Text(
                        'Warte auf Karte',
                        style: text.headlineMedium!.copyWith(
                          color: c.accentInk,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KassaTokens.spaceXxl),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatEuro(amountCents),
                    key: const Key('card-wait-amount'),
                    maxLines: 1,
                    style: text.displayLarge!.copyWith(
                      color: c.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: KassaTokens.spaceXxl),
                Text(
                  'Der Kunde hält Karte oder Handy an das Gerät.',
                  style: text.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: c.accentInk,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Punkt von 14 dp, der leise pulsiert. Mit "Animationen entfernen" steht er
/// still.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: KassaTokens.motionSlow,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    if (still) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
    return ExcludeSemantics(
      child: FadeTransition(
        key: const Key('card-wait-dot'),
        opacity: still
            ? const AlwaysStoppedAnimation(1.0)
            : Tween(begin: 0.35, end: 1.0).animate(
                CurvedAnimation(
                  parent: _controller,
                  curve: KassaTokens.motionCurve,
                ),
              ),
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
