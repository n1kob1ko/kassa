// Der Prüflauf "Karte prüfen": fünf Zeilen (Kartenleser, Zugriff,
// Signaturkarte, Zertifikat, Probe-Unterschrift), der Bericht zum Teilen und
// der PIN-Wächter. Bildschirm und Tasten baut Task 7 auf [CardCheckState].
//
// Schutz der Karte: VERIFY geht nur aus [CardCheck.sign] hinaus. Vorher wird
// der Wächter gefragt; nach einer Antwort ungleich 9000 oder einem Abbruch
// geht in diesem Aufruf nur noch das Ausschalten zur Karte. Die PIN lebt nur
// als Parameter von [CardCheck.sign]; sie steht in keinem Feld, keinem
// Zustand, keinem Bericht und keinem Protokoll.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'atr.dart';
import 'atrust_card.dart';
import 'card_session.dart';
import 'ccid.dart';
import 'certificate.dart';
import 'pin_guard.dart';
import 'probe_log.dart';
import 'reader_transport.dart';

enum CheckRow { reader, access, card, certificate, signature }

enum RowState { waiting, running, ok, problem, locked }

class RowResult {
  const RowResult(this.state, this.message, [this.hint]);

  final RowState state;
  final String message;
  final String? hint;

  @override
  String toString() => 'RowResult(${state.name}, $message)';
}

class CardCheckState {
  const CardCheckState({
    required this.rows,
    required this.busy,
    required this.canSign,
    required this.guardBlocks,
    required this.report,
    this.cardLocked = false,
  });

  final Map<CheckRow, RowResult> rows;
  final bool busy;

  /// Zeile 4 ist ok, die Karte ist bekannt, der Wächter erlaubt es.
  final bool canSign;

  /// Der Wächter kennt nur noch einen Versuch (oder keinen).
  final bool guardBlocks;

  /// Die Karte hat keinen Versuch mehr (nach `6983`, `63C0` oder einer
  /// gespeicherten 0).
  final bool cardLocked;

  /// Der Bericht als Text, höchstens [CardCheck.maxReportLength] Zeichen.
  final String report;
}

class CardCheck {
  CardCheck({
    required this._transport,
    required this._guard,
    required this._now,
    required this._appVersion,
  }) {
    _state = _compose();
  }

  /// So lange darf ein Lauf ab dem geöffneten Leser höchstens dauern. Die
  /// Zeit, in der Android nach der Erlaubnis fragt (`open`), zählt nicht.
  static const timeLimit = Duration(seconds: 20);
  static const maxReportLength = 60000;
  static const _maxCertificateBlocks = 16;
  static const _blockSize = 256;
  static const _masterFile = [0x3F, 0x00];
  static final _pinPattern = RegExp(r'^(?:[0-9]{4}|[0-9]{6})$');

  final ReaderTransport _transport;
  final PinGuard _guard;
  final DateTime Function() _now;
  final String _appVersion;
  final _changes = StreamController<CardCheckState>.broadcast();

  Map<CheckRow, RowResult> _rows = _initialRows;
  bool _busy = false;
  bool _guardBlocks = false;
  bool _cardLocked = false;

  /// Je Kartennummer der kleinste Zähler, den diese Instanz gesehen oder
  /// vorsichtig angenommen hat. Gilt zusammen mit dem Speicher des Wächters,
  /// auch wenn dieser nicht schreiben konnte, bis zu [resetGuard] oder 9000.
  final Map<String, int> _lowest = {};

  /// Die Karte aus dem letzten Lauf, wenn Zeile 4 grün ist; sonst `null`.
  _ReadyCard? _ready;
  _Facts _facts = _Facts(null);
  late CardCheckState _state;

  CardCheckState get state => _state;

  /// Jede Änderung von [state].
  Stream<CardCheckState> get changes => _changes.stream;

  /// Zeilen 1 bis 4; schickt nie eine PIN.
  Future<void> run() async {
    if (_busy) return;
    _busy = true;
    _ready = null;
    _guardBlocks = false;
    _cardLocked = false;
    final facts = _facts = _Facts(_now());
    facts.log.line('Prüflauf ${_dateTime(facts.startedAt!)}');
    _rows = _initialRows;
    final attempt = _Attempt(this, _Link(_transport), facts);
    _publish();
    try {
      await _runSteps(attempt);
    } catch (e) {
      _unexpected(attempt, e);
    } finally {
      await attempt.link.close();
      _busy = false;
      _publish();
    }
  }

  /// Zeile 5: Probe-Unterschrift mit [pin]. Tut nichts, wenn `!canSign` oder
  /// die PIN nicht aus 4 oder 6 Ziffern besteht.
  Future<void> sign(String pin) async {
    final ready = _ready;
    if (ready == null || _busy || _guardBlocks) return;
    if (!_pinPattern.hasMatch(pin)) return;
    _busy = true;
    _publish();
    final int? left;
    try {
      left = await _countOf(ready.key);
    } catch (_) {
      // Ohne Antwort des Wächters geht keine PIN hinaus.
      _busy = false;
      _publish();
      return;
    }
    if (left != null && left <= 1) {
      _busy = false;
      _guardBlocks = true;
      _cardLocked = left == 0;
      _put({CheckRow.signature: _guardRow(left)});
      return;
    }

    final facts = _facts..clearSignature();
    facts.log.line('Probe-Unterschrift ${_dateTime(_now())}');
    final attempt = _Attempt(this, _Link(_transport), facts);
    attempt.start(CheckRow.signature);
    attempt.known = left;
    try {
      await _signSteps(attempt, ready, pin);
    } catch (e) {
      _unexpected(attempt, e);
    } finally {
      await attempt.link.close();
      facts.log.line(
        'Probe-Unterschrift: ${_word(_rows[CheckRow.signature]!.state)}',
      );
      _busy = false;
      _publish();
    }
  }

  /// Der Chef sagt: Der Zähler der Karte ist wieder voll. Schickt nichts zur
  /// Karte.
  Future<void> resetGuard() async {
    final ready = _ready;
    if (ready == null || _busy) return;
    try {
      await _guard.clear(ready.key);
    } catch (_) {
      return;
    }
    _lowest.remove(ready.key);
    _guardBlocks = false;
    _cardLocked = false;
    _put({CheckRow.signature: const RowResult(RowState.waiting, _T.ready)});
  }

  /// Beendet [changes]. Ein laufender Lauf endet trotzdem und gibt den Leser
  /// frei.
  void dispose() => _changes.close();

  // Ablauf von run.

  Future<void> _runSteps(_Attempt a) async {
    String? address;
    final listed = await _limited(a, () async {
      a.start(CheckRow.reader);
      final devices = await a.link.list();
      a.facts.devices = devices;
      a.facts.tablet = await a.link.info();
      UsbDeviceInfo? reader;
      for (final device in devices) {
        if (device.isCardReader) {
          reader = device;
          break;
        }
      }
      if (reader == null) {
        a.fail(CheckRow.reader, _T.noReader, _T.noReaderHint);
        return;
      }
      a.facts.log.line('Kartenleser ${reader.address}');
      a.set(
        CheckRow.reader,
        RowState.ok,
        reader.name.isEmpty
            ? 'Kartenleser gefunden.'
            : '${reader.name} gefunden.',
      );
      address = reader.address;
    });
    final found = address;
    if (!listed || found == null) return;

    a.start(CheckRow.access);
    final descriptor = await _open(a, found);
    if (descriptor == null) return;
    a.set(CheckRow.access, RowState.ok, _T.allowed);

    await _limited(a, () => _readCard(a, found, descriptor));
  }

  Future<void> _readCard(
    _Attempt a,
    String address,
    CcidDescriptor descriptor,
  ) async {
    a.start(CheckRow.card);
    final session = await _startSession(a, descriptor, forSign: false);
    if (session == null) return;
    try {
      final atr = session.atr;
      final profile = profileForAtr(atr.bytes);
      if (profile == null) {
        _foreign(a, atr.bytes);
        return;
      }
      a.facts.profile = profile;

      final send = session.send;

      for (final aid in profile.applications) {
        if (!(await send(CardCommand.selectApplication(aid))).ok) {
          a.fail(CheckRow.card, _T.applicationMissing, _T.shareReport);
          return;
        }
      }
      final number = await _readNumber(send, profile);
      if (number == null) {
        a.fail(CheckRow.card, _T.applicationMissing, _T.shareReport);
        return;
      }
      a.facts.cardNumber = number;
      a.set(
        CheckRow.card,
        RowState.ok,
        '${profile.label} erkannt.',
        profile.notice,
      );

      a.start(CheckRow.certificate);
      final certificate = await _readCertificate(send, profile, a.facts);
      if (certificate == null) {
        a.fail(CheckRow.certificate, _T.certificateUnreadable, _T.shareReport);
        return;
      }
      final until = _date(certificate.notAfter);
      if (_now().toUtc().isAfter(certificate.notAfter)) {
        a.fail(
          CheckRow.certificate,
          'Das Zertifikat ist am $until abgelaufen.',
          'Die Karte muss getauscht werden.',
        );
        return;
      }
      a.set(
        CheckRow.certificate,
        RowState.ok,
        'Seriennummer ${certificate.serial}, gültig bis $until.',
        'Ausgestellt von ${certificate.issuer}.',
      );

      final key = _compactHex(number);
      int? left;
      try {
        left = await _countOf(key);
      } catch (_) {
        // sign fragt den Wächter noch einmal und schickt ohne Antwort nichts.
        left = _lowest[key];
      }
      if (!a.live) return;
      _ready = _ReadyCard(
        address: address,
        profile: profile,
        atr: atr.bytes,
        number: number,
        key: key,
        certificate: certificate,
      );
      _guardBlocks = left != null && left <= 1;
      _cardLocked = left == 0;
      a.put({CheckRow.signature: _guardRow(left)});
    } on SessionException catch (e) {
      a.facts.log.line('Abbruch: ${e.detail}');
      final (message, hint) = _lost(a);
      a.fail(a.running ?? CheckRow.card, message, hint);
    } finally {
      await session.end();
    }
  }

  /// Öffnet den Leser und liest seinen Deskriptor; ein Fehler steht in
  /// Zeile 2.
  Future<CcidDescriptor?> _open(_Attempt a, String address) async {
    final Uint8List raw;
    try {
      raw = await a.link.open(address);
    } on ReaderException catch (e) {
      a.facts.log.line('Öffnen: ${e.problem.name}');
      final (message, hint) = switch (e.problem) {
        ReaderProblem.noPermission => (_T.denied, _T.deniedHint),
        ReaderProblem.busy => (_T.busy, _T.busyHint),
        ReaderProblem.notCcid => (_T.unknownReader, _T.shareReport),
        _ => (_T.readerGone, _T.readerGoneHint),
      };
      a.fail(CheckRow.access, message, hint);
      return null;
    }
    a.facts.descriptors = raw;
    final CcidDescriptor descriptor;
    try {
      descriptor = CcidDescriptor.parse(raw);
    } on FormatException {
      a.facts.log.line('Kein Deskriptor eines Kartenlesers');
      a.fail(CheckRow.access, _T.unknownReader, _T.shareReport);
      return null;
    }
    a.facts.descriptor = descriptor;
    if (descriptor.level == ExchangeLevel.character) {
      a.facts.log.line('Stufe character');
      a.fail(CheckRow.access, _T.unknownReader, _T.shareReport);
      return null;
    }
    return descriptor;
  }

  /// Schaltet die Karte ein; ein Fehler steht in Zeile 3 (oder 2, wenn der
  /// Leser nicht passt).
  Future<CardSession?> _startSession(
    _Attempt a,
    CcidDescriptor descriptor, {
    required bool forSign,
  }) async {
    final reader = _AtrKeepingReader(
      a.link,
      descriptor,
      log: a.facts.log,
      clock: _now,
    );
    try {
      final session = await CardSession.start(
        reader,
        descriptor,
        log: a.facts.log,
      );
      if (!forSign) a.facts.atr = session.atr.bytes;
      return session;
    } on CcidException catch (e) {
      a.facts.log.line('Einschalten: $e');
      switch (e.problem) {
        case CcidProblem.cardAbsent:
          a.fail(CheckRow.card, _T.noCard, _T.noCardHint);
        case CcidProblem.cardMute:
        case CcidProblem.commandFailed:
          a.fail(CheckRow.card, _T.mute, _T.muteHint);
        case CcidProblem.badAnswer:
          a.fail(CheckRow.card, _T.lost, _T.lostHint);
      }
    } on ReaderException catch (e) {
      a.facts.log.line('Einschalten: $e');
      a.fail(CheckRow.card, _T.readerGone, _T.readerGoneHint);
    } on SessionException catch (e) {
      a.facts.log.line('Sitzung: ${e.detail}');
      switch (e.problem) {
        case SessionProblem.readerNotSupported:
          a.fail(CheckRow.access, _T.unknownReader, _T.shareReport);
        case SessionProblem.cardNotSupported:
          if (forSign) {
            a.fail(CheckRow.card, _T.otherCard);
          } else {
            a.facts.atr = reader.atr;
            _foreign(a, reader.atr);
          }
        case SessionProblem.connectionLost:
          final (message, hint) = _lost(a);
          a.fail(CheckRow.card, message, hint);
      }
    } finally {
      _noteSpeed(a.facts, reader.atr);
    }
    return null;
  }

  /// Gibt die Karte die Geschwindigkeit fest vor (TA2), kann ein Leser, der
  /// sie nicht schafft, schon beim Start abbrechen. Das steht im Bericht,
  /// sobald eine solche ATR gelesen wurde.
  static void _noteSpeed(_Facts facts, Uint8List? raw) {
    if (raw == null) return;
    final Atr atr;
    try {
      atr = Atr.parse(raw);
    } on FormatException {
      return;
    }
    if (atr.ta2 == null) return;
    final ta1 = atr.ta1;
    final line =
        'Hinweis: Die Karte gibt ihre Geschwindigkeit fest vor '
        '(TA1 ${ta1 == null ? '-' : _byteHex(ta1)}). Kann der Leser das '
        'nicht, bricht die Verbindung ab.';
    if (!facts.notes.contains(line)) facts.notes.add(line);
  }

  Future<Uint8List?> _readNumber(
    Future<CardResponse> Function(CardCommand) send,
    CardProfile profile,
  ) async {
    if (!(await send(CardCommand.selectFile(_masterFile))).ok) return null;
    if (!_same(profile.numberFolder, _masterFile) &&
        !(await send(CardCommand.selectFile(profile.numberFolder))).ok) {
      return null;
    }
    if (!(await send(CardCommand.selectFile(profile.numberFile))).ok) {
      return null;
    }
    final answer = await send(CardCommand.readCardNumber());
    if (!answer.ok || answer.data.isEmpty) return null;
    return answer.data;
  }

  /// Liest das Zertifikat in Blöcken zu 256 Bytes, bis seine Länge erreicht
  /// ist, eine Antwort kürzer ist, der Status nicht 9000 ist oder 16 Blöcke
  /// gelesen sind.
  Future<CardCertificate?> _readCertificate(
    Future<CardResponse> Function(CardCommand) send,
    CardProfile profile,
    _Facts facts,
  ) async {
    for (final file in [
      _masterFile,
      profile.signatureFolder,
      profile.certificateFile,
    ]) {
      if (!(await send(CardCommand.selectFile(file))).ok) return null;
    }
    final read = BytesBuilder(copy: true);
    int? total;
    for (var block = 0; block < _maxCertificateBlocks; block++) {
      final answer = await send(CardCommand.readBinary(block * _blockSize));
      if (!answer.ok) break;
      read.add(answer.data);
      total ??= derTotalLength(read.toBytes());
      if (total != null && total > _maxCertificateBlocks * _blockSize) {
        facts.log.line('Zertifikat zu lang ($total Bytes)');
        return null;
      }
      if (total != null && read.length >= total) break;
      if (answer.data.length < _blockSize) break;
    }
    var bytes = read.toBytes();
    if (total != null && bytes.length > total) bytes = bytes.sublist(0, total);
    facts.certificate = bytes;
    try {
      final certificate = CardCertificate.parse(bytes);
      facts.certificate = certificate.der;
      return certificate;
    } on FormatException {
      facts.log.line('Zertifikat nicht lesbar (${bytes.length} Bytes)');
      return null;
    }
  }

  void _foreign(_Attempt a, Uint8List? atr) {
    a.put({
      CheckRow.card: RowResult(
        RowState.problem,
        _T.foreign,
        'Antwort der Karte: ${atr == null ? '-' : hex(atr)}. ${_T.shareReport}',
      ),
      CheckRow.certificate: const RowResult(RowState.locked, _T.prerequisite),
      CheckRow.signature: const RowResult(RowState.locked, _T.notReleased),
    });
  }

  // Ablauf von sign.

  Future<void> _signSteps(_Attempt a, _ReadyCard ready, String pin) async {
    final descriptor = await _open(a, ready.address);
    if (descriptor == null) {
      if (a.live) _ready = null;
      return;
    }
    await _limited(a, () => _signOnCard(a, descriptor, ready, pin));
  }

  Future<void> _signOnCard(
    _Attempt a,
    CcidDescriptor descriptor,
    _ReadyCard ready,
    String pin,
  ) async {
    final session = await _startSession(a, descriptor, forSign: true);
    if (session == null) {
      if (a.live) _ready = null;
      return;
    }
    try {
      final profile = ready.profile;
      // Dieselbe Karte wie beim letzten Lauf? Sonst kein VERIFY: der Wächter
      // gilt je Kartennummer.
      final number = _same(session.atr.bytes, ready.atr)
          ? await _readNumber(session.send, profile)
          : null;
      if (number == null || !_same(number, ready.number)) {
        a.facts.log.line('Andere Karte als beim Prüflauf');
        if (a.live) _ready = null;
        a.fail(CheckRow.card, _T.otherCard);
        return;
      }
      for (final file in [_masterFile, profile.signatureFolder]) {
        if (!(await session.send(CardCommand.selectFile(file))).ok) {
          a.fail(CheckRow.signature, _T.rejected, _T.shareReport);
          return;
        }
      }
      if (profile.separateHash &&
          !(await session.send(CardCommand.prepareSignature())).ok) {
        a.fail(CheckRow.signature, _T.rejected, _T.shareReport);
        return;
      }
      // Eine Runde, und nur wenn sie stimmt, zwei weitere für die Dauer (K5).
      for (var round = 0; round < 3; round++) {
        if (!await _signRound(a, session, ready, pin)) return;
      }
      final durations = a.facts.durationsMs;
      final mean = durations.reduce((x, y) => x + y) / durations.length;
      final seconds = (mean / 1000).toStringAsFixed(1).replaceAll('.', ',');
      a.set(
        CheckRow.signature,
        RowState.ok,
        'Unterschrift erstellt und geprüft. Dauer: $seconds Sekunden.',
      );
    } on SessionException catch (e) {
      a.facts.log.line('Abbruch: ${e.detail}');
      final (message, hint) = _lost(a);
      a.fail(CheckRow.signature, message, hint);
    } finally {
      await session.end();
    }
  }

  /// VERIFY, unterschreiben, prüfen. `false`: Schluss, nichts mehr zur Karte
  /// außer dem Ausschalten.
  Future<bool> _signRound(
    _Attempt a,
    CardSession session,
    _ReadyCard ready,
    String pin,
  ) async {
    final profile = ready.profile;
    final facts = a.facts;
    final hash = _hashOfNow();
    final started = _now();
    // Vorher merken (write-ahead): Ob die Antwort kommt oder nicht, ob die
    // App mittendrin stirbt, der Wächter rechnet mit einem Versuch weniger.
    final key = ready.key;
    final known = a.known;
    final assumed = known == null ? 2 : known - 1;
    final seen = _lowest[key];
    _lowest[key] = assumed;
    try {
      await _guard.recordFailure(key, assumed);
    } catch (_) {
      // Nichts ging hinaus: zurück auf den alten Stand, keine PIN.
      if (seen == null) {
        _lowest.remove(key);
      } else {
        _lowest[key] = seen;
      }
      facts.log.line('Wächter konnte vor VERIFY nicht schreiben');
      a.fail(CheckRow.signature, _T.cannotRemember, _T.cannotRememberHint);
      return false;
    }
    if (!a.live) return false;
    if (assumed <= 1) _guardBlocks = true;
    facts.log.line('Wächter vor VERIFY: $assumed');

    final CardResponse verified;
    a.verifyInFlight = assumed;
    try {
      verified = await session.send(CardCommand.verifyPin(profile, pin));
    } catch (e) {
      // Nach Ablauf der Zeit hat _limited die Zeile schon gesetzt. Der vorher
      // geschriebene Wert bleibt stehen.
      if (!a.live) return false;
      a.verifyInFlight = null;
      facts.log.line(
        'VERIFY abgebrochen: '
        '${e is SessionException ? e.detail : e.runtimeType}',
      );
      a.fail(CheckRow.signature, _T.lost, _unclearHint(assumed));
      return false;
    }
    a.verifyInFlight = null;
    if (!verified.ok) {
      await _wrongVerify(a, ready, verified.status);
      return false;
    }
    _lowest.remove(key);
    _guardBlocks = false;
    a.known = null;
    try {
      await _guard.clear(ready.key);
    } catch (_) {
      facts.log.line('Wächter nicht gelöscht');
    }

    if (profile.separateHash &&
        !(await session.send(CardCommand.putHash(hash))).ok) {
      a.fail(CheckRow.signature, _T.rejected, _T.shareReport);
      return false;
    }
    final signed = await session.send(CardCommand.sign(profile, hash));
    if (!signed.ok) {
      a.fail(CheckRow.signature, _T.rejected, _T.shareReport);
      return false;
    }
    final elapsed = _now().difference(started).inMilliseconds;
    final valid = ready.certificate.verify(hash, signed.data);
    facts.signatureLength ??= signed.data.length;
    facts.signatureValid = (facts.signatureValid ?? true) && valid;
    facts.durationsMs.add(elapsed);
    if (!valid) {
      a.fail(CheckRow.signature, _T.mismatch, _T.shareReport);
      return false;
    }
    return true;
  }

  /// Eine Antwort ungleich 9000 auf VERIFY. Der Wächter schreibt, bevor der
  /// Bildschirm davon erfährt.
  Future<void> _wrongVerify(_Attempt a, _ReadyCard ready, int status) async {
    // Die echte Zahl der Karte ersetzt den vorsichtigen Wert, bevor der
    // Bildschirm davon erfährt.
    Future<void> record(int left) async {
      _lowest[ready.key] = left;
      if (a.live) {
        _guardBlocks = left <= 1;
        _cardLocked = left == 0;
      }
      try {
        await _guard.recordFailure(ready.key, left);
      } catch (_) {
        a.facts.log.line('Wächter konnte nicht schreiben');
      }
    }

    if (status & 0xFFF0 == 0x63C0) {
      final left = status & 0x0F;
      await record(left);
      if (left >= 2) {
        a.fail(
          CheckRow.signature,
          'Die PIN war falsch. Noch $left Versuche.',
          _T.wrongPinHint,
        );
      } else if (left == 1) {
        a.fail(CheckRow.signature, _T.lastTry, _T.lastTryHint);
      } else {
        a.fail(CheckRow.signature, _T.cardLocked, _T.cardLockedHint);
      }
    } else if (status == 0x6983) {
      await record(0);
      a.fail(CheckRow.signature, _T.cardLocked, _T.cardLockedHint);
    } else {
      a.fail(CheckRow.signature, _T.rejected, _T.shareReport);
    }
  }

  // Gemeinsames.

  /// Lässt [body] höchstens [timeLimit] laufen. Danach geht nichts mehr über
  /// den Leser dieses Versuchs, die laufende Zeile zeigt "zu lange", und der
  /// Leser wird freigegeben. `false`, wenn die Zeit abgelaufen ist.
  Future<bool> _limited(_Attempt a, Future<void> Function() body) async {
    try {
      await body().timeout(timeLimit);
      return true;
    } on TimeoutException {
      a.link.cut();
      a.facts.log.line('Nach ${timeLimit.inSeconds} Sekunden abgebrochen');
      // Lief gerade ein VERIFY, ist unklar, ob die Karte gezählt hat; der
      // vorsichtige Wert steht schon im Wächter.
      final inFlight = a.verifyInFlight;
      a.verifyInFlight = null;
      final hint = inFlight == null ? _T.tooSlowHint : _unclearHint(inFlight);
      _put(_failure(a.running ?? CheckRow.reader, _T.tooSlow, hint));
      return false;
    }
  }

  /// Der Stand des Wächters für [key]: das Kleinere aus seinem Speicher und
  /// dem, was diese Instanz gesehen hat. Wirft, wenn der Speicher nicht
  /// lesbar ist.
  Future<int?> _countOf(String key) async {
    final stored = await _guard.retriesLeft(key);
    final seen = _lowest[key];
    if (stored == null) return seen;
    if (seen == null) return stored;
    return min(stored, seen);
  }

  static String _unclearHint(int left) =>
      left >= 2 ? _T.unclearHint : _T.unclearLastHint;

  void _unexpected(_Attempt a, Object error) {
    a.facts.log.line('Unerwarteter Fehler (${error.runtimeType})');
    a.fail(a.running ?? CheckRow.reader, _T.lost, _T.lostHint);
  }

  (String, String) _lost(_Attempt a) => a.link.readerGone
      ? (_T.readerGone, _T.readerGoneHint)
      : (_T.lost, _T.lostHint);

  /// Zeile 5 nach einem Lauf, je nach dem, was der Wächter weiß.
  static RowResult _guardRow(int? left) => switch (left) {
    null => const RowResult(RowState.waiting, _T.ready),
    0 => const RowResult(RowState.problem, _T.cardLocked, _T.cardLockedHint),
    1 => const RowResult(
      RowState.problem,
      _T.probablyLast,
      _T.probablyLastHint,
    ),
    _ => const RowResult(RowState.waiting, _T.ready),
  };

  Uint8List _hashOfNow() {
    final text = 'Kassa Karte prüfen ${_now().toUtc().toIso8601String()}';
    return Uint8List.fromList(crypto.sha256.convert(utf8.encode(text)).bytes);
  }

  /// [row] zeigt den Fehler, die Zeilen darunter sind gesperrt.
  static Map<CheckRow, RowResult> _failure(
    CheckRow row,
    String message,
    String? hint,
  ) => {
    row: RowResult(RowState.problem, message, hint),
    for (final later in CheckRow.values.skip(row.index + 1))
      later: const RowResult(RowState.locked, _T.prerequisite),
  };

  void _put(Map<CheckRow, RowResult> changes) {
    _rows = {..._rows, ...changes};
    _publish();
  }

  void _publish() {
    _state = _compose();
    if (!_changes.isClosed) _changes.add(_state);
  }

  CardCheckState _compose() => CardCheckState(
    rows: Map.unmodifiable(_rows),
    busy: _busy,
    canSign: _ready != null && !_busy && !_guardBlocks,
    guardBlocks: _guardBlocks,
    cardLocked: _cardLocked,
    report: _report(),
  );

  // Bericht.

  String _report() {
    final f = _facts;
    final out = StringBuffer()
      ..writeln('Kassa: Bericht "Karte prüfen"')
      ..writeln(
        'Version $_appVersion, '
        '${f.startedAt == null ? '-' : _dateTime(f.startedAt!)}, '
        '${_orDash(f.tablet.model)}, Android ${_orDash(f.tablet.android)}',
      )
      ..writeln()
      ..writeln('Ergebnis');
    for (final row in CheckRow.values) {
      final result = _rows[row]!;
      out.writeln(
        '${row.index + 1} ${_titles[row]}: ${_word(result.state)} '
        '${result.message}',
      );
    }
    f.notes.forEach(out.writeln);

    out
      ..writeln()
      ..writeln('USB-Geräte');
    final devices = f.devices ?? const [];
    if (devices.isEmpty) out.writeln('keine');
    for (final d in devices) {
      final interfaces = [
        for (final i in d.interfaces)
          '${_byteHex(i.klass)}/${_byteHex(i.subclass)}/${_byteHex(i.protocol)}',
      ].join(', ');
      out.writeln(
        '${d.address} "${d.name}" Klasse ${_byteHex(d.deviceClass)} '
        'Schnittstellen ${interfaces.isEmpty ? '-' : interfaces} '
        '${d.granted ? 'erlaubt' : 'nicht erlaubt'}',
      );
    }

    final descriptor = f.descriptor;
    final descriptors = f.descriptors;
    out
      ..writeln()
      ..writeln('Kartenleser')
      ..writeln('Deskriptoren: ${descriptors == null ? '-' : hex(descriptors)}')
      ..writeln(
        descriptor == null
            ? 'Stufe -, Merkmale -, Blockgröße -'
            : 'Stufe ${descriptor.level.name}, Merkmale '
                  '${descriptor.features.toRadixString(16).padLeft(8, '0').toUpperCase()}, '
                  'Blockgröße ${descriptor.maxIfsd}',
      );

    final atr = f.atr, number = f.cardNumber, certificate = f.certificate;
    final length = f.signatureLength;
    out
      ..writeln()
      ..writeln('Karte')
      ..writeln('ATR: ${atr == null ? '-' : hex(atr)}')
      ..writeln('Art: ${f.profile?.label ?? 'unbekannt'}')
      ..writeln('Kartennummer: ${number == null ? '-' : hex(number)}')
      ..writeln('Zertifikat: ${certificate == null ? '-' : hex(certificate)}')
      ..writeln(
        length == null
            ? 'Unterschrift: -'
            : 'Unterschrift: $length Bytes, '
                  '${f.signatureValid ?? false ? 'gültig' : 'ungültig'}'
                  '${[for (final ms in f.durationsMs) ', $ms ms'].join()}',
      )
      ..writeln()
      ..writeln('Protokoll');
    return _fitted(out.toString(), f.log.lines);
  }

  /// Hängt [lines] an [head]; wird es zu lang, fällt die Mitte des
  /// Protokolls weg.
  static String _fitted(String head, List<String> lines) {
    final full = head + lines.join('\n');
    if (full.length <= maxReportLength) return full;
    const marker = '… gekürzt …';
    final budget = maxReportLength - head.length - marker.length - 2;
    final front = <String>[];
    var used = 0;
    for (final line in lines) {
      if (used + line.length + 1 > budget ~/ 2) break;
      front.add(line);
      used += line.length + 1;
    }
    final back = <String>[];
    for (var i = lines.length - 1; i >= front.length; i--) {
      if (used + lines[i].length + 1 > budget) break;
      back.add(lines[i]);
      used += lines[i].length + 1;
    }
    return head + [...front, marker, ...back.reversed].join('\n');
  }

  static const _titles = {
    CheckRow.reader: 'Kartenleser',
    CheckRow.access: 'Zugriff',
    CheckRow.card: 'Signaturkarte',
    CheckRow.certificate: 'Zertifikat',
    CheckRow.signature: 'Probe-Unterschrift',
  };

  static String _word(RowState state) => switch (state) {
    RowState.ok => 'gut',
    RowState.problem => 'Fehler',
    _ => 'offen',
  };
}

/// Die Texte am Bildschirm, wörtlich aus dem Plan.
abstract final class _T {
  static const readerWaiting =
      'Wird geprüft, sobald du auf "Jetzt prüfen" tippst.';
  static const accessWaiting =
      'Android fragt einmal, ob die Kassa den Leser verwenden darf.';
  static const cardWaiting = 'Die Karte muss im Leser stecken.';
  static const certificateWaiting = 'Seriennummer und Gültigkeit der Karte.';
  static const ready =
      'Mit der PIN der Signaturkarte erstellt die Kassa eine Unterschrift zur '
      'Probe.';

  static const noReader = 'Kein Kartenleser gefunden.';
  static const noReaderHint =
      'Steckt der Leser am Verteiler, und hat der Verteiler Strom?';
  static const allowed = 'Die Kassa darf den Kartenleser verwenden.';
  static const denied = 'Die Kassa darf den Kartenleser nicht verwenden.';
  static const deniedHint =
      'Tipp auf "Nochmal prüfen" und erlaube den Zugriff im Fenster von '
      'Android.';
  static const busy = 'Der Kartenleser ist gerade belegt.';
  static const busyHint =
      'Zieh den Leser ab, steck ihn wieder an und prüf nochmal.';
  static const unknownReader = 'Diesen Kartenleser kennt die Kassa nicht.';
  static const readerGone = 'Der Kartenleser antwortet nicht mehr.';
  static const readerGoneHint = 'Steck ihn wieder an und prüf nochmal.';

  static const noCard = 'Keine Karte im Leser.';
  static const noCardHint =
      'Steck die Karte mit dem Chip voran bis zum Anschlag hinein.';
  static const mute = 'Die Karte antwortet nicht.';
  static const muteHint = 'Dreh die Karte um und steck sie nochmal hinein.';
  static const foreign =
      'Die Karte antwortet, aber die Kassa kennt diese Art nicht.';
  static const applicationMissing =
      'Auf der Karte fehlt die Signatur für Registrierkassen.';
  static const lost = 'Die Verbindung zur Karte ist abgebrochen.';
  static const lostHint =
      'Prüf nochmal. Bleibt es dabei, teil bitte den Bericht.';
  static const otherCard = 'Das ist eine andere Karte. Prüf nochmal.';

  static const certificateUnreadable = 'Das Zertifikat ließ sich nicht lesen.';

  static const wrongPinHint =
      'Frag im Betrieb nach der richtigen PIN, bevor du es nochmal versuchst.';
  static const lastTry =
      'Die PIN war falsch. Die Karte hat nur noch einen Versuch.';
  static const lastTryHint =
      'Die Kassa schickt die PIN jetzt nicht mehr. Wird die Karte in der alten '
      'Kassa mit der richtigen PIN verwendet, ist der Zähler wieder voll.';
  static const probablyLast =
      'Die Karte hat vermutlich nur noch einen Versuch.';
  static const probablyLastHint =
      'Die Kassa schickt die PIN jetzt nicht mehr. Wird die Karte in der alten '
      'Kassa mit der richtigen PIN verwendet, ist der Zähler wieder voll.';
  static const unclearHint =
      'Ob die Karte den Versuch gezählt hat, ist unklar. Die Kassa rechnet '
      'vorsichtig mit einem Versuch weniger.';
  static const unclearLastHint =
      'Die Karte hat vermutlich nur noch einen Versuch. Die Kassa schickt die '
      'PIN jetzt nicht mehr. Wird die Karte in der alten Kassa mit der '
      'richtigen PIN verwendet, ist der Zähler wieder voll.';
  static const cannotRemember =
      'Die Kassa kann sich den Versuch gerade nicht merken.';
  static const cannotRememberHint =
      'Deshalb schickt sie die PIN nicht. Prüf nochmal. Bleibt es dabei, teil '
      'bitte den Bericht.';
  static const cardLocked = 'Die Karte ist gesperrt.';
  static const cardLockedHint = 'Wende dich an A-Trust.';
  static const rejected = 'Die Karte hat die Unterschrift abgelehnt.';
  static const mismatch =
      'Die Karte hat unterschrieben, aber die Unterschrift passt nicht zum '
      'Zertifikat.';

  static const prerequisite = 'Erst wenn die Zeile darüber grün ist.';
  static const notReleased =
      'Für diese Karte ist die Probe-Unterschrift nicht freigegeben.';
  static const tooSlow = 'Das hat zu lange gedauert.';
  static const tooSlowHint =
      'Prüf nochmal. Bleibt es dabei, teil bitte den Bericht.';
  static const shareReport = 'Teil bitte den Bericht.';
}

const _initialRows = {
  CheckRow.reader: RowResult(RowState.waiting, _T.readerWaiting),
  CheckRow.access: RowResult(RowState.waiting, _T.accessWaiting),
  CheckRow.card: RowResult(RowState.waiting, _T.cardWaiting),
  CheckRow.certificate: RowResult(RowState.waiting, _T.certificateWaiting),
  CheckRow.signature: RowResult(RowState.waiting, _T.ready),
};

/// Ein Lauf oder eine Probe-Unterschrift. Nach Ablauf der Zeit ([live] ist
/// `false`) ändert der Versuch keine Zeile mehr, und über seinen Leser geht
/// nichts mehr hinaus.
class _Attempt {
  _Attempt(this.check, this.link, this.facts);

  final CardCheck check;
  final _Link link;
  final _Facts facts;

  /// Die Zeile, die gerade läuft.
  CheckRow? running;

  /// Bei [CardCheck.sign]: der Zähler, den der Wächter vor diesem Versuch
  /// kannte; `null`, wenn keiner bekannt ist (auch nach einem 9000).
  int? known;

  /// Ein VERIFY ist unterwegs, der Status noch nicht da: der vorher in den
  /// Wächter geschriebene Wert.
  int? verifyInFlight;

  bool get live => !link.isCut;

  /// [row] läuft; der Text bleibt der der wartenden Zeile.
  void start(CheckRow row) {
    if (!live) return;
    running = row;
    check._put({row: RowResult(RowState.running, _initialRows[row]!.message)});
  }

  void set(CheckRow row, RowState state, String message, [String? hint]) =>
      put({row: RowResult(state, message, hint)});

  void fail(CheckRow row, String message, [String? hint]) =>
      put(CardCheck._failure(row, message, hint));

  void put(Map<CheckRow, RowResult> changes) {
    if (live) check._put(changes);
  }
}

/// Der Leser eines Versuchs. Nach [cut] geht nichts mehr hinaus, und
/// [close] gibt den Leser nur einmal frei.
class _Link implements ReaderTransport {
  _Link(this._inner);

  final ReaderTransport _inner;
  bool _cut = false;
  bool _closed = false;

  /// Der Leser selbst meldete einen Fehler (abgezogen, nicht mehr offen).
  bool readerGone = false;

  bool get isCut => _cut;

  void cut() => _cut = true;

  @override
  Future<List<UsbDeviceInfo>> list() => _inner.list();

  @override
  Future<TabletInfo> info() => _inner.info();

  @override
  Future<Uint8List> open(String address) {
    if (_cut) throw const ReaderException(ReaderProblem.notOpen);
    return _inner.open(address);
  }

  @override
  Future<Uint8List> exchange(Uint8List? out, {required Duration limit}) async {
    if (_cut) throw const ReaderException(ReaderProblem.notOpen);
    try {
      final answer = await _inner.exchange(out, limit: limit);
      if (_cut) throw const ReaderException(ReaderProblem.notOpen);
      return answer;
    } on ReaderException catch (e) {
      if (const [
        ReaderProblem.io,
        ReaderProblem.notOpen,
        ReaderProblem.notFound,
        ReaderProblem.noChannel,
      ].contains(e.problem)) {
        readerGone = true;
      }
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _inner.close();
  }
}

/// Merkt sich die ATR, auch wenn die Sitzung sie danach ablehnt.
class _AtrKeepingReader extends CcidReader {
  _AtrKeepingReader(
    super.transport,
    super.descriptor, {
    super.log,
    super.clock,
  });

  Uint8List? atr;

  @override
  Future<Uint8List> powerOn() async => atr = await super.powerOn();
}

/// Was der Bericht braucht. Nie die PIN.
class _Facts {
  _Facts(this.startedAt);

  final DateTime? startedAt;
  final ProbeLog log = ProbeLog();
  final List<String> notes = [];
  List<UsbDeviceInfo>? devices;
  TabletInfo tablet = const TabletInfo('', '');
  Uint8List? descriptors;
  CcidDescriptor? descriptor;
  Uint8List? atr;
  CardProfile? profile;
  Uint8List? cardNumber;
  Uint8List? certificate;
  int? signatureLength;
  bool? signatureValid;
  final List<int> durationsMs = [];

  void clearSignature() {
    signatureLength = null;
    signatureValid = null;
    durationsMs.clear();
  }
}

class _ReadyCard {
  const _ReadyCard({
    required this.address,
    required this.profile,
    required this.atr,
    required this.number,
    required this.key,
    required this.certificate,
  });

  final String address;
  final CardProfile profile;
  final Uint8List atr;
  final Uint8List number;

  /// Die Kartennummer für den Wächter.
  final String key;
  final CardCertificate certificate;
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _compactHex(List<int> data) =>
    data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();

String _byteHex(int value) =>
    value.toRadixString(16).padLeft(2, '0').toUpperCase();

String _two(int n) => n.toString().padLeft(2, '0');

/// `TT.MM.JJJJ` des Tages in UTC.
String _date(DateTime t) {
  final u = t.toUtc();
  return '${_two(u.day)}.${_two(u.month)}.${u.year}';
}

/// `TT.MM.JJJJ HH:MM:SS`, bei einer Zeit in UTC mit ` UTC` dahinter.
String _dateTime(DateTime t) =>
    '${_two(t.day)}.${_two(t.month)}.${t.year} '
    '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}'
    '${t.isUtc ? ' UTC' : ''}';

String _orDash(String text) => text.isEmpty ? '-' : text;
