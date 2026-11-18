// Die Nachrichten des USB-Kartenlesers (CCID): Karte ein- und ausschalten,
// Parameter setzen, Blöcke übertragen. Darunter liegt [ReaderTransport], der
// nur Bytes hin- und herschiebt; Mehrbyte-Felder sind "little endian".

import 'dart:typed_data';

import 'probe_log.dart';
import 'reader_transport.dart';

/// Wie viel der Leser bei der Übertragung selbst übernimmt.
enum ExchangeLevel { character, tpdu, shortApdu, extendedApdu }

/// Bits aus `dwFeatures`.
abstract final class CcidFeature {
  static const autoConfig = 0x02,
      autoActivation = 0x04,
      autoVoltage = 0x08,
      autoNegotiation = 0x40,
      autoPps = 0x80,
      autoIfsd = 0x400;
}

/// Der Eintrag vom Typ `21` (54 Bytes) der Schnittstelle der Klasse `0B`.
class CcidDescriptor {
  const CcidDescriptor({
    required this.voltageSupport,
    required this.protocols,
    required this.maxIfsd,
    required this.features,
    required this.maxMessageLength,
  });

  /// Sucht in den rohen USB-Deskriptoren den Eintrag des Kartenlesers: Typ
  /// `21`, Länge `36`, nach einer Schnittstelle der Klasse `0B` und vor der
  /// nächsten Schnittstelle. [FormatException], wenn keiner da ist.
  static CcidDescriptor parse(Uint8List rawDescriptors) {
    final raw = rawDescriptors;
    var inReader = false;
    var at = 0;
    while (at + 2 <= raw.length) {
      final length = raw[at];
      final type = raw[at + 1];
      if (length < 2 || at + length > raw.length) break;
      if (type == _interfaceType) {
        inReader = length > 5 && raw[at + 5] == usbClassSmartCard;
      } else if (inReader && type == _ccidType && length == _ccidLength) {
        final entry = ByteData.sublistView(raw, at, at + length);
        return CcidDescriptor(
          voltageSupport: entry.getUint8(5),
          protocols: entry.getUint32(6, Endian.little),
          maxIfsd: entry.getUint32(28, Endian.little),
          features: entry.getUint32(40, Endian.little),
          maxMessageLength: entry.getUint32(44, Endian.little),
        );
      }
      at += length;
    }
    throw const FormatException('Kein Deskriptor eines Kartenlesers');
  }

  static const _interfaceType = 0x04;
  static const _ccidType = 0x21;
  static const _ccidLength = 0x36;

  /// `bVoltageSupport`: `01` 5 V, `02` 3 V, `04` 1,8 V.
  final int voltageSupport;

  /// `dwProtocols`: Bit 0 T=0, Bit 1 T=1.
  final int protocols;
  final int maxIfsd;
  final int features;
  final int maxMessageLength;

  ExchangeLevel get level => switch (features & 0x00070000) {
    0x00010000 => ExchangeLevel.tpdu,
    0x00020000 => ExchangeLevel.shortApdu,
    0x00040000 => ExchangeLevel.extendedApdu,
    _ => ExchangeLevel.character,
  };

  bool has(int feature) => features & feature != 0;
}

enum CcidProblem { cardAbsent, cardMute, commandFailed, badAnswer }

class CcidException implements Exception {
  const CcidException(this.problem, {this.error});

  final CcidProblem problem;

  /// Das Fehlerbyte des Lesers bei [CcidProblem.commandFailed].
  final int? error;

  @override
  String toString() => error == null
      ? 'CcidException(${problem.name})'
      : 'CcidException(${problem.name}, '
            '${error!.toRadixString(16).padLeft(2, '0').toUpperCase()})';
}

class CcidReader {
  CcidReader(
    this._transport,
    this.descriptor, {
    this.log,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ReaderTransport _transport;
  final CcidDescriptor descriptor;
  final ProbeLog? log;

  /// Für die Grenze von 20 Sekunden beim Warten; Tests stellen sie selbst.
  final DateTime Function() _clock;

  /// Die laufende Nummer der nächsten Nachricht.
  int _sequence = 0;

  static const _powerOnType = 0x62;
  static const _powerOffType = 0x63;
  static const _setParametersType = 0x61;
  static const _transferType = 0x6F;
  static const _dataBlockType = 0x80;
  static const _slotStatusType = 0x81;
  static const _parametersType = 0x82;

  static const _controlLimit = Duration(seconds: 3);
  static const _maxWaits = 30;
  static const _maxWaitTime = Duration(seconds: 20);
  static const _maxStaleAnswers = 3;
  static const _muteError = 0xFE;

  /// Schaltet die Karte ein und gibt ihre ATR zurück.
  Future<Uint8List> powerOn() async {
    if (descriptor.has(CcidFeature.autoVoltage) ||
        descriptor.has(CcidFeature.autoActivation)) {
      return _powerOnAt(0x00);
    }
    // 5 V, 3 V, 1,8 V: jeweils, wenn der Leser sie kann.
    final voltages = [
      for (final (voltage, bit) in const [
        (0x01, 0x01),
        (0x02, 0x02),
        (0x03, 0x04),
      ])
        if (descriptor.voltageSupport & bit != 0) voltage,
    ];
    if (voltages.isEmpty) return _powerOnAt(0x00);
    late CcidException failure;
    for (var i = 0; i < voltages.length; i++) {
      if (i > 0) await powerOff();
      try {
        return await _powerOnAt(voltages[i]);
      } on CcidException catch (e) {
        if (e.problem == CcidProblem.cardAbsent ||
            e.problem == CcidProblem.badAnswer) {
          rethrow;
        }
        failure = e;
      }
    }
    throw failure;
  }

  Future<Uint8List> _powerOnAt(int voltage) async {
    final atr = await _send(
      _powerOnType,
      voltage,
      Uint8List(0),
      _dataBlockType,
    );
    if (atr.isEmpty) throw const CcidException(CcidProblem.cardMute);
    return atr;
  }

  /// Schaltet die Karte aus; wirft nie.
  Future<void> powerOff() async {
    try {
      await _send(_powerOffType, 0x00, Uint8List(0), _slotStatusType);
    } catch (_) {
      // Ausschalten gelingt immer, auch ohne Karte oder Leser.
    }
  }

  /// Setzt die Parameter für [protocol] (`1` für T=1, dann 7 Bytes [data]).
  Future<void> setParameters(int protocol, Uint8List data) async {
    await _send(_setParametersType, protocol, data, _parametersType);
  }

  /// Überträgt einen Block und gibt die Antwort der Karte zurück. [bwi]
  /// verlängert die Wartezeit des Lesers; [limit] gilt für jeden Lesevorgang.
  /// Bei [secret] zeigt das Protokoll nur die Länge, in beiden Richtungen.
  Future<Uint8List> transfer(
    Uint8List data, {
    int bwi = 0,
    bool secret = false,
    Duration limit = const Duration(seconds: 3),
  }) => _send(
    _transferType,
    bwi,
    data,
    _dataBlockType,
    secret: secret,
    limit: limit,
  );

  /// Schickt eine Nachricht und gibt die Daten der passenden Antwort zurück.
  Future<Uint8List> _send(
    int type,
    int parameter,
    Uint8List data,
    int answerType, {
    bool secret = false,
    Duration limit = _controlLimit,
  }) async {
    final sequence = _sequence;
    _sequence = (_sequence + 1) & 0xFF;
    final out = Uint8List(10 + data.length);
    ByteData.sublistView(out)
      ..setUint8(0, type)
      ..setUint32(1, data.length, Endian.little)
      ..setUint8(5, 0x00)
      ..setUint8(6, sequence)
      ..setUint8(7, parameter);
    out.setAll(10, data);

    final started = _clock();
    log?.bytes('an Leser', out, secret: secret);
    var answer = await _transport.exchange(out, limit: limit);
    var stale = 0;
    var waits = 0;
    while (true) {
      log?.bytes('vom Leser', answer, secret: secret);
      if (answer.length < 10) {
        throw const CcidException(CcidProblem.badAnswer);
      }
      if (answer[6] != sequence) {
        // Eine alte Antwort hing noch in der Leitung.
        if (stale == _maxStaleAnswers) {
          throw const CcidException(CcidProblem.badAnswer);
        }
        stale++;
        answer = await _transport.exchange(null, limit: limit);
        continue;
      }
      if (answer[0] != answerType) {
        throw const CcidException(CcidProblem.badAnswer);
      }
      final status = answer[7];
      final error = answer[8];
      switch (status >> 6) {
        case 0:
          break;
        case 1:
          if (status & 0x03 == 0x02) {
            throw const CcidException(CcidProblem.cardAbsent);
          }
          if (error == _muteError) {
            throw const CcidException(CcidProblem.cardMute);
          }
          throw CcidException(CcidProblem.commandFailed, error: error);
        case 2:
          // Der Leser braucht mehr Zeit; die Antwort kommt mit derselben
          // Nummer.
          if (waits == _maxWaits ||
              _clock().difference(started) >= _maxWaitTime) {
            throw const ReaderException(ReaderProblem.timeout);
          }
          waits++;
          answer = await _transport.exchange(null, limit: limit);
          continue;
        default:
          throw const CcidException(CcidProblem.badAnswer);
      }
      final length = ByteData.sublistView(answer).getUint32(1, Endian.little);
      if (length > answer.length - 10) {
        throw const CcidException(CcidProblem.badAnswer);
      }
      return answer.sublist(10, 10 + length);
    }
  }
}
