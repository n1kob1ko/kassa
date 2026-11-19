// Fängt unerwartete Fehler ab und gibt sie an den Berichts-Speicher. Das
// Abfangen wirft nie, ändert keinen Bildschirm und löst keinen zweiten Bericht
// aus.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/report_repository.dart';

/// Hängt sich einmal beim Start an `FlutterError.onError` (der bisherige
/// Handler läuft weiter) und `PlatformDispatcher.onError`.
void installErrorCapture(ReportRepository Function() reports) {
  var busy = false;

  void capture(Object error, StackTrace? stack) {
    if (busy) return;
    busy = true;
    try {
      // Der Speicher wird erst im Future gelesen: ein Fehler dabei ist
      // geschluckt wie jeder andere beim Schreiben.
      unawaited(
        Future<void>(() => reports().addError(error, stack)).catchError((_) {}),
      );
    } catch (_) {
      // Das Abfangen wirft nie.
    } finally {
      busy = false;
    }
  }

  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    try {
      previous?.call(details);
    } catch (_) {
      // Der bisherige Handler darf das Abfangen nicht verhindern.
    }
    capture(details.exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    capture(error, stack);
    return true;
  };
}
