// Helfer für Tests des Bereichs Bons: Verkäufe anlegen und den Bereich öffnen.

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/features/login/session.dart';
import 'package:material_ui/material_ui.dart';

import 'demo_fixtures.dart';
import 'kassa_pump.dart';

int _sales = 0;

/// Verkauft [cart] bar (Standard: eine Cola) als die angemeldete Person.
/// Gegeben wird passend.
Future<Receipt> sellCash(WidgetTester t, {Cart? cart}) async {
  final c = cart ?? const Cart.empty().add(cola);
  final staff = containerOf(t).read(sessionProvider)!;
  return containerOf(t)
      .read(receiptRepositoryProvider)
      .finalizeCashSale(
        saleId: 'sale-${_sales++}',
        cart: c,
        givenCents: c.totalCents,
        staff: staff,
      );
}

/// Meldet [pin] an (Anna: 1234, Chef: 4711), legt [n] Barverkäufe an (jeder
/// ein anderer Artikel) und öffnet den Bereich Bons.
Future<void> pumpBonsWithSales(
  WidgetTester t,
  int n, {
  String pin = '1234',
  Size size = const Size(1280, 800),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  List<Override>? overrides,
}) async {
  await pumpKassa(
    t,
    size: size,
    brightness: brightness,
    textScale: textScale,
    overrides: overrides,
  );
  if (pin != '1234') {
    await containerOf(t).read(sessionProvider.notifier).login(pin);
    await t.pump();
  }
  const ids = ['cola', 'teigtaschen', 'pommes', 'mochi', 'edamame', 'eistee'];
  for (var i = 0; i < n; i++) {
    await sellCash(t, cart: const Cart.empty().add(catalog.item(ids[i % 6])));
  }
  await t.tap(find.byKey(const Key('tab-Bons')));
  await t.pumpAndSettle();
}

/// Tippt den Bon mit dieser Nummer in der Liste an.
Future<void> openReceipt(WidgetTester t, int number) async {
  await t.tap(find.byKey(Key('receipt-$number')));
  await t.pumpAndSettle();
}
