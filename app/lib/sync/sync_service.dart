// Gleicht im Hintergrund mit dem Server ab: erst senden, was in der Liste
// "noch zu senden" steht, dann die Änderungen holen. Kein Bildschirm wartet
// darauf: die Kassa arbeitet mit dem, was sie hat, und der Ausgang des
// letzten Versuchs steht im `SyncState`.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/clock.dart';
import '../data/outbox_repository.dart';
import '../data/report_repository.dart' show OutboxBuildError;
import '../data/sync_state_repository.dart';
import 'file_sync.dart';
import 'push_wire.dart';
import 'server_api.dart';
import 'server_changes.dart';
import 'token_store.dart';
import 'wire.dart';

/// `lastError` für einen Fehler am Tablet selbst (eine Seite lässt sich nicht
/// einspielen, die Datenbank oder der geschützte Speicher antwortet nicht).
const localError = 'local';

enum _Outcome {
  /// Alles geholt.
  done,

  /// Gescheitert, bald nochmal versuchen.
  retry,

  /// Gesperrt, Schlüssel ungültig, nicht gekoppelt: erst beim nächsten
  /// regelmäßigen Lauf wieder.
  wait,
}

class SyncService {
  SyncService({
    required this._api,
    required this._tokens,
    required this._syncState,
    required this._changes,
    required this._outbox,
    required this._payloads,
    required this._clock,
    this._files,
    this._internet = const Stream.empty(),
    this._resumed = const Stream.empty(),
    this._enabled = true,
    this._onChanged = _nothing,
    this._reportError = _noReport,
  });

  static void _nothing() {}
  static Future<void> _noReport(Object error, StackTrace? stack) async {}

  /// Abstand der regelmäßigen Läufe.
  static const interval = Duration(minutes: 5);

  /// So lange wartet [poke] auf weitere Einträge, bevor ein Lauf beginnt.
  static const pokeDelay = Duration(seconds: 2);

  /// Höchstens so viele Einträge gehen in einem Paket hinauf. Nach einer
  /// Zeitüberschreitung beim Senden nimmt der nächste Versuch die nächste
  /// Größe (eine langsame Leitung schafft das erste Paket sonst nie), nach
  /// einem Paket, das durchging, wieder die erste.
  static const packetSizes = [100, 25, 5];

  /// Abstände nach Fehlern in Folge, danach bleibt es beim letzten.
  static const retryDelays = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 4),
    Duration(minutes: 8),
    Duration(minutes: 15),
  ];

  final ServerApi _api;
  final TokenStore _tokens;
  final SyncStateRepository _syncState;
  final ServerChanges _changes;
  final OutboxRepository _outbox;
  final PushPayloads _payloads;
  final Clock _clock;

  /// Lädt nach dem Holen die Fotos und das Logo. Ohne: nichts davon.
  final FileSync? _files;
  final Stream<bool> _internet;
  final Stream<void> _resumed;
  final bool _enabled;

  /// Nach einem Lauf, der Daten am Tablet geändert hat.
  final void Function() _onChanged;

  /// Schreibt einen Bericht über einen Fehler am Tablet (der Bericht selbst
  /// nimmt nur feste Felder).
  final Future<void> Function(Object error, StackTrace? stack) _reportError;

  /// Stelle in [packetSizes] für das nächste Paket.
  int _packetStep = 0;

  final _running = StreamController<bool>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  Future<void>? _current;
  Timer? _timer;
  Timer? _pokeTimer;
  bool _pokeAgain = false;
  int _failures = 0;
  bool? _online;
  bool _started = false;
  bool _disposed = false;

  /// Das Holen des laufenden Laufs ist bis zum Ende gekommen.
  bool _pulledAll = false;

  /// `true`, solange ein Lauf läuft.
  Stream<bool> get running => _running.stream;

  /// Holt alle Änderungen seit dem Cursor. Ohne Kassa, vor dem ersten Laden
  /// oder ohne Adresse des Servers tut es nichts. Läuft schon ein Lauf,
  /// wartet der Aufruf auf diesen. Wirft nie.
  Future<void> syncNow() => _current ??= _runAndSchedule().whenComplete(() {
    _current = null;
    // Während des Laufs kam ein neuer Eintrag: noch einmal, nach Ruhe.
    if (_pokeAgain) {
      _pokeAgain = false;
      poke();
    }
  });

  /// Ein neuer Eintrag steht in der Liste: ein Lauf, [pokeDelay] nach dem
  /// letzten Aufruf. Viele Aufrufe kurz hintereinander ergeben einen Lauf. Ein
  /// Lauf, der gerade läuft, wird nicht doppelt gestartet; danach folgt einer.
  /// Ohne Kassa oder ohne Adresse des Servers tut es nichts.
  void poke() {
    if (!_enabled || _disposed) return;
    _pokeTimer?.cancel();
    _pokeTimer = Timer(pokeDelay, _pokeFired);
  }

  Future<void> _pokeFired() async {
    if (_disposed) return;
    if (_current != null) {
      _pokeAgain = true;
      return;
    }
    try {
      if (!(await _syncState.current()).paired) return;
    } catch (_) {
      return;
    }
    if (_disposed) return;
    unawaited(syncNow());
  }

  /// Ein Lauf sofort, dann alle 5 Minuten, nach Fehlern früher. Außerdem ein
  /// Lauf, wenn die App nach vorn kommt und wenn das Internet zurückkommt.
  void start() {
    if (!_enabled || _started || _disposed) return;
    _started = true;
    _subscriptions
      ..add(
        _internet.listen((online) {
          final back = online && _online == false;
          _online = online;
          if (back) syncNow();
        }),
      )
      ..add(_resumed.listen((_) => syncNow()));
    syncNow();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _pokeTimer?.cancel();
    for (final s in _subscriptions) {
      s.cancel();
    }
    _running.close();
  }

  Future<void> _runAndSchedule() async {
    final outcome = await _run();
    if (!_started || _disposed) return;
    final Duration delay;
    switch (outcome) {
      case _Outcome.done:
        _failures = 0;
        delay = interval;
      case _Outcome.retry:
        delay = retryDelays[min(_failures, retryDelays.length - 1)];
        _failures++;
      case _Outcome.wait:
        delay = interval;
    }
    _timer?.cancel();
    _timer = Timer(delay, syncNow);
  }

  Future<_Outcome> _run() async {
    if (!_enabled || _disposed) return _Outcome.wait;
    final SyncState state;
    try {
      state = await _syncState.current();
    } catch (e) {
      // Die eigene Datenbank ist nicht lesbar: bald nochmal.
      return _recordLocal(e);
    }
    if (!state.paired) return _Outcome.wait;
    _setRunning(true);
    try {
      final String? token;
      try {
        token = await _tokens.read();
      } catch (e) {
        return await _recordLocal(e);
      }
      // Daten wiederhergestellt, geschützter Speicher leer: wie ein
      // ungültiger Schlüssel.
      if (token == null) return await _record(ServerFailure.unauthorized.name);
      // Erst senden, dann holen: der Stand des Servers soll die eigenen
      // Änderungen schon kennen.
      final bool complete;
      try {
        complete = await _send(token);
      } on ServerException catch (e) {
        return await _record(e.failure.name);
      } catch (e) {
        return await _recordLocal(e);
      }
      final outcome = await _pull(
        state.pullCursor,
        state.registerId!,
        token,
        sendComplete: complete,
      );
      // Der dritte Schritt: Bilder. Er ändert weder den Ausgang des Laufs noch
      // "Zuletzt abgeglichen", und was dabei schiefgeht, sieht die Kassa nicht.
      if (_pulledAll) await _loadFiles(token);
      return outcome;
    } finally {
      _setRunning(false);
    }
  }

  /// Schickt die Liste "noch zu senden" in Paketen hinauf, bis nichts mehr
  /// wartet. `true`, wenn alles erledigt ist; `false`, wenn Einträge stehen
  /// bleiben, weil der Server für sie `error` sagte oder nichts. Ein Eintrag,
  /// der in diesem Lauf stehen blieb, kommt in diesem Lauf nicht noch einmal
  /// dran: so endet die Schleife immer. Netzfehler werfen [ServerException].
  Future<bool> _send(String token) async {
    final deviceId = await _syncState.deviceId();
    final seen = <int>{};
    var incomplete = false;
    var sent = false;
    while (true) {
      final size = packetSizes[_packetStep];
      final batch = [
        for (final e in await _outbox.nextBatch(limit: size + seen.length))
          if (!seen.contains(e.id)) e,
      ].take(size).toList();
      if (batch.isEmpty) break;

      final packet = <(OutboxEntry, Map<String, Object?>)>[];
      for (final entry in batch) {
        final Map<String, Object?>? body;
        try {
          body = await _payloads.build(entry);
        } catch (e) {
          // Ein Eintrag, der sich nicht bauen lässt, hält die anderen nicht
          // auf: abgelehnt am Tablet, dazu ein Bericht mit der Art des
          // Eintrags und des Fehlers. Ein Bericht über einen Bericht nicht.
          seen.add(entry.id);
          await _outbox.markRejected(entry.id, localError);
          if (entry.kind != 'report') {
            try {
              await _reportError(
                OutboxBuildError(entry.kind, e.runtimeType.toString()),
                null,
              );
            } catch (_) {
              // Der Bericht darf das Senden nicht aufhalten.
            }
          }
          continue;
        }
        if (body == null) {
          // Die Sache gibt es nicht mehr: nichts zu senden.
          await _outbox.remove(entry.id, rev: entry.rev);
        } else {
          packet.add((entry, body));
        }
      }
      if (packet.isEmpty) continue;

      sent = true;
      List<PushResult> results;
      try {
        results = await _api.push(
          token: token,
          deviceId: deviceId,
          entries: [for (final (_, body) in packet) body],
        );
      } on ServerException catch (e) {
        if (e.failure == ServerFailure.timeout) {
          _packetStep = min(_packetStep + 1, packetSizes.length - 1);
        }
        if (e.failure != ServerFailure.rejected) rethrow;
        // Das ganze Paket ist abgelehnt: jeder Eintrag einzeln, damit ein
        // kaputter die anderen nicht aufhält.
        results = [];
        for (final (entry, body) in packet) {
          try {
            results.addAll(
              await _api.push(
                token: token,
                deviceId: deviceId,
                entries: [body],
              ),
            );
          } on ServerException catch (e) {
            if (e.failure != ServerFailure.rejected) rethrow;
            results.add(
              PushResult(
                seq: entry.id,
                status: PushStatus.rejected,
                reason: 'invalid',
              ),
            );
          }
        }
      }

      _packetStep = 0;
      final bySeq = {for (final r in results) r.seq: r};
      for (final (entry, _) in packet) {
        seen.add(entry.id);
        switch (bySeq[entry.id]?.status) {
          case PushStatus.accepted || PushStatus.duplicate:
            // Hat sich der Eintrag währenddessen geändert (`rev`), bleibt er
            // und geht im nächsten Lauf mit dem neuen Stand noch einmal.
            await _outbox.remove(entry.id, rev: entry.rev);
          case PushStatus.rejected:
            await _outbox.markRejected(
              entry.id,
              bySeq[entry.id]?.reason ?? 'invalid',
            );
          case PushStatus.error || null:
            incomplete = true;
        }
      }
    }
    if (sent) await _syncState.setPushed(_clock.now());
    if (incomplete) return false;
    // Ein Eintrag, der sich während des Sendens änderte, wartet noch.
    return (await _outbox.nextBatch(limit: 1)).isEmpty;
  }

  /// Holt die Änderungen. War das Senden nicht vollständig ([sendComplete]
  /// `false`), ist der Lauf danach trotzdem ein Fehler: bald nochmal, und
  /// "Zuletzt abgeglichen" rückt nicht weiter.
  Future<_Outcome> _pull(
    int cursor,
    String registerId,
    String token, {
    required bool sendComplete,
  }) async {
    var changed = false;
    _pulledAll = false;
    try {
      var since = cursor;
      while (true) {
        final page = await _api.pull(token: token, since: since);
        // Eine Seite, die nicht weiterführt, ergäbe eine endlose Schleife.
        if (page.more && page.next <= since) {
          throw const ServerException(ServerFailure.server);
        }
        final applied = await _changes.applyPage(
          page,
          at: _clock.now(),
          since: since,
          registerId: registerId,
          markPulled: sendComplete,
        );
        // Inzwischen neu gekoppelt oder ein anderer Lauf war schneller: die
        // Seite gehört nicht mehr hierher. Kein Fehler, nichts festhalten.
        if (!applied) return _Outcome.wait;
        changed = changed || _hasRows(page);
        if (!page.more) break;
        since = page.next;
      }
      _pulledAll = true;
      if (!sendComplete) {
        await _syncState.setResult(
          at: _clock.now(),
          error: ServerFailure.server.name,
          blocked: false,
        );
        return _Outcome.retry;
      }
      await _syncState.setResult(at: _clock.now(), blocked: false);
      return _Outcome.done;
    } on ServerException catch (e) {
      return _record(e.failure.name);
    } catch (e) {
      // Eine Seite ließ sich nicht einspielen. Der Cursor steht noch davor.
      return _recordLocal(e);
    } finally {
      if (changed && !_disposed) {
        try {
          _onChanged();
        } catch (_) {
          // Wer zuhört, darf den Lauf nicht scheitern lassen.
        }
      }
    }
  }

  static bool _hasRows(PullResponse p) =>
      p.business != null ||
      p.categories.isNotEmpty ||
      p.items.isNotEmpty ||
      p.templates.isNotEmpty ||
      p.staff.isNotEmpty;

  /// Lädt fehlende Bilder. Ein neues Bild lässt die Kassa den Katalog neu
  /// lesen.
  Future<void> _loadFiles(String token) async {
    final files = _files;
    if (files == null || _disposed) return;
    try {
      if (await files.run(token) && !_disposed) _onChanged();
    } catch (_) {
      // Bilder sind nie der Grund, einen guten Lauf scheitern zu lassen.
    }
  }

  /// Ein Fehler am Tablet selbst. Nur die Art des Fehlers geht ins
  /// Protokoll, und nur beim Entwickeln: nie der Schlüssel oder eine Antwort.
  Future<_Outcome> _recordLocal(Object error) {
    if (kDebugMode) {
      debugPrint('Abgleich: Fehler am Tablet (${error.runtimeType})');
    }
    return _record(localError);
  }

  /// Hält den Fehler fest. `blocked` geht auch als Fehler ein, damit
  /// "Zuletzt abgeglichen" nicht weiterrückt.
  Future<_Outcome> _record(String error) async {
    final blocked = error == ServerFailure.blocked.name;
    try {
      await _syncState.setResult(
        at: _clock.now(),
        error: error,
        blocked: blocked ? true : null,
      );
    } catch (_) {
      // Nicht einmal das Festhalten geht: der nächste Lauf versucht es.
    }
    if (blocked || error == ServerFailure.unauthorized.name) {
      return _Outcome.wait;
    }
    return _Outcome.retry;
  }

  void _setRunning(bool value) {
    if (!_running.isClosed) _running.add(value);
  }
}
