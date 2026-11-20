import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/rksv/online/atrust_client.dart';
import 'package:kassa/rksv/online/atrust_session_keeper.dart';
import 'package:kassa/rksv/online/online_signature_unit.dart';
import 'package:kassa/rksv/rksv_secrets.dart';

import '../../support/fake_atrust.dart';

const _login = 'PUT /Session/u123456789';
const _liveLogin = 'PUT /Session/u-beispiel';
const _creds = AtrustCredentials('u-beispiel', 'geheim-beispiel');

class _Rig {
  final fake = FakeAtrust();
  final secrets = MemoryRksvSecrets();
  final clock = FixedClock(DateTime(2026, 11, 19, 10));
  late final AtrustSessionKeeper keeper = make();

  /// Ein neuer Halter auf demselben Speicher, wie nach einem Neustart.
  /// Der Halter des Testsystems mit dem öffentlichen Test-Benutzer.
  AtrustSessionKeeper make() => AtrustSessionKeeper(
    client: AtrustClient(fake.client, AtrustSystem.test),
    credentials: () async =>
        const AtrustCredentials(atrustTestUser, atrustTestPassword),
    secrets: secrets,
    clock: clock,
  );

  /// Ein Halter wie der des echten Systems: Zugangsdaten aus dem Speicher,
  /// Kennzeichen `live`. Der Fake antwortet am Pfad beider Systeme.
  AtrustSessionKeeper makeLive() => AtrustSessionKeeper(
    client: AtrustClient(fake.client, AtrustSystem.test),
    credentials: secrets.atrustCredentials,
    secrets: secrets,
    clock: clock,
    live: true,
  );

  /// Lesezugriffe auf die Zugangsdaten, die der Test selbst beendet.
  final List<Completer<AtrustCredentials?>> reads = [];

  /// Ein Halter wie der des echten Systems, dessen Lesen der Zugangsdaten
  /// erst endet, wenn der Test das Element in [reads] beendet.
  AtrustSessionKeeper makeHeldReads() => AtrustSessionKeeper(
    client: AtrustClient(fake.client, AtrustSystem.test),
    credentials: () {
      final read = Completer<AtrustCredentials?>();
      reads.add(read);
      return read.future;
    },
    secrets: secrets,
    clock: clock,
    live: true,
  );

  int get logins => fake.requests.where((r) => r == _login).length;

  Future<AtrustProblem> problem([AtrustSessionKeeper? k]) async {
    try {
      await (k ?? keeper).session();
    } on AtrustException catch (e) {
      return e.problem;
    }
    fail('keine AtrustException');
  }
}

/// session() in fake_async: das Ergebnis oder der Fehler, sobald da.
(List<AtrustSession>, List<Object>) _start(AtrustSessionKeeper k) {
  final sessions = <AtrustSession>[];
  final errors = <Object>[];
  k.session().then(sessions.add, onError: errors.add);
  return (sessions, errors);
}

void main() {
  late _Rig rig;
  setUp(() async {
    rig = _Rig();
    await rig.keeper.restore();
  });

  test('erste session() meldet an, zweite nicht', () async {
    final a = await rig.keeper.session();
    final b = await rig.keeper.session();
    expect(identical(a, b), isTrue);
    expect(rig.fake.requests, [_login]);
  });

  test(
    'Review Focus 2: zwei gleichzeitige session() ergeben ein PUT',
    () async {
      final both = await Future.wait([
        rig.keeper.session(),
        rig.keeper.session(),
      ]);
      expect(identical(both[0], both[1]), isTrue);
      expect(rig.fake.requests, [_login]);
    },
  );

  test('Bon und warmUp zugleich ergeben ein PUT', () async {
    rig.keeper.warmUp();
    await rig.keeper.session();
    rig.keeper.warmUp();
    await pumpEventQueue();
    expect(rig.fake.requests, [_login]);
  });

  test(
    'warmUp meldet im Hintergrund an, session() findet die Sitzung vor',
    () async {
      rig.keeper.warmUp();
      await pumpEventQueue();
      expect(rig.fake.requests, [_login]);
      await rig.keeper.session();
      expect(rig.fake.requests, [_login]);
    },
  );

  group('P7', () {
    test('nach 54 Minuten ohne used keine neue Anmeldung', () async {
      await rig.keeper.session();
      rig.clock.value = DateTime(2026, 11, 19, 10, 54);
      await rig.keeper.session();
      expect(rig.logins, 1);
    });

    test('nach 55 Minuten ohne used neue Anmeldung', () async {
      final first = await rig.keeper.session();
      rig.clock.value = DateTime(2026, 11, 19, 10, 55);
      final second = await rig.keeper.session();
      expect(rig.logins, 2);
      expect(identical(first, second), isFalse);
    });

    test('Sitzung von gestern: used nach Mitternacht hilft nicht', () async {
      rig.clock.value = DateTime(2026, 11, 19, 23, 59);
      final s = await rig.keeper.session();
      rig.clock.value = DateTime(2026, 11, 20, 0, 0, 1);
      rig.keeper.used(s);
      final t = await rig.keeper.session();
      expect(rig.logins, 2);
      expect(identical(s, t), isFalse);
    });

    test('neuer Kalendertag: neue Anmeldung, auch nach 15 Minuten', () async {
      rig.clock.value = DateTime(2026, 11, 19, 23, 50);
      await rig.keeper.session();
      rig.clock.value = DateTime(2026, 11, 19, 23, 59);
      await rig.keeper.session();
      expect(rig.logins, 1);
      rig.clock.value = DateTime(2026, 11, 20, 0, 5);
      await rig.keeper.session();
      expect(rig.logins, 2);
    });

    test('used verlängert um 55 Minuten', () async {
      final s = await rig.keeper.session();
      rig.clock.value = DateTime(2026, 11, 19, 10, 50);
      rig.keeper.used(s);
      rig.clock.value = DateTime(2026, 11, 19, 11, 44);
      await rig.keeper.session();
      expect(rig.logins, 1);
      rig.clock.value = DateTime(2026, 11, 19, 11, 45);
      await rig.keeper.session();
      expect(rig.logins, 2);
    });

    test('used mit einer alten Sitzung verlängert die neue nicht', () async {
      final old = await rig.keeper.session();
      rig.keeper.drop(old);
      await rig.keeper.session(); // neu, 10:00
      rig.clock.value = DateTime(2026, 11, 19, 10, 50);
      rig.keeper.used(old);
      rig.clock.value = DateTime(2026, 11, 19, 10, 55);
      await rig.keeper.session();
      expect(rig.logins, 3);
    });
  });

  test('drop: die nächste session() meldet neu an', () async {
    final s = await rig.keeper.session();
    rig.keeper.drop(s);
    final t = await rig.keeper.session();
    expect(identical(s, t), isFalse);
    expect(rig.fake.requests, [_login, _login]);
  });

  group('abgelehnt', () {
    for (final status in [401, 403]) {
      test('$status setzt rejected, danach keine Anfrage mehr', () async {
        var notified = 0;
        rig.keeper.rejected.addListener(() => notified++);
        rig.fake.loginStatus = status;
        expect(await rig.problem(), AtrustProblem.rejected);
        expect(rig.keeper.rejected.value, isTrue);
        expect(notified, 1);
        await pumpEventQueue();
        expect(await rig.secrets.atrustRejected(), isTrue);

        rig.fake.loginStatus = 200;
        expect(await rig.problem(), AtrustProblem.rejected);
        rig.keeper.warmUp();
        await pumpEventQueue();
        expect(rig.fake.requests, [_login]);
      });
    }

    test('session() wartet nicht auf das Speichern', () async {
      rig.secrets.hangWrites = true;
      rig.fake.loginStatus = 403;
      expect(await rig.problem(), AtrustProblem.rejected);
      expect(rig.keeper.rejected.value, isTrue);
    });

    test(
      'nach Neustart mit gespeichertem Kennzeichen: keine Anfrage',
      () async {
        await rig.secrets.writeAtrustRejected(true);
        final k = rig.make();
        await k.restore();
        expect(k.rejected.value, isTrue);
        expect(await rig.problem(k), AtrustProblem.rejected);
        k.warmUp();
        await pumpEventQueue();
        expect(rig.fake.requests, isEmpty);
      },
    );

    test('session() vor restore() liest das Kennzeichen trotzdem', () async {
      await rig.secrets.writeAtrustRejected(true);
      final k = rig.make();
      expect(await rig.problem(k), AtrustProblem.rejected);
      k.warmUp();
      await pumpEventQueue();
      expect(rig.fake.requests, isEmpty);
    });

    test('R2: ein zweites restore() liest nicht noch einmal', () async {
      await rig.secrets.writeAtrustRejected(true);
      final k = rig.make();
      await k.restore();
      await rig.secrets.writeAtrustRejected(false);
      await k.restore();
      expect(k.rejected.value, isTrue);
      expect(rig.fake.requests, isEmpty);
    });

    test('nicht lesbarer Speicher: kein Netz, später neuer Versuch', () async {
      final k = rig.make();
      rig.secrets.failReads = true;
      await expectLater(k.restore(), throwsA(anything));
      await expectLater(k.session(), throwsA(anything));
      k.warmUp();
      await pumpEventQueue();
      expect(rig.fake.requests, isEmpty);
      rig.secrets.failReads = false;
      await k.restore();
      await k.session();
      expect(rig.fake.requests, [_login]);
    });

    test('allowOneLogin erlaubt genau eine Anmeldung', () async {
      rig.fake.loginStatus = 401;
      expect(await rig.problem(), AtrustProblem.rejected);
      await rig.keeper.allowOneLogin();
      expect(rig.keeper.rejected.value, isFalse);
      expect(await rig.secrets.atrustRejected(), isFalse);
      expect(await rig.problem(), AtrustProblem.rejected);
      expect(await rig.problem(), AtrustProblem.rejected);
      rig.keeper.warmUp();
      await pumpEventQueue();
      expect(rig.fake.requests, [_login, _login]);
      expect(rig.keeper.rejected.value, isTrue);
    });

    test('allowOneLogin, dann gelingt die Anmeldung', () async {
      rig.fake.loginStatus = 403;
      expect(await rig.problem(), AtrustProblem.rejected);
      rig.fake.loginStatus = 200;
      await rig.keeper.allowOneLogin();
      await rig.keeper.session();
      expect(rig.keeper.rejected.value, isFalse);
      expect(rig.fake.requests, [_login, _login]);
    });
  });

  test(
    'offline setzt rejected nicht, der nächste Aufruf versucht es neu',
    () async {
      rig.fake.offline = true;
      expect(await rig.problem(), AtrustProblem.noInternet);
      expect(rig.keeper.rejected.value, isFalse);
      await pumpEventQueue();
      expect(await rig.secrets.atrustRejected(), isFalse);
      rig.fake.offline = false;
      await rig.keeper.session();
      expect(rig.fake.requests, [_login, _login]);
    },
  );

  test(
    'gescheiterte geteilte Anmeldung: alle bekommen denselben Fehler',
    () async {
      rig.fake.loginStatus = 500;
      final errors = <Object>[];
      await Future.wait([
        rig.keeper.session().then<void>((_) {}, onError: errors.add),
        rig.keeper.session().then<void>((_) {}, onError: errors.add),
      ]);
      expect(errors, hasLength(2));
      expect(identical(errors[0], errors[1]), isTrue);
      expect((errors[0] as AtrustException).problem, AtrustProblem.server);
      expect(rig.fake.requests, [_login]);
      rig.fake.loginStatus = 200;
      await rig.keeper.session();
      expect(rig.fake.requests, [_login, _login]);
    },
  );

  group('warmUp wirft nie', () {
    test('offline', () async {
      rig.fake.offline = true;
      rig.keeper.warmUp();
      await pumpEventQueue();
      expect(rig.fake.requests, [_login]);
    });

    test('500', () async {
      rig.fake.loginStatus = 500;
      rig.keeper.warmUp();
      await pumpEventQueue();
      expect(rig.fake.requests, [_login]);
    });

    test('abgelehnt', () async {
      rig.fake.loginStatus = 401;
      rig.keeper.warmUp();
      await pumpEventQueue();
      expect(rig.keeper.rejected.value, isTrue);
      rig.keeper.warmUp();
      await pumpEventQueue();
      expect(rig.fake.requests, [_login]);
    });
  });

  group('Anmeldung ohne Antwort', () {
    const hang = Duration(minutes: 10);

    /// session() in fake_async: das Ergebnis oder der Fehler, sobald da.
    (List<AtrustSession>, List<Object>) start(AtrustSessionKeeper k) {
      final sessions = <AtrustSession>[];
      final errors = <Object>[];
      k.session().then(sessions.add, onError: errors.add);
      return (sessions, errors);
    }

    test('loginLimit ist 20 Sekunden wie ConnectionCheck.timeLimit', () {
      expect(AtrustSessionKeeper.loginLimit, const Duration(seconds: 20));
    });

    test('Q13: nach loginLimit noInternet, dann schickt eine neue session() '
        'erst nach abandonedLimit ein zweites PUT und bekommt eine Sitzung, '
        'sobald A-Trust wieder antwortet', () {
      fakeAsync((async) {
        rig.fake.delay = hang;
        final (firstOk, firstErrors) = start(rig.keeper);
        async.elapse(
          AtrustSessionKeeper.loginLimit - const Duration(milliseconds: 1),
        );
        expect(firstErrors, isEmpty);
        async.elapse(const Duration(milliseconds: 1));
        expect(firstOk, isEmpty);
        expect(firstErrors, hasLength(1));
        expect(
          (firstErrors.single as AtrustException).problem,
          AtrustProblem.noInternet,
        );
        expect(rig.fake.requests, [_login]);

        rig.fake.delay = Duration.zero;
        rig.clock.value = rig.clock.value.add(
          AtrustSessionKeeper.abandonedLimit,
        );
        final (secondOk, secondErrors) = start(rig.keeper);
        async.flushMicrotasks();
        expect(secondErrors, isEmpty);
        expect(secondOk, hasLength(1));
        expect(rig.fake.requests, [_login, _login]);
        expect(rig.keeper.rejected.value, isFalse);
      });
    });

    test('die späte 401 der aufgegebenen Anmeldung setzt rejected, danach '
        'keine Anfrage mehr', () {
      fakeAsync((async) {
        rig.fake.delay = hang;
        rig.fake.loginStatus = 401;
        final (_, errors) = start(rig.keeper);
        async.elapse(AtrustSessionKeeper.loginLimit);
        expect(
          (errors.single as AtrustException).problem,
          AtrustProblem.noInternet,
        );
        expect(rig.keeper.rejected.value, isFalse);

        async.elapse(hang);
        expect(rig.keeper.rejected.value, isTrue);
        bool? stored;
        rig.secrets.atrustRejected().then((v) => stored = v);
        async.flushMicrotasks();
        expect(stored, isTrue);

        rig.fake.delay = Duration.zero;
        rig.fake.loginStatus = 200;
        final (ok, later) = start(rig.keeper);
        rig.keeper.warmUp();
        async.flushMicrotasks();
        expect(ok, isEmpty);
        expect(
          (later.single as AtrustException).problem,
          AtrustProblem.rejected,
        );
        expect(rig.fake.requests, [_login]);
      });
    });

    test('die späte 200 gilt, wenn der Halter keine Sitzung hat', () {
      fakeAsync((async) {
        rig.fake.delay = hang;
        start(rig.keeper);
        async.elapse(AtrustSessionKeeper.loginLimit);
        async.elapse(hang);

        rig.fake.delay = Duration.zero;
        final (ok, errors) = start(rig.keeper);
        async.flushMicrotasks();
        expect(errors, isEmpty);
        expect(ok, hasLength(1));
        expect(rig.fake.requests, [_login]);
      });
    });

    test('die späte 200 fällt weg, wenn der Halter schon eine Sitzung hat', () {
      fakeAsync((async) {
        rig.fake.delay = hang;
        start(rig.keeper);
        async.elapse(AtrustSessionKeeper.loginLimit);

        rig.fake.delay = Duration.zero;
        rig.clock.value = rig.clock.value.add(
          AtrustSessionKeeper.abandonedLimit,
        );
        final (second, _) = start(rig.keeper);
        async.flushMicrotasks();
        expect(second, hasLength(1));

        async.elapse(hang); // die erste Anmeldung antwortet jetzt
        final (third, _) = start(rig.keeper);
        async.flushMicrotasks();
        expect(identical(third.single, second.single), isTrue);
        expect(rig.fake.requests, [_login, _login]);
      });
    });

    test('ein später anderer Fehler ändert nichts', () {
      fakeAsync((async) {
        rig.fake.delay = hang;
        rig.fake.loginStatus = 500;
        start(rig.keeper);
        async.elapse(AtrustSessionKeeper.loginLimit);
        async.elapse(hang);
        expect(rig.keeper.rejected.value, isFalse);

        rig.fake.delay = Duration.zero;
        rig.fake.loginStatus = 200;
        final (ok, errors) = start(rig.keeper);
        async.flushMicrotasks();
        expect(errors, isEmpty);
        expect(ok, hasLength(1));
        expect(rig.fake.requests, [_login, _login]);
      });
    });

    test('zwei Aufrufer während einer hängenden Anmeldung: genau eine '
        'Anfrage, beide bekommen den Fehler', () {
      fakeAsync((async) {
        rig.fake.delay = hang;
        final (_, a) = start(rig.keeper);
        async.elapse(const Duration(seconds: 5));
        final (_, b) = start(rig.keeper);
        rig.keeper.warmUp();
        async.elapse(const Duration(seconds: 5));
        expect(rig.fake.requests, [_login]);
        async.elapse(AtrustSessionKeeper.loginLimit);
        expect(a, hasLength(1));
        expect(b, hasLength(1));
        expect(rig.fake.requests, [_login]);
      });
    });
  });

  group('Halter echt: Zugangsdaten aus dem geschützten Speicher', () {
    test(
      'ohne Zugangsdaten: noCredentials, keine Anfrage, nicht abgelehnt',
      () async {
        final k = rig.makeLive();
        await k.restore();
        expect(await rig.problem(k), AtrustProblem.noCredentials);
        expect(
          const AtrustException(AtrustProblem.noCredentials).sentence,
          'Die Zugangsdaten von A-Trust fehlen.',
        );
        k.warmUp();
        await pumpEventQueue();
        expect(rig.fake.requests, isEmpty);
        expect(k.rejected.value, isFalse);
        expect(await rig.secrets.atrustRejected(live: true), isFalse);
      },
    );

    test('mit Zugangsdaten genau ein PUT mit diesen', () async {
      rig.fake.password = 'geheim-beispiel';
      await rig.secrets.writeAtrustCredentials(_creds);
      final k = rig.makeLive();
      await k.restore();
      await k.session();
      await k.session();
      expect(rig.fake.requests, [_liveLogin]);
      expect(k.rejected.value, isFalse);
    });

    test('401 setzt nur das Kennzeichen live', () async {
      rig.fake.loginStatus = 401;
      await rig.secrets.writeAtrustCredentials(_creds);
      final k = rig.makeLive();
      expect(await rig.problem(k), AtrustProblem.rejected);
      await pumpEventQueue();
      expect(await rig.secrets.atrustRejected(live: true), isTrue);
      expect(await rig.secrets.atrustRejected(), isFalse);
      expect(rig.keeper.rejected.value, isFalse);
      rig.fake.loginStatus = 200;
      await rig.keeper.session();
      expect(rig.fake.requests, [_liveLogin, _login]);
    });

    test('401 am Testsystem setzt nur dessen Kennzeichen', () async {
      rig.fake.loginStatus = 401;
      expect(await rig.problem(), AtrustProblem.rejected);
      await pumpEventQueue();
      expect(await rig.secrets.atrustRejected(), isTrue);
      expect(await rig.secrets.atrustRejected(live: true), isFalse);
      rig.fake.loginStatus = 200;
      await rig.secrets.writeAtrustCredentials(_creds);
      final k = rig.makeLive();
      await k.restore();
      expect(k.rejected.value, isFalse);
      await k.session();
      expect(rig.fake.requests, [_login, _liveLogin]);
    });

    test('Review Focus 2: neue Zugangsdaten und forget(): PUT mit den neuen, '
        'die alte Sitzung wird nicht mehr ausgegeben', () async {
      await rig.secrets.writeAtrustCredentials(
        const AtrustCredentials('u-alt', 'geheim-alt'),
      );
      final k = rig.makeLive();
      await k.restore();
      final old = await k.session();
      expect(identical(await k.session(), old), isTrue);

      await rig.secrets.writeAtrustCredentials(_creds);
      rig.fake.password = 'geheim-beispiel';
      k.forget();
      expect(rig.fake.requests, ['PUT /Session/u-alt']);
      final fresh = await k.session();
      expect(identical(fresh, old), isFalse);
      expect(rig.fake.requests, ['PUT /Session/u-alt', _liveLogin]);

      k.used(old);
      expect(identical(await k.session(), fresh), isTrue);
      expect(rig.fake.requests, ['PUT /Session/u-alt', _liveLogin]);
    });

    test('forget() während einer Anmeldung mit den alten Zugangsdaten: die '
        'nächste session() meldet mit den neuen an, die alte Antwort wird '
        'nicht gehalten', () {
      fakeAsync((async) {
        rig.fake.holdLogins = true;
        rig.secrets.writeAtrustCredentials(
          const AtrustCredentials('u-alt', 'geheim-alt'),
        );
        async.flushMicrotasks();
        final k = rig.makeLive();
        final (oldOk, _) = _start(k);
        async.flushMicrotasks();
        expect(rig.fake.requests, ['PUT /Session/u-alt']);

        rig.secrets.writeAtrustCredentials(_creds);
        async.flushMicrotasks();
        k.forget();
        final (newOk, _) = _start(k);
        async.flushMicrotasks();
        expect(rig.fake.requests, ['PUT /Session/u-alt', _liveLogin]);

        rig.fake.heldLogins[0].complete(200);
        async.flushMicrotasks();
        expect(oldOk, hasLength(1));
        final (laterOk, _) = _start(k);
        async.flushMicrotasks();
        expect(laterOk, isEmpty);

        rig.fake.heldLogins[1].complete(200);
        async.flushMicrotasks();
        expect(newOk, hasLength(1));
        expect(identical(laterOk.single, newOk.single), isTrue);
        expect(identical(newOk.single, oldOk.single), isFalse);
        expect(rig.fake.requests, hasLength(2));
      });
    });

    test('eine späte 401 mit den alten Zugangsdaten nach forget() setzt '
        'abgelehnt nicht', () {
      fakeAsync((async) {
        rig.fake.holdLogins = true;
        rig.secrets.writeAtrustCredentials(
          const AtrustCredentials('u-alt', 'geheim-alt'),
        );
        async.flushMicrotasks();
        final k = rig.makeLive();
        final (_, oldErrors) = _start(k);
        async.flushMicrotasks();
        rig.secrets.writeAtrustCredentials(_creds);
        async.flushMicrotasks();
        k.forget();
        rig.fake.heldLogins.single.complete(401);
        async.flushMicrotasks();
        expect(
          (oldErrors.single as AtrustException).problem,
          AtrustProblem.rejected,
        );
        expect(k.rejected.value, isFalse);

        rig.fake.holdLogins = false;
        final (ok, _) = _start(k);
        async.flushMicrotasks();
        expect(ok, hasLength(1));
        expect(rig.fake.requests, ['PUT /Session/u-alt', _liveLogin]);
      });
    });

    test(
      'Review Focus 5: nach 401 keine Anfrage bei session() und warmUp(); '
      'nach Aufheben des Kennzeichens und allowOneLogin() genau ein PUT',
      () async {
        await rig.secrets.writeAtrustCredentials(_creds);
        rig.fake.loginStatus = 401;
        final k = rig.makeLive();
        await k.restore();
        expect(await rig.problem(k), AtrustProblem.rejected);
        rig.fake.loginStatus = 200;
        expect(await rig.problem(k), AtrustProblem.rejected);
        k.warmUp();
        await pumpEventQueue();
        expect(rig.fake.requests, [_liveLogin]);

        // Ein Neustart ändert nichts.
        final restarted = rig.makeLive();
        expect(await rig.problem(restarted), AtrustProblem.rejected);
        restarted.warmUp();
        await pumpEventQueue();
        expect(rig.fake.requests, [_liveLogin]);

        await rig.secrets.writeAtrustRejected(false, live: true);
        await k.allowOneLogin();
        await k.session();
        await k.session();
        k.warmUp();
        await pumpEventQueue();
        expect(rig.fake.requests, [_liveLogin, _liveLogin]);
      },
    );
  });

  group('F5: abgelehnt gilt, sobald eine Anmeldung antwortet', () {
    test('aufgegebene Anmeldung antwortet spät mit 401, während eine neue '
        'läuft; die neue antwortet 200: die Wartenden bekommen rejected, der '
        'Halter hält keine Sitzung, danach keine Anfrage', () {
      fakeAsync((async) {
        rig.fake.holdLogins = true;
        final (_, first) = _start(rig.keeper);
        async.elapse(AtrustSessionKeeper.loginLimit);
        expect(
          (first.single as AtrustException).problem,
          AtrustProblem.noInternet,
        );

        rig.clock.value = rig.clock.value.add(
          AtrustSessionKeeper.abandonedLimit,
        );
        final (ok, waiting) = _start(rig.keeper);
        async.flushMicrotasks();
        expect(rig.fake.requests, [_login, _login]);

        rig.fake.heldLogins[0].complete(401);
        async.flushMicrotasks();
        expect(rig.keeper.rejected.value, isTrue);
        expect(waiting, isEmpty);

        rig.fake.heldLogins[1].complete(200);
        async.flushMicrotasks();
        expect(ok, isEmpty);
        expect(
          (waiting.single as AtrustException).problem,
          AtrustProblem.rejected,
        );

        final (_, later) = _start(rig.keeper);
        rig.keeper.warmUp();
        async.elapse(const Duration(minutes: 5));
        expect(
          (later.single as AtrustException).problem,
          AtrustProblem.rejected,
        );
        expect(rig.fake.requests, [_login, _login]);

        // Keine Sitzung gehalten: nach dem Antippen geht eine Anmeldung los.
        rig.fake.holdLogins = false;
        rig.keeper.allowOneLogin();
        async.flushMicrotasks();
        final (after, _) = _start(rig.keeper);
        async.flushMicrotasks();
        expect(after, hasLength(1));
        expect(rig.fake.requests, [_login, _login, _login]);
      });
    });
  });

  group('Q13: aufgegebene Anmeldung ohne Antwort', () {
    test('abandonedLimit ist 120 Sekunden', () {
      expect(AtrustSessionKeeper.abandonedLimit, const Duration(seconds: 120));
    });

    test('hängt die Anmeldung, schicken session() und warmUp() 120 Sekunden '
        'lang nichts und enden sofort mit noInternet; danach genau eine neue '
        'Anmeldung', () {
      fakeAsync((async) {
        final abandonedAt = rig.clock.value;
        rig.fake.holdLogins = true;
        final (_, first) = _start(rig.keeper);
        async.elapse(AtrustSessionKeeper.loginLimit);
        expect(
          (first.single as AtrustException).problem,
          AtrustProblem.noInternet,
        );
        expect(rig.fake.requests, [_login]);

        for (final seconds in [0, 1, 60, 119]) {
          rig.clock.value = abandonedAt.add(Duration(seconds: seconds));
          final (ok, errors) = _start(rig.keeper);
          rig.keeper.warmUp();
          async.flushMicrotasks();
          expect(ok, isEmpty);
          expect(
            (errors.single as AtrustException).problem,
            AtrustProblem.noInternet,
            reason: 'nach $seconds Sekunden',
          );
        }
        expect(rig.fake.requests, [_login]);

        rig.clock.value = abandonedAt.add(AtrustSessionKeeper.abandonedLimit);
        final (_, errors) = _start(rig.keeper);
        rig.keeper.warmUp();
        async.flushMicrotasks();
        expect(errors, isEmpty);
        expect(rig.fake.requests, [_login, _login]);
      });
    });

    test('allowOneLogin() hebt die Sperre nicht auf', () {
      fakeAsync((async) {
        rig.fake.holdLogins = true;
        _start(rig.keeper);
        async.elapse(AtrustSessionKeeper.loginLimit);
        rig.keeper.allowOneLogin();
        async.flushMicrotasks();
        final (_, errors) = _start(rig.keeper);
        async.flushMicrotasks();
        expect(
          (errors.single as AtrustException).problem,
          AtrustProblem.noInternet,
        );
        expect(rig.fake.requests, [_login]);
      });
    });

    test('antwortet die hängende vorher mit 200 und der Halter hat keine '
        'Sitzung, wird sie gehalten; der nächste Bon signiert ohne neue '
        'Anmeldung', () {
      fakeAsync((async) {
        rig.fake.holdLogins = true;
        _start(rig.keeper);
        async.elapse(AtrustSessionKeeper.loginLimit);
        rig.clock.value = rig.clock.value.add(const Duration(seconds: 30));
        rig.fake.heldLogins.single.complete(200);
        async.flushMicrotasks();

        final unit = OnlineSignatureUnit(
          client: AtrustClient(rig.fake.client, AtrustSystem.test),
          keeper: rig.keeper,
          zdaId: 'AT1',
          certificateDer: rig.fake.certificateDer,
        );
        Object? signature;
        unit.sign('Beispiel-Imbiss Bon 1').then((s) => signature = s);
        async.flushMicrotasks();
        expect(signature, hasLength(64));
        expect(rig.fake.requests, hasLength(2));
        expect(rig.fake.requests.first, _login);
        expect(
          rig.fake.requests.last,
          matches(r'^POST /Session/\w+/Sign/Hash$'),
        );
      });
    });

    test('antwortet die hängende mit einem Fehler, darf die nächste '
        'Anmeldung hinaus', () {
      fakeAsync((async) {
        rig.fake.holdLogins = true;
        _start(rig.keeper);
        async.elapse(AtrustSessionKeeper.loginLimit);
        rig.clock.value = rig.clock.value.add(const Duration(seconds: 30));
        rig.fake.heldLogins.single.complete(500);
        async.flushMicrotasks();
        expect(rig.keeper.rejected.value, isFalse);

        rig.fake.holdLogins = false;
        final (ok, _) = _start(rig.keeper);
        async.flushMicrotasks();
        expect(ok, hasLength(1));
        expect(rig.fake.requests, [_login, _login]);
      });
    });
  });

  group('langsames Lesen der Zugangsdaten', () {
    late AtrustSessionKeeper k;
    setUp(() => k = rig.makeHeldReads());

    /// Die Sperre nach einer aufgegebenen Anmeldung ist um.
    void afterBlock() => rig.clock.value = rig.clock.value.add(
      AtrustSessionKeeper.abandonedLimit,
    );

    test(
      'eine aufgegebene Anmeldung, deren Lesen spät endet, schickt nichts',
      () {
        fakeAsync((async) {
          final (_, errors) = _start(k);
          async.elapse(AtrustSessionKeeper.loginLimit);
          expect(
            (errors.single as AtrustException).problem,
            AtrustProblem.noInternet,
          );
          rig.reads.single.complete(_creds);
          async.elapse(const Duration(minutes: 5));
          expect(rig.fake.requests, isEmpty);
        });
      },
    );

    test(
      'mehrere wartende Lesezugriffe, zugleich beendet: höchstens ein PUT',
      () {
        fakeAsync((async) {
          for (var i = 0; i < 3; i++) {
            _start(k);
            async.elapse(AtrustSessionKeeper.loginLimit);
            afterBlock();
          }
          final (ok, _) = _start(k);
          async.flushMicrotasks();
          expect(rig.reads, hasLength(4));
          for (final read in rig.reads) {
            read.complete(_creds);
          }
          async.flushMicrotasks();
          expect(rig.fake.requests, [_liveLogin]);
          expect(ok, hasLength(1));
        });
      },
    );

    test('nach einer 401 schickt keine wartende Anmeldung mehr', () {
      fakeAsync((async) {
        rig.fake.loginStatus = 401;
        _start(k);
        async.elapse(AtrustSessionKeeper.loginLimit);
        afterBlock();
        final (_, errors) = _start(k);
        async.flushMicrotasks();
        rig.reads[1].complete(_creds);
        async.flushMicrotasks();
        expect(
          (errors.single as AtrustException).problem,
          AtrustProblem.rejected,
        );
        expect(rig.fake.requests, [_liveLogin]);

        rig.reads[0].complete(_creds);
        async.elapse(const Duration(minutes: 5));
        expect(rig.fake.requests, [_liveLogin]);
      });
    });

    test('forget() während des Lesens: die Anmeldung der alten Runde schickt '
        'nichts, die neue meldet an', () {
      fakeAsync((async) {
        final (oldOk, oldErrors) = _start(k);
        async.flushMicrotasks();
        k.forget();
        final (ok, _) = _start(k);
        async.flushMicrotasks();
        expect(rig.reads, hasLength(2));

        rig.reads[0].complete(_creds);
        async.flushMicrotasks();
        expect(rig.fake.requests, isEmpty);
        expect(oldOk, isEmpty);
        expect(oldErrors, hasLength(1));

        rig.reads[1].complete(_creds);
        async.flushMicrotasks();
        expect(rig.fake.requests, [_liveLogin]);
        expect(ok, hasLength(1));
      });
    });
  });

  group('Q14: scheiterndes Schreiben von abgelehnt', () {
    for (final trigger in ['session()', 'warmUp()', 'restore()']) {
      test('rejected gilt sofort, keine weitere Anfrage; das Schreiben wird '
          'bei $trigger wiederholt, bis es steht', () async {
        rig.secrets.failWrites = true;
        rig.fake.loginStatus = 401;
        expect(await rig.problem(), AtrustProblem.rejected);
        expect(rig.keeper.rejected.value, isTrue);
        await pumpEventQueue();

        rig.fake.loginStatus = 200;
        expect(await rig.problem(), AtrustProblem.rejected);
        rig.keeper.warmUp();
        await rig.keeper.restore();
        await pumpEventQueue();
        expect(await rig.secrets.atrustRejected(), isFalse);
        expect(rig.fake.requests, [_login]);

        rig.secrets.failWrites = false;
        switch (trigger) {
          case 'session()':
            expect(await rig.problem(), AtrustProblem.rejected);
          case 'warmUp()':
            rig.keeper.warmUp();
          case 'restore()':
            await rig.keeper.restore();
        }
        await pumpEventQueue();
        expect(await rig.secrets.atrustRejected(), isTrue);

        final restarted = rig.make();
        expect(await rig.problem(restarted), AtrustProblem.rejected);
        restarted.warmUp();
        await pumpEventQueue();
        expect(rig.fake.requests, [_login]);
      });
    }

    test('hangWrites: rejected gilt sofort, keine weitere Anfrage', () async {
      rig.secrets.hangWrites = true;
      rig.fake.loginStatus = 401;
      expect(await rig.problem(), AtrustProblem.rejected);
      expect(rig.keeper.rejected.value, isTrue);
      rig.fake.loginStatus = 200;
      expect(await rig.problem(), AtrustProblem.rejected);
      rig.keeper.warmUp();
      await pumpEventQueue();
      expect(rig.fake.requests, [_login]);
    });

    test(
      'der Halter des echten Systems schreibt das Kennzeichen live nach',
      () async {
        await rig.secrets.writeAtrustCredentials(_creds);
        rig.secrets.failWrites = true;
        rig.fake.loginStatus = 401;
        final k = rig.makeLive();
        expect(await rig.problem(k), AtrustProblem.rejected);
        await pumpEventQueue();
        rig.secrets.failWrites = false;
        expect(await rig.problem(k), AtrustProblem.rejected);
        await pumpEventQueue();
        expect(await rig.secrets.atrustRejected(live: true), isTrue);
        expect(await rig.secrets.atrustRejected(), isFalse);
      },
    );
  });

  test('toString enthält weder Passwort noch Sitzungsschlüssel', () async {
    final s = await rig.keeper.session();
    final text = rig.keeper.toString();
    expect(text, isNot(contains(atrustTestPassword)));
    expect(text, isNot(contains(s.key)));
    expect(text, isNot(contains(s.id)));
  });
}
