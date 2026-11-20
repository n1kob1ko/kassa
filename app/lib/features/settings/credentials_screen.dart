import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../rksv/online/atrust_client.dart';
import '../../rksv/online/online_providers.dart';
import '../../rksv/rksv_providers.dart';
import '../../rksv/rksv_secrets.dart';
import '../../rksv/rksv_state.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import 'card_check_screen.dart' show checkCardDecoration;
import 'connection_check_screen.dart';
import 'settings_rows.dart';
import 'signature_panel.dart' show ConnectionCheckOpening;

const _empty = 'Bitte beides ausfüllen.';
const _saveFailed =
    'Die Zugangsdaten konnten nicht gespeichert werden. Bitte noch einmal.';
const _unexpected = 'Das hat nicht geklappt. Bitte noch einmal.';

/// Wo der Weg "Zugangsdaten von A-Trust" steht. Die Hülle hält ihn, damit
/// "Zurück" des Tablets eine Ebene schließt: erst die Prüfung, dann die
/// Zugangsdaten.
@immutable
final class CredentialsRoute {
  const CredentialsRoute({this.edit = false, this.check});

  /// Die Felder stehen da, auch wenn Zugangsdaten gespeichert sind.
  final bool edit;

  /// "Verbindung prüfen" am echten System steht an Stelle der Zugangsdaten,
  /// geöffnet wie angegeben; `null` ohne.
  final ConnectionCheckOpening? check;
}

/// Der Bildschirm "Zugangsdaten von A-Trust" (nur Chef, Plan Q3): der einzige
/// der App mit Tastatur. Benutzername und Passwort des echten Kontos gehen
/// nur in den geschützten Speicher. Sind Zugangsdaten gespeichert, steht der
/// Benutzername da, nie das Passwort.
///
/// "Speichern und prüfen" schreibt die Zugangsdaten, hebt "abgelehnt" des
/// echten Systems auf, lässt den Halter die alte Sitzung vergessen und öffnet
/// "Verbindung prüfen" am echten System als Antippen des Chefs: genau eine
/// Anmeldung. Die Felder werden beim Verlassen geleert.
class CredentialsScreen extends ConsumerStatefulWidget {
  const CredentialsScreen({
    super.key,
    this.edit = false,
    this.checking,
    required this.onChecking,
    required this.onBack,
  });

  /// Gleich die Felder zeigen, auch wenn Zugangsdaten gespeichert sind.
  final bool edit;

  /// "Verbindung prüfen" am echten System, wie geöffnet; `null` zeigt die
  /// Zugangsdaten.
  final ConnectionCheckOpening? checking;
  final ValueChanged<ConnectionCheckOpening?> onChecking;

  /// Zurück zu den Einstellungen.
  final VoidCallback onBack;

  @override
  ConsumerState<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends ConsumerState<CredentialsScreen> {
  @override
  Widget build(BuildContext context) {
    final opening = widget.checking;
    if (opening == null) {
      return _CredentialsPage(
        edit: widget.edit,
        onCheck: widget.onChecking,
        onBack: widget.onBack,
      );
    }
    final live =
        (ref.watch(rksvStateProvider).value ?? const RksvState()).mode ==
        RksvMode.live;
    return ConnectionCheckScreen(
      key: const Key('credentials-check'),
      system: AtrustSystem.live,
      opening: opening,
      onBack: () => widget.onChecking(null),
      // Task 6 hängt hier den nächsten Schritt an; bis dahin schließt
      // "Weiter" die Prüfung. In Betrieb gibt es keinen nächsten Schritt.
      onContinue: live ? null : (_) => widget.onChecking(null),
    );
  }
}

/// Die Zugangsdaten selbst: Felder oder "Zugangsdaten sind gespeichert.".
class _CredentialsPage extends ConsumerStatefulWidget {
  const _CredentialsPage({
    required this.edit,
    required this.onCheck,
    required this.onBack,
  });

  final bool edit;
  final ValueChanged<ConnectionCheckOpening> onCheck;
  final VoidCallback onBack;

  @override
  ConsumerState<_CredentialsPage> createState() => _CredentialsPageState();
}

class _CredentialsPageState extends ConsumerState<_CredentialsPage> {
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  /// Gelesen ist, was im geschützten Speicher steht.
  bool _loaded = false;

  /// Der gespeicherte Benutzername; das Passwort hält die Seite nie.
  String? _storedUser;

  late bool _editing = widget.edit;
  bool _shown = false;
  bool _busy = false;
  bool _confirmDelete = false;
  String? _problem;

  RksvSecrets get _secrets => ref.read(rksvSecretsProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    String? user;
    try {
      user = (await _secrets.atrustCredentials())?.user;
    } catch (_) {
      // Nicht lesbar: Die Felder stehen da, neue Zugangsdaten gehen immer.
    }
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _storedUser = user;
    });
  }

  @override
  void dispose() {
    _clear();
    _user.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _clear() {
    _user.value = TextEditingValue.empty;
    _password.value = TextEditingValue.empty;
  }

  Future<void> _save() async {
    if (_busy) return;
    final user = _user.text.trim();
    final password = _password.text;
    if (user.isEmpty || password.isEmpty) {
      setState(() => _problem = _empty);
      return;
    }
    final secrets = _secrets;
    final keeper = ref.read(atrustKeeperProvider(AtrustSystem.live));
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await secrets.writeAtrustCredentials(AtrustCredentials(user, password));
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = _saveFailed;
        });
      }
      return;
    }
    // Neue Zugangsdaten heben "abgelehnt" auf (Q4). Scheitert das, bleiben
    // sie trotzdem gespeichert; die Prüfung meldet es selbst.
    try {
      await secrets.writeAtrustRejected(false, live: true);
    } catch (_) {}
    keeper.forget();
    if (!mounted) return;
    _clear();
    widget.onCheck(ConnectionCheckOpening.relogin);
  }

  Future<void> _delete() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _confirmDelete = false;
      _problem = null;
    });
    String? problem;
    try {
      await _secrets.writeAtrustCredentials(null);
      await _secrets.writePendingSetup(null);
      ref.read(atrustKeeperProvider(AtrustSystem.live)).forget();
    } catch (_) {
      problem = _unexpected;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _problem = problem;
      if (problem == null) {
        _storedUser = null;
        _editing = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final live =
        (ref.watch(rksvStateProvider).value ?? const RksvState()).mode ==
        RksvMode.live;
    final stored = _storedUser;

    final Widget body;
    if (!_loaded) {
      body = const SizedBox.shrink();
    } else if (stored != null && !_editing) {
      body = _saved(context, stored, live: live);
    } else {
      body = _form(context);
    }

    return Column(
      key: const Key('credentials'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: KassaTokens.receiptHeaderHeight,
          padding: const EdgeInsets.only(left: 6, right: 16),
          child: Row(
            children: [
              Pressable(
                key: const Key('credentials-back'),
                onTap: widget.onBack,
                semanticLabel: 'Zurück zu den Einstellungen',
                minTapSize: const Size(KassaTokens.minTap, KassaTokens.minTap),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.chevronLeft, size: 28, color: c.ink),
                    Text(
                      'Zurück',
                      style: text.titleMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KassaTokens.spaceXxl),
              Expanded(
                child: Text(
                  'Zugangsdaten von A-Trust',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.headlineMedium,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: const Key('credentials-scroll'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(KassaTokens.spaceHuge),
              decoration: checkCardDecoration(c),
              child: body,
            ),
          ),
        ),
      ],
    );
  }

  Widget _form(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final problem = _problem;
    final save = KeyedSubtree(
      key: const Key('credentials-save'),
      child: PrimaryButton(
        label: 'Speichern und prüfen',
        height: _fieldHeight,
        labelSize: 18,
        onPressed: _busy ? null : _save,
      ),
    );
    final user = _LabeledField(
      label: 'Benutzername',
      child: _Field(
        key: const Key('credentials-user'),
        controller: _user,
        label: 'Benutzername',
        keyboardType: TextInputType.visiblePassword,
        action: TextInputAction.next,
        onSubmitted: (_) => _passwordFocus.requestFocus(),
      ),
    );
    final password = _LabeledField(
      label: 'Passwort',
      child: _Field(
        key: const Key('credentials-password'),
        controller: _password,
        focusNode: _passwordFocus,
        label: 'Passwort',
        obscure: !_shown,
        action: TextInputAction.done,
        onSubmitted: (_) => _save(),
        trailing: _ShowToggle(
          shown: _shown,
          onTap: () => setState(() => _shown = !_shown),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Benutzername und Passwort hast du von A-Trust bekommen, als das '
          'Konto für diesen Betrieb angelegt wurde. Die Kassa speichert sie '
          'geschützt auf diesem Tablet.',
          style: text.bodyMedium!.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
        const SizedBox(height: KassaTokens.spaceHuge),
        LayoutBuilder(
          builder: (context, constraints) {
            // Breit: beide Felder und die Haupttaste in einer Reihe, damit
            // alles über der Tastatur bleibt. Schmal: untereinander.
            if (constraints.maxWidth >= 720) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: user),
                  const SizedBox(width: KassaTokens.spaceXxl),
                  Expanded(child: password),
                  const SizedBox(width: KassaTokens.spaceXxl),
                  SizedBox(width: 240, child: save),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                user,
                const SizedBox(height: KassaTokens.spaceXxl),
                password,
                const SizedBox(height: KassaTokens.spaceXxl),
                save,
              ],
            );
          },
        ),
        if (problem != null) ...[
          const SizedBox(height: KassaTokens.spaceXl),
          WarnBox(problem, key: const Key('credentials-problem')),
        ],
      ],
    );
  }

  Widget _saved(BuildContext context, String user, {required bool live}) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final problem = _problem;
    return Column(
      key: const Key('credentials-saved'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.veganBg,
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.check, size: 22, color: c.veganFg),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zugangsdaten sind gespeichert.',
                    style: text.titleMedium!.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: KassaTokens.spaceXxs),
                  Text(
                    'Benutzername $user',
                    style: text.bodyMedium!.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.ink2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: KassaTokens.spaceXxl),
        Divider(height: 1, thickness: KassaTokens.borderThin, color: c.line),
        const SizedBox(height: KassaTokens.spaceXxl),
        if (_confirmDelete)
          _DeleteQuestion(
            onConfirm: _busy ? null : _delete,
            onCancel: () => setState(() => _confirmDelete = false),
          )
        else
          Row(
            children: [
              if (!live) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 140),
                  child: PrimaryButton(
                    key: const Key('credentials-delete'),
                    label: 'Löschen',
                    filled: false,
                    height: 56,
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _confirmDelete = true;
                            _problem = null;
                          }),
                  ),
                ),
                const SizedBox(width: KassaTokens.spaceXl),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 180),
                child: PrimaryButton(
                  key: const Key('credentials-new'),
                  label: 'Neu eingeben',
                  filled: false,
                  height: 56,
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _editing = true;
                          _shown = false;
                          _problem = null;
                        }),
                ),
              ),
              const Spacer(),
              if (!live)
                SizedBox(
                  width: 240,
                  child: KeyedSubtree(
                    key: const Key('credentials-continue'),
                    child: PrimaryButton(
                      label: 'Weiter',
                      height: _fieldHeight,
                      onPressed: _busy
                          ? null
                          : () => widget.onCheck(ConnectionCheckOpening.check),
                    ),
                  ),
                ),
            ],
          ),
        if (problem != null) ...[
          const SizedBox(height: KassaTokens.spaceXl),
          WarnBox(problem, key: const Key('credentials-problem')),
        ],
      ],
    );
  }
}

/// Höhe der Felder und der Haupttaste daneben.
const double _fieldHeight = 64;

/// Beschriftung über einem Feld.
class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: KassaTokens.spaceMd),
          child: ExcludeSemantics(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: c.ink2,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Ein Eingabefeld, 64 dp hoch, mit sichtbarem Fokus. Die Tastatur macht
/// keine Vorschläge, korrigiert nichts, schreibt nichts groß, lernt nichts
/// und bietet keine Ausfüllhilfe an.
class _Field extends StatefulWidget {
  const _Field({
    super.key,
    required this.controller,
    required this.label,
    required this.action,
    required this.onSubmitted,
    this.focusNode,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.trailing,
  });

  final TextEditingController controller;
  final String label;
  final TextInputAction action;
  final ValueChanged<String> onSubmitted;
  final FocusNode? focusNode;
  final bool obscure;

  /// Der Benutzername ist `visiblePassword` (Android-Tastaturen schlagen dann
  /// nichts vor). Das Passwortfeld bleibt `text`: Mit `visiblePassword`
  /// verlöre es auf Android die Variante "Passwort", an der Tastaturen ihren
  /// geschützten Modus festmachen; Vorschläge schaltet dort schon
  /// `obscureText` ab, und die Parameter darunter gelten in beiden Zuständen.
  final TextInputType keyboardType;
  final Widget? trailing;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  FocusNode? _own;

  FocusNode get _focus => widget.focusNode ?? (_own ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_changed);
  }

  @override
  void didUpdateWidget(_Field old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _own)?.removeListener(_changed);
      _focus.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_changed);
    _own?.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final focused = _focus.hasFocus;
    final style = Theme.of(context).textTheme.titleMedium!.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: c.ink,
      letterSpacing: widget.obscure ? 2 : 0.5,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focus.requestFocus,
      child: Container(
        height: _fieldHeight,
        padding: const EdgeInsets.only(left: 20, right: 8),
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
        child: Row(
          children: [
            Expanded(
              // Der Name für die Vorlesehilfe; die Beschriftung darüber ist
              // davon ausgenommen.
              child: Semantics(
                label: widget.label,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  obscureText: widget.obscure,
                  obscuringCharacter: '•',
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  autofillHints: null,
                  enableIMEPersonalizedLearning: false,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.action,
                  onSubmitted: widget.onSubmitted,
                  maxLines: 1,
                  style: style,
                  cursorColor: c.accent,
                  scrollPadding: const EdgeInsets.all(96),
                  decoration: const InputDecoration.collapsed(hintText: null),
                ),
              ),
            ),
            ?widget.trailing,
          ],
        ),
      ),
    );
  }
}

/// "Anzeigen" und "Verbergen" im Passwortfeld.
class _ShowToggle extends StatelessWidget {
  const _ShowToggle({required this.shown, required this.onTap});

  final bool shown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final label = shown ? 'Verbergen' : 'Anzeigen';
    return Pressable(
      key: const Key('credentials-show'),
      onTap: onTap,
      semanticLabel: shown ? 'Passwort verbergen' : 'Passwort anzeigen',
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: c.fill,
          borderRadius: BorderRadius.circular(KassaTokens.radiusLg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              shown ? LucideIcons.eyeOff : LucideIcons.eye,
              size: 20,
              color: c.ink,
            ),
            const SizedBox(width: KassaTokens.spaceMd),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium!
                  .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nachfrage "Zugangsdaten löschen?" mit "Löschen" und "Abbrechen".
class _DeleteQuestion extends StatelessWidget {
  const _DeleteQuestion({required this.onConfirm, required this.onCancel});

  final VoidCallback? onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Container(
      key: const Key('credentials-delete-question'),
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
            'Zugangsdaten löschen?',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: KassaTokens.spaceXl),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  key: const Key('credentials-delete-cancel'),
                  label: 'Abbrechen',
                  filled: false,
                  height: 56,
                  onPressed: onCancel,
                ),
              ),
              const SizedBox(width: KassaTokens.spaceLg),
              Expanded(
                child: PrimaryButton(
                  key: const Key('credentials-delete-confirm'),
                  label: 'Löschen',
                  solid: true,
                  height: 56,
                  onPressed: onConfirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
