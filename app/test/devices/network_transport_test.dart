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

  group('aufgegebene Aufrufe', () {
    // Verbindet nach [delay] und zählt die Server-Sicht mit.
    Future<Socket> Function(String, int, Duration) slowConnector(
      Future<void> delay,
    ) => (host, port, limit) async {
      await delay;
      return Socket.connect(host, port);
    };

    test('Zustandsfrage: kommt die Verbindung nach dem 1-Sekunden-Limit, wird sie geschlossen und nichts geschickt', () async {
      final data = <int>[];
      final closed = Completer<void>();
      server.listen((s) {
        sockets.add(s);
        s.listen(data.addAll, onDone: closed.complete);
      });
      final t = NetworkTransport(
        '127.0.0.1:${server.port}',
        connector: slowConnector(
          Future<void>.delayed(const Duration(milliseconds: 1300)),
        ),
      );
      expect(await t.status(escposStatusPrinter), isNull);
      await closed.future.timeout(const Duration(seconds: 3));
      expect(data, isEmpty);
    });

    test(
      'abandon: eine noch verbindende send-Anfrage schreibt nichts mehr',
      () async {
        final data = <int>[];
        final closed = Completer<void>();
        server.listen((s) {
          sockets.add(s);
          s.listen(data.addAll, onDone: closed.complete);
        });
        final gate = Completer<void>();
        final t = NetworkTransport(
          '127.0.0.1:${server.port}',
          connector: slowConnector(gate.future),
        );
        final sending = t.send(Uint8List.fromList([1, 2, 3]));
        final result = sending.then<Object?>(
          (_) => null,
          onError: (Object e) => e,
        );
        t.abandon();
        gate.complete();
        expect(await result, isA<PrinterException>());
        await closed.future.timeout(const Duration(seconds: 3));
        expect(data, isEmpty);
      },
    );

    test('ein langer Küchenbon: send darf das Limit des ganzen Aufrufs '
        'nutzen, nicht nur 5 Sekunden', () async {
      final received = Completer<List<int>>();
      server.listen((s) {
        sockets.add(s);
        final data = <int>[];
        s.listen(data.addAll, onDone: () => received.complete(data));
      });
      // Verbindung und Übertragung brauchen zusammen länger als 5 Sekunden.
      final t = NetworkTransport(
        '127.0.0.1:${server.port}',
        connector: slowConnector(
          Future<void>.delayed(const Duration(milliseconds: 5400)),
        ),
      );
      t.startCall(rasterCallLimit);
      await t.send(Uint8List.fromList([1, 2, 3]));
      expect(await received.future, [1, 2, 3]);
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('send endet spätestens mit dem Limit des Aufrufs', () async {
      server.listen(sockets.add);
      final t = NetworkTransport(
        '127.0.0.1:${server.port}',
        connector: slowConnector(
          Future<void>.delayed(const Duration(seconds: 2)),
        ),
      );
      t.startCall(const Duration(milliseconds: 300));
      final watch = Stopwatch()..start();
      await expectLater(
        t.send(Uint8List.fromList([1])),
        throwsA(
          isA<PrinterException>().having(
            (e) => e.problem,
            'problem',
            PrintProblem.timeout,
          ),
        ),
      );
      expect(watch.elapsed, lessThan(const Duration(milliseconds: 1500)));
    });

    test('abandon schließt eine offene Verbindung', () async {
      final closed = Completer<void>();
      server.listen((s) {
        sockets.add(s); // schweigt
        s.listen((_) {}, onDone: closed.complete);
      });
      final t = NetworkTransport('127.0.0.1:${server.port}');
      final asking = t.status(escposStatusPrinter);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      t.abandon();
      await closed.future.timeout(const Duration(seconds: 1));
      expect(await asking, isNull);
    });
  });
}
