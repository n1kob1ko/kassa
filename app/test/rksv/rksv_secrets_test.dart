import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/rksv/rksv_secrets.dart';

void main() {
  credentialsAndSetup();
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

    test('SecureRksvSecrets: Zugangsdaten unter rksv_atrust_user und '
        'rksv_atrust_password', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final s = SecureRksvSecrets();
      expect(await s.atrustCredentials(), isNull);
      await s.writeAtrustCredentials(creds);
      expect(await const FlutterSecureStorage().readAll(), {
        'rksv_atrust_user': 'u-beispiel',
        'rksv_atrust_password': 'geheim-beispiel',
      });
      final read = await s.atrustCredentials();
      expect(read!.user, 'u-beispiel');
      expect(read.password, 'geheim-beispiel');
      await s.writeAtrustCredentials(null);
      expect(await s.atrustCredentials(), isNull);
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
    });

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

    test('SecureRksvSecrets: PendingSetup unter rksv_setup_cash_box_id und '
        'rksv_setup_aes', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final s = SecureRksvSecrets();
      expect(await s.pendingSetup(), isNull);
      await s.writePendingSetup(
        PendingSetup(cashBoxId: 'KASSA-1', aesKey: aes),
      );
      expect(await const FlutterSecureStorage().readAll(), {
        'rksv_setup_cash_box_id': 'KASSA-1',
        'rksv_setup_aes': base64.encode(aes),
      });
      final read = await s.pendingSetup();
      expect(read!.cashBoxId, 'KASSA-1');
      expect(read.aesKey, aes);
      await s.writePendingSetup(null);
      expect(await s.pendingSetup(), isNull);
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
    });

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
