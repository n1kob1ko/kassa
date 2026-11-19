import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../ui/keypad.dart';
import '../../ui/business_logo.dart';
import '../../ui/tokens.dart';
import 'session.dart';

/// Anmeldung: vier Ziffern, die Prüfung läuft nach der vierten von selbst.
class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  String _pin = '';
  bool _wrong = false;
  bool _failed = false;
  bool _busy = false;

  Future<void> _onKey(String key) async {
    if (_busy) return;
    if (key == 'back') {
      setState(() {
        _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1);
        _wrong = false;
        _failed = false;
      });
      return;
    }
    if (_pin.length >= 4 || key.length != 1) return;
    final pin = _pin + key;
    setState(() {
      _pin = pin;
      _wrong = false;
      _failed = false;
    });
    if (pin.length < 4) return;
    _busy = true;
    var ok = false;
    var failed = false;
    try {
      ok = await ref.read(sessionProvider.notifier).login(pin);
    } catch (_) {
      failed = true;
    } finally {
      _busy = false;
    }
    if (!ok && mounted) {
      setState(() {
        _pin = '';
        _wrong = !failed;
        _failed = failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KassaColors.of(context).ground,
      body: SafeArea(
        child: PinCard(
          businessName: ref.watch(catalogProvider).value?.businessName,
          title: 'PIN eingeben',
          hint: _failed
              ? 'Das hat nicht geklappt. Bitte nochmal versuchen.'
              : _wrong
              ? 'Diese PIN kennt die Kassa nicht.'
              : 'Jede Person hat ihre eigene PIN',
          hintIsError: _wrong || _failed,
          filled: _pin.length,
          onKey: _onKey,
        ),
      ),
    );
  }
}

/// Karte mit Titel, Hinweis, vier Punkten und Zahlenfeld ohne Komma. Die
/// Anmeldung und das Festlegen der Chef-PIN teilen sie.
class PinCard extends StatelessWidget {
  const PinCard({
    super.key,
    required this.title,
    required this.hint,
    required this.filled,
    required this.onKey,
    this.hintIsError = false,
    this.businessName,
  });

  final String title;
  final String hint;
  final bool hintIsError;
  final int filled;
  final ValueChanged<String> onKey;
  final String? businessName;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KassaTokens.spaceXxl),
        child: Container(
          width: 420,
          padding: const EdgeInsets.fromLTRB(36, 32, 36, 36),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(KassaTokens.radiusCard),
            border: Border.all(color: c.line, width: KassaTokens.borderThin),
            boxShadow: c.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const BusinessLogo(size: 34),
                  const SizedBox(width: KassaTokens.spaceLg),
                  Text('Kassa', style: text.headlineMedium),
                  if (businessName != null) ...[
                    const SizedBox(width: KassaTokens.spaceXl),
                    Flexible(
                      child: Text(
                        businessName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium!.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.ink2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: text.headlineLarge!.copyWith(fontSize: 26),
              ),
              const SizedBox(height: KassaTokens.spaceSm),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 20),
                child: Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium!.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: hintIsError ? c.red : c.ink2,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _Dots(filled: filled, error: hintIsError),
              const SizedBox(height: 20),
              Keypad(onKey: onKey, showComma: false, keyHeight: 72),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.filled, required this.error});

  final int filled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final instant = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: '$filled von 4 Ziffern eingegeben',
      excludeSemantics: true,
      child: SizedBox(
        height: 24,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 18),
              AnimatedContainer(
                duration: instant ? Duration.zero : KassaTokens.motionFast,
                curve: Curves.linear,
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < filled ? c.accent : const Color(0x00000000),
                  border: Border.all(
                    color: error
                        ? c.red
                        : i < filled
                        ? c.accent
                        : c.ink2,
                    width: KassaTokens.borderStrong,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
