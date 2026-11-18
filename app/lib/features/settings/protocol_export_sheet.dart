import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../rksv/dep_export.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import 'probe_question.dart' show SettingsSheet, showSettingsSheet;

const _months = [
  'Jänner',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
];

String _day(DateTime d) => '${d.day}. ${_months[d.month - 1]}';

/// Die Hilfe der Zeiträume, von [now] aus (Kalender-Vierteljahre in der
/// Ortszeit, wie `RksvService.exportProtocol` sie rechnet): "Seit 1. Oktober
/// 2026." und "1. Juli bis 30. September 2026.".
({String thisQuarter, String lastQuarter}) quarterHelp(DateTime now) {
  final start = DateTime(now.year, now.month - (now.month - 1) % 3);
  final lastStart = DateTime(start.year, start.month - 3);
  final lastEnd = DateTime(start.year, start.month, 0);
  return (
    thisQuarter: 'Seit ${_day(start)} ${start.year}.',
    lastQuarter: '${_day(lastStart)} bis ${_day(lastEnd)} ${lastEnd.year}.',
  );
}

/// Das Blatt "Protokoll ausgeben": drei Zeiträume und "Abbrechen". Gibt den
/// gewählten Zeitraum zurück, bei "Abbrechen" oder "Zurück" `null`. Danach
/// öffnet der Aufrufer das Fenster von Android.
Future<ExportRange?> showProtocolExportSheet(
  BuildContext context, {
  required DateTime now,
}) => showSettingsSheet<ExportRange>(
  context,
  builder: (context) => _ExportSheet(now: now),
);

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({required this.now});

  final DateTime now;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  bool _closing = false;

  void _close(ExportRange? range) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(range);
  }

  @override
  Widget build(BuildContext context) {
    final help = quarterHelp(widget.now);
    const gap = SizedBox(height: KassaTokens.spaceLg);
    return SettingsSheet(
      key: const Key('rksv-export-sheet'),
      title: 'Protokoll ausgeben',
      message:
          'Wähle den Zeitraum. Danach fragt Android, wohin die Datei soll.',
      children: [
        _RangeRow(
          key: const Key('rksv-export-all'),
          title: 'Alles',
          help: 'Vom Startbeleg bis heute.',
          onTap: () => _close(ExportRange.all),
        ),
        gap,
        _RangeRow(
          key: const Key('rksv-export-this-quarter'),
          title: 'Dieses Vierteljahr',
          help: help.thisQuarter,
          onTap: () => _close(ExportRange.thisQuarter),
        ),
        gap,
        _RangeRow(
          key: const Key('rksv-export-last-quarter'),
          title: 'Letztes Vierteljahr',
          help: help.lastQuarter,
          onTap: () => _close(ExportRange.lastQuarter),
        ),
        const SizedBox(height: KassaTokens.spaceHuge),
        PrimaryButton(
          key: const Key('rksv-export-cancel'),
          label: 'Abbrechen',
          filled: false,
          height: 64,
          onPressed: () => _close(null),
        ),
      ],
    );
  }
}

/// Eine große Zeile des Blatts: Titel, Hilfe darunter, Pfeil rechts, ganz
/// antippbar, mindestens 76 dp hoch.
class _RangeRow extends StatelessWidget {
  const _RangeRow({
    super.key,
    required this.title,
    required this.help,
    required this.onTap,
  });

  final String title;
  final String help;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      semanticLabel: '$title. $help',
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: c.fill,
          borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: text.bodyMedium!.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: KassaTokens.spaceXxs),
                  Text(
                    help,
                    style: text.bodyMedium!.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                      color: c.ink2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: KassaTokens.spaceXl),
            Icon(LucideIcons.chevronRight, size: 24, color: c.ink2),
          ],
        ),
      ),
    );
  }
}
