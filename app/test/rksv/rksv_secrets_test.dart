import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/rksv/rksv_secrets.dart';

void main() {
  credentialsAndSetup();
  cardPinAndStatus();
  final key = Uint8List.fromList(List.generate(32, (i) => i));

  test('MemoryRksvSecrets: lesen nach schreiben; failReads wirft', () async {
    final s = MemoryRksvSecrets();
    expect(await s.aesKey(1), isNull);
    await s.writeAesKey(1, key);
    await s.writeProbeKey(1, key);
    expect(await s.aesKey(1), key);
    expect(await s.probeKey(1), key);
    expect(await s.aesKey(2), isNull);
    s.failReads = true;
    await expectLater(s.aesKey(1), throwsA(anything));
    await expectLater(s.probeKey(1), throwsA(anything));
  });

  test('SecureRksvSecrets: Schlüsselnamen und base64', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final s = SecureRksvSecrets();
    expect(await s.aesKey(3), isNull);
    await s.writeAesKey(3, key);
    await s.writeProbeKey(3, key);
    expect(await s.aesKey(3), key);
    expect(await s.probeKey(3), key);
    final raw = await const FlutterSecureStorage().readAll();
    expect(raw.keys.toSet(), {'rksv_aes_3', 'rksv_probe_key_3'});
    expect(raw['rksv_aes_3'], 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=');
  });

  test('MemoryRksvSecrets: Kennzeichen abgelehnt', () async {
    final s = MemoryRksvSecrets();
    expect(await s.atrustRejected(), isFalse);
    await s.writeAtrustRejected(true);
    expect(await s.atrustRejected(), isTrue);
    await s.writeAtrustRejected(false);
    expect(await s.atrustRejected(), isFalse);
    s.failReads = true;
    await expectLater(s.atrustRejected(), throwsA(anything));
  });

  test(
    'SecureRksvSecrets: Kennzeichen abgelehnt unter rksv_atrust_rejected',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final s = SecureRksvSecrets();
      expect(await s.atrustRejected(), isFalse);
      await s.writeAtrustRejected(true);
      expect(await s.atrustRejected(), isTrue);
      expect(await const FlutterSecureStorage().readAll(), {
        'rksv_atrust_rejected': 'true',
      });
      await s.writeAtrustRejected(false);
      expect(await s.atrustRejected(), isFalse);
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
    },
  );
}

void credentialsAndSetup() {
  const creds = AtrustCredentials('u-beispiel', 'geheim-beispiel');
  final aes = Uint8List.fromList(List.generate(32, (i) => 255 - i));

  group('Zugangsdaten und PendingSetup', () {
    test('MemoryRksvSecrets: Zugangsdaten schreiben, lesen, löschen', () async {
      final s = MemoryRksvSecrets();
      expect(await s.atrustCredentials(), isNull);
      await s.writeAtrustCredentials(creds);
      final read = await s.atrustCredentials();
      expect(read!.user, 'u-beispiel');
      expect(read.password, 'geheim-beispiel');
      await s.writeAtrustCredentials(null);
      expect(await s.atrustCredentials(), isNull);
      s.failReads = true;
      await expectLater(s.atrustCredentials(), throwsA(anything));
    });

    test('SecureRksvSecrets: Zugangsdaten als ein Wert unter '
        'rksv_atrust_credentials', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final s = SecureRksvSecrets();
      expect(await s.atrustCredentials(), isNull);
      await s.writeAtrustCredentials(creds);
      final raw = await const FlutterSecureStorage().readAll();
      expect(raw.keys, ['rksv_atrust_credentials']);
      expect(jsonDecode(raw['rksv_atrust_credentials']!), {
        'user': 'u-beispiel',
        'password': 'geheim-beispiel',
      });
      final read = await s.atrustCredentials();
      expect(read!.user, 'u-beispiel');
      expect(read.password, 'geheim-beispiel');
      await s.writeAtrustCredentials(null);
      expect(await s.atrustCredentials(), isNull);
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
    });

    test(
      'SecureRksvSecrets: scheitert das Schreiben an irgendeiner Stelle, '
      'bleiben die alten Zugangsdaten oder keine, nie ein gemischtes Paar',
      () async {
        const fresh = AtrustCredentials(
          'u-neu-beispiel',
          'neu-geheim-beispiel',
        );
        for (final AtrustCredentials? next in [fresh, null]) {
          for (var left = 0; left < 3; left++) {
            FlutterSecureStorage.setMockInitialValues({});
            final storage = _FailingStorage();
            final s = SecureRksvSecrets(storage);
            await s.writeAtrustCredentials(creds);
            storage.writesLeft = left;
            var failed = false;
            try {
              await s.writeAtrustCredentials(next);
            } catch (_) {
              failed = true;
            }
            final read = await s.atrustCredentials();
            final pair = (read?.user, read?.password);
            final why = '$next nach $left Schreibvorgängen';
            if (failed) {
              expect(
                pair,
                anyOf((creds.user, creds.password), (null, null)),
                reason: why,
              );
            } else {
              expect(pair, (next?.user, next?.password), reason: why);
            }
          }
        }
      },
    );

    test('MemoryRksvSecrets: PendingSetup schreiben, lesen, löschen', () async {
      final s = MemoryRksvSecrets();
      expect(await s.pendingSetup(), isNull);
      await s.writePendingSetup(
        PendingSetup(cashBoxId: 'KASSA-1', aesKey: aes),
      );
      final read = await s.pendingSetup();
      expect(read!.cashBoxId, 'KASSA-1');
      expect(read.aesKey, aes);
      await s.writePendingSetup(null);
      expect(await s.pendingSetup(), isNull);
      s.failReads = true;
      await expectLater(s.pendingSetup(), throwsA(anything));
    });

    test(
      'SecureRksvSecrets: PendingSetup als ein Wert unter rksv_setup',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final s = SecureRksvSecrets();
        expect(await s.pendingSetup(), isNull);
        await s.writePendingSetup(
          PendingSetup(cashBoxId: 'KASSA-1', aesKey: aes),
        );
        final raw = await const FlutterSecureStorage().readAll();
        expect(raw.keys, ['rksv_setup']);
        expect(jsonDecode(raw['rksv_setup']!), {
          'cashBoxId': 'KASSA-1',
          'aesKey': base64.encode(aes),
        });
        final read = await s.pendingSetup();
        expect(read!.cashBoxId, 'KASSA-1');
        expect(read.aesKey, aes);
        await s.writePendingSetup(null);
        expect(await s.pendingSetup(), isNull);
        expect(await const FlutterSecureStorage().readAll(), isEmpty);
      },
    );

    test(
      'SecureRksvSecrets: scheitert das Schreiben an irgendeiner Stelle, '
      'bleibt das alte PendingSetup oder keins, nie eine gemischte Hälfte',
      () async {
        final fresh = PendingSetup(cashBoxId: 'KASSA-2', aesKey: Uint8List(32));
        for (final PendingSetup? next in [fresh, null]) {
          for (var left = 0; left < 3; left++) {
            FlutterSecureStorage.setMockInitialValues({});
            final storage = _FailingStorage();
            final s = SecureRksvSecrets(storage);
            await s.writePendingSetup(
              PendingSetup(cashBoxId: 'KASSA-1', aesKey: aes),
            );
            storage.writesLeft = left;
            var failed = false;
            try {
              await s.writePendingSetup(next);
            } catch (_) {
              failed = true;
            }
            final read = await s.pendingSetup();
            final why = '$next nach $left Schreibvorgängen';
            bool isOld(PendingSetup? p) =>
                p != null && p.cashBoxId == 'KASSA-1' && _same(p.aesKey, aes);
            bool isNew(PendingSetup? p) =>
                p != null &&
                p.cashBoxId == 'KASSA-2' &&
                _same(p.aesKey, fresh.aesKey);
            if (failed) {
              expect(read == null || isOld(read), isTrue, reason: why);
            } else if (next == null) {
              expect(read, isNull, reason: why);
            } else {
              expect(isNew(read), isTrue, reason: why);
            }
          }
        }
      },
    );

    test('MemoryRksvSecrets: abgelehnt für Test und echt getrennt', () async {
      final s = MemoryRksvSecrets();
      await s.writeAtrustRejected(true, live: true);
      expect(await s.atrustRejected(live: true), isTrue);
      expect(await s.atrustRejected(), isFalse);
      await s.writeAtrustRejected(true);
      await s.writeAtrustRejected(false, live: true);
      expect(await s.atrustRejected(), isTrue);
      expect(await s.atrustRejected(live: true), isFalse);
    });

    test(
      'SecureRksvSecrets: abgelehnt echt unter rksv_atrust_rejected_live',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final s = SecureRksvSecrets();
        await s.writeAtrustRejected(true, live: true);
        expect(await const FlutterSecureStorage().readAll(), {
          'rksv_atrust_rejected_live': 'true',
        });
        expect(await s.atrustRejected(live: true), isTrue);
        expect(await s.atrustRejected(), isFalse);
        await s.writeAtrustRejected(true);
        await s.writeAtrustRejected(false, live: true);
        expect(await const FlutterSecureStorage().readAll(), {
          'rksv_atrust_rejected': 'true',
        });
        expect(await s.atrustRejected(live: true), isFalse);
      },
    );

    test('toString nennt weder Benutzer, Passwort noch Schlüssel', () {
      final setup = PendingSetup(cashBoxId: 'KASSA-1', aesKey: aes);
      expect(creds.toString(), 'AtrustCredentials');
      for (final text in [creds.toString(), setup.toString()]) {
        expect(text, isNot(contains('u-beispiel')));
        expect(text, isNot(contains('geheim-beispiel')));
        expect(text, isNot(contains('KASSA-1')));
        expect(text, isNot(contains(base64.encode(aes))));
        expect(text, isNot(contains('255')));
      }
    });

    test(
      'MemoryRksvSecrets: failWrites lässt das Schreiben scheitern',
      () async {
        final s = MemoryRksvSecrets()..failWrites = true;
        await expectLater(s.writeAtrustRejected(true), throwsA(anything));
        await expectLater(s.writeAtrustCredentials(creds), throwsA(anything));
        s.failWrites = false;
        expect(await s.atrustRejected(), isFalse);
        expect(await s.atrustCredentials(), isNull);
      },
    );
  });
}

void cardPinAndStatus() {
  const pin = CardPin(
    kind: 'acosId41',
    numberHex: '0102030405060708',
    pin: '246813',
  );

  group('PIN der Karte und ihr Status', () {
    test('CardPin nennt in toString nichts', () {
      expect(pin.toString(), 'CardPin');
      expect('$pin', isNot(contains('246813')));
    });

    test('MemoryRksvSecrets: Hin und Zurück, Löschen, Status', () async {
      final s = MemoryRksvSecrets();
      expect(await s.cardPin(), isNull);
      final status = await s.cardPinStatus();
      expect(status.rejected, isFalse);
      expect(status.unanswered, 0);

      await s.writeCardPin(pin);
      final read = (await s.cardPin())!;
      expect(read.kind, 'acosId41');
      expect(read.numberHex, '0102030405060708');
      expect(read.pin, '246813');

      await s.writeCardPinStatus(const CardPinStatus(unanswered: 1));
      expect((await s.cardPinStatus()).unanswered, 1);
      await s.writeCardPinStatus(const CardPinStatus(rejected: true));
      expect((await s.cardPinStatus()).rejected, isTrue);

      // Schreiben der PIN setzt den Status zurück.
      await s.writeCardPin(pin);
      expect((await s.cardPinStatus()).rejected, isFalse);
      expect((await s.cardPinStatus()).unanswered, 0);

      await s.writeCardPinStatus(const CardPinStatus(unanswered: 2));
      await s.writeCardPin(null);
      expect(await s.cardPin(), isNull);
      expect((await s.cardPinStatus()).unanswered, 0);

      s.failWrites = true;
      await expectLater(s.writeCardPin(pin), throwsA(anything));
      await expectLater(
        s.writeCardPinStatus(const CardPinStatus(unanswered: 1)),
        throwsA(anything),
      );
      s.failWrites = false;
      expect(await s.cardPin(), isNull);
      expect((await s.cardPinStatus()).unanswered, 0);
      s.failReads = true;
      await expectLater(s.cardPin(), throwsA(anything));
      await expectLater(s.cardPinStatus(), throwsA(anything));
    });

    test('SecureRksvSecrets: ein JSON-Wert unter rksv_card_pin, Status unter '
        'rksv_card_pin_status', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final s = SecureRksvSecrets();
      expect(await s.cardPin(), isNull);
      expect((await s.cardPinStatus()).rejected, isFalse);
      expect((await s.cardPinStatus()).unanswered, 0);

      await s.writeCardPin(pin);
      var raw = await const FlutterSecureStorage().readAll();
      expect(raw.keys.toSet(), {'rksv_card_pin'});
      expect(jsonDecode(raw['rksv_card_pin']!), {
        'kind': 'acosId41',
        'numberHex': '0102030405060708',
        'pin': '246813',
      });
      final read = (await s.cardPin())!;
      expect(read.kind, 'acosId41');
      expect(read.numberHex, '0102030405060708');
      expect(read.pin, '246813');

      await s.writeCardPinStatus(const CardPinStatus(unanswered: 1));
      expect((await s.cardPinStatus()).unanswered, 1);
      expect((await s.cardPinStatus()).rejected, isFalse);
      await s.writeCardPinStatus(const CardPinStatus(rejected: true));
      expect((await s.cardPinStatus()).rejected, isTrue);
      raw = await const FlutterSecureStorage().readAll();
      expect(raw.keys.toSet(), {'rksv_card_pin', 'rksv_card_pin_status'});
      expect(raw['rksv_card_pin_status'], isNot(contains('246813')));

      // Schreiben der PIN setzt den Status zurück.
      await s.writeCardPin(pin);
      expect((await s.cardPinStatus()).rejected, isFalse);
      expect((await s.cardPinStatus()).unanswered, 0);

      // Der leere Status ist kein Eintrag.
      await s.writeCardPinStatus(const CardPinStatus(unanswered: 2));
      await s.writeCardPinStatus(const CardPinStatus());
      raw = await const FlutterSecureStorage().readAll();
      expect(raw.keys.toSet(), {'rksv_card_pin'});

      await s.writeCardPinStatus(const CardPinStatus(unanswered: 1));
      await s.writeCardPin(null);
      expect(await s.cardPin(), isNull);
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
    });

    test(
      'SecureRksvSecrets: ein unlesbarer Status gilt als abgelehnt',
      () async {
        for (final value in ['kaputt', '[]', '{"unanswered":"eins"}', '7']) {
          FlutterSecureStorage.setMockInitialValues({
            'rksv_card_pin_status': value,
          });
          final status = await SecureRksvSecrets().cardPinStatus();
          expect(status.rejected, isTrue, reason: value);
        }
      },
    );
  });
}

bool _same(Uint8List a, Uint8List b) =>
    a.length == b.length &&
    [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

/// Der Speicher der Tests, der nach [writesLeft] Schreib- oder
/// Löschvorgängen scheitert, wie ein Speicher, der mitten im Speichern
/// aufgibt.
class _FailingStorage extends FlutterSecureStorage {
  _FailingStorage();

  int writesLeft = 1 << 30;

  void _count() {
    if (writesLeft-- <= 0) {
      throw PlatformException(code: 'beispiel', message: 'Schreiben scheitert');
    }
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _count();
    await super.write(key: key, value: value);
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _count();
    await super.delete(key: key);
  }
}
