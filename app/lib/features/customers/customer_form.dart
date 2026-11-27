// Das Formular für den Empfänger einer Rechnung (Spec 5.3): Name, zwei
// Adress-Zeilen und die UID. Die einzige Stelle der Kassa, an der die
// Tastatur des Tablets kommt (Ausnahme in `test/no_text_field_test.dart`).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../domain/customer.dart';
import '../../domain/receipt.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/app_toggle.dart';
import '../../ui/ltr.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import '../login/session.dart';

/// Was im Formular zu Beginn steht: die Werte eines Empfängers oder eines
/// Firmenkunden, der Firmenkunde, den "Als Firmenkunde speichern" ändert
/// (leer: ein neuer), und ob der Schalter zu Beginn an ist ([keep]).
class CustomerFormStart {
  const CustomerFormStart({
    this.customerId,
    this.name = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.vatId = '',
    this.keep = true,
  });

  /// Die Werte der letzten Fassung (für "Ändern"). "Ändern" ändert nie einen
  /// gespeicherten Firmenkunden: Wer den falschen gewählt hat und die Daten
  /// eines anderen tippt, überschriebe ihn sonst. Der Schalter ist aus, die
  /// neue Fassung hängt an keinem Firmenkunden; schaltet man ihn an, entsteht
  /// ein neuer. Gespeicherte Firmenkunden ändert man im Browser.
  CustomerFormStart.of(ReceiptRecipient r)
    : customerId = null,
      name = r.name,
      addressLine1 = r.addressLine1,
      addressLine2 = r.addressLine2,
      vatId = r.vatId ?? '',
      keep = false;

  /// Die Werte eines gespeicherten Firmenkunden, dem für diesen Bon etwas
  /// fehlt (etwa die UID über 10.000 €). Wie bei [CustomerFormStart.of]
  /// ändert das Formular ihn nie: Wer hier eine andere Firma tippt,
  /// überschriebe ihn sonst. Der Schalter ist aus; schaltet man ihn an,
  /// entsteht ein neuer Firmenkunde. Gespeicherte ändert man im Browser.
  CustomerFormStart.customer(Customer c)
    : customerId = null,
      name = c.name,
      addressLine1 = c.addressLine1,
      addressLine2 = c.addressLine2,
      vatId = c.vatId ?? '',
      keep = false;

  final String? customerId;
  final String name;
  final String addressLine1;
  final String addressLine2;
  final String vatId;
  final bool keep;
}

/// Öffnet das Formular als eigene Seite über die ganze Breite (damit die
/// Tastatur Platz hat). `true`, wenn ein Empfänger zu [receipt] gespeichert
/// ist; `false` nach "Abbrechen" oder "Zurück".
Future<bool> openCustomerForm(
  BuildContext context, {
  required Receipt receipt,
  CustomerFormStart start = const CustomerFormStart(),
}) async {
  final saved = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => CustomerForm(receipt: receipt, start: start),
    ),
  );
  return saved ?? false;
}

/// Die Seite `customer-form`: Felder `customer-name`, `customer-address1`,
/// `customer-address2` und `customer-vat`, jedes mit sichtbarer Beschriftung
/// darüber und dem Grund darunter, solange [checkRecipient] dort etwas
/// findet (angesagt für die Vorlesehilfe). "Übernehmen" (`customer-save`)
/// ist bis dahin grau. Längen prüft die Regel, abgeschnitten wird nichts.
///
/// "Weiter" der Tastatur springt ins nächste Feld, "Fertig" im letzten tut
/// dasselbe wie "Übernehmen", wenn es geht. Mit "Als Firmenkunde speichern"
/// (`customer-keep`, an) wird der Firmenkunde angelegt oder geändert, sonst
/// entsteht nur der Empfänger. "Abbrechen" (`customer-cancel`) fragt nichts
/// und geht zurück: der Bon ist schon gespeichert. Meldet sich die Person
/// ab, geht die Seite von selbst zu.
class CustomerForm extends ConsumerStatefulWidget {
  const CustomerForm({
    super.key,
    required this.receipt,
    this.start = const CustomerFormStart(),
  });

  final Receipt receipt;
  final CustomerFormStart start;

  @override
  ConsumerState<CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends ConsumerState<CustomerForm> {
  late final _name = TextEditingController(text: widget.start.name);
  late final _address1 = TextEditingController(text: widget.start.addressLine1);
  late final _address2 = TextEditingController(text: widget.start.addressLine2);
  late final _vat = TextEditingController(text: widget.start.vatId);
  final _nameFocus = FocusNode();
  final _address1Focus = FocusNode();
  final _address2Focus = FocusNode();
  final _vatFocus = FocusNode();

  late bool _keep = widget.start.keep;

  /// Solange gespeichert wird, tun weitere Tipps nichts.
  bool _saving = false;
  bool _failed = false;

  /// Der Firmenkunde, den dieses Formular ändert; nach dem ersten Anlegen
  /// der neue, damit ein zweiter Versuch keinen zweiten anlegt.
  late String? _customerId = widget.start.customerId;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _address1, _address2, _vat]) {
      c.addListener(_changed);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _address1, _address2, _vat]) {
      c.dispose();
    }
    for (final f in [_nameFocus, _address1Focus, _address2Focus, _vatFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() => _failed = false);
  }

  Map<RecipientField, RecipientProblem?> get _problems =>
      recipientFieldProblems(
        name: _name.text,
        addressLine1: _address1.text,
        addressLine2: _address2.text,
        vatId: _vat.text,
        receiptTotalCents: widget.receipt.totalCents,
      );

  bool get _ready => _problems.values.every((p) => p == null);

  Future<void> _save() async {
    if (_saving || !_ready) return;
    final staff = ref.read(sessionProvider);
    if (staff == null) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    final repo = ref.read(customerRepositoryProvider);
    try {
      String? customerId;
      if (_keep) {
        final customer = await repo.save(
          id: _customerId,
          name: _name.text,
          addressLine1: _address1.text,
          addressLine2: _address2.text,
          vatId: _vat.text,
        );
        _customerId = customerId = customer.id;
      }
      await repo.setRecipient(
        receiptId: widget.receipt.id,
        customerId: customerId,
        name: _name.text,
        addressLine1: _address1.text,
        addressLine2: _address2.text,
        vatId: _vat.text,
        staff: staff,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  String? _problemText(L10n l, RecipientProblem? p) => switch (p) {
    null => null,
    RecipientProblem.nameMissing => l.customerNameMissing,
    RecipientProblem.addressMissing => l.customerAddressMissing,
    RecipientProblem.vatIdMissing => l.customerVatIdMissing,
    RecipientProblem.tooLong => l.customerTooLong,
  };

  @override
  Widget build(BuildContext context) {
    // Abgemeldet: zurück, ohne zu speichern.
    ref.listen(sessionProvider, (_, staff) {
      if (staff == null && mounted) Navigator.of(context).maybePop(false);
    });
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final problems = _problems;
    final ready = problems.values.every((p) => p == null);
    return Scaffold(
      key: const Key('customer-form'),
      backgroundColor: c.ground,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              constraints: const BoxConstraints(
                minHeight: KassaTokens.receiptHeaderHeight,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: KassaTokens.spaceHuge,
                vertical: KassaTokens.spaceMd,
              ),
              alignment: AlignmentDirectional.centerStart,
              decoration: BoxDecoration(
                color: c.card,
                border: Border(
                  bottom: BorderSide(
                    color: c.line,
                    width: KassaTokens.borderThin,
                  ),
                ),
              ),
              child: Semantics(
                header: true,
                child: Text(l.customerFormTitle, style: text.headlineMedium),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('customer-form-scroll'),
                padding: EdgeInsets.fromLTRB(
                  KassaTokens.spaceHuge,
                  KassaTokens.spaceHuge,
                  KassaTokens.spaceHuge,
                  // Den Platz der Tastatur nimmt schon das Scaffold weg.
                  KassaTokens.spaceHuge,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FormField(
                          fieldKey: const Key('customer-name'),
                          label: l.customerName,
                          controller: _name,
                          focusNode: _nameFocus,
                          capitalization: TextCapitalization.words,
                          action: TextInputAction.next,
                          onSubmitted: _address1Focus.requestFocus,
                          problem: _problemText(
                            l,
                            problems[RecipientField.name],
                          ),
                          autofocus: widget.start.name.isEmpty,
                        ),
                        _FormField(
                          fieldKey: const Key('customer-address1'),
                          label: l.customerAddress1,
                          controller: _address1,
                          focusNode: _address1Focus,
                          capitalization: TextCapitalization.words,
                          action: TextInputAction.next,
                          onSubmitted: _address2Focus.requestFocus,
                          problem: _problemText(
                            l,
                            problems[RecipientField.addressLine1],
                          ),
                        ),
                        _FormField(
                          fieldKey: const Key('customer-address2'),
                          label: l.customerAddress2,
                          controller: _address2,
                          focusNode: _address2Focus,
                          capitalization: TextCapitalization.words,
                          action: TextInputAction.next,
                          onSubmitted: _vatFocus.requestFocus,
                          problem: _problemText(
                            l,
                            problems[RecipientField.addressLine2],
                          ),
                        ),
                        _FormField(
                          fieldKey: const Key('customer-vat'),
                          label: l.customerVatId,
                          controller: _vat,
                          focusNode: _vatFocus,
                          capitalization: TextCapitalization.characters,
                          autocorrect: false,
                          action: TextInputAction.done,
                          onSubmitted: _save,
                          problem: _problemText(
                            l,
                            problems[RecipientField.vatId],
                          ),
                        ),
                        const SizedBox(height: KassaTokens.spaceMd),
                        AppToggle(
                          key: const Key('customer-keep'),
                          value: _keep,
                          label: l.customerKeep,
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _keep = v),
                        ),
                        if (_failed) ...[
                          const SizedBox(height: KassaTokens.spaceXl),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              l.customerSaveFailed,
                              key: const Key('customer-save-failed'),
                              style: text.bodyLarge!.copyWith(
                                fontWeight: FontWeight.w700,
                                color: c.warnInk,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: KassaTokens.spaceHuge),
                        Row(
                          children: [
                            Expanded(
                              child: PrimaryButton(
                                key: const Key('customer-cancel'),
                                label: l.customerCancel,
                                filled: false,
                                height: KassaTokens.secondaryActionHeight,
                                onPressed: () =>
                                    Navigator.of(context).maybePop(false),
                              ),
                            ),
                            const SizedBox(width: KassaTokens.spaceXl),
                            Expanded(
                              flex: 2,
                              child: PrimaryButton(
                                key: const Key('customer-save'),
                                label: l.customerSave,
                                height: KassaTokens.secondaryActionHeight,
                                onPressed: ready && !_saving ? _save : null,
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
          ],
        ),
      ),
    );
  }
}

/// Ein Feld mit Beschriftung darüber und, wenn es eines gibt, dem Grund
/// darunter ([problem], Schlüssel `<fieldKey>-problem`). Die Beschriftung ist
/// der Name des Felds für die Vorlesehilfe.
class _FormField extends StatefulWidget {
  const _FormField({
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.capitalization,
    required this.action,
    required this.onSubmitted,
    required this.problem,
    this.autocorrect = true,
    this.autofocus = false,
  });

  final Key fieldKey;
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextCapitalization capitalization;
  final TextInputAction action;
  final VoidCallback onSubmitted;
  final String? problem;
  final bool autocorrect;
  final bool autofocus;

  @override
  State<_FormField> createState() => _FormFieldState();
}

class _FormFieldState extends State<_FormField> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_changed);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final focused = widget.focusNode.hasFocus;
    final key = widget.fieldKey;
    final problemKey = key is ValueKey<String>
        ? Key('${key.value}-problem')
        : null;
    final problem = widget.problem;
    return Padding(
      padding: const EdgeInsets.only(bottom: KassaTokens.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Text(
              widget.label,
              style: text.bodyLarge!.copyWith(
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
          ),
          const SizedBox(height: KassaTokens.spaceSm),
          GestureDetector(
            key: widget.fieldKey,
            behavior: HitTestBehavior.opaque,
            onTap: widget.focusNode.requestFocus,
            child: Container(
              constraints: const BoxConstraints(
                minHeight: KassaTokens.keypadInputHeight,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: KassaTokens.spaceXxl,
                vertical: KassaTokens.spaceMd,
              ),
              alignment: AlignmentDirectional.centerStart,
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
                label: widget.label,
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  autofocus: widget.autofocus,
                  textCapitalization: widget.capitalization,
                  autocorrect: widget.autocorrect,
                  enableSuggestions: widget.autocorrect,
                  keyboardType: TextInputType.text,
                  textInputAction: widget.action,
                  onSubmitted: (_) => widget.onSubmitted(),
                  maxLines: 1,
                  // Name, Adresse und UID stehen so auf der deutschen
                  // Rechnung: von links nach rechts, auch auf Arabisch
                  // ("1010 Wien", nicht "Wien 1010"), am Anfang der Zeile.
                  textDirection: TextDirection.ltr,
                  textAlign: ltrAlign(context, TextAlign.start),
                  style: text.titleMedium!.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                  cursorColor: c.accent,
                  scrollPadding: const EdgeInsets.all(96),
                  decoration: const InputDecoration.collapsed(hintText: null),
                ),
              ),
            ),
          ),
          if (problem != null) ...[
            const SizedBox(height: KassaTokens.spaceSm),
            Semantics(
              liveRegion: true,
              child: Text(
                problem,
                key: problemKey,
                style: text.bodyLarge!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: c.warnInk,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
