import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/generated/l10n.dart';
import 'business_logo.dart';
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

  /// Der deutsche Name, Teil des Schlüssels `tab-<label>` (in jeder Sprache
  /// gleich). Der Reiter zeigt [title].
  final String label;

  /// Beschriftung des Reiters in der Bediensprache.
  String title(L10n l) => switch (this) {
    AppArea.kassa => l.shellTabKassa,
    AppArea.bons => l.shellTabBons,
    AppArea.overview => l.shellTabOverview,
    AppArea.items => l.shellTabItems,
    AppArea.close => l.shellTabClose,
  };
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
    this.settingsActive = false,
    this.businessName,
    this.offline = false,
  });

  final AppArea area;
  final ValueChanged<AppArea> onArea;
  final String staffName;
  final bool isChef;
  final VoidCallback onStaff;
  final VoidCallback onSettings;

  /// Die Einstellungen sind offen: der Knopf ist aktiv, kein Reiter ist es.
  final bool settingsActive;

  /// Name des Betriebs, neben der Wortmarke.
  final String? businessName;

  /// Das Tablet hat kein Internet: eine Pille sagt es und dass Bar weitergeht.
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final areas = isChef ? AppArea.values : const [AppArea.kassa, AppArea.bons];
    // Die Kopfleiste reicht mit ihrer Farbe bis unter die Statusleiste des
    // Tablets, ihr Inhalt beginnt erst darunter.
    final statusBar = MediaQuery.paddingOf(context).top;
    return Container(
      height: KassaTokens.headerHeight + statusBar,
      padding: EdgeInsetsDirectional.only(start: 16, end: 12, top: statusBar),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(
          bottom: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: Row(
        children: [
          const BusinessLogo(size: 34),
          const SizedBox(width: KassaTokens.spaceXl),
          Text('Kassa', style: text.headlineMedium),
          if (businessName != null) ...[
            const SizedBox(width: KassaTokens.spaceXxl),
            // Kein Anteil am freien Platz: die Reiter nehmen den Rest, die
            // Knöpfe am Ende bleiben am Rand.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
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
          const SizedBox(width: KassaTokens.spaceXl),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final a in areas) ...[
                    if (a != areas.first)
                      const SizedBox(width: KassaTokens.spaceXxs),
                    _Tab(
                      area: a,
                      active: a == area && !settingsActive,
                      onTap: () => onArea(a),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (offline) ...[
            const _OfflinePill(),
            const SizedBox(width: KassaTokens.spaceXl),
          ],
          const SizedBox(width: KassaTokens.spaceXl),
          _StaffButton(name: staffName, onTap: onStaff),
          if (isChef) ...[
            const SizedBox(width: KassaTokens.spaceXs),
            _SettingsButton(active: settingsActive, onTap: onSettings),
          ],
        ],
      ),
    );
  }
}

/// "Kein Internet. Bar bonieren geht weiter." in `warnBg`.
class _OfflinePill extends StatelessWidget {
  const _OfflinePill();

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Container(
        key: const Key('offline-pill'),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: c.warnBg,
          borderRadius: BorderRadius.circular(KassaTokens.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.wifiOff, size: 18, color: c.warnInk),
            const SizedBox(width: KassaTokens.spaceMd),
            Flexible(
              child: Text(
                L10n.of(context).shellOffline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.warnInk,
                ),
              ),
            ),
          ],
        ),
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
          area.title(L10n.of(context)),
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
      semanticLabel: L10n.of(context).shellSwitchStaff(name),
      child: Container(
        height: KassaTokens.minTap,
        padding: const EdgeInsetsDirectional.only(start: 7, end: 14),
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
  const _SettingsButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Pressable(
      key: const Key('settings'),
      onTap: onTap,
      semanticLabel: L10n.of(context).shellSettings,
      child: Container(
        width: KassaTokens.minTap,
        height: KassaTokens.minTap,
        decoration: BoxDecoration(
          color: active ? c.accentSoft : const Color(0x00000000),
          borderRadius: BorderRadius.circular(KassaTokens.radiusLg),
        ),
        child: Icon(
          LucideIcons.slidersHorizontal,
          size: 24,
          color: active ? c.accentInk : c.ink,
        ),
      ),
    );
  }
}
