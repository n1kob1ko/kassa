import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/rksv/online/atrust_client.dart';
import 'package:kassa/rksv/online/atrust_session_keeper.dart';
import 'package:kassa/rksv/rksv_secrets.dart';

import '../../support/fake_atrust.dart';

const _login = 'PUT /Session/u123456789';

class _Rig {
  final fake = FakeAtrust();
  final secrets = MemoryRksvSecrets();
  final clock = FixedClock(DateTime(2026, 11, 19, 10));
  late final AtrustSessionKeeper keeper = make();

  /// Ein neuer Halter auf demselben Speicher, wie nach einem Neustart.
  AtrustSessionKeeper make() => AtrustSessionKeeper(
    client: AtrustClient(fake.client, AtrustSystem.test),
    user: atrustTestUser,
    password: atrustTestPassword,
    secrets: secrets,
    clock: clock,
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

    test('nach loginLimit gibt eine neue session() ein zweites PUT und '
        'bekommt eine Sitzung, sobald A-Trust wieder antwortet', () {
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

  test('toString enthält weder Passwort noch Sitzungsschlüssel', () async {
    final s = await rig.keeper.session();
    final text = rig.keeper.toString();
    expect(text, isNot(contains(atrustTestPassword)));
    expect(text, isNot(contains(s.key)));
    expect(text, isNot(contains(s.id)));
  });
}
