import 'package:material_ui/material_ui.dart';

import 'keypad.dart';
import 'primary_button.dart';
import 'tokens.dart';

/// Ob [text] eine IPv4-Adresse ist: vier Zahlen von 0 bis 255 mit Punkten.
bool isIpv4Address(String text) {
  final parts = text.split('.');
  if (parts.length != 4) return false;
  for (final part in parts) {
    if (part.isEmpty || part.length > 3) return false;
    final n = int.tryParse(part);
    if (n == null || n > 255) return false;
  }
  return true;
}

/// Adresse eintippen ohne Systemtastatur: Anzeige, Zahlenfeld mit Ziffern,
/// Punkt und Löschen, "Zurück" und "Übernehmen". "Übernehmen" ist erst aktiv,
/// wenn vier Zahlen von 0 bis 255 dastehen.
class AddressKeypad extends StatefulWidget {
  const AddressKeypad({
    super.key,
    required this.onSubmit,
    required this.onCancel,
  });

  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;

  @override
  State<AddressKeypad> createState() => _AddressKeypadState();
}

class _AddressKeypadState extends State<AddressKeypad> {
  String _input = '';

  void _onKey(String key) {
    setState(() {
      if (key == 'back') {
        if (_input.isNotEmpty) _input = _input.substring(0, _input.length - 1);
      } else if (key == '.') {
        // Nach einer Zahl, höchstens drei Punkte.
        if (_input.isNotEmpty &&
            !_input.endsWith('.') &&
            '.'.allMatches(_input).length < 3) {
          _input += '.';
        }
      } else {
        // Höchstens drei Ziffern je Zahl.
        final last = _input.split('.').last;
        if (last.length < 3) _input += key;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final empty = _input.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: KassaTokens.keypadInputHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerRight,
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
            border: Border.all(
              color: c.accent,
              width: KassaTokens.borderStrong,
            ),
          ),
          child: Semantics(
            liveRegion: true,
            label: 'Adresse des Druckers',
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _input,
                key: const Key('printer-address'),
                maxLines: 1,
                style: text.titleLarge!.copyWith(
                  fontSize: 30,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
        ),
        if (empty)
          Padding(
            padding: const EdgeInsets.only(top: KassaTokens.spaceSm),
            child: Text(
              'Vier Zahlen mit Punkten, zum Beispiel 192.168.1.50',
              style: text.bodySmall!.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: c.ink2,
              ),
            ),
          ),
        const SizedBox(height: KassaTokens.spaceMd),
        Keypad(onKey: _onKey, separator: '.'),
        const SizedBox(height: KassaTokens.spaceLg),
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                key: const Key('printer-address-cancel'),
                label: 'Zurück',
                filled: false,
                height: 60,
                onPressed: widget.onCancel,
              ),
            ),
            const SizedBox(width: KassaTokens.spaceLg),
            Expanded(
              child: PrimaryButton(
                key: const Key('printer-address-save'),
                label: 'Übernehmen',
                height: 60,
                onPressed: isIpv4Address(_input)
                    ? () => widget.onSubmit(_input)
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
