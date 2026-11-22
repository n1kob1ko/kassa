import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../rksv/rksv_providers.dart';
import '../../rksv/rksv_service.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import 'probe_question.dart' show showSettingsSheet;
import 'signature_panel.dart' show staleSettingsSentence;

const _unexpected = 'Das hat nicht geklappt. Bitte noch einmal.';

/// Höchstens so viele Zeichen hat eine Kassen-ID (Plan C8).
const _maxLength = 20;

/// Öffnet das Blatt "Kassen-ID ändern" mit [current] im Feld. "Speichern"
/// ändert die Kennung des PendingSetup ([RksvService.changeCashBoxId], der
/// AES-Schlüssel bleibt) und gibt die neue Kennung zurück; bei "Abbrechen"
/// oder "Zurück" `null`. Scheitert das Speichern, steht der Satz unter dem
/// Feld, und das Blatt bleibt offen.
///
/// Neben "Zugangsdaten von A-Trust" die zweite Stelle der App mit Tastatur
/// (Plan C9): Das Feld nimmt nur A bis Z, 0 bis 9 und Bindestrich, schreibt
/// Kleinbuchstaben groß und hört nach 20 Zeichen auf.
Future<String?> showCashBoxIdSheet(
  BuildContext context, {
  required String current,
}) => showSettingsSheet<String>(
  context,
  builder: (context) => CashBoxIdSheet(current: current),
);

/// Der Inhalt des Blatts "Kassen-ID ändern"; geöffnet mit
/// [showCashBoxIdSheet].
class CashBoxIdSheet extends ConsumerStatefulWidget {
  const CashBoxIdSheet({super.key, required this.current});

  /// Die Kennung, die das Feld beim Öffnen zeigt.
  final String current;

  @override
  ConsumerState<CashBoxIdSheet> createState() => _CashBoxIdSheetState();
}

class _CashBoxIdSheetState extends ConsumerState<CashBoxIdSheet> {
  late final _controller = TextEditingController(text: widget.current)
    ..selection = TextSelection.collapsed(offset: widget.current.length);
  final _focus = FocusNode();

  bool _saving = false;
  bool _closing = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    _focus.addListener(_focusChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _focus.removeListener(_focusChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  late String _lastText = widget.current;

  /// Eine Änderung im Feld nimmt den Satz eines gescheiterten Speicherns weg.
  void _changed() {
    final text = _controller.text;
    if (text == _lastText) return;
    _lastText = text;
    if (mounted) setState(() => _problem = null);
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  bool get _valid => RksvService.cashBoxIdProblem(_controller.text) == null;

  Future<void> _save() async {
    if (_saving || _closing || !_valid) return;
    final id = _controller.text.trim().toUpperCase();
    final service = ref.read(rksvServiceProvider);
    setState(() {
      _saving = true;
      _problem = null;
    });
    String? problem;
    try {
      await service.changeCashBoxId(id);
    } on RksvProblem catch (e) {
      problem = e.message;
    } on StateError {
      problem = staleSettingsSentence;
    } catch (_) {
      problem = _unexpected;
    }
    if (!mounted) return;
    if (problem == null) {
      _close(id);
      return;
    }
    setState(() {
      _saving = false;
      _problem = problem;
    });
  }

  void _close(String? id) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final problem = _problem;
    final small = text.bodyMedium!.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: c.ink2,
    );
    // Die Tastatur schiebt das Blatt nach oben: Feld und Tasten bleiben über
    // ihr.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      key: const Key('cash-box-id-sheet'),
      padding: EdgeInsets.only(bottom: keyboard),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(KassaTokens.spaceXxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Material(
              color: c.card,
              borderRadius: BorderRadius.circular(KassaTokens.radiusCard),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Kassen-ID ändern',
                        style: text.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: KassaTokens.spaceXl),
                    _field(context),
                    if (problem != null) ...[
                      const SizedBox(height: KassaTokens.spaceMd),
                      _ProblemLine(problem),
                    ],
                    const SizedBox(height: KassaTokens.spaceMd),
                    Text(
                      'Buchstaben, Ziffern und Bindestrich, höchstens 20 '
                      'Zeichen.',
                      style: small,
                    ),
                    const SizedBox(height: KassaTokens.spaceXl),
                    Text(
                      'Nimm keine Kennung, die bei FinanzOnline schon '
                      'angemeldet ist.',
                      style: small.copyWith(color: c.ink),
                    ),
                    const SizedBox(height: KassaTokens.spaceXs),
                    Text(
                      'Ein schon gedruckter Zettel gilt danach nicht mehr.',
                      style: small.copyWith(color: c.ink),
                    ),
                    const SizedBox(height: KassaTokens.spaceHuge),
                    Row(
                      children: [
                        Expanded(
                          child: KeyedSubtree(
                            key: const Key('cash-box-id-cancel'),
                            child: PrimaryButton(
                              label: 'Abbrechen',
                              filled: false,
                              height: 64,
                              onPressed: _saving ? null : () => _close(null),
                            ),
                          ),
                        ),
                        const SizedBox(width: KassaTokens.spaceXl),
                        Expanded(
                          child: KeyedSubtree(
                            key: const Key('cash-box-id-save'),
                            child: PrimaryButton(
                              label: 'Speichern',
                              height: 64,
                              onPressed: _saving || !_valid ? null : _save,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Das Feld, 64 dp hoch wie die Felder der Zugangsdaten, mit sichtbarem
  /// Fokus und der Schrift der Kennungen. Die Tastatur macht keine
  /// Vorschläge, korrigiert nichts und lernt nichts.
  Widget _field(BuildContext context) {
    final c = KassaColors.of(context);
    final focused = _focus.hasFocus;
    return GestureDetector(
      key: const Key('cash-box-id-field'),
      behavior: HitTestBehavior.opaque,
      onTap: _focus.requestFocus,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
          border: Border.all(
            color: focused ? c.accent : c.line,
            width: focused
                ? KassaTokens.borderStrong
                : KassaTokens.borderButton,
          ),
        ),
        child: Semantics(
          label: 'Kassen-ID',
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            autofocus: true,
            readOnly: _saving,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            autofillHints: null,
            enableIMEPersonalizedLearning: false,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9-]')),
              const _UpperCase(),
              LengthLimitingTextInputFormatter(_maxLength),
            ],
            maxLines: 1,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              fontFamily: KassaTokens.monoFontFamily,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              color: c.ink,
            ),
            cursorColor: c.accent,
            decoration: const InputDecoration.collapsed(hintText: null),
          ),
        ),
      ),
    );
  }
}

/// Schreibt, was getippt wird, groß (nach dem Filter nur A bis Z, 0 bis 9
/// und Bindestrich: Die Länge bleibt gleich).
class _UpperCase extends TextInputFormatter {
  const _UpperCase();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

/// Der Satz eines gescheiterten Speicherns unter dem Feld, mit Warnzeichen.
class _ProblemLine extends StatelessWidget {
  const _ProblemLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Row(
      key: const Key('cash-box-id-problem'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(LucideIcons.triangleAlert, size: 18, color: c.warnInk),
        ),
        const SizedBox(width: KassaTokens.spaceMd),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: c.ink,
            ),
          ),
        ),
      ],
    );
  }
}
