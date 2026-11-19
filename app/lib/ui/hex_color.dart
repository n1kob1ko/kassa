import 'package:material_ui/material_ui.dart';

/// Liest `#rrggbb` (so schickt der Server die mittlere Farbe eines Bildes).
/// Alles andere ergibt `null`.
Color? colorFromHex(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}
