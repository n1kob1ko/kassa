// Der Halter der Signaturkarte: der eine Besitzer des Kartenlesers für das
// Signieren. Er hält die Sitzung mit der Karte zwischen den Bons offen, prüft
// die gespeicherte PIN einmal je Sitzung (Plan C2) und liefert für einen Hash
// von 32 Bytes die rohe Antwort der Karte auf COMPUTE DIGITAL SIGNATURE.
//
// Schutz der Karte: VERIFY geht nur aus [CardSigner._verify] hinaus, nur an
// die Karte, deren Art (aus der ATR) und Nummer der gespeicherten [CardPin]
// gleichen, und nie, wenn die PIN abgelehnt ist oder zwei VERIFY ohne
// Antwort blieben (Plan C4), und nie, wenn der PIN-Wächter nur noch einen
// Versuch kennt. Der Zähler "ohne Antwort" wird vor dem Senden
// geschrieben. Die PIN steht in keinem Feld; sie wird für jedes VERIFY neu
// aus dem geschützten Speicher gelesen.

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../rksv_secrets.dart';
import 'atrust_card.dart';
import 'card_session.dart';
import 'ccid.dart';
import 'pin_guard.dart';
import 'reader_transport.dart';

enum CardSignProblem {
  noReader,
  noPermission,
  noCard,
  otherCard,
  pinMissing,
  pinRejected,
  silent,
  refused,
  busy,
}

final class CardSignException implements Exception {
  const CardSignException(this.problem);

  final CardSignProblem problem;

  /// Der Satz für den Ausfall; ohne Geheimnis.
  String get sentence => switch (problem) {
    CardSignProblem.noReader => 'Kein Kartenleser gefunden.',
    CardSignProblem.noPermission =>
      'Der Zugriff auf den Kartenleser ist nicht erlaubt.',
    CardSignProblem.noCard => 'Keine Karte im Kartenleser.',
    CardSignProblem.otherCard => 'Im Kartenleser steckt eine andere Karte.',
    CardSignProblem.pinMissing => 'Die PIN der Karte fehlt.',
    CardSignProblem.pinRejected => 'Die Karte hat die PIN abgelehnt.',
    CardSignProblem.silent => 'Die Karte antwortet nicht.',
    CardSignProblem.refused => 'Die Karte hat die Unterschrift abgelehnt.',
    CardSignProblem.busy => 'Die Karte wird gerade geprüft.',
  };

  @override
  String toString() => 'CardSignException(${problem.name})';
}

class CardSigner {
  CardSigner({
    required this._transport,
    required this._secrets,
    required this._guard,
  });

  final ReaderTransport _transport;
  final RksvSecrets _secrets;
  final PinGuard _guard;

  /// So lange darf jeder Aufruf in den geschützten Speicher und den
  /// PIN-Wächter höchstens dauern.
  static const storageLimit = Duration(seconds: 2);

  static const _masterFile = [0x3F, 0x00];
  static const _notSatisfied = 0x6982;

  /// So viele Versuche hat eine Karte, von der kein Fehlversuch bekannt ist.
  static const _fullRetries = 3;

  /// Nach diesen Problemen wärmt der Halter nicht von selbst auf: Ein neuer
  /// Versuch änderte nichts, oder jemand anderer hat den Leser.
  static const _noWarmUpAfter = {
    CardSignProblem.pinRejected,
    CardSignProblem.pinMissing,
    CardSignProblem.otherCard,
    CardSignProblem.busy,
  };

  /// Die offene Sitzung; `null`: keine.
  _Held? _held;

  /// Ein Öffnen läuft gerade (aus [warmUp] oder [sign]); endet nie mit Fehler.
  Future<void>? _opening;

  /// Die Sitzung wird gerade freigegeben (Ausschalten, Leser schließen); ein
  /// neues Öffnen wartet darauf. Endet nie mit Fehler.
  Future<void>? _dropping;

  /// Das Ende des letzten [sign] oder [release]; endet nie mit Fehler.
  Future<void> _queue = Future<void>.value();

  /// Wie viele [paused] gerade laufen.
  int _pauses = 0;

  /// Ein laufendes Öffnen wartet gerade auf die Antwort von Android auf die
  /// Frage nach der Erlaubnis (nur mit `ask`, Gerät ohne Erlaubnis).
  bool _waitingForAndroid = false;

  /// Endet, sobald ein Öffnen Android zu fragen beginnt; danach neu.
  Completer<void> _androidAsks = Completer<void>();

  /// Wie viele VERIFY dieser Halter abgeschickt hat (A1: kein zweiter
  /// Versuch nach einem VERIFY im selben Aufruf).
  int _verifiesSent = 0;

  /// Was dieser Halter selbst weiß, zusätzlich zum Speicher (Plan C4).
  int _unanswered = 0;
  bool _rejected = false;

  CardSignProblem? _lastProblem;

  /// Eine Sitzung ist offen.
  bool get ready => _held != null;

  /// Das Problem des letzten [sign] oder [warmUp]; `null` nach einem Erfolg.
  CardSignProblem? get lastProblem => _lastProblem;

  /// Unterschreibt [hash] (32 Bytes) und gibt die rohe Antwort der Karte
  /// zurück. Aufrufe laufen nacheinander. Wirft nur [CardSignException].
  /// Während [paused] endet ein neuer Aufruf sofort mit
  /// [CardSignProblem.busy]; einer von vorher läuft noch zu Ende.
  Future<Uint8List> sign(Uint8List hash) {
    if (_pauses > 0) {
      _lastProblem = CardSignProblem.busy;
      return Future.error(const CardSignException(CardSignProblem.busy));
    }
    final result = _queue.then((_) => _signGuarded(hash));
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Öffnet ohne Sitzung eine im Hintergrund; prüft keine PIN und wirft nie.
  /// Höchstens ein Versuch zugleich: Läuft schon einer, wartet dieser Aufruf
  /// auf ihn. Nur mit [ask] darf Android nach der Erlaubnis fragen (C6).
  Future<void> warmUp({bool ask = false}) async {
    if (_pauses > 0) {
      _lastProblem = CardSignProblem.busy;
      return;
    }
    if (_held != null) return;
    final running = _opening;
    if (running != null) return running;
    try {
      await _openOnce(ask: ask);
    } on CardSignException catch (e) {
      _lastProblem = e.problem;
    }
  }

  /// Gibt die Sitzung frei, nachdem ein laufendes [sign] fertig ist.
  Future<void> release() {
    final done = _queue.then((_) async {
      while (_opening != null) {
        await _opening;
      }
      await _drop();
    });
    _queue = done.then<void>((_) {}, onError: (Object _) {});
    return _queue;
  }

  /// Gibt die Sitzung frei und hält [sign] und [warmUp] mit
  /// [CardSignProblem.busy] ab, bis [body] fertig ist (Plan C13). Ein schon
  /// laufendes [sign] endet vorher. Darf verschachtelt werden.
  Future<T> paused<T>(Future<T> Function() body) async {
    _pauses++;
    try {
      await release();
      return await body();
    } finally {
      _pauses--;
    }
  }

  /// Die gespeicherte PIN ist neu: vergisst "abgelehnt" und "ohne Antwort"
  /// im Arbeitsspeicher und gibt die Sitzung frei.
  void pinChanged() {
    _unanswered = 0;
    _rejected = false;
    unawaited(release());
  }

  /// [call] mit [storageLimit]; nach Ablauf [TimeoutException], wie ein
  /// Speicher, der wirft.
  static Future<T> _stored<T>(Future<T> call) => call.timeout(storageLimit);

  /// [_stored], ein Fehler oder Ablauf zählt nicht.
  static Future<void> _quietly(Future<void> call) async {
    try {
      await _stored(call);
    } catch (_) {
      // Bewusst übergangen; siehe die Aufrufer.
    }
  }

  // Signieren.

  Future<Uint8List> _signGuarded(Uint8List hash) async {
    try {
      final signature = await _signNow(hash);
      _lastProblem = null;
      return signature;
    } on CardSignException catch (e) {
      _failed(e.problem);
      rethrow;
    } catch (_) {
      await _drop();
      _failed(CardSignProblem.silent);
      throw const CardSignException(CardSignProblem.silent);
    }
  }

  void _failed(CardSignProblem problem) {
    _lastProblem = problem;
    // Während einer Pause bliebe vom Aufwärmen nur "busy" über dem echten
    // Problem.
    if (_pauses == 0 && !_noWarmUpAfter.contains(problem)) {
      unawaited(warmUp());
    }
  }

  Future<Uint8List> _signNow(Uint8List hash) async {
    if (hash.length != 32) {
      throw const CardSignException(CardSignProblem.refused);
    }
    final old = _held;
    if (old != null) {
      final verifiesBefore = _verifiesSent;
      try {
        return await _signOn(old, hash);
      } on _SessionLost catch (lost) {
        // Die Sitzung von vorher ist tot (Karte neu gesteckt, USB kurz weg).
        // Ging in diesem Aufruf noch kein VERIFY hinaus, öffnet der Halter
        // einmal neu und signiert noch einmal, mit dem ersten VERIFY der
        // neuen Sitzung. Nach einem VERIFY nie: Es kann gezählt haben.
        if (_verifiesSent != verifiesBefore) {
          throw CardSignException(lost.problem);
        }
      }
    }
    // Scheitert das Öffnen, gilt sein Problem (etwa noReader).
    final held = await _sessionForSign();
    try {
      return await _signOn(held, hash);
    } on _SessionLost catch (lost) {
      throw CardSignException(lost.problem);
    }
  }

  /// Die Sitzung für ein [sign] ohne offene Sitzung: wartet auf ein laufendes
  /// Öffnen, außer es wartet auf die Antwort von Android (dann sofort
  /// [CardSignProblem.noPermission], A3), sonst öffnet es selbst, ohne
  /// Android zu fragen (C6).
  Future<_Held> _sessionForSign() async {
    while (true) {
      final running = _opening;
      if (running == null) break;
      if (_waitingForAndroid) {
        throw const CardSignException(CardSignProblem.noPermission);
      }
      await Future.any([running, _androidAsks.future]);
    }
    return _held ?? await _openOnce(ask: false);
  }

  /// VERIFY, wenn die Sitzung es braucht, und die Unterschrift. Bricht die
  /// Verbindung ab, gibt es die Sitzung frei und wirft [_SessionLost].
  Future<Uint8List> _signOn(_Held held, Uint8List hash) async {
    try {
      var verifiedNow = false;
      if (!held.verified) {
        await _verify(held);
        verifiedNow = true;
      }
      var answer = await _signOnce(held, hash);
      if (answer.status == _notSatisfied && !verifiedNow) {
        // Die Karte will die PIN je Unterschrift: genau einmal (C2).
        held.verified = false;
        await _verify(held);
        answer = await _signOnce(held, hash);
      }
      if (!answer.ok) throw const CardSignException(CardSignProblem.refused);
      return answer.data;
    } on SessionException {
      final absent = held.reader.cardAbsent;
      await _drop();
      throw _SessionLost(
        absent ? CardSignProblem.noCard : CardSignProblem.silent,
      );
    }
  }

  Future<CardResponse> _signOnce(_Held held, Uint8List hash) async {
    final send = held.session.send;
    if (held.profile.separateHash) {
      final put = await send(CardCommand.putHash(hash));
      if (!put.ok) return put;
    }
    return send(CardCommand.sign(held.profile, hash));
  }

  /// VERIFY mit der gespeicherten PIN. Wirft, wenn die PIN nicht gilt oder
  /// nicht hinausgehen darf; [SessionException], wenn keine Antwort kam.
  Future<void> _verify(_Held held) async {
    final CardPin? pin;
    try {
      pin = await _stored(_secrets.cardPin());
    } on TimeoutException {
      throw const CardSignException(CardSignProblem.silent);
    } catch (_) {
      throw const CardSignException(CardSignProblem.pinMissing);
    }
    if (pin == null) throw const CardSignException(CardSignProblem.pinMissing);
    if (pin.kind != held.kind || pin.numberHex != held.numberHex) {
      throw const CardSignException(CardSignProblem.otherCard);
    }
    final CardPinStatus stored;
    try {
      stored = await _stored(_secrets.cardPinStatus());
    } catch (_) {
      // Ohne den Stand geht keine PIN hinaus.
      throw const CardSignException(CardSignProblem.silent);
    }
    final unanswered = max(_unanswered, stored.unanswered);
    if (_rejected || stored.rejected || unanswered >= 2) {
      throw const CardSignException(CardSignProblem.pinRejected);
    }
    // Die Schutzregeln von "Karte prüfen" gelten auch hier: Kennt der Wächter
    // nur noch einen Versuch, geht keine PIN hinaus. Nicht gemerkt, denn der
    // Chef kann den Wächter jederzeit zurücksetzen.
    final int? guarded;
    try {
      guarded = await _stored(_guard.retriesLeft(held.numberHex));
    } catch (_) {
      throw const CardSignException(CardSignProblem.silent);
    }
    if (guarded != null && guarded <= 1) {
      throw const CardSignException(CardSignProblem.pinRejected);
    }
    final CardCommand command;
    try {
      command = CardCommand.verifyPin(held.profile, pin.pin);
    } on ArgumentError {
      throw const CardSignException(CardSignProblem.pinRejected);
    }
    // Vorher merken: Kommt keine Antwort, zählt der Versuch (C4).
    try {
      await _stored(
        _secrets.writeCardPinStatus(CardPinStatus(unanswered: unanswered + 1)),
      );
    } catch (_) {
      throw const CardSignException(CardSignProblem.silent);
    }
    // Und im Wächter, wie CardCheck._signRound (write-ahead): ein Versuch
    // weniger als bekannt, ohne Eintrag der volle Zähler der Karte weniger
    // eins. So sieht "Karte prüfen" die Versuche des Halters und umgekehrt.
    try {
      await _stored(
        _guard.recordFailure(held.numberHex, (guarded ?? _fullRetries) - 1),
      );
    } catch (_) {
      // Nichts ging hinaus: der Zähler zurück auf den alten Stand, keine PIN.
      await _quietly(
        _secrets.writeCardPinStatus(
          CardPinStatus(unanswered: stored.unanswered),
        ),
      );
      throw const CardSignException(CardSignProblem.silent);
    }
    _unanswered = unanswered + 1;

    _verifiesSent++;
    final answer = await held.session.send(command);
    final status = answer.status;
    if (answer.ok) {
      _unanswered = 0;
      held.verified = true;
      // Beides zugleich, damit ein hängender Speicher den Bon höchstens
      // einmal [storageLimit] kostet. Scheitert eins: Der Zähler bleibt im
      // Speicher stehen (vorsichtig, nicht falsch), oder der Wächter bleibt,
      // wie er war (wie CardCheck); die Unterschrift geht weiter.
      await Future.wait([
        _quietly(_secrets.writeCardPinStatus(const CardPinStatus())),
        _quietly(_guard.clear(held.numberHex)),
      ]);
      return;
    }
    // Wie CardCheck._wrongVerify: die Zahl der Versuche für den Wächter.
    final int? left;
    if (status & 0xFFF0 == 0x63C0) {
      left = status & 0x0F;
    } else if (status == 0x6983) {
      left = 0;
    } else if (status == 0x6984) {
      left = null;
    } else {
      // Keine Ablehnung der PIN; der Zähler bleibt, wie er geschrieben wurde.
      throw const CardSignException(CardSignProblem.refused);
    }
    _rejected = true;
    _unanswered = 0;
    // Scheitert eins, hält der Arbeitsspeicher "abgelehnt" fest; der Wächter
    // ist eine zweite Sicherung.
    await Future.wait([
      _quietly(
        _secrets.writeCardPinStatus(const CardPinStatus(rejected: true)),
      ),
      if (left != null) _quietly(_guard.recordFailure(held.numberHex, left)),
    ]);
    throw const CardSignException(CardSignProblem.pinRejected);
  }

  // Sitzung.

  /// Öffnet eine Sitzung und merkt sich, dass gerade geöffnet wird.
  Future<_Held> _openOnce({required bool ask}) {
    final future = _open(ask: ask);
    final done = future.then<void>((_) {}, onError: (Object _) {});
    _opening = done;
    unawaited(
      done.whenComplete(() {
        if (identical(_opening, done)) _opening = null;
      }),
    );
    return future;
  }

  Future<_Held> _open({required bool ask}) async {
    // Ein Schließen, das noch läuft, schlösse sonst den neuen Leser.
    while (_dropping != null) {
      await _dropping;
    }
    try {
      final held = await _openSteps(ask: ask);
      _held = held;
      _lastProblem = null;
      return held;
    } on CardSignException {
      rethrow;
    } catch (_) {
      throw const CardSignException(CardSignProblem.silent);
    }
  }

  Future<_Held> _openSteps({required bool ask}) async {
    final CardPin? pin;
    try {
      pin = await _stored(_secrets.cardPin());
    } on TimeoutException {
      throw const CardSignException(CardSignProblem.silent);
    } catch (_) {
      throw const CardSignException(CardSignProblem.pinMissing);
    }
    if (pin == null) throw const CardSignException(CardSignProblem.pinMissing);
    final kind = pin.kind, numberHex = pin.numberHex;

    UsbDeviceInfo? device;
    for (final candidate in await _transport.list()) {
      if (candidate.isCardReader) {
        device = candidate;
        break;
      }
    }
    if (device == null) throw const CardSignException(CardSignProblem.noReader);
    // Beim Signieren kein Fenster von Android (C6).
    if (!ask && !device.granted) {
      throw const CardSignException(CardSignProblem.noPermission);
    }

    final Uint8List raw;
    // Mit `ask` fragt Android jetzt; ein [sign] wartet darauf nicht (A3).
    final asks = ask && !device.granted;
    if (asks) {
      _waitingForAndroid = true;
      if (!_androidAsks.isCompleted) _androidAsks.complete();
    }
    try {
      raw = await _transport.open(device.address);
    } on ReaderException catch (e) {
      throw CardSignException(switch (e.problem) {
        ReaderProblem.noPermission => CardSignProblem.noPermission,
        ReaderProblem.notFound ||
        ReaderProblem.notCcid ||
        ReaderProblem.noChannel => CardSignProblem.noReader,
        _ => CardSignProblem.silent,
      });
    } finally {
      if (asks) {
        _waitingForAndroid = false;
        _androidAsks = Completer<void>();
      }
    }
    try {
      final CcidDescriptor descriptor;
      try {
        descriptor = CcidDescriptor.parse(raw);
      } on FormatException {
        throw const CardSignException(CardSignProblem.noReader);
      }
      if (descriptor.level == ExchangeLevel.character) {
        throw const CardSignException(CardSignProblem.noReader);
      }
      final reader = _WatchingReader(_transport, descriptor);
      final CardSession session;
      try {
        session = await CardSession.start(reader, descriptor);
      } on CcidException catch (e) {
        throw CardSignException(
          e.problem == CcidProblem.cardAbsent
              ? CardSignProblem.noCard
              : CardSignProblem.silent,
        );
      } on SessionException catch (e) {
        throw CardSignException(switch (e.problem) {
          SessionProblem.readerNotSupported => CardSignProblem.noReader,
          SessionProblem.cardNotSupported => CardSignProblem.otherCard,
          SessionProblem.connectionLost =>
            reader.cardAbsent ? CardSignProblem.noCard : CardSignProblem.silent,
        });
      }
      try {
        return await _prepare(session, reader, kind, numberHex);
      } catch (_) {
        await session.end();
        rethrow;
      }
    } catch (_) {
      await _closeTransport();
      rethrow;
    }
  }

  /// Art und Nummer der eingeschalteten Karte prüfen, Ordner der Signatur
  /// wählen.
  Future<_Held> _prepare(
    CardSession session,
    _WatchingReader reader,
    String kind,
    String numberHex,
  ) async {
    try {
      // Die Art jedes Mal neu aus der ATR (Plan 6.2).
      final profile = profileForAtr(session.atr.bytes);
      if (profile == null || profile.kind.name != kind) {
        throw const CardSignException(CardSignProblem.otherCard);
      }
      final number = await _readNumber(session, profile);
      if (number == null || _hex(number) != numberHex) {
        throw const CardSignException(CardSignProblem.otherCard);
      }
      for (final file in [_masterFile, profile.signatureFolder]) {
        if (!(await session.send(CardCommand.selectFile(file))).ok) {
          throw const CardSignException(CardSignProblem.refused);
        }
      }
      if (profile.separateHash &&
          !(await session.send(CardCommand.prepareSignature())).ok) {
        throw const CardSignException(CardSignProblem.refused);
      }
      return _Held(session, reader, profile, kind, numberHex);
    } on SessionException {
      throw CardSignException(
        reader.cardAbsent ? CardSignProblem.noCard : CardSignProblem.silent,
      );
    }
  }

  /// Wie `CardCheck._readNumber`.
  static Future<Uint8List?> _readNumber(
    CardSession session,
    CardProfile profile,
  ) async {
    final send = session.send;
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

  /// Schaltet die Karte aus und gibt den Leser frei; wirft nie.
  Future<void> _drop() async {
    final held = _held;
    _held = null;
    if (held == null) {
      final running = _dropping;
      if (running != null) await running;
      return;
    }
    final done = () async {
      await held.session.end();
      await _closeTransport();
    }();
    _dropping = done;
    try {
      await done;
    } finally {
      if (identical(_dropping, done)) _dropping = null;
    }
  }

  Future<void> _closeTransport() async {
    try {
      await _transport.close();
    } catch (_) {
      // Schließen gelingt immer.
    }
  }
}

/// Die Verbindung zur Karte brach ab; die Sitzung ist schon freigegeben.
final class _SessionLost implements Exception {
  const _SessionLost(this.problem);

  final CardSignProblem problem;
}

/// Die offene Sitzung. Die PIN steht nicht darin.
class _Held {
  _Held(this.session, this.reader, this.profile, this.kind, this.numberHex);

  final CardSession session;
  final _WatchingReader reader;
  final CardProfile profile;

  /// Art und Nummer der gespeicherten [CardPin], denen die Karte glich.
  final String kind, numberHex;

  /// VERIFY gelang in dieser Sitzung.
  bool verified = false;
}

/// Merkt sich, ob der Leser "keine Karte" gemeldet hat; die Sitzung macht
/// daraus nur einen Abbruch der Verbindung.
class _WatchingReader extends CcidReader {
  _WatchingReader(super.transport, super.descriptor);

  bool cardAbsent = false;

  @override
  Future<Uint8List> transfer(
    Uint8List data, {
    int bwi = 0,
    bool secret = false,
    Duration limit = const Duration(seconds: 3),
  }) async {
    try {
      return await super.transfer(data, bwi: bwi, secret: secret, limit: limit);
    } on CcidException catch (e) {
      if (e.problem == CcidProblem.cardAbsent) cardAbsent = true;
      rethrow;
    }
  }
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _hex(List<int> data) =>
    data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();
