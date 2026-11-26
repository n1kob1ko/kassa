import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/devices/kitchen_ticket_image.dart';
import 'package:kassa/devices/mono_image.dart';
import 'package:kassa/domain/kitchen_ticket.dart';

import '../support/pump.dart';

// Bildvergleich des Küchenbons, so wie er aus dem Drucker kommt: nach der
// Schwelle, schwarz oder weiß je Punkt. Neu erzeugen mit
// `flutter test --update-goldens test/golden/kitchen_ticket_golden_test.dart`.

/// Erfundene Zeilen je Sprache: ein Artikel mit Zusatz und zwei Optionen, ein
/// Artikel mit langem Namen, ein kurzer.
const _samples = {
  AppLanguage.de: (
    'KÜCHE',
    [
      KitchenLine(
        quantity: 2,
        name: 'Huhn Bowl',
        info: 'scharf',
        options: ['XXL', 'Nudeln'],
      ),
      KitchenLine(quantity: 1, name: 'Gemüse Bowl mit Erdnusssauce und Sesam'),
      KitchenLine(quantity: 12, name: 'Teigtaschen'),
    ],
  ),
  AppLanguage.en: (
    'KITCHEN',
    [
      KitchenLine(
        quantity: 2,
        name: 'Chicken bowl',
        info: 'spicy',
        options: ['XXL', 'Noodles'],
      ),
      KitchenLine(
        quantity: 1,
        name: 'Vegetable bowl with peanut sauce and sesame',
      ),
      KitchenLine(quantity: 12, name: 'Dumplings'),
    ],
  ),
  AppLanguage.zh: (
    '厨房',
    [
      KitchenLine(quantity: 2, name: '鸡肉饭碗', info: '辣', options: ['特大', '面条']),
      KitchenLine(quantity: 1, name: '蔬菜饭碗配花生酱和芝麻，少盐少油不要香菜'),
      KitchenLine(quantity: 12, name: '饺子'),
    ],
  ),
  AppLanguage.tr: (
    'MUTFAK',
    [
      KitchenLine(
        quantity: 2,
        name: 'Tavuk şiş dürüm',
        info: 'acılı',
        options: ['Acı sos', 'Soğansız'],
      ),
      KitchenLine(
        quantity: 1,
        name: 'Izgara köfte pilav, salata ve közlenmiş biber',
      ),
      KitchenLine(quantity: 12, name: 'Mercimek çorbası'),
    ],
  ),
  AppLanguage.ar: (
    'المطبخ',
    [
      KitchenLine(
        quantity: 2,
        name: 'طبق دجاج',
        info: 'حار',
        options: ['كبير جدًا', 'معكرونة'],
      ),
      KitchenLine(quantity: 1, name: 'طبق خضار مع صلصة الفول السوداني والسمسم'),
      KitchenLine(quantity: 12, name: 'زلابية'),
    ],
  ),
};

KitchenTicket _ticket(AppLanguage language, {String? banner}) {
  final (title, lines) = _samples[language]!;
  return KitchenTicket(
    language: language,
    kind: banner == null ? KitchenTicketKind.order : KitchenTicketKind.voided,
    title: title,
    banner: banner,
    number: 128,
    time: DateTime(2026, 11, 26, 14, 32),
    staffName: 'Ayşe',
    lines: lines,
  );
}

/// Das Bild nach der Schwelle zurück in Farbe, für den Vergleich als PNG.
Future<ui.Image> _toImage(MonoImage mono) async {
  final rgba = Uint8List(mono.width * mono.height * 4);
  for (var y = 0; y < mono.height; y++) {
    for (var x = 0; x < mono.width; x++) {
      final v = mono.at(x, y) ? 0 : 255;
      final i = (y * mono.width + x) * 4;
      rgba
        ..[i] = v
        ..[i + 1] = v
        ..[i + 2] = v
        ..[i + 3] = 255;
    }
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: mono.width,
    height: mono.height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  return (await codec.getNextFrame()).image;
}

Future<void> _expectGolden(KitchenTicket ticket, int width, String file) async {
  final mono = await renderKitchenTicket(ticket, widthDots: width);
  final image = await _toImage(mono);
  await expectLater(image, matchesGoldenFile('goldens/$file.png'));
  image.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundledFonts);

  for (final language in AppLanguage.values) {
    test('Küchenbon ${language.name} bei 576 Punkten', () async {
      await _expectGolden(
        _ticket(language),
        576,
        'kuechenbon_${language.name}_576',
      );
    });
  }

  test('Küchenbon tr bei 384 Punkten', () async {
    await _expectGolden(_ticket(AppLanguage.tr), 384, 'kuechenbon_tr_384');
  });

  test('Küchenbon Storno (de) bei 576 Punkten', () async {
    await _expectGolden(
      _ticket(AppLanguage.de, banner: 'STORNO'),
      576,
      'kuechenbon_storno_576',
    );
  });

  test('Küchenbon ar mit deutschen Namen aus der Speisekarte', () async {
    // Fehlt die Übersetzung, steht der Name der Speisekarte da: eine Zahl
    // am Anfang und ein Satzzeichen am Ende bleiben, wo sie hingehören.
    await _expectGolden(
      KitchenTicket(
        language: AppLanguage.ar,
        kind: KitchenTicketKind.order,
        title: 'المطبخ',
        number: 128,
        time: DateTime(2026, 11, 26, 14, 32),
        staffName: 'Ayşe',
        lines: const [
          KitchenLine(
            quantity: 2,
            name: '3 Frühlingsrollen',
            info: '5 Stück',
            options: ['2 Saucen', 'Extra scharf!'],
          ),
          KitchenLine(quantity: 1, name: 'طبق دجاج', options: ['حار']),
        ],
      ),
      576,
      'kuechenbon_arabisch_gemischt',
    );
  });

  test('Küchenbon Storno (ar) bei 576 Punkten', () async {
    await _expectGolden(
      _ticket(AppLanguage.ar, banner: 'إلغاء'),
      576,
      'kuechenbon_storno_ar_576',
    );
  });
}
