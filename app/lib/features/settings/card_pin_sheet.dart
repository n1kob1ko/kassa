import 'package:material_ui/material_ui.dart';

import '../../ui/keypad.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import 'settings_rows.dart';

/// Öffnet das Fenster für die PIN der Signaturkarte und gibt die PIN zurück
/// (4 oder 6 Ziffern), bei "Abbrechen" oder "Zurück" `null`.
///
/// Schutz der Karte: Das Fenster schickt nie von selbst ab, auch nicht nach
/// der 4. oder 6. Ziffer. Die Ziffern leben nur im Zustand des Fensters,
/// solange es offen ist; angezeigt wird je Platz ein Punkt, die Semantik sagt
/// nur, wie viele Ziffern es sind. Beim Schließen sind sie weg.
Future<String?> showCardPinSheet(BuildContext context) {
  final instant = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: false,
    barrierColor: KassaTokens.scrim,
    transitionDuration: instant ? Duration.zero : KassaTokens.motionFade,
    pageBuilder: (context, _, _) => const _CardPinSheet(),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: KassaTokens.motionCurve,
      ),
      child: child,
    ),
  );
}

class _CardPinSheet extends StatefulWidget {
  const _CardPinSheet();

  @override
  State<_CardPinSheet> createState() => _CardPinSheetState();
}

class _CardPinSheetState extends State<_CardPinSheet> {
  static const _places = 6;

  /// Die Ziffern, nur hier und nur solange das Fenster offen ist.
  String _digits = '';
  bool _closing = false;

  bool get _complete => _digits.length == 4 || _digits.length == 6;

  void _key(String key) {
    if (_closing) return;
    setState(() {
      if (key == 'back') {
        if (_digits.isNotEmpty) {
          _digits = _digits.substring(0, _digits.length - 1);
        }
      } else if (_digits.length < _places &&
          key.length == 1 &&
          key.codeUnitAt(0) >= 0x30 &&
          key.codeUnitAt(0) <= 0x39) {
        _digits += key;
      }
    });
  }

  void _close(String? result) {
    if (_closing) return;
    _closing = true;
    _digits = '';
    Navigator.of(context).pop(result);
  }

  void _submit() {
    if (!_complete) return;
    _close(_digits);
  }

  @override
  void dispose() {
    _digits = '';
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KassaTokens.spaceXxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Material(
            key: const Key('card-pin-sheet'),
            color: c.card,
            borderRadius: BorderRadius.circular(KassaTokens.radiusCard),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'PIN der Signaturkarte',
                      textAlign: TextAlign.center,
                      style: text.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: KassaTokens.spaceHuge),
                  const WarnBox(
                    'Das ist nicht deine Chef-PIN. Nach drei falschen '
                    'Versuchen sperrt sich die Karte.',
                  ),
                  const SizedBox(height: KassaTokens.spaceHuge),
                  _PinPlaces(filled: _digits.length, places: _places),
                  const SizedBox(height: KassaTokens.spaceHuge),
                  Keypad(onKey: _key, showComma: false),
                  const SizedBox(height: KassaTokens.spaceHuge),
                  Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: PrimaryButton(
                          key: const Key('card-pin-cancel'),
                          label: 'Abbrechen',
                          filled: false,
                          height: 64,
                          onPressed: () => _close(null),
                        ),
                      ),
                      const SizedBox(width: KassaTokens.spaceXl),
                      Expanded(
                        child: KeyedSubtree(
                          key: const Key('card-pin-submit'),
                          child: PrimaryButton(
                            label: 'Unterschrift erstellen',
                            height: 64,
                            onPressed: _complete ? _submit : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sechs Plätze: ein gefüllter zeigt einen Punkt, nie die Ziffer. Der
/// nächste freie Platz trägt den Akzentrand.
class _PinPlaces extends StatelessWidget {
  const _PinPlaces({required this.filled, required this.places});

  final int filled;
  final int places;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final instant = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      key: const Key('card-pin-slots'),
      container: true,
      label: '$filled von $places Ziffern eingegeben',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < places; i++) ...[
            if (i > 0) const SizedBox(width: KassaTokens.spaceMd),
            AnimatedContainer(
              duration: instant ? Duration.zero : KassaTokens.motionFast,
              curve: Curves.linear,
              width: 42,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i < filled ? c.card : c.fill,
                borderRadius: BorderRadius.circular(KassaTokens.radiusLg),
                border: Border.all(
                  color: i == filled
                      ? c.accent
                      : i < filled
                      ? c.line
                      : c.fill,
                  width: KassaTokens.borderStrong,
                ),
              ),
              child: i < filled
                  ? Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: c.ink,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
