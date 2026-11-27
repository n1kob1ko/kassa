import 'package:material_ui/material_ui.dart';

import '../../data/settings_repository.dart';
import '../../domain/feature_access.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/segmented.dart';
import 'settings_rows.dart';

/// Die Karte "Zahlen" der Einstellungen: zwei Schalter (Teil bar, Rest Karte;
/// Trinkgeld bei Kartenzahlung) und zwei Regler, wer Rabatt und freien Betrag
/// geben darf (Aus, Alle, Nur Chef); darunter aus Stufe 1b der Regler, wer
/// Pfand zurückgeben darf, und die Schalter Gutschein und Rechnung an Firma.
/// Alles ist aus, bis der Chef es einschaltet. Jede Änderung geht über [onChange] und wird sofort
/// gespeichert.
class PaymentSection extends StatelessWidget {
  const PaymentSection({
    super.key,
    required this.settings,
    required this.onChange,
  });

  final RegisterSettings settings;
  final Future<void> Function(
    RegisterSettings Function(RegisterSettings s) change,
  )
  onChange;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final s = settings;

    Widget access(
      String keyPrefix,
      FeatureAccess value,
      RegisterSettings Function(RegisterSettings s, FeatureAccess a) set,
    ) => Segmented<FeatureAccess>(
      expand: true,
      segments: [
        (FeatureAccess.off, l.settingsAccessOff),
        (FeatureAccess.all, l.settingsAccessAll),
        (FeatureAccess.chefOnly, l.settingsAccessChef),
      ],
      selected: value,
      keyFor: (a) => Key('$keyPrefix-${a.name}'),
      onSelected: (a) => onChange((s) => set(s, a)),
    );

    return SettingsCard(
      key: const Key('payment-card'),
      title: l.settingsPayments,
      rows: [
        SettingsRow(
          title: l.settingsSplitPayment,
          control: RowToggle(
            key: const Key('toggle-split-payment'),
            label: l.settingsSplitPayment,
            value: s.splitPaymentEnabled,
            onChanged: (v) =>
                onChange((s) => s.copyWith(splitPaymentEnabled: v)),
          ),
        ),
        SettingsRow(
          title: l.settingsCardTip,
          control: RowToggle(
            key: const Key('toggle-card-tip'),
            label: l.settingsCardTip,
            value: s.cardTipEnabled,
            onChanged: (v) => onChange((s) => s.copyWith(cardTipEnabled: v)),
          ),
        ),
        SettingsRow(
          title: l.settingsDiscount,
          below: access(
            'discount-access',
            s.discountAccess,
            (s, a) => s.copyWith(discountAccess: a),
          ),
        ),
        SettingsRow(
          title: l.settingsOpenAmount,
          below: access(
            'open-amount-access',
            s.openAmountAccess,
            (s, a) => s.copyWith(openAmountAccess: a),
          ),
        ),
        SettingsRow(
          key: const Key('setting-deposit-return'),
          title: l.settingsDepositReturn,
          below: access(
            'setting-deposit-return',
            s.depositReturnAccess,
            (s, a) => s.copyWith(depositReturnAccess: a),
          ),
        ),
        SettingsRow(
          title: l.settingsVoucher,
          help: l.settingsVoucherInfo,
          control: RowToggle(
            key: const Key('setting-voucher'),
            label: l.settingsVoucher,
            value: s.voucherEnabled,
            onChanged: (v) => onChange((s) => s.copyWith(voucherEnabled: v)),
          ),
        ),
        SettingsRow(
          title: l.settingsInvoice,
          help: l.settingsInvoiceInfo,
          control: RowToggle(
            key: const Key('setting-invoice'),
            label: l.settingsInvoice,
            value: s.invoiceEnabled,
            onChanged: (v) => onChange((s) => s.copyWith(invoiceEnabled: v)),
          ),
        ),
      ],
    );
  }
}
