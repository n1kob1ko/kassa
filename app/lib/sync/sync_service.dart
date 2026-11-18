// Holt im Hintergrund die Änderungen vom Server. Kein Bildschirm wartet
// darauf: die Kassa arbeitet mit dem, was sie hat, und der Ausgang des
// letzten Versuchs steht im `SyncState`.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/clock.dart';
import '../data/sync_state_repository.dart';
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
    required this._clock,
    this._internet = const Stream.empty(),
    this._resumed = const Stream.empty(),
    this._enabled = true,
    this._onChanged = _nothing,
  });

  static void _nothing() {}

  /// Abstand der regelmäßigen Läufe.
  static const interval = Duration(minutes: 5);

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
  final Clock _clock;
  final Stream<bool> _internet;
  final Stream<void> _resumed;
  final bool _enabled;

  /// Nach einem Lauf, der Daten am Tablet geändert hat.
  final void Function() _onChanged;

  final _running = StreamController<bool>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  Future<void>? _current;
  Timer? _timer;
  int _failures = 0;
  bool? _online;
  bool _started = false;
  bool _disposed = false;

  /// `true`, solange ein Lauf läuft.
  Stream<bool> get running => _running.stream;

  /// Holt alle Änderungen seit dem Cursor. Ohne Kassa, vor dem ersten Laden
  /// oder ohne Adresse des Servers tut es nichts. Läuft schon ein Lauf,
  /// wartet der Aufruf auf diesen. Wirft nie.
  Future<void> syncNow() =>
      _current ??= _runAndSchedule().whenComplete(() => _current = null);

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
      return await _pull(state.pullCursor, state.registerId!);
    } finally {
      _setRunning(false);
    }
  }

  Future<_Outcome> _pull(int cursor, String registerId) async {
    final String? token;
    try {
      token = await _tokens.read();
    } catch (e) {
      return _recordLocal(e);
    }
    // Daten wiederhergestellt, geschützter Speicher leer: wie ein
    // ungültiger Schlüssel.
    if (token == null) return _record(ServerFailure.unauthorized.name);
    var changed = false;
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
        );
        // Inzwischen neu gekoppelt oder ein anderer Lauf war schneller: die
        // Seite gehört nicht mehr hierher. Kein Fehler, nichts festhalten.
        if (!applied) return _Outcome.wait;
        changed = changed || _hasRows(page);
        if (!page.more) break;
        since = page.next;
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
