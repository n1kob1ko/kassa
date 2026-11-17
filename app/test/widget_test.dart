import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/data/catalog_repository.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:material_ui/material_ui.dart';

import 'support/pump.dart';

/// Eine Speisekarte, deren Lesen scheitert, solange [broken] gesetzt ist.
class _BrokenCatalog extends CatalogRepository {
  _BrokenCatalog(super.db);

  bool broken = true;

  @override
  Future<Catalog?> current() async {
    if (broken) throw StateError('Platte nicht lesbar');
    return super.current();
  }
}

void main() {
  testWidgets(
    'scheitert das erste Lesen der Datenbank: Fehleransicht mit Nochmal versuchen',
    (t) async {
      final base = await memoryOverrides();
      late _BrokenCatalog repo;
      final List<Override> overrides = [
        ...base,
        catalogRepositoryProvider.overrideWith(
          (ref) => repo = _BrokenCatalog(ref.watch(databaseProvider)),
        ),
      ];
      await pumpApp(t, const KassaApp(), overrides: overrides);
      await t.pump();
      await t.pump();
      expect(find.text('Die Kassa kann nicht starten.'), findsOneWidget);
      expect(
        find.text('Die Daten auf diesem Tablet lassen sich nicht lesen.'),
        findsOneWidget,
      );
      expect(find.textContaining('StateError'), findsOneWidget);
      expect(find.textContaining('Platte nicht lesbar'), findsOneWidget);
      expect(find.text('Nochmal versuchen'), findsOneWidget);
      // Die Datenbank liest wieder: die Taste führt weiter (zur Anmeldung).
      repo.broken = false;
      await t.tap(find.text('Nochmal versuchen'));
      await t.pumpAndSettle();
      expect(find.text('Die Kassa kann nicht starten.'), findsNothing);
      expect(find.text('Nochmal versuchen'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('KassaApp baut ohne Fehler', (tester) async {
    await pumpApp(tester, const KassaApp(), overrides: await memoryOverrides());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('KassaApp begrenzt die Textvergrößerung auf 1,3', (tester) async {
    await pumpApp(
      tester,
      const KassaApp(),
      textScale: 2.0,
      overrides: await memoryOverrides(),
    );
    await tester.pumpAndSettle();
    final scaler = MediaQuery.of(tester.element(find.byType(Scaffold)))
        .textScaler;
    expect(scaler.scale(10), closeTo(13, 0.001));
  });
}
