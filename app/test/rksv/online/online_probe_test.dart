import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/rksv/dep_export.dart';
import 'package:kassa/rksv/online/atrust_client.dart';
import 'package:kassa/rksv/online/atrust_session_keeper.dart';
import 'package:kassa/rksv/online/connection_check.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/rksv_service.dart';
import 'package:kassa/rksv/rksv_state.dart';

import '../../support/fake_atrust.dart';
import '../../support/rksv_rig.dart';
import '../../support/sales.dart' show cart;

bool _isSign(String r) => r.endsWith('/Sign/Hash');

void main() {
  late RksvRig rig;
  late FakeAtrust atrust;

  setUp(() async {
    atrust = FakeAtrust();
    rig = await RksvRig.open(atrust: atrust);
  });
  tearDown(() => rig.close());

  /// "Verbindung prüfen" am Testsystem mit dem Halter der Bons, wie in der
  /// App.
  Future<ConnectionFacts> check() async {
    final result = await ConnectionCheck(
      client: AtrustClient(atrust.client, AtrustSystem.test),
      keeper: rig.keeper!,
      user: atrustTestUser,
      clock: rig.clock,
    ).run(chefTapped: false);
    return result.facts!;
  }

  Future<void> expectNothingStarted() async {
    expect(await rig.count('rksv_chains'), 0);
    expect(await rig.count('rksv_entries'), 0);
    expect(await rig.count('receipts'), 0);
    expect(await rig.count('rksv_certificates'), 1); // nur die der Attrappe
    final state = await rig.stateRow();
    expect((state.mode, state.chain), ('off', null));
  }

  test('enableOnlineProbe: Kette probe/atrustTest mit der Kennung von '
      'A-Trust, Zertifikat mit Ausstellern, Startbeleg von A-Trust signiert '
      'ohne zweite Anmeldung', () async {
    final facts = await check();
    atrust.requests.clear();

    final start = await rig.service.enableOnlineProbe(
      staff: rig.chef,
      facts: facts,
    );

    expect(start.kind, ReceiptKind.start);
    expect(start.rksv!.damaged, isFalse);
    expect(start.rksv!.probe, isTrue);
    expect(atrust.requests, [startsWith('POST /Session/')]);

    final chain = await rig.chainRow(1);
    expect(
      (chain.mode, chain.unit, chain.zdaId, chain.certSerial),
      ('probe', 'atrustTest', 'AT1', '2159b9f6'),
    );
    expect(chain.cashBoxId, matches(RegExp(r'^[A-HJ-NP-Z2-9]{10}$')));
    expect(chain.startedAt, rig.clock.now());
    expect(await rig.secrets.aesKey(1), hasLength(32));
    expect(await rig.secrets.probeKey(1), isNull);

    final cert = await (rig.db.select(
      rig.db.rksvCertificateRows,
    )..where((t) => t.serialHex.equals('2159b9f6'))).getSingle();
    expect(cert.certificate, atrust.certificateDer);
    expect(issuersBase64(cert), [
      for (final i in atrust.issuersDer) base64.encode(i),
    ]);

    final entry = (await rig.entryOf(start.id))!;
    expect(
      (entry.position, entry.damaged, entry.certSerial),
      (1, false, '2159b9f6'),
    );
    final f = await rig.codeFieldsOf(start.id);
    expect(f.sublist(1, 3), ['R1-AT1', chain.cashBoxId]);
    await rig.verifyChain(1);
    expect(await rig.journal.chainIsSound(1), isTrue);

    final state = await rig.rksv.current();
    expect(
      (state.mode, state.unit, state.chain),
      (RksvMode.probe, RksvUnit.atrustTest, 1),
    );
  });

  test('Verkauf, Storno, Nullbeleg, Schlussbeleg laufen über A-Trust; '
      'danach mode off', () async {
    await rig.service.enableOnlineProbe(staff: rig.chef, facts: await check());
    await rig.sell('s1', cart);
    await rig.sellCard('s2', cart);
    await rig.receipts.voidReceipt('s1', staff: rig.chef);
    await rig.service.zeroReceipt(staff: rig.chef);
    rig.clock.value = DateTime(2026, 11, 18, 14);
    final closing = await rig.service.disableProbe(staff: rig.chef);

    expect(await rig.entryKinds(), [
      'start',
      'sale',
      'sale',
      'voided',
      'zero',
      'closing',
    ]);
    expect([
      for (final e in await rig.entries(1)) e.damaged,
    ], everyElement(false));
    // Eine Signatur von "Verbindung prüfen", sechs Bons.
    expect(atrust.requests.where(_isSign), hasLength(7));
    expect(rig.fake.signCalls, 0);
    expect((await rig.entries(1)).last.receiptId, closing.id);
    await rig.verifyChain(1);
    expect(await rig.journal.chainIsSound(1), isTrue);
    expect((await rig.chainRow(1)).endedAt, DateTime(2026, 11, 18, 14));
    final off = await rig.rksv.current();
    expect((off.mode, off.chain), (RksvMode.off, null));
  });

  test('buildDepExport nennt die Aussteller-Zertifikate', () async {
    await rig.service.enableOnlineProbe(staff: rig.chef, facts: await check());
    await rig.sell('s1', cart);
    final text = await buildDepExport(rig.db, chain: 1);
    final groups =
        (jsonDecode(text) as Map<String, dynamic>)['Belege-Gruppe'] as List;
    expect(groups, hasLength(1));
    final group = groups.single as Map<String, dynamic>;
    expect(group['Signaturzertifikat'], base64.encode(atrust.certificateDer));
    expect(group['Zertifizierungsstellen'], [
      for (final i in atrust.issuersDer) base64.encode(i),
    ]);
    expect(group['Belege-kompakt'], hasLength(2));
  });

  test('zweite Online-Probe nach dem Ende: das Zertifikat bleibt eine Zeile, '
      'neue Kette', () async {
    final facts = await check();
    await rig.service.enableOnlineProbe(staff: rig.chef, facts: facts);
    await rig.service.disableProbe(staff: rig.chef);
    await rig.service.enableOnlineProbe(staff: rig.chef, facts: facts);
    expect(await rig.count('rksv_certificates'), 2);
    final second = await rig.chainRow(2);
    expect((second.unit, second.certSerial), ('atrustTest', '2159b9f6'));
    await rig.verifyChain(2);
  });

  test('enableOnlineProbe bei laufender Signatur: StateError, nichts '
      'geschrieben', () async {
    final facts = await check();
    await rig.service.enableProbe(staff: rig.chef);
    await expectLater(
      rig.service.enableOnlineProbe(staff: rig.chef, facts: facts),
      throwsStateError,
    );
    expect(await rig.count('rksv_chains'), 1);
    expect(await rig.count('receipts'), 1);
  });

  test(
    'Fakten vom echten System: StateError (Testsystem heißt Testbon)',
    () async {
      final live = FakeAtrust(validFrom: DateTime.utc(2020, 6, 1));
      final keeper = AtrustSessionKeeper(
        client: AtrustClient(live.client, AtrustSystem.live),
        credentials: () async =>
            const AtrustCredentials(atrustTestUser, atrustTestPassword),
        secrets: rig.secrets,
        clock: rig.clock,
      );
      final result = await ConnectionCheck(
        client: AtrustClient(live.client, AtrustSystem.live),
        keeper: keeper,
        user: atrustTestUser,
        clock: rig.clock,
      ).run(chefTapped: false);
      await expectLater(
        rig.service.enableOnlineProbe(staff: rig.chef, facts: result.facts!),
        throwsStateError,
      );
      await expectNothingStarted();
    },
  );

  test('offline während des Startbelegs: RksvProblem("Kein Internet."), '
      'keine Kette, kein Bon, mode off', () async {
    final facts = await check();
    atrust.offline = true;
    await expectLater(
      rig.service.enableOnlineProbe(staff: rig.chef, facts: facts),
      throwsA(
        isA<RksvProblem>().having(
          (p) => p.message,
          'message',
          'Kein Internet.',
        ),
      ),
    );
    await expectNothingStarted();
  });

  test('Ausfall und Sammelbeleg: offline beim Verkauf ergibt einen Eintrag '
      'mit Vermerk und Grund "Kein Internet."; online und retrySignature '
      'ergibt den Sammelbeleg', () async {
    await rig.service.enableOnlineProbe(staff: rig.chef, facts: await check());
    atrust.offline = true;
    final sold = await rig.sell('s1', cart);
    expect(sold.rksv!.damaged, isTrue);
    final entry = (await rig.entryOf('s1'))!;
    expect((entry.position, entry.damaged), (2, true));
    final state = await rig.stateRow();
    expect(
      (state.outageSince, state.outageReason),
      (rig.clock.now(), 'Kein Internet.'),
    );

    atrust.offline = false;
    expect(await rig.service.retrySignature(staff: rig.chef), isTrue);
    expect(await rig.entryKinds(), ['start', 'sale', 'collective']);
    final after = await rig.stateRow();
    expect((after.outageSince, after.outageReason), (null, null));
    await rig.verifyChain(1);
    expect(await rig.journal.chainIsSound(1), isTrue);
  });

  test('bei rejected schickt retrySignature keine Anfrage und liefert '
      'false', () async {
    await rig.service.enableOnlineProbe(staff: rig.chef, facts: await check());
    // Die Sitzung läuft ab, und A-Trust lehnt die neue Anmeldung ab.
    atrust
      ..expireSessions = true
      ..loginStatus = 401;
    final sold = await rig.sell('s1', cart);
    expect(sold.rksv!.damaged, isTrue);
    expect(rig.keeper!.rejected.value, isTrue);
    expect(
      (await rig.stateRow()).outageReason,
      'A-Trust hat die Zugangsdaten abgelehnt.',
    );

    atrust.requests.clear();
    expect(await rig.service.retrySignature(staff: rig.chef), isFalse);
    expect(atrust.requests, isEmpty);
    expect(await rig.entryKinds(), ['start', 'sale']);
  });
}
