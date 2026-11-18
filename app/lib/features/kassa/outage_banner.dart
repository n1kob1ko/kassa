import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../rksv/rksv_providers.dart';
import '../../rksv/rksv_state.dart';
import '../../ui/pressable.dart';
import '../../ui/tokens.dart';
import '../login/session.dart';

/// So lange bleibt "Die Signatur geht wieder." stehen, dann geht der Hinweis.
const outageBackStay = Duration(seconds: 4);

const _notYet = 'Geht noch nicht.';

/// "Signatur ausgefallen seit 13:05", an einem anderen Tag
/// "seit 16.11. 18:30".
String outageSinceText(DateTime since, DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  final time = '${two(since.hour)}:${two(since.minute)}';
  final sameDay =
      since.year == now.year &&
      since.month == now.month &&
      since.day == now.day;
  return sameDay
      ? 'Signatur ausgefallen seit $time'
      : 'Signatur ausgefallen seit ${two(since.day)}.${two(since.month)}. $time';
}

/// Ruhiger Hinweis über dem Bon, solange die Signatur ausgefallen ist
/// (`rksv-outage`): seit wann, dass weiterverkauft werden kann, und die Taste
/// "Nochmal prüfen" (`rksv-retry`, 56 dp). Ihr Ergebnis steht im Hinweis,
/// nie in einem Dialog. Geht die Signatur wieder, bleibt der Hinweis noch
/// [outageBackStay] mit "Die Signatur geht wieder." stehen. Ohne Ausfall ist
/// er nicht da.
class OutageBanner extends ConsumerStatefulWidget {
  const OutageBanner({super.key});

  @override
  ConsumerState<OutageBanner> createState() => _OutageBannerState();
}

class _OutageBannerState extends ConsumerState<OutageBanner> {
  bool _busy = false;
  String? _result;

  /// Wahr, solange "Die Signatur geht wieder." stehen bleibt.
  bool _back = false;
  Timer? _backTimer;

  @override
  void dispose() {
    _backTimer?.cancel();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_busy) return;
    final staff = ref.read(sessionProvider);
    if (staff == null) return;
    setState(() {
      _busy = true;
      _result = null;
    });
    var back = false;
    try {
      back = await ref.read(rksvServiceProvider).retrySignature(staff: staff);
    } catch (_) {
      // Was auch schiefgeht: Die Signatur geht dann noch nicht.
      back = false;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _back = back;
      _result = back ? null : _notYet;
    });
    if (back) {
      _backTimer?.cancel();
      _backTimer = Timer(outageBackStay, () {
        if (mounted) setState(() => _back = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rksvStateProvider).value ?? const RksvState();
    final since = state.outageSince;
    if (_back) return const _BackNotice();
    if (since == null || state.mode == RksvMode.off) {
      return const SizedBox.shrink();
    }
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final now = ref.read(clockProvider).now();
    final ink = text.bodyMedium!.copyWith(color: c.warnInk);
    final result = _result;
    return Container(
      key: const Key('rksv-outage'),
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: c.warnBg,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  outageSinceText(since, now),
                  key: const Key('rksv-outage-title'),
                  style: ink.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: KassaTokens.spaceXs),
                Text(
                  'Du kannst normal weiterverkaufen.',
                  style: ink.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                if (result != null) ...[
                  const SizedBox(height: KassaTokens.spaceXs),
                  Text(
                    result,
                    key: const Key('rksv-retry-result'),
                    style: ink.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: KassaTokens.spaceXl),
          _RetryButton(onTap: _busy ? null : _retry),
        ],
      ),
    );
  }
}

/// "Nochmal prüfen": 56 dp hoch wie die Tasten rechts in den Einstellungen,
/// helle Fläche auf dem Hinweis.
class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Pressable(
      key: const Key('rksv-retry'),
      onTap: onTap,
      semanticLabel: 'Nochmal prüfen',
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
        ),
        child: Text(
          'Nochmal prüfen',
          maxLines: 1,
          style: Theme.of(context).textTheme.bodyMedium!
              .copyWith(fontWeight: FontWeight.w800, color: c.warnInk),
        ),
      ),
    );
  }
}

/// Kurz nach "Nochmal prüfen", wenn die Signatur wieder geht.
class _BackNotice extends StatelessWidget {
  const _BackNotice();

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Container(
      key: const Key('rksv-outage'),
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.veganBg,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.check, size: 20, color: c.veganFg),
          const SizedBox(width: KassaTokens.spaceLg),
          Expanded(
            child: Text(
              'Die Signatur geht wieder.',
              key: const Key('rksv-retry-result'),
              style: Theme.of(context).textTheme.bodyMedium!
                  .copyWith(fontWeight: FontWeight.w800, color: c.veganFg),
            ),
          ),
        ],
      ),
    );
  }
}
