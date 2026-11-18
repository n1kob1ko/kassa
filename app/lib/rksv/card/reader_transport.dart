// Der USB-Kartenleser: Android öffnet ihn und schiebt Bytes hin und her, Dart
// spricht mit ihm über den Kanal `kassa/cardreader` (siehe
// CardReaderChannel.kt). Der Kanal kennt keine Nachrichtentypen und verändert
// keine Bytes.

import 'package:flutter/services.dart';

const cardReaderChannel = MethodChannel('kassa/cardreader');

/// Was beim Kartenleser schiefging. [noChannel]: kein Android (Tests, andere
/// Plattformen).
enum ReaderProblem {
  noChannel,
  notFound,
  noPermission,
  notCcid,
  busy,
  notOpen,
  timeout,
  io,
}

class ReaderException implements Exception {
  const ReaderException(this.problem);

  final ReaderProblem problem;

  @override
  String toString() => 'ReaderException(${problem.name})';
}

/// Übersetzt einen Fehlercode des Kanals; ein unbekannter Code heißt [io].
ReaderProblem problemOfReaderError(String code) => switch (code) {
  'not_found' => ReaderProblem.notFound,
  'no_permission' => ReaderProblem.noPermission,
  'not_ccid' => ReaderProblem.notCcid,
  'busy' => ReaderProblem.busy,
  'not_open' => ReaderProblem.notOpen,
  'timeout' => ReaderProblem.timeout,
  _ => ReaderProblem.io,
};

/// Klasse der Chipkartenleser (CCID) bei USB-Schnittstellen.
const usbClassSmartCard = 0x0B;

/// Eine Schnittstelle eines USB-Geräts.
class UsbInterfaceInfo {
  const UsbInterfaceInfo(this.klass, this.subclass, this.protocol);

  final int klass;
  final int subclass;
  final int protocol;
}

/// Ein angestecktes USB-Gerät, wie Android es meldet.
class UsbDeviceInfo {
  const UsbDeviceInfo({
    required this.address,
    required this.name,
    required this.vendorId,
    required this.productId,
    required this.deviceClass,
    required this.granted,
    required this.interfaces,
  });

  factory UsbDeviceInfo.fromChannel(Map<Object?, Object?> map) => UsbDeviceInfo(
    address: map['address'] as String? ?? '',
    name: map['name'] as String? ?? '',
    vendorId: map['vendorId'] as int? ?? 0,
    productId: map['productId'] as int? ?? 0,
    deviceClass: map['deviceClass'] as int? ?? 0,
    granted: map['granted'] as bool? ?? false,
    interfaces: [
      for (final raw in map['interfaces'] as List? ?? const [])
        if (raw is Map)
          UsbInterfaceInfo(
            raw['klass'] as int? ?? 0,
            raw['subclass'] as int? ?? 0,
            raw['protocol'] as int? ?? 0,
          ),
    ],
  );

  /// `<vendorId>:<productId>`, beides dezimal.
  final String address;

  /// Produktname oder `''`.
  final String name;
  final int vendorId;
  final int productId;
  final int deviceClass;

  /// Ob die Kassa das Gerät schon verwenden darf.
  final bool granted;
  final List<UsbInterfaceInfo> interfaces;

  /// Ein Kartenleser hat eine Schnittstelle der Klasse 0x0B; die Geräteklasse
  /// allein zählt nicht (sie ist meist 0).
  bool get isCardReader => interfaces.any((i) => i.klass == usbClassSmartCard);
}

/// Das Tablet, für den Bericht.
class TabletInfo {
  const TabletInfo(this.model, this.android);

  /// Hersteller und Modell, z. B. `Xiaomi 23073RPBFG`.
  final String model;

  /// z. B. `14 (API 34)`.
  final String android;
}

abstract interface class ReaderTransport {
  /// Alle angesteckten USB-Geräte; ohne Kanal eine leere Liste.
  Future<List<UsbDeviceInfo>> list();

  /// Öffnet den Leser unter [address] und gibt seine rohen Deskriptoren
  /// zurück. Ein schon offener Leser wird vorher geschlossen.
  Future<Uint8List> open(String address);

  /// Schreibt [out] (wenn gesetzt) und liest genau eine vollständige
  /// Nachricht des Lesers. [limit] gilt für den ganzen Aufruf.
  Future<Uint8List> exchange(Uint8List? out, {required Duration limit});

  /// Gibt den Leser frei; wirft nie.
  Future<void> close();

  /// Modell und Android-Version; ohne Kanal `TabletInfo('', '')`.
  Future<TabletInfo> info();
}

class ChannelReaderTransport implements ReaderTransport {
  ChannelReaderTransport({this.channel = cardReaderChannel});

  final MethodChannel channel;

  @override
  Future<List<UsbDeviceInfo>> list() async {
    try {
      final raw = await channel.invokeListMethod<Object?>('list');
      return [
        for (final device in raw ?? const <Object?>[])
          if (device is Map) UsbDeviceInfo.fromChannel(device),
      ];
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  @override
  Future<Uint8List> open(String address) async {
    final answer = await _call<Map<Object?, Object?>>('open', {
      'address': address,
    });
    final descriptors = answer?['descriptors'];
    if (descriptors is! Uint8List) {
      throw const ReaderException(ReaderProblem.io);
    }
    return descriptors;
  }

  @override
  Future<Uint8List> exchange(Uint8List? out, {required Duration limit}) async {
    final answer = await _call<Uint8List>('exchange', {
      'out': out,
      'timeoutMs': limit.inMilliseconds,
    });
    if (answer == null) throw const ReaderException(ReaderProblem.io);
    return answer;
  }

  @override
  Future<void> close() async {
    try {
      await channel.invokeMethod<void>('close');
    } catch (_) {
      // Schließen gelingt immer, auch ohne Kanal.
    }
  }

  @override
  Future<TabletInfo> info() async {
    try {
      final raw = await channel.invokeMapMethod<Object?, Object?>('info');
      return TabletInfo(
        raw?['model'] as String? ?? '',
        raw?['android'] as String? ?? '',
      );
    } on MissingPluginException {
      return const TabletInfo('', '');
    } on PlatformException {
      return const TabletInfo('', '');
    }
  }

  Future<T?> _call<T>(String method, Map<String, Object?> arguments) async {
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw ReaderException(problemOfReaderError(e.code));
    } on MissingPluginException {
      throw const ReaderException(ReaderProblem.noChannel);
    }
  }
}
