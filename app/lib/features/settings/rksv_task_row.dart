import 'package:material_ui/material_ui.dart';

import '../../rksv/rksv_state.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';

/// Eine offene Aufgabe der Signatur (`rksv-task-<id>`): Punkt in
/// Akzentfarbe, der Satz aus [rksvTaskText] und rechts die Taste "Erledigt"
/// (`rksv-task-done-<id>`, 56 dp hoch), die [onDone] ruft. Ohne [onDone]
/// steht keine Taste da (wer nicht Chef ist, sieht die Aufgabe nur).
/// Mit [busy] ist die Taste gesperrt.
class RksvTaskRow extends StatelessWidget {
  const RksvTaskRow({
    super.key,
    required this.task,
    this.onDone,
    this.busy = false,
  });

  final RksvTask task;
  final VoidCallback? onDone;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final done = onDone;
    return ConstrainedBox(
      key: Key('rksv-task-${task.id}'),
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KassaTokens.spaceSm),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: c.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: KassaTokens.spaceXxl),
            Expanded(
              child: Text(
                rksvTaskText(task),
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: c.ink,
                ),
              ),
            ),
            if (done != null) ...[
              const SizedBox(width: KassaTokens.spaceXl),
              PrimaryButton(
                key: Key('rksv-task-done-${task.id}'),
                label: 'Erledigt',
                filled: false,
                height: 56,
                onPressed: busy ? null : done,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Der Block der offenen Aufgaben: klein die Überschrift "Zu erledigen", mit
/// [practice] (alle Aufgaben gehören zur laufenden Probe,
/// `RksvState.onlyProbeTasks`) darunter "Aufgaben aus der Probe sind zum
/// Üben.", dann je Aufgabe eine [RksvTaskRow]. [onDone] bekommt die Aufgabe; ohne
/// [onDone] stehen keine Tasten da. Ohne Aufgabe ist der Block leer
/// (`SizedBox.shrink`), wer ihn einbaut, lässt ihn dann besser ganz weg.
class RksvTaskBlock extends StatelessWidget {
  const RksvTaskBlock({
    super.key,
    required this.tasks,
    required this.practice,
    this.onDone,
    this.busy = false,
  });

  final List<RksvTask> tasks;
  final bool practice;
  final ValueChanged<RksvTask>? onDone;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final done = onDone;
    return Padding(
      key: const Key('rksv-tasks'),
      padding: const EdgeInsets.only(top: 14, bottom: KassaTokens.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Zu erledigen',
            style: text.bodyMedium!.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: c.ink2,
            ),
          ),
          if (practice) ...[
            const SizedBox(height: KassaTokens.spaceXxs),
            Text(
              'Aufgaben aus der Probe sind zum Üben.',
              style: text.bodyMedium!.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.3,
                color: c.ink2,
              ),
            ),
          ],
          const SizedBox(height: KassaTokens.spaceSm),
          for (final task in tasks)
            RksvTaskRow(
              task: task,
              busy: busy,
              onDone: done == null ? null : () => done(task),
            ),
        ],
      ),
    );
  }
}
