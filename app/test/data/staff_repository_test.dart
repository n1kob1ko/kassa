import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/staff_repository.dart';
import 'package:kassa/domain/staff.dart';

void main() {
  late KassaDatabase db;
  late StaffRepository staff;

  setUp(() {
    db = KassaDatabase(NativeDatabase.memory());
    staff = StaffRepository(db);
  });
  tearDown(() => db.close());

  test('PIN', () async {
    final chef = await staff.create(name: 'Chef', pin: '4711', role: StaffRole.chef);
    expect((await staff.findByPin('4711'))!.id, chef.id);
    expect(await staff.findByPin('0000'), isNull);
    await expectLater(staff.create(name: 'Anna', pin: '4711', role: StaffRole.staff),
        throwsA(isA<PinTakenException>()));
    await expectLater(staff.create(name: 'Ben', pin: '12a', role: StaffRole.staff),
        throwsA(isA<InvalidPinException>()));
  });

  test('PIN muss genau vier Ziffern haben', () async {
    for (final pin in ['', '123', '12345', '12 4', '١٢٣٤']) {
      await expectLater(staff.create(name: 'X', pin: pin, role: StaffRole.staff),
          throwsA(isA<InvalidPinException>()),
          reason: 'PIN "$pin"');
    }
  });

  test('mehrere Mitarbeiter mit verschiedenen PINs, alle werden gefunden', () async {
    final a = await staff.create(name: 'Anna', pin: '1111', role: StaffRole.staff);
    final b = await staff.create(name: 'Ben', pin: '2222', role: StaffRole.chef);
    expect(a.id, isNot(b.id));
    expect((await staff.findByPin('1111'))!.name, 'Anna');
    final found = (await staff.findByPin('2222'))!;
    expect((found.name, found.role), ('Ben', StaffRole.chef));
    expect((await staff.all()).map((s) => s.name), unorderedEquals(['Anna', 'Ben']));
    await expectLater(staff.create(name: 'Cy', pin: '2222', role: StaffRole.staff),
        throwsA(isA<PinTakenException>()));
  });

  test('die PIN steht nicht im Klartext in der Datenbank', () async {
    await staff.create(name: 'Chef', pin: '4711', role: StaffRole.chef);
    final rows = await db.customSelect('SELECT * FROM staff').get();
    expect(rows.single.data.values.join('|'), isNot(contains('4711')));
  });

  test('jeder Mitarbeiter hat sein eigenes Salz', () async {
    await staff.create(name: 'A', pin: '1111', role: StaffRole.staff);
    await staff.create(name: 'B', pin: '2222', role: StaffRole.staff);
    final rows = await db.customSelect('SELECT pin_salt FROM staff').get();
    expect(rows.map((r) => r.read<String>('pin_salt')).toSet(), hasLength(2));
  });
}
