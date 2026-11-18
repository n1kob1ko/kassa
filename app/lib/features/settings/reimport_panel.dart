import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../domain/catalog.dart';
import '../../domain/menu_import.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import '../items/item_detail.dart' show FailedHint;
import '../setup/menu_file_picker.dart';
import '../setup/setup_screen.dart' show ProblemList;
import 'settings_rows.dart';

enum _Step { idle, problems, confirm, done }

/// Die Zeile "Speisekarte neu einspielen" samt Rückfrage und Ergebnis, alles
/// in der Karte, ohne Dialog.
class ReimportPanel extends ConsumerStatefulWidget {
  const ReimportPanel({super.key});

  @override
  ConsumerState<ReimportPanel> createState() => _ReimportPanelState();
}

class _ReimportPanelState extends ConsumerState<ReimportPanel> {
  _Step _step = _Step.idle;
  Catalog? _catalog;
  List<String> _problems = const [];
  int _count = 0;
  bool _busy = false;
  bool _failed = false;

  Future<void> _pick() async {
    final String? text;
    try {
      text = await ref.read(menuFilePickerProvider).pickText();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _problems = const [
          'Die Datei konnte nicht geöffnet werden. Bitte nochmal versuchen.',
        ];
        _step = _Step.problems;
        _failed = false;
      });
      return;
    }
    if (text == null || !mounted) return;
    try {
      final catalog = parseMenuFile(text);
      setState(() {
        _catalog = catalog;
        _step = _Step.confirm;
        _failed = false;
      });
    } on MenuImportException catch (e) {
      setState(() {
        _problems = e.problems;
        _step = _Step.problems;
        _failed = false;
      });
    }
  }

  void _cancel() => setState(() {
    _step = _Step.idle;
    _catalog = null;
  });

  Future<void> _confirm() async {
    final catalog = _catalog;
    if (_busy || catalog == null) return;
    _busy = true;
    try {
      await ref.read(catalogRepositoryProvider).importCatalog(catalog);
      ref.invalidate(catalogProvider);
      if (!mounted) return;
      setState(() {
        _count = catalog.items.length;
        _step = _Step.done;
        _failed = false;
        _catalog = null;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    const title = 'Speisekarte neu einspielen';
    // Bei einem gekoppelten Tablet kommt die Speisekarte vom Server.
    if (ref.watch(syncStateProvider).value?.paired ?? false) {
      return SettingsRow(
        title: title,
        help: 'Die Speisekarte kommt vom Server.',
      );
    }
    final pick = SizedBox(
      width: 180,
      child: PrimaryButton(
        key: const Key('reimport'),
        label: _step == _Step.problems ? 'Andere Datei wählen' : 'Datei wählen',
        filled: false,
        height: 52,
        onPressed: _pick,
      ),
    );

    final Widget below;
    switch (_step) {
      case _Step.idle:
        return SettingsRow(
          title: title,
          help: 'Liest die Speisekarten-Datei neu ein.',
          control: pick,
        );
      case _Step.done:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsRow(
              title: title,
              help: 'Liest die Speisekarten-Datei neu ein.',
              control: pick,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.veganBg,
                  borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
                ),
                child: Text(
                  'Speisekarte eingespielt: $_count Artikel.',
                  style: text.bodyMedium!.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: c.veganFg,
                  ),
                ),
              ),
            ),
          ],
        );
      case _Step.problems:
        below = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Die Datei passt noch nicht',
              style: text.titleMedium!.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: KassaTokens.spaceSm),
            Text(
              'Es wurde nichts eingespielt. '
              'Das muss in der Datei geändert werden:',
              style: text.bodyMedium!.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: c.ink2,
              ),
            ),
            const SizedBox(height: KassaTokens.spaceXl),
            ProblemList(problems: _problems),
            const SizedBox(height: KassaTokens.spaceXl),
            Align(alignment: Alignment.centerLeft, child: pick),
          ],
        );
      case _Step.confirm:
        below = Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
            border: Border.all(color: c.line, width: KassaTokens.borderButton),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Preise und Namen kommen neu aus der Datei. '
                'Favoriten und "Im Verkauf" bleiben.',
                style: text.bodyMedium!.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              if (_failed) const FailedHint(),
              const SizedBox(height: KassaTokens.spaceXl),
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      key: const Key('cancel-reimport'),
                      label: 'Abbrechen',
                      filled: false,
                      height: 60,
                      onPressed: _cancel,
                    ),
                  ),
                  const SizedBox(width: KassaTokens.spaceLg),
                  Expanded(
                    child: PrimaryButton(
                      key: const Key('confirm-reimport'),
                      label: 'Ja, einspielen',
                      height: 60,
                      onPressed: _confirm,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
    }
    return SettingsRow(
      title: title,
      help: 'Liest die Speisekarten-Datei neu ein.',
      below: below,
    );
  }
}
