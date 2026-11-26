// Zeichnet den Küchenbon als Bild, schwarz auf weiß, so breit wie das Papier
// des Druckers. Der Drucker kann nur westliche Schrift (PC858); Chinesisch,
// Türkisch und Arabisch kommen deshalb als Rasterbild an (`escpos.dart`).

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../domain/kitchen_ticket.dart';
import 'mono_image.dart';

/// Breite in Punkten: Spalten des Druckers mal 12 (48 -> 576, 32 -> 384, 42 -> 504).
Future<ui.Image> paintKitchenTicket(
  KitchenTicket ticket, {
  required int widthDots,
}) async {
  final layout = _TicketLayout(ticket, widthDots);
  final recorder = ui.PictureRecorder();
  final size = ui.Rect.fromLTWH(
    0,
    0,
    widthDots.toDouble(),
    layout.height.toDouble(),
  );
  final ui.Picture picture;
  try {
    layout.paint(
      ui.Canvas(recorder, size)..drawRect(size, ui.Paint()..color = _white),
    );
  } finally {
    // Auch wenn das Zeichnen scheitert: Aufnahme beenden, Texte freigeben.
    picture = recorder.endRecording();
    layout.dispose();
  }
  try {
    return await picture.toImage(widthDots, layout.height);
  } finally {
    picture.dispose();
  }
}

/// Wie [paintKitchenTicket], nach der Schwelle: ein Bit je Punkt.
Future<MonoImage> renderKitchenTicket(
  KitchenTicket ticket, {
  required int widthDots,
}) async {
  final image = await paintKitchenTicket(ticket, widthDots: widthDots);
  try {
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return MonoImage.fromRgba(
      rgba!.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
      image.width,
      image.height,
    );
  } finally {
    image.dispose();
  }
}

const _black = ui.Color(0xFF000000);
const _white = ui.Color(0xFFFFFFFF);

// Ohne ausdrückliche Familie und Ersatz zeigt der Zeichner Kästchen.
const _family = 'Figtree';
const _fallback = ['Noto Sans Arabic', 'Noto Sans SC'];

/// Hält Datum und Uhrzeit auch in einer arabischen Zeile von links nach
/// rechts (Unicode: LRI ... PDI).
String _ltr(String text) => '\u2066$text\u2069';

/// Ein Name in einer Zeile mit Ziffern: eigene Richtung (FSI ... PDI).
String _isolate(String text) => '\u2068$text\u2069';

String _two(int n) => n.toString().padLeft(2, '0');

/// Ein Text an seiner Stelle auf dem Zettel.
class _Placed {
  _Placed(this.paragraph, this.x, this.y);
  final ui.Paragraph paragraph;
  final double x;
  final double y;
}

/// Maße des Zettels für 576 Punkte; bei schmalerem Papier im selben
/// Verhältnis. Erst alles setzen und messen, dann zeichnen: die Höhe ergibt
/// sich aus dem Inhalt.
class _TicketLayout {
  _TicketLayout(this.ticket, this.width) : _scale = width / 576 {
    _build();
  }

  final KitchenTicket ticket;
  final int width;
  final double _scale;

  final _texts = <_Placed>[];
  final _bars = <ui.Rect>[];
  final _rules = <double>[];
  late final int height;

  ui.TextDirection get _direction =>
      ticket.language.isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr;

  double _px(double v) => v * _scale;

  double get _margin => _px(12);
  double get _content => width - 2 * _margin;

  /// Dicke der gestrichelten Linie: nie unter 3 Punkten, sonst geht sie in
  /// der Schwelle verloren.
  double get _ruleThickness => math.max(3, _px(3).roundToDouble());

  /// Links-Kante eines Kastens, der [offset] vom Anfang der Zeile beginnt;
  /// bei Arabisch vom rechten Rand gezählt.
  double _x(double offset, double boxWidth) => ticket.language.isRtl
      ? width - _margin - offset - boxWidth
      : _margin + offset;

  ui.Paragraph _text(
    String text, {
    required double size,
    required ui.FontWeight weight,
    required double width,
    ui.TextDirection? direction,
    ui.TextAlign align = ui.TextAlign.start,
    ui.Color color = _black,
    double lineHeight = 1.25,
  }) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textDirection: direction ?? _direction,
              textAlign: align,
              fontFamily: _family,
              fontSize: _px(size),
              fontWeight: weight,
              height: lineHeight,
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              color: color,
              fontFamily: _family,
              fontFamilyFallback: _fallback,
              fontSize: _px(size),
              fontWeight: weight,
              // Feste Zeilenhöhe für alle Schriften: Noto Sans Arabic und SC
              // brächten sonst viel mehr Abstand zwischen den Zeilen.
              height: lineHeight,
              leadingDistribution: ui.TextLeadingDistribution.even,
            ),
          )
          ..addText(text);
    return builder.build()..layout(ui.ParagraphConstraints(width: width));
  }

  /// Setzt [p] neu auf die Breite seines Textes, damit der Kasten genau so
  /// breit ist wie die Schrift (für Nummer und Anzahl).
  ui.Paragraph _tight(ui.Paragraph p) => p
    ..layout(
      ui.ParagraphConstraints(width: p.maxIntrinsicWidth.ceilToDouble()),
    );

  void _build() {
    var y = 0.0;

    // Banner: weiße Schrift auf schwarzem Balken über die ganze Breite.
    final banner = ticket.banner;
    if (banner != null && banner.isNotEmpty) {
      final pad = _px(10).roundToDouble();
      final text = _text(
        banner,
        size: 44,
        weight: ui.FontWeight.w800,
        width: _content,
        align: ui.TextAlign.center,
        color: _white,
      );
      final bar = (text.height + 2 * pad).ceilToDouble();
      _bars.add(ui.Rect.fromLTWH(0, 0, width.toDouble(), bar));
      _texts.add(_Placed(text, _margin, pad));
      y = bar;
    }
    y += _margin;

    // Kopf: Überschrift am Anfang, Nummer am Ende, auf einer Grundlinie.
    final number = _tight(
      _text(
        '${ticket.number}',
        size: 64,
        weight: ui.FontWeight.w800,
        width: _content,
        direction: ui.TextDirection.ltr,
      ),
    );
    final numberWidth = number.width;
    final title = _text(
      ticket.title,
      size: 52,
      weight: ui.FontWeight.w800,
      width: _content - numberWidth - _px(16),
    );
    final baseline = math.max(
      title.alphabeticBaseline,
      number.alphabeticBaseline,
    );
    final titleTop = y + baseline - title.alphabeticBaseline;
    final numberTop = y + baseline - number.alphabeticBaseline;
    _texts
      ..add(_Placed(title, _x(0, title.width), titleTop))
      ..add(
        _Placed(number, _x(_content - numberWidth, numberWidth), numberTop),
      );
    y = math.max(titleTop + title.height, numberTop + number.height);

    // Datum, Uhrzeit, Bedienung.
    final t = ticket.time;
    final date = '${_two(t.day)}.${_two(t.month)}.${t.year}';
    final time = '${_two(t.hour)}:${_two(t.minute)}';
    final meta = _text(
      '${_ltr(date)}   ${_ltr(time)}   ·   ${_isolate(ticket.staffName)}',
      size: 26,
      weight: ui.FontWeight.w600,
      width: _content,
    );
    _texts.add(_Placed(meta, _margin, y + _px(4)));
    y += _px(4) + meta.height;

    y += _px(14);
    _rules.add(y.roundToDouble());
    y += _ruleThickness + _px(18);

    // Zeilen: Anzahl in einer eigenen Spalte, der Name bricht in seiner
    // Spalte um; Zusatz und Optionen stehen unter dem Namen.
    final quantities = [
      for (final line in ticket.lines)
        _tight(
          _text(
            '${line.quantity}\u00A0×',
            size: 44,
            weight: ui.FontWeight.w800,
            width: _content,
          ),
        ),
    ];
    final quantityColumn = quantities.fold<double>(
      0,
      (w, p) => math.max(w, p.width),
    );
    final gap = _px(14);
    final nameOffset = quantityColumn + gap;
    final nameWidth = _content - nameOffset;

    for (var i = 0; i < ticket.lines.length; i++) {
      final line = ticket.lines[i];
      if (i > 0) y += _px(22);
      final name = _text(
        line.name,
        size: 44,
        weight: ui.FontWeight.w800,
        width: nameWidth,
        lineHeight: 1.2,
      );
      final quantity = quantities[i];
      final quantityWidth = quantity.width;
      final first = math.max(
        name.alphabeticBaseline,
        quantity.alphabeticBaseline,
      );
      final nameTop = y + first - name.alphabeticBaseline;
      final quantityTop = y + first - quantity.alphabeticBaseline;
      // Die Anzahl steht bündig an der Namensspalte, damit die "×"
      // untereinander stehen. Bei Arabisch gespiegelt ("× 2", von rechts
      // gelesen "2 ×"); die Ziffern einer Zahl bleiben in ihrer Reihenfolge.
      final quantityLeft = _x(quantityColumn - quantityWidth, quantityWidth);
      _texts
        ..add(_Placed(quantity, quantityLeft, quantityTop))
        ..add(_Placed(name, _x(nameOffset, nameWidth), nameTop));
      var bottom = nameTop + name.height;

      final info = line.info;
      if (info != null && info.isNotEmpty) {
        final p = _text(
          info,
          size: 30,
          weight: ui.FontWeight.w600,
          width: nameWidth,
        );
        _texts.add(_Placed(p, _x(nameOffset, nameWidth), bottom));
        bottom += p.height;
      }
      if (line.options.isNotEmpty) bottom += _px(2);
      for (final option in line.options) {
        final p = _text(
          option,
          size: 34,
          weight: ui.FontWeight.w600,
          width: nameWidth,
        );
        _texts.add(_Placed(p, _x(nameOffset, nameWidth), bottom));
        bottom += p.height;
      }
      y = math.max(bottom, quantityTop + quantity.height);
    }

    y += _px(18);
    _rules.add(y.roundToDouble());
    y += _ruleThickness + _px(24);
    height = y.ceil();
  }

  void paint(ui.Canvas canvas) {
    final black = ui.Paint()..color = _black;
    for (final bar in _bars) {
      canvas.drawRect(bar, black);
    }
    // Gestrichelt, auf ganze Punkte gesetzt: keine grauen Kanten.
    final dash = _px(14).roundToDouble();
    final space = _px(10).roundToDouble();
    final left = _margin.roundToDouble();
    final right = (width - _margin).roundToDouble();
    for (final top in _rules) {
      for (var x = left; x < right; x += dash + space) {
        canvas.drawRect(
          ui.Rect.fromLTRB(
            x,
            top,
            math.min(x + dash, right),
            top + _ruleThickness,
          ),
          black,
        );
      }
    }
    for (final t in _texts) {
      canvas.drawParagraph(t.paragraph, ui.Offset(t.x, t.y.roundToDouble()));
    }
  }

  void dispose() {
    for (final t in _texts) {
      t.paragraph.dispose();
    }
  }
}
