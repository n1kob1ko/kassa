import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/ui/keypad.dart';
import 'package:material_ui/material_ui.dart';

import 'pump.dart';

void main() {
  testWidgets('memoryOverrides mit Beispieldaten: 14 Artikel, Chef und Anna', (
    t,
  ) async {
    final overrides = await memoryOverrides();
    late WidgetRef captured;
    await pumpApp(
      t,
      Consumer(
        builder: (context, ref, _) {
          captured = ref;
          return const SizedBox();
        },
      ),
      overrides: overrides,
    );
    final catalog = await captured.read(catalogRepositoryProvider).current();
    expect(catalog!.items, hasLength(14));
    final staff = captured.read(staffRepositoryProvider);
    final chef = await staff.findByPin('4711');
    expect(chef?.name, 'Chef');
    expect(chef?.role, StaffRole.chef);
    expect((await staff.findByPin('1234'))?.name, 'Anna');
    expect(captured.read(clockProvider).now(), DateTime(2026, 11, 17, 11));
  });

  testWidgets('Datenbankaufruf eines Widgets wird von pump vorangebracht', (
    t,
  ) async {
    final count = FutureProvider(
      (ref) async =>
          (await ref.watch(catalogRepositoryProvider).current())!.items.length,
    );
    await pumpApp(
      t,
      Consumer(
        builder: (context, ref, _) {
          return Text(
            ref
                .watch(count)
                .maybeWhen(data: (n) => '$n Artikel', orElse: () => 'lädt'),
          );
        },
      ),
      overrides: await memoryOverrides(),
    );
    expect(find.text('lädt'), findsOneWidget);
    await t.pump();
    await t.pump();
    expect(find.text('14 Artikel'), findsOneWidget);
  });

  testWidgets('memoryOverrides ohne Beispieldaten bleibt leer', (t) async {
    final overrides = await memoryOverrides(seeded: false);
    late WidgetRef captured;
    await pumpApp(
      t,
      Consumer(
        builder: (context, ref, _) {
          captured = ref;
          return const SizedBox();
        },
      ),
      overrides: overrides,
    );
    expect(await captured.read(catalogRepositoryProvider).current(), isNull);
    expect(await captured.read(staffRepositoryProvider).all(), isEmpty);
  });

  testWidgets('memoryOverrides nimmt eine eigene Uhr', (t) async {
    final clock = FixedClock(DateTime(2027, 1, 2, 3));
    late WidgetRef captured;
    await pumpApp(
      t,
      Consumer(
        builder: (context, ref, _) {
          captured = ref;
          return const SizedBox();
        },
      ),
      overrides: await memoryOverrides(seeded: false, clock: clock),
    );
    expect(captured.read(clockProvider).now(), DateTime(2027, 1, 2, 3));
  });

  testWidgets('tapKeys und typePin tippen das Zahlenfeld', (t) async {
    final keys = <String>[];
    await pumpApp(t, Keypad(onKey: keys.add));
    await tapKeys(t, '1 2 , 5 0 back');
    expect(keys, ['1', '2', ',', '5', '0', 'back']);
    keys.clear();
    await typePin(t, '4711');
    expect(keys, ['4', '7', '1', '1']);
  });

  testWidgets('textOf liest den Text eines Widgets und des ersten darunter', (
    t,
  ) async {
    await pumpApp(
      t,
      const Column(
        children: [
          Text('Hallo', key: Key('direct')),
          SizedBox(key: Key('box'), child: Text('Welt')),
        ],
      ),
    );
    expect(textOf(t, const Key('direct')), 'Hallo');
    expect(textOf(t, const Key('box')), 'Welt');
  });

  testWidgets('pumpApp stellt Größe, Pixelverhältnis und Textskala ein', (
    t,
  ) async {
    await pumpApp(
      t,
      const SizedBox.expand(key: Key('x')),
      size: const Size(960, 600),
      textScale: 1.3,
    );
    expect(t.getSize(find.byKey(const Key('x'))), const Size(960, 600));
    final media = MediaQuery.of(t.element(find.byKey(const Key('x'))));
    expect(media.devicePixelRatio, 1.0);
    expect(media.textScaler.scale(10), closeTo(13, 0.001));
  });
}
