import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/rksv/card/pin_guard.dart';

const cardA = '0102030405060708';
const cardB = '1112131415161718';

Future<void> checkGuard(PinGuard guard) async {
  expect(await guard.retriesLeft(cardA), isNull);
  await guard.recordFailure(cardA, 2);
  expect(await guard.retriesLeft(cardA), 2);
  expect(await guard.retriesLeft(cardB), isNull);
  await guard.recordFailure(cardB, 1);
  await guard.recordFailure(cardA, 1);
  expect(await guard.retriesLeft(cardA), 1);
  expect(await guard.retriesLeft(cardB), 1);
  await guard.clear(cardA);
  expect(await guard.retriesLeft(cardA), isNull);
  expect(await guard.retriesLeft(cardB), 1);
  await guard.recordFailure(cardB, 0);
  expect(await guard.retriesLeft(cardB), 0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recordFailure, retriesLeft, clear; getrennt je Kartennummer', () async {
    await checkGuard(MemoryPinGuard());

    final values = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(values);
    final secure = SecurePinGuard();
    await checkGuard(secure);
    // Im geschützten Speicher steht nur die Zahl der Versuche, unter dem
    // Schlüssel je Kartennummer.
    expect(await const FlutterSecureStorage().readAll(), {
      'rksv_pin_guard_$cardB': '0',
    });
    await secure.clear(cardB);
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
  });

  test('MemoryPinGuard mit gemeinsamem Speicher: zweite Instanz kennt den Fehlversuch', () async {
    final store = <String, int>{};
    await MemoryPinGuard(store).recordFailure(cardA, 1);
    expect(await MemoryPinGuard(store).retriesLeft(cardA), 1);
  });

  test(
    'SecurePinGuard: unlesbarer Eintrag zählt als bekannt mit 0 Versuchen',
    () async {
      FlutterSecureStorage.setMockInitialValues({'rksv_pin_guard_$cardA': 'x'});
      expect(await SecurePinGuard().retriesLeft(cardA), 0);
    },
  );
}
