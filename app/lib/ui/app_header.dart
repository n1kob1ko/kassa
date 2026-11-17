import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'pressable.dart';
import 'tokens.dart';

/// Die Bereiche der App, wie sie die Reiter der Kopfleiste zeigen.
enum AppArea {
  kassa('Kassa'),
  bons('Bons'),
  overview('Übersicht'),
  items('Artikel'),
  close('Abschluss');

  const AppArea(this.label);

  /// Beschriftung des Reiters, zugleich Teil seines Schlüssels `tab-<name>`.
  final String label;
}

/// Kopfleiste: Logo, Wortmarke, Reiter, Mitarbeiter-Knopf und (nur für den
/// Chef) Einstellungen. Mitarbeiter sehen nur "Kassa" und "Bons".
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.area,
    required this.onArea,
    required this.staffName,
    required this.isChef,
    required this.onStaff,
    required this.onSettings,
  });

  final AppArea area;
  final ValueChanged<AppArea> onArea;
  final String staffName;
  final bool isChef;
  final VoidCallback onStaff;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final areas = isChef ? AppArea.values : const [AppArea.kassa, AppArea.bons];
    return Container(
      height: KassaTokens.headerHeight,
      padding: const EdgeInsets.only(left: 16, right: 12),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(
          bottom: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(KassaTokens.radiusMd),
            ),
            child: Icon(LucideIcons.receipt, size: 20, color: c.onAccent),
          ),
          const SizedBox(width: KassaTokens.spaceXl),
          Text('Kassa', style: text.headlineMedium),
          const SizedBox(width: KassaTokens.spaceXl),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final a in areas) ...[
                    if (a != areas.first)
                      const SizedBox(width: KassaTokens.spaceXxs),
                    _Tab(area: a, active: a == area, onTap: () => onArea(a)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: KassaTokens.spaceXl),
          _StaffButton(name: staffName, onTap: onStaff),
          if (isChef) ...[
            const SizedBox(width: KassaTokens.spaceXs),
            _SettingsButton(onTap: onSettings),
          ],
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.area, required this.active, required this.onTap});

  final AppArea area;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final instant = MediaQuery.disableAnimationsOf(context);
    return Pressable(
      key: Key('tab-${area.label}'),
      onTap: onTap,
      minTapSize: const Size(0, KassaTokens.minTap),
      child: AnimatedContainer(
        duration: instant ? Duration.zero : KassaTokens.motionFast,
        curve: Curves.linear,
        height: KassaTokens.drawnControlHeight,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? c.accentSoft : const Color(0x00000000),
          borderRadius: BorderRadius.circular(KassaTokens.radiusLg),
        ),
        child: Text(
          area.label,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: active ? c.accentInk : c.ink2,
          ),
        ),
      ),
    );
  }
}

class _StaffButton extends StatelessWidget {
  const _StaffButton({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final style = Theme.of(context).textTheme.bodyMedium!
        .copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: c.ink);
    final initial = name.isEmpty ? '' : name.characters.first.toUpperCase();
    return Pressable(
      key: const Key('staff'),
      onTap: onTap,
      semanticLabel: 'Mitarbeiter wechseln, angemeldet: $name',
      child: Container(
        height: KassaTokens.minTap,
        padding: const EdgeInsets.only(left: 7, right: 14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Text(
                initial,
                style: style.copyWith(
                  fontWeight: FontWeight.w800,
                  color: c.accentInk,
                ),
              ),
            ),
            const SizedBox(width: KassaTokens.spaceMd),
            Text(name, style: style),
          ],
        ),
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Pressable(
      key: const Key('settings'),
      onTap: onTap,
      semanticLabel: 'Einstellungen',
      child: SizedBox(
        width: KassaTokens.minTap,
        height: KassaTokens.minTap,
        child: Icon(LucideIcons.slidersHorizontal, size: 24, color: c.ink),
      ),
    );
  }
}
