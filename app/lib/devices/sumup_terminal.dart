// Kartenzahlung mit SumUp: Android spricht mit dem SDK, Dart über den Kanal
// `kassa/sumup` (siehe SumUpChannel.kt).

import 'package:flutter/services.dart';

import 'card_terminal.dart';

const sumUpChannel = MethodChannel('kassa/sumup');

/// Übersetzt die Antwort von `pay` (Ergebniscodes aus
/// `SumUpAPI.Response.ResultCode`).
CardPaymentResult mapSumUpResult(Map<Object?, Object?> raw) {
  final code = raw['resultCode'];
  final message = raw['message'] as String?;
  switch (code) {
    case 1:
      final txCode = raw['txCode'] as String?;
      // Ohne Transaktionscode lässt sich die Zahlung nicht nachweisen.
      if (txCode == null || txCode.isEmpty) return const CardUnknown();
      return CardPaid(
        txCode: txCode,
        cardScheme: raw['cardType'] as String?,
        cardLast4: raw['last4'] as String?,
      );
    case 2:
      return const CardFailed(CardFailure.declined);
    case 3 || 7:
      return const CardFailed(CardFailure.permission);
    case 6:
      return const CardFailed(CardFailure.noInternet);
    case 8:
      return const CardFailed(CardFailure.notLoggedIn);
    case 14:
      return const CardFailed(CardFailure.noReader);
    // 15: Stand unbekannt. 9: Die Kennung wurde schon einmal verwendet, also
    // ist offen, was mit der ersten Zahlung war.
    case 15 || 9:
      return const CardUnknown();
    default:
      return CardFailed(CardFailure.other, detail: message);
  }
}

class SumUpTerminal implements CardTerminal {
  SumUpTerminal({this.channel = sumUpChannel});

  final MethodChannel channel;

  static const _notConfigured = CardTerminalStatus(
    CardTerminalState.notConfigured,
  );

  @override
  String get providerName => 'sumup';

  @override
  int get minimumCents => 100;

  /// Ohne Kanal (Tests, andere Plattformen) oder bei einem Fehler: nicht
  /// eingerichtet.
  @override
  Future<CardTerminalStatus> status() async {
    try {
      final raw = await channel.invokeMapMethod<String, Object?>('status');
      if (raw == null || raw['configured'] != true) return _notConfigured;
      if (raw['loggedIn'] != true) {
        return const CardTerminalStatus(CardTerminalState.loggedOut);
      }
      return CardTerminalStatus(
        CardTerminalState.ready,
        merchantName: raw['merchant'] as String?,
      );
    } catch (_) {
      return _notConfigured;
    }
  }

  /// Zeigt die Anmeldung von SumUp und meldet danach den Stand.
  @override
  Future<CardTerminalStatus> login() async {
    await _call('login');
    return status();
  }

  @override
  Future<void> logout() => _call('logout');

  @override
  Future<void> openReaderSettings() => _call('openReaderPage');

  @override
  Future<void> prepare() => _call('prepare');

  @override
  Future<CardPaymentResult> pay({
    required String paymentId,
    required int amountCents,
    required String title,
  }) async {
    final Map<Object?, Object?>? raw;
    try {
      raw = await channel.invokeMethod<Map<Object?, Object?>>('pay', {
        'paymentId': paymentId,
        'amountCents': amountCents,
        'title': title,
      });
    } on PlatformException catch (e) {
      // Die Antwort von SumUp war nicht lesbar: Ob bezahlt wurde, ist offen.
      if (e.code == 'unknown') return const CardUnknown();
      // Sonst wurde die Zahlung gar nicht erst begonnen.
      if (e.code == 'busy') {
        return const CardFailed(
          CardFailure.other,
          detail: 'Es läuft schon eine Kartenzahlung.',
        );
      }
      return CardFailed(CardFailure.other, detail: e.message);
    } on MissingPluginException {
      return const CardFailed(CardFailure.other);
    }
    // Der Bildschirm von SumUp wurde ohne Ergebnis geschlossen.
    if (raw == null) return const CardFailed(CardFailure.cancelled);
    return mapSumUpResult(raw);
  }

  /// Ruft [method] auf; Fehler und ein fehlender Kanal werden geschluckt.
  Future<void> _call(String method) async {
    try {
      await channel.invokeMethod<void>(method);
    } catch (_) {
      // Der Stand zeigt, ob es geklappt hat.
    }
  }
}
