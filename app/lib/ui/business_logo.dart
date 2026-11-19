import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/providers.dart';
import 'hex_color.dart';
import 'kassa_logo.dart';

/// Das Logo des Betriebs, aus der Datei auf dem Tablet. Gibt es kein Logo, ist
/// die Datei noch nicht ganz da oder lässt sie sich nicht zeichnen, steht
/// stattdessen das [KassaLogo]. Gleiche Größe und gleiche Rundung wie dieses:
/// nichts rückt, wenn das Logo erscheint. Bis das Bild gezeichnet ist, steht
/// die mittlere Farbe des Logos da.
class BusinessLogo extends ConsumerWidget {
  const BusinessLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(catalogProvider).value?.business;
    final path = business?.logoPath;
    final fallback = KassaLogo(size: size);
    if (path == null) return fallback;
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return Container(
      key: const Key('business-logo'),
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorFromHex(business?.logo?.color),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Image.file(
        File(path),
        fit: BoxFit.contain,
        cacheWidth: pixels,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
