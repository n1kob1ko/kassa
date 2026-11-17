// Das Balkendiagramm der Übersicht, selbst gezeichnet (kein Diagramm-Paket).

import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/stats.dart';
import '../../ui/tokens.dart';

const double _axisWidth = 52;
const double _labelRowHeight = 28;
const double _maxBarWidth = 24;

/// Welche Beschriftungen unter den Balken stehen: alle bis 12 Balken, jeder
/// zweite bis 24, jeder fünfte darüber. Der gewählte Balken immer.
///
/// Ein regelmäßiger Balken verliert seine Beschriftung, wenn sie die des
/// gewählten Balkens berührt: [minGap] ist der kleinste Abstand in Balken
/// (aus Beschriftungsbreite und Spaltenbreite berechnet).
bool showsAxisLabel(int index, int count, int selected, {int minGap = 1}) {
  if (index == selected) return true;
  if ((index - selected).abs() < minGap) return false;
  if (count <= 12) return true;
  if (count <= 24) return index % 2 == 0;
  return index % 5 == 0;
}

/// Linien bei runden Beträgen (zwei oder drei, wenn der Platz reicht) in Cent.
List<int> gridLines(int topCents) {
  if (topCents <= 0) return const [];
  var step = 10; // 0,10 €
  var mantissaIndex = 0;
  const mantissas = [1, 2, 5];
  var magnitude = 10;
  while (topCents ~/ step > 3) {
    mantissaIndex++;
    if (mantissaIndex == mantissas.length) {
      mantissaIndex = 0;
      magnitude *= 10;
    }
    step = magnitude * mantissas[mantissaIndex];
  }
  return [for (var v = step; v <= topCents; v += step) v];
}

String axisLabel(int cents) =>
    cents % 100 == 0 ? '${cents ~/ 100} €' : formatEuro(cents);

/// Balken pro Stunde oder Tag. Ein Tipp auf die Spalte eines Balkens (volle
/// Breite und Höhe des Diagramms) wählt ihn. Der gewählte Balken ist in
/// `accentInk` gezeichnet, die anderen in `accent`.
class RevenueChart extends StatelessWidget {
  const RevenueChart({
    super.key,
    required this.buckets,
    required this.selected,
    required this.onSelect,
    required this.semanticLabelFor,
  });

  final List<Bucket> buckets;
  final int selected;
  final ValueChanged<int> onSelect;

  /// Vorlesetext eines Balkens, z. B. "11 bis 12 Uhr, 18,20 €".
  final String Function(Bucket) semanticLabelFor;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final instant = MediaQuery.disableAnimationsOf(context);
    var top = 0;
    for (final b in buckets) {
      if (b.cents > top) top = b.cents;
    }
    // Nur negative Beträge: die Achse zeigt trotzdem eine Skala.
    final scaleTop = top > 0 ? top : 10000;
    final lines = gridLines(scaleTop);
    final axisStyle = text.labelMedium!.copyWith(fontSize: 12.5, color: c.ink2);

    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, outer) {
        // Einmal je Aufbau gemessen (nicht je Bild der Animation): die breiteste
        // Beschriftung, fett wie der gewählte Balken und mit der Textgröße des
        // Geräts, gegen die echte Spaltenbreite. So viele Balken Abstand braucht
        // eine Beschriftung zum gewählten Balken.
        final column = (outer.maxWidth - _axisWidth) / buckets.length;
        var widest = 0.0;
        for (final b in buckets) {
          final painter = TextPainter(
            text: TextSpan(
              text: b.label,
              style: axisStyle.copyWith(fontWeight: FontWeight.w800),
            ),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          if (painter.width > widest) widest = painter.width;
          painter.dispose();
        }
        final minGap = column <= 0 ? 1 : ((widest + 6) / column).ceil();
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: instant ? 1 : 0, end: 1),
          duration: instant ? Duration.zero : KassaTokens.motionSlow,
          curve: KassaTokens.motionCurve,
          builder: (context, grow, _) => Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final h = box.maxHeight;
                    double y(int cents) => h - h * cents / scaleTop;
                    return Row(
                      children: [
                        SizedBox(
                          width: _axisWidth,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              for (final v in [0, ...lines])
                                Positioned(
                                  left: 0,
                                  right: 12,
                                  top: y(v) - 9,
                                  height: 18,
                                  child: Text(
                                    axisLabel(v),
                                    maxLines: 1,
                                    textAlign: TextAlign.right,
                                    style: axisStyle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              for (final v in [0, ...lines])
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: y(v) - (v == 0 ? 1 : 0.5),
                                  height: v == 0 ? 1.5 : 1,
                                  child: ColoredBox(color: c.line),
                                ),
                              Row(
                                children: [
                                  for (var i = 0; i < buckets.length; i++)
                                    Expanded(
                                      child: _BarColumn(
                                        key: Key('bar-$i'),
                                        height: buckets[i].cents <= 0
                                            ? 0
                                            : h *
                                                  buckets[i].cents /
                                                  scaleTop *
                                                  grow,
                                        color: i == selected
                                            ? c.accentInk
                                            : c.accent,
                                        selected: i == selected,
                                        semanticLabel: semanticLabelFor(
                                          buckets[i],
                                        ),
                                        onTap: () => onSelect(i),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(
                height: _labelRowHeight,
                child: Row(
                  children: [
                    const SizedBox(width: _axisWidth),
                    for (var i = 0; i < buckets.length; i++)
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child:
                              showsAxisLabel(
                                i,
                                buckets.length,
                                selected,
                                minGap: minGap,
                              )
                              ? OverflowBox(
                                  maxWidth: 64,
                                  child: Text(
                                    buckets[i].label,
                                    key: Key('axis-label-$i'),
                                    maxLines: 1,
                                    softWrap: false,
                                    textAlign: TextAlign.center,
                                    style: axisStyle.copyWith(
                                      color: i == selected ? c.ink : c.ink2,
                                      fontWeight: i == selected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({
    super.key,
    required this.height,
    required this.color,
    required this.selected,
    required this.semanticLabel,
    required this.onTap,
  });

  final double height;
  final Color color;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      selected: selected,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, box) => Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: (box.maxWidth * 0.62).clamp(0, _maxBarWidth).toDouble(),
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
