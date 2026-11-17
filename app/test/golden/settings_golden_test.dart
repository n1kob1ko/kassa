import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:material_ui/material_ui.dart';

import '../support/settings_pump.dart';

// Bildvergleich der Einstellungen gegen den freigegebenen Entwurf. Neu
// erzeugen mit `flutter test --update-goldens test/golden/settings_golden_test.dart`.

void main() {
  testWidgets('Einstellungen (hell)', (t) async {
    await pumpSettings(t);
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/einstellungen_hell.png'),
    );
  });

  testWidgets('Einstellungen (dunkel)', (t) async {
    await pumpSettings(t, brightness: Brightness.dark);
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/einstellungen_dunkel.png'),
    );
  });

  testWidgets('Einstellungen, Speisekarte neu einspielen, Rückfrage (hell)', (t) async {
    await pumpSettings(t, pickedFile: demoOhneTeigtaschen());
    await t.tap(find.byKey(const Key('reimport')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/einstellungen_neu_einspielen_hell.png'),
    );
  });
}
