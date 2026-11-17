import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/ui/app_header.dart';
import 'package:kassa/ui/app_toggle.dart';
import 'package:kassa/ui/pressable.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:kassa/ui/segmented.dart';
import 'package:kassa/ui/tokens.dart';
import 'package:kassa/ui/undo_toast.dart';
import 'package:material_ui/material_ui.dart';

import '../support/pump.dart';

AppHeader header({
  bool isChef = false,
  AppArea area = AppArea.kassa,
  ValueChanged<AppArea>? onArea,
  VoidCallback? onStaff,
  VoidCallback? onSettings,
}) => AppHeader(
  area: area,
  onArea: onArea ?? (_) {},
  staffName: isChef ? 'Chef' : 'Anna',
  isChef: isChef,
  onStaff: onStaff ?? () {},
  onSettings: onSettings ?? () {},
);

class _Probe extends StatefulWidget {
  const _Probe(this.inits);
  final List<int> inits;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.inits.add(1);
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 100, height: 60);
}

void main() {
  group('Kopfleiste', () {
    testWidgets('zeigt Mitarbeitern nur Kassa und Bons', (t) async {
      await pumpApp(t, header());
      expect(find.byKey(const Key('tab-Kassa')), findsOneWidget);
      expect(find.byKey(const Key('tab-Bons')), findsOneWidget);
      expect(find.byKey(const Key('tab-Abschluss')), findsNothing);
      expect(find.byKey(const Key('tab-Übersicht')), findsNothing);
      expect(find.byKey(const Key('settings')), findsNothing);
      expect(find.byKey(const Key('staff')), findsOneWidget);
      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Kassa'), findsNWidgets(2)); // Wortmarke und Reiter
    });

    testWidgets('zeigt dem Chef alle Reiter und die Einstellungen', (t) async {
      final areas = <AppArea>[];
      var staff = 0, settings = 0;
      await pumpApp(
        t,
        header(
          isChef: true,
          onArea: areas.add,
          onStaff: () => staff++,
          onSettings: () => settings++,
        ),
      );
      for (final name in [
        'Kassa',
        'Bons',
        'Übersicht',
        'Artikel',
        'Abschluss',
      ]) {
        expect(find.byKey(Key('tab-$name')), findsOneWidget, reason: name);
      }
      await t.tap(find.byKey(const Key('tab-Abschluss')));
      await t.tap(find.byKey(const Key('tab-Bons')));
      await t.tap(find.byKey(const Key('staff')));
      await t.tap(find.byKey(const Key('settings')));
      expect(areas, [AppArea.close, AppArea.bons]);
      expect(staff, 1);
      expect(settings, 1);
    });

    testWidgets('Reiter ist 44 dp gezeichnet, die Tippfläche mindestens 48', (
      t,
    ) async {
      await pumpApp(t, header(isChef: true));
      final tab = find.byKey(const Key('tab-Bons'));
      expect(t.getSize(tab).height, greaterThanOrEqualTo(48));
      final drawn = find.descendant(
        of: tab,
        matching: find.byType(DecoratedBox),
      );
      expect(t.getSize(drawn.first).height, KassaTokens.drawnControlHeight);
      // Ein Tipp an der oberen Kante der Tippfläche (außerhalb der 44 dp)
      // trifft den Reiter.
      var hits = 0;
      await pumpApp(t, header(isChef: true, onArea: (_) => hits++));
      final rect = t.getRect(find.byKey(const Key('tab-Bons')));
      await t.tapAt(Offset(rect.center.dx, rect.top + 1));
      expect(hits, 1);
    });

    testWidgets('Kopfleiste ist 60 dp hoch', (t) async {
      await pumpApp(t, header(isChef: true));
      expect(
        t.getSize(find.byType(AppHeader)).height,
        KassaTokens.headerHeight,
      );
    });
  });

  group('Hinweis mit Rückgängig', () {
    BuildContext ctx(WidgetTester t) => t.element(find.byType(Scaffold));

    testWidgets('onUndo wird einmal gerufen, der Hinweis verschwindet', (
      t,
    ) async {
      var undone = 0;
      await pumpApp(t, const SizedBox.expand());
      showUndoToast(ctx(t), message: 'Bon geleert', onUndo: () => undone++);
      await t.pump();
      await t.pump(KassaTokens.motionSnack);
      expect(find.text('Bon geleert'), findsOneWidget);
      expect(find.text('Rückgängig'), findsOneWidget);

      await t.tap(find.text('Rückgängig'));
      await t.pump();
      expect(undone, 1);
      expect(find.text('Bon geleert'), findsNothing);
      await t.pump(const Duration(seconds: 8));
      expect(undone, 1);
    });

    testWidgets('verschwindet nach 7 Sekunden von allein', (t) async {
      var undone = 0;
      await pumpApp(t, const SizedBox.expand());
      showUndoToast(ctx(t), message: 'Bon geleert', onUndo: () => undone++);
      await t.pump();
      await t.pump(const Duration(seconds: 6));
      expect(find.text('Bon geleert'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 1100));
      expect(find.text('Bon geleert'), findsNothing);
      expect(undone, 0);
    });

    testWidgets('ein zweiter Hinweis ersetzt den ersten', (t) async {
      await pumpApp(t, const SizedBox.expand());
      showUndoToast(ctx(t), message: 'Erster', onUndo: () {});
      await t.pump();
      showUndoToast(ctx(t), message: 'Zweiter', onUndo: () {});
      await t.pump();
      expect(find.text('Erster'), findsNothing);
      expect(find.text('Zweiter'), findsOneWidget);
      // Die Uhr des ersten läuft nicht weiter und nimmt den zweiten mit.
      await t.pump(const Duration(seconds: 6));
      await t.pump(const Duration(seconds: 2));
      expect(find.text('Zweiter'), findsNothing);
    });

    testWidgets('Knopf ist mindestens 48 dp hoch, Hinweis schwebt unten', (
      t,
    ) async {
      await pumpApp(t, const SizedBox.expand());
      showUndoToast(ctx(t), message: 'Bon geleert', onUndo: () {});
      await t.pump();
      await t.pump(KassaTokens.motionSnack);
      expect(
        t.getSize(find.byKey(const Key('undo'))).height,
        greaterThanOrEqualTo(48),
      );
      final toast = t.getRect(find.byKey(const Key('undo-toast')));
      expect(toast.height, 60);
      expect(toast.center.dx, closeTo(640, 1));
      expect(toast.bottom, closeTo(800 - 20, 1));
    });
  });

  group('Schalter und Segmente', () {
    testWidgets('Schalter meldet den neuen Wert', (t) async {
      final values = <bool>[];
      var value = false;
      await pumpApp(
        t,
        StatefulBuilder(
          builder: (context, setState) {
            return AppToggle(
              value: value,
              label: 'Im Verkauf',
              onChanged: (v) {
                values.add(v);
                setState(() => value = v);
              },
            );
          },
        ),
      );
      expect(find.text('Im Verkauf'), findsOneWidget);
      await t.tap(find.byType(AppToggle));
      await t.pumpAndSettle();
      expect(values, [true]);
      await t.tap(find.byType(AppToggle));
      await t.pumpAndSettle();
      expect(values, [true, false]);
    });

    testWidgets('ausgeschalteter Schalter reagiert nicht, Tippfläche 64 x 48', (
      t,
    ) async {
      await pumpApp(
        t,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            child: AppToggle(value: false, label: 'Pfand', onChanged: null),
          ),
        ),
      );
      await t.tap(find.byType(AppToggle));
      final opacity = t.widget<Opacity>(
        find.descendant(
          of: find.byType(AppToggle),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, KassaTokens.disabledOpacity);
      final target = t.getSize(find.byKey(const Key('toggle-hit')));
      expect(target.width, greaterThanOrEqualTo(64));
      expect(target.height, greaterThanOrEqualTo(48));
    });

    testWidgets('Segmente melden die Wahl, Tippfläche mindestens 48 dp', (
      t,
    ) async {
      final picked = <String>[];
      await pumpApp(
        t,
        Segmented<String>(
          segments: const [('images', 'Mit Bildern'), ('compact', 'Kompakt')],
          selected: 'images',
          onSelected: picked.add,
        ),
      );
      final second = find.byKey(const Key('segment-Kompakt'));
      expect(t.getSize(second).height, greaterThanOrEqualTo(48));
      final drawn = find.descendant(
        of: second,
        matching: find.byType(DecoratedBox),
      );
      expect(t.getSize(drawn.first).height, KassaTokens.drawnControlHeight);
      await t.tap(second);
      expect(picked, ['compact']);
    });
  });

  group('Hauptaktion', () {
    testWidgets('ruft onPressed, Höhe 72 und 80', (t) async {
      var calls = 0;
      await pumpApp(
        t,
        Column(
          children: [
            PrimaryButton(label: 'Bar', onPressed: () => calls++),
            PrimaryButton(
              label: 'Abschließen',
              height: KassaTokens.mainActionHeight,
              onPressed: () {},
            ),
          ],
        ),
      );
      await t.tap(find.text('Bar'));
      expect(calls, 1);
      expect(t.getSize(find.byKey(const Key('primary-Bar'))).height, 72);
      expect(
        t.getSize(find.byKey(const Key('primary-Abschließen'))).height,
        80,
      );
    });

    testWidgets('ausgeschaltet: Deckkraft 0,4 und keine Reaktion', (t) async {
      await pumpApp(t, const PrimaryButton(label: 'Karte', onPressed: null));
      await t.tap(find.text('Karte'));
      final opacity = t.widget<Opacity>(
        find.descendant(
          of: find.byKey(const Key('primary-Karte')),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, KassaTokens.disabledOpacity);
    });

    testWidgets('Zusatzzeile wird gezeigt, leise Variante nutzt fill', (
      t,
    ) async {
      await pumpApp(
        t,
        Column(
          children: [
            PrimaryButton(
              label: 'Bar',
              sublabel: '17,40 € Rückgeld',
              onPressed: () {},
            ),
            PrimaryButton(label: 'Abbrechen', filled: false, onPressed: () {}),
          ],
        ),
      );
      expect(find.text('17,40 € Rückgeld'), findsOneWidget);
      final box = t.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(const Key('primary-Abbrechen')),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((box.decoration as BoxDecoration).color, const Color(0xFFF1F2F4));
    });
  });

  group('Druck-Rückmeldung', () {
    testWidgets('skaliert sofort beim Aufsetzen auf 0,97', (t) async {
      await pumpApp(
        t,
        Pressable(onTap: () {}, child: const SizedBox(width: 100, height: 60)),
      );
      AnimatedScale scale() =>
          t.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale().scale, 1.0);
      final g = await t.startGesture(t.getCenter(find.byType(Pressable)));
      await t.pump();
      expect(scale().scale, KassaTokens.pressScale);
      expect(scale().duration, KassaTokens.motionFast);
      await g.up();
      await t.pump();
      expect(scale().scale, 1.0);
    });

    testWidgets('ohne Animationen entfallen die Übergänge', (t) async {
      await pumpApp(
        t,
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Pressable(
            onTap: () {},
            child: const SizedBox(width: 100, height: 60),
          ),
        ),
      );
      final scale = t.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.duration, Duration.zero);
    });

    testWidgets('abgebrochenes Tippen setzt zurück', (t) async {
      var taps = 0;
      await pumpApp(
        t,
        Center(
          child: Pressable(
            onTap: () => taps++,
            child: const SizedBox(width: 100, height: 60),
          ),
        ),
      );
      final g = await t.startGesture(t.getCenter(find.byType(Pressable)));
      await t.pump();
      await g.moveTo(const Offset(5, 5));
      await g.up();
      await t.pump();
      expect(taps, 0);
      expect(t.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1.0);
    });
    testWidgets('das Kind behält beim Drücken und Loslassen seinen Zustand', (
      t,
    ) async {
      final inits = <int>[];
      await pumpApp(
        t,
        Center(
          child: Pressable(onTap: () {}, child: _Probe(inits)),
        ),
      );
      final g = await t.startGesture(t.getCenter(find.byType(Pressable)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      await g.up();
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(inits, hasLength(1));
    });

    testWidgets('Schalterknopf ist 50 ms nach dem Tippen mitten im Übergang', (
      t,
    ) async {
      var value = false;
      await pumpApp(
        t,
        StatefulBuilder(
          builder: (context, setState) => Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: AppToggle(
                value: value,
                label: 'Pfand',
                onChanged: (v) => setState(() => value = v),
              ),
            ),
          ),
        ),
      );
      final knob = find.descendant(
        of: find.byType(AnimatedPositioned),
        matching: find.byType(Container),
      );
      final start = t.getTopLeft(knob).dx;
      await t.tap(find.byType(AppToggle));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      final mid = t.getTopLeft(knob).dx;
      expect(mid, greaterThan(start + 1));
      await t.pump(const Duration(milliseconds: 300));
      final end = t.getTopLeft(knob).dx;
      expect(end, closeTo(start + 20, 0.5));
      expect(mid, lessThan(end - 1));
    });

    testWidgets('Segment-Regler ist 50 dp hoch, Tipp knapp neben dem Knopf '
        'wählt trotzdem', (t) async {
      final picked = <String>[];
      await pumpApp(
        t,
        Align(
          alignment: Alignment.topLeft,
          child: Segmented<String>(
            segments: const [('a', 'Eins'), ('b', 'Zwei')],
            selected: 'a',
            onSelected: picked.add,
          ),
        ),
      );
      expect(t.getSize(find.byType(Segmented<String>)).height, 50);
      final second = find.byKey(const Key('segment-Zwei'));
      final drawn = find.descendant(
        of: second,
        matching: find.byType(DecoratedBox),
      );
      final rect = t.getRect(drawn.first);
      expect(rect.height, 44);
      await t.tapAt(Offset(rect.center.dx, rect.top - 1));
      await t.tapAt(Offset(rect.center.dx, rect.bottom + 1));
      expect(picked, ['b', 'b']);
    });
  });
}
