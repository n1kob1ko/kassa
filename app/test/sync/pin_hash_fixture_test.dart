import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/staff_repository.dart';

void main() {
  test('PIN vom Server meldet am Tablet an', () async {
    final fixture =
        jsonDecode(File('../shared/fixtures/pin_hash.json').readAsStringSync())
            as Map<String, dynamic>;
    final db = KassaDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.staffRows)
        .insert(
          StaffRowsCompanion.insert(
            id: 'server-chefin',
            name: 'Chefin',
            role: 'chef',
            pinSalt: fixture['salt'] as String,
            pinHash: fixture['hash'] as String,
          ),
        );
    final staff = StaffRepository(db);
    final found = await staff.findByPin(fixture['pin'] as String);
    expect(found?.id, 'server-chefin');
    expect(await staff.findByPin('1235'), isNull);
  });
}
