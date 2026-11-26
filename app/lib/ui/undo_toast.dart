import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/generated/l10n.dart';
import 'pressable.dart';
import 'tokens.dart';

OverlayEntry? _current;

/// Zeigt unten mittig einen Hinweis mit der Taste "Rückgängig". Bleibt
/// [KassaTokens.snackStay] (7 Sekunden) stehen. Ein neuer Hinweis ersetzt den
/// alten. Antippen von "Rückgängig" ruft [onUndo] einmal und schließt ihn.
/// Ohne [onUndo] zeigt der Hinweis nur den Text (z. B. das Ergebnis des
/// Druckens). [stay] ersetzt die Standzeit, [viewKey] den Schlüssel des
/// Hinweises (Standard `undo-toast`). Die Rückgabe schließt den Hinweis von außen (mehrfach
/// aufrufbar).
VoidCallback showUndoToast(
  BuildContext context, {
  required String message,
  VoidCallback? onUndo,
  Duration stay = KassaTokens.snackStay,
  Key viewKey = const Key('undo-toast'),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  _current?.remove();
  _current?.dispose();
  late final OverlayEntry entry;
  void close() {
    if (identical(_current, entry)) _current = null;
    if (entry.mounted) entry.remove();
    entry.dispose();
  }

  entry = OverlayEntry(
    builder: (context) => _ToastHost(
      message: message,
      stay: stay,
      viewKey: viewKey,
      onUndo: onUndo == null
          ? null
          : () {
              close();
              onUndo();
            },
      onTimeout: close,
    ),
  );
  _current = entry;
  overlay.insert(entry);
  var closed = false;
  return () {
    if (closed) return;
    closed = true;
    // Nur schließen, wenn es noch dieser Hinweis ist.
    if (identical(_current, entry) || entry.mounted) close();
  };
}

class _ToastHost extends StatefulWidget {
  const _ToastHost({
    required this.message,
    required this.stay,
    required this.viewKey,
    required this.onUndo,
    required this.onTimeout,
  });

  final String message;
  final Duration stay;
  final Key viewKey;
  final VoidCallback? onUndo;
  final VoidCallback onTimeout;

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.stay, widget.onTimeout);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final instant = MediaQuery.disableAnimationsOf(context);
    return Positioned.fill(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: 20 + MediaQuery.paddingOf(context).bottom,
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: instant ? 1 : 0, end: 1),
            duration: instant ? Duration.zero : KassaTokens.motionSnack,
            curve: KassaTokens.motionCurve,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - t)),
                child: child,
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: UndoToastView(
                key: widget.viewKey,
                message: widget.message,
                onUndo: widget.onUndo,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Aussehen des Hinweises: Höhe 60, Rundung 16, `solid` mit `solidInk`.
/// Eigenes Widget, damit Bildvergleiche es ohne Overlay zeigen können.
class UndoToastView extends StatelessWidget {
  const UndoToastView({
    super.key = const Key('undo-toast'),
    required this.message,
    this.onUndo,
  });

  final String message;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme.bodyLarge!;
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: EdgeInsets.only(left: 20, right: onUndo == null ? 20 : 6),
      decoration: BoxDecoration(
        color: c.solid,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x47101828),
            offset: Offset(0, 12),
            blurRadius: 32,
          ),
        ],
      ),
      child: IntrinsicWidth(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                message,
                style: text.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.solidInk,
                ),
              ),
            ),
            if (onUndo != null) ...[
              const SizedBox(width: 24),
              Pressable(
                key: const Key('undo'),
                onTap: onUndo,
                minTapSize: const Size(0, KassaTokens.minTap),
                child: Container(
                  height: KassaTokens.minTap,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  child: Text(
                    L10n.of(context).uiUndo,
                    style: text.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: c.accentSnack,
                    ),
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
