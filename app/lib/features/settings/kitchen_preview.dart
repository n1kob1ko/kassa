import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_language.dart';
import '../../data/providers.dart';
import '../../devices/kitchen_ticket_image.dart';
import '../../domain/catalog.dart';
import '../../domain/kitchen_ticket.dart';
import '../../domain/menu_dictionary.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/kitchen_texts.dart';
import '../../ui/tokens.dart';

const _noCatalog = Catalog(
  business: BusinessInfo(name: ''),
  categories: [],
  items: [],
  templates: [],
);

/// Der Beispiel-Küchenbon, wie er aus dem Drucker kommt: das Bild des
/// Zeichners auf Papier, höchstens [maxWidth] breit. Es steht in der Richtung
/// der Küchensprache, nicht der Bediensprache. Ändern sich Sprache,
/// Kategorien, Speisekarte, Wörterbuch oder Breite, bleibt das alte Bild
/// stehen, bis das neue fertig ist (kein Flackern, kein Ladekreis).
class KitchenPreview extends ConsumerStatefulWidget {
  const KitchenPreview({
    super.key,
    required this.language,
    required this.skipCategories,
    required this.widthDots,
    this.maxWidth = 300,
  });

  final AppLanguage language;
  final Set<String> skipCategories;

  /// Breite des Papiers in Punkten (Spalten des Druckers mal 12).
  final int widthDots;
  final double maxWidth;

  @override
  ConsumerState<KitchenPreview> createState() => _KitchenPreviewState();
}

class _KitchenPreviewState extends ConsumerState<KitchenPreview> {
  /// Das gezeigte Bild; gehört diesem Zustand und wird freigegeben, sobald
  /// ein neues da ist oder die Vorschau verschwindet.
  ui.Image? _image;

  /// Wofür zuletzt gezeichnet wurde; nur bei einer Änderung neu zeichnen.
  Object? _drawnFor;

  /// Ein späterer Auftrag gilt mehr als ein früherer, der noch läuft.
  int _generation = 0;

  @override
  void dispose() {
    _generation++;
    _image?.dispose();
    super.dispose();
  }

  Future<void> _paint(KitchenTicket ticket, int widthDots) async {
    final generation = ++_generation;
    final ui.Image image;
    try {
      image = await paintKitchenTicket(ticket, widthDots: widthDots);
    } catch (_) {
      // Ohne neues Bild bleibt das alte stehen.
      return;
    }
    if (!mounted || generation != _generation) {
      image.dispose();
      return;
    }
    final old = _image;
    setState(() => _image = image);
    old?.dispose();
  }

  void _paintIfChanged(Catalog catalog, MenuDictionary dictionary) {
    final skip = widget.skipCategories.toList()..sort();
    final inputs = (
      widget.language,
      skip.join('\u0000'),
      catalog,
      dictionary,
      widget.widthDots,
    );
    if (inputs == _drawnFor) return;
    _drawnFor = inputs;
    final language = widget.language;
    final ticket = sampleKitchenTicket(
      catalog,
      language: language,
      texts: kitchenTextsFor(language),
      dictionary: dictionary,
      skipCategories: widget.skipCategories,
      now: ref.read(clockProvider).now(),
    );
    _paint(ticket, widget.widthDots);
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    _paintIfChanged(
      ref.watch(catalogStreamProvider).value ?? _noCatalog,
      ref.watch(menuDictionaryProvider).value ?? MenuDictionary.empty,
    );
    final instant = MediaQuery.disableAnimationsOf(context);
    final image = _image;
    return LayoutBuilder(
      builder: (context, box) {
        final width = math.min(widget.maxWidth, box.maxWidth);
        // Das Bild füllt das Blatt innerhalb des Rands.
        final inner = width - 2 * KassaTokens.borderThin;
        // Vor dem ersten Bild: ein leeres Blatt in ungefährer Größe.
        final height = image == null
            ? inner * 0.8
            : inner * image.height / image.width;
        return Semantics(
          image: true,
          label: L10n.of(context).settingsKitchenPreview,
          child: Container(
            key: const Key('kitchen-preview'),
            width: width,
            decoration: BoxDecoration(
              color: KassaTokens.paper,
              borderRadius: BorderRadius.circular(KassaTokens.radiusXs),
              border: Border.all(color: c.line, width: KassaTokens.borderThin),
              boxShadow: c.cardShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: AnimatedSize(
              duration: instant ? Duration.zero : KassaTokens.motionSnack,
              curve: KassaTokens.motionCurve,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: inner,
                height: height,
                child: image == null
                    ? null
                    : RawImage(
                        image: image,
                        width: inner,
                        height: height,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
