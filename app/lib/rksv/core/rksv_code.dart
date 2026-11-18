import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Rechenkern der Registrierkassensicherheit: Betrags- und Zeitformat,
/// verschlüsselter Umsatzzähler, Kettenwert, Code-Text, JWS und QR-Text.
/// Reines Dart, ohne Flutter.

const String jwsHeader = 'eyJhbGciOiJFUzI1NiJ9';
const String damagedSignatureText = 'Sicherheitseinrichtung ausgefallen';
const String stornoCounterField = 'U1RP'; // base64 von "STO"

/// '12,90', '-0,25', '0,00', '1234,56'. Nie ein Tausenderpunkt, nie '-0,00'.
String formatCodeAmount(int cents) {
  final negative = cents < 0;
  final abs = cents.abs();
  final euros = abs ~/ 100;
  final rest = (abs % 100).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}$euros,$rest';
}

/// Ortszeit ohne Zeitzone: '2026-11-18T13:05:09'.
String formatCodeTime(DateTime local) {
  String p(int n, [int w = 2]) => n.toString().padLeft(w, '0');
  return '${p(local.year, 4)}-${p(local.month)}-${p(local.day)}'
      'T${p(local.hour)}:${p(local.minute)}:${p(local.second)}';
}

Uint8List _iv(String cashBoxId, String receiptId) {
  final digest = SHA256Digest().process(
    Uint8List.fromList(utf8.encode(cashBoxId + receiptId)),
  );
  return Uint8List.sublistView(digest, 0, 16);
}

Uint8List _ctr(
  Uint8List key,
  String cashBoxId,
  String receiptId,
  Uint8List data,
) {
  final cipher = CTRStreamCipher(
    AESEngine(),
  )..init(true, ParametersWithIV(KeyParameter(key), _iv(cashBoxId, receiptId)));
  return cipher.process(data);
}

/// AES-256 im Zählermodus. IV = die ersten 16 Bytes von SHA-256(UTF-8(cashBoxId + receiptId)).
/// Klartext = [counterCents] als 8 Bytes, Zweierkomplement, höchstes Byte zuerst.
String encryptCounter({
  required Uint8List aesKey,
  required String cashBoxId,
  required String receiptId,
  required int counterCents,
}) {
  final plain = Uint8List(8);
  var rest = BigInt.from(counterCents).toUnsigned(64);
  for (var i = 7; i >= 0; i--) {
    plain[i] = (rest & BigInt.from(0xff)).toInt();
    rest >>= 8;
  }
  return base64Encode(_ctr(aesKey, cashBoxId, receiptId, plain));
}

/// Umkehrung, für Tests und die Prüfung der eigenen Kette.
int decryptCounter({
  required Uint8List aesKey,
  required String cashBoxId,
  required String receiptId,
  required String field,
}) {
  final plain = _ctr(aesKey, cashBoxId, receiptId, base64Decode(field));
  var value = BigInt.zero;
  for (final b in plain) {
    value = (value << 8) | BigInt.from(b);
  }
  return value.toSigned(plain.length * 8).toInt();
}

/// base64 der ersten 8 Bytes von SHA-256(UTF-8(input)).
String chainValue(String input) {
  final digest = SHA256Digest().process(Uint8List.fromList(utf8.encode(input)));
  return base64Encode(digest.sublist(0, 8));
}

final class CodeFields {
  const CodeFields({
    required this.zdaId,
    required this.cashBoxId,
    required this.receiptId,
    required this.time,
    required this.sumsCents,
    required this.counterField,
    required this.certSerial,
    required this.chain,
  });

  final String zdaId;
  final String cashBoxId;
  final String receiptId;
  final DateTime time;

  /// Genau 5: Normal, Ermäßigt-1, Ermäßigt-2, Null, Besonders.
  final List<int> sumsCents;
  final String counterField;
  final String certSerial;
  final String chain;
}

/// Format: `_R1-AT1_BSPIMB01_1_2026-11-18T13:05:09_0,00_0,00_0,00_0,00_0,00_Zähler_Serie_Kette`.
String codeText(CodeFields f) {
  if (f.sumsCents.length != 5) {
    throw ArgumentError('sumsCents braucht genau 5 Werte');
  }
  for (final id in [f.cashBoxId, f.receiptId]) {
    if (id.isEmpty || id.contains('_')) {
      throw ArgumentError('Kennung leer oder mit Unterstrich');
    }
  }
  return '_R1-${f.zdaId}_${f.cashBoxId}_${f.receiptId}_${formatCodeTime(f.time)}'
      '_${f.sumsCents.map(formatCodeAmount).join('_')}'
      '_${f.counterField}_${f.certSerial}_${f.chain}';
}

String _b64Url(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

/// Das, was signiert wird.
String jwsSigningInput(String text) =>
    '$jwsHeader.${_b64Url(utf8.encode(text))}';

/// signingInput + '.' + base64url ohne '=' der 64 Bytes R|S.
String jwsCompact(String text, Uint8List signature) =>
    '${jwsSigningInput(text)}.${_b64Url(signature)}';

/// Wie [jwsCompact], mit [damagedSignatureText] an der Stelle der Signatur.
String jwsDamaged(String text) =>
    '${jwsSigningInput(text)}.'
    '${_b64Url(utf8.encode(damagedSignatureText))}';

bool isDamagedJws(String jws) {
  final i = jws.lastIndexOf('.');
  return i >= 0 &&
      jws.substring(i + 1) == _b64Url(utf8.encode(damagedSignatureText));
}

/// Nutzlast + '_' + Signatur als base64 MIT '=' (nicht url-sicher).
String qrText(String jws) {
  final parts = jws.split('.');
  if (parts.length != 3) throw const FormatException('Kein JWS');
  final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
  final sig = base64.encode(base64Url.decode(base64Url.normalize(parts[2])));
  return '${payload}_$sig';
}

/// DER-Signatur (SEQUENCE aus zwei INTEGER) zu 64 Bytes R|S.
Uint8List derSignatureToConcat(Uint8List der) {
  const bad = FormatException('Ungültige DER-Signatur');
  var pos = 0;
  int len() {
    if (pos >= der.length) throw bad;
    final b = der[pos++];
    if (b < 0x80) return b;
    final n = b & 0x7f;
    if (n != 1 || pos >= der.length) throw bad;
    return der[pos++];
  }

  Uint8List integer() {
    if (pos >= der.length || der[pos++] != 0x02) throw bad;
    final l = len();
    if (l == 0 || pos + l > der.length) throw bad;
    var bytes = der.sublist(pos, pos + l);
    pos += l;
    while (bytes.length > 32 && bytes.first == 0) {
      bytes = bytes.sublist(1);
    }
    if (bytes.length > 32) throw bad;
    return Uint8List(32)..setRange(32 - bytes.length, 32, bytes);
  }

  if (der.isEmpty || der[pos++] != 0x30) throw bad;
  final total = len();
  if (pos + total != der.length) throw bad;
  final r = integer();
  final s = integer();
  if (pos != der.length) throw bad;
  return Uint8List.fromList([...r, ...s]);
}
