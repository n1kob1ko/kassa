import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/devices/printer_discovery.dart';

void main() {
  group('Netzsuche', () {
    test('probeHosts findet den, der den Port annimmt', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((s) => s.destroy());
      final found = await probeHosts(
        ['127.0.0.1', '127.0.0.2'],
        port: server.port,
        limit: const Duration(milliseconds: 400),
      );
      // 127.0.0.2 ist auch dieser Rechner, hört aber nicht auf diese Adresse.
      expect(found, ['127.0.0.1']);
    });

    test(
      'probeHosts: Zeitgrenze und Fehler zählen als nicht gefunden',
      () async {
        final found = await probeHosts(
          ['a', 'b', 'c'],
          connector: (host, port, limit) async {
            if (host == 'a') throw const SocketException('nein');
            if (host == 'b') throw TimeoutException('zu langsam');
            return _Closed();
          },
        );
        expect(found, ['c']);
      },
    );

    test('probeHosts probiert höchstens 32 gleichzeitig', () async {
      var running = 0;
      var peak = 0;
      final hosts = [for (var i = 1; i <= 254; i++) '10.0.0.$i'];
      final found = await probeHosts(
        hosts,
        connector: (host, port, limit) async {
          running++;
          if (running > peak) peak = running;
          await Future<void>.delayed(const Duration(milliseconds: 1));
          running--;
          throw const SocketException('nein');
        },
      );
      expect(found, isEmpty);
      expect(peak, 32);
    });

    test('subnetHosts: alle 254 Adressen des /24-Netzes', () {
      final hosts = subnetHosts('192.168.1.20');
      expect(hosts, hasLength(254));
      expect(hosts.first, '192.168.1.1');
      expect(hosts.last, '192.168.1.254');
      expect(subnetHosts('10.0.5.200'), hasLength(254));
      expect(subnetHosts('10.0.5.200'), contains('10.0.5.1'));
    });
  });
}

class _Closed extends Fake implements Socket {
  @override
  void destroy() {}
}
