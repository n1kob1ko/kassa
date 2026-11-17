import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lässt die Person eine Speisekarten-Datei vom Tablet wählen.
abstract class MenuFilePicker {
  /// Der Text der gewählten Datei, `null` wenn die Person abbricht.
  Future<String?> pickText();
}

/// Echte Umsetzung mit dem Dateiwähler des Systems. Die Bytes werden gelesen
/// (nicht der Pfad), das geht auch auf Android.
class SystemMenuFilePicker implements MenuFilePicker {
  const SystemMenuFilePicker();

  @override
  Future<String?> pickText() async {
    // Jede Datei ist wählbar: Dateien aus Nachrichten oder von Laufwerken
    // haben oft keinen passenden Typ und wären sonst ausgegraut. Ob es eine
    // Speisekarte ist, prüft der Leser.
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return null;
    return utf8.decode(await file.readAsBytes(), allowMalformed: true);
  }
}

/// Tests ersetzen ihn durch eine Attrappe.
final menuFilePickerProvider = Provider<MenuFilePicker>(
  (ref) => const SystemMenuFilePicker(),
);

/// Liefert den Text der mitgelieferten Beispiel-Speisekarte (erfundener
/// Imbiss). Tests lesen die Datei direkt, weil Asset-Laden echte Zeit braucht.
final demoMenuTextProvider = Provider<Future<String> Function()>(
  (ref) =>
      () => rootBundle.loadString('assets/demo/beispiel-imbiss.json'),
);
