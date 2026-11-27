import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../devices/card_terminal.dart';
import '../../devices/device_providers.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/ltr.dart';

/// Ob die Karte für [amountCents] geht, sonst der erste Grund in der
/// Bediensprache: Terminal nicht eingerichtet, abgemeldet, kein Internet,
/// Betrag unter dem Kleinstbetrag. Solange der Stand des Terminals noch nicht
/// da ist, geht sie still nicht (ohne Grund). Nur in `build` rufen: der Stand
/// des Terminals und des Internets wird beobachtet.
({bool enabled, String? reason}) cardAvailability(
  WidgetRef ref,
  BuildContext context,
  int amountCents,
) {
  final l = L10n.of(context);
  final status = ref.watch(cardStatusProvider).value;
  if (status == null) return (enabled: false, reason: null);
  final minimum = ref.read(cardTerminalProvider).minimumCents;
  final online = ref.watch(internetProvider).value ?? true;
  return switch (status.state) {
    CardTerminalState.notConfigured => (
      enabled: false,
      reason: l.kassaCardNotSetUp,
    ),
    CardTerminalState.loggedOut => (
      enabled: false,
      reason: l.kassaCardLoggedOut,
    ),
    CardTerminalState.ready when !online => (
      enabled: false,
      reason: l.kassaCardNoInternet,
    ),
    CardTerminalState.ready when amountCents < minimum => (
      enabled: false,
      reason: l.kassaCardFrom(ltrIsolate(context, formatEuro(minimum))),
    ),
    CardTerminalState.ready => (enabled: true, reason: null),
  };
}
