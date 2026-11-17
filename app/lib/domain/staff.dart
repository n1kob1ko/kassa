// Mitarbeiter der Kassa. Reines Dart, ohne Flutter.

enum StaffRole { staff, chef }

class Staff {
  const Staff({required this.id, required this.name, required this.role});

  final String id;
  final String name;
  final StaffRole role;

  bool get isChef => role == StaffRole.chef;
}
