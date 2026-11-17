import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/cart.dart';
import '../../domain/catalog.dart';

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

  void setQuantity(String lineId, int quantity) =>
      _set(state.setQuantity(lineId, quantity));

  void remove(String lineId) => _set(state.remove(lineId));

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

final cartProvider = NotifierProvider<CartController, Cart>(
  CartController.new,
);
