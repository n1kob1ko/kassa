import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../devices/card_terminal.dart';
import '../../devices/device_providers.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import 'settings_rows.dart';

const _failed = 'Das hat bei SumUp nicht geklappt. Bitte noch einmal.';

/// Die Zeile "Kartenterminal" (`card-row`): je nach Stand "Nicht
/// eingerichtet", "Nicht angemeldet" mit der Taste zum Anmelden oder der
/// Händler mit "Kartenleser verbinden" und "Abmelden". Abmelden fragt in der
/// Zeile nach, ohne Dialog. Die Seiten von SumUp sind eigene Bildschirme über
/// der App; beim Zurückkommen holt [cardStatusProvider] den Stand neu.
class CardPanel extends ConsumerStatefulWidget {
  const CardPanel({super.key});

  @override
  ConsumerState<CardPanel> createState() => _CardPanelState();
}

class _CardPanelState extends ConsumerState<CardPanel> {
  bool _busy = false;
  bool _confirmLogout = false;
  String? _problem;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    String? problem;
    try {
      await action();
    } catch (_) {
      problem = _failed;
    }
    ref.invalidate(cardStatusProvider);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _problem = problem;
    });
  }

  Future<void> _login() =>
      _run(() async => await ref.read(cardTerminalProvider).login());

  Future<void> _logout() async {
    setState(() => _confirmLogout = false);
    await _run(() => ref.read(cardTerminalProvider).logout());
  }

  Future<void> _reader() =>
      _run(() => ref.read(cardTerminalProvider).openReaderSettings());

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(cardStatusProvider);
    final value = status.value;
    final Widget control;
    final String help;
    Widget? below;
    if (value == null) {
      help = status.hasError
          ? 'Der Stand ist gerade nicht zu lesen.'
          : 'Wird geprüft …';
      control = const SizedBox.shrink();
    } else {
      switch (value.state) {
        case CardTerminalState.notConfigured:
          help = 'Diese Version wurde ohne SumUp gebaut.';
          control = const NeutralPill('Nicht eingerichtet');
        case CardTerminalState.loggedOut:
          help = 'Zum Bezahlen mit Karte bei SumUp anmelden.';
          control = const WarnPill('Nicht angemeldet');
          below = PrimaryButton(
            key: const Key('card-login'),
            label: 'Bei SumUp anmelden',
            icon: LucideIcons.logIn,
            height: 64,
            onPressed: _busy ? null : _login,
          );
        case CardTerminalState.ready:
          final name = value.merchantName;
          help = 'Karte und Handy an der Kassa annehmen.';
          control = DevicePill(
            name == null || name.isEmpty ? 'Angemeldet' : name,
          );
          below = _confirmLogout ? _logoutQuestion() : _readyButtons();
      }
    }
    final extra = _problem;
    return Column(
      key: const Key('card-row'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsRow(
          title: 'Kartenterminal',
          help: help,
          control: control,
          below: below,
        ),
        if (extra != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: WarnBox(extra),
          ),
      ],
    );
  }

  Widget _readyButtons() => Row(
    children: [
      Expanded(
        child: PrimaryButton(
          key: const Key('card-reader'),
          label: 'Kartenleser verbinden',
          filled: false,
          height: 56,
          icon: LucideIcons.nfc,
          onPressed: _busy ? null : _reader,
        ),
      ),
      const SizedBox(width: KassaTokens.spaceLg),
      Expanded(
        child: PrimaryButton(
          key: const Key('card-logout'),
          label: 'Abmelden',
          filled: false,
          height: 56,
          icon: LucideIcons.logOut,
          onPressed: _busy ? null : () => setState(() => _confirmLogout = true),
        ),
      ),
    ],
  );

  Widget _logoutQuestion() {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Wirklich abmelden?',
          style: text.bodyMedium!.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: c.ink,
          ),
        ),
        const SizedBox(height: KassaTokens.spaceLg),
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                key: const Key('card-logout-yes'),
                label: 'Abmelden',
                height: 56,
                onPressed: _busy ? null : _logout,
              ),
            ),
            const SizedBox(width: KassaTokens.spaceLg),
            Expanded(
              child: PrimaryButton(
                key: const Key('card-logout-no'),
                label: 'Doch nicht',
                filled: false,
                height: 56,
                onPressed: () => setState(() => _confirmLogout = false),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
