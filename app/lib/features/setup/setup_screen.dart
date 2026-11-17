import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../domain/catalog.dart';
import '../../domain/menu_import.dart';
import '../../domain/staff.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import '../../ui/kassa_logo.dart';
import '../login/pin_screen.dart';
import '../login/session.dart';
import 'menu_file_picker.dart';

enum _Step { start, read, problems, pin }

/// Ersteinrichtung: Speisekarte einspielen, dann die Chef-PIN festlegen.
/// Geschrieben wird erst, wenn die PIN bestätigt ist.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  _Step _step = _Step.start;
  Catalog? _catalog;
  List<String> _problems = const [];

  // Chef-PIN
  String _pin = '';
  String? _first;
  String? _error;
  bool _busy = false;

  void _show(Catalog catalog) => setState(() {
    _catalog = catalog;
    _step = _Step.read;
  });

  Future<void> _pickFile() async {
    final String? text;
    try {
      text = await ref.read(menuFilePickerProvider).pickText();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _problems = const ['Die Datei konnte nicht geöffnet werden. Bitte nochmal versuchen.'];
        _step = _Step.problems;
      });
      return;
    }
    if (text == null || !mounted) return;
    try {
      _show(parseMenuFile(text));
    } on MenuImportException catch (e) {
      setState(() {
        _problems = e.problems;
        _step = _Step.problems;
      });
    }
  }

  Future<void> _useDemo() async {
    final text = await ref.read(demoMenuTextProvider)();
    if (!mounted) return;
    _startPin(parseMenuFile(text));
  }

  void _startPin(Catalog catalog) => setState(() {
    _catalog = catalog;
    _step = _Step.pin;
    _pin = '';
    _first = null;
    _error = null;
  });

  void _backToStart() => setState(() => _step = _Step.start);

  Future<void> _onPinKey(String key) async {
    if (_busy) return;
    if (key == 'back') {
      setState(() {
        _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1);
        _error = null;
      });
      return;
    }
    if (_pin.length >= 4 || key.length != 1) return;
    final pin = _pin + key;
    if (pin.length < 4) {
      setState(() {
        _pin = pin;
        _error = null;
      });
      return;
    }
    final first = _first;
    if (first == null) {
      final taken = _catalog!.staffSeeds.any((s) => s.pin == pin);
      setState(() {
        _pin = '';
        _first = taken ? null : pin;
        _error = taken
            ? 'Diese PIN hat schon jemand aus der Datei. '
                  'Bitte eine andere wählen.'
            : null;
      });
    } else if (pin != first) {
      setState(() {
        _pin = '';
        _first = null;
        _error = 'Die PINs sind nicht gleich. Bitte noch einmal.';
      });
    } else {
      setState(() => _pin = pin);
      await _finish(pin);
    }
  }

  /// Schreibt Speisekarte, Mitarbeiter und Chef in einem Zug. Bricht etwas
  /// ab, bleibt nichts Halbes zurück.
  Future<void> _finish(String pin) async {
    _busy = true;
    final catalog = _catalog!;
    try {
      final catalogs = ref.read(catalogRepositoryProvider);
      final staff = ref.read(staffRepositoryProvider);
      await ref.read(databaseProvider).transaction(() async {
        await catalogs.importCatalog(catalog);
        for (final s in catalog.staffSeeds) {
          await staff.create(name: s.name, pin: s.pin, role: s.role);
        }
        await staff.create(name: 'Chef', pin: pin, role: StaffRole.chef);
      });
      await ref.read(sessionProvider.notifier).login(pin);
      ref.invalidate(catalogProvider);
    } catch (_) {
      if (mounted) {
        setState(() {
          _pin = '';
          _first = null;
          _error = 'Das Einrichten hat nicht geklappt. Bitte noch einmal.';
        });
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    if (_step == _Step.pin) {
      return Scaffold(
        backgroundColor: c.ground,
        body: PinCard(
          businessName: _catalog!.businessName,
          title: _first == null ? 'Chef-PIN festlegen' : 'PIN wiederholen',
          hint:
              _error ??
              (_first == null
                  ? 'Vier Ziffern, die nur der Chef kennt'
                  : 'Zur Sicherheit noch einmal'),
          hintIsError: _error != null,
          filled: _pin.length,
          onKey: _onPinKey,
        ),
      );
    }
    return Scaffold(
      backgroundColor: c.ground,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(KassaTokens.spaceHuge),
          child: Container(
            width: 560,
            padding: const EdgeInsets.fromLTRB(40, 40, 40, 32),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(KassaTokens.radiusCard),
              border: Border.all(color: c.line, width: KassaTokens.borderThin),
              boxShadow: c.cardShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _CardHeader(),
                const SizedBox(height: KassaTokens.spaceHuge),
                ..._content(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context) {
    const gap = SizedBox(height: KassaTokens.spaceHuge);
    switch (_step) {
      case _Step.start:
        return [
          const _Heading(
            'Diese Kassa einrichten',
            'Spiel zuerst die Speisekarte des Betriebs ein. '
                'Danach legst du die PIN für den Chef fest.',
          ),
          gap,
          _ActionTile(
            key: const Key('setup-file'),
            icon: LucideIcons.fileUp,
            label: 'Speisekarte einspielen',
            sublabel: 'Datei vom Tablet auswählen',
            filled: true,
            onTap: _pickFile,
          ),
          const SizedBox(height: KassaTokens.spaceXl),
          _ActionTile(
            key: const Key('setup-demo'),
            icon: LucideIcons.play,
            label: 'Mit Beispieldaten starten',
            sublabel: 'Zum Ausprobieren, mit einem erfundenen Imbiss',
            filled: false,
            onTap: _useDemo,
          ),
        ];
      case _Step.read:
        final catalog = _catalog!;
        return [
          const _Heading(
            'Speisekarte gelesen',
            'Bitte kurz prüfen, ob das stimmt.',
          ),
          gap,
          _Summary(
            rows: [
              ('Betrieb', catalog.businessName),
              ('Kategorien', '${catalog.categories.length}'),
              ('Artikel', '${catalog.items.length}'),
              ('Auswahl-Vorlagen', '${catalog.templates.length}'),
              if (catalog.staffSeeds.isNotEmpty)
                ('Mitarbeiter', '${catalog.staffSeeds.length}'),
            ],
          ),
          gap,
          Row(
            children: [
              SizedBox(
                width: 160,
                child: PrimaryButton(
                  label: 'Andere Datei',
                  filled: false,
                  onPressed: _backToStart,
                ),
              ),
              const SizedBox(width: KassaTokens.spaceXl),
              Expanded(
                child: PrimaryButton(
                  label: 'Weiter zur Chef-PIN',
                  onPressed: () => _startPin(catalog),
                ),
              ),
            ],
          ),
        ];
      case _Step.problems:
        return [
          const _Heading(
            'Die Datei passt noch nicht',
            'Es wurde nichts eingespielt. '
                'Das muss in der Datei geändert werden:',
          ),
          gap,
          ProblemList(problems: _problems),
          gap,
          PrimaryButton(label: 'Andere Datei wählen', onPressed: _backToStart),
        ];
      case _Step.pin:
        return const [];
    }
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader();

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        const KassaLogo(size: 44),
        const SizedBox(width: KassaTokens.spaceXl),
        Text('Kassa', style: text.headlineMedium!.copyWith(fontSize: 26)),
        const Spacer(),
        Text(
          'Schritt 1 von 2',
          style: text.bodyMedium!.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: c.ink2,
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.sub);

  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: text.headlineLarge!.copyWith(fontSize: 30),
        ),
        const SizedBox(height: KassaTokens.spaceMd),
        Text(
          sub,
          style: text.bodyMedium!.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.4,
            color: KassaColors.of(context).ink2,
          ),
        ),
      ],
    );
  }
}

/// Große Aktion der Startseite: Symbol links, Text linksbündig.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final fg = filled ? c.onAccent : c.ink;
    return Pressable(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: filled ? 80 : 72),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: filled ? c.accent : c.card,
          borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
          border: filled
              ? null
              : Border.all(color: c.line, width: KassaTokens.borderButton),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: filled ? c.onAccent : c.accentInk),
            const SizedBox(width: KassaTokens.spaceXxl),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: text.titleLarge!.copyWith(
                      fontSize: filled ? 20 : 18,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: KassaTokens.spaceXxs),
                  Text(
                    sublabel,
                    style: text.bodyMedium!.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: filled ? fg.withValues(alpha: 0.85) : c.ink2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme.bodyMedium!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: c.fill,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(top: BorderSide(color: c.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[i].$1,
                      style: text.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.ink2,
                      ),
                    ),
                  ),
                  const SizedBox(width: KassaTokens.spaceXl),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Text(
                      rows[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      key: Key('summary-${rows[i].$1}'),
                      textAlign: TextAlign.right,
                      style: text.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Alle Fehler der Datei, einer pro Zeile. Sind es viele, rollt die Liste.
/// Auch die Einstellungen zeigen sie.
class ProblemList extends StatelessWidget {
  const ProblemList({super.key, required this.problems});

  final List<String> problems;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.6,
      color: c.warnInk,
    );
    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: c.warnBg,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
      ),
      child: Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in problems)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 6, right: 12),
                      child: Text('•', style: style),
                    ),
                    Expanded(child: Text(p, style: style)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
