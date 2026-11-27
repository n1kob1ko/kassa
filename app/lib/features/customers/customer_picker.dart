// Rechnung an Firma (Spec 5.3) nach dem Bezahlen: die Taste und der
// Empfänger auf "Verkauf fertig" und im Detail eines Bons ([InvoiceBox]) und
// das Blatt "Firmenkunde wählen" ([CustomerPicker]). Gesucht wird über Tasten
// mit den Anfangsbuchstaben, die vorkommen, nie über die Tastatur.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../devices/printer.dart';
import '../../domain/customer.dart';
import '../../domain/receipt.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/print_problem_text.dart';
import '../../ui/tokens.dart';
import '../kassa/more_sheet.dart' show SheetHeader;
import '../kassa/sale_service.dart';
import '../login/session.dart';
import 'customer_form.dart';

/// Ob "Rechnung an Firma" bei [receipt] steht: der Schalter ist an, und der
/// Bon kann eine Rechnung bekommen ([invoiceAllowed]).
bool showsInvoice(RegisterSettings settings, Receipt receipt) =>
    settings.invoiceEnabled && invoiceAllowed(receipt);

/// Die Rechnung zu einem Bon. Ohne Empfänger die Taste "Rechnung an Firma"
/// (`invoice-button`, ruft [onPick]), mit [showHint] und einer Summe über
/// [invoiceHintAboveCents] darüber der Hinweis `invoice-hint`. Mit Empfänger
/// "Rechnung an" und sein Name (`invoice-recipient`), mit Drucker "Rechnung
/// drucken" (`invoice-print`) und "Ändern" (`invoice-change`, das Formular
/// mit den Werten der letzten Fassung). Was der Druck ergab, steht darunter
/// (`invoice-state`). Die Lade bleibt zu.
class InvoiceBox extends ConsumerStatefulWidget {
  const InvoiceBox({
    super.key,
    required this.receipt,
    required this.onPick,
    this.showHint = false,
  });

  final Receipt receipt;
  final VoidCallback onPick;
  final bool showHint;

  @override
  ConsumerState<InvoiceBox> createState() => _InvoiceBoxState();
}

class _InvoiceBoxState extends ConsumerState<InvoiceBox> {
  /// Solange gedruckt wird, tun weitere Tipps auf "Rechnung drucken" nichts.
  bool _printing = false;

  /// Das Ergebnis des letzten Drucks, `null` vor dem ersten.
  PrintOutcome? _outcome;

  bool _changing = false;

  Future<void> _print(ReceiptRecipient recipient) async {
    if (_printing) return;
    setState(() {
      _printing = true;
      _outcome = null;
    });
    final outcome = await ref
        .read(saleServiceProvider)
        .printInvoice(widget.receipt, recipient);
    if (!mounted) return;
    setState(() {
      _printing = false;
      _outcome = outcome;
    });
  }

  Future<void> _change(ReceiptRecipient recipient) async {
    if (_changing) return;
    _changing = true;
    try {
      final saved = await openCustomerForm(
        context,
        receipt: widget.receipt,
        start: CustomerFormStart.of(recipient),
      );
      if (saved && mounted) setState(() => _outcome = null);
    } finally {
      _changing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final settings =
        ref.watch(settingsStreamProvider).value ?? const RegisterSettings();
    final recipientState = ref.watch(
      receiptRecipientProvider(widget.receipt.id),
    );
    // Bis der Empfänger gelesen ist, steht nichts da.
    if (!recipientState.hasValue) return const SizedBox.shrink();
    final recipient = recipientState.value;
    final canPrint = settings.printerKind != PrinterKind.none;

    if (recipient == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHint &&
              widget.receipt.totalCents > invoiceHintAboveCents) ...[
            Text(
              l.invoiceHint400,
              key: const Key('invoice-hint'),
              style: text.bodyLarge!.copyWith(color: c.ink2),
            ),
            const SizedBox(height: KassaTokens.spaceMd),
          ],
          PrimaryButton(
            key: const Key('invoice-button'),
            label: l.invoiceButton,
            icon: LucideIcons.fileText,
            filled: false,
            height: 64,
            onPressed: widget.onPick,
          ),
        ],
      );
    }

    final outcome = _outcome;
    final problem = outcome?.problem;
    return Container(
      key: const Key('invoice-box'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
        border: Border.all(color: c.line, width: KassaTokens.borderButton),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.invoiceRecipient,
            style: text.bodyLarge!.copyWith(color: c.accentInk),
          ),
          const SizedBox(height: KassaTokens.spaceXs),
          Text(
            recipient.name,
            key: const Key('invoice-recipient'),
            style: text.titleLarge,
          ),
          Text(
            recipient.addressLine1,
            style: text.bodyLarge!.copyWith(color: c.ink2),
          ),
          Text(
            recipient.addressLine2,
            style: text.bodyLarge!.copyWith(color: c.ink2),
          ),
          if (outcome != null && problem != PrintProblem.notSetUp) ...[
            const SizedBox(height: KassaTokens.spaceSm),
            Semantics(
              liveRegion: true,
              child: Text(
                problem == null
                    ? l.invoicePrinted
                    : printProblemText(l, problem),
                key: const Key('invoice-state'),
                style: text.bodyLarge!.copyWith(
                  fontWeight: problem == null
                      ? FontWeight.w600
                      : FontWeight.w700,
                  color: problem == null ? c.ink2 : c.warnInk,
                ),
              ),
            ),
          ],
          if (canPrint) ...[
            const SizedBox(height: KassaTokens.spaceMd),
            PrimaryButton(
              key: const Key('invoice-print'),
              label: l.invoicePrint,
              icon: LucideIcons.printer,
              filled: false,
              height: 64,
              onPressed: _printing ? null : () => _print(recipient),
            ),
          ],
          const SizedBox(height: KassaTokens.spaceMd),
          PrimaryButton(
            key: const Key('invoice-change'),
            label: l.invoiceChange,
            filled: false,
            height: 64,
            onPressed: () => _change(recipient),
          ),
        ],
      ),
    );
  }
}

/// Das Blatt "Firmenkunde wählen" (`customer-picker`) in der Bon-Spalte
/// beziehungsweise im Detail: oben "Alle" (`customer-initial-all`) und je
/// Anfangsbuchstabe, der vorkommt, eine Taste (`customer-initial-<X>`), darunter
/// die Firmenkunden (`customer-row-<id>`, Name und erste Adress-Zeile), die
/// zuletzt verwendeten oben; unten "Neuer Kunde" (`customer-new`). Ein Tipp
/// auf eine Reihe macht den Kunden zum Empfänger und ruft [onChosen]; fehlt
/// dem Kunden etwas für diesen Bon (etwa die UID über 10.000 €), öffnet sich
/// das Formular mit seinen Werten. "Zurück" ruft [onClose].
class CustomerPicker extends ConsumerStatefulWidget {
  const CustomerPicker({
    super.key,
    required this.receipt,
    required this.onChosen,
    required this.onClose,
  });

  final Receipt receipt;
  final VoidCallback onChosen;
  final VoidCallback onClose;

  @override
  ConsumerState<CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends ConsumerState<CustomerPicker> {
  /// Der gewählte Anfangsbuchstabe, `null` für alle.
  String? _initial;

  late Future<({List<Customer> customers, List<String> initials})> _load =
      _read();

  /// Solange ein Kunde übernommen wird oder das Formular offen ist, tun
  /// weitere Tipps nichts.
  bool _busy = false;
  bool _failed = false;

  /// Bringt der Abgleich Firmenkunden, während die Auswahl offen ist, liest
  /// sie die Liste neu: ein archivierter verschwindet, ein neuer kommt dazu.
  StreamSubscription<void>? _changes;

  @override
  void initState() {
    super.initState();
    _changes = ref.read(customerRepositoryProvider).watchChanges().listen((_) {
      if (!mounted) return;
      setState(() {
        _load = _read();
      });
    });
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  Future<({List<Customer> customers, List<String> initials})> _read() async {
    final repo = ref.read(customerRepositoryProvider);
    return (customers: await repo.list(), initials: await repo.initials());
  }

  Future<void> _choose(Customer customer) async {
    if (_busy) return;
    final staff = ref.read(sessionProvider);
    if (staff == null) return;
    _busy = true;
    try {
      final problems = checkRecipient(
        name: customer.name,
        addressLine1: customer.addressLine1,
        addressLine2: customer.addressLine2,
        vatId: customer.vatId ?? '',
        receiptTotalCents: widget.receipt.totalCents,
      );
      if (problems.isNotEmpty) {
        await _form(CustomerFormStart.customer(customer));
        return;
      }
      await ref
          .read(customerRepositoryProvider)
          .setRecipient(
            receiptId: widget.receipt.id,
            customerId: customer.id,
            name: customer.name,
            addressLine1: customer.addressLine1,
            addressLine2: customer.addressLine2,
            vatId: customer.vatId,
            staff: staff,
          );
      if (mounted) widget.onChosen();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _busy = false;
    }
  }

  Future<void> _new() async {
    if (_busy) return;
    _busy = true;
    try {
      await _form(const CustomerFormStart());
    } finally {
      _busy = false;
    }
  }

  Future<void> _form(CustomerFormStart start) async {
    final saved = await openCustomerForm(
      context,
      receipt: widget.receipt,
      start: start,
    );
    if (!mounted) return;
    if (saved) {
      widget.onChosen();
    } else {
      setState(() {
        _load = _read();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    return Column(
      key: const Key('customer-picker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: l.customerPickerTitle,
          backKey: const Key('customer-picker-back'),
          onBack: widget.onClose,
        ),
        Expanded(
          child: FutureBuilder(
            future: _load,
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (data == null) return const SizedBox.shrink();
              final initial = data.initials.contains(_initial)
                  ? _initial
                  : null;
              final shown = [
                for (final c in data.customers)
                  if (initial == null || customerInitial(c.name) == initial) c,
              ];
              return ListView(
                key: const Key('customer-picker-scroll'),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                  if (data.customers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: KassaTokens.spaceXl,
                      ),
                      child: Text(
                        l.customerEmpty,
                        key: const Key('customer-empty'),
                        style: text.bodyLarge!.copyWith(color: c.ink2),
                      ),
                    )
                  else ...[
                    Wrap(
                      spacing: KassaTokens.spaceMd,
                      runSpacing: KassaTokens.spaceMd,
                      children: [
                        _InitialKey(
                          key: const Key('customer-initial-all'),
                          label: l.customerAll,
                          selected: initial == null,
                          onTap: () => setState(() => _initial = null),
                        ),
                        for (final x in data.initials)
                          _InitialKey(
                            key: Key('customer-initial-$x'),
                            label: x,
                            selected: initial == x,
                            onTap: () => setState(() => _initial = x),
                          ),
                      ],
                    ),
                    const SizedBox(height: KassaTokens.spaceXl),
                    for (final customer in shown)
                      _CustomerRow(
                        customer: customer,
                        onTap: () => _choose(customer),
                      ),
                  ],
                  if (_failed) ...[
                    const SizedBox(height: KassaTokens.spaceMd),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        l.customerSaveFailed,
                        key: const Key('customer-picker-failed'),
                        style: text.bodyLarge!.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.warnInk,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: PrimaryButton(
            key: const Key('customer-new'),
            label: l.customerNew,
            icon: LucideIcons.plus,
            filled: false,
            height: KassaTokens.secondaryActionHeight,
            onPressed: _new,
          ),
        ),
      ],
    );
  }
}

/// Eine Taste mit einem Anfangsbuchstaben (oder "Alle"), mindestens 48 dp im
/// Quadrat; die gewählte im Akzent.
class _InitialKey extends StatelessWidget {
  const _InitialKey({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: KassaTokens.minTap + 8,
          minHeight: KassaTokens.minTap + 8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: KassaTokens.spaceXl),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.accent : c.fill,
          borderRadius: BorderRadius.circular(KassaTokens.radiusLg),
        ),
        child: Text(
          label,
          style: text.titleMedium!.copyWith(
            fontWeight: FontWeight.w700,
            color: selected ? c.onAccent : c.ink,
          ),
        ),
      ),
    );
  }
}

/// Ein Firmenkunde in der Liste: Name und erste Adress-Zeile.
class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.customer, required this.onTap});

  final Customer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: KassaTokens.spaceMd),
      child: Pressable(
        key: Key('customer-row-${customer.id}'),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: KassaTokens.receiptLineMinHeight,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: KassaTokens.spaceLg,
          ),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
            border: Border.all(color: c.line, width: KassaTokens.borderButton),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                customer.name,
                style: text.bodyLarge!.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                customer.addressLine1,
                style: text.bodyMedium!.copyWith(color: c.ink2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
