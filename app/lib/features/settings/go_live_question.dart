import 'package:material_ui/material_ui.dart';

import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import 'probe_question.dart';

const _message =
    'Das lässt sich nicht zurücknehmen. Ab jetzt ist jeder Bon ein echter Bon '
    'für das Finanzamt.';
const _probeEnds = 'Die laufende Probe endet mit einem Schlussbeleg.';

/// Fragt vor der Inbetriebnahme genau einmal nach ("Jetzt in Betrieb
/// nehmen?"); mit [probe] steht dazu, dass die laufende Probe mit einem
/// Schlussbeleg endet. true bei "In Betrieb nehmen" (`go-live-confirm`),
/// false bei "Abbrechen" (`go-live-cancel`) oder "Zurück". Die Antwort zählt
/// nur einmal: Ein zweites Antippen, während das Blatt schon geht, tut
/// nichts.
Future<bool> showGoLiveQuestion(
  BuildContext context, {
  required bool probe,
}) async {
  final answer = await showSettingsSheet<bool>(
    context,
    builder: (context) => _GoLiveQuestion(probe: probe),
  );
  return answer ?? false;
}

class _GoLiveQuestion extends StatefulWidget {
  const _GoLiveQuestion({required this.probe});

  final bool probe;

  @override
  State<_GoLiveQuestion> createState() => _GoLiveQuestionState();
}

class _GoLiveQuestionState extends State<_GoLiveQuestion> {
  bool _closing = false;

  void _close(bool answer) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(answer);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSheet(
      key: const Key('go-live-question'),
      title: 'Jetzt in Betrieb nehmen?',
      message: widget.probe ? '$_message\n\n$_probeEnds' : _message,
      children: [
        Row(
          children: [
            SizedBox(
              width: 150,
              child: PrimaryButton(
                key: const Key('go-live-cancel'),
                label: 'Abbrechen',
                filled: false,
                height: 64,
                onPressed: () => _close(false),
              ),
            ),
            const SizedBox(width: KassaTokens.spaceXl),
            Expanded(
              child: PrimaryButton(
                key: const Key('go-live-confirm'),
                label: 'In Betrieb nehmen',
                height: 64,
                onPressed: () => _close(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
