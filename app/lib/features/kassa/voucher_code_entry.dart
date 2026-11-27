import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../data/providers.dart';
import '../../domain/voucher.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/keypad.dart';
import '../../ui/ltr.dart';
import '../../ui/pressable.dart';
import '../../ui/tokens.dart';
import '../close/amount_entry.dart' show FieldLabel;

/// Ein angefangener Code in Gruppen zu vier: '12345' wird '1234 5'.
String groupVoucherDigits(String digits) => digits.length <= 4
    ? digits
    : '${digits.substring(0, 4)} ${digits.substring(4)}';

/// "17.11.2026": das Datum eines Gutscheins oder einer Bewegung, in jeder
/// Sprache in Ziffern.
String voucherDateText(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.'
    '${d.month.toString().padLeft(2, '0')}.${d.year}';

/// Code eines Gutscheins tippen: die Anzeige `voucher-code` ("1234 5678",
/// in jeder Sprache von links nach rechts) und darunter das Zahlenfeld, nur
/// Ziffern. Nach der achten Ziffer sucht sie den Gutschein. Kennt die Kassa
/// den Code nicht, steht `voucher-code-problem` da; passen zwei oder mehr,
/// stehen sie mit Wert und Datum zur Wahl (`voucher-pick-<i>`, ältester
/// zuerst). [onFound] kommt mit genau einem Treffer oder der Wahl der
/// Person, [onCleared], sobald der Code wieder kürzer als 8 Ziffern ist.
/// Was mit dem Gutschein geschieht, entscheidet der Aufrufer (Prüfen,
/// Einlösen). Für einen getippten Code kommt [onFound] höchstens einmal, auch
/// wenn die letzte Ziffer weg- und wieder dazugetippt wird, während noch
/// gesucht wird: nur die neueste Suche meldet.
///
/// Sagt der Aufrufer zum gefundenen Gutschein einen [problem] (etwa
/// "aufgebraucht"), steht er wie "unbekannt" unter der Anzeige, in
/// `voucher-code-problem` mit rotem Rand.
class VoucherCodeEntry extends ConsumerStatefulWidget {
  const VoucherCodeEntry({
    super.key,
    required this.onFound,
    required this.onCleared,
    this.problem,
  });

  /// Genau ein Treffer, oder die Person hat unter zweien gewählt.
  final void Function(Voucher voucher) onFound;

  /// Der Code ist wieder kürzer als 8 Ziffern.
  final VoidCallback onCleared;

  /// Warum der gefundene Gutschein nicht geht; `null`: nichts zu sagen.
  final String? problem;

  @override
  ConsumerState<VoucherCodeEntry> createState() => _VoucherCodeEntryState();
}

class _VoucherCodeEntryState extends ConsumerState<VoucherCodeEntry> {
  static const _length = 8;

  String _digits = '';

  /// Das Ergebnis der Suche nach [_digits]; `null`, solange der Code kürzer
  /// ist oder gesucht wird.
  List<Voucher>? _found;

  /// Unter mehreren Treffern gewählt: die Wahl steht nicht mehr da.
  bool _picked = false;

  /// Zählt jede Änderung des Codes: nur die Suche mit dem neuesten Stand
  /// darf melden.
  int _generation = 0;

  void _key(String key) {
    final before = _digits;
    final next = key == 'back'
        ? (before.isEmpty ? before : before.substring(0, before.length - 1))
        : (RegExp(r'^[0-9]$').hasMatch(key) && before.length < _length
              ? '$before$key'
              : before);
    if (next == before) return;
    _generation++;
    setState(() {
      _digits = next;
      _found = null;
      _picked = false;
    });
    if (before.length == _length) widget.onCleared();
    if (next.length == _length) _search(next, _generation);
  }

  Future<void> _search(String code, int generation) async {
    List<Voucher> found;
    try {
      found = await ref.read(voucherRepositoryProvider).findByCode(code);
    } catch (_) {
      found = const [];
    }
    // Inzwischen anders getippt (auch weg und wieder dieselbe Ziffer): das
    // Ergebnis gilt nicht mehr, die neuere Suche meldet.
    if (!mounted || generation != _generation) return;
    setState(() => _found = found);
    if (found.length == 1) widget.onFound(found.single);
  }

  void _pick(Voucher voucher) {
    setState(() => _picked = true);
    widget.onFound(voucher);
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final found = _found;
    final empty = _digits.isEmpty;
    final problem = found == null
        ? null
        : found.isEmpty
        ? l.voucherUnknown
        : widget.problem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(l.voucherCode),
        const SizedBox(height: KassaTokens.spaceMd),
        Container(
          height: KassaTokens.keypadInputHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          // Die Anzeige gehört zum Zahlenfeld: in jeder Sprache rechts.
          alignment: Alignment.centerRight,
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
            border: Border.all(
              color: problem != null ? c.red : c.accent,
              width: KassaTokens.borderStrong,
            ),
          ),
          child: Semantics(
            liveRegion: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Ltr(
                child: Text(
                  empty ? '•••• ••••' : groupVoucherDigits(_digits),
                  key: const Key('voucher-code'),
                  maxLines: 1,
                  style: text.titleLarge!.copyWith(
                    fontSize: 30,
                    letterSpacing: 1.5,
                    color: empty ? c.ink2 : c.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (problem != null) ...[
          const SizedBox(height: KassaTokens.spaceMd),
          Semantics(
            liveRegion: true,
            child: Text(
              problem,
              key: const Key('voucher-code-problem'),
              style: text.bodyMedium!.copyWith(
                fontWeight: FontWeight.w700,
                color: c.red,
              ),
            ),
          ),
        ],
        if (found != null && found.length > 1 && !_picked) ...[
          const SizedBox(height: KassaTokens.spaceMd),
          for (final (i, v) in found.indexed) ...[
            if (i > 0) const SizedBox(height: KassaTokens.spaceMd),
            _Pick(
              key: Key('voucher-pick-$i'),
              voucher: v,
              onTap: () => _pick(v),
            ),
          ],
        ],
        const SizedBox(height: KassaTokens.spaceMd),
        Keypad(onKey: _key, showComma: false),
      ],
    );
  }
}

/// Einer von mehreren Gutscheinen mit demselben Code: Wert und Datum, ein
/// Tipp wählt ihn.
class _Pick extends StatelessWidget {
  const _Pick({super.key, required this.voucher, required this.onTap});

  final Voucher voucher;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final tabular = text.titleMedium!.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Pressable(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: KassaTokens.minTap + 8),
        padding: const EdgeInsets.symmetric(
          horizontal: KassaTokens.spaceXxl,
          vertical: KassaTokens.spaceMd,
        ),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
          border: Border.all(color: c.line, width: KassaTokens.borderButton),
        ),
        child: Row(
          children: [
            Expanded(
              child: Ltr(
                child: Text(
                  formatEuro(voucher.valueCents),
                  textAlign: ltrAlign(context, TextAlign.start),
                  style: tabular,
                ),
              ),
            ),
            const SizedBox(width: KassaTokens.spaceMd),
            Ltr(
              child: Text(
                voucherDateText(voucher.createdAt),
                style: tabular.copyWith(
                  fontWeight: FontWeight.w600,
                  color: c.ink2,
                ),
              ),
            ),
            const SizedBox(width: KassaTokens.spaceMd),
            Icon(
              directionalIcon(
                context,
                ltr: LucideIcons.chevronRight,
                rtl: LucideIcons.chevronLeft,
              ),
              size: 20,
              color: c.ink2,
            ),
          ],
        ),
      ),
    );
  }
}
