// Helfer für Tests des Bereichs Übersicht: Verkäufe zu bestimmten Zeiten
// anlegen und den Bereich als Chef öffnen.

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/features/login/session.dart';
import 'package:material_ui/material_ui.dart';

import 'bons_pump.dart';
import 'demo_fixtures.dart';
import 'kassa_pump.dart';
import 'pump.dart';

/// Der Standard-Bon: 2 x Cola und 1 x Huhn Bowl (XXL, Nudeln), 18,20 €.
Cart bowlCart() => const Cart.empty()
    .add(cola)
    .add(cola)
    .add(huhnBowl, options: [xxl, nudeln]);

/// Ein Verkauf zu einer bestimmten Zeit. Mit [voided] wird er danach (zur
/// Zeit [at]) storniert.
class OverviewSale {
  const OverviewSale(this.at, {this.cart, this.voided = false});

  final DateTime at;
  final Cart? cart;
  final bool voided;
}

DateTime today(int hour, [int minute = 0]) =>
    DateTime(2026, 11, 17, hour, minute);

/// Legt [sales] an (Chef, bar), setzt die Uhr auf [now] und öffnet den
/// Bereich Übersicht. Die Verkäufe müssen zeitlich aufsteigend stehen.
Future<void> pumpOverviewWithSales(
  WidgetTester t, {
  List<OverviewSale>? sales,
  DateTime? now,
  Size size = const Size(1280, 800),
  Brightness brightness = Brightness.light,
  List<Override> extraOverrides = const [],
  String? openRange,
  double textScale = 1.0,
}) async {
  final clock = FixedClock(today(11));
  final overrides = [...await memoryOverrides(clock: clock), ...extraOverrides];
  await pumpKassa(
    t,
    size: size,
    brightness: brightness,
    textScale: textScale,
    overrides: overrides,
  );
  await containerOf(t).read(sessionProvider.notifier).login('4711');
  await t.pump();
  for (final s
      in sales ?? [OverviewSale(today(11, 5)), OverviewSale(today(13, 10))]) {
    clock.value = s.at;
    await _closeForgottenDay(t);
    final r = await sellCash(t, cart: s.cart ?? bowlCart());
    if (s.voided) {
      await containerOf(t)
          .read(receiptRepositoryProvider)
          .voidReceipt(r.id, staff: containerOf(t).read(sessionProvider)!);
    }
  }
  clock.value = now ?? today(13, 40);
  await _closeForgottenDay(t);
  await t.tap(find.byKey(const Key('tab-Übersicht')));
  await t.pumpAndSettle();
  if (openRange != null) {
    await t.tap(find.byKey(Key('range-$openRange')));
    await t.pumpAndSettle();
  }
}

/// Schließt einen offenen Tag, der an einem früheren Kalendertag begann: die
/// Verkäufe über mehrere Tage sollen aussehen wie in einem Betrieb, der jeden
/// Abend abschließt (sonst zeigt die Kopfleiste den Hinweis auf den
/// vergessenen Abschluss).
Future<void> _closeForgottenDay(WidgetTester t) async {
  final days = containerOf(t).read(dayRepositoryProvider);
  if (await days.hasForgottenClose()) {
    await days.close(
      countedCents: 0,
      leftInDrawerCents: 0,
      staff: containerOf(t).read(sessionProvider)!,
    );
  }
}

/// Setzt die Uhr der laufenden App (nach [pumpOverviewWithSales]).
FixedClock clockOf(WidgetTester t) =>
    containerOf(t).read(clockProvider) as FixedClock;

/// Ein weiterer Barverkauf zur aktuellen Uhrzeit.
Future<Receipt> sellMore(WidgetTester t) => sellCash(t, cart: bowlCart());
