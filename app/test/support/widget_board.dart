// Tafel für Bildvergleiche: alle Bausteine der Oberfläche in allen Zuständen.

import 'package:kassa/ui/app_header.dart';
import 'package:kassa/ui/app_toggle.dart';
import 'package:kassa/ui/keypad.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:kassa/ui/segmented.dart';
import 'package:kassa/ui/tokens.dart';
import 'package:kassa/ui/undo_toast.dart';
import 'package:material_ui/material_ui.dart';

class WidgetBoard extends StatelessWidget {
  const WidgetBoard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return ColoredBox(
      color: c.ground,
      child: Padding(
        padding: const EdgeInsets.all(KassaTokens.spaceXxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(KassaTokens.radiusMd),
              child: AppHeader(
                area: AppArea.bons,
                onArea: (_) {},
                staffName: 'Chef',
                isChef: true,
                onStaff: () {},
                onSettings: () {},
              ),
            ),
            const SizedBox(height: KassaTokens.spaceMd),
            ClipRRect(
              borderRadius: BorderRadius.circular(KassaTokens.radiusMd),
              child: AppHeader(
                area: AppArea.kassa,
                onArea: (_) {},
                staffName: 'Anna',
                isChef: false,
                onStaff: () {},
                onSettings: () {},
              ),
            ),
            const SizedBox(height: KassaTokens.spaceXxl),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(KassaTokens.spaceXxl),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(KassaTokens.radiusCard),
                  border: Border.all(color: c.line),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 190, child: Keypad(onKey: (_) {})),
                    const SizedBox(width: KassaTokens.spaceXxl),
                    SizedBox(
                      width: 190,
                      child: Keypad(onKey: (_) {}, showComma: false),
                    ),
                    const SizedBox(width: KassaTokens.spaceXxl),
                    Expanded(child: _Rest()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: KassaTokens.spaceMd);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: KassaTokens.spaceXxl,
          children: [
            SizedBox(
              width: 124,
              child: AppToggle(value: true, onChanged: (_) {}, label: 'An'),
            ),
            SizedBox(
              width: 124,
              child: AppToggle(value: false, onChanged: (_) {}, label: 'Aus'),
            ),
            const SizedBox(
              width: 150,
              child: AppToggle(
                value: false,
                onChanged: null,
                label: 'Gesperrt',
              ),
            ),
          ],
        ),
        gap,
        Segmented<int>(
          segments: const [(0, 'Mit Bildern'), (1, 'Kompakt')],
          selected: 0,
          onSelected: (_) {},
        ),
        const SizedBox(height: KassaTokens.spaceXxl),
        UndoToastView(message: 'Bon geleert', onUndo: () {}),
        const SizedBox(height: KassaTokens.spaceXxl),
        Row(
          children: [
            Expanded(
              child: PrimaryButton(label: 'Bar', onPressed: () {}),
            ),
            const SizedBox(width: KassaTokens.spaceLg),
            Expanded(
              child: PrimaryButton(
                label: 'Abbrechen',
                filled: false,
                onPressed: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: KassaTokens.spaceLg),
        Row(
          children: [
            const Expanded(
              child: PrimaryButton(label: 'Karte', onPressed: null),
            ),
            const SizedBox(width: KassaTokens.spaceLg),
            Expanded(
              child: PrimaryButton(
                label: 'Passend',
                sublabel: '17,40 €',
                onPressed: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}
