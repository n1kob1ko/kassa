import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import 'cash_sheet.dart';

/// Nach dem Bezahlen: "Bezahlt", die Bon-Nummer und das Rückgeld, das die
/// Person jetzt herausgibt. "Nächster Kunde" führt zur leeren Kassa zurück.
class SaleDone extends ConsumerWidget {
  const SaleDone({
    super.key,
    required this.number,
    required this.changeCents,
    required this.onNext,
  });

  final int number;
  final int changeCents;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final drawer =
        (ref.watch(settingsStreamProvider).value ?? const RegisterSettings())
            .cashDrawerEnabled;
    return PayColumnFrame(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
              child: Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: c.green,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.check,
                          size: 34,
                          color: c.onAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Bezahlt',
                      style: text.headlineLarge!.copyWith(fontSize: 30),
                    ),
                    const SizedBox(height: KassaTokens.spaceXs),
                    Text(
                      'Bon Nr. $number',
                      key: const Key('receipt-number'),
                      style: text.bodyLarge!.copyWith(
                        fontWeight: FontWeight.w400,
                        color: c.ink2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.accentSoft,
                        borderRadius: BorderRadius.circular(
                          KassaTokens.radiusXxl,
                        ),
                      ),
                      child: changeCents == 0
                          ? Text(
                              'Passend bezahlt',
                              style: text.titleLarge!.copyWith(
                                color: c.accentInk,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  drawer
                                      ? 'Rückgeld aus der Lade geben'
                                      : 'Rückgeld geben',
                                  style: text.bodyLarge!.copyWith(
                                    color: c.accentInk,
                                  ),
                                ),
                                const SizedBox(height: KassaTokens.spaceXs),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    formatEuro(changeCents),
                                    key: const Key('change-done'),
                                    maxLines: 1,
                                    style: text.displayLarge!.copyWith(
                                      color: c.ink,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: PrimaryButton(
              key: const Key('next-customer'),
              label: 'Nächster Kunde',
              filled: false,
              solid: true,
              height: KassaTokens.mainActionHeight,
              onPressed: onNext,
            ),
          ),
        ],
      ),
    );
  }
}
