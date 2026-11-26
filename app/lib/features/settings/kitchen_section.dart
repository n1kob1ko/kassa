import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_language.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../devices/printer.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/language_picker.dart';
import '../../ui/ltr.dart';
import '../../ui/menu_text.dart';
import '../../ui/primary_button.dart';
import '../../ui/print_problem_text.dart';
import '../../ui/segmented.dart';
import '../../ui/tokens.dart';
import '../kassa/kitchen_service.dart';
import 'kitchen_preview.dart';
import 'printer_panel.dart';
import 'settings_rows.dart';

/// Ab dieser Breite des Abschnitts steht die Vorschau neben den Kategorien,
/// sonst darunter (Vorschau 300, Abstand, Kategorien mindestens 220).
const _sideBySide = 300 + KassaTokens.spaceHuge + 220;

/// Der Abschnitt "Küche" der Einstellungen: wo der Küchenbon kommt (drei
/// Segmente) und, wenn er nicht "Aus" ist, Sprache am Küchenbon, der
/// Küchendrucker, die Kategorien für die Küche, die Vorschau und "Probe
/// drucken". Jede Änderung geht über [onChange] und wird sofort gespeichert.
class KitchenSection extends ConsumerStatefulWidget {
  const KitchenSection({
    super.key,
    required this.settings,
    required this.onChange,
  });

  final RegisterSettings settings;
  final Future<void> Function(
    RegisterSettings Function(RegisterSettings s) change,
  )
  onChange;

  @override
  ConsumerState<KitchenSection> createState() => _KitchenSectionState();
}

class _KitchenSectionState extends ConsumerState<KitchenSection>
    with SingleTickerProviderStateMixin {
  /// Ein- und Ausblenden der Zeilen unter den Segmenten (Höhe und Deckkraft
  /// zusammen); ein Tipp mitten im Übergang kehrt ihn von dort aus um.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: KassaTokens.motionSnack,
    value: widget.settings.kitchenMode == KitchenMode.off ? 0 : 1,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _reveal,
    curve: KassaTokens.motionCurve,
  );

  /// Der zuletzt eingeschaltete Ort: beim Ausblenden bleiben seine Zeilen
  /// stehen, bis sie weg sind.
  late KitchenMode _shown = widget.settings.kitchenMode == KitchenMode.off
      ? KitchenMode.receiptPrinter
      : widget.settings.kitchenMode;

  bool _sampling = false;
  PrintOutcome? _sample;

  /// Ein Wechsel des Orts macht eine laufende Probe ungültig.
  int _sampleGeneration = 0;

  @override
  void didUpdateWidget(KitchenSection old) {
    super.didUpdateWidget(old);
    final mode = widget.settings.kitchenMode;
    if (mode == old.settings.kitchenMode) return;
    if (mode != KitchenMode.off) _shown = mode;
    // Das Ergebnis der Probe galt dem bisherigen Ort.
    _sample = null;
    _sampleGeneration++;
    final show = mode != KitchenMode.off;
    if (MediaQuery.disableAnimationsOf(context)) {
      _reveal.value = show ? 1 : 0;
    } else {
      // Läuft der Übergang noch, kehrt er von der Stelle aus um.
      show ? _reveal.forward() : _reveal.reverse();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  Future<void> _printSample() async {
    if (_sampling) return;
    final generation = _sampleGeneration;
    setState(() => _sampling = true);
    PrintOutcome outcome;
    try {
      outcome = await ref.read(kitchenServiceProvider).printSample();
    } catch (_) {
      outcome = const PrintOutcome.failed(PrintProblem.unreachable);
    }
    if (!mounted) return;
    setState(() {
      _sampling = false;
      if (generation == _sampleGeneration) _sample = outcome;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final s = widget.settings;
    return SettingsCard(
      key: const Key('kitchen-card'),
      title: l.settingsKitchen,
      rows: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Block(
              title: l.settingsKitchenMode,
              child: Segmented<KitchenMode>(
                expand: true,
                segments: [
                  (KitchenMode.off, l.settingsKitchenOff),
                  (
                    KitchenMode.receiptPrinter,
                    l.settingsKitchenAtReceiptPrinter,
                  ),
                  (
                    KitchenMode.kitchenPrinter,
                    l.settingsKitchenAtKitchenPrinter,
                  ),
                ],
                selected: s.kitchenMode,
                keyFor: (m) => Key('kitchen-mode-${m.name}'),
                onSelected: (m) =>
                    widget.onChange((s) => s.copyWith(kitchenMode: m)),
              ),
            ),
            AnimatedBuilder(
              animation: _reveal,
              builder: (context, child) => _reveal.isDismissed
                  ? const SizedBox.shrink()
                  : ClipRect(
                      child: SizeTransition(
                        sizeFactor: _curve,
                        alignment: AlignmentDirectional.topCenter,
                        child: FadeTransition(opacity: _curve, child: child),
                      ),
                    ),
              child: _details(context, s),
            ),
          ],
        ),
      ],
    );
  }

  /// Die Zeilen, die nur bei "Am Bondrucker" und "Am Küchendrucker" stehen.
  Widget _details(BuildContext context, RegisterSettings s) {
    final l = L10n.of(context);
    final instant = MediaQuery.disableAnimationsOf(context);
    final atKitchen = _shown == KitchenMode.kitchenPrinter;
    final columns = atKitchen ? s.kitchenPrinterColumns : s.printerColumns;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Line(),
        _Block(
          title: l.settingsKitchenLanguage,
          child: LanguagePicker(
            keyPrefix: 'kitchen-language',
            value: s.kitchenLanguage,
            onChanged: (language) =>
                widget.onChange((s) => s.copyWith(kitchenLanguage: language)),
          ),
        ),
        AnimatedSize(
          duration: instant ? Duration.zero : KassaTokens.motionSnack,
          curve: KassaTokens.motionCurve,
          alignment: AlignmentDirectional.topCenter,
          child: atKitchen
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Line(),
                    // Die Seite zum Einrichten bleibt Deutsch, wie beim
                    // Bondrucker.
                    const Ltr(child: PrinterPanel.kitchen()),
                    if (s.kitchenPrinterKind == PrinterKind.none)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(bottom: 14),
                        child: _Notice(
                          key: const Key('kitchen-no-printer'),
                          text: l.settingsKitchenNoPrinter,
                          ok: false,
                        ),
                      ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
        const _Line(),
        LayoutBuilder(
          builder: (context, box) {
            final categories = _Categories(
              skip: s.kitchenSkipCategories,
              onChanged: (id, on) => widget.onChange((s) {
                final skip = {...s.kitchenSkipCategories};
                on ? skip.remove(id) : skip.add(id);
                return s.copyWith(kitchenSkipCategories: skip);
              }),
            );
            final preview = _PreviewColumn(
              language: s.kitchenLanguage,
              skip: s.kitchenSkipCategories,
              widthDots: columns * 12,
              sampling: _sampling,
              sample: _sample,
              mode: _shown,
              onSample: _printSample,
            );
            if (box.maxWidth >= _sideBySide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: categories),
                  const SizedBox(width: KassaTokens.spaceHuge),
                  SizedBox(width: 300, child: preview),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                categories,
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: preview,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: KassaTokens.spaceLg),
      ],
    );
  }
}

/// Überschrift (16 dp 700) und darunter ein breites Bedienelement.
class _Block extends StatelessWidget {
  const _Block({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Title(title),
          const SizedBox(height: KassaTokens.spaceXl),
          child,
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium!
          .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }
}

/// 1 dp Trennlinie wie zwischen den Zeilen einer Karte.
class _Line extends StatelessWidget {
  const _Line();

  @override
  Widget build(BuildContext context) => Container(
    height: KassaTokens.borderThin,
    color: KassaColors.of(context).line,
  );
}

/// "Kategorien für die Küche": je Kategorie der Speisekarte ein Schalter,
/// der Name in der Bediensprache.
class _Categories extends ConsumerWidget {
  const _Categories({required this.skip, required this.onChanged});

  final Set<String> skip;
  final void Function(String categoryId, bool on) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = KassaColors.of(context);
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final name = ref.watch(menuTextProvider);
    final categories =
        ref.watch(catalogStreamProvider).value?.categories ?? const [];
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Title(l.settingsKitchenCategories),
          const SizedBox(height: KassaTokens.spaceSm),
          for (final k in categories)
            Builder(
              builder: (context) {
                final on = !skip.contains(k.id);
                final label = name(k.name);
                return ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: text.bodyMedium!.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              on
                                  ? l.settingsKitchenCategoryOn
                                  : l.settingsKitchenCategoryOff,
                              style: text.bodySmall!.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                height: 1.3,
                                color: c.ink2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: KassaTokens.spaceXl),
                      RowToggle(
                        key: Key('kitchen-category-${k.id}'),
                        label: label,
                        value: on,
                        onChanged: (v) => onChanged(k.id, v),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Vorschau, "Probe drucken" und darunter das Ergebnis der Probe. Die Zeile
/// für das Ergebnis ist immer da, damit nichts springt, wenn es erscheint.
class _PreviewColumn extends StatelessWidget {
  const _PreviewColumn({
    required this.language,
    required this.skip,
    required this.widthDots,
    required this.sampling,
    required this.sample,
    required this.mode,
    required this.onSample,
  });

  final AppLanguage language;
  final Set<String> skip;
  final int widthDots;
  final bool sampling;
  final PrintOutcome? sample;
  final KitchenMode mode;
  final VoidCallback onSample;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final result = sample;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Text(
              l.settingsKitchenPreview,
              style: text.bodySmall!.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: c.ink2,
              ),
            ),
          ),
          const SizedBox(height: KassaTokens.spaceMd),
          Center(
            child: KitchenPreview(
              language: language,
              skipCategories: skip,
              widthDots: widthDots,
            ),
          ),
          const SizedBox(height: KassaTokens.spaceXxl),
          PrimaryButton(
            key: const Key('kitchen-sample'),
            label: sampling
                ? l.settingsKitchenSamplePrinting
                : l.settingsKitchenSample,
            icon: LucideIcons.printer,
            filled: false,
            height: 64,
            onPressed: sampling ? null : onSample,
          ),
          const SizedBox(height: KassaTokens.spaceMd),
          // Zwei Zeilen Platz, ob ein Ergebnis da ist oder nicht.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Semantics(
              liveRegion: true,
              child: result == null || sampling
                  ? const SizedBox.shrink()
                  : _Notice(
                      key: const Key('kitchen-sample-result'),
                      text: result.ok
                          ? l.settingsKitchenSamplePrinted
                          : kitchenProblemText(l, result.problem!, mode),
                      ok: result.ok,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Eine Zeile mit Zeichen: in Ordnung (Haken, grün) oder Warnung (Dreieck,
/// Warnfarbe). Der Zustand steht im Satz, Zeichen und Farbe ergänzen ihn.
class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.text, required this.ok});

  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final color = ok ? c.veganFg : c.warnInk;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 1),
          child: Icon(
            ok ? LucideIcons.check : LucideIcons.triangleAlert,
            size: 18,
            color: color,
          ),
        ),
        const SizedBox(width: KassaTokens.spaceMd),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
