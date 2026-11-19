import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/rksv/online/online_providers.dart';
import 'package:kassa/rksv/online/online_signature_unit.dart';
import 'package:kassa/rksv/probe_signature_unit.dart';
import 'package:kassa/rksv/rksv_journal.dart';
import 'package:kassa/rksv/rksv_providers.dart';
import 'package:kassa/rksv/signature_unit.dart';

import '../../support/fake_atrust.dart';
import '../../support/rksv_rig.dart';
import '../../support/sales.dart' show cart;

Future<Never> _noOnline(RksvChainRow chain, RksvCertificateRow cert) =>
    fail('online darf hier nicht gerufen werden');

void main() {
  late RksvRig rig;
  late FakeAtrust atrust;

  setUp(() async {
    rig = await RksvRig.open();
    atrust = FakeAtrust();
  });
  tearDown(() => rig.close());

  Future<void> setUnit(String unit) =>
      rig.db.customStatement("UPDATE rksv_chains SET unit = '$unit'");

  group('signatureUnitOf', () {
    test('Probe-Kette ergibt die Probe-Signatur mit dem Zertifikat der '
        'Kette', () async {
      await rig.service.enableProbe(staff: rig.chef);
      final unit = await signatureUnitOf(
        rig.db,
        rig.secrets,
        online: _noOnline,
      )(1);
      expect(unit, isA<ProbeSignatureUnit>());
      final chain = await rig.chainRow(1);
      expect(chain.unit, 'probe');
      expect((await unit.info()).serialHex, chain.certSerial);
    });

    for (final unit in ['atrustTest', 'atrust']) {
      test('Kette $unit ruft online mit Kette und Zertifikat', () async {
        await rig.startAtrustTest(atrust);
        await setUnit(unit);
        final calls = <(RksvChainRow, RksvCertificateRow)>[];
        final result = await signatureUnitOf(
          rig.db,
          rig.secrets,
          online: (chain, cert) async {
            calls.add((chain, cert));
            return rig.fake;
          },
        )(1);
        expect(result, same(rig.fake));
        expect(calls, hasLength(1));
        final (chain, cert) = calls.single;
        expect(
          (chain.chain, chain.unit, chain.zdaId, chain.cashBoxId),
          (1, unit, 'AT1', 'ONLINETEST'),
        );
        expect(cert.serialHex, '2159b9f6');
        expect(cert.certificate, atrust.certificateDer);
      });
    }

    test('unbekannte Einheit wirft StateError', () async {
      await rig.service.enableProbe(staff: rig.chef);
      await setUnit('neu');
      await expectLater(
        signatureUnitOf(rig.db, rig.secrets, online: _noOnline)(1),
        throwsStateError,
      );
    });

    test('Kette atrustTest mit Modus live wirft StateError: Testsystem '
        'heißt Testbon', () async {
      await rig.startAtrustTest(atrust);
      await rig.db.customStatement("UPDATE rksv_chains SET mode = 'live'");
      await expectLater(
        signatureUnitOf(rig.db, rig.secrets, online: _noOnline)(1),
        throwsStateError,
      );
    });

    test('fehlende Kette wirft StateError', () async {
      await expectLater(
        signatureUnitOf(rig.db, rig.secrets, online: _noOnline)(7),
        throwsStateError,
      );
    });
  });

  group('in der App', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(rig.db),
          rksvSecretsProvider.overrideWithValue(rig.secrets),
          clockProvider.overrideWithValue(rig.clock),
          atrustHttpClientProvider.overrideWithValue(atrust.client),
        ],
      );
      addTearDown(container.dispose);
    });

    test('die Provider zu erzeugen schickt nichts an A-Trust; der Halter '
        'kennt das gespeicherte Kennzeichen', () async {
      await rig.secrets.writeAtrustRejected(true);
      container.read(rksvJournalProvider);
      final keeper = container.read(atrustTestKeeperProvider);
      expect(container.read(atrustTestKeeperProvider), same(keeper));
      await pumpEventQueue();
      expect(keeper.rejected.value, isTrue);
      expect(atrust.requests, isEmpty);
    });

    test('Probe-Kette: ein Verkauf schickt nichts an A-Trust', () async {
      await rig.service.enableProbe(staff: rig.chef);
      final r = await container
          .read(receiptRepositoryProvider)
          .finalizeCashSale(
            saleId: 's1',
            cart: cart,
            givenCents: cart.totalCents,
            staff: rig.anna,
          );
      expect(r.rksv!.damaged, isFalse);
      expect(atrust.requests, isEmpty);
    });

    test('Kette atrustTest: der Bon wird bei A-Trust signiert, mit der '
        'Kennung der Kette und dem Zertifikat aus rksv_certificates', () async {
      await rig.startAtrustTest(atrust);
      final r = await container
          .read(receiptRepositoryProvider)
          .finalizeCashSale(
            saleId: 's1',
            cart: cart,
            givenCents: cart.totalCents,
            staff: rig.anna,
          );
      expect(r.rksv!.damaged, isFalse);
      expect(atrust.requests, [
        'PUT /Session/u123456789',
        startsWith('POST /Session/'),
      ]);
      expect(atrust.requests.last, endsWith('/Sign/Hash'));
      expect((await rig.entryOf('s1'))!.certSerial, '2159b9f6');
      expect((await rig.codeFieldsOf('s1'))[1], 'R1-AT1');
      expect((await rig.stateRow()).outageSince, isNull);
      await rig.verifyChain(1);
    });

    test('Kette atrustTest: die Einheit ist eine OnlineSignatureUnit mit '
        'Kennung, Zertifikat und Ausstellern der Kette', () async {
      await rig.startAtrustTest(atrust);
      final online = container.read(_onlineProvider);
      final chain = await rig.chainRow(1);
      final cert = await rig.db.select(rig.db.rksvCertificateRows).get();
      final unit = await online(
        chain,
        cert.singleWhere((c) => c.serialHex == '2159b9f6'),
      );
      expect(unit, isA<OnlineSignatureUnit>());
      final info = await unit.info();
      expect(info.zdaId, 'AT1');
      expect(info.serialHex, '2159b9f6');
      expect(info.certificateDer, atrust.certificateDer);
      expect(info.issuerCertificatesDer, atrust.issuersDer);
      expect(
        [for (final i in info.issuerCertificatesDer) utf8.decode(i)],
        ['Beispiel Aussteller 1', 'Beispiel Aussteller 2'],
      );
      expect(atrust.requests, isEmpty);
    });

    test(
      'Kette atrust: StateError "Noch nicht gebaut.", nichts an A-Trust',
      () async {
        await rig.startAtrustTest(atrust);
        await setUnit('atrust');
        await expectLater(
          container
              .read(rksvJournalProvider)
              .record(
                receiptId: 'x',
                number: 1,
                createdAt: rig.clock.now(),
                kind: ReceiptKind.sale,
                sumsCents: const [0, 0, 0, 0, 0],
              ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'Noch nicht gebaut.',
            ),
          ),
        );
        expect(atrust.requests, isEmpty);
      },
    );
  });
}

/// Die Online-Einheiten der App, wie [rksvJournalProvider] sie baut.
final _onlineProvider =
    Provider<Future<SignatureUnit> Function(RksvChainRow, RksvCertificateRow)>(
      onlineSignatureUnitOf,
    );
