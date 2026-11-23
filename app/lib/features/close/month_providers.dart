// Die Zahlen der Monatsabrechnung am Tablet. Alles nur gelesen; wird
// verworfen, sobald der Bereich nicht mehr angezeigt wird.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/period_report.dart';
import '../../domain/receipt.dart';

/// Welche Monate sich abrechnen lassen.
final monthChoiceProvider = FutureProvider.autoDispose<MonthChoice>(
  (ref) => ref.watch(periodReportRepositoryProvider).choice(),
);

/// Die Abrechnung über einen Zeitraum aus [monthChoiceProvider].
final periodReportProvider = FutureProvider.autoDispose
    .family<PeriodReport, MonthRange>(
      (ref, range) => ref.watch(periodReportRepositoryProvider).report(range),
    );

/// Monats- oder Jahresbeleg zum Monat; null ohne Beleg.
final signatureReceiptProvider = FutureProvider.autoDispose
    .family<Receipt?, YearMonth>((ref, month) async {
      final id = await ref
          .watch(periodReportRepositoryProvider)
          .signatureReceiptId(month);
      if (id == null) return null;
      return ref.watch(receiptRepositoryProvider).find(id);
    });

/// Wahr, wenn die Signatur eingerichtet ist oder war.
final hasSignatureProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(periodReportRepositoryProvider).hasSignature(),
);
