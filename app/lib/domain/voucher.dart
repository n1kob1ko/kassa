// Ein Gutschein und seine Bewegungen (Spec 5.5). Reines Dart. Das Guthaben
// steht nirgends fest, es folgt immer aus den Bewegungen.

/// Art einer Bewegung; [dbName] ist der Text in Datenbank und Abgleich.
enum VoucherMovementKind {
  sale('sale'),
  redeem('redeem'),
  voidSale('void_sale'),
  voidRedeem('void_redeem');

  const VoucherMovementKind(this.dbName);

  final String dbName;

  /// Die Art zu [dbName]; wirft [ArgumentError] bei unbekanntem Text.
  static VoucherMovementKind fromDb(String dbName) {
    for (final k in values) {
      if (k.dbName == dbName) return k;
    }
    throw ArgumentError.value(dbName, 'dbName', 'Unbekannte Art');
  }
}

/// Eine Bewegung am Gutschein: Verkauf und Storno einer Einlösung über 0,
/// Einlösung und Storno des Verkaufs unter 0.
class VoucherMovement {
  const VoucherMovement({
    required this.voucherId,
    required this.receiptId,
    required this.kind,
    required this.amountCents,
    required this.createdAt,
  });

  final String voucherId;

  /// Der Bon, zu dem die Bewegung gehört.
  final String receiptId;
  final VoucherMovementKind kind;
  final int amountCents;
  final DateTime createdAt;
}

enum VoucherState { active, empty, voided, overdrawn }

class Voucher {
  const Voucher({
    required this.id,
    required this.code,
    required this.valueCents,
    required this.createdAt,
    required this.isTest,
    this.soldReceiptId,
    required this.movements,
  });

  final String id;

  /// 8 Ziffern, nur zum Tippen; die Kennung ist [id].
  final String code;
  final int valueCents;
  final DateTime createdAt;

  /// Ein Übungs-Gutschein von einem Übungs-Bon.
  final bool isTest;

  /// Der Bon, auf dem der Gutschein verkauft wurde, soweit bekannt.
  final String? soldReceiptId;
  final List<VoucherMovement> movements;

  /// Summe aller Bewegungen.
  int get balanceCents => movements.fold(0, (sum, m) => sum + m.amountCents);

  /// Überzogen bei Guthaben unter 0; storniert, wenn der Verkauf storniert
  /// ist und das Guthaben 0 ist; leer bei Guthaben 0; sonst aktiv.
  VoucherState get state {
    final balance = balanceCents;
    if (balance < 0) return VoucherState.overdrawn;
    if (balance == 0) {
      return movements.any((m) => m.kind == VoucherMovementKind.voidSale)
          ? VoucherState.voided
          : VoucherState.empty;
    }
    return VoucherState.active;
  }

  /// Wahr, solange es nur die Bewegung des Verkaufs gibt.
  bool get untouched =>
      movements.length == 1 &&
      movements.single.kind == VoucherMovementKind.sale;

  /// Ob sich der Verkauf dieses Gutscheins stornieren lässt: solange er sein
  /// Guthaben vom Verkauf hat (jede Einlösung ist selbst storniert) und der
  /// Verkauf noch nicht storniert ist.
  bool get mayVoidSale =>
      balanceCents == valueCents &&
      !movements.any((m) => m.kind == VoucherMovementKind.voidSale);
}

/// Das Guthaben, das [voucher] auf einem Bon hat, der gerade entsteht: ein
/// Übungs-Gutschein gilt nur auf einem Übungs-Bon ([onTestReceipt]), ein
/// echter nur auf einem echten; sonst und ohne Gutschein 0. Die eine Stelle
/// dieser Regel für das Abschließen, die Prüfung vor dem Terminal und das
/// Neu-Lesen der gewählten Gutscheine.
int usableVoucherBalance(Voucher? voucher, {required bool onTestReceipt}) {
  if (voucher == null || voucher.isTest != onTestReceipt) return 0;
  return voucher.balanceCents;
}

/// Warum sich ein gefundener Gutschein nicht einlösen lässt.
enum VoucherRedeemProblem {
  /// Er liegt schon am Bon.
  alreadyOnReceipt,

  /// Sein Verkauf ist storniert.
  voided,

  /// Ein Übungs-Gutschein im echten Betrieb.
  testOnly,

  /// Ein echter Gutschein im Übungsmodus.
  liveOnly,

  /// Kein Guthaben (0 oder darunter).
  empty,
}

/// Ob sich [voucher] auf einem Bon einlösen lässt, der gerade entsteht
/// ([onTestReceipt]: ein Übungs-Bon), mit den schon gewählten Gutscheinen
/// [chosenIds]; `null`, wenn ja. Sonst der erste Grund in dieser
/// Reihenfolge: schon am Bon, storniert, Übung und echt gemischt, kein
/// Guthaben.
VoucherRedeemProblem? voucherRedeemProblem(
  Voucher voucher, {
  required bool onTestReceipt,
  Iterable<String> chosenIds = const [],
}) {
  if (chosenIds.contains(voucher.id)) {
    return VoucherRedeemProblem.alreadyOnReceipt;
  }
  if (voucher.state == VoucherState.voided) return VoucherRedeemProblem.voided;
  if (voucher.isTest && !onTestReceipt) return VoucherRedeemProblem.testOnly;
  if (!voucher.isTest && onTestReceipt) return VoucherRedeemProblem.liveOnly;
  if (voucher.balanceCents <= 0) return VoucherRedeemProblem.empty;
  return null;
}

final _voucherCode = RegExp(r'^[0-9]{8}$');

/// Ob [code] ein Gutschein-Code ist: genau 8 Ziffern, ohne Leerzeichen.
bool isVoucherCode(String code) => _voucherCode.hasMatch(code);

/// '12345678' wird '1234 5678'. Was kein Gutschein-Code ist, bleibt, wie es
/// ist.
String formatVoucherCode(String code) =>
    isVoucherCode(code) ? '${code.substring(0, 4)} ${code.substring(4)}' : code;
