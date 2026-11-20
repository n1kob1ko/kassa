// Lauf gegen das öffentliche Testsystem von A-Trust (a.sign RK HSM).
//
// Die Gruppe "Testsystem" läuft nur mit KASSA_ATRUST_TEST=1 (GitHub-Lauf
// "atrust-testsystem"), mit dem echten http.Client gegen AtrustSystem.test.
// Die Gruppe "Probelauf" fährt dieselben Schritte gegen FakeAtrust und läuft
// immer, damit ein Fehler im Testcode nicht erst am Testsystem auffällt.
//
// Benutzer und Passwörter stehen im Handbuch von A-Trust und sind öffentlich
// (P6). Gedruckt werden nur die beiden Dateien für das Prüfwerkzeug, nie ein
// Passwort, eine Sitzungs-Id oder ein Sitzungsschlüssel.

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kassa/core/clock.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/rksv/card/card_check.dart' show RowState;
import 'package:kassa/rksv/card/certificate.dart';
import 'package:kassa/rksv/dep_export.dart';
import 'package:kassa/rksv/online/atrust_client.dart';
import 'package:kassa/rksv/online/atrust_session_keeper.dart';
import 'package:kassa/rksv/online/connection_check.dart';
import 'package:kassa/rksv/online/online_signature_unit.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:pointycastle/digests/sha256.dart';

import '../../support/fake_atrust.dart';
import '../../support/pruefwerkzeug.dart';
import '../../support/rksv_rig.dart';
import '../../support/sales.dart' show cart;

/// Der gesperrte Test-Benutzer aus dem Handbuch von A-Trust. Öffentliche
/// Testwerte (P6).
const _blockedUser = 'u039193334';
const _blockedPassword = '60z7dx';

/// Start der Kette, innerhalb der Gültigkeit des Test-Zertifikats von
/// A-Trust (10.03.2016 bis 10.05.2020) und in der Vergangenheit der echten
/// Uhr (Kern R11).
final _start = DateTime(2019, 11, 18, 13, 5, 9);

const _timeout = Timeout(Duration(minutes: 3));

/// Zählt die Anfragen und merkt sich von Anmeldungen nur den Benutzer. Kein
/// Pfad mit Sitzungs-Id und kein Körper wird gespeichert.
class _CountingClient extends http.BaseClient {
  _CountingClient(this._inner);

  final http.Client _inner;
  int requests = 0;
  final List<String> loginUsers = [];

  static final _login = RegExp(r'/Session/(u\d+)$');

  int logins(String user) => loginUsers.where((u) => u == user).length;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests++;
    final m = _login.firstMatch(request.url.path);
    if (request.method == 'PUT' && m != null) loginUsers.add(m.group(1)!);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

Uint8List _sha256(String text) =>
    SHA256Digest().process(Uint8List.fromList(ascii.encode(text)));

Matcher _throwsProblem(AtrustProblem problem) => throwsA(
  isA<AtrustException>().having((e) => e.problem, 'problem', problem),
);

AtrustSessionKeeper _keeper(
  AtrustClient client, {
  String user = atrustTestUser,
  String password = atrustTestPassword,
}) => AtrustSessionKeeper(
  client: client,
  credentials: () async => AtrustCredentials(user, password),
  secrets: MemoryRksvSecrets(),
  clock: FixedClock(_start),
);

// Die Schritte. Jeder nimmt, was zwischen Testsystem und Probelauf
// verschieden ist, und prüft selbst.

/// 1. "Verbindung prüfen" ergibt vier Haken.
Future<void> _checkConnection(http.Client http) async {
  final client = AtrustClient(http, AtrustSystem.test);
  final check = ConnectionCheck(
    client: client,
    keeper: _keeper(client),
    user: atrustTestUser,
    clock: FixedClock(_start),
  );
  addTearDown(check.dispose);
  final result = await check.run(chefTapped: false);
  expect(
    {for (final e in result.rows.entries) e.key: e.value.state},
    {for (final row in ConnectionRow.values) row: RowState.ok},
    reason: [for (final r in result.rows.values) r.message].join(' '),
  );
  expect(result.facts, isNotNull);
  expect(result.facts!.zdaId, 'AT1');
  expect(result.facts!.certificate.serialHex, '2159b9f6');
}

/// 2. 20 Signaturen über eine OnlineSignatureUnit, jede am Zertifikat
/// geprüft; genau eine Anmeldung.
Future<void> _twentySignatures(_CountingClient http) async {
  final client = AtrustClient(http, AtrustSystem.test);
  final certificate = await client.certificate(atrustTestUser);
  final parsed = CardCertificate.parse(certificate.certificateDer);
  final unit = OnlineSignatureUnit(
    client: client,
    keeper: _keeper(client),
    zdaId: 'AT1',
    certificateDer: certificate.certificateDer,
    issuerCertificatesDer: certificate.issuersDer,
  );
  final before = http.logins(atrustTestUser);
  for (var i = 1; i <= 20; i++) {
    final input = 'Kassa Testsystem Signatur $i';
    final signature = await unit.sign(input);
    expect(signature, hasLength(64), reason: 'Signatur $i');
    expect(
      parsed.verify(_sha256(input), signature),
      isTrue,
      reason: 'Signatur $i passt nicht zum Zertifikat',
    );
  }
  expect(http.logins(atrustTestUser) - before, 1, reason: 'Anmeldungen');
}

/// 3. Eine erfundene Sitzung mit dem Schlüssel der echten wirft
/// sessionExpired; das Abmelden der echten Sitzung antwortet ohne Fehler.
Future<void> _unknownSessionAndLogout(http.Client http) async {
  final client = AtrustClient(http, AtrustSystem.test);
  final session = await client.login(atrustTestUser, atrustTestPassword);
  await expectLater(
    client.signHash(
      AtrustSession('unbekannt', session.key),
      _sha256('Kassa Testsystem unbekannte Sitzung'),
    ),
    _throwsProblem(AtrustProblem.sessionExpired),
  );
  await client.logout(session);
}

/// 4. Der gesperrte Benutzer: login wirft rejected; ein Halter mit ihm setzt
/// rejected und schickt beim zweiten session() nichts. Genau zwei
/// Anmeldungen mit ihm im ganzen Lauf.
Future<void> _blockedUserIsRejected(_CountingClient http) async {
  // Vorher keine: so bleiben es höchstens zwei je Lauf.
  expect(http.logins(_blockedUser), 0);
  final client = AtrustClient(http, AtrustSystem.test);
  await expectLater(
    client.login(_blockedUser, _blockedPassword),
    _throwsProblem(AtrustProblem.rejected),
  );
  final keeper = _keeper(
    client,
    user: _blockedUser,
    password: _blockedPassword,
  );
  await expectLater(keeper.session(), _throwsProblem(AtrustProblem.rejected));
  expect(keeper.rejected.value, isTrue);
  final sent = http.requests;
  await expectLater(keeper.session(), _throwsProblem(AtrustProblem.rejected));
  expect(http.requests, sent, reason: 'zweites session() schickt nichts');
  expect(http.logins(_blockedUser), 2);
}

/// 5. Eine Kette im RksvRig mit echter Online-Einheit: Probe ein, zwei
/// Verkäufe (einer mit 1.234,56 Euro, nach dem Monatswechsel), ein Storno,
/// ein Nullbeleg, Probe aus. Prüft noch nichts an der Kette, damit Schritt 6
/// die Dateien auch von einer kaputten Kette ausgibt.
Future<RksvRig> _buildChain(http.Client http) async {
  final rig = await RksvRig.open(atrustClient: http);
  rig.clock.value = _start;
  final check = ConnectionCheck(
    client: AtrustClient(http, AtrustSystem.test),
    keeper: rig.keeper!,
    user: atrustTestUser,
    clock: rig.clock,
  );
  final facts = (await check.run(chefTapped: false)).facts;
  check.dispose();
  if (facts == null) {
    await rig.close();
    fail('"Verbindung prüfen" ohne vier Haken.');
  }
  await rig.service.enableOnlineProbe(staff: rig.chef, facts: facts);
  rig.clock.value = DateTime(2019, 11, 18, 13, 6, 9);
  await rig.sell('november', cart);
  rig.clock.value = DateTime(2019, 11, 18, 13, 7, 9);
  await rig.receipts.voidReceipt('november', staff: rig.chef);
  // Monatswechsel: vor dem Verkauf kommt der Monatsbeleg.
  rig.clock.value = DateTime(2019, 12, 2, 10);
  await rig.sell('gross', const Cart.empty().add(_gross));
  rig.clock.value = DateTime(2019, 12, 2, 10, 5);
  await rig.service.zeroReceipt(staff: rig.chef);
  rig.clock.value = DateTime(2019, 12, 2, 10, 10);
  await rig.service.disableProbe(staff: rig.chef);
  return rig;
}

const _gross = Item(
  id: 'gross',
  name: 'gross',
  priceCents: 123456,
  categoryId: 'snacks',
  taxRate: TaxRate.normal,
  position: 0,
);

/// 5. Die Kette aus [_buildChain] ist heil.
Future<void> _expectSoundChain(RksvRig rig) async {
  expect(await rig.entryKinds(), [
    'start',
    'sale',
    'voided',
    'month',
    'sale',
    'zero',
    'closing',
  ]);
  expect([
    for (final e in await rig.entries(1)) e.damaged,
  ], everyElement(false));
  final chain = await rig.chainRow(1);
  expect(
    (chain.mode, chain.unit, chain.zdaId, chain.certSerial),
    ('probe', 'atrustTest', 'AT1', '2159b9f6'),
  );
  await rig.verifyChain(1);
  expect(await rig.journal.chainIsSound(1), isTrue);
}

/// 6. Das ausgegebene Protokoll und die Datei mit Schlüssel und Zertifikat
/// für das Prüfwerkzeug nach [dir], beide über [out] als Base64 in je einer
/// Zeile zwischen den Marken.
Future<(File, File)> _writeFiles(
  RksvRig rig,
  Directory dir,
  void Function(String line) out,
) async {
  expect(
    await rig.service.exportProtocol(ExportRange.all, now: rig.clock.now()),
    ExportOutcome.saved,
  );
  dir.createSync(recursive: true);
  final dep = File('${dir.path}/dep-export.json')
    ..writeAsStringSync(rig.saver.lastText);
  final crypto = File('${dir.path}/cryptographicMaterialContainer.json')
    ..writeAsStringSync(await cryptographicMaterialContainer(rig, 1));
  out('-----DEP-----');
  out(base64.encode(dep.readAsBytesSync()));
  out('-----CRYPTO-----');
  out(base64.encode(crypto.readAsBytesSync()));
  out('-----ENDE-----');
  return (dep, crypto);
}

void main() {
  final real = Platform.environment['KASSA_ATRUST_TEST'] == '1';

  group('Testsystem von A-Trust', () {
    late _CountingClient client;
    RksvRig? rig;

    setUpAll(() {
      // flutter test lässt sonst keine echte Anfrage hinaus.
      HttpOverrides.global = null;
      client = _CountingClient(http.Client());
    });
    tearDownAll(() async {
      await rig?.close();
      client.close();
    });

    test(
      '1. Verbindung prüfen ergibt vier Haken',
      () => _checkConnection(client),
      timeout: _timeout,
    );
    test(
      '2. 20 Signaturen, jede am Zertifikat geprüft, eine Anmeldung',
      () => _twentySignatures(client),
      timeout: _timeout,
    );
    test(
      '3. erfundene Sitzung: sessionExpired; Abmelden ohne Fehler',
      () => _unknownSessionAndLogout(client),
      timeout: _timeout,
    );
    test(
      '4. gesperrter Benutzer: rejected, danach keine Anfrage',
      () => _blockedUserIsRejected(client),
      timeout: _timeout,
    );
    test('5. Kette mit echter Online-Einheit aufbauen', () async {
      rig = await _buildChain(client);
    }, timeout: _timeout);
    test('6. Protokoll und Datei für das Prüfwerkzeug', () async {
      if (rig == null) fail('Keine Kette aus Schritt 5.');
      await _writeFiles(rig!, Directory('build/atrust'), print);
    }, timeout: _timeout);
    test('5. die Kette ist heil (chainIsSound)', () async {
      if (rig == null) fail('Keine Kette aus Schritt 5.');
      await _expectSoundChain(rig!);
    }, timeout: _timeout);
  }, skip: real ? null : 'Nur mit KASSA_ATRUST_TEST=1.');

  group('Probelauf gegen FakeAtrust', () {
    late FakeAtrust atrust;
    late _CountingClient client;

    setUp(() {
      // Das Zertifikat gilt ab 10.03.2016 zehn Jahre, also auch 2019.
      atrust = FakeAtrust(validFrom: DateTime.utc(2016, 3, 10));
      client = _CountingClient(atrust.client);
    });

    test('1. Verbindung prüfen ergibt vier Haken', () async {
      await _checkConnection(client);
    });
    test(
      '2. 20 Signaturen, jede am Zertifikat geprüft, eine Anmeldung',
      () async {
        await _twentySignatures(client);
        expect(
          atrust.requests.where((r) => r.endsWith('/Sign/Hash')),
          hasLength(20),
        );
      },
    );
    test(
      '3. erfundene Sitzung: sessionExpired; Abmelden ohne Fehler',
      () async {
        await _unknownSessionAndLogout(client);
        expect(atrust.requests.last, startsWith('DELETE /Session/'));
      },
    );
    test('4. gesperrter Benutzer: rejected, danach keine Anfrage', () async {
      atrust.loginStatus = 403;
      await _blockedUserIsRejected(client);
      expect(atrust.requests, [
        'PUT /Session/$_blockedUser',
        'PUT /Session/$_blockedUser',
      ]);
    });

    group('5. und 6.', () {
      late RksvRig rig;
      late Directory temp;

      setUp(() async {
        rig = await _buildChain(client);
        temp = await Directory.systemTemp.createTemp('kassa-atrust-');
      });
      tearDown(() async {
        await rig.close();
        await temp.delete(recursive: true);
      });

      test('5. die Kette ist heil (chainIsSound)', () async {
        await _expectSoundChain(rig);
      });

      test('6. Dateien geschrieben und zwischen den Marken gedruckt', () async {
        final lines = <String>[];
        final (dep, crypto) = await _writeFiles(rig, temp, lines.add);
        expect(lines, hasLength(5));
        expect(
          [lines[0], lines[2], lines[4]],
          ['-----DEP-----', '-----CRYPTO-----', '-----ENDE-----'],
        );
        expect(base64.decode(lines[1]), dep.readAsBytesSync());
        expect(base64.decode(lines[3]), crypto.readAsBytesSync());
        final container =
            jsonDecode(crypto.readAsStringSync()) as Map<String, dynamic>;
        expect(
          base64.decode(container['base64AESKey'] as String),
          (await rig.secrets.aesKey(1))!,
        );
        expect((container['certificateOrPublicKeyMap'] as Map).keys, [
          '2159b9f6',
        ]);
        final groups =
            (jsonDecode(dep.readAsStringSync()) as Map)['Belege-Gruppe']
                as List;
        expect((groups.single as Map)['Belege-kompakt'], hasLength(7));
      });

      final tool = pruefwerkzeugDir();
      test(
        '6. das Prüfwerkzeug nimmt beide Dateien an',
        () async {
          final (dep, crypto) = await _writeFiles(rig, temp, (_) {});
          final problems = await checkWithPruefwerkzeug(
            tool!,
            dep: dep,
            crypto: crypto,
            entryCount: (await rig.entries(1)).length,
            workDir: temp,
          );
          expect(problems, isEmpty, reason: problems.join('\n\n'));
        },
        skip: tool == null
            ? 'Prüfwerkzeug nicht da: KASSA_RKSV_TOOL zeigt auf keinen Ordner.'
            : null,
        timeout: const Timeout(Duration(minutes: 3)),
      );
    });
  });
}
