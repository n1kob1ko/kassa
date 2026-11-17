import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// Logo-Kachel: Bon-Symbol in Weiß auf Petrol. Größe [size], Rundung 30 %.
/// Das Symbol ist wie im Entwurf gezeichnet (Bon mit zwei Zeilen).
class KassaLogo extends StatelessWidget {
  const KassaLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.accent,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: CustomPaint(painter: _ReceiptPainter(c.onAccent, size * 0.58)),
    );
  }
}

class _ReceiptPainter extends CustomPainter {
  const _ReceiptPainter(this.color, this.icon);

  final Color color;
  final double icon;

  @override
  void paint(Canvas canvas, Size size) {
    final k = icon / 24;
    canvas.translate((size.width - icon) / 2, (size.height - icon) / 2);
    canvas.scale(k);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final receipt = Path()
      ..moveTo(6, 3)
      ..lineTo(18, 3)
      ..lineTo(18, 21)
      ..lineTo(15, 19)
      ..lineTo(12, 21)
      ..lineTo(9, 19)
      ..lineTo(6, 21)
      ..close();
    canvas.drawPath(receipt, paint);
    canvas.drawLine(const Offset(9.5, 8), const Offset(14.5, 8), paint);
    canvas.drawLine(const Offset(9.5, 12), const Offset(14.5, 12), paint);
  }

  @override
  bool shouldRepaint(_ReceiptPainter old) =>
      old.color != color || old.icon != icon;
}
