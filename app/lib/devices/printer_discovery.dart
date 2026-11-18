// Sucht Bondrucker, die die Kassa verwenden kann.

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

  @override
  Future<List<FoundPrinter>> network() async => const [];

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

final printerDiscoveryProvider = Provider<PrinterDiscovery>(
  (ref) => const ChannelPrinterDiscovery(),
);
