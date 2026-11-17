import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/staff.dart';

/// Wer gerade an der Kassa angemeldet ist. Die Anmeldung wird nicht
/// gespeichert: nach einem Neustart fragt die Kassa wieder nach der PIN.
class SessionController extends Notifier<Staff?> {
  @override
  Staff? build() => null;

  /// Meldet die Person mit dieser PIN an. `false` bei unbekannter PIN.
  Future<bool> login(String pin) async {
    final staff = await ref.read(staffRepositoryProvider).findByPin(pin);
    if (staff == null) return false;
    state = staff;
    return true;
  }

  void logout() => state = null;
}

final sessionProvider = NotifierProvider<SessionController, Staff?>(
  SessionController.new,
);
