import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('KassaApp baut ohne Fehler', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KassaApp()));
    expect(tester.takeException(), isNull);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('KassaApp begrenzt die Textvergrößerung auf 1,3',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const ProviderScope(child: KassaApp()));
    final scaler = MediaQuery.of(tester.element(find.byType(Scaffold)))
        .textScaler;
    expect(scaler.scale(10), closeTo(13, 0.001));
  });
}
