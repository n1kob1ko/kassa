// Wer einen Schalter der Kassa benutzen darf (Rabatt, freier Betrag). Reines
// Dart, ohne Flutter.

import 'staff.dart';

enum FeatureAccess {
  off,
  all,
  chefOnly;

  /// off: nie. all: jede angemeldete Person. chefOnly: nur Chef. Ohne
  /// Anmeldung nie.
  bool allows(Staff? staff) {
    if (staff == null) return false;
    return switch (this) {
      FeatureAccess.off => false,
      FeatureAccess.all => true,
      FeatureAccess.chefOnly => staff.isChef,
    };
  }
}
