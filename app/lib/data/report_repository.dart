// Berichte für den Server: unerwartete Fehler und das Ergebnis von "Geräte
// testen". Der Bericht wird aus festen Feldern gebaut. Die Meldung eines
// Fehlers kann Text aus Daten enthalten (Artikelname, Betrag); darum geht nur
// die Art des Fehlers und die Aufrufliste hinaus, die Meldung selbst nur bei
// Fehlerarten aus einer festen Liste. Die Datenbank trägt jeden neuen oder
// geänderten Bericht selbst in die Liste "noch zu senden" ein.

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:uuid/uuid.dart';

import '../core/clock.dart';
import 'database.dart';

/// Höchstens so viele neue Berichte pro Kalendertag.
const maxReportsPerDay = 50;

/// Grenzen, die auch der Server prüft.
const maxMessageLength = 500;
const maxStackLength = 8000;

class ReportRepository {
  ReportRepository(
    this._db,
    this._clock, {
    required this.appVersion,
    this.androidVersion,
    this.deviceModel,
  });

  final KassaDatabase _db;
  final Clock _clock;
  final String appVersion;
  final String? androidVersion;
  final String? deviceModel;

  /// Schreibt einen Bericht über [error], oder erhöht den Zähler des jüngsten,
  /// wenn es derselbe Fehler ist und der Bericht noch wartet. Wirft nie.
  Future<void> addError(Object error, StackTrace? stack) async {
    try {
      final type = error.runtimeType.toString();
      final stackText = _cut(stack?.toString() ?? '', maxStackLength);
      final lines = stackText.split('\n').take(5).join('\n');
      final signature = '$type\n$lines';
      final content = jsonEncode({
        'type': type,
        'message': _message(error),
        'stack': stackText,
      });
      await _db.transaction(() async {
        final latest = await _latest();
        if (latest != null &&
            latest.kind == 'error' &&
            latest.signature == signature &&
            await _waiting(latest.id)) {
          await (_db.update(_db.reportRows)
                ..where((t) => t.id.equals(latest.id)))
              .write(ReportRowsCompanion(count: Value(latest.count + 1)));
          return;
        }
        await _insert('error', signature, content);
      });
    } catch (_) {
      // Kein Bericht über den Bericht.
    }
  }

  /// Schreibt das Ergebnis eines Laufs von "Geräte testen": je Gerät, ob es
  /// gut ging, und der Text, den der Bildschirm zeigt. Wirft nie.
  Future<void> addDeviceTest(
    List<({String device, bool ok, String text})> results,
  ) async {
    try {
      final content = jsonEncode([
        for (final r in results.take(20))
          {
            'device': _cut(r.device, 200),
            'ok': r.ok,
            'text': _cut(r.text, maxMessageLength),
          },
      ]);
      await _db.transaction(
        () => _insert('device_test', 'device_test', content),
      );
    } catch (_) {
      // Kein Bericht über den Bericht.
    }
  }

  Future<void> _insert(String kind, String signature, String content) async {
    final now = _clock.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = DateTime(now.year, now.month, now.day + 1);
    final today =
        await (_db.select(_db.reportRows)..where(
              (t) =>
                  t.at.isBiggerOrEqualValue(dayStart) &
                  t.at.isSmallerThanValue(dayEnd),
            ))
            .get();
    if (today.length >= maxReportsPerDay) return;
    await _db
        .into(_db.reportRows)
        .insert(
          ReportRowsCompanion.insert(
            id: const Uuid().v4(),
            kind: kind,
            at: now,
            appVersion: appVersion,
            androidVersion: Value(androidVersion),
            deviceModel: Value(deviceModel),
            signature: signature,
            content: content,
          ),
        );
  }

  Future<ReportRow?> _latest() =>
      (_db.select(_db.reportRows)
            ..orderBy([
              (t) => OrderingTerm.desc(t.at),
              (t) => OrderingTerm.desc(const CustomExpression<int>('rowid')),
            ])
            ..limit(1))
          .getSingleOrNull();

  /// Ob der Bericht noch in der Liste "noch zu senden" wartet.
  Future<bool> _waiting(String id) async {
    final row = await _db
        .customSelect(
          "SELECT 1 FROM outbox WHERE kind = 'report' AND ref = ? AND state = 'pending'",
          variables: [Variable<String>(id)],
        )
        .getSingleOrNull();
    return row != null;
  }

  /// Die Meldung nur für Fehlerarten, die keine Daten tragen.
  static String? _message(Object error) {
    if (error is PlatformException) return _cut(error.code, maxMessageLength);
    final keep =
        error is TimeoutException ||
        error is RangeError ||
        error is TypeError ||
        error is NoSuchMethodError ||
        error is AssertionError ||
        error is UnsupportedError ||
        error is UnimplementedError ||
        error is MissingPluginException;
    return keep ? _cut(error.toString(), maxMessageLength) : null;
  }

  static String _cut(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);
}
