import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/devices/device_providers.dart';
import 'package:kassa/devices/printer.dart';

void main() {
  test(
    'solange Einstellungen oder Betriebsdaten laden: notSetUp, keine Ausnahme',
    () async {
      final never = StreamController<RegisterSettings>();
      addTearDown(never.close);
      final container = ProviderContainer(
        overrides: [
          settingsStreamProvider.overrideWith((ref) => never.stream),
          catalogStreamProvider.overrideWith((ref) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);
      final printer = container.read(receiptPrinterProvider);
      expect((await printer.openDrawer()).problem, PrintProblem.notSetUp);
      expect((await printer.testPrint()).problem, PrintProblem.notSetUp);
    },
  );
}
