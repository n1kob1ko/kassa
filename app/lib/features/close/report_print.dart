// Berichte drucken: Tagesabschluss und Abrechnung gehen über denselben
// Drucker wie die Bons. Ein Bericht schreibt nichts und öffnet nie die Lade.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../devices/device_providers.dart';
import '../../devices/printer.dart';
import '../../domain/day.dart';
import '../../domain/period_report.dart';

class ReportPrintService {
  ReportPrintService(this._ref);

  final Ref _ref;

  Future<PrintOutcome> printDay(DaySummary summary) => _print(
    (printer, settings, name) => printer.printDayReport(
      summary,
      registerName: name,
      drawer: settings.cashDrawerEnabled,
    ),
  );

  Future<PrintOutcome> printPeriod(PeriodReport report) => _print(
    (printer, settings, name) =>
        printer.printPeriodReport(report, registerName: name),
  );

  /// Ohne eingerichteten Drucker `notSetUp` (der Drucker wird nicht gerufen);
  /// ein unerwarteter Fehler ist `unreachable`.
  Future<PrintOutcome> _print(
    Future<PrintOutcome> Function(
      ReceiptPrinter printer,
      RegisterSettings settings,
      String? registerName,
    )
    run,
  ) async {
    try {
      final settings = await _ref.read(settingsRepositoryProvider).current();
      if (settings.printerKind == PrinterKind.none) {
        return const PrintOutcome.failed(PrintProblem.notSetUp);
      }
      return await run(
        _ref.read(receiptPrinterProvider),
        settings,
        await _registerName(),
      );
    } catch (_) {
      return const PrintOutcome.failed(PrintProblem.unreachable);
    }
  }

  /// Der Name kann fehlen (nicht gekoppelt); ein Lesefehler hält den Druck
  /// nicht auf.
  Future<String?> _registerName() async {
    try {
      return (await _ref.read(syncStateRepositoryProvider).current())
          .registerName;
    } catch (_) {
      return null;
    }
  }
}

final reportPrintProvider = Provider<ReportPrintService>(
  ReportPrintService.new,
);

/// Wahr, wenn in den Einstellungen ein Drucker eingerichtet ist.
final printerSetUpProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsStreamProvider).value;
  return settings != null && settings.printerKind != PrinterKind.none;
});
