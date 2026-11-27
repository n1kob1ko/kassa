import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../core/money.dart';
import '../../data/card_payment_repository.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../devices/card_terminal.dart';
import '../../devices/device_providers.dart';
import '../../devices/printer_discovery.dart';
import '../../domain/catalog.dart';
import '../../l10n/generated/l10n.dart';
import '../../rksv/card/card_providers.dart';
import '../../rksv/online/atrust_client.dart';
import '../../rksv/online/online_providers.dart';
import '../../rksv/rksv_providers.dart';
import '../../rksv/rksv_state.dart';
import '../../ui/ltr.dart';
import '../../ui/menu_text.dart';
import '../../ui/tokens.dart';
import '../../ui/undo_toast.dart';
import '../login/session.dart';
import 'card_wait.dart';
import 'cart_controller.dart';
import 'cart_panel.dart';
import 'cash_sheet.dart';
import 'category_rail.dart';
import 'discount_sheet.dart';
import 'item_grid.dart';
import 'late_kitchen.dart';
import 'modifier_panel.dart';
import 'outage_banner.dart';
import 'sale_done.dart';
import 'sale_service.dart';
import 'tip_sheet.dart';

const _favoritesId = 'favorites';

const _cardMessageStay = Duration(seconds: 6);

/// Warum die Kartenzahlung nicht zustande kam, in der Bediensprache. Ein
/// Text des Anbieters ([CardFailed.detail]) bleibt, wie er kommt. Der
/// Kleinstbetrag steht auch in einem arabischen Satz von links nach rechts.
String cardSaleFailedText(BuildContext context, CardSaleFailed f) {
  final l = L10n.of(context);
  return switch (f.problem) {
    CardSaleProblem.alreadyRunning => l.cardAlreadyRunning,
    CardSaleProblem.emptyCart => l.cardEmptyReceipt,
    CardSaleProblem.belowMinimum => l.cardMinimum(
      ltrIsolate(context, formatEuro(f.minimumCents)),
    ),
    CardSaleProblem.notStarted => l.cardNotStarted,
    CardSaleProblem.terminal => switch (f.terminal) {
      null => l.cardFailed,
      CardFailed(:final failure, :final detail) => switch (failure) {
        CardFailure.declined => l.cardDeclined,
        CardFailure.cancelled => l.cardCancelled,
        CardFailure.noInternet => l.cardNoInternet,
        CardFailure.notLoggedIn => l.cardNotLoggedIn,
        CardFailure.noReader => l.cardNoReader,
        CardFailure.permission => l.cardPermission,
        CardFailure.other =>
          detail == null || detail.isEmpty
              ? l.cardFailed
              : l.cardFailedDetail(detail),
      },
    },
  };
}

/// Ob die Kassa seit dem Start der App schon einmal zu sehen war.
class _KassaMounts {
  bool seen = false;
}

final _kassaMountsProvider = Provider<_KassaMounts>((ref) => _KassaMounts());

/// Der Kassenbildschirm: Kategorien links, Artikel (oder das Zusammenstellen)
/// in der Mitte, der offene Bon rechts (in Arabisch gespiegelt). Mit "Bar" wird die Bon-Spalte zum
/// Bezahlen, mit "Karte" zum Warten auf das Terminal (ist Trinkgeld bei
/// Kartenzahlung eingeschaltet, zuerst zum Blatt "Trinkgeld"), danach zur
/// Fertig-Ansicht; die Artikelfläche ist dabei halb ausgeblendet und reagiert
/// nicht. Darf die angemeldete Person Rabatt geben, wird die Bon-Spalte mit
/// einem Tipp auf eine Zeile oder auf "Rabatt" zum Blatt "Rabatt". Eine Summe
/// von 0,00 € durch einen Rabatt schließt "Abschließen" ohne Bezahlen ab.
class KassaScreen extends ConsumerStatefulWidget {
  const KassaScreen({super.key});

  @override
  ConsumerState<KassaScreen> createState() => _KassaScreenState();
}

/// Was die rechte Spalte zeigt.
enum _Side { cart, paying, tip, discount, waitingForCard, done }

class _KassaScreenState extends ConsumerState<KassaScreen>
    with WidgetsBindingObserver {
  String? _categoryId;
  Item? _building;
  _Side _side = _Side.cart;
  SaleResult? _paid;

  /// Der Betrag, auf den das Terminal wartet (mit Trinkgeld).
  int _cardCents = 0;

  /// Der Bar-Teil der Kartenzahlung, die eben vorbereitet wird ("Teil bar");
  /// 0 ohne.
  int _cashPartCents = 0;

  /// Die Karte mit Bar-Teil ist sicher gescheitert: der Bar-Teil und der
  /// Grund, bis sich der Bon ändert oder eine Zahlung beginnt. Wird nicht
  /// gespeichert.
  ({int cashPartCents, CardSaleFailed failure})? _splitFailed;

  /// Steht ab dem ersten Tipp auf "Karte" bis zum Ergebnis; ein zweiter Tipp im
  /// selben Bild startet nichts.
  bool _cardRunning = false;

  /// Die Zeile, für die das Blatt "Rabatt" offen ist; null: der ganze Bon.
  String? _discountLineId;

  /// Die Kennung des Bons für "Abschließen" bei Summe 0: ein neuer Versuch
  /// nach einem Fehler schreibt denselben Bon. Jede Änderung des Bons nimmt
  /// sie weg.
  String? _freeSaleId;

  /// Steht ab dem ersten Tipp auf "Abschließen" bis zum Ergebnis; so lange
  /// nimmt die Bon-Spalte keine Tipps.
  bool _finishingFree = false;

  /// Was die Person eben getippt hat, bis die Datenbank es bestätigt: so
  /// wechselt die Ansicht im selben Bild.
  bool? _imagesOverride;

  void _selectCategory(String id) => setState(() {
    _categoryId = id;
    _building = null;
  });

  void _setImages(bool value) {
    setState(() => _imagesOverride = value);
    final repo = ref.read(settingsRepositoryProvider);
    repo
        .current()
        .then((s) => repo.save(s.copyWith(showImages: value)))
        .catchError((Object _) {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prepareTerminal();
    _preparePrinter();
    // Nur das erste Bild der Kassa nach dem Start der App darf Android nach
    // dem Kartenleser fragen lassen; ein Wechsel der Bereiche nicht (C5).
    final first = ref.read(_kassaMountsProvider);
    _warmUpSignature(ask: !first.seen);
    first.seen = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _preparePrinter();
      _warmUpSignature(ask: true);
    }
  }

  /// Meldet die Kassa in der Online-Probe oder in Betrieb im Voraus bei
  /// A-Trust an, am Halter des Systems der laufenden Kette, damit der
  /// nächste Bon nicht auf die Anmeldung wartet. Läuft eine Kette mit Karte
  /// (Karten-Probe oder in Betrieb), öffnet der Halter der Karte die Sitzung
  /// im Voraus; nur hier, beim Start und beim Fortsetzen ([ask]), darf
  /// Android dafür nach der Erlaubnis für den Kartenleser fragen (C6). In Betrieb liest das
  /// Journal dazu den AES-Schlüssel in den Speicher (Q17). Ohne laufende
  /// Kette von A-Trust entsteht weder Sitzungshalter noch Verbindung; nach
  /// einer Ablehnung schickt der Halter selbst nichts. Auf nichts davon
  /// wartet ein Verkauf oder das erste Bild: Wer das ruft, wartet nicht, und
  /// Fehler gehen still unter.
  Future<void> _warmUpSignature({required bool ask}) async {
    try {
      final state = await ref.read(rksvStateProvider.future);
      if (!mounted) return;
      if (state.unit == RksvUnit.atrust || state.unit == RksvUnit.card) {
        // Ohne Frist, wenn der geschützte Speicher hängt: nie darauf warten.
        ref.read(rksvJournalProvider).primeLiveKey().ignore();
      }
      final system = switch (state.unit) {
        RksvUnit.atrustTest => AtrustSystem.test,
        RksvUnit.atrust => AtrustSystem.live,
        RksvUnit.probe || RksvUnit.cardTest || RksvUnit.card || null => null,
      };
      if (system == null) {
        if (state.unit == RksvUnit.cardTest || state.unit == RksvUnit.card) {
          // Wirft nie.
          ref.read(cardSignerProvider).warmUp(ask: ask).ignore();
        }
        return;
      }
      final keeper = ref.read(atrustKeeperProvider(system));
      try {
        await keeper.restore();
      } catch (_) {
        // Der Halter schickt nichts, solange er das Kennzeichen nicht kennt.
      }
      if (!mounted) return;
      keeper.warmUp();
    } catch (_) {}
  }

  /// Eine Frage nach der Erlaubnis für den Drucker läuft gerade.
  bool _askingPrinter = false;

  /// Wann die letzte Frage abgelehnt wurde. Das Schließen der Frage selbst
  /// bringt die App wieder in den Vordergrund; gleich danach wird nicht
  /// noch einmal gefragt.
  DateTime? _printerRefusedAt;

  static const _askAgainAfter = Duration(seconds: 10);

  /// Holt die Erlaubnis für einen USB- oder Bluetooth-Drucker, bevor der erste
  /// Bon gedruckt wird: Android vergisst sie für USB, wenn der Drucker
  /// ausgeschaltet oder das Tablet neu gestartet wird. Netzwerk braucht keine.
  /// Fehler gehen still unter: ein Gerät hält nie einen Verkauf auf.
  Future<void> _preparePrinter() async {
    if (_askingPrinter) return;
    final clock = ref.read(clockProvider);
    final refused = _printerRefusedAt;
    if (refused != null && clock.now().difference(refused) < _askAgainAfter) {
      return;
    }
    // Während einer Kartenzahlung liegt der Bildschirm von SumUp darüber.
    if (ref.read(activeCardPaymentProvider) != null) return;
    _askingPrinter = true;
    try {
      final settings = await ref.read(settingsRepositoryProvider).current();
      final address = settings.printerAddress?.trim() ?? '';
      final kind = settings.printerKind;
      if (address.isEmpty ||
          (kind != PrinterKind.usb && kind != PrinterKind.bluetooth)) {
        return;
      }
      final granted = await ref
          .read(printerDiscoveryProvider)
          .requestAccess(kind, address);
      _printerRefusedAt = granted ? null : clock.now();
    } catch (_) {
    } finally {
      _askingPrinter = false;
    }
  }

  /// Weckt den Kartenleser, wenn das Terminal angemeldet ist. Fehler gehen
  /// still unter: ein Gerät hält nie einen Verkauf auf.
  Future<void> _prepareTerminal() async {
    try {
      final status = await ref.read(cardStatusProvider.future);
      if (!mounted || status.state != CardTerminalState.ready) return;
      await ref.read(cardTerminalProvider).prepare();
    } catch (_) {}
  }

  void _onPaid(SaleResult result) {
    setState(() {
      _paid = result;
      _side = _Side.done;
    });
    unawaited(_prepareTerminal());
  }

  /// "Bar": das Blatt "Bar bezahlen"; ein Hinweis nach einer gescheiterten
  /// Karte mit Bar-Teil geht weg.
  void _tapCash() => setState(() {
    _splitFailed = null;
    _side = _Side.paying;
  });

  /// "Karte": mit Trinkgeld bei Kartenzahlung zuerst das Blatt "Trinkgeld",
  /// sonst direkt zum Terminal.
  void _tapCard() => _toCard(0);

  /// "Weiter zur Karte" im Blatt "Bar bezahlen": der Rest nach [cashPartCents]
  /// geht wie "Karte" weiter.
  void _toCard(int cashPartCents) {
    final settings =
        ref.read(settingsStreamProvider).value ?? const RegisterSettings();
    if (settings.cardTipEnabled) {
      if (_cardRunning || ref.read(cartProvider).isEmpty) {
        if (_side == _Side.paying) setState(() => _side = _Side.cart);
        return;
      }
      setState(() {
        _splitFailed = null;
        _cashPartCents = cashPartCents;
        _side = _Side.tip;
      });
    } else {
      _cashPartCents = cashPartCents;
      _payByCard();
    }
  }

  Future<void> _payByCard({int tipCents = 0}) async {
    final staff = ref.read(sessionProvider);
    final cart = ref.read(cartProvider);
    final cashPartCents = _cashPartCents;
    if (_cardRunning || staff == null || cart.isEmpty) {
      if (_side == _Side.tip || _side == _Side.paying) {
        setState(() => _side = _Side.cart);
      }
      return;
    }
    _cardRunning = true;
    setState(() {
      _splitFailed = null;
      _cardCents = terminalAmountCents(
        totalCents: cart.totalCents,
        cashPartCents: cashPartCents,
        tipCents: tipCents,
      );
      _side = _Side.waitingForCard;
    });
    CardSaleOutcome? outcome;
    try {
      outcome = await ref
          .read(saleServiceProvider)
          .payByCard(
            paymentId: const Uuid().v4(),
            cart: cart,
            staff: staff,
            cashPartCents: cashPartCents,
            tipCents: tipCents,
          );
    } catch (_) {
      // payByCard wirft nicht; falls doch, zurück zum Bon. Gibt es eine offene
      // Zahlung, fragt das Blatt danach.
      outcome = null;
    } finally {
      _cardRunning = false;
    }
    if (!mounted) return;
    if (outcome == null) {
      setState(() => _side = _Side.cart);
      return;
    }
    switch (outcome) {
      case CardSaleDone(:final sale):
        _onPaid(sale);
      case final CardSaleFailed failure when cashPartCents > 0:
        // Der Bar-Teil liegt schon in der Hand: der Hinweis bleibt stehen,
        // bis sich der Bon ändert oder eine Zahlung beginnt.
        setState(() {
          _side = _Side.cart;
          _splitFailed = (cashPartCents: cashPartCents, failure: failure);
        });
      case CardSaleFailed():
        setState(() => _side = _Side.cart);
        showUndoToast(
          context,
          message: cardSaleFailedText(context, outcome),
          stay: _cardMessageStay,
          viewKey: const Key('card-message'),
        );
      case CardSaleUnclear():
        // Der Bon ist leer; die Frage dazu liegt über der ganzen App.
        setState(() => _side = _Side.cart);
    }
  }

  void _openDiscount(String? lineId) => setState(() {
    _discountLineId = lineId;
    _side = _Side.discount;
  });

  /// "Abschließen": ein Bon mit Summe 0,00 € durch einen Rabatt, ohne
  /// Zahlung und ohne Lade.
  Future<void> _finishFree() async {
    final staff = ref.read(sessionProvider);
    final cart = ref.read(cartProvider);
    if (_finishingFree || staff == null || cart.isEmpty) return;
    if (cart.totalCents != 0) return;
    setState(() => _finishingFree = true);
    final saleId = _freeSaleId ??= const Uuid().v4();
    final cartCtl = ref.read(cartProvider.notifier);
    try {
      final result = await ref
          .read(saleServiceProvider)
          .completeFree(saleId: saleId, cart: cart, staff: staff);
      // Der Bon ist gespeichert: der offene Bon und sein Entwurf gehen weg.
      cartCtl.clear();
      _freeSaleId = null;
      if (mounted) _onPaid(result);
    } catch (_) {
      if (mounted) {
        showUndoToast(
          context,
          message: L10n.of(context).kassaSaveFailed,
          stay: _cardMessageStay,
          viewKey: const Key('finish-free-failed'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _finishingFree = false);
      } else {
        _finishingFree = false;
      }
    }
  }

  void _tapItem(Catalog catalog, Item item) {
    if (catalog.templateOf(item) != null) {
      setState(() => _building = item);
    } else {
      ref.read(cartProvider.notifier).add(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    ref.listen(settingsStreamProvider, (_, next) {
      if (next.value?.showImages == _imagesOverride) _imagesOverride = null;
    });
    final catalog = ref.watch(catalogStreamProvider).value;
    final stored =
        ref.watch(settingsStreamProvider).value ?? const RegisterSettings();
    final showImages = _imagesOverride ?? stored.showImages;
    final cart = ref.watch(cartProvider);
    final cartCtl = ref.read(cartProvider.notifier);
    ref.listen(cartProvider, (prev, next) {
      if (!identical(prev, next)) _freeSaleId = null;
      if (_splitFailed != null && !identical(prev, next)) {
        setState(() => _splitFailed = null);
      }
    });
    final mayDiscount = stored.discountAccess.allows(
      ref.watch(sessionProvider),
    );
    // Wird der Rabatt ausgeschaltet, während das Blatt offen ist, steht
    // wieder der Bon da.
    final side = _side == _Side.discount && !mayDiscount ? _Side.cart : _side;
    if (catalog == null) return ColoredBox(color: c.ground);

    final favorites = [
      for (final i in catalog.items)
        if (i.favorite) i,
    ];
    final entries = [
      if (favorites.isNotEmpty)
        CategoryEntry(
          id: _favoritesId,
          name: L10n.of(context).kassaFavorites,
          count: favorites.length,
          isFavorites: true,
        ),
      for (final k in catalog.categories)
        CategoryEntry(
          id: k.id,
          name: k.name,
          count: catalog.items.where((i) => i.categoryId == k.id).length,
        ),
    ];
    final selected = entries.any((e) => e.id == _categoryId)
        ? _categoryId
        : (entries.isEmpty ? null : entries.first.id);
    final entry = entries.where((e) => e.id == selected).firstOrNull;
    final items = selected == _favoritesId
        ? favorites
        : [
            for (final i in catalog.items)
              if (i.categoryId == selected) i,
          ];
    final quantities = <String, int>{};
    for (final l in cart.lines) {
      quantities[l.item.id] = (quantities[l.item.id] ?? 0) + l.quantity;
    }
    final building = _building;
    final template = building == null ? null : catalog.templateOf(building);

    // Unten bleibt Platz für die Gestenleiste. Die Bon-Spalte füllt ihn mit
    // ihrer Fläche selbst aus.
    final bottomBar = MediaQuery.paddingOf(context).bottom;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: bottomBar),
          child: CategoryRail(
            entries: entries,
            selectedId: selected,
            onSelected: _selectCategory,
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomBar),
            child: AnimatedOpacity(
              key: const Key('item-area-dim'),
              opacity: side == _Side.cart ? 1.0 : 0.5,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : KassaTokens.motionFade,
              curve: KassaTokens.motionCurve,
              child: IgnorePointer(
                ignoring: side != _Side.cart,
                child: building != null && template != null
                    ? ModifierPanel(
                        key: Key('builder-${building.id}'),
                        item: building,
                        template: template,
                        onCancel: () => setState(() => _building = null),
                        onAdd: (options) {
                          cartCtl.add(building, options: options);
                          setState(() => _building = null);
                        },
                      )
                    : ItemArea(
                        title: switch (entry) {
                          null => '',
                          CategoryEntry(isFavorites: true) => entry.name,
                          _ => ref.watch(menuTextProvider)(entry.name),
                        },
                        items: items,
                        quantities: quantities,
                        showImages: showImages,
                        onShowImages: _setImages,
                        onItem: (item) => _tapItem(catalog, item),
                      ),
              ),
            ),
          ),
        ),
        switch (side) {
          _Side.cart => AbsorbPointer(
            key: const Key('cart-busy'),
            absorbing: _finishingFree,
            child: CartPanel(
              onPayCash: _tapCash,
              onPayCard: _tapCard,
              canPay: building == null,
              onLineDiscount: mayDiscount ? _openDiscount : null,
              onReceiptDiscount: mayDiscount ? () => _openDiscount(null) : null,
              onFinishFree: _finishFree,
              payNotice: switch (_splitFailed) {
                null => null,
                final f => SplitCardFailedNotice(
                  cashPartCents: f.cashPartCents,
                  failure: f.failure,
                ),
              },
              notice: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [OutageBanner(), LateKitchenNotice()],
              ),
            ),
          ),
          _Side.paying => _AboveBottomBar(
            child: CashSheet(
              cart: cart,
              onBack: () => setState(() => _side = _Side.cart),
              onPaid: _onPaid,
              onSplit: _toCard,
            ),
          ),
          _Side.tip => _AboveBottomBar(
            child: TipSheet(
              dueCents: cart.totalCents - _cashPartCents,
              receiptTotalCents: cart.totalCents,
              onBack: () => setState(() => _side = _Side.cart),
              onPay: (tip) => _payByCard(tipCents: tip),
            ),
          ),
          _Side.discount => _AboveBottomBar(
            child: DiscountSheet(
              key: ValueKey(_discountLineId),
              lineId: _discountLineId,
              onClose: () => setState(() => _side = _Side.cart),
            ),
          ),
          _Side.waitingForCard => _AboveBottomBar(
            child: CardWait(amountCents: _cardCents),
          ),
          _Side.done => _AboveBottomBar(
            child: SaleDone(
              result: _paid!,
              onNext: () => setState(() {
                _paid = null;
                _side = _Side.cart;
              }),
            ),
          ),
        },
      ],
    );
  }
}

/// Über dem Summenblock, nachdem die Karte mit Bar-Teil sicher nicht bezahlt
/// wurde: den Bar-Teil zurückgeben oder noch einmal versuchen, darunter der
/// Grund. Bleibt stehen, bis die Kassa ihn wegnimmt.
class SplitCardFailedNotice extends StatelessWidget {
  const SplitCardFailedNotice({
    super.key,
    required this.cashPartCents,
    required this.failure,
  });

  final int cashPartCents;
  final CardSaleFailed failure;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    return Container(
      key: const Key('split-card-failed'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.warnBg,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
      ),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.splitCardFailed(ltrIsolate(context, formatEuro(cashPartCents))),
              style: text.bodyMedium!.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: c.warnInk,
              ),
            ),
            const SizedBox(height: KassaTokens.spaceXxs),
            Text(
              cardSaleFailedText(context, failure),
              style: text.bodyMedium!.copyWith(color: c.warnInk),
            ),
          ],
        ),
      ),
    );
  }
}

/// Die rechte Spalte außer dem Bon bleibt über der Gestenleiste; der Streifen
/// darunter hat die Farbe der Spalte.
class _AboveBottomBar extends StatelessWidget {
  const _AboveBottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: KassaColors.of(context).card,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: child,
      ),
    );
  }
}
