import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import 'amount_entry.dart';

/// Zustand A: Wie viel Wechselgeld lag am Morgen in der Lade? Speichern geht,
/// sobald etwas getippt ist (0 muss getippt werden).
class OpeningFloatSheet extends StatelessWidget {
  const OpeningFloatSheet({
    super.key,
    required this.drawer,
    required this.input,
    required this.onKey,
    required this.onSave,
    required this.failed,
  });

  final bool drawer;
  final KeypadInput input;
  final ValueChanged<String> onKey;

  /// `null`, solange nichts getippt ist oder gerade gespeichert wird.
  final VoidCallback? onSave;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    return CloseColumn(
      title: 'Wechselgeld',
      failed: failed,
      content: [
        FieldLabel(
          drawer
              ? 'Wie viel Wechselgeld war am Morgen in der Lade?'
              : 'Wie viel Wechselgeld war am Morgen da?',
        ),
        const SizedBox(height: KassaTokens.spaceMd),
        AmountEntry(input: input, onKey: onKey),
      ],
      bottom: PrimaryButton(
        key: const Key('set-float'),
        label: 'Wechselgeld speichern',
        height: KassaTokens.mainActionHeight,
        onPressed: input.isEmpty ? null : onSave,
      ),
    );
  }
}
