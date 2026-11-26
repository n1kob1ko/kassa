import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart' show appLanguageProvider;
import '../../data/providers.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/keypad.dart';
import '../../ui/business_logo.dart';
import '../../ui/language_picker.dart';
import '../../ui/pressable.dart';
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
    final l = L10n.of(context);
    return Scaffold(
      backgroundColor: KassaColors.of(context).ground,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: PinCard(
                businessName: ref.watch(catalogProvider).value?.businessName,
                title: l.loginTitle,
                hint: _failed
                    ? l.loginFailed
                    : _wrong
                    ? l.loginWrongPin
                    : l.loginHint,
                hintIsError: _wrong || _failed,
                filled: _pin.length,
                onKey: _onKey,
              ),
            ),
            // Oben am Ende der Zeile, in Arabisch also links.
            const PositionedDirectional(
              top: KassaTokens.spaceXxl,
              end: KassaTokens.spaceXxl,
              child: _LanguageButton(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Weltkugel und Name der jetzigen Sprache; öffnet die Sprachen als Blatt.
/// Wer kein Deutsch liest, findet sie ohne Lesen.
class _LanguageButton extends ConsumerWidget {
  const _LanguageButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = KassaColors.of(context);
    final language = ref.watch(appLanguageProvider);
    return Pressable(
      key: const Key('login-language'),
      onTap: () => showLanguageSheet(context, ref),
      semanticLabel: L10n.of(context).languageChangeLabel,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: KassaTokens.loginLanguageButtonHeight,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
          border: Border.all(color: c.line, width: KassaTokens.borderThin),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.globe, size: 22, color: c.ink),
            const SizedBox(width: KassaTokens.spaceMd),
            Text(
              language.nativeName,
              locale: language.locale,
              style: TextStyle(
                fontFamily: KassaTokens.fontFamily,
                fontFamilyFallback: KassaTokens.fontFallback,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: c.ink,
              ),
            ),
          ],
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
      label: L10n.of(context).loginDigitsEntered(filled),
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
