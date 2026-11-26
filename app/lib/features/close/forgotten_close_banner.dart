import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/pressable.dart';
import '../../ui/tokens.dart';

/// Streifen unter der Kopfleiste, solange der letzte Tag nicht abgeschlossen
/// ist. Der Chef hat dazu die Taste "Jetzt abschließen" ([onClose]),
/// Mitarbeiter sehen nur den Text. Bonieren bleibt möglich.
class ForgottenCloseBanner extends ConsumerStatefulWidget {
  const ForgottenCloseBanner({
    super.key,
    required this.isChef,
    required this.onClose,
  });

  final bool isChef;
  final VoidCallback onClose;

  @override
  ConsumerState<ForgottenCloseBanner> createState() =>
      _ForgottenCloseBannerState();
}

/// Eine Kassa kann über Nacht angemeldet bleiben: der Hinweis wird neu
/// berechnet, wenn die App in den Vordergrund kommt und danach jede Minute.
class _ForgottenCloseBannerState extends ConsumerState<ForgottenCloseBanner>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _recheck());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recheck();
  }

  void _recheck() {
    if (mounted) ref.invalidate(forgottenCloseProvider);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isChef = widget.isChef;
    final onClose = widget.onClose;
    if (!ref.watch(forgottenCloseProvider)) return const SizedBox.shrink();
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      key: const Key('forgotten-close'),
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: c.warnBg,
      child: Row(
        children: [
          Icon(LucideIcons.triangleAlert, size: 20, color: c.warnInk),
          const SizedBox(width: KassaTokens.spaceLg),
          Expanded(
            child: Text(
              L10n.of(context).closeForgotten,
              style: text.bodyMedium!.copyWith(color: c.warnInk),
            ),
          ),
          if (isChef) ...[
            const SizedBox(width: KassaTokens.spaceXl),
            Pressable(
              key: const Key('forgotten-close-go'),
              onTap: onClose,
              child: Container(
                height: KassaTokens.minTap,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.warnInk,
                  borderRadius: BorderRadius.circular(KassaTokens.radiusLg),
                ),
                child: Text(
                  L10n.of(context).closeNow,
                  maxLines: 1,
                  style: text.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w800,
                    color: c.warnBg,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
