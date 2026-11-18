import 'package:material_ui/material_ui.dart';

import '../../ui/app_toggle.dart';
import '../../ui/tokens.dart';

/// Karte der Einstellungen: Titel (mit [trailing] rechts, zum Beispiel einer
/// Pille), 1 dp Linie, darunter die Zeilen.
class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.title,
    required this.rows,
    this.trailing,
  });

  final String title;
  final List<Widget> rows;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KassaTokens.spaceHuge),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(KassaTokens.radiusCard),
        border: Border.all(color: c.line, width: KassaTokens.borderThin),
        boxShadow: c.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 56,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium!
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          for (final row in rows)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: c.line, width: KassaTokens.borderThin),
                ),
              ),
              child: row,
            ),
          const SizedBox(height: KassaTokens.spaceXs),
        ],
      ),
    );
  }
}

/// Eine Zeile: Titel (16 dp 700) mit Hilfezeile (14 dp, `ink2`), rechts das
/// Bedienelement [control]. Mindestens 76 dp hoch. Mit [below] steht unter dem
/// Text ein breites Bedienelement (Regler), mit [panel] ersetzt die Zeile ihren
/// Inhalt ganz (offene Rückfrage).
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    required this.help,
    this.control,
    this.below,
  });

  final String title;
  final String help;
  final Widget? control;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.bodyMedium!.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: KassaTokens.spaceXxs),
                    Text(
                      help,
                      style: text.bodyMedium!.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                        color: c.ink2,
                      ),
                    ),
                  ],
                ),
              ),
              if (control != null) ...[
                const SizedBox(width: KassaTokens.spaceXl),
                control!,
              ],
            ],
          ),
          if (below != null) ...[
            const SizedBox(height: KassaTokens.spaceXl),
            below!,
          ],
        ],
      ),
    );
  }
}

/// Schalter einer Zeile. Die Beschriftung steht in der Zeile, der Schalter
/// trägt sie nur für Screenreader.
class RowToggle extends StatelessWidget {
  const RowToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Semantics(
        container: true,
        label: label,
        toggled: value,
        onTap: () => onChanged(!value),
        child: ExcludeSemantics(
          child: AppToggle(value: value, onChanged: onChanged, label: ''),
        ),
      ),
    );
  }
}

/// Neutrale Pille ohne Punkt: "Noch nicht dabei", "Nicht eingerichtet".
class NeutralPill extends StatelessWidget {
  const NeutralPill(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.fill,
        borderRadius: BorderRadius.circular(KassaTokens.radiusPill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge!.copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: c.ink2,
        ),
      ),
    );
  }
}

/// Pille eines Geräts, das etwas braucht: `warnBg` mit `warnInk`
/// ("Nicht angemeldet").
class WarnPill extends StatelessWidget {
  const WarnPill(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.warnBg,
        borderRadius: BorderRadius.circular(KassaTokens.radiusPill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge!.copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: c.warnInk,
        ),
      ),
    );
  }
}

/// Pille eines eingerichteten Geräts: `fill`, `ink`, grüner Punkt und der Name
/// (bei langen Namen mit Auslassung).
class DevicePill extends StatelessWidget {
  const DevicePill(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Container(
      height: 30,
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: c.fill,
        borderRadius: BorderRadius.circular(KassaTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c.green, shape: BoxShape.circle),
          ),
          const SizedBox(width: KassaTokens.spaceSm),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pille mit Punkt und Wort für den Zustand einer Verbindung. [ok] ist grün
/// ("Verbunden"), sonst die Warnfläche ("Gesperrt", "Unbekannt", "Nicht
/// geladen"). Der Zustand steht immer im Wort, die Farbe ergänzt ihn nur.
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final bg = ok ? c.veganBg : c.warnBg;
    final fg = ok ? c.veganFg : c.warnInk;
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(KassaTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: ok ? c.green : fg,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: KassaTokens.spaceSm),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge!.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Satz in der Warnfläche: etwas stimmt nicht, und was zu tun ist.
class WarnBox extends StatelessWidget {
  const WarnBox(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.warnBg,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          height: 1.3,
          color: c.warnInk,
        ),
      ),
    );
  }
}
