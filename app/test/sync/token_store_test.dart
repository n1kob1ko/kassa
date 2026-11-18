import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/sync/token_store.dart';

void main() {
  test('MemoryTokenStore: schreiben, lesen, löschen', () async {
    final store = MemoryTokenStore();
    expect(await store.read(), isNull);
    await store.write('abc');
    expect(await store.read(), 'abc');
    await store.write('def');
    expect(await store.read(), 'def');
    await store.clear();
    expect(await store.read(), isNull);
  });
}
