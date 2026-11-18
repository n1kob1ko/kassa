import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import '../setup/pairing_controller.dart';
import '../setup/pairing_view.dart';

/// Rückfrage vor dem Koppeln eines Tablets, das schon eingerichtet ist. Sie
/// steht in der Karte, ohne Dialog.
class PairQuestion extends StatelessWidget {
  const PairQuestion({
    super.key,
    required this.onConfirm,
    required this.onCancel,
    this.loadOnly = false,
  });

  /// Die Kassa ist schon verbunden und holt nur die Speisekarte: andere
  /// Überschrift und "Laden" statt "Verbinden".
  final bool loadOnly;

  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
        border: Border.all(color: c.line, width: KassaTokens.borderButton),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loadOnly
                ? 'Speisekarte vom Server laden?'
                : 'Mit dem Server verbinden?',
            style: text.titleMedium!.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: KassaTokens.spaceSm),
          Text(
            'Die Speisekarte und die Mitarbeiter kommen danach vom Server. '
            'Die Bons auf diesem Tablet bleiben. Ein offener Bon wird '
            'geleert, und du meldest dich neu an.',
            style: text.bodyMedium!.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: KassaTokens.spaceXl),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  key: const Key('cancel-pair-question'),
                  label: 'Abbrechen',
                  filled: false,
                  height: 60,
                  onPressed: onCancel,
                ),
              ),
              const SizedBox(width: KassaTokens.spaceLg),
              Expanded(
                child: PrimaryButton(
                  key: const Key('confirm-pair-question'),
                  label: loadOnly ? 'Laden' : 'Verbinden',
                  height: 60,
                  onPressed: onConfirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Der Bildschirm zum Koppeln, von den Einstellungen aus als ganzer Bildschirm
/// geöffnet. Ist die Speisekarte geladen, meldet der Dienst den Chef ab und die
/// Anmeldung erscheint darunter: dann schließt sich dieser Bildschirm von
/// selbst, damit er sie nicht verdeckt.
class PairingScreen extends ConsumerWidget {
  const PairingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(pairingControllerProvider.select((s) => s.step));
    ref.listen(pairingControllerProvider.select((s) => s.step), (_, step) {
      if (step == PairingStep.done) Navigator.of(context).maybePop();
    });
    return PopScope(
      // Während der Prüfung und des Ladens gibt es kein Zurück.
      canPop: step != PairingStep.checking && step != PairingStep.loading,
      child: PairingView(
        onBack: () => Navigator.of(context).maybePop(),
        onNewCode: ref.read(pairingControllerProvider.notifier).restart,
        onClose: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}
