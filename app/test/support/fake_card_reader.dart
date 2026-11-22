// Ein nachgebauter USB-Kartenleser mit einer nachgebauten Signaturkarte von
// A-Trust. Der Leser beantwortet die Nachrichten aus ccid.dart; auf Stufe
// TPDU spricht die Karte T=1, sonst nimmt der Leser ganze Befehle. Die Karte
// hat ein kleines Dateisystem und prüft die PIN wie die echte: drei falsche
// Versuche, dann ist sie gesperrt.
//
// Keine Liste und kein Fehlertext hier zeigt die 8 Bytes PIN eines VERIFY.

import 'dart:async';
import 'dart:typed_data';

import 'package:kassa/rksv/card/atrust_card.dart';
import 'package:kassa/rksv/card/ccid.dart';
import 'package:kassa/rksv/card/reader_transport.dart';

/// `AABBCC`: Großbuchstaben, ohne Leerzeichen.
String compactHex(List<int> data) =>
    data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();

/// Wie [compactHex], aber bei einem VERIFY stehen statt der 8 Bytes PIN acht
/// `**`.
String maskedApdu(List<int> apdu) {
  if (apdu.length >= 5 && apdu[1] == 0x20) {
    return compactHex(apdu.sublist(0, 5)) + '**' * (apdu.length - 5);
  }
  return compactHex(apdu);
}

/// Ein erfundenes Zertifikat (DER-Kopf `30 82 01 77`, 379 Bytes), damit das
/// Lesen zwei Blöcke braucht.
Uint8List fillerCertificate() {
  final cert = Uint8List(379)
    ..[0] = 0x30
    ..[1] = 0x82
    ..[2] = 0x01
    ..[3] = 0x77;
  for (var i = 4; i < cert.length; i++) {
    cert[i] = (i * 7) & 0xFF;
  }
  return cert;
}

/// Die Kartennummer jeder nachgebauten Karte.
final fakeCardNumber = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

class FakeCard {
  FakeCard({
    required this.atr,
    required this.profile,
    this.pin = '123456',
    this.retriesLeft = 3,
    Uint8List? certificate,
    Uint8List? number,
    Uint8List Function(Uint8List hash)? signer,
    this.verifyPerSignature = true,
  }) : certificate = certificate ?? fillerCertificate(),
       number = number ?? fakeCardNumber,
       signer = signer ?? _defaultSigner;

  final Uint8List atr;
  final CardProfile profile;

  /// Die richtige PIN; nie in einer Liste oder einem Fehlertext.
  final String pin;

  /// Bei 0 ist die Karte gesperrt.
  int retriesLeft;
  final Uint8List certificate;

  /// Die Kartennummer; ohne Angabe [fakeCardNumber].
  final Uint8List number;
  final Uint8List Function(Uint8List hash) signer;

  /// `true`: Jede Unterschrift braucht ein neues VERIFY (sonst `6982`).
  /// `false`: Ein VERIFY gilt bis zum Ausschalten.
  final bool verifyPerSignature;

  /// Jedes VERIFY, das die Karte sah, richtig oder falsch.
  int verifyCount = 0;

  /// Jeder Befehl als Hex ([maskedApdu]: bei VERIFY `**` statt der PIN).
  List<String> received = [];

  /// Wie oft die Karte unterschrieben hat.
  int signCount = 0;

  /// `true`: Der Leser meldet "keine Karte".
  bool removed = false;

  /// `true`: Die Karte antwortet nicht auf das Einschalten.
  bool mute = false;

  /// Status der Antwort auf ein Lesen des Zertifikats, das das Ende der
  /// Datei vor Le Bytes erreicht (`6282` laut A-Trust); die Daten kommen
  /// trotzdem mit. `null`: `9000`.
  int? certificateEndStatus;

  /// So oft antwortet die Karte auf ein Lesen des Zertifikats, das bis zum
  /// Ende der Datei reicht, zuerst nur mit `6Cxx` (xx: die Zahl der Bytes
  /// bis zum Ende), auch wenn Le schon stimmt.
  int certificateWrongLength = 0;

  // Zustand seit dem letzten Einschalten.
  bool _powered = false;
  List<int> _folder = _mf;
  List<int>? _file;
  bool _verified = false;
  bool _prepared = false;
  Uint8List? _hash;

  static const _mf = [0x3F, 0x00];

  static Uint8List _defaultSigner(Uint8List hash) =>
      Uint8List.fromList([...hash, ...hash.reversed]);

  void _powerOn() {
    _powered = true;
    _folder = _mf;
    _file = null;
    _verified = false;
    _prepared = false;
    _hash = null;
  }

  void _powerOff() => _powered = false;

  /// Die Karte wurde gezogen und gleich wieder gesteckt: Sie ist aus, bis der
  /// Leser sie neu einschaltet, und weiß von keinem VERIFY mehr.
  void reseat() {
    _powerOff();
    _verified = false;
    _prepared = false;
    _hash = null;
  }

  /// Führt einen ganzen Befehl aus; die Antwort endet mit dem Status.
  Uint8List process(Uint8List apdu) {
    received.add(maskedApdu(apdu));
    if (apdu.length < 4) return _status(0x6700);
    final ins = apdu[1], p1 = apdu[2], p2 = apdu[3];
    final body = apdu.sublist(4);
    final lc = body.isEmpty ? 0 : body[0];
    final data = body.length > 1 ? body.sublist(1, 1 + lc) : Uint8List(0);
    final acos = profile.kind == CardKind.acos;

    switch ((ins, p1, p2)) {
      case (0xA4, 0x00, 0x0C):
        return _selectFile(data);
      case (0xA4, 0x04, 0x0C):
        return _selectApplication(data);
      case (0xB0, _, _):
        return _readBinary(p1, p2, body.isEmpty ? 0 : body[0]);
      case (0x22, 0x41, 0xB6) when acos:
        if (!_same(_folder, profile.signatureFolder)) return _status(0x6A88);
        _prepared = true;
        return _status(0x9000);
      case (0x20, 0x00, _):
        return _verify(p2, body);
      case (0x2A, 0x90, 0x81) when acos:
        if (data.length != 32) return _status(0x6700);
        if (!_verified) return _status(0x6982);
        if (!_prepared) return _status(0x6F05);
        _hash = data;
        return _status(0x9000);
      case (0x2A, 0x9E, 0x9A):
        return _sign(body, acos);
    }
    return _status(0x6D00);
  }

  Uint8List _selectFile(Uint8List id) {
    if (id.length != 2) return _status(0x6700);
    if (_same(id, _mf)) {
      _folder = _mf;
      _file = null;
      return _status(0x9000);
    }
    if (_folders.contains(compactHex(id))) {
      _folder = id;
      _file = null;
      return _status(0x9000);
    }
    if (_contentOf(_folder, id) != null) {
      _file = id;
      return _status(0x9000);
    }
    return _status(0x6A82);
  }

  Set<String> get _folders => {
    compactHex(profile.signatureFolder),
    if (!_same(profile.numberFolder, _mf)) compactHex(profile.numberFolder),
  };

  Uint8List? _contentOf(List<int> folder, List<int> file) {
    if (_same(folder, profile.signatureFolder) &&
        _same(file, profile.certificateFile)) {
      return certificate;
    }
    if (_same(folder, profile.numberFolder) &&
        _same(file, profile.numberFile)) {
      return number;
    }
    return null;
  }

  Uint8List _selectApplication(Uint8List aid) {
    final index = profile.applications.indexWhere((a) => _same(a, aid));
    if (index < 0) return _status(0x6A82);
    // Die erste Anwendung ist die Signatur, bei ACOS die zweite die mit der
    // Kartennummer.
    _folder = index == 0 ? profile.signatureFolder : profile.numberFolder;
    _file = null;
    return _status(0x9000);
  }

  Uint8List _readBinary(int p1, int p2, int le) {
    final file = _file;
    if (p1 & 0x80 != 0) return _status(0x6A81);
    if (file == null) return _status(0x6986);
    final content = _contentOf(_folder, file)!;
    final offset = p1 << 8 | p2;
    if (offset >= content.length) return _status(0x6B00);
    final wanted = le == 0 ? 256 : le;
    final rest = content.length - offset;
    if (_same(file, profile.certificateFile) && wanted >= rest) {
      if (certificateWrongLength > 0) {
        certificateWrongLength--;
        return _status(0x6C00 | (rest & 0xFF));
      }
      final status = certificateEndStatus;
      if (status != null && wanted > rest) {
        return Uint8List.fromList([
          ...content.sublist(offset),
          status >> 8,
          status & 0xFF,
        ]);
      }
    }
    final end = offset + wanted < content.length
        ? offset + wanted
        : content.length;
    return Uint8List.fromList([...content.sublist(offset, end), 0x90, 0x00]);
  }

  Uint8List _verify(int reference, Uint8List body) {
    verifyCount++;
    if (reference != profile.pinReference) return _status(0x6A88);
    if (body.length != 9 || body[0] != 8) return _status(0x6700);
    if (retriesLeft == 0) return _status(0x6983);
    if (_same(body.sublist(1), _pinBlock())) {
      retriesLeft = 3;
      _verified = true;
      return _status(0x9000);
    }
    retriesLeft--;
    _verified = false;
    return _status(0x63C0 | retriesLeft);
  }

  /// Die PIN in 8 Bytes, unabhängig von [CardCommand] gebaut.
  List<int> _pinBlock() {
    final digits = pin.codeUnits;
    if (profile.pinFormat == PinFormat.ascii) {
      return [...digits, ...List.filled(8 - digits.length, 0x00)];
    }
    final nibbles = [
      0x2,
      digits.length,
      for (final d in digits) d - 0x30,
      ...List.filled(14 - digits.length, 0xF),
    ];
    return [for (var i = 0; i < 16; i += 2) nibbles[i] << 4 | nibbles[i + 1]];
  }

  Uint8List _sign(Uint8List body, bool acos) {
    final Uint8List hash;
    if (acos) {
      if (body.length != 1 || body[0] != 0x00) return _status(0x6700);
      if (!_verified) return _status(0x6982);
      if (!_prepared) return _status(0x6F05);
      if (_hash == null) return _status(0x6F03);
      hash = _hash!;
    } else {
      if (body.length != 34 || body[0] != 0x20 || body[33] != 0x40) {
        return _status(0x6700);
      }
      if (!_verified) return _status(0x6982);
      hash = body.sublist(1, 33);
    }
    if (verifyPerSignature) _verified = false;
    _hash = null;
    signCount++;
    return Uint8List.fromList([...signer(hash), 0x90, 0x00]);
  }

  static Uint8List _status(int sw) => Uint8List.fromList([sw >> 8, sw & 0xFF]);

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Ein USB-Kartenleser für Tests. Was er nicht versteht, beantwortet er wie
/// ein echter Leser mit einem Fehler, nie mit einem Test-Abbruch.
class FakeCardReader implements ReaderTransport {
  FakeCardReader({
    List<UsbDeviceInfo>? devices,
    this.card,
    this.features = 0x00010030,
    this.maxIfsd = 254,
    this.permission = true,
    this.failAfterExchanges,
    this.corruptBlockNumber,
    this.wtxBeforeSign = 0,
    this.cardIfsc = 254,
  }) : devices = devices ?? [readerDevice(granted: permission)];

  /// Ein Kartenleser mit Schnittstelle der Klasse `0B`.
  static UsbDeviceInfo readerDevice({bool granted = true}) => UsbDeviceInfo(
    address: readerAddress,
    name: 'Beispiel-Kartenleser',
    vendorId: 1254,
    productId: 21777,
    deviceClass: 0,
    granted: granted,
    interfaces: const [UsbInterfaceInfo(usbClassSmartCard, 0, 0)],
  );

  static const readerAddress = '1254:21777';

  /// Was [list] meldet.
  final List<UsbDeviceInfo> devices;

  /// Die Karte im Leser; `null`: keine.
  FakeCard? card;

  /// `dwFeatures` des Lesers; bestimmt die Stufe (TPDU, kurze oder erweiterte
  /// APDU, Zeichen).
  final int features;
  final int maxIfsd;

  /// `false`: [open] wirft `noPermission`.
  bool permission;

  /// Nach so vielen Aufrufen von [exchange] wirft jeder weitere
  /// `ReaderException(io)` (abgezogen); `null`: nie.
  int? failAfterExchanges;

  /// Was Android zu diesem Fehler meldet (`ReaderException.detail`).
  String? failureDetail;

  /// Die Karte verfälscht das Prüfbyte ihres T=1-Blocks mit dieser laufenden
  /// Nummer (ab 1, über alle Sitzungen, siehe [cardBlocks]) einmal.
  int? corruptBlockNumber;

  /// So oft bittet die Karte vor der Unterschrift um mehr Zeit (T=1: `C3`,
  /// Stufe APDU: der Leser meldet "mehr Zeit").
  int wtxBeforeSign;

  /// So viele Bytes trägt ein T=1-Block der Karte höchstens, in beiden
  /// Richtungen; ein längerer Block der Kassa ist ein Fehler.
  int cardIfsc;

  /// `false` lehnt das Setzen der Parameter ab (Fehlerbyte `0A`).
  bool acceptParameters = true;

  /// Läuft vor jedem Aufruf von [exchange] mit dessen laufender Nummer (ab 1).
  /// Wirft es, endet der Aufruf mit diesem Fehler.
  void Function(int exchange)? onExchange;

  /// So viele VERIFY bekommen keine Antwort: Die Karte führt den Befehl aus,
  /// der Leser meldet danach aber `ReaderException(timeout)` statt der
  /// Antwort, wie bei einer Karte, die mitten im Befehl gezogen wird.
  int dropVerifyAnswers = 0;
  bool _swallow = false;

  /// `true`: Ohne offenen Leser ([open] ohne [close] danach) wirft
  /// [exchange] `ReaderException(notOpen)`, wie der Kanal von Android.
  bool strictOpen = false;

  /// So lange dauert [close], bevor es den Leser schließt; auch einen, der
  /// inzwischen neu geöffnet wurde.
  Duration? closeDelay;
  bool _isOpen = false;

  /// Was in welcher Reihenfolge geschah: `powerOn`, `powerOff`,
  /// `parameters <hex>`, `ifsd <hex>`, `command <maskedApdu>`.
  final List<String> events = [];

  /// Die Daten jedes `6F` als Hex; bei VERIFY ohne die PIN.
  final List<String> transfers = [];

  /// Das `limit` jedes Aufrufs von [exchange].
  final List<Duration> limits = [];

  /// Das `bwi` jedes `6F`.
  final List<int> bwis = [];
  final List<String> opened = [];
  int closed = 0;
  int exchanges = 0;

  /// Wie viele T=1-Blöcke die Karte geschickt hat.
  int cardBlocks = 0;

  final List<Uint8List> _pending = [];
  _T1Card? _t1;

  ExchangeLevel get level => descriptor.level;

  CcidDescriptor get descriptor => CcidDescriptor.parse(descriptors);

  /// Schnittstelle der Klasse `0B` und der Eintrag vom Typ `21`.
  Uint8List get descriptors {
    final entry = ByteData(0x36)
      ..setUint8(0, 0x36)
      ..setUint8(1, 0x21)
      ..setUint16(2, 0x0110, Endian.little)
      ..setUint8(5, 0x07)
      ..setUint32(6, 0x03, Endian.little)
      ..setUint32(28, maxIfsd, Endian.little)
      ..setUint32(40, features, Endian.little)
      ..setUint32(44, features & 0x00040000 != 0 ? 65544 : 271, Endian.little)
      ..setUint8(53, 0x01);
    return Uint8List.fromList([
      0x09, 0x04, 0x00, 0x00, 0x02, usbClassSmartCard, 0x00, 0x00, 0x00, //
      ...entry.buffer.asUint8List(),
    ]);
  }

  @override
  Future<List<UsbDeviceInfo>> list() async => devices;

  @override
  Future<Uint8List> open(String address) async {
    opened.add(address);
    if (!devices.any((d) => d.address == address && d.isCardReader)) {
      throw const ReaderException(ReaderProblem.notFound);
    }
    if (!permission) throw const ReaderException(ReaderProblem.noPermission);
    _pending.clear();
    _isOpen = true;
    return descriptors;
  }

  @override
  Future<void> close() async {
    final delay = closeDelay;
    if (delay != null) await Future<void>.delayed(delay);
    _isOpen = false;
    closed++;
    _pending.clear();
  }

  @override
  Future<TabletInfo> info() async =>
      const TabletInfo('Beispiel Tablet', '14 (API 34)');

  @override
  Future<Uint8List> exchange(Uint8List? out, {required Duration limit}) async {
    exchanges++;
    limits.add(limit);
    onExchange?.call(exchanges);
    if (strictOpen && !_isOpen) {
      throw const ReaderException(ReaderProblem.notOpen);
    }
    final failAfter = failAfterExchanges;
    if (failAfter != null && exchanges > failAfter) {
      throw ReaderException(ReaderProblem.io, failureDetail);
    }
    if (out == null) {
      if (_pending.isEmpty) throw const ReaderException(ReaderProblem.timeout);
      return _pending.removeAt(0);
    }
    if (out.length < 10) throw const ReaderException(ReaderProblem.io);
    final type = out[0];
    final sequence = out[6];
    final parameter = out[7];
    final data = out.sublist(10);
    final answers = switch (type) {
      0x62 => [_powerOn(sequence)],
      0x63 => [_powerOff(sequence)],
      0x61 => [_setParameters(sequence, parameter, data)],
      0x6F => _transfer(sequence, parameter, data),
      _ => [_answer(0x81, sequence, 0x40 | _slotState, 0x00)],
    };
    if (_swallow) {
      _swallow = false;
      throw const ReaderException(ReaderProblem.timeout);
    }
    _pending.addAll(answers.skip(1));
    return answers.first;
  }

  bool get _cardPresent => card != null && !card!.removed;

  /// `bmICCStatus`: 0 aktiv, 1 da und aus, 2 keine Karte.
  int get _slotState => !_cardPresent
      ? 2
      : card!._powered
      ? 0
      : 1;

  Uint8List _powerOn(int sequence) {
    events.add('powerOn');
    final present = card;
    if (present == null || present.removed) {
      return _answer(0x80, sequence, 0x42, 0xFE);
    }
    if (present.mute) return _answer(0x80, sequence, 0x41, 0xFE);
    present._powerOn();
    _t1 = _T1Card(this, present);
    return _answer(0x80, sequence, 0x00, 0x00, present.atr);
  }

  Uint8List _powerOff(int sequence) {
    events.add('powerOff');
    card?._powerOff();
    _t1 = null;
    return _answer(0x81, sequence, _slotState, 0x00);
  }

  Uint8List _setParameters(int sequence, int protocol, Uint8List data) {
    events.add('parameters ${compactHex(data)}');
    if (!_cardPresent) return _answer(0x82, sequence, 0x42, 0xFE);
    if (!acceptParameters || protocol != 1 || data.length != 7) {
      return _answer(0x82, sequence, 0x40 | _slotState, 0x0A);
    }
    return _answer(0x82, sequence, _slotState, 0x00, data, protocol);
  }

  List<Uint8List> _transfer(int sequence, int bwi, Uint8List data) {
    bwis.add(bwi);
    transfers.add(
      level == ExchangeLevel.tpdu ? _maskedBlock(data) : maskedApdu(data),
    );
    if (!_cardPresent) return [_answer(0x80, sequence, 0x42, 0xFE)];
    final present = card!;
    if (!present._powered) return [_answer(0x80, sequence, 0x41, 0xFB)];
    if (level == ExchangeLevel.tpdu) {
      return [_answer(0x80, sequence, 0x00, 0x00, _t1!.receive(data))];
    }
    final isSign = data.length >= 4 && data[1] == 0x2A && data[2] == 0x9E;
    events.add('command ${maskedApdu(data)}');
    final response = present.process(data);
    _maybeSwallow(data);
    return [
      if (isSign)
        for (var i = 0; i < wtxBeforeSign; i++)
          _answer(0x80, sequence, 0x80, 0x01),
      _answer(0x80, sequence, 0x00, 0x00, response),
    ];
  }

  void _maybeSwallow(Uint8List apdu) {
    if (apdu.length >= 2 && apdu[1] == 0x20 && dropVerifyAnswers > 0) {
      dropVerifyAnswers--;
      _swallow = true;
    }
  }

  static String _maskedBlock(Uint8List block) {
    if (block.length >= 4 && block[1] & 0x80 == 0) {
      final information = block.sublist(3, block.length - 1);
      if (information.length >= 5 && information[1] == 0x20) {
        return '${compactHex(block.sublist(0, 3))}'
            '${maskedApdu(information)}${compactHex([block.last])}';
      }
    }
    return compactHex(block);
  }

  static Uint8List _answer(
    int type,
    int sequence,
    int status,
    int error, [
    List<int> data = const [],
    int specific = 0,
  ]) {
    final answer = Uint8List(10 + data.length);
    ByteData.sublistView(answer)
      ..setUint8(0, type)
      ..setUint32(1, data.length, Endian.little)
      ..setUint8(6, sequence)
      ..setUint8(7, status)
      ..setUint8(8, error)
      ..setUint8(9, specific);
    answer.setAll(10, data);
    return answer;
  }
}

/// Ein Leser, bei dem Android nach der Erlaubnis fragt: [open] eines Geräts,
/// das [list] ohne Erlaubnis meldet, wartet, bis der Test mit [answer]
/// antwortet. Ja trägt die Erlaubnis in die Liste ein.
class AskingReader implements ReaderTransport {
  AskingReader(this.inner);

  final FakeCardReader inner;
  Completer<bool>? _question;

  /// Android fragt gerade.
  bool get asking => _question != null;

  /// Wie oft Android gefragt hat.
  int questions = 0;

  /// Beantwortet die laufende Frage.
  void answer({required bool yes}) {
    final question = _question;
    _question = null;
    if (yes) {
      for (var i = 0; i < inner.devices.length; i++) {
        final d = inner.devices[i];
        if (d.isCardReader && !d.granted) {
          inner.devices[i] = FakeCardReader.readerDevice();
        }
      }
    }
    question?.complete(yes);
  }

  @override
  Future<List<UsbDeviceInfo>> list() => inner.list();

  @override
  Future<Uint8List> open(String address) async {
    final device = inner.devices.where((d) => d.address == address).firstOrNull;
    if (device != null && !device.granted) {
      questions++;
      final question = _question = Completer<bool>();
      if (!await question.future) {
        throw const ReaderException(ReaderProblem.noPermission);
      }
    }
    return inner.open(address);
  }

  @override
  Future<Uint8List> exchange(Uint8List? out, {required Duration limit}) =>
      inner.exchange(out, limit: limit);

  @override
  Future<void> close() => inner.close();

  @override
  Future<TabletInfo> info() => inner.info();
}

/// Die Seite der Karte bei T=1:nimmt Blöcke der Kassa, setzt Befehle aus
/// mehreren Blöcken zusammen und schickt Antworten in Stücken zurück.
class _T1Card {
  _T1Card(this._reader, this._card);

  final FakeCardReader _reader;
  final FakeCard _card;

  /// Eigene Nummer des nächsten Daten-Blocks.
  int _ns = 0;

  /// Erwartete Nummer des nächsten Daten-Blocks der Kassa.
  int _nr = 0;

  /// So viel nimmt die Kassa in einem Block an; bis `C1` gilt 32.
  int _ifsd = 32;
  final BytesBuilder _command = BytesBuilder(copy: true);
  Uint8List _response = Uint8List(0);
  int _responseAt = 0;
  int _waitsLeft = 0;
  Uint8List _last = Uint8List(0);

  Uint8List receive(Uint8List block) {
    if (!_intact(block)) return _send(0x80 | _nr << 4 | 0x01, const []);
    final pcb = block[1];
    final data = block.sublist(3, block.length - 1);
    if (pcb & 0x80 == 0) {
      // Daten-Block der Kassa.
      if (data.length > _reader.cardIfsc) {
        return _send(0x80 | _nr << 4 | 0x02, const []);
      }
      if ((pcb >> 6) & 1 != _nr) {
        // Schon bekommen: die letzte Antwort noch einmal.
        return _repeat();
      }
      _nr ^= 1;
      _command.add(data);
      if (pcb & 0x20 != 0) return _send(0x80 | _nr << 4, const []);
      final apdu = _command.takeBytes();
      _reader.events.add('command ${maskedApdu(apdu)}');
      _response = _card.process(apdu);
      _reader._maybeSwallow(apdu);
      _responseAt = 0;
      final isSign = apdu.length >= 4 && apdu[1] == 0x2A && apdu[2] == 0x9E;
      _waitsLeft = isSign ? _reader.wtxBeforeSign : 0;
      return _nextOfResponse();
    }
    if (pcb & 0x40 == 0) {
      // Bestätigung der Kassa: N(R) gleich der eigenen nächsten Nummer heißt
      // "angekommen, weiter"; sonst den letzten Block noch einmal.
      if ((pcb >> 4) & 1 == _ns && pcb & 0x03 == 0 && _responseAt > 0) {
        return _nextOfResponse();
      }
      return _repeat();
    }
    switch (pcb) {
      case 0xC1 when data.length == 1:
        _ifsd = data[0];
        _reader.events.add('ifsd ${compactHex(data)}');
        return _send(0xE1, data);
      case 0xC0:
        _ns = 0;
        _nr = 0;
        _command.clear();
        return _send(0xE0, const []);
      case 0xE3:
        return _nextOfResponse();
    }
    return _send(0x80 | _nr << 4 | 0x02, const []);
  }

  Uint8List _nextOfResponse() {
    if (_waitsLeft > 0) {
      _waitsLeft--;
      return _send(0xC3, const [0x01]);
    }
    final size = _ifsd < _reader.cardIfsc ? _ifsd : _reader.cardIfsc;
    final end = _responseAt + size < _response.length
        ? _responseAt + size
        : _response.length;
    final more = end < _response.length;
    final piece = _response.sublist(_responseAt, end);
    _responseAt = more ? end : 0;
    final pcb = _ns << 6 | (more ? 0x20 : 0);
    _ns ^= 1;
    return _send(pcb, piece);
  }

  Uint8List _repeat() {
    _reader.cardBlocks++;
    return _maybeCorrupt(Uint8List.fromList(_last));
  }

  Uint8List _send(int pcb, List<int> data) {
    final block = Uint8List(data.length + 4)
      ..[1] = pcb
      ..[2] = data.length
      ..setAll(3, data);
    var check = 0;
    for (var i = 0; i < block.length - 1; i++) {
      check ^= block[i];
    }
    block[block.length - 1] = check;
    _last = block;
    _reader.cardBlocks++;
    return _maybeCorrupt(Uint8List.fromList(block));
  }

  Uint8List _maybeCorrupt(Uint8List block) {
    if (_reader.corruptBlockNumber == _reader.cardBlocks) {
      _reader.corruptBlockNumber = null;
      block[block.length - 1] ^= 0xFF;
    }
    return block;
  }

  static bool _intact(Uint8List block) {
    if (block.length < 4 || block[0] != 0 || block.length != block[2] + 4) {
      return false;
    }
    var check = 0;
    for (final b in block) {
      check ^= b;
    }
    return check == 0;
  }
}
