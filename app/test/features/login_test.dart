import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kassa/app.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/staff_repository.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/ui/business_logo.dart';
import 'package:kassa/ui/kassa_logo.dart';
import 'package:kassa/ui/keypad.dart';

import '../support/files_pump.dart';
import '../support/pump.dart';

/// Eine eingerichtete Kassa, niemand angemeldet: das Anmeldebild.
Future<void> pumpLoggedOut(WidgetTester t, {Size? size}) async {
  await pumpApp(
    t,
    const KassaApp(),
    overrides: await memoryOverrides(),
    size: size ?? const Size(1280, 800),
  );
  await t.pumpAndSettle();
}

/// Findet die PIN nicht, solange [broken] gesetzt ist: die Datenbank wirft.
class _BrokenStaff extends StaffRepository {
  _BrokenStaff(super.db);

  bool broken = true;

  @override
  Future<Staff?> findByPin(String pin) async {
    if (broken) throw StateError('Datenbank nicht lesbar');
    return super.findByPin(pin);
  }
}

void main() {
  testWidgets(
    'wirft die Anmeldung: Hinweis, die PIN-Tasten leben, der nächste Versuch klappt',
    (t) async {
      late _BrokenStaff repo;
      await pumpApp(
        t,
        const KassaApp(),
        overrides: [
          ...await memoryOverrides(),
          staffRepositoryProvider.overrideWith(
            (ref) => repo = _BrokenStaff(ref.watch(databaseProvider)),
          ),
        ],
      );
      await t.pumpAndSettle();
      await typePin(t, '1234');
      await t.pump();
      await t.pump();
      expect(
        find.text('Das hat nicht geklappt. Bitte nochmal versuchen.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('0 von 4 Ziffern eingegeben'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
      repo.broken = false;
      await typePin(t, '1234');
      await t.pumpAndSettle();
      expect(find.text('Anna'), findsOneWidget);
    },
  );

  testWidgets('eingerichtet und niemand angemeldet: Anmeldebild', (t) async {
    await pumpLoggedOut(t);
    expect(find.text('PIN eingeben'), findsOneWidget);
    expect(find.text('Jede Person hat ihre eigene PIN'), findsOneWidget);
    expect(find.text('Beispiel-Imbiss'), findsOneWidget);
    expect(find.byKey(const Key('key-comma')), findsNothing);
    expect(t.widget<Keypad>(find.byType(Keypad)).showComma, isFalse);
  });

  testWidgets(
    'falsche PIN: Hinweis, Punkte leeren sich, nächste Ziffer räumt auf',
    (t) async {
      await pumpLoggedOut(t);
      await typePin(t, '0000');
      await t.pump();
      await t.pump();
      expect(find.text('Diese PIN kennt die Kassa nicht.'), findsOneWidget);
      expect(
        find.bySemanticsLabel('0 von 4 Ziffern eingegeben'),
        findsOneWidget,
      );
      await tapKeys(t, '1');
      expect(find.text('Diese PIN kennt die Kassa nicht.'), findsNothing);
      expect(
        find.bySemanticsLabel('1 von 4 Ziffern eingegeben'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Chef meldet sich an und sieht alle fünf Reiter', (t) async {
    await pumpLoggedOut(t);
    await typePin(t, '4711');
    await t.pumpAndSettle();
    for (final name in ['Kassa', 'Bons', 'Übersicht', 'Artikel', 'Abschluss']) {
      expect(find.byKey(Key('tab-$name')), findsOneWidget);
    }
    expect(find.text('Chef'), findsOneWidget);
    expect(find.byKey(const Key('area-kassa')), findsOneWidget);
  });

  testWidgets('Mitarbeiter ohne Chef-Rolle sieht nur Kassa und Bons', (
    t,
  ) async {
    await pumpLoggedOut(t);
    await typePin(t, '1234');
    await t.pumpAndSettle();
    expect(find.text('Anna'), findsOneWidget);
    expect(find.byKey(const Key('tab-Kassa')), findsOneWidget);
    expect(find.byKey(const Key('tab-Bons')), findsOneWidget);
    for (final name in ['Übersicht', 'Artikel', 'Abschluss']) {
      expect(find.byKey(Key('tab-$name')), findsNothing);
    }
    expect(find.byKey(const Key('settings')), findsNothing);
  });

  testWidgets('Reiter wechseln den Bereich, nach der Anmeldung ist es Kassa', (
    t,
  ) async {
    await pumpLoggedOut(t);
    await typePin(t, '4711');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('tab-Bons')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('area-bons')), findsOneWidget);
    expect(find.byKey(const Key('area-kassa')), findsNothing);
    await t.tap(find.byKey(const Key('staff')));
    await t.pumpAndSettle();
    await typePin(t, '1234');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('area-kassa')), findsOneWidget);
  });

  testWidgets('Tipp auf den Namen in der Kopfleiste meldet ab', (t) async {
    await pumpLoggedOut(t);
    await typePin(t, '4711');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('staff')));
    await t.pumpAndSettle();
    expect(find.text('PIN eingeben'), findsOneWidget);
    expect(find.byKey(const Key('tab-Kassa')), findsNothing);
    expect(_session(t), isNull);
  });

  testWidgets('SessionController.login: unbekannte PIN gibt false', (t) async {
    await pumpLoggedOut(t);
    final c = ProviderScope.containerOf(t.element(find.byType(KassaApp)));
    final session = c.read(sessionProvider.notifier);
    expect(await session.login('9999'), isFalse);
    expect(c.read(sessionProvider), isNull);
    expect(await session.login('1234'), isTrue);
    expect(c.read(sessionProvider)!.name, 'Anna');
    session.logout();
    expect(c.read(sessionProvider), isNull);
    expect(c.read(staffRepositoryProvider), isNotNull);
  });

  group('Logo des Betriebs', () {
    final logo = find.byKey(const Key('business-logo'));

    testWidgets('ohne Logo steht das Logo der Kassa da', (t) async {
      await pumpLoggedOut(t);
      expect(find.byType(BusinessLogo), findsOneWidget);
      expect(logo, findsNothing);
      expect(find.byType(KassaLogo), findsOneWidget);
    });

    testWidgets('mit Logo steht es am Anmeldebild, im Platz des Kassa-Logos', (
      t,
    ) async {
      await pumpLoggedOut(t);
      final before = t.getRect(find.byType(KassaLogo));
      await putLogo(t);
      await settleImages(t, until: () => logo.evaluate().isNotEmpty);
      await settleImages(t);

      expect(logo, findsOneWidget);
      expect(find.byType(KassaLogo), findsNothing);
      expect(t.getRect(logo), before);
      expect(t.takeException(), isNull);
    });

    testWidgets('kaputte Logo-Datei: das Logo der Kassa, kein Fehler', (
      t,
    ) async {
      await pumpLoggedOut(t);
      await putLogo(t, bytes: Uint8List.fromList([9, 9, 9]));
      await settleImages(
        t,
        until: () => find
            .descendant(of: logo, matching: find.byType(KassaLogo))
            .evaluate()
            .isNotEmpty,
      );

      expect(find.byType(KassaLogo), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}

Object? _session(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(KassaApp)))
        .read(sessionProvider);
