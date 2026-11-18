import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// Die Felder für den Kopplungscode: [length] Stück, nach der Hälfte ein etwas
/// größerer Abstand. Das nächste freie Feld trägt den Akzentrand, bei
/// [error] sind alle Ränder rot. Es ist nur eine Anzeige: getippt wird auf
/// dem Zahlenfeld.
class CodeBoxes extends StatelessWidget {
  const CodeBoxes({
    super.key,
    required this.value,
    this.length = 8,
    this.error = false,
  });

  final String value;
  final int length;
  final bool error;

  static const double boxWidth = 40;
  static const double boxHeight = 52;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final instant = MediaQuery.disableAnimationsOf(context);
    final half = length ~/ 2;
    return Semantics(
      label: '${value.length} von $length Ziffern eingegeben',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < length; i++) ...[
            if (i > 0)
              SizedBox(
                width: i == half ? KassaTokens.spaceHuge : KassaTokens.spaceMd,
              ),
            AnimatedContainer(
              key: Key('code-box-$i'),
              duration: instant ? Duration.zero : KassaTokens.motionFast,
              curve: Curves.linear,
              width: boxWidth,
              height: boxHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: error ? c.card : c.fill,
                borderRadius: BorderRadius.circular(KassaTokens.radiusMd),
                border: Border.all(
                  color: error
                      ? c.red
                      : i == value.length
                      ? c.accent
                      : i < value.length
                      ? c.line
                      : const Color(0x00000000),
                  width: KassaTokens.borderStrong,
                ),
              ),
              child: Text(
                i < value.length ? value[i] : '',
                style: text.headlineMedium!.copyWith(fontSize: 26),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
