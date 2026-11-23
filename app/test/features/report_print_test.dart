import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/devices/device_providers.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/domain/day.dart';
import 'package:kassa/domain/period_report.dart';
import 'package:kassa/features/close/report_print.dart';

import '../support/fake_devices.dart';
import '../support/report_samples.dart';
import '../support/sales.dart';

/// Hält fest, mit welchen Angaben der Drucker gerufen wurde.
class _SpyPrinter extends FakePrinter {
  final calls = <String>[];

  @override
  Future<PrintOutcome> printDayReport(
    DaySummary summary, {
    required String? registerName,
    required bool drawer,
  }) {
    calls.add('day:$registerName:$drawer');
    return super.printDayReport(
      summary,
      registerName: registerName,
      drawer: drawer,
    );
  }

  @override
  Future<PrintOutcome> printPeriodReport(
    PeriodReport report, {
    required String? registerName,
  }) {
    calls.add('period:$registerName');
    return super.printPeriodReport(report, registerName: registerName);
  }
}

class _Throwing extends FakePrinter {
  @override
  Future<PrintOutcome> printDayReport(
    DaySummary summary, {
    required String? registerName,
    required bool drawer,
  }) async => throw StateError('x');

  @override
  Future<PrintOutcome> printPeriodReport(
    PeriodReport report, {
    required String? registerName,
  }) async => throw StateError('x');
}

void main() {
  late TestShop shop;
  late ProviderContainer container;

  Future<void> open(FakePrinter printer) async {
    shop = await TestShop.open();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(shop.db),
        clockProvider.overrideWithValue(shop.clock),
        receiptPrinterProvider.overrideWithValue(printer),
      ],
    );
    addTearDown(shop.db.close);
    addTearDown(container.dispose); // zuerst: Ströme enden vor der Datenbank
  }

  Future<void> configure({
    PrinterKind kind = PrinterKind.network,
    bool drawer = true,
  }) async {
    final repo = container.read(settingsRepositoryProvider);
    await repo.save(
      (await repo.current()).copyWith(
        printerKind: kind,
        printerAddress: kind == PrinterKind.none ? null : '192.168.0.50',
        cashDrawerEnabled: drawer,
      ),
    );
  }

  test(
    'ohne eingerichteten Drucker: notSetUp, der Drucker wird nicht gerufen',
    () async {
      final printer = FakePrinter();
      await open(printer);
      await configure(kind: PrinterKind.none);
      final service = container.read(reportPrintProvider);
      expect(
        (await service.printDay(sampleDay())).problem,
        PrintProblem.notSetUp,
      );
      expect(
        (await service.printPeriod(samplePeriod())).problem,
        PrintProblem.notSetUp,
      );
      expect(printer.log, isEmpty);
    },
  );

  test('Name der Kassa und Geldlade kommen aus dem Stand des Abgleichs und den Einstellungen', () async {
    final printer = _SpyPrinter();
    await open(printer);
    await configure(drawer: false);
    await container
        .read(syncStateRepositoryProvider)
        .saveRegister(
          registerId: 'r1',
          registerName: 'Kassa 1',
          businessId: 'b1',
        );
    final service = container.read(reportPrintProvider);
    expect((await service.printDay(sampleDay(id: 'd7'))).ok, isTrue);
    expect((await service.printPeriod(samplePeriod())).ok, isTrue);
    expect(printer.calls, ['day:Kassa 1:false', 'period:Kassa 1']);
    expect(printer.log, ['day-report:d7', 'period-report:2026-09..2026-10']);
    expect(printer.printed, isEmpty);

    await configure(drawer: true);
    await service.printDay(sampleDay());
    expect(printer.calls.last, 'day:Kassa 1:true');
  });

  test('ohne gekoppelte Kassa wird ohne Namen gedruckt', () async {
    final printer = _SpyPrinter();
    await open(printer);
    await configure();
    await container.read(reportPrintProvider).printPeriod(samplePeriod());
    expect(printer.calls, ['period:null']);
  });

  test('wirft der Drucker, ist das Ergebnis unreachable', () async {
    await open(_Throwing());
    await configure();
    final service = container.read(reportPrintProvider);
    expect(
      (await service.printDay(sampleDay())).problem,
      PrintProblem.unreachable,
    );
    expect(
      (await service.printPeriod(samplePeriod())).problem,
      PrintProblem.unreachable,
    );
  });

  test('printerSetUpProvider folgt den Einstellungen', () async {
    await open(FakePrinter());
    final seen = <bool>[];
    final sub = container.listen(
      printerSetUpProvider,
      (_, v) => seen.add(v),
      fireImmediately: true,
    );
    addTearDown(sub.close);
    expect(seen.last, isFalse); // noch nichts geladen
    await configure();
    for (var i = 0; i < 50 && !seen.last; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(seen.last, isTrue);
  });
}
