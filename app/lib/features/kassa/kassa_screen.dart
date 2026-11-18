import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../devices/card_terminal.dart';
import '../../devices/device_providers.dart';
import '../../domain/catalog.dart';
import '../../ui/tokens.dart';
import '../../ui/undo_toast.dart';
import '../login/session.dart';
import 'card_wait.dart';
import 'cart_controller.dart';
import 'cart_panel.dart';
import 'cash_sheet.dart';
import 'category_rail.dart';
import 'item_grid.dart';
import 'modifier_panel.dart';
import 'sale_done.dart';
import 'sale_service.dart';

const _favoritesId = 'favorites';

const _cardMessageStay = Duration(seconds: 6);

/// Der Kassenbildschirm: Kategorien links, Artikel (oder das Zusammenstellen)
/// in der Mitte, der offene Bon rechts. Mit "Bar" wird die Bon-Spalte zum
/// Bezahlen, mit "Karte" zum Warten auf das Terminal, danach zur
/// Fertig-Ansicht; die Artikelfläche ist dabei halb ausgeblendet und reagiert
/// nicht.
class KassaScreen extends ConsumerStatefulWidget {
  const KassaScreen({super.key});

  @override
  ConsumerState<KassaScreen> createState() => _KassaScreenState();
}

/// Was die rechte Spalte zeigt.
enum _Side { cart, paying, waitingForCard, done }

class _KassaScreenState extends ConsumerState<KassaScreen> {
  String? _categoryId;
  Item? _building;
  _Side _side = _Side.cart;
  SaleResult? _paid;

  /// Der Betrag, auf den das Terminal wartet.
  int _cardCents = 0;

  /// Steht ab dem ersten Tipp auf "Karte" bis zum Ergebnis; ein zweiter Tipp im
  /// selben Bild startet nichts.
  bool _cardRunning = false;

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
    _prepareTerminal();
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

  Future<void> _payByCard() async {
    final staff = ref.read(sessionProvider);
    final cart = ref.read(cartProvider);
    if (_cardRunning || staff == null || cart.isEmpty) return;
    _cardRunning = true;
    setState(() {
      _cardCents = cart.totalCents;
      _side = _Side.waitingForCard;
    });
    final CardSaleOutcome outcome;
    try {
      outcome = await ref
          .read(saleServiceProvider)
          .payByCard(paymentId: const Uuid().v4(), cart: cart, staff: staff);
    } finally {
      _cardRunning = false;
    }
    if (!mounted) return;
    switch (outcome) {
      case CardSaleDone(:final sale):
        _onPaid(sale);
      case CardSaleFailed(:final message):
        setState(() => _side = _Side.cart);
        showUndoToast(
          context,
          message: message,
          stay: _cardMessageStay,
          viewKey: const Key('card-message'),
        );
      case CardSaleUnclear():
        // Der Bon ist leer; die Frage dazu liegt über der ganzen App.
        setState(() => _side = _Side.cart);
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
    if (catalog == null) return ColoredBox(color: c.ground);

    final favorites = [
      for (final i in catalog.items)
        if (i.favorite) i,
    ];
    final entries = [
      if (favorites.isNotEmpty)
        CategoryEntry(
          id: _favoritesId,
          name: 'Favoriten',
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
              opacity: _side == _Side.cart ? 1.0 : 0.5,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : KassaTokens.motionFade,
              curve: KassaTokens.motionCurve,
              child: IgnorePointer(
                ignoring: _side != _Side.cart,
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
                        title: entry?.name ?? '',
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
        switch (_side) {
          _Side.cart => CartPanel(
            onPayCash: () => setState(() => _side = _Side.paying),
            onPayCard: _payByCard,
            canPay: building == null,
          ),
          _Side.paying => _AboveBottomBar(
            child: CashSheet(
              cart: cart,
              onBack: () => setState(() => _side = _Side.cart),
              onPaid: _onPaid,
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
