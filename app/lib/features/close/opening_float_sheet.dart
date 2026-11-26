import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../l10n/generated/l10n.dart';
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
    final l = L10n.of(context);
    return CloseColumn(
      title: l.closeFloatTitle,
      failed: failed,
      content: [
        FieldLabel(drawer ? l.closeFloatQuestionDrawer : l.closeFloatQuestion),
        const SizedBox(height: KassaTokens.spaceMd),
        AmountEntry(input: input, onKey: onKey),
      ],
      bottom: PrimaryButton(
        key: const Key('set-float'),
        label: l.closeSaveFloat,
        height: KassaTokens.mainActionHeight,
        onPressed: input.isEmpty ? null : onSave,
      ),
    );
  }
}
