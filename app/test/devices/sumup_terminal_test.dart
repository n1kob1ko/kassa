import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/devices/card_terminal.dart';
import 'package:kassa/devices/device_providers.dart';
import 'package:kassa/devices/sumup_terminal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Stellt den Kanal `kassa/sumup` nach; [calls] sammelt die Aufrufe.
  List<MethodCall> answer(Future<Object?>? Function(MethodCall call) handler) {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(sumUpChannel, (call) {
      calls.add(call);
      return handler(call);
    });
    addTearDown(() => messenger.setMockMethodCallHandler(sumUpChannel, null));
    return calls;
  }

  CardFailure failureOf(Map<Object?, Object?> raw) =>
      (mapSumUpResult(raw) as CardFailed).failure;

  test('Ergebnis-Codes werden richtig übersetzt', () {
    expect(
      mapSumUpResult({
        'resultCode': 1,
        'txCode': 'TX1',
        'cardType': 'VISA',
        'last4': '4242',
      }),
      isA<CardPaid>()
          .having((p) => p.txCode, 'txCode', 'TX1')
          .having((p) => p.cardScheme, 'cardScheme', 'VISA')
          .having((p) => p.cardLast4, 'last4', '4242'),
    );
    expect(mapSumUpResult({'resultCode': 1}), isA<CardUnknown>());
    expect(mapSumUpResult({'resultCode': 1, 'txCode': ''}), isA<CardUnknown>());
    expect(failureOf({'resultCode': 2}), CardFailure.declined);
    expect(failureOf({'resultCode': 3}), CardFailure.permission);
    expect(failureOf({'resultCode': 7}), CardFailure.permission);
    expect(failureOf({'resultCode': 6}), CardFailure.noInternet);
    expect(failureOf({'resultCode': 8}), CardFailure.notLoggedIn);
    expect(failureOf({'resultCode': 14}), CardFailure.noReader);
    expect(mapSumUpResult({'resultCode': 15}), isA<CardUnknown>());
    expect(mapSumUpResult({'resultCode': 9}), isA<CardUnknown>());
    final other = mapSumUpResult({'resultCode': 4, 'message': 'x'});
    expect((other as CardFailed).failure, CardFailure.other);
    expect(other.detail, 'x');
    expect(failureOf({'resultCode': 10}), CardFailure.other);
    expect(failureOf({}), CardFailure.other);
  });

  test('pay schickt Kennung, Cent und Titel', () async {
    final calls = answer(
      (call) async => {
        'resultCode': 1,
        'message': null,
        'txCode': 'TX9',
        'cardType': 'MASTERCARD',
        'last4': '0005',
      },
    );

    final result = await SumUpTerminal().pay(
      paymentId: 'bon-1',
      amountCents: 1250,
      title: 'Beispiel-Imbiss',
    );

    expect(calls.single.method, 'pay');
    expect(calls.single.arguments, {
      'paymentId': 'bon-1',
      'amountCents': 1250,
      'title': 'Beispiel-Imbiss',
    });
    expect(
      result,
      isA<CardPaid>()
          .having((p) => p.txCode, 'txCode', 'TX9')
          .having((p) => p.cardScheme, 'cardScheme', 'MASTERCARD')
          .having((p) => p.cardLast4, 'last4', '0005'),
    );
  });

  test('Antwort null wird abgebrochen', () async {
    answer((call) async => null);

    final result = await SumUpTerminal().pay(
      paymentId: 'bon-1',
      amountCents: 500,
      title: 'Beispiel-Imbiss',
    );

    expect((result as CardFailed).failure, CardFailure.cancelled);
  });

  test('Kanal-Fehler busy wird "Es läuft schon eine Kartenzahlung."', () async {
    answer((call) async => throw PlatformException(code: 'busy'));

    final result = await SumUpTerminal().pay(
      paymentId: 'bon-2',
      amountCents: 500,
      title: 'Beispiel-Imbiss',
    );

    expect((result as CardFailed).failure, CardFailure.other);
    expect(result.detail, 'Es läuft schon eine Kartenzahlung.');
    expect(result.message, contains('Es läuft schon eine Kartenzahlung.'));
  });

  test('ein anderer Kanal-Fehler bei pay wird CardFailed other', () async {
    answer((call) async => throw PlatformException(code: 'failed'));

    final result = await SumUpTerminal().pay(
      paymentId: 'bon-3',
      amountCents: 500,
      title: 'Beispiel-Imbiss',
    );

    expect((result as CardFailed).failure, CardFailure.other);
  });

  test(
    'Kanal-Fehler unknown (Antwort nicht lesbar) wird CardUnknown',
    () async {
      answer((call) async => throw PlatformException(code: 'unknown'));

      final result = await SumUpTerminal().pay(
        paymentId: 'bon-4',
        amountCents: 500,
        title: 'Beispiel-Imbiss',
      );

      expect(result, isA<CardUnknown>());
    },
  );

  test('status ohne Schlüssel: notConfigured, mit Schlüssel abgemeldet: '
      'loggedOut, angemeldet: ready mit Namen', () async {
    Map<String, Object?> reply = {
      'configured': false,
      'loggedIn': false,
      'merchant': null,
    };
    answer((call) async => reply);
    final terminal = SumUpTerminal();

    expect(
      await terminal.status(),
      const CardTerminalStatus(CardTerminalState.notConfigured),
    );

    reply = {'configured': true, 'loggedIn': false, 'merchant': null};
    expect(
      await terminal.status(),
      const CardTerminalStatus(CardTerminalState.loggedOut),
    );

    reply = {'configured': true, 'loggedIn': true, 'merchant': 'MC123'};
    expect(
      await terminal.status(),
      const CardTerminalStatus(CardTerminalState.ready, merchantName: 'MC123'),
    );
  });

  test('login, logout, Leser und prepare rufen ihre Methoden', () async {
    final calls = answer(
      (call) async => call.method == 'status'
          ? {'configured': true, 'loggedIn': true, 'merchant': 'MC123'}
          : null,
    );
    final terminal = SumUpTerminal();

    expect(
      await terminal.login(),
      const CardTerminalStatus(CardTerminalState.ready, merchantName: 'MC123'),
    );
    await terminal.logout();
    await terminal.openReaderSettings();
    await terminal.prepare();

    expect(calls.map((c) => c.method), [
      'login',
      'status',
      'logout',
      'openReaderPage',
      'prepare',
    ]);
  });

  test(
    'ein Fehler bei login meldet den aktuellen Stand, prepare wirft nie',
    () async {
      answer((call) async {
        if (call.method == 'status') {
          return {'configured': true, 'loggedIn': false, 'merchant': null};
        }
        throw PlatformException(code: 'busy');
      });
      final terminal = SumUpTerminal();

      expect(
        await terminal.login(),
        const CardTerminalStatus(CardTerminalState.loggedOut),
      );
      await terminal.prepare();
      await terminal.logout();
      await terminal.openReaderSettings();
    },
  );

  test('der Kanal fehlt (Test ohne Android): notConfigured, pay ergibt '
      'CardFailed other', () async {
    final terminal = SumUpTerminal();

    expect(
      await terminal.status(),
      const CardTerminalStatus(CardTerminalState.notConfigured),
    );
    expect(
      await terminal.login(),
      const CardTerminalStatus(CardTerminalState.notConfigured),
    );
    await terminal.logout();
    await terminal.openReaderSettings();
    await terminal.prepare();
    final result = await terminal.pay(
      paymentId: 'bon-1',
      amountCents: 500,
      title: 'Beispiel-Imbiss',
    );
    expect((result as CardFailed).failure, CardFailure.other);
  });

  test('minimumCents ist 100, providerName ist sumup', () {
    final terminal = SumUpTerminal();
    expect(terminal.minimumCents, 100);
    expect(terminal.providerName, 'sumup');
  });

  test('cardTerminalProvider liefert SumUpTerminal', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(cardTerminalProvider), isA<SumUpTerminal>());
  });
}
