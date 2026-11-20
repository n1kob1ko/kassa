// Stand der Signatur (RKSV): Zustand, laufende Kette, Umsatzzähler, Ausfall,
// offene Aufgaben und ein Hinweis. Ohne Datenbank und ohne Oberfläche.

import 'dart:convert';

/// `off`: Nicht eingerichtet (oder außer Betrieb, siehe
/// [RksvState.decommissioned]), `probe`: Probe-Signatur, `live`: in Betrieb
/// am echten System von A-Trust.
enum RksvMode { off, probe, live }

/// Wer eine Kette signiert (`rksv_chains.unit`): `probe` die Probe-Signatur
/// auf dem Tablet, `atrustTest` das Testsystem von A-Trust (immer im Modus
/// probe), `atrust` das echte System von A-Trust.
enum RksvUnit { probe, atrustTest, atrust }

enum RksvTaskKind {
  checkStart,
  checkYear,
  reportOutage,
  reportOutageEnd,
  backupProtocol,
  registerFinanzOnline,
  reportDecommission,
}

/// Eine offene Aufgabe. Sie sperrt nichts und verschwindet mit "Erledigt".
final class RksvTask {
  const RksvTask({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.detail = '',
  });

  final String id;
  final RksvTaskKind kind;
  final DateTime createdAt;

  /// Was der Satz der Aufgabe einsetzt: das Jahr bei [RksvTaskKind.checkYear],
  /// Beginn oder Ende bei den Meldungen eines Ausfalls (`18.11.2026 13:05`),
  /// die Frist bei [RksvTaskKind.registerFinanzOnline] und
  /// [RksvTaskKind.reportDecommission] (`25.11.2026`).
  final String detail;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'createdAt': createdAt.toIso8601String(),
    'detail': detail,
  };

  /// Wirft bei einem fehlenden Feld oder einer unbekannten Art.
  static RksvTask fromJson(Map<String, Object?> j) => RksvTask(
    id: j['id']! as String,
    kind: RksvTaskKind.values.byName(j['kind']! as String),
    createdAt: DateTime.parse(j['createdAt']! as String),
    detail: (j['detail'] as String?) ?? '',
  );
}

/// Die Aufgaben aus `rksv_state.tasks`. Kaputtes JSON ergibt eine leere
/// Liste: Eine verlorene Aufgabe ist besser als eine Kassa, die den Stand
/// nicht lesen kann.
List<RksvTask> decodeRksvTasks(String json) {
  try {
    final list = jsonDecode(json) as List<Object?>;
    return [
      for (final e in list) RksvTask.fromJson(e! as Map<String, Object?>),
    ];
  } on Object {
    return const [];
  }
}

/// Die Aufgaben für `rksv_state.tasks`.
String encodeRksvTasks(List<RksvTask> tasks) =>
    jsonEncode([for (final t in tasks) t.toJson()]);

/// Ids mit der Nummer ihrer Kette (so legen Journal und Service sie an).
final _chainInId = RegExp(
  r'^(?:check-start|report-outage-end|report-outage|register-finanzonline|'
  r'report-decommission|backup-decommission)-(\d+)(?:-\d+)?$',
);

/// Die Aufgaben, die bleiben, wenn die Probe-Kette [chain] (begonnen um
/// [startedAt]) endet: Ihre eigenen gehen, die einer früheren Kette (etwa
/// der außer Betrieb genommenen `live`-Kette) bleiben. Eine Id mit
/// Kettennummer gehört zu dieser Kette; eine ohne (Jahresbeleg, Protokoll
/// sichern) zur Probe, wenn sie nach deren Beginn entstand.
List<RksvTask> tasksAfterProbe(
  List<RksvTask> tasks, {
  required int chain,
  required DateTime startedAt,
}) {
  bool ofProbe(RksvTask t) {
    final m = _chainInId.firstMatch(t.id);
    return m != null
        ? int.parse(m.group(1)!) == chain
        : t.createdAt.isAfter(startedAt);
  }

  return [
    for (final t in tasks)
      if (!ofProbe(t)) t,
  ];
}

/// Der Satz der Aufgabe am Bildschirm.
String rksvTaskText(RksvTask t) => switch (t.kind) {
  RksvTaskKind.checkStart => 'Startbeleg mit der App "BMF Belegcheck" prüfen.',
  RksvTaskKind.checkYear =>
    'Jahresbeleg ${t.detail} mit der App "BMF Belegcheck" prüfen, '
        'bis 15. Februar.',
  RksvTaskKind.reportOutage =>
    'Ausfall der Signatur bei FinanzOnline melden. Beginn: ${t.detail}.',
  RksvTaskKind.reportOutageEnd =>
    'Ende des Ausfalls bei FinanzOnline melden. Ende: ${t.detail}.',
  RksvTaskKind.backupProtocol =>
    'Protokoll sichern: "Protokoll ausgeben" und die Datei aufheben.',
  RksvTaskKind.registerFinanzOnline =>
    'Signatureinheit und Kassa bei FinanzOnline anmelden, bis ${t.detail}.',
  RksvTaskKind.reportDecommission =>
    'Außerbetriebnahme bei FinanzOnline melden, bis ${t.detail}. '
        'Grund: 6, planmäßige Außerbetriebnahme.',
};

final class RksvState {
  const RksvState({
    this.mode = RksvMode.off,
    this.chain,
    this.cashBoxId,
    this.unit,
    this.counterCents = 0,
    this.outageSince,
    this.outageReason,
    this.tasks = const [],
    this.notice,
    this.decommissioned = false,
  });

  final RksvMode mode;

  /// Die laufende Kette, `null` ohne.
  final int? chain;

  /// Kassen-Kennung der laufenden Kette, `null` ohne Kette.
  final String? cashBoxId;

  /// Einheit der laufenden Kette, `null` ohne Kette (und bei einem Wert,
  /// den diese Version nicht kennt).
  final RksvUnit? unit;
  final int counterCents;
  final DateTime? outageSince;
  final String? outageReason;
  final List<RksvTask> tasks;

  /// Ein Satz für den Chef, etwa warum die Probe-Signatur beendet wurde.
  final String? notice;

  /// "Außer Betrieb" (Q8): [mode] ist off, und die Kette mit der höchsten
  /// Nummer ist eine beendete Kette `live`.
  final bool decommissioned;

  bool get outage => outageSince != null;
}
