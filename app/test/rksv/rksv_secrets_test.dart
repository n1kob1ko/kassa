import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/rksv/rksv_secrets.dart';

void main() {
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
