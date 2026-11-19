import 'package:material_ui/material_ui.dart';

import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';

/// Welche Rückfrage: Probe-Signatur einschalten oder beenden, oder mit A-Trust
/// ausprobieren (Online-Probe).
enum ProbeQuestion { enable, disable, online }

/// Fragt vor dem Einschalten oder Beenden der Probe-Signatur nach. true bei
/// "Einschalten", "Beenden" bzw. "Weiter" (`rksv-question-confirm`), false bei
/// "Abbrechen" (`rksv-question-cancel`) oder "Zurück". Die Antwort zählt nur
/// einmal: Ein zweites Antippen, während das Blatt schon geht, tut nichts.
Future<bool> showProbeQuestion(
  BuildContext context,
  ProbeQuestion question,
) async {
  final answer = await showSettingsSheet<bool>(
    context,
    builder: (context) => _ProbeQuestion(question),
  );
  return answer ?? false;
}

/// Öffnet ein Blatt der Einstellungen in der Mitte, über einer Abdunkelung,
/// wie das Fenster für die PIN der Karte. Tippen daneben schließt es nicht.
Future<T?> showSettingsSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final instant = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierColor: KassaTokens.scrim,
    transitionDuration: instant ? Duration.zero : KassaTokens.motionFade,
    pageBuilder: (context, _, _) => builder(context),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: KassaTokens.motionCurve,
      ),
      child: child,
    ),
  );
}

/// Rahmen eines Blatts: Karte (520 dp breit, Rundung 20), Titel, Text und
/// darunter [children].
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({
    super.key,
    required this.title,
    required this.message,
    required this.children,
  });

  final String title;
  final String message;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KassaTokens.spaceXxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: c.card,
            borderRadius: BorderRadius.circular(KassaTokens.radiusCard),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(title, style: text.headlineMedium),
                  ),
                  const SizedBox(height: KassaTokens.spaceXl),
                  Text(
                    message,
                    style: text.bodyMedium!.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.45,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: KassaTokens.spaceHuge),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProbeQuestion extends StatefulWidget {
  const _ProbeQuestion(this.question);

  final ProbeQuestion question;

  @override
  State<_ProbeQuestion> createState() => _ProbeQuestionState();
}

class _ProbeQuestionState extends State<_ProbeQuestion> {
  bool _closing = false;

  void _close(bool answer) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(answer);
  }

  @override
  Widget build(BuildContext context) {
    final (title, message, confirm) = switch (widget.question) {
      ProbeQuestion.enable => (
        'Probe-Signatur einschalten?',
        'Jeder Bon bekommt dann einen QR-Code und wird ins Protokoll '
            'geschrieben, so wie später im echten Betrieb. Die Bons bleiben '
            'Testbons. Ältere Bons kannst du danach nicht mehr stornieren.',
        'Einschalten',
      ),
      ProbeQuestion.disable => (
        'Probe-Signatur beenden?',
        'Die Kassa erstellt einen Schlussbeleg. Danach haben neue Bons '
            'keinen QR-Code mehr.',
        'Beenden',
      ),
      ProbeQuestion.online => (
        'Mit A-Trust ausprobieren?',
        'Jeder Bon wird dann über das Internet vom Testsystem von A-Trust '
            'signiert. Die Bons bleiben Testbons. Ältere Bons kannst du '
            'danach nicht mehr stornieren.',
        'Weiter',
      ),
    };
    return SettingsSheet(
      key: const Key('rksv-question'),
      title: title,
      message: message,
      children: [
        Row(
          children: [
            SizedBox(
              width: 150,
              child: PrimaryButton(
                key: const Key('rksv-question-cancel'),
                label: 'Abbrechen',
                filled: false,
                height: 64,
                onPressed: () => _close(false),
              ),
            ),
            const SizedBox(width: KassaTokens.spaceXl),
            Expanded(
              child: PrimaryButton(
                key: const Key('rksv-question-confirm'),
                label: confirm,
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
