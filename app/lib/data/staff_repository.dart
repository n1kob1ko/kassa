// Mitarbeiter mit PIN. Die PIN wird nie im Klartext gespeichert.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../domain/staff.dart';
import 'database.dart';

class PinTakenException implements Exception {
  const PinTakenException();

  @override
  String toString() => 'PinTakenException: Diese PIN ist schon vergeben.';
}

class InvalidPinException implements Exception {
  const InvalidPinException();

  @override
  String toString() => 'InvalidPinException: Die PIN muss genau vier Ziffern haben.';
}

class StaffRepository {
  StaffRepository(this._db);

  final KassaDatabase _db;

  Future<Staff> create({
    required String name,
    required String pin,
    required StaffRole role,
  }) async {
    if (!_pinPattern.hasMatch(pin)) throw const InvalidPinException();
    return _db.transaction(() async {
      if (await _rowFor(pin) != null) throw const PinTakenException();
      final salt = _newSalt();
      final id = const Uuid().v4();
      await _db.into(_db.staffRows).insert(StaffRowsCompanion.insert(
            id: id,
            name: name,
            role: role.name,
            pinSalt: salt,
            pinHash: _hash(salt, pin),
          ));
      return Staff(id: id, name: name, role: role);
    });
  }

  Future<Staff?> findByPin(String pin) async {
    final row = await _rowFor(pin);
    return row == null ? null : _toStaff(row);
  }

  Future<List<Staff>> all() async {
    final rows = await _db.select(_db.staffRows).get();
    return [for (final r in rows) _toStaff(r)];
  }

  Future<StaffRow?> _rowFor(String pin) async {
    for (final r in await _db.select(_db.staffRows).get()) {
      if (r.pinHash == _hash(r.pinSalt, pin)) return r;
    }
    return null;
  }

  Staff _toStaff(StaffRow r) =>
      Staff(id: r.id, name: r.name, role: StaffRole.values.byName(r.role));
}

final _pinPattern = RegExp(r'^[0-9]{4}$');

String _newSalt() {
  final random = Random.secure();
  return base64Encode([for (var i = 0; i < 16; i++) random.nextInt(256)]);
}

String _hash(String salt, String pin) =>
    sha256.convert(utf8.encode('$salt$pin')).toString();
