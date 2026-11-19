import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/outbox_repository.dart';
import 'package:kassa/data/report_repository.dart';
import 'package:kassa/sync/push_wire.dart';

void main() {
  late KassaDatabase db;
  late FixedClock clock;
  late ReportRepository reports;

  setUp(() {
    db = KassaDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime(2026, 11, 19, 8, 11));
    reports = ReportRepository(
      db,
      clock,
      appVersion: '1.5.0',
      androidVersion: '14',
      deviceModel: 'Redmi Pad Pro',
    );
  });
  tearDown(() => db.close());

  Future<List<ReportRow>> rows() => db.select(db.reportRows).get();
  Map<String, dynamic> content(ReportRow r) =>
      jsonDecode(r.content) as Map<String, dynamic>;

  Future<List<OutboxEntry>> outbox() => OutboxRepository(db).nextBatch();

  StackTrace stackOf(String where) => StackTrace.fromString(
    '#0      $where (package:kassa/a.dart:1:1)\n'
    '#1      main (package:kassa/main.dart:2:2)\n',
  );

  test('StateError mit Artikelname in der Meldung: message ist null, type und stack sind da', () async {
    await reports.addError(StateError('Huhn Bowl 9,90 fehlt'), stackOf('f'));
    final r = (await rows()).single;
    final c = content(r);
    expect(c['type'], 'StateError');
    expect(c['message'], isNull);
    expect(c['stack'], contains('package:kassa/a.dart'));
    expect(r.content, isNot(contains('Huhn')));
    expect(r.kind, 'error');
    expect(r.appVersion, '1.5.0');
    expect(r.androidVersion, '14');
    expect(r.deviceModel, 'Redmi Pad Pro');
    expect(r.count, 1);
    expect(r.at, clock.value);
  });

  test('TimeoutException: message ist da und höchstens 500 Zeichen', () async {
    await reports.addError(
      TimeoutException('x' * 900, const Duration(seconds: 5)),
      stackOf('t'),
    );
    final message = content((await rows()).single)['message'] as String;
    expect(message, startsWith('TimeoutException'));
    expect(message.length, 500);
  });

  test('PlatformException: nur der Code geht als message hinaus', () async {
    await reports.addError(
      PlatformException(code: 'no_printer', message: 'Bon 17, Cola 2,50'),
      stackOf('p'),
    );
    final c = content((await rows()).single);
    expect(c['type'], 'PlatformException');
    expect(c['message'], 'no_printer');
  });

  test('Aufrufliste hat höchstens 8000 Zeichen', () async {
    await reports.addError(
      StateError('x'),
      StackTrace.fromString('#0 ${'a' * 20000}'),
    );
    expect((content((await rows()).single)['stack'] as String).length, 8000);
  });

  test('derselbe Fehler dreimal: ein Bericht mit count 3, die Liste hat einen Eintrag report', () async {
    for (var i = 0; i < 3; i++) {
      clock.value = clock.value.add(const Duration(minutes: 1));
      await reports.addError(StateError('m$i'), stackOf('same'));
    }
    final r = (await rows()).single;
    expect(r.count, 3);
    expect(r.at, DateTime(2026, 11, 19, 8, 12));
    final list = await outbox();
    expect(list.where((e) => e.kind == 'report').length, 1);
    expect(list.single.ref, r.id);
  });

  test('derselbe Fehler nach dem Senden: ein neuer Bericht, der alte bleibt unverändert', () async {
    await reports.addError(StateError('a'), stackOf('same'));
    final first = (await rows()).single;
    final sent = (await outbox()).single;
    await OutboxRepository(db).remove(sent.id, rev: sent.rev);

    await reports.addError(StateError('a'), stackOf('same'));
    final all = await rows();
    expect(all.length, 2);
    final old = all.singleWhere((r) => r.id == first.id);
    expect(old.count, 1);
    expect(all.where((r) => r.id != first.id).single.count, 1);
    expect((await outbox()).length, 1);
  });

  test(
    'anderer Fehler dazwischen: kein Zusammenfassen mit dem älteren',
    () async {
      await reports.addError(StateError('a'), stackOf('one'));
      await reports.addError(StateError('b'), stackOf('two'));
      await reports.addError(StateError('c'), stackOf('one'));
      expect((await rows()).length, 3);
    },
  );

  test('51 verschiedene Fehler an einem Tag: 50 Berichte', () async {
    for (var i = 0; i < 51; i++) {
      await reports.addError(StateError('x'), stackOf('where$i'));
    }
    expect((await rows()).length, 50);
  });

  test('am nächsten Kalendertag gilt die Grenze neu', () async {
    for (var i = 0; i < 50; i++) {
      await reports.addError(StateError('x'), stackOf('where$i'));
    }
    clock.value = DateTime(2026, 11, 20, 0, 5);
    await reports.addError(StateError('x'), stackOf('neu'));
    expect((await rows()).length, 51);
  });

  test('count erhöhen zählt nicht gegen die Grenze von 50', () async {
    for (var i = 0; i < 49; i++) {
      await reports.addError(StateError('x'), stackOf('where$i'));
    }
    await reports.addError(StateError('x'), stackOf('last'));
    await reports.addError(StateError('x'), stackOf('last'));
    final all = await rows();
    expect(all.length, 50);
    expect(all.map((r) => r.count).reduce((a, b) => a + b), 51);
  });

  test('Datenbank geschlossen: addError wirft nicht', () async {
    await db.close();
    await reports.addError(StateError('x'), stackOf('closed'));
    await reports.addDeviceTest([(device: 'printer', ok: true, text: 'ok')]);
  });

  test(
    'Geräte testen: ein Bericht device_test mit den Zeilen des Bildschirms',
    () async {
      await reports.addDeviceTest([
        (
          device: 'printer',
          ok: true,
          text: 'Testdruck geschickt. Kommt Papier?',
        ),
        (device: 'card', ok: false, text: 'Kein Internet.'),
      ]);
      final r = (await rows()).single;
      expect(r.kind, 'device_test');
      expect(jsonDecode(r.content), [
        {
          'device': 'printer',
          'ok': true,
          'text': 'Testdruck geschickt. Kommt Papier?',
        },
        {'device': 'card', 'ok': false, 'text': 'Kein Internet.'},
      ]);
      expect((await outbox()).single.kind, 'report');
    },
  );

  test(
    'zwei Läufe von Geräte testen: zwei Berichte, nie zusammengefasst',
    () async {
      final run = [(device: 'printer', ok: true, text: 'ok')];
      await reports.addDeviceTest(run);
      await reports.addDeviceTest(run);
      expect((await rows()).length, 2);
    },
  );

  test(
    'Bericht enthält keine Schlüssel außer denen der Nachrichtenform',
    () async {
      await reports.addError(StateError('Cola'), stackOf('keys'));
      await reports.addDeviceTest([(device: 'printer', ok: true, text: 'ok')]);
      final ids = (await rows()).map((r) => r.id).toList();
      final payloads = PushPayloads(db);
      for (var i = 0; i < ids.length; i++) {
        final built = (await payloads.build(
          OutboxEntry(id: i + 1, kind: 'report', ref: ids[i], rev: 0),
        ))!;
        expect(built.keys.toSet(), {'seq', 'kind', 'report'});
        final report = built['report'] as Map<String, Object?>;
        expect(report.keys.toSet(), {
          'id',
          'kind',
          'at',
          'appVersion',
          'androidVersion',
          'deviceModel',
          'count',
          'error',
          'devices',
        });
        final error = report['error'];
        if (error != null) {
          expect((error as Map).keys.toSet(), {'type', 'message', 'stack'});
        }
        final devices = report['devices'];
        if (devices != null) {
          for (final d in devices as List) {
            expect((d as Map).keys.toSet(), {'device', 'ok', 'text'});
          }
        }
      }
    },
  );

  test(
    'ohne Geräteangaben geht ein Text hinaus, der Server verlangt Strings',
    () async {
      final bare = ReportRepository(db, clock, appVersion: '1.5.0');
      await bare.addError(StateError('x'), stackOf('bare'));
      final built = (await PushPayloads(db).build(
        OutboxEntry(
          id: 1,
          kind: 'report',
          ref: (await rows()).single.id,
          rev: 0,
        ),
      ))!;
      final report = built['report'] as Map<String, Object?>;
      expect(report['androidVersion'], isA<String>());
      expect(report['deviceModel'], isA<String>());
    },
  );
}
