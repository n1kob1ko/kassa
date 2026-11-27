import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/cart.dart';
import '../../domain/catalog.dart';
import '../../domain/discount.dart';

/// Der offene Bon der Kassa. Er gehört zur Kassa, nicht zur angemeldeten
/// Person: Abmelden und Anmelden lässt ihn stehen. Jede Änderung schreibt den
/// Entwurf in die Datenbank (ein leerer Bon löscht ihn), beim Start wird er
/// einmal gelesen.
class CartController extends Notifier<Cart> {
  bool _changed = false;

  @override
  Cart build() {
    _restoreDraft();
    // Der offene Bon folgt dem Katalog, wie nach einem Neustart: neuer Preis,
    // neue Optionen, Zeilen ohne Artikel fallen weg.
    ref.listen(catalogStreamProvider, (_, next) {
      final catalog = next.value;
      if (catalog == null || state.isEmpty) return;
      _set(state.rebind(catalog));
    });
    return const Cart.empty();
  }

  void add(Item item, {List<ModifierOption> options = const []}) =>
      _set(state.add(item, options: options));

  /// Ein freier Betrag als eigene Zeile (siehe [Cart.addOpenAmount]).
  void addOpenAmount({required int amountCents, required TaxRate rate}) =>
      _set(state.addOpenAmount(amountCents: amountCents, rate: rate));

  /// Ein verkaufter Gutschein über [valueCents] als eigene Zeile (siehe
  /// [Cart.addVoucherSale]).
  void addVoucherSale({required int valueCents}) =>
      _set(state.addVoucherSale(valueCents: valueCents));

  /// Die Menge einer Zeile. Bei einer Zeile "Pfand zurück" geht sie über
  /// [Cart.setDepositReturn]: höchstens 99, 0 nimmt die Zeile weg. Eine
  /// Gutschein-Zeile hat immer die Menge 1: mehr ändert nichts.
  void setQuantity(String lineId, int quantity) {
    final line = state.lines.where((l) => l.lineId == lineId).firstOrNull;
    if (line != null && line.isVoucherSale && quantity > 1) return;
    if (line != null && line.isDepositReturn) {
      setDepositReturns({
        -line.item.depositCents: quantity.clamp(0, maxQuantity),
      });
      return;
    }
    _set(state.setQuantity(lineId, quantity));
  }

  /// Setzt jede Reihe des Blatts "Pfand zurück" in einem Schritt: je Betrag
  /// in Cent die Menge (0 nimmt die Zeile weg). Ändert sich nichts, bleibt
  /// der Bon, wie er ist.
  void setDepositReturns(Map<int, int> quantityByCents) {
    var next = state;
    for (final e in quantityByCents.entries) {
      if (next.depositReturnQuantity(e.key) == e.value) continue;
      next = next.setDepositReturn(depositCents: e.key, quantity: e.value);
    }
    if (identical(next, state)) return;
    _set(next);
  }

  void remove(String lineId) => _set(state.remove(lineId));

  /// Rabatt auf eine Zeile; null nimmt ihn weg.
  void setLineDiscount(String lineId, Discount? discount) =>
      _set(state.setLineDiscount(lineId, discount));

  /// Rabatt auf den ganzen Bon; null nimmt ihn weg.
  void setReceiptDiscount(Discount? discount) =>
      _set(state.setReceiptDiscount(discount));

  void clear() => _set(const Cart.empty());

  /// Setzt einen früheren Bon wieder ein ("Rückgängig"), aber nur auf einen
  /// leeren Bon: was inzwischen auf dem Bon liegt, wird nie ersetzt.
  void restore(Cart cart) {
    if (!state.isEmpty) return;
    _set(cart);
  }

  void _set(Cart cart) {
    _changed = true;
    state = cart;
    _writeDraft(cart);
  }

  void _writeDraft(Cart cart) {
    final json = cart.isEmpty ? null : jsonEncode(cart.toJson());
    // Der Bildschirm wartet nicht auf die Datenbank. Ein Fehler beim
    // Speichern darf das Bonieren nicht stören.
    ref
        .read(settingsRepositoryProvider)
        .writeDraft(json)
        .catchError((Object _) {});
  }

  Future<void> _restoreDraft() async {
    final repo = ref.read(settingsRepositoryProvider);
    try {
      final raw = await repo.readDraft();
      if (raw == null) return;
      final catalog = await ref.read(catalogProvider.future);
      if (!ref.mounted) return;
      if (catalog == null) return;
      final cart = Cart.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
        catalog,
      );
      if (_changed) return;
      if (cart.isEmpty) {
        await repo.writeDraft(null);
        return;
      }
      state = cart;
    } catch (_) {
      // Ein Entwurf, den es nicht lesen kann, wird verworfen.
      if (ref.mounted && !_changed) {
        await repo.writeDraft(null).catchError((Object _) {});
      }
    }
  }
}

final cartProvider = NotifierProvider<CartController, Cart>(CartController.new);
