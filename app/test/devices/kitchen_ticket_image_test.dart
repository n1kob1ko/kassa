import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/devices/kitchen_ticket_image.dart';
import 'package:kassa/devices/mono_image.dart';
import 'package:kassa/domain/kitchen_ticket.dart';

import '../support/pump.dart';

KitchenTicket _ticket(
  AppLanguage language,
  List<KitchenLine> lines, {
  String title = 'MUTFAK',
  String? banner,
}) => KitchenTicket(
  language: language,
  kind: banner == null ? KitchenTicketKind.order : KitchenTicketKind.voided,
  title: title,
  banner: banner,
  number: 128,
  time: DateTime(2026, 11, 26, 14, 32),
  staffName: 'Ayşe',
  lines: lines,
);

/// Zeilen, in denen die gestrichelte Linie liegt: viele Wechsel zwischen
/// Schwarz und Weiß und fast die halbe Breite schwarz.
List<int> _ruleRows(MonoImage image) => [
  for (var y = 0; y < image.height; y++)
    if (_runs(image, y) >= 20 && _black(image, y) > image.width * 0.4) y,
];

int _runs(MonoImage image, int y) {
  var runs = 0;
  for (var x = 1; x < image.width; x++) {
    if (image.at(x, y) && !image.at(x - 1, y)) runs++;
  }
  return runs;
}

int _black(MonoImage image, int y) => [
  for (var x = 0; x < image.width; x++)
    if (image.at(x, y)) x,
].length;

/// Mittlere Spalte der schwarzen Punkte zwischen den beiden Linien.
double _centerOfLines(MonoImage image) {
  final rules = _ruleRows(image);
  expect(rules, isNotEmpty);
  final from = rules.first + 4, to = rules.last - 4;
  var sum = 0, count = 0;
  for (var y = from; y < to; y++) {
    if (rules.contains(y)) continue;
    for (var x = 0; x < image.width; x++) {
      if (image.at(x, y)) {
        sum += x;
        count++;
      }
    }
  }
  expect(count, greaterThan(0));
  return sum / count;
}

/// Kein schwarzer Punkt in den [margin] Punkten am Rand rundum.
void _expectWhiteMargin(MonoImage image, int margin) {
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final inside =
          x >= margin &&
          x < image.width - margin &&
          y >= margin &&
          y < image.height - margin;
      if (!inside && image.at(x, y)) fail('Punkt am Rand bei ($x, $y)');
    }
  }
}

const _longName = 'Izgara köfte pilav, salata ve közlenmiş biber';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundledFonts);

  const doner = KitchenLine(
    quantity: 2,
    name: 'Tavuk şiş dürüm',
    options: ['Acı sos', 'Soğansız'],
  );
  const soup = KitchenLine(quantity: 1, name: 'Mercimek çorbası');
  const ayran = KitchenLine(quantity: 1, name: 'Ayran');

  test('Breite genau widthDots, bei 576, 504 und 384', () async {
    for (final width in [576, 504, 384]) {
      final image = await renderKitchenTicket(
        _ticket(AppLanguage.tr, [doner]),
        widthDots: width,
      );
      expect(image.width, width);
      expect(image.rowBytes, (width + 7) ~/ 8);
      expect(image.bits.length, image.rowBytes * image.height);
    }
  });

  test('das Bild aus dart:ui hat dieselbe Größe', () async {
    final ticket = _ticket(AppLanguage.tr, [doner]);
    final picture = await paintKitchenTicket(ticket, widthDots: 576);
    final mono = await renderKitchenTicket(ticket, widthDots: 576);
    expect(picture.width, 576);
    expect(picture.height, mono.height);
    picture.dispose();
  });

  test('Höhe wächst mit den Zeilen', () async {
    final one = await renderKitchenTicket(
      _ticket(AppLanguage.tr, [ayran]),
      widthDots: 576,
    );
    final three = await renderKitchenTicket(
      _ticket(AppLanguage.tr, [doner, soup, ayran]),
      widthDots: 576,
    );
    expect(three.height, greaterThan(one.height + 100));
  });

  test('bei tr liegt die Namenszeile links, bei ar rechts', () async {
    final tr = await renderKitchenTicket(
      _ticket(AppLanguage.tr, [ayran]),
      widthDots: 576,
    );
    final ar = await renderKitchenTicket(
      _ticket(AppLanguage.ar, const [
        KitchenLine(quantity: 1, name: 'شاي'),
      ], title: 'المطبخ'),
      widthDots: 576,
    );
    expect(_centerOfLines(tr), lessThan(576 / 2));
    expect(_centerOfLines(ar), greaterThan(576 / 2));
  });

  test('ein Name mit 45 Zeichen bricht um statt überzulaufen', () async {
    final short = await renderKitchenTicket(
      _ticket(AppLanguage.tr, [ayran]),
      widthDots: 384,
    );
    final long = await renderKitchenTicket(
      _ticket(AppLanguage.tr, const [
        KitchenLine(quantity: 12, name: _longName),
      ]),
      widthDots: 384,
    );
    expect(_longName, hasLength(45));
    expect(long.width, 384);
    expect(long.height, greaterThan(short.height + 30));
    _expectWhiteMargin(long, 8);
  });

  test('kein Punkt außerhalb: Rand rundum weiß, in jeder Sprache', () async {
    for (final language in AppLanguage.values) {
      final image = await renderKitchenTicket(
        _ticket(language, [doner, soup]),
        widthDots: 576,
      );
      _expectWhiteMargin(image, 12);
    }
  });

  test('ar mit deutschen Namen: eine Zahl am Anfang bleibt vorne', () async {
    // Mit und ohne führende Zahl: steht der deutsche Name als eigener
    // Abschnitt von links nach rechts, endet er rechts gleich ("...rollen"),
    // und die rechte Hälfte des Zettels ist fast Punkt für Punkt dieselbe. Ohne
    // eigenen Abschnitt rückt die "3" ans Ende, neben die Anzahl.
    Future<MonoImage> render(String prefix) => renderKitchenTicket(
      _ticket(AppLanguage.ar, [
        KitchenLine(
          quantity: 2,
          name: '${prefix}Frühlingsrollen',
          info: '${prefix}Falafel',
          options: ['${prefix}Fladen'],
        ),
      ], title: 'المطبخ'),
      widthDots: 576,
    );
    final digits = await render('3 ');
    final plain = await render('');
    expect(digits.height, plain.height);
    var differing = 0, ink = 0;
    for (var y = 0; y < plain.height; y++) {
      for (var x = 288; x < 576; x++) {
        if (plain.at(x, y)) ink++;
        if (digits.at(x, y) != plain.at(x, y)) differing++;
      }
    }
    // Kanten einzelner Buchstaben dürfen um einen Punkt anders fallen
    // (Laufweite); eine Zahl am falschen Ende sind tausende Punkte.
    expect(differing, lessThan(ink * 0.05));
  });

  test('mit Banner: oben über die ganze Breite schwarz', () async {
    final image = await renderKitchenTicket(
      _ticket(AppLanguage.de, [soup], banner: 'STORNO'),
      widthDots: 576,
    );
    expect(image.at(0, 2), isTrue);
    expect(image.at(575, 2), isTrue);
    expect(image.at(288, 2), isTrue);
  });
}
