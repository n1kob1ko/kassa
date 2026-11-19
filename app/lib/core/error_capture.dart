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

  _capture = capture;
  // Was die Zone vor dem Einhängen aufgefangen hat, geht jetzt hinaus.
  final early = List.of(_early);
  _early.clear();
  for (final e in early) {
    capture(e.$1, e.$2);
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

void Function(Object, StackTrace?)? _capture;
final _early = <(Object, StackTrace?)>[];

/// Nur für Tests: vergisst das Eingehängte und die gemerkten Fehler.
@visibleForTesting
void resetErrorCapture() {
  _capture = null;
  _early.clear();
}

/// Führt [body] in einer Zone aus, die Fehler aus Futures und Hintergrund-
/// Aufgaben an das Abfangen gibt. Kommt ein Fehler, bevor
/// [installErrorCapture] gelaufen ist, merkt sich die Zone ihn (höchstens
/// zehn) und gibt ihn beim Einhängen weiter. Der Handler wirft nie.
Future<void> runGuarded(Future<void> Function() body) {
  final done = Completer<void>();
  runZonedGuarded(
    () async {
      try {
        await body();
      } finally {
        if (!done.isCompleted) done.complete();
      }
    },
    (error, stack) {
      try {
        final capture = _capture;
        if (capture != null) {
          capture(error, stack);
        } else if (_early.length < 10) {
          _early.add((error, stack));
        }
      } catch (_) {
        // Das Abfangen wirft nie.
      }
      if (!done.isCompleted) done.complete();
    },
  );
  return done.future;
}
