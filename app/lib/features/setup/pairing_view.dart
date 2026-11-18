// Die Bildschirme zum Koppeln mit Code (Entwurf 5.11): Code eingeben, dann
// "Verbunden mit …" mit Laden, Fehler beim Laden oder Hinweis auf fehlende
// Mitarbeiter. Kein Textfeld: der Code kommt vom Zahlenfeld.

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../sync/server_api.dart';
import '../../ui/code_boxes.dart';
import '../../ui/keypad.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import 'pairing_controller.dart';

/// Der Hinweis, solange der Betrieb keinen Chef mit PIN hat.
const noStaffText =
    'Lege in der Verwaltung zuerst einen Mitarbeiter mit PIN an.';

/// Der Satz zu einem Fehler beim Koppeln.
String pairingFailureText(ServerFailure f) => switch (f) {
  ServerFailure.invalidCode => 'Der Code stimmt nicht oder ist abgelaufen.',
  ServerFailure.offline ||
  ServerFailure.timeout => 'Keine Verbindung zum Internet.',
  ServerFailure.tooManyAttempts =>
    'Zu viele Versuche. Bitte in 15 Minuten nochmal.',
  ServerFailure.otherBusiness =>
    'Dieses Tablet gehört zu einem anderen Betrieb.',
  ServerFailure.unauthorized ||
  ServerFailure.blocked ||
  ServerFailure.server => 'Das hat nicht geklappt. Bitte nochmal versuchen.',
};

class PairingView extends ConsumerWidget {
  const PairingView({
    super.key,
    required this.onBack,
    required this.onNewCode,
    this.onClose,
  });

  /// "Zurück" auf der Code-Eingabe.
  final VoidCallback onBack;

  /// "Mit neuem Code koppeln" nach einem gescheiterten Laden.
  final VoidCallback onNewCode;

  /// "Zurück zur Kassa", wenn der Betrieb am Server keinen Chef hat. Nur
  /// aus den Einstellungen: dort arbeitet die Kassa mit dem alten Stand.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pairingControllerProvider);
    final controller = ref.read(pairingControllerProvider.notifier);
    final c = KassaColors.of(context);
    final Widget card =
        state.step == PairingStep.idle || state.step == PairingStep.checking
        ? _CodeCard(state: state, controller: controller, onBack: onBack)
        : _ConnectedCard(
            state: state,
            controller: controller,
            onNewCode: onNewCode,
            onClose: onClose,
          );
    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KassaTokens.spaceHuge),
            child: card,
          ),
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration(KassaColors c) => BoxDecoration(
  color: c.card,
  borderRadius: BorderRadius.circular(KassaTokens.radiusCard),
  border: Border.all(color: c.line, width: KassaTokens.borderThin),
  boxShadow: c.cardShadow,
);

class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.state,
    required this.controller,
    required this.onBack,
  });

  final PairingState state;
  final PairingController controller;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final checking = state.step == PairingStep.checking;
    final failure = state.failure;
    final complete = state.code.length == PairingController.codeLength;
    return Container(
      width: 480,
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
      decoration: _cardDecoration(c),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Kopplungscode eingeben',
            textAlign: TextAlign.center,
            style: text.headlineLarge!.copyWith(fontSize: 26),
          ),
          const SizedBox(height: KassaTokens.spaceXxl),
          CodeBoxes(value: state.code, error: failure != null),
          const SizedBox(height: KassaTokens.spaceLg),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 20),
            child: Text(
              failure == null
                  ? 'Den Code findest du in der Verwaltung unter Kassen.'
                  : pairingFailureText(failure),
              key: const Key('pair-hint'),
              textAlign: TextAlign.center,
              style: text.bodyMedium!.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: failure == null ? c.ink2 : c.red,
              ),
            ),
          ),
          const SizedBox(height: KassaTokens.spaceXxl),
          // Während der Prüfung gesperrt und abgeblendet.
          IgnorePointer(
            ignoring: checking,
            child: Opacity(
              opacity: checking ? KassaTokens.disabledOpacity : 1,
              child: Keypad(
                onKey: controller.key,
                showComma: false,
                keyHeight: 60,
              ),
            ),
          ),
          const SizedBox(height: KassaTokens.spaceXxl),
          Row(
            children: [
              SizedBox(
                width: 140,
                child: PrimaryButton(
                  key: const Key('pair-back'),
                  label: 'Zurück',
                  filled: false,
                  height: 64,
                  onPressed: checking ? null : onBack,
                ),
              ),
              const SizedBox(width: KassaTokens.spaceXl),
              Expanded(
                child: PrimaryButton(
                  key: const Key('pair-submit'),
                  label: 'Koppeln',
                  height: 64,
                  leading: checking ? const _Spinner() : null,
                  onPressed: complete && !checking ? controller.submit : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectedCard extends StatelessWidget {
  const _ConnectedCard({
    required this.state,
    required this.controller,
    required this.onNewCode,
    required this.onClose,
  });

  final PairingState state;
  final PairingController controller;
  final VoidCallback onNewCode;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final name = state.businessName;
    final register = state.registerName;
    final Widget body;
    switch (state.step) {
      case PairingStep.noStaff || PairingStep.noChefOnServer:
        final close = state.step == PairingStep.noChefOnServer ? onClose : null;
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Notice(noStaffText),
            const SizedBox(height: KassaTokens.spaceHuge),
            PrimaryButton(
              key: const Key('pair-recheck'),
              label: 'Nochmal prüfen',
              leading: state.busy ? const _Spinner() : null,
              onPressed: state.busy ? null : controller.recheck,
            ),
            if (close != null) ...[
              const SizedBox(height: KassaTokens.spaceXl),
              // Die Kassa arbeitet mit der alten Speisekarte und den alten
              // PINs weiter, bis der Betrieb einen Chef hat.
              PrimaryButton(
                key: const Key('pair-close'),
                label: 'Zurück zur Kassa',
                filled: false,
                onPressed: state.busy ? null : close,
              ),
            ],
          ],
        );
      case PairingStep.loadFailed:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Notice('Die Speisekarte konnte nicht geladen werden.'),
            const SizedBox(height: KassaTokens.spaceHuge),
            PrimaryButton(
              key: const Key('pair-retry'),
              label: 'Nochmal versuchen',
              onPressed: controller.retry,
            ),
            const SizedBox(height: KassaTokens.spaceXl),
            // Gilt der Schlüssel nicht mehr, hilft nur ein neuer Code.
            PrimaryButton(
              key: const Key('pair-new'),
              label: 'Mit neuem Code koppeln',
              filled: false,
              onPressed: onNewCode,
            ),
          ],
        );
      case _:
        body = Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          decoration: BoxDecoration(
            color: c.fill,
            borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Speisekarte wird geladen',
                style: text.bodyMedium!.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: KassaTokens.spaceXl),
              const _ProgressBar(),
            ],
          ),
        );
    }
    return Container(
      width: 560,
      padding: const EdgeInsets.fromLTRB(40, 36, 40, 36),
      decoration: _cardDecoration(c),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.green.withValues(alpha: 0.14),
                ),
                child: Icon(LucideIcons.check, size: 28, color: c.green),
              ),
              const SizedBox(width: KassaTokens.spaceXxl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name == null ? 'Verbunden' : 'Verbunden mit $name',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.headlineLarge!.copyWith(fontSize: 28),
                    ),
                    if (register != null) ...[
                      const SizedBox(height: KassaTokens.spaceXs),
                      Text(
                        'Dieses Tablet ist jetzt $register.',
                        style: text.bodyMedium!.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: c.ink2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KassaTokens.spaceHuge + KassaTokens.spaceMd),
          body,
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: c.warnBg,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.4,
          color: c.warnInk,
        ),
      ),
    );
  }
}

/// Fortschrittsbalken ohne bekannte Länge: ein Stück läuft hin und her. Mit
/// "Bewegung reduzieren" steht es still.
class _ProgressBar extends StatefulWidget {
  const _ProgressBar();

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _running = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still && _running) {
      _controller.stop();
      _running = false;
    } else if (!still && !_running) {
      _controller.repeat(reverse: true);
      _running = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Semantics(
      label: 'Speisekarte wird geladen',
      excludeSemantics: true,
      child: SizedBox(
        height: 6,
        child: LayoutBuilder(
          builder: (context, box) {
            final still = MediaQuery.disableAnimationsOf(context);
            final w = box.maxWidth;
            final piece = w * 0.35;
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final p = still
                    ? 0.0
                    : Curves.easeInOut.transform(_controller.value);
                return Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.fill2,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (w - piece) * p,
                      width: piece,
                      top: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.accent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Kleiner Ring, der sich dreht. Mit "Bewegung reduzieren" steht er still.
class _Spinner extends StatefulWidget {
  const _Spinner();

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _running = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still && _running) {
      _controller.stop();
      _running = false;
    } else if (!still && !_running) {
      _controller.repeat();
      _running = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Wird geprüft',
      excludeSemantics: true,
      child: SizedBox(
        width: 24,
        height: 24,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _RingPainter(
              _controller.value * 2 * math.pi,
              KassaColors.of(context).onAccent,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.turn, this.color);

  final double turn;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Offset.zero & size, turn, math.pi * 1.5, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.turn != turn || old.color != color;
}
