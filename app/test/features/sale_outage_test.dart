import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/devices/device_providers.dart';
import 'package:kassa/features/kassa/sale_service.dart';
import 'package:kassa/rksv/rksv_journal.dart';

import '../support/fake_devices.dart';
import '../support/fake_signature_unit.dart';
import '../support/rksv_rig.dart';
import '../support/sales.dart' show cart;

const _ms = Duration(milliseconds: 1);

/// Wartet in gedachter Zeit auf [f], ohne die Zeit weiterzudrehen.
T _await<T>(FakeAsync async, Future<T> f) {
  late T value;
  Object? error;
  var done = false;
  f.then(
    (v) {
      value = v;
      done = true;
    },
    onError: (Object e) {
      error = e;
      done = true;
    },
  );
  async.flushMicrotasks();
  if (!done) fail('Nicht fertig, ohne dass die Zeit weiterläuft.');
  if (error != null) throw error!;
  return value;
}

void main() {
  test('Verkauf im Ausfall: completeCash kommt nach höchstens der Frist '
      '(1 Sekunde) zurück, auch wenn Signatur und Drucker hängen', () {
    fakeAsync((async) {
      final rig = _await(async, RksvRig.open());
      final printer = FakePrinter()..hold = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(rig.db),
          clockProvider.overrideWithValue(rig.clock),
          receiptRepositoryProvider.overrideWithValue(rig.receipts),
          receiptPrinterProvider.overrideWithValue(printer),
        ],
      );
      try {
        final settings = container.read(settingsRepositoryProvider);
        _await(
          async,
          settings.save(
            const RegisterSettings(
              printerKind: PrinterKind.network,
              printerAddress: '192.168.0.50',
            ),
          ),
        );
        _await(async, rig.service.enableProbe(staff: rig.chef));
        final service = container.read(saleServiceProvider);
        rig.fake.mode = FakeMode.silent;

        // Der erste Verkauf wartet die volle Frist, dann beginnt der Ausfall.
        SaleResult? first;
        service
            .completeCash(
              saleId: 's1',
              cart: cart,
              givenCents: cart.totalCents,
              staff: rig.anna,
            )
            .then((r) => first = r);
        async.elapse(RksvJournal.signLimit - _ms);
        expect(first, isNull);
        async.elapse(_ms);
        expect(first, isNotNull);
        expect(first!.receipt.rksv!.damaged, isTrue);

        // Im Ausfall: höchstens 1 Sekunde, der Drucker hält nichts auf.
        SaleResult? second;
        service
            .completeCash(
              saleId: 's2',
              cart: cart,
              givenCents: cart.totalCents,
              staff: rig.anna,
            )
            .then((r) => second = r);
        async.elapse(RksvJournal.signLimitDuringOutage - _ms);
        expect(second, isNull);
        async.elapse(_ms);
        expect(second, isNotNull);
        expect(second!.receipt.rksv!.damaged, isTrue);
        expect(printer.printed, ['s1', 's2']);

        printer.hold!.complete();
        async.flushMicrotasks();
        expect(_await(async, second!.print).ok, isTrue);
        rig.fake.release();
      } finally {
        container.dispose();
        _await(async, rig.close());
      }
    });
  });
}
