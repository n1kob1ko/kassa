import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/rksv/card/certificate.dart';
import 'package:kassa/rksv/online/atrust_client.dart';
import 'package:kassa/rksv/online/atrust_session_keeper.dart';
import 'package:kassa/rksv/online/online_signature_unit.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/signature_unit.dart';
import 'package:pointycastle/digests/sha256.dart';

import '../../support/fake_atrust.dart';

const _login = 'PUT /Session/u123456789';
const _text = '_R1-AT1_Beispiel-Imbiss-1_4711_2026-11-19T10:00:00_12,50';

Uint8List _sha256(String s) =>
    SHA256Digest().process(Uint8List.fromList(ascii.encode(s)));

class _Rig {
  _Rig() {
    keeper = AtrustSessionKeeper(
      client: client,
      credentials: () async =>
          const AtrustCredentials(atrustTestUser, atrustTestPassword),
      secrets: secrets,
      clock: clock,
    );
    unit = makeUnit();
  }

  final fake = FakeAtrust();
  final secrets = MemoryRksvSecrets();
  final clock = FixedClock(DateTime(2026, 11, 19, 10));
  late final client = AtrustClient(fake.client, AtrustSystem.test);
  late final AtrustSessionKeeper keeper;
  late final OnlineSignatureUnit unit;

  /// Eine neue Einheit am selben Halter, wie die App sie je Bon baut.
  OnlineSignatureUnit makeUnit() => OnlineSignatureUnit(
    client: client,
    keeper: keeper,
    zdaId: 'AT1',
    certificateDer: fake.certificateDer,
    issuerCertificatesDer: fake.issuersDer,
  );

  List<String> get methods => [
    for (final r in fake.requests) r.split(' ').first,
  ];

  Future<String> failure([String text = _text, OnlineSignatureUnit? u]) async {
    try {
      await (u ?? unit).sign(text);
    } on SignatureFailure catch (e) {
      return e.reason;
    }
    fail('keine SignatureFailure');
  }
}

void main() {
  late _Rig rig;
  setUp(() async {
    rig = _Rig();
    await rig.keeper.restore();
  });

  test(
    'Erfolg: 64 Bytes, die das Zertifikat gegen den Hashwert bestätigt',
    () async {
      final sig = await rig.unit.sign(_text);
      expect(sig, hasLength(64));
      expect(
        CardCertificate.parse(rig.fake.certificateDer)
            .verify(_sha256(_text), sig),
        isTrue,
      );
      expect(rig.fake.requests, hasLength(2));
      expect(rig.fake.requests.first, _login);
      expect(rig.fake.requests.last, matches(r'^POST /Session/\w+/Sign/Hash$'));
    },
  );

  test('die Anfrage enthält den Hashwert und nie den Text', () async {
    await rig.unit.sign(_text);
    final body = rig.fake.signBodies.single;
    expect(jsonDecode(body)['hash'], base64.encode(_sha256(_text)));
    expect(body, isNot(contains('Beispiel-Imbiss')));
    expect(body, isNot(contains('4711')));
  });

  test('zweiter Bon: keine neue Anmeldung', () async {
    await rig.unit.sign(_text);
    await rig.unit.sign('${_text}x');
    expect(rig.methods, ['PUT', 'POST', 'POST']);
  });

  test('Review Focus 3: abgelaufene Sitzung ergibt POST, PUT, POST', () async {
    await rig.unit.sign(_text);
    rig.fake.requests.clear();
    rig.fake.expireSessions = true;
    final sig = await rig.unit.sign(_text);
    expect(rig.methods, ['POST', 'PUT', 'POST']);
    expect(
      CardCertificate.parse(rig.fake.certificateDer)
          .verify(_sha256(_text), sig),
      isTrue,
    );
  });

  test('Q9: zwei Mal abgelaufen: A-Trust hat die Signatur abgelehnt., genau '
      'zwei POST', () async {
    await rig.unit.sign(_text);
    rig.fake.requests.clear();
    rig.fake.expireSessions = true;
    rig.fake.onRequest = (r) {
      if (r == _login) rig.fake.expireSessions = true;
    };
    expect(await rig.failure(), 'A-Trust hat die Signatur abgelehnt.');
    await pumpEventQueue();
    expect(rig.methods, ['POST', 'PUT', 'POST']);
  });

  group('Q9: Signieren antwortet immer 403', () {
    test(
      'erster Bon: POST, PUT, POST und abgelehnt; zweiter Bon: genau ein '
      'POST; neue Sitzung vom Halter: wieder ein Mal neu angemeldet',
      () async {
        await rig.unit.sign(_text);
        rig.fake.requests.clear();
        rig.fake.signStatus = 403;
        expect(
          const AtrustException(AtrustProblem.refused).sentence,
          'A-Trust hat die Signatur abgelehnt.',
        );

        expect(await rig.failure(), 'A-Trust hat die Signatur abgelehnt.');
        await pumpEventQueue();
        expect(rig.methods, ['POST', 'PUT', 'POST']);

        // Die App baut je Bon eine neue Einheit am selben Halter.
        rig.fake.requests.clear();
        expect(
          await rig.failure(_text, rig.makeUnit()),
          'A-Trust hat die Signatur abgelehnt.',
        );
        expect(await rig.failure(), 'A-Trust hat die Signatur abgelehnt.');
        await pumpEventQueue();
        expect(rig.methods, ['POST', 'POST']);
        expect(rig.keeper.rejected.value, isFalse);

        // 56 Minuten später gibt der Halter eine neue Sitzung aus.
        rig.clock.value = DateTime(2026, 11, 19, 10, 56);
        rig.fake.requests.clear();
        expect(
          await rig.failure(_text, rig.makeUnit()),
          'A-Trust hat die Signatur abgelehnt.',
        );
        await pumpEventQueue();
        expect(rig.methods, ['PUT', 'POST', 'PUT', 'POST']);

        rig.fake.requests.clear();
        expect(
          await rig.failure(_text, rig.makeUnit()),
          'A-Trust hat die Signatur abgelehnt.',
        );
        await pumpEventQueue();
        expect(rig.methods, ['POST']);
      },
    );

    test('gelingt das Signieren wieder, signiert dieselbe Sitzung', () async {
      await rig.unit.sign(_text);
      rig.fake.signStatus = 403;
      expect(await rig.failure(), 'A-Trust hat die Signatur abgelehnt.');
      rig.fake.signStatus = null;
      rig.fake.requests.clear();
      final sig = await rig.makeUnit().sign(_text);
      expect(sig, hasLength(64));
      expect(rig.methods, ['POST']);
    });
  });

  test('wrongSignature: SignatureFailure', () async {
    rig.fake.wrongSignature = true;
    expect(
      await rig.failure(),
      'Die Signatur von A-Trust passt nicht zum Zertifikat.',
    );
  });

  test(
    'offline: Kein Internet., danach genau eine Anmeldung im Hintergrund',
    () async {
      rig.fake.offline = true;
      expect(await rig.failure(), 'Kein Internet.');
      await pumpEventQueue();
      expect(rig.fake.requests, [_login, _login]);
      await pumpEventQueue();
      expect(rig.fake.requests, [_login, _login]);
    },
  );

  test('500 beim Anmelden: A-Trust meldet einen Fehler.', () async {
    rig.fake.loginStatus = 500;
    expect(await rig.failure(), 'A-Trust meldet einen Fehler.');
  });

  test('gescheiterte Anmeldung: der nächste Bon findet die Sitzung vor', () {
    fakeAsync((async) {
      rig.fake.delay = const Duration(milliseconds: 100);
      rig.fake.loginStatus = 500;
      Object? caught;
      rig.unit
          .sign(_text)
          .then<void>(
            (_) {},
            onError: (Object e) {
              caught = e;
              // Die Anmeldung von warmUp ist schon unterwegs.
              rig.fake.loginStatus = 200;
            },
          );
      async.elapse(const Duration(milliseconds: 150));
      expect(caught, isA<SignatureFailure>());
      async.elapse(const Duration(milliseconds: 150));
      expect(rig.fake.requests, [_login, _login]);

      rig.fake.delay = Duration.zero;
      Uint8List? sig;
      rig.unit.sign(_text).then((s) => sig = s);
      async.flushMicrotasks();
      expect(sig, hasLength(64));
      expect(rig.methods, ['PUT', 'PUT', 'POST']);
    });
  });

  test('abgelehnt: Satz, und beim nächsten Bon keine Anfrage', () async {
    rig.fake.loginStatus = 401;
    expect(await rig.failure(), 'A-Trust hat die Zugangsdaten abgelehnt.');
    await pumpEventQueue();
    expect(rig.fake.requests, [_login]);
    rig.fake.loginStatus = 200;
    expect(await rig.failure(), 'A-Trust hat die Zugangsdaten abgelehnt.');
    await pumpEventQueue();
    expect(rig.fake.requests, [_login]);
  });

  test('anderer Fehler: Die Signatur von A-Trust ist gescheitert.', () async {
    expect(
      await rig.failure('Käsekrainer'),
      'Die Signatur von A-Trust ist gescheitert.',
    );
    expect(rig.fake.requests, isEmpty);
  });

  group('Review Focus 1: späte Antwort', () {
    test('Anmeldung nach der Frist: keine Ausnahme, Sitzung bleibt', () {
      fakeAsync((async) {
        rig.fake.delay = const Duration(seconds: 3);
        Object? caught;
        rig.unit
            .sign(_text)
            .timeout(const Duration(seconds: 1))
            .then<void>((_) {}, onError: (Object e) => caught = e);
        async.elapse(const Duration(seconds: 1));
        expect(caught, isA<TimeoutException>());
        async.elapse(const Duration(seconds: 10));

        rig.fake.delay = Duration.zero;
        Uint8List? sig;
        rig.unit.sign(_text).then((s) => sig = s);
        async.flushMicrotasks();
        expect(sig, hasLength(64));
        expect(rig.fake.requests.where((r) => r == _login), hasLength(1));
        expect(rig.methods.last, 'POST');
      });
    });

    test('Fehler nach der Frist: keine unbehandelte Ausnahme', () {
      fakeAsync((async) {
        rig.fake.delay = const Duration(seconds: 3);
        rig.fake.offline = true;
        Object? caught;
        rig.unit
            .sign(_text)
            .timeout(const Duration(seconds: 1))
            .then<void>((_) {}, onError: (Object e) => caught = e);
        async.elapse(const Duration(seconds: 1));
        expect(caught, isA<TimeoutException>());
        async.elapse(const Duration(seconds: 10));
        expect(rig.keeper.rejected.value, isFalse);

        rig.fake.delay = Duration.zero;
        rig.fake.offline = false;
        Uint8List? sig;
        rig.unit.sign(_text).then((s) => sig = s);
        async.flushMicrotasks();
        expect(sig, hasLength(64));
      });
    });

    test('Signatur nach der Frist: die Sitzung bleibt benutzbar', () {
      fakeAsync((async) {
        Uint8List? first;
        rig.unit.sign(_text).then((s) => first = s);
        async.flushMicrotasks();
        expect(first, hasLength(64));

        rig.fake.delay = const Duration(seconds: 3);
        Object? caught;
        rig.unit
            .sign(_text)
            .timeout(const Duration(seconds: 1))
            .then<void>((_) {}, onError: (Object e) => caught = e);
        async.elapse(const Duration(seconds: 5));
        expect(caught, isA<TimeoutException>());

        rig.fake.delay = Duration.zero;
        Uint8List? sig;
        rig.unit.sign(_text).then((s) => sig = s);
        async.flushMicrotasks();
        expect(sig, hasLength(64));
        expect(rig.methods, ['PUT', 'POST', 'POST', 'POST']);
      });
    });
  });

  test('info() ohne Netz aus den übergebenen Werten', () async {
    final info = await rig.unit.info();
    expect(info.zdaId, 'AT1');
    expect(info.serialHex, '2159b9f6');
    expect(info.certificateDer, rig.fake.certificateDer);
    expect(info.issuerCertificatesDer, rig.fake.issuersDer);
    expect(rig.fake.requests, isEmpty);
  });

  test(
    'toString von Einheit und Halter ohne Passwort und Sitzungsschlüssel',
    () async {
      await rig.unit.sign(_text);
      final key =
          jsonDecode(rig.fake.signBodies.single)['sessionkey'] as String;
      for (final text in [rig.unit.toString(), rig.keeper.toString()]) {
        expect(text, isNot(contains(atrustTestPassword)));
        expect(text, isNot(contains(key)));
      }
    },
  );
}
