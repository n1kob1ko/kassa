import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/devices/escpos.dart';
import 'package:kassa/devices/network_transport.dart';
import 'package:kassa/devices/printer.dart';

void main() {
  late ServerSocket server;
  final sockets = <Socket>[];

  setUp(() async {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  });

  tearDown(() async {
    for (final s in sockets) {
      s.destroy();
    }
    sockets.clear();
    await server.close();
  });

  test('schickt die Bytes an den Drucker', () async {
    final received = Completer<List<int>>();
    server.listen((s) {
      sockets.add(s);
      final data = <int>[];
      s.listen(data.addAll, onDone: () => received.complete(data));
    });
    await NetworkTransport('127.0.0.1:${server.port}')
        .send(Uint8List.fromList([1, 2, 3]));
    expect(await received.future, [1, 2, 3]);
  });

  test(
    'niemand hört zu: PrinterException unreachable in unter 4 Sekunden',
    () async {
      final port = server.port;
      await server.close();
      final watch = Stopwatch()..start();
      await expectLater(
        NetworkTransport('127.0.0.1:$port').send(Uint8List.fromList([1])),
        throwsA(
          isA<PrinterException>().having(
            (e) => e.problem,
            'problem',
            PrintProblem.unreachable,
          ),
        ),
      );
      expect(watch.elapsed, lessThan(const Duration(seconds: 4)));
      // tearDown schließt den schon geschlossenen Server erneut: harmlos.
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    },
  );

  test('Adresse ohne Port nimmt 9100', () {
    final t = NetworkTransport('192.168.1.50');
    expect(t.host, '192.168.1.50');
    expect(t.port, 9100);
  });

  test('Adresse mit Port', () {
    final t = NetworkTransport('drucker.local:9101');
    expect(t.host, 'drucker.local');
    expect(t.port, 9101);
  });

  test('Drucker antwortet auf die Zustandsfrage', () async {
    final asked = Completer<List<int>>();
    server.listen((s) {
      sockets.add(s);
      s.listen((d) {
        asked.complete(d);
        s.add([0x12]);
      });
    });
    final answer = await NetworkTransport('127.0.0.1:${server.port}')
        .status(escposStatusPrinter);
    expect(answer, 0x12);
    expect(await asked.future, escposStatusPrinter);
  });

  test(
    'keine Antwort auf die Zustandsfrage ergibt null nach höchstens 1 Sekunde',
    () async {
      server.listen(sockets.add); // nimmt an, schweigt
      final watch = Stopwatch()..start();
      final answer = await NetworkTransport('127.0.0.1:${server.port}')
          .status(escposStatusPrinter);
      expect(answer, isNull);
      expect(watch.elapsed, lessThan(const Duration(milliseconds: 1500)));
    },
  );

  test('Zustandsfrage ohne Drucker ergibt null', () async {
    final port = server.port;
    await server.close();
    expect(
      await NetworkTransport('127.0.0.1:$port').status(escposStatusPrinter),
      isNull,
    );
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  });
}
