import 'package:material_ui/material_ui.dart';
import 'package:qr/qr.dart';

import 'tokens.dart';

/// Ruhezone um den Code, in Modulen (so verlangt es der QR-Standard).
const _quietModules = 4;

/// Zeichnet [data] als QR-Code (Fehlerkorrektur M, wie am gedruckten Bon):
/// dunkle Module in der Tinte der hellen Ansicht auf Weiß, mit feinem Rand.
/// Auch im dunklen Modus bleibt die Fläche weiß, damit jede Kamera den Code
/// liest. Quadratisch, [size] dp.
class QrView extends StatelessWidget {
  const QrView({super.key, required this.data, this.size = 180});

  /// Der Text im Code, genau der des gedruckten Bons.
  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    QrImage? image;
    try {
      image = QrImage(
        QrCode(
          payload: QrPayload.fromString(data),
          errorCorrectLevel: QrErrorCorrectLevel.medium,
        ),
      );
    } on Object {
      // Zu lang oder nicht darstellbar: die Fläche bleibt leer.
      image = null;
    }
    return Semantics(
      label: 'QR-Code des Bons',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          // Weiß wie Papier, in beiden Ansichten.
          color: KassaColors.light.card,
          borderRadius: BorderRadius.circular(KassaTokens.radiusMd),
          border: Border.all(color: c.line, width: KassaTokens.borderThin),
        ),
        child: image == null
            ? null
            : CustomPaint(
                painter: _QrPainter(image, KassaColors.light.ink),
                size: Size.square(size),
              ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image, this.ink);

  final QrImage image;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final count = image.moduleCount;
    final module = size.shortestSide / (count + 2 * _quietModules);
    final offset = (size.shortestSide - module * count) / 2;
    final paint = Paint()
      ..color = ink
      ..isAntiAlias = false;
    for (var row = 0; row < count; row++) {
      for (var col = 0; col < count; col++) {
        if (!image.isDark(row, col)) continue;
        // Ein Hauch Überlappung, damit zwischen Modulen keine Haarlinien
        // stehen bleiben.
        canvas.drawRect(
          Rect.fromLTWH(
            offset + col * module,
            offset + row * module,
            module + 0.3,
            module + 0.3,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.image != image || old.ink != ink;
}
