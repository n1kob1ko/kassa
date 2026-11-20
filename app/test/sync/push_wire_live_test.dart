// Q10: Das Feld `test` eines Bons hängt nur am Modus seiner Kette und ändert
// sich nie, auch nicht durch die Inbetriebnahme. Hält das Verhalten von
// `push_wire` für Ketten `live` fest (dort ändert sich nichts).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/outbox_repository.dart';
import 'package:kassa/sync/push_wire.dart';

import '../support/fake_atrust.dart';
import '../support/rksv_rig.dart';
import '../support/sales.dart' show cart;

void main() {
  late RksvRig rig;
  late FakeAtrust atrust;
  late PushPayloads payloads;

  setUp(() async {
    atrust = FakeAtrust();
    rig = await RksvRig.open(atrust: atrust);
    payloads = PushPayloads(rig.db);
  });
  tearDown(() => rig.close());

  Future<Map<String, dynamic>> receiptOf(String id) async {
    final built = await payloads.build(
      OutboxEntry(id: 1, kind: 'receipt', ref: id, rev: 0),
    );
    return built!['receipt'] as Map<String, dynamic>;
  }

  test(
    'Bon einer live-Kette hat test false, auch mit Ausfall-Eintrag',
    () async {
      final chain = await rig.seedLive();
      await rig.sell('l1', cart);
      atrust.signStatus = 500;
      await rig.sell('l2', cart);

      final signed = await receiptOf('l1');
      expect(signed['test'], isFalse);
      expect((signed['rksv'] as Map)['chain'], chain);
      expect((signed['rksv'] as Map)['damaged'], isFalse);
      final damaged = await receiptOf('l2');
      expect(damaged['test'], isFalse);
      expect((damaged['rksv'] as Map)['chain'], chain);
      expect((damaged['rksv'] as Map)['damaged'], isTrue);
    },
  );

  test('Bons von vor der Inbetriebnahme (ohne Kette, Probe-Kette) haben vor '
      'und nach ihr test true und byte-gleiche Nachrichten', () async {
    await rig.sell('ohne', cart);
    await rig.service.enableProbe(staff: rig.chef);
    await rig.sell('probe', cart);
    final before = {
      for (final id in ['ohne', 'probe']) id: jsonEncode(await receiptOf(id)),
    };
    expect((await receiptOf('ohne'))['test'], isTrue);
    expect((await receiptOf('ohne'))['rksv'], isNull);
    expect((await receiptOf('probe'))['test'], isTrue);
    expect(((await receiptOf('probe'))['rksv'] as Map)['chain'], 1);

    final chain = await rig.seedLive();
    expect(chain, 2);
    await rig.sell('echt', cart);
    expect((await receiptOf('echt'))['test'], isFalse);

    for (final id in ['ohne', 'probe']) {
      final after = jsonEncode(await receiptOf(id));
      expect(after, before[id], reason: id);
      expect(utf8.encode(after), utf8.encode(before[id]!), reason: id);
      expect((jsonDecode(after) as Map)['test'], isTrue, reason: id);
    }
  });
}
