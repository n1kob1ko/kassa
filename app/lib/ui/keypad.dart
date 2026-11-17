import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'pressable.dart';
import 'tokens.dart';

/// Zahlenfeld: 3 Spalten, Abstand 8, Tastenhöhe 56. Meldet nur Tasten über
/// [onKey]: `'0'` bis `'9'`, `','` und `'back'`. Es gibt nie eine
/// Systemtastatur.
class Keypad extends StatelessWidget {
  const Keypad({
    super.key,
    required this.onKey,
    this.showComma = true,
    this.keyHeight = KassaTokens.keypadKeyHeight,
  });

  final ValueChanged<String> onKey;

  /// Ohne Komma bleibt die Zelle leer, damit das Raster gleich bleibt.
  final bool showComma;

  /// Höhe einer Taste. Die Anmeldung nutzt 72.
  final double keyHeight;

  @override
  Widget build(BuildContext context) {
    Widget digit(int d) => _KeypadKey(
      key: Key('key-$d'),
      height: keyHeight,
      onTap: () => onKey('$d'),
      child: Text('$d', style: _keyStyle(context)),
    );
    Widget row(List<Widget> cells) => Row(
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) const SizedBox(width: KassaTokens.spaceMd),
          Expanded(child: cells[i]),
        ],
      ],
    );

    final comma = showComma
        ? _KeypadKey(
            key: const Key('key-comma'),
            height: keyHeight,
            quiet: true,
            semanticLabel: 'Komma',
            onTap: () => onKey(','),
            child: Text(',', style: _keyStyle(context)),
          )
        : SizedBox(height: keyHeight);
    final back = _KeypadKey(
      key: const Key('key-back'),
      height: keyHeight,
      quiet: true,
      semanticLabel: 'Letzte Ziffer löschen',
      onTap: () => onKey('back'),
      child: Icon(
        LucideIcons.delete,
        size: 26,
        color: KassaColors.of(context).ink,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([digit(1), digit(2), digit(3)]),
        const SizedBox(height: KassaTokens.spaceMd),
        row([digit(4), digit(5), digit(6)]),
        const SizedBox(height: KassaTokens.spaceMd),
        row([digit(7), digit(8), digit(9)]),
        const SizedBox(height: KassaTokens.spaceMd),
        row([comma, digit(0), back]),
      ],
    );
  }

  TextStyle _keyStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!
          .copyWith(fontSize: 24, fontWeight: FontWeight.w700);
}

class _KeypadKey extends StatelessWidget {
  const _KeypadKey({
    super.key,
    required this.onTap,
    required this.child,
    required this.height,
    this.quiet = false,
    this.semanticLabel,
  });

  final double height;
  final VoidCallback onTap;
  final Widget child;
  final bool quiet;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: quiet ? c.fill : c.card,
          borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
          border: quiet
              ? null
              : Border.all(color: c.line, width: KassaTokens.borderButton),
        ),
        child: child,
      ),
    );
  }
}
