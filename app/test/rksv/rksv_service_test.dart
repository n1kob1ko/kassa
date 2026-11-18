import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/rksv/card/certificate.dart';
import 'package:kassa/rksv/core/rksv_code.dart';
import 'package:kassa/rksv/rksv_journal.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/rksv_service.dart';
import 'package:kassa/rksv/rksv_state.dart';

import '../support/fake_signature_unit.dart';
import '../support/rksv_rig.dart';
import '../support/sales.dart' show cart;

/// Ein Speicher, der Schreiben annimmt, aber nichts behält.
class _ForgetfulSecrets extends MemoryRksvSecrets {
  @override
  Future<void> writeAesKey(int chain, Uint8List key) async {}
}

void main() {
  late RksvRig rig;

  setUp(() async => rig = await RksvRig.open());
  tearDown(() => rig.close());

  test('enableProbe: Startbeleg mit Betrag 0, Position 1, Kettenwert aus der '
      'Kassen-Kennung, Zähler 0; Zustand probe', () async {
    final start = await rig.service.enableProbe(staff: rig.chef);

    expect(start.kind, ReceiptKind.start);
    expect(start.number, 1);
    expect((start.goodsCents, start.depositCents, start.totalCents), (0, 0, 0));
    expect(start.lines, isEmpty);
    expect(start.payment, isNull);
    expect(start.businessDayId, isNull);
    expect((start.staffId, start.staffName), (rig.chef.id, 'Chef'));
    expect(await rig.count('business_days'), 0);

    final chain = await rig.chainRow(1);
    expect(chain.mode, 'probe');
    expect(chain.zdaId, 'AT100');
    expect(chain.cashBoxId, matches(RegExp(r'^[A-HJ-NP-Z2-9]{10}$')));
    expect(chain.startedAt, rig.clock.now());
    expect(chain.endedAt, isNull);
    final cert = await (rig.db.select(
      rig.db.rksvCertificateRows,
    )..where((t) => t.serialHex.equals(chain.certSerial))).getSingle();
    final parsed = CardCertificate.parse(cert.certificate);
    expect(parsed.subject, 'Kassa Probe-Signatur ${chain.cashBoxId}');
    expect(parsed.serial.toRadixString(16), chain.certSerial);

    final aesKey = (await rig.secrets.aesKey(1))!;
    expect(aesKey, hasLength(32));
    expect(await rig.secrets.probeKey(1), hasLength(32));

    final entry = (await rig.entryOf(start.id))!;
    expect((entry.chain, entry.position, entry.damaged), (1, 1, false));
    final f = await rig.codeFieldsOf(start.id);
    expect(f.sublist(1, 4), ['R1-AT100', chain.cashBoxId, '1']);
    expect(f.sublist(5, 10), ['0,00', '0,00', '0,00', '0,00', '0,00']);
    expect(f[12], chainValue(chain.cashBoxId));
    expect(
      decryptCounter(
        aesKey: aesKey,
        cashBoxId: chain.cashBoxId,
        receiptId: '1',
        field: f[10],
      ),
      0,
    );
    await rig.verifyChain(1);

    final state = await rig.rksv.current();
    expect(state.mode, RksvMode.probe);
    expect(state.chain, 1);
    expect(state.cashBoxId, chain.cashBoxId);
    expect(state.counterCents, 0);
    expect(state.outage, isFalse);
    expect(start.rksv!.probe, isTrue);
    expect(start.rksv!.cashBoxId, chain.cashBoxId);
  });

  test('enableProbe mit der Probe-Signatur der App: Kette mit ihrem '
      'Zertifikat, Verkauf und Storno signiert', () async {
    final app = await RksvRig.open(probeUnit: true);
    addTearDown(app.close);
    await app.service.enableProbe(staff: app.chef);
    await app.sell('s1', cart);
    await app.receipts.voidReceipt('s1', staff: app.chef);
    final chain = await app.chainRow(1);
    expect(
      {for (final e in await app.entries(1)) e.certSerial},
      {chain.certSerial},
    );
    expect(app.fake.signCalls, 0);
    await app.verifyChain(1);
    expect(await app.journal.chainIsSound(1), isTrue);
  });

  test('probeSignatureUnitOf: ohne Schlüssel ein unerwarteter Fehler; mit '
      'kaputtem Schlüssel ein Ausfall, die Probe läuft weiter', () async {
    final app = await RksvRig.open(probeUnit: true);
    addTearDown(app.close);
    await app.service.enableProbe(staff: app.chef);
    await app.secrets.writeProbeKey(1, Uint8List(0));
    final unitOf = probeSignatureUnitOf(app.db, MemoryRksvSecrets());
    await expectLater(unitOf(1), throwsStateError);
    // Mit einem kaputten Schlüssel meldet die Probe-Signatur einen Fehler:
    // das ist ein Ausfall, kein Ende der Probe.
    final r = await app.sell('s1', cart);
    expect(r.rksv!.damaged, isTrue);
    expect((await app.stateRow()).mode, 'probe');
    expect(
      (await app.stateRow()).outageReason,
      'Die Signatur hat einen Fehler gemeldet.',
    );
  });

  test('disableProbe: Schlussbeleg als letzter Eintrag, ended_at gesetzt, '
      'mode off; danach enableProbe: neue Kette mit neuer Kassen-Kennung, '
      'Position 1', () async {
    await rig.service.enableProbe(staff: rig.chef);
    await rig.sell('s1', cart);
    rig.clock.value = DateTime(2026, 11, 18, 14);
    final closing = await rig.service.disableProbe(staff: rig.chef);

    expect(closing.kind, ReceiptKind.closing);
    expect(closing.number, 3);
    expect(closing.totalCents, 0);
    expect(closing.payment, isNull);
    expect(closing.businessDayId, isNull);
    expect(closing.staffName, 'Chef');
    final first = await rig.entries(1);
    expect(first.last.receiptId, closing.id);
    expect(first.last.position, 3);
    await rig.verifyChain(1);
    expect((await rig.chainRow(1)).endedAt, DateTime(2026, 11, 18, 14));
    final off = await rig.rksv.current();
    expect(off.mode, RksvMode.off);
    expect(off.chain, isNull);
    expect(off.cashBoxId, isNull);

    // Ohne Probe: Verkauf ohne Eintrag.
    final plain = await rig.sell('s2', cart);
    expect(plain.rksv, isNull);

    final start = await rig.service.enableProbe(staff: rig.chef);
    expect(start.number, 5);
    final second = await rig.chainRow(2);
    expect(second.cashBoxId, isNot((await rig.chainRow(1)).cashBoxId));
    expect(second.certSerial, isNot((await rig.chainRow(1)).certSerial));
    expect((await rig.entryOf(start.id))!.position, 1);
    expect((await rig.entryOf(start.id))!.chain, 2);
    expect((await rig.stateRow()).counterCents, 0);
    await rig.sell('s3', cart);
    await rig.verifyChain(2);
    expect(await rig.secrets.aesKey(1), isNot(await rig.secrets.aesKey(2)));
  });

  test('enableProbe mit Speicher, der nicht schreibt: RksvProblem, Zustand '
      'unverändert off, keine Kette', () async {
    final db = rig.db;
    final service = RksvService(
      db,
      _ForgetfulSecrets(),
      rig.receipts,
      rig.clock,
    );
    await expectLater(
      service.enableProbe(staff: rig.chef),
      throwsA(
        isA<RksvProblem>().having(
          (p) => p.message,
          'message',
          'Das Tablet konnte den Schlüssel nicht sicher speichern.',
        ),
      ),
    );
    expect(await rig.count('rksv_chains'), 0);
    expect(await rig.count('receipts'), 0);
    expect(await rig.count('rksv_entries'), 0);
    final state = await rig.stateRow();
    expect((state.mode, state.chain, state.counterCents), ('off', null, 0));
  });

  test('enableProbe mit Speicher, der nicht lesbar ist: RksvProblem, nichts '
      'geschrieben', () async {
    rig.secrets.failReads = true;
    await expectLater(
      rig.service.enableProbe(staff: rig.chef),
      throwsA(
        isA<RksvProblem>().having(
          (p) => p.message,
          'message',
          'Das Tablet konnte den Schlüssel nicht sicher speichern.',
        ),
      ),
    );
    expect(await rig.count('rksv_chains'), 0);
    expect(await rig.count('receipts'), 0);
    expect((await rig.stateRow()).mode, 'off');
  });

  test('enableProbe, wenn die Signatur scheitert: RksvProblem mit ihrem '
      'Grund, nichts geschrieben', () async {
    rig.fake.mode = FakeMode.error;
    await expectLater(
      rig.service.enableProbe(staff: rig.chef),
      throwsA(
        isA<RksvProblem>().having(
          (p) => p.message,
          'message',
          'Die Attrappe signiert nicht.',
        ),
      ),
    );
    expect(await rig.count('rksv_chains'), 0);
    expect(await rig.count('rksv_certificates'), 1); // nur die der Attrappe
    expect(await rig.count('receipts'), 0);
    final state = await rig.stateRow();
    expect((state.mode, state.chain, state.notice), ('off', null, null));
  });

  test('enableProbe zweimal zugleich: genau ein Startbeleg', () async {
    final results = await Future.wait([
      rig.service.enableProbe(staff: rig.chef).then<Object>((r) => r),
      rig.service
          .enableProbe(staff: rig.chef)
          .then<Object>((r) => r, onError: (Object e) => e),
    ]);
    expect(results.whereType<Receipt>(), hasLength(1));
    expect(results.whereType<StateError>(), hasLength(1));
    expect(await rig.count('rksv_chains'), 1);
    expect(await rig.count('rksv_entries'), 1);
    await rig.verifyChain(1);
  });

  test('disableProbe ohne Probe: StateError, nichts geschrieben', () async {
    await expectLater(
      rig.service.disableProbe(staff: rig.chef),
      throwsStateError,
    );
    expect(await rig.count('receipts'), 0);
  });

  test('createSpecial: nur Sonderbelege, nur mit Signatur', () async {
    await expectLater(
      rig.receipts.createSpecial(ReceiptKind.zero, staff: rig.chef),
      throwsStateError,
    );
    await rig.service.enableProbe(staff: rig.chef);
    await expectLater(
      rig.receipts.createSpecial(ReceiptKind.sale, staff: rig.chef),
      throwsArgumentError,
    );
    final zero = await rig.receipts.createSpecial(
      ReceiptKind.zero,
      staff: rig.anna,
    );
    expect(
      (zero.kind, zero.number, zero.staffName),
      (ReceiptKind.zero, 2, 'Anna'),
    );
    expect(zero.rksv, isNotNull);
    await expectLater(
      rig.receipts.voidReceipt(zero.id, staff: rig.chef),
      throwsA(isA<CannotVoidSpecialException>()),
    );
    await rig.verifyChain(1);
  });
}
