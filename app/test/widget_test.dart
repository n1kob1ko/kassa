import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:material_ui/material_ui.dart';

import 'support/pump.dart';

void main() {
  testWidgets('KassaApp baut ohne Fehler', (tester) async {
    await pumpApp(tester, const KassaApp(), overrides: await memoryOverrides());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('KassaApp begrenzt die Textvergrößerung auf 1,3',
      (tester) async {
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
