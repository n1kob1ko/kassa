import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../devices/device_providers.dart';
import '../../devices/printer.dart';
import '../../devices/printer_discovery.dart';
import '../../ui/address_keypad.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/segmented.dart';
import '../../ui/tokens.dart';
import '../items/item_detail.dart' show FailedHint;
import 'settings_rows.dart';

const _noPermission =
    'Kassa darf den Drucker nicht verwenden. Bitte die Erlaubnis geben.';
const _searchFailed = 'Die Suche hat nicht geklappt.';

const _nothingFound = {
  PrinterKind.network:
      'Kein Drucker gefunden. Ist er eingeschaltet und im selben WLAN?',
  PrinterKind.usb: 'Kein Drucker am USB-Anschluss gefunden.',
  PrinterKind.bluetooth:
      'Kein Drucker gekoppelt. Bitte zuerst in den Bluetooth-Einstellungen '
      'des Tablets koppeln.',
};

/// Die Zeile "Bondrucker" samt dem Feld zum Einrichten: ein Tipp öffnet es
/// darunter in derselben Karte, ohne Dialog (wie beim neuen Einspielen).
/// Verbindung wählen, Drucker suchen und antippen, Testdruck, Breite,
/// Drucker entfernen. Jede Speicherung geht vom gespeicherten Stand aus, damit
/// keine andere Einstellung verloren geht.
class PrinterPanel extends ConsumerStatefulWidget {
  const PrinterPanel({super.key}) : kitchen = false;

  /// Dasselbe für den Küchendrucker (Abschnitt Küche): Zeile "Küchendrucker",
  /// eigene Art, Adresse, Name und Breite, Testdruck am Küchendrucker, ohne
  /// "QR-Code als Bild". Schlüssel `kitchen-printer-…` statt `printer-…`.
  const PrinterPanel.kitchen({super.key}) : kitchen = true;

  final bool kitchen;

  @override
  ConsumerState<PrinterPanel> createState() => _PrinterPanelState();
}

class _PrinterPanelState extends ConsumerState<PrinterPanel> {
  bool _open = false;
  PrinterKind _kind = PrinterKind.network;

  bool _searching = false;
  List<FoundPrinter> _found = const [];
  String? _searchProblem;
  int _generation = 0;

  bool _typing = false;
  String? _notice;
  bool _saveFailed = false;

  bool _testing = false;
  PrintOutcome? _result;

  /// Anfang der Schlüssel: `printer` oder `kitchen-printer`.
  String get _key => widget.kitchen ? 'kitchen-printer' : 'printer';

  PrinterKind _kindOf(RegisterSettings s) =>
      widget.kitchen ? s.kitchenPrinterKind : s.printerKind;

  String? _addressOf(RegisterSettings s) =>
      widget.kitchen ? s.kitchenPrinterAddress : s.printerAddress;

  String? _nameOf(RegisterSettings s) =>
      widget.kitchen ? s.kitchenPrinterName : s.printerName;

  int _columnsOf(RegisterSettings s) =>
      widget.kitchen ? s.kitchenPrinterColumns : s.printerColumns;

  Future<void> _save(
    RegisterSettings Function(RegisterSettings s) change,
  ) async {
    final repo = ref.read(settingsRepositoryProvider);
    try {
      await repo.save(change(await repo.current()));
      if (mounted && _saveFailed) setState(() => _saveFailed = false);
    } catch (_) {
      if (mounted) setState(() => _saveFailed = true);
    }
  }

  void _toggle(RegisterSettings s) {
    setState(() {
      _open = !_open;
      _typing = false;
      _notice = null;
      _result = null;
      if (_open && _kindOf(s) != PrinterKind.none) _kind = _kindOf(s);
    });
    if (_open) _search();
  }

  void _selectKind(PrinterKind kind) {
    if (kind == _kind) return;
    setState(() {
      _kind = kind;
      _typing = false;
    });
    _search();
  }

  Future<void> _search() async {
    final generation = ++_generation;
    final discovery = ref.read(printerDiscoveryProvider);
    final kind = _kind;
    setState(() {
      _searching = true;
      _found = const [];
      _searchProblem = null;
      _notice = null;
    });
    List<FoundPrinter> found = const [];
    String? problem;
    try {
      found = await switch (kind) {
        PrinterKind.usb => discovery.usb(),
        PrinterKind.bluetooth => discovery.bluetooth(),
        _ => discovery.network(),
      };
    } on PrinterException catch (e) {
      problem = e.problem == PrintProblem.noPermission
          ? _noPermission
          : _searchFailed;
    } catch (_) {
      problem = _searchFailed;
    }
    // Eine spätere Suche (oder das Schließen) gilt mehr als diese Antwort.
    if (!mounted || generation != _generation) return;
    setState(() {
      _searching = false;
      _found = found;
      _searchProblem = problem;
    });
  }

  Future<void> _choose(FoundPrinter printer) async {
    if (printer.kind != PrinterKind.network) {
      var allowed = false;
      try {
        allowed = await ref
            .read(printerDiscoveryProvider)
            .requestAccess(printer.kind, printer.address);
      } catch (_) {}
      if (!mounted) return;
      if (!allowed) {
        setState(() => _notice = _noPermission);
        return;
      }
    }
    setState(() {
      _notice = null;
      _typing = false;
      _result = null;
    });
    await _save(
      (s) => widget.kitchen
          ? s.copyWith(
              kitchenPrinterKind: printer.kind,
              kitchenPrinterAddress: printer.address,
              kitchenPrinterName: printer.name,
            )
          : s.copyWith(
              printerKind: printer.kind,
              printerAddress: printer.address,
              printerName: printer.name,
            ),
    );
  }

  Future<void> _chooseTyped(String host) => _choose(
    FoundPrinter(
      kind: PrinterKind.network,
      name: 'Drucker $host',
      address: '$host:$rawPrintPort',
    ),
  );

  Future<void> _testPrint() async {
    if (_testing) return;
    setState(() {
      _testing = true;
      _result = null;
    });
    PrintOutcome outcome;
    try {
      final printer = widget.kitchen
          ? ref.read(kitchenPrinterProvider)
          : ref.read(receiptPrinterProvider);
      outcome =
          await printer?.testPrint() ??
          const PrintOutcome.failed(PrintProblem.notSetUp);
    } catch (_) {
      outcome = const PrintOutcome.failed(PrintProblem.unreachable);
    }
    if (!mounted) return;
    setState(() {
      _testing = false;
      _result = outcome;
    });
  }

  Future<void> _remove() async {
    setState(() => _result = null);
    await _save(
      (s) => widget.kitchen ? s.withoutKitchenPrinter() : s.withoutPrinter(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final s =
        ref.watch(settingsStreamProvider).value ?? const RegisterSettings();
    final set = _kindOf(s) != PrinterKind.none;
    final name = _nameOf(s);

    final header = Semantics(
      button: true,
      expanded: _open,
      child: GestureDetector(
        key: Key('$_key-row'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggle(s),
        child: SettingsRow(
          title: widget.kitchen ? 'Küchendrucker' : 'Bondrucker',
          help: set
              ? 'Tippen, um den Drucker zu ändern.'
              : 'Tippen, um einen Drucker zu wählen.',
          control: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (set && name != null && name.isNotEmpty)
                DevicePill(name)
              else
                const NeutralPill('Nicht eingerichtet'),
              const SizedBox(width: KassaTokens.spaceMd),
              Icon(
                _open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                size: 22,
                color: c.ink2,
              ),
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (_open)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _panel(context, s),
          ),
        if (set && !widget.kitchen)
          SettingsRow(
            title: 'QR-Code als Bild drucken',
            help:
                'Einschalten, wenn am Bon statt des QR-Codes nur Zeichen '
                'stehen.',
            control: RowToggle(
              key: const Key('printer-qr-image'),
              label: 'QR-Code als Bild drucken',
              value: s.printerQrAsImage,
              onChanged: (v) => _save((s) => s.copyWith(printerQrAsImage: v)),
            ),
          ),
      ],
    );
  }

  Widget _panel(BuildContext context, RegisterSettings s) {
    final set = _kindOf(s) != PrinterKind.none;
    const gap = SizedBox(height: KassaTokens.spaceXl);
    return Column(
      key: Key('$_key-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Segmented<PrinterKind>(
            segments: const [
              (PrinterKind.network, 'Netzwerk'),
              (PrinterKind.usb, 'USB'),
              (PrinterKind.bluetooth, 'Bluetooth'),
            ],
            selected: _kind,
            keyFor: (k) => Key('$_key-kind-${k.name}'),
            onSelected: _selectKind,
          ),
        ),
        gap,
        if (_typing)
          AddressKeypad(
            onSubmit: _chooseTyped,
            onCancel: () => setState(() => _typing = false),
          )
        else
          ..._finder(context, s),
        if (_saveFailed) const FailedHint(),
        if (set) ..._chosen(context, s),
      ],
    );
  }

  /// Notiz, Suchergebnis (Platzhalter, Satz oder Liste) und die Tasten
  /// "Nochmal suchen" und "Adresse eintippen".
  List<Widget> _finder(BuildContext context, RegisterSettings s) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    const gap = SizedBox(height: KassaTokens.spaceLg);
    final body = text.bodyMedium!.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: c.ink2,
    );
    return [
      if (_notice != null) ...[WarnBox(_notice!), gap],
      if (_searching) ...[
        Text(
          _kind == PrinterKind.network
              ? 'Suche läuft. Das kann einen Moment dauern.'
              : 'Suche läuft.',
          key: Key('$_key-searching'),
          style: body,
        ),
        gap,
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(height: KassaTokens.spaceMd),
          _SkeletonRow(keyPrefix: _key),
        ],
      ] else if (_searchProblem != null)
        WarnBox(_searchProblem!)
      else if (_found.isEmpty)
        Text(_nothingFound[_kind]!, style: body)
      else
        for (var i = 0; i < _found.length; i++) ...[
          if (i > 0) const SizedBox(height: KassaTokens.spaceMd),
          _FoundRow(
            keyPrefix: _key,
            printer: _found[i],
            selected:
                _kindOf(s) == _found[i].kind &&
                _addressOf(s) == _found[i].address,
            onTap: () => _choose(_found[i]),
          ),
        ],
      gap,
      Row(
        children: [
          Expanded(
            child: PrimaryButton(
              key: Key('$_key-search'),
              label: 'Nochmal suchen',
              filled: false,
              height: 56,
              icon: LucideIcons.refreshCw,
              onPressed: _searching ? null : _search,
            ),
          ),
          if (_kind == PrinterKind.network) ...[
            const SizedBox(width: KassaTokens.spaceLg),
            Expanded(
              child: PrimaryButton(
                key: Key('$_key-address-open'),
                label: 'Adresse eintippen',
                filled: false,
                height: 56,
                icon: LucideIcons.keyboard,
                onPressed: () => setState(() => _typing = true),
              ),
            ),
          ],
        ],
      ),
    ];
  }

  /// Nach der Wahl: Testdruck, Ergebnis, Breite, Entfernen.
  List<Widget> _chosen(BuildContext context, RegisterSettings s) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final result = _result;
    return [
      const SizedBox(height: KassaTokens.spaceXxl),
      Container(height: KassaTokens.borderThin, color: c.line),
      const SizedBox(height: KassaTokens.spaceXxl),
      PrimaryButton(
        key: Key('$_key-test'),
        label: _testing ? 'Druckt …' : 'Testdruck',
        height: 64,
        icon: LucideIcons.printer,
        onPressed: _testing ? null : _testPrint,
      ),
      if (result != null) ...[
        const SizedBox(height: KassaTokens.spaceLg),
        result.ok
            ? _OkBox('Testdruck geschickt. Kommt Papier?', keyPrefix: _key)
            : WarnBox(result.message, key: Key('$_key-result')),
      ],
      const SizedBox(height: KassaTokens.spaceXxl),
      Text(
        'Breite',
        style: text.bodyMedium!.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: KassaTokens.spaceMd),
      Align(
        alignment: Alignment.centerLeft,
        child: Segmented<int>(
          segments: const [(48, 'Normal'), (42, 'Schmal')],
          selected: _columnsOf(s),
          keyFor: (v) => Key('$_key-width-$v'),
          onSelected: (v) => _save(
            (s) => widget.kitchen
                ? s.copyWith(kitchenPrinterColumns: v)
                : s.copyWith(printerColumns: v),
          ),
        ),
      ),
      const SizedBox(height: KassaTokens.spaceSm),
      Text(
        'Schmal wählen, wenn der Testdruck am Rand umbricht.',
        style: text.bodyMedium!.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.3,
          color: c.ink2,
        ),
      ),
      const SizedBox(height: KassaTokens.spaceXl),
      Align(
        alignment: Alignment.centerLeft,
        child: Pressable(
          key: Key('$_key-remove'),
          onTap: _remove,
          minTapSize: const Size(0, KassaTokens.minTap),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KassaTokens.spaceLg,
              vertical: KassaTokens.spaceMd,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.trash2, size: 20, color: c.red),
                const SizedBox(width: KassaTokens.spaceMd),
                Text(
                  'Drucker entfernen',
                  style: text.bodyMedium!.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }
}

/// Ein gefundener Drucker: 64 dp hoch, antippbar. Der gewählte hat Rand und
/// Haken.
class _FoundRow extends StatelessWidget {
  const _FoundRow({
    required this.keyPrefix,
    required this.printer,
    required this.selected,
    required this.onTap,
  });

  final String keyPrefix;
  final FoundPrinter printer;
  final bool selected;
  final VoidCallback onTap;

  String get _detail => switch (printer.kind) {
    PrinterKind.network => printer.address.split(':').first,
    PrinterKind.usb => 'USB-Anschluss',
    _ => printer.address,
  };

  IconData get _icon => switch (printer.kind) {
    PrinterKind.usb => LucideIcons.usb,
    PrinterKind.bluetooth => LucideIcons.bluetooth,
    _ => LucideIcons.wifi,
  };

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final instant = MediaQuery.disableAnimationsOf(context);
    return Pressable(
      key: Key('$keyPrefix-found-${printer.address}'),
      onTap: onTap,
      child: AnimatedContainer(
        duration: instant ? Duration.zero : KassaTokens.motionFast,
        curve: Curves.linear,
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? c.accentSoft : c.card,
          borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
          border: Border.all(
            color: selected ? c.accent : c.line,
            width: KassaTokens.borderButton,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? c.card : c.fill,
                borderRadius: BorderRadius.circular(KassaTokens.radiusLg),
              ),
              child: Icon(
                _icon,
                size: 22,
                color: selected ? c.accentInk : c.ink2,
              ),
            ),
            const SizedBox(width: KassaTokens.spaceXl),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    printer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium!.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: selected ? c.accentInk : c.ink,
                    ),
                  ),
                  Text(
                    _detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall!.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.ink2,
                    ),
                  ),
                ],
              ),
            ),
            if (selected) Icon(LucideIcons.check, size: 22, color: c.accentInk),
          ],
        ),
      ),
    );
  }
}

/// Grauer Platzhalter einer Drucker-Zeile während der Suche.
class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.keyPrefix});

  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return ExcludeSemantics(
      child: Container(
        key: Key('$keyPrefix-skeleton'),
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: c.fill,
          borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.fill2,
                borderRadius: BorderRadius.circular(KassaTokens.radiusLg),
              ),
            ),
            const SizedBox(width: KassaTokens.spaceXl),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: c.fill2,
                      borderRadius: BorderRadius.circular(KassaTokens.radiusXs),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satz in der grünen Fläche: es hat geklappt.
class _OkBox extends StatelessWidget {
  const _OkBox(this.message, {required this.keyPrefix});

  final String message;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.veganBg,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
      ),
      child: Text(
        message,
        key: Key('$keyPrefix-result'),
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          height: 1.3,
          color: c.veganFg,
        ),
      ),
    );
  }
}
