import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/devices/channel_transport.dart';
import 'package:kassa/devices/device_providers.dart';
import 'package:kassa/devices/escpos.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/devices/printer_discovery.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answer(Future<Object?>? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(printerChannel, handler);
    addTearDown(() => messenger.setMockMethodCallHandler(printerChannel, null));
  }

  Future<PrintProblem?> problemOfSend(ChannelTransport transport) async {
    try {
      await transport.send(Uint8List.fromList([1, 2, 3]));
      return null;
    } on PrinterException catch (e) {
      return e.problem;
    }
  }

  test('send reicht Art, Adresse und Bytes an den Kanal', () async {
    final calls = <MethodCall>[];
    answer((call) async {
      calls.add(call);
      return null;
    });

    await ChannelTransport(
      PrinterKind.usb,
      '1155:22304',
    ).send(Uint8List.fromList([27, 64, 10]));
    await ChannelTransport(
      PrinterKind.bluetooth,
      '00:11:22:33:44:55',
    ).send(Uint8List.fromList([10]));

    expect(calls, hasLength(2));
    expect(calls[0].method, 'send');
    final usb = calls[0].arguments as Map;
    expect(usb['kind'], 'usb');
    expect(usb['address'], '1155:22304');
    expect(usb['bytes'], isA<Uint8List>());
    expect(usb['bytes'], [27, 64, 10]);
    final bluetooth = calls[1].arguments as Map;
    expect(bluetooth['kind'], 'bluetooth');
    expect(bluetooth['address'], '00:11:22:33:44:55');
    expect(bluetooth['bytes'], [10]);
  });

  test('status reicht die Frage weiter und gibt das Byte zurück', () async {
    MethodCall? seen;
    answer((call) async {
      seen = call;
      return 0x12;
    });

    final state = await ChannelTransport(
      PrinterKind.usb,
      '1:2',
    ).status(escposStatusPrinter);

    expect(state, 0x12);
    expect(seen!.method, 'status');
    final args = seen!.arguments as Map;
    expect(args['kind'], 'usb');
    expect(args['address'], '1:2');
    expect(args['request'], isA<Uint8List>());
    expect(args['request'], escposStatusPrinter);
  });

  test('status: keine Antwort oder ein Fehler ergibt null', () async {
    answer((call) async => null);
    expect(await ChannelTransport(PrinterKind.usb, '1:2').status([1]), isNull);

    answer((call) async => throw PlatformException(code: 'unreachable'));
    expect(
      await ChannelTransport(PrinterKind.bluetooth, 'AA').status([1]),
      isNull,
    );
  });

  test(
    'Fehlercode no_permission wird PrinterException(noPermission)',
    () async {
      answer((call) async => throw PlatformException(code: 'no_permission'));
      expect(
        await problemOfSend(ChannelTransport(PrinterKind.usb, '1:2')),
        PrintProblem.noPermission,
      );
    },
  );

  test(
    'Fehlercode unreachable und jeder unbekannte Code werden unreachable',
    () async {
      answer((call) async => throw PlatformException(code: 'unreachable'));
      expect(
        await problemOfSend(ChannelTransport(PrinterKind.bluetooth, 'AA')),
        PrintProblem.unreachable,
      );

      answer((call) async => throw PlatformException(code: 'etwas_anderes'));
      expect(
        await problemOfSend(ChannelTransport(PrinterKind.bluetooth, 'AA')),
        PrintProblem.unreachable,
      );
    },
  );

  test('Fehlercode timeout wird timeout', () async {
    answer((call) async => throw PlatformException(code: 'timeout'));
    expect(
      await problemOfSend(ChannelTransport(PrinterKind.usb, '1:2')),
      PrintProblem.timeout,
    );
  });

  test('listUsb und listBluetooth werden zu FoundPrinter', () async {
    answer((call) async {
      switch (call.method) {
        case 'listUsb':
          return [
            {'name': 'TM-T20III', 'address': '1208:3605'},
          ];
        case 'listBluetooth':
          return [
            {'name': 'MTP-II', 'address': '00:11:22:33:44:55'},
            {'name': 'Kopfhörer', 'address': 'AA:BB:CC:DD:EE:FF'},
          ];
      }
      return null;
    });
    const discovery = ChannelPrinterDiscovery();

    final usb = await discovery.usb();
    expect(usb, hasLength(1));
    expect(usb.single.kind, PrinterKind.usb);
    expect(usb.single.name, 'TM-T20III');
    expect(usb.single.address, '1208:3605');

    final bluetooth = await discovery.bluetooth();
    expect(bluetooth.map((p) => p.kind), [
      PrinterKind.bluetooth,
      PrinterKind.bluetooth,
    ]);
    expect(bluetooth.map((p) => p.name), ['MTP-II', 'Kopfhörer']);
    expect(bluetooth.map((p) => p.address), [
      '00:11:22:33:44:55',
      'AA:BB:CC:DD:EE:FF',
    ]);

    expect(await discovery.network(), isEmpty);
  });

  test('Suche: Fehlercode no_permission wird PrinterException', () async {
    answer((call) async => throw PlatformException(code: 'no_permission'));
    await expectLater(
      const ChannelPrinterDiscovery().bluetooth(),
      throwsA(
        isA<PrinterException>().having(
          (e) => e.problem,
          'problem',
          PrintProblem.noPermission,
        ),
      ),
    );
  });

  test(
    'der Kanal fehlt (Test ohne Android): leere Listen, send wirft unreachable',
    () async {
      messenger.setMockMethodCallHandler(printerChannel, null);
      const discovery = ChannelPrinterDiscovery();

      expect(await discovery.usb(), isEmpty);
      expect(await discovery.bluetooth(), isEmpty);
      expect(
        await problemOfSend(ChannelTransport(PrinterKind.usb, '1:2')),
        PrintProblem.unreachable,
      );
      expect(
        await ChannelTransport(PrinterKind.bluetooth, 'AA').status([1]),
        isNull,
      );
    },
  );

  test('transportFactory: usb und bluetooth ergeben ChannelTransport, ohne Adresse null', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final factory = container.read(transportFactoryProvider);

    final usb = factory(
      const RegisterSettings(
        printerKind: PrinterKind.usb,
        printerAddress: '1208:3605',
      ),
    );
    expect(usb, isA<ChannelTransport>());
    expect((usb! as ChannelTransport).kind, PrinterKind.usb);
    expect((usb as ChannelTransport).address, '1208:3605');

    final bluetooth = factory(
      const RegisterSettings(
        printerKind: PrinterKind.bluetooth,
        printerAddress: '00:11:22:33:44:55',
      ),
    );
    expect(bluetooth, isA<ChannelTransport>());
    expect((bluetooth! as ChannelTransport).kind, PrinterKind.bluetooth);
    expect((bluetooth as ChannelTransport).address, '00:11:22:33:44:55');

    expect(
      factory(const RegisterSettings(printerKind: PrinterKind.usb)),
      isNull,
    );
    expect(
      factory(
        const RegisterSettings(
          printerKind: PrinterKind.bluetooth,
          printerAddress: '  ',
        ),
      ),
      isNull,
    );
  });
}
