import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/rksv/card/reader_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answer(Future<Object?>? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(cardReaderChannel, handler);
    addTearDown(
      () => messenger.setMockMethodCallHandler(cardReaderChannel, null),
    );
  }

  Future<ReaderProblem?> problemOf(Future<Object?> Function() call) async {
    try {
      await call();
      return null;
    } on ReaderException catch (e) {
      return e.problem;
    }
  }

  final printer = {
    'address': '1208:3605',
    'name': 'TM-T20III',
    'vendorId': 1208,
    'productId': 3605,
    'deviceClass': 0,
    'granted': true,
    'interfaces': [
      {'klass': 0x07, 'subclass': 1, 'protocol': 2},
    ],
  };
  final reader = {
    'address': '1254:21905',
    'name': '',
    'vendorId': 1254,
    'productId': 21905,
    'deviceClass': 0,
    'granted': false,
    'interfaces': [
      {'klass': 0x0B, 'subclass': 0, 'protocol': 0},
    ],
  };

  test(
    'list wird zu UsbDeviceInfo; nur Klasse 0x0B gilt als Kartenleser',
    () async {
      final calls = <MethodCall>[];
      answer((call) async {
        calls.add(call);
        return [printer, reader];
      });

      final devices = await ChannelReaderTransport().list();

      expect(calls.single.method, 'list');
      expect(devices, hasLength(2));
      final p = devices[0];
      expect(p.address, '1208:3605');
      expect(p.name, 'TM-T20III');
      expect(p.vendorId, 1208);
      expect(p.productId, 3605);
      expect(p.deviceClass, 0);
      expect(p.granted, isTrue);
      expect(p.interfaces, hasLength(1));
      expect(p.interfaces.single.klass, 0x07);
      expect(p.interfaces.single.subclass, 1);
      expect(p.interfaces.single.protocol, 2);
      expect(p.isCardReader, isFalse);

      final r = devices[1];
      expect(r.address, '1254:21905');
      expect(r.name, '');
      expect(r.vendorId, 1254);
      expect(r.productId, 21905);
      expect(r.granted, isFalse);
      expect(r.interfaces.single.klass, 0x0B);
      expect(r.isCardReader, isTrue);
    },
  );

  test('ein Gerät mit Geräteklasse 0 und zwei Schnittstellen (03 und 0B) ist ein Kartenleser', () async {
    answer(
      (call) async => [
        {
          'address': '2278:13',
          'name': 'Leser mit Tasten',
          'vendorId': 2278,
          'productId': 13,
          'deviceClass': 0,
          'granted': true,
          'interfaces': [
            {'klass': 0x03, 'subclass': 0, 'protocol': 0},
            {'klass': 0x0B, 'subclass': 0, 'protocol': 0},
          ],
        },
        {
          'address': '1:2',
          'name': 'Tastatur',
          'vendorId': 1,
          'productId': 2,
          'deviceClass': 0,
          'granted': true,
          'interfaces': [
            {'klass': 0x03, 'subclass': 1, 'protocol': 1},
          ],
        },
        {
          // Die Geräteklasse allein zählt nicht, nur eine Schnittstelle.
          'address': '3:4',
          'name': '',
          'vendorId': 3,
          'productId': 4,
          'deviceClass': 0x0B,
          'granted': true,
          'interfaces': <Object?>[],
        },
      ],
    );

    final devices = await ChannelReaderTransport().list();

    expect(devices.map((d) => d.isCardReader), [true, false, false]);
    expect(devices[0].deviceClass, 0);
    expect(devices[0].interfaces.map((i) => i.klass), [0x03, 0x0B]);
    expect(devices[2].deviceClass, 0x0B);
  });

  test('list ohne Kanal ist leer; info ohne Kanal ist leer', () async {
    messenger.setMockMethodCallHandler(cardReaderChannel, null);
    final transport = ChannelReaderTransport();

    expect(await transport.list(), isEmpty);
    final info = await transport.info();
    expect(info.model, '');
    expect(info.android, '');

    answer(
      (call) async => {'model': 'Xiaomi 23073RPBFG', 'android': '14 (API 34)'},
    );
    final real = await transport.info();
    expect(real.model, 'Xiaomi 23073RPBFG');
    expect(real.android, '14 (API 34)');
  });

  test('open gibt die Deskriptoren zurück', () async {
    final calls = <MethodCall>[];
    final descriptors = Uint8List.fromList([0x12, 0x01, 0x10, 0x01, 0x00]);
    answer((call) async {
      calls.add(call);
      return {'descriptors': descriptors};
    });

    final result = await ChannelReaderTransport().open('1254:21905');

    expect(result, [0x12, 0x01, 0x10, 0x01, 0x00]);
    expect(calls.single.method, 'open');
    expect(calls.single.arguments, {'address': '1254:21905'});
  });

  test('Fehlercodes: not_found, no_permission, not_ccid, busy, not_open, timeout, io', () async {
    final transport = ChannelReaderTransport();
    const openCodes = {
      'not_found': ReaderProblem.notFound,
      'no_permission': ReaderProblem.noPermission,
      'not_ccid': ReaderProblem.notCcid,
      'busy': ReaderProblem.busy,
    };
    for (final entry in openCodes.entries) {
      answer((call) async => throw PlatformException(code: entry.key));
      expect(
        await problemOf(() => transport.open('1:2')),
        entry.value,
        reason: entry.key,
      );
    }
    const exchangeCodes = {
      'not_open': ReaderProblem.notOpen,
      'timeout': ReaderProblem.timeout,
      'io': ReaderProblem.io,
    };
    for (final entry in exchangeCodes.entries) {
      answer((call) async => throw PlatformException(code: entry.key));
      expect(
        await problemOf(
          () => transport.exchange(
            Uint8List.fromList([0x62]),
            limit: const Duration(seconds: 1),
          ),
        ),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test(
    'ein unbekannter Fehlercode wird io; MissingPluginException wird noChannel',
    () async {
      final transport = ChannelReaderTransport();
      answer((call) async => throw PlatformException(code: 'etwas_anderes'));
      expect(await problemOf(() => transport.open('1:2')), ReaderProblem.io);
      expect(
        await problemOf(
          () => transport.exchange(null, limit: const Duration(seconds: 1)),
        ),
        ReaderProblem.io,
      );

      messenger.setMockMethodCallHandler(cardReaderChannel, null);
      expect(
        await problemOf(() => transport.open('1:2')),
        ReaderProblem.noChannel,
      );
      expect(
        await problemOf(
          () => transport.exchange(null, limit: const Duration(seconds: 1)),
        ),
        ReaderProblem.noChannel,
      );
    },
  );

  test(
    'exchange reicht out und timeoutMs durch; out == null bleibt null',
    () async {
      final calls = <MethodCall>[];
      answer((call) async {
        calls.add(call);
        return Uint8List.fromList([0x80, 0, 0, 0, 0, 0, 1, 0, 0, 0]);
      });
      final transport = ChannelReaderTransport();

      final first = await transport.exchange(
        Uint8List.fromList([0x62, 0, 0, 0, 0, 0, 1, 0, 0, 0]),
        limit: const Duration(milliseconds: 2500),
      );
      final second = await transport.exchange(
        null,
        limit: const Duration(seconds: 3),
      );

      expect(first, [0x80, 0, 0, 0, 0, 0, 1, 0, 0, 0]);
      expect(second, [0x80, 0, 0, 0, 0, 0, 1, 0, 0, 0]);
      expect(calls.map((c) => c.method), ['exchange', 'exchange']);
      final a = calls[0].arguments as Map;
      expect(a['out'], isA<Uint8List>());
      expect(a['out'], [0x62, 0, 0, 0, 0, 0, 1, 0, 0, 0]);
      expect(a['timeoutMs'], 2500);
      final b = calls[1].arguments as Map;
      expect(b.containsKey('out'), isTrue);
      expect(b['out'], isNull);
      expect(b['timeoutMs'], 3000);
    },
  );

  test('close wirft nie, auch wenn der Kanal einen Fehler meldet', () async {
    final calls = <MethodCall>[];
    answer((call) async {
      calls.add(call);
      throw PlatformException(code: 'io');
    });
    final transport = ChannelReaderTransport();

    await transport.close();
    expect(calls.single.method, 'close');

    messenger.setMockMethodCallHandler(cardReaderChannel, null);
    await transport.close();
  });
}
