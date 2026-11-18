// Der Ablauf "Mit Code koppeln": Code tippen, koppeln, Speisekarte laden,
// auf einen Mitarbeiter warten. Der Bildschirm (`PairingView`) zeigt nur
// den Zustand. Der Schlüssel der Kassa erscheint hier nie.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_sync_providers.dart';
import '../../data/providers.dart';
import '../../data/sync_state_repository.dart';
import '../../sync/pairing_service.dart';
import '../../sync/server_api.dart';

enum PairingStep {
  /// Code wird getippt (oder der Weg ist noch nicht begonnen).
  idle,

  /// Der Code wird beim Server geprüft.
  checking,

  /// Gekoppelt, die Speisekarte wird geladen.
  loading,

  /// Gekoppelt, aber das Laden ist gescheitert. Es geht ohne neuen Code weiter.
  loadFailed,

  /// Alles geladen, der Betrieb hat aber noch keinen Chef (Mitarbeiter mit
  /// PIN und der Rolle Chef).
  noStaff,

  /// Das Tablet hat schon einen Chef, der Betrieb am Server keinen. Nichts
  /// wurde ersetzt: die Kassa arbeitet mit dem alten Stand weiter.
  noChefOnServer,

  /// Alles geladen und es gibt einen Chef: die Anmeldung folgt.
  done,
}

class PairingState {
  const PairingState({
    this.step = PairingStep.idle,
    this.code = '',
    this.failure,
    this.businessName,
    this.registerName,
    this.busy = false,
  });

  final PairingStep step;
  final String code;

  /// Der letzte Fehler beim Koppeln, nur im Schritt [PairingStep.idle].
  final ServerFailure? failure;
  final String? businessName;
  final String? registerName;

  /// "Nochmal prüfen" läuft.
  final bool busy;

  PairingState copyWith({
    PairingStep? step,
    String? code,
    ServerFailure? failure,
    bool clearFailure = false,
    String? businessName,
    String? registerName,
    bool? busy,
  }) => PairingState(
    step: step ?? this.step,
    code: code ?? this.code,
    failure: clearFailure ? null : failure ?? this.failure,
    businessName: businessName ?? this.businessName,
    registerName: registerName ?? this.registerName,
    busy: busy ?? this.busy,
  );
}

final pairingControllerProvider =
    NotifierProvider.autoDispose<PairingController, PairingState>(
      PairingController.new,
    );

class PairingController extends Notifier<PairingState> {
  static const codeLength = 8;

  @override
  PairingState build() => const PairingState();

  bool get _locked => state.step != PairingStep.idle;

  /// Eine Taste des Zahlenfelds: `'0'` bis `'9'` oder `'back'`.
  void key(String key) {
    if (_locked) return;
    if (key == 'back') {
      if (state.code.isEmpty && state.failure == null) return;
      state = state.copyWith(
        code: state.code.isEmpty
            ? ''
            : state.code.substring(0, state.code.length - 1),
        clearFailure: true,
      );
      return;
    }
    if (key.length != 1 || !'0123456789'.contains(key)) return;
    if (state.code.length >= codeLength) return;
    state = state.copyWith(code: state.code + key, clearFailure: true);
  }

  /// Zurück zur Eingabe (zum Beispiel, wenn der Schlüssel nicht mehr gilt).
  void restart() => state = const PairingState();

  Future<void> submit() async {
    if (_locked || state.code.length != codeLength) return;
    final code = state.code;
    state = state.copyWith(step: PairingStep.checking, clearFailure: true);
    try {
      final r = await ref.read(pairingServiceProvider).pair(code);
      if (!ref.mounted) return;
      state = PairingState(
        step: PairingStep.loading,
        businessName: r.businessName,
        registerName: r.registerName,
      );
    } on ServerException catch (e) {
      if (!ref.mounted) return;
      state = PairingState(failure: e.failure);
      return;
    } catch (_) {
      if (!ref.mounted) return;
      state = const PairingState(failure: ServerFailure.server);
      return;
    }
    await _load();
  }

  /// "Nochmal versuchen": ohne neuen Code.
  Future<void> retry() async {
    if (state.step != PairingStep.loadFailed) return;
    state = state.copyWith(step: PairingStep.loading);
    await _load();
  }

  /// Start der App mit einer Kassa ohne Speisekarte ([hasRegister], aber
  /// nicht [initialPullDone]) lädt weiter. Eine Kassa mit Daten, aber ohne
  /// Mitarbeiter wartet auf einen.
  Future<void> resume(SyncState sync) async {
    if (state.step != PairingStep.idle || !sync.hasRegister) return;
    if (sync.initialPullDone) {
      state = PairingState(
        step: PairingStep.noStaff,
        registerName: sync.registerName,
      );
      return;
    }
    state = PairingState(
      step: PairingStep.loading,
      registerName: sync.registerName,
    );
    await _load();
  }

  Future<void> _load() async {
    try {
      await ref.read(pairingServiceProvider).loadInitial();
    } on NoChefOnServerException {
      if (ref.mounted) {
        state = state.copyWith(step: PairingStep.noChefOnServer, busy: false);
      }
      return;
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(step: PairingStep.loadFailed, busy: false);
      }
      return;
    }
    await _afterLoad();
  }

  Future<void> _afterLoad() async {
    final bool anyone;
    try {
      anyone = (await ref.read(staffRepositoryProvider).all()).any(
        (s) => s.isChef,
      );
    } catch (_) {
      if (ref.mounted) state = state.copyWith(step: PairingStep.loadFailed);
      return;
    }
    if (!ref.mounted) return;
    state = state.copyWith(
      step: anyone ? PairingStep.done : PairingStep.noStaff,
      busy: false,
    );
  }

  /// "Nochmal prüfen": holt Neues vom Server. Ist jetzt ein Mitarbeiter da,
  /// schaltet die Einrichtung von selbst weiter. Fehlte dem Server der Chef,
  /// ist noch nichts geladen: dann lädt es von vorn (`syncNow` tut vor dem
  /// ersten Laden nichts).
  Future<void> recheck() async {
    if (state.busy) return;
    if (state.step == PairingStep.noChefOnServer) {
      state = state.copyWith(busy: true);
      await _load();
      return;
    }
    if (state.step != PairingStep.noStaff) return;
    state = state.copyWith(busy: true);
    await ref.read(syncServiceProvider).syncNow();
    if (!ref.mounted) return;
    await _afterLoad();
  }
}
