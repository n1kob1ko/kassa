import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Läuft gerade ein Schritt, der sich nicht zurücknehmen lässt: `goLive` aus
/// "Angaben für FinanzOnline" oder `decommission` aus der Karte "Signatur"?
/// Solange er läuft, schließen weder "Zurück" noch ein anderer Bereich, die
/// Einstellungen-Taste, Abmelden oder der Hinweis zum vergessenen Abschluss
/// den Bildschirm: Sein Ergebnis darf nicht verloren gehen. Wer ihn setzt,
/// hebt ihn in einem `finally` wieder auf.
class IrreversibleStep extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final irreversibleStepProvider = NotifierProvider<IrreversibleStep, bool>(
  IrreversibleStep.new,
);
