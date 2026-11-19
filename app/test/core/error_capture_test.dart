
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/core/error_capture.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/report_repository.dart';

void main() {
  late KassaDatabase db;
  late FlutterExceptionHandler? savedFlutter;
  late bool Function(Object, StackTrace)? savedPlatform;

  setUp(() {
    db = KassaDatabase(NativeDatabase.memory());
    savedFlutter = FlutterError.onError;
    savedPlatform = PlatformDispatcher.instance.onError;
  });
  tearDown(() async {
    FlutterError.onError = savedFlutter;
    PlatformDispatcher.instance.onError = savedPlatform;
    await db.close();
  });

  ReportRepository repo() => ReportRepository(
    db,
    FixedClock(DateTime(2026, 11, 19, 8, 11)),
    appVersion: '1.5.0',
  );

  Future<List<ReportRow>> waitForRows(int n) async {
    for (var i = 0; i < 100; i++) {
      final all = await db.select(db.reportRows).get();
      if (all.length >= n) return all;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return db.select(db.reportRows).get();
  }

  test('Fehler in einem Widget landet als Bericht und der bisherige Handler läuft weiter', () async {
    final seen = <FlutterErrorDetails>[];
    FlutterError.onError = seen.add;
    installErrorCapture(repo);

    FlutterError.reportError(
      FlutterErrorDetails(
        exception: RangeError('Cola'),
        stack: StackTrace.fromString('#0 build (package:kassa/w.dart:1:1)'),
      ),
    );

    final all = await waitForRows(1);
    expect(seen.length, 1);
    expect(all.single.content, contains('RangeError'));
    expect(all.single.content, contains('package:kassa/w.dart'));
  });

  test(
    'Fehler in einem Future außerhalb der Oberfläche landet als Bericht',
    () async {
      FlutterError.onError = (_) {};
      installErrorCapture(repo);

      final handled = PlatformDispatcher.instance.onError!(
        StateError('Huhn Bowl'),
        StackTrace.fromString('#0 later (package:kassa/f.dart:1:1)'),
      );

      expect(handled, isTrue);
      final all = await waitForRows(1);
      expect(all.single.content, contains('StateError'));
      expect(all.single.content, isNot(contains('Huhn')));
    },
  );

  test(
    'ein Fehler beim Schreiben macht keinen zweiten Bericht und wirft nicht',
    () async {
      FlutterError.onError = (_) {};
      var asked = 0;
      installErrorCapture(() {
        asked++;
        throw StateError('Datenbank nicht da');
      });

      final handled = PlatformDispatcher.instance.onError!(
        StateError('x'),
        StackTrace.current,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(handled, isTrue);
      expect(asked, 1);
      expect(await db.select(db.reportRows).get(), isEmpty);
    },
  );
}
