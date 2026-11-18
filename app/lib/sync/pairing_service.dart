// Koppeln mit dem Server und das erste Holen der Daten des Betriebs.
//
// Koppeln und Laden sind zwei Schritte: Nach `pair` hat die Kassa ihren
// Schlüssel, die Speisekarte ist aber noch die alte. `loadInitial` holt alles
// in den Speicher und spielt es erst ein, wenn die letzte Seite da ist. Bricht
// das Internet dazwischen ab, bleibt das Tablet wie es war, und `loadInitial`
// lässt sich ohne neuen Code wiederholen.

import '../core/clock.dart';
import '../data/sync_state_repository.dart';
import 'server_api.dart';
import 'server_changes.dart';
import 'token_store.dart';
import 'wire.dart';

class PairingService {
  PairingService({
    required this._api,
    required this._tokens,
    required this._syncState,
    required this._changes,
    required this._clock,
    required this._onCatalogReplaced,
    this._deviceModel,
  });

  final ServerApi _api;
  final TokenStore _tokens;
  final SyncStateRepository _syncState;
  final ServerChanges _changes;
  final Clock _clock;
  final void Function() _onCatalogReplaced;
  final String? _deviceModel;

  /// Koppelt mit [code]. War das Tablet schon gekoppelt, geht die Kennung
  /// des bisherigen Betriebs mit. Wirft [ServerException].
  Future<PairResponse> pair(String code) async {
    final state = await _syncState.current();
    final r = await _api.pair(
      code: code,
      previousBusinessId: state.businessId,
      deviceModel: _deviceModel,
    );
    // Nie ein neuer Schlüssel neben dem alten Stand: ein Abgleich dazwischen
    // holte sonst mit dem neuen Schlüssel ab dem alten Cursor. Darum zuerst
    // den alten Schlüssel weg, dann die Kassa (sie ist damit nicht mehr
    // gekoppelt, kein Abgleich läuft), erst zuletzt der neue Schlüssel.
    // Bricht etwas dazwischen ab, fehlt der Schlüssel, und das Tablet
    // verlangt ein neues Koppeln.
    await _tokens.clear();
    await _syncState.saveRegister(
      registerId: r.registerId,
      registerName: r.registerName,
      businessId: r.businessId,
    );
    await _tokens.write(r.token);
    return r;
  }

  /// Holt alle Seiten ab dem Anfang und ersetzt damit Speisekarte,
  /// Mitarbeiter und Betriebsdaten. Danach ist niemand mehr angemeldet.
  /// Wirft [ServerException], dann ist am Tablet nichts geändert.
  Future<void> loadInitial() async {
    final token = await _tokens.read();
    if (token == null) throw const ServerException(ServerFailure.unauthorized);
    final pages = <PullResponse>[];
    var since = 0;
    while (true) {
      final page = await _api.pull(token: token, since: since);
      pages.add(page);
      if (!page.more) break;
      // Eine Seite, die nicht weiterführt, ergäbe eine endlose Schleife.
      if (page.next <= since) {
        throw const ServerException(ServerFailure.server);
      }
      since = page.next;
    }
    await _changes.replaceAll(pages, at: _clock.now());
    _onCatalogReplaced();
  }
}
