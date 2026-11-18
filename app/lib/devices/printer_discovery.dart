// Sucht Bondrucker, die die Kassa verwenden kann.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';
import 'channel_transport.dart';
import 'printer.dart';

class FoundPrinter {
  const FoundPrinter({
    required this.kind,
    required this.name,
    required this.address,
  });

  final PrinterKind kind;
  final String name;

  /// USB: `<vendorId>:<productId>` dezimal; Bluetooth: die MAC-Adresse.
  final String address;
}

abstract interface class PrinterDiscovery {
  /// Angesteckte USB-Drucker.
  Future<List<FoundPrinter>> usb();

  /// Gekoppelte Bluetooth-Geräte; leer, wenn Bluetooth aus ist.
  Future<List<FoundPrinter>> bluetooth();

  /// Drucker im Netzwerk.
  Future<List<FoundPrinter>> network();

  /// Fragt nach der Erlaubnis, den Drucker zu verwenden (USB: dieses Gerät,
  /// Bluetooth: BLUETOOTH_CONNECT), ohne etwas zu drucken. Beim Auswählen
  /// des Druckers aufrufen, damit das Drucken selbst nicht fragen muss.
  /// Netzwerk braucht keine Erlaubnis.
  Future<bool> requestAccess(PrinterKind kind, String address);
}

/// Sucht über den Kanal `kassa/printer`. Ohne Android sind die Listen leer;
/// ein Fehler des Kanals (etwa keine Erlaubnis) wird [PrinterException].
class ChannelPrinterDiscovery implements PrinterDiscovery {
  const ChannelPrinterDiscovery({this.channel = printerChannel});

  final MethodChannel channel;

  @override
  Future<List<FoundPrinter>> usb() => _list('listUsb', PrinterKind.usb);

  @override
  Future<List<FoundPrinter>> bluetooth() =>
      _list('listBluetooth', PrinterKind.bluetooth);

  /// Probiert alle Adressen des eigenen /24-Netzes auf Port 9100. Ohne
  /// Netzwerk (kein WLAN) oder bei einem Fehler: leer.
  @override
  Future<List<FoundPrinter>> network() async {
    try {
      final own = await ownNetworkAddress();
      if (own == null) return const [];
      final hosts = await probeHosts(subnetHosts(own));
      return [
        for (final host in hosts)
          FoundPrinter(
            kind: PrinterKind.network,
            name: 'Drucker $host',
            address: '$host:$rawPrintPort',
          ),
      ];
    } on Object {
      return const [];
    }
  }

  @override
  Future<bool> requestAccess(PrinterKind kind, String address) async =>
      switch (kind) {
        PrinterKind.network => true,
        PrinterKind.none => false,
        PrinterKind.usb ||
        PrinterKind.bluetooth => requestChannelAccess(channel, kind, address),
      };

  Future<List<FoundPrinter>> _list(String method, PrinterKind kind) async {
    final List<Object?>? rows;
    try {
      rows = await channel.invokeListMethod<Object?>(method);
    } on PlatformException catch (e) {
      throw PrinterException(problemOfChannelError(e.code));
    } on MissingPluginException {
      return const [];
    }
    return [
      for (final row in rows ?? const <Object?>[])
        if (row case {
          'name': final String name,
          'address': final String address,
        })
          FoundPrinter(kind: kind, name: name, address: address),
    ];
  }
}

/// Der Port, auf dem Bondrucker rohe ESC/POS-Daten annehmen.
const rawPrintPort = 9100;

/// Die eigene IPv4-Adresse im WLAN (oder Netzwerk); `null`, wenn es keine
/// gibt. Private Adressen (192.168, 10, 172.16 bis 31) gehen vor.
Future<String?> ownNetworkAddress() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
  );
  final addresses = [
    for (final i in interfaces)
      for (final a in i.addresses)
        if (!a.isLoopback && !a.isLinkLocal) a.address,
  ];
  for (final a in addresses) {
    if (_isPrivate(a)) return a;
  }
  return addresses.firstOrNull;
}

bool _isPrivate(String ip) {
  final p = ip.split('.').map(int.tryParse).toList();
  if (p.length != 4 || p.contains(null)) return false;
  return p[0] == 10 ||
      (p[0] == 192 && p[1] == 168) ||
      (p[0] == 172 && p[1]! >= 16 && p[1]! <= 31);
}

/// Alle 254 Adressen des /24-Netzes von [ownAddress].
List<String> subnetHosts(String ownAddress) {
  final prefix = ownAddress.split('.').take(3).join('.');
  return [for (var i = 1; i <= 254; i++) '$prefix.$i'];
}

/// Verbindet zu [host]:[port], höchstens [limit] lang.
typedef HostConnector = Future<Socket> Function(
  String host,
  int port,
  Duration limit,
);

/// Probiert [hosts] auf [port] und gibt die zurück, die die Verbindung
/// annehmen (in der Reihenfolge von [hosts]). Je Adresse höchstens [limit],
/// höchstens [concurrency] Verbindungen gleichzeitig. Gefundene Verbindungen
/// werden sofort wieder geschlossen, es wird nichts gesendet.
Future<List<String>> probeHosts(
  List<String> hosts, {
  int port = rawPrintPort,
  Duration limit = const Duration(milliseconds: 400),
  int concurrency = 32,
  HostConnector? connector,
}) async {
  final connect =
      connector ??
      (host, port, limit) => Socket.connect(host, port, timeout: limit);
  final found = List<bool>.filled(hosts.length, false);
  var next = 0;
  Future<void> worker() async {
    while (next < hosts.length) {
      final i = next++;
      try {
        final socket = await connect(hosts[i], port, limit);
        socket.destroy();
        found[i] = true;
      } on Object {
        // Nicht erreichbar oder Zeit abgelaufen: dort ist kein Drucker.
      }
    }
  }

  await Future.wait([
    for (var w = 0; w < concurrency && w < hosts.length; w++) worker(),
  ]);
  return [
    for (var i = 0; i < hosts.length; i++)
      if (found[i]) hosts[i],
  ];
}

final printerDiscoveryProvider = Provider<PrinterDiscovery>(
  (ref) => const ChannelPrinterDiscovery(),
);
