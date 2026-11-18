// Die Schnittstelle zum Kartenterminal. Der Kern kennt nur sie, nie den
// Anbieter dahinter.

enum CardTerminalState { notConfigured, loggedOut, ready }

class CardTerminalStatus {
  const CardTerminalStatus(this.state, {this.merchantName});

  final CardTerminalState state;

  /// Der Name des angemeldeten Kontos, falls bekannt.
  final String? merchantName;

  @override
  bool operator ==(Object other) =>
      other is CardTerminalStatus &&
      other.state == state &&
      other.merchantName == merchantName;

  @override
  int get hashCode => Object.hash(state, merchantName);
}

enum CardFailure {
  declined,
  cancelled,
  noInternet,
  notLoggedIn,
  noReader,
  permission,
  other,
}

sealed class CardPaymentResult {
  const CardPaymentResult();
}

/// Das Terminal hat die Zahlung angenommen.
class CardPaid extends CardPaymentResult {
  const CardPaid({required this.txCode, this.cardScheme, this.cardLast4});

  final String txCode;
  final String? cardScheme;
  final String? cardLast4;
}

/// Die Zahlung ist sicher nicht zustande gekommen.
class CardFailed extends CardPaymentResult {
  const CardFailed(this.failure, {this.detail});

  final CardFailure failure;
  final String? detail;

  /// Text für die Bedienung.
  String get message => switch (failure) {
    CardFailure.declined => 'Die Karte wurde abgelehnt.',
    CardFailure.cancelled => 'Kartenzahlung abgebrochen.',
    CardFailure.noInternet => 'Kein Internet. Kartenzahlung geht gerade nicht.',
    CardFailure.notLoggedIn =>
      'SumUp ist nicht angemeldet. Bitte in den Einstellungen anmelden.',
    CardFailure.noReader =>
      'Kein Kartenleser verbunden. Bitte in den Einstellungen verbinden.',
    CardFailure.permission =>
      'Kassa braucht die Erlaubnis für Bluetooth und Standort.',
    CardFailure.other =>
      detail == null || detail!.isEmpty
          ? 'Die Kartenzahlung hat nicht geklappt.'
          : 'Die Kartenzahlung hat nicht geklappt. ($detail)',
  };
}

/// Ob bezahlt wurde, ist nicht sicher (Verbindung weg, App beendet).
class CardUnknown extends CardPaymentResult {
  const CardUnknown();
}

abstract interface class CardTerminal {
  /// Name des Anbieters, wird beim Bon gespeichert, z. B. `sumup`.
  String get providerName;

  /// Kleinster Betrag in Cent, den das Terminal annimmt.
  int get minimumCents;

  Future<CardTerminalStatus> status();
  Future<CardTerminalStatus> login();
  Future<void> logout();
  Future<void> openReaderSettings();

  /// Bereitet eine Zahlung vor (Leser wecken); darf nie werfen.
  Future<void> prepare();

  /// [paymentId] ist die Id des Bons, [title] steht beim Anbieter.
  Future<CardPaymentResult> pay({
    required String paymentId,
    required int amountCents,
    required String title,
  });
}
