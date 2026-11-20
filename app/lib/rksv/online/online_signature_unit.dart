import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';

import '../card/certificate.dart';
import '../self_signed_certificate.dart';
import '../signature_unit.dart';
import 'atrust_client.dart';
import 'atrust_session_keeper.dart';

/// Die Signatureinheit über A-Trust (Entwurf 6.2). Jeder Fehler wird zu einer
/// [SignatureFailure] mit einem deutschen Satz (P2). Scheitert das Signieren
/// auch mit einer nach `sessionExpired` frisch geholten Sitzung, ist das
/// "A-Trust hat die Signatur abgelehnt.", und mit dieser Sitzung wird nicht
/// noch einmal neu angemeldet (Plan Q9). Eine Frist setzt der
/// Aufrufer; eine Antwort nach der Frist läuft hier ohne unbehandelte
/// Ausnahme zu Ende, und eine dabei erhaltene Sitzung bleibt im Halter.
class OnlineSignatureUnit implements SignatureUnit {
  OnlineSignatureUnit({
    required this._client,
    required this._keeper,
    required this._zdaId,
    required Uint8List certificateDer,
    List<Uint8List> issuerCertificatesDer = const [],
  }) : _certificateDer = Uint8List.fromList(certificateDer),
       _issuersDer = [
         for (final i in issuerCertificatesDer) Uint8List.fromList(i),
       ];

  static const _mismatch =
      'Die Signatur von A-Trust passt nicht zum Zertifikat.';
  static const _failed = 'Die Signatur von A-Trust ist gescheitert.';

  /// Je Halter die Sitzung, mit der nach einer neuen Anmeldung wieder nicht
  /// signiert werden konnte (Q9). Am Halter und nicht an der Einheit, weil die
  /// App je Bon eine neue Einheit baut; der Halter selbst weiß davon nichts.
  static final _refused = Expando<AtrustSession>('refused');

  final AtrustClient _client;
  final AtrustSessionKeeper _keeper;
  final String _zdaId;
  final Uint8List _certificateDer;

  /// Nur weitergereicht, nie gelesen (die Aussteller haben RSA-Schlüssel).
  final List<Uint8List> _issuersDer;
  CardCertificate? _certificate;

  @override
  Future<SignerInfo> info() async => SignerInfo(
    zdaId: _zdaId,
    serialHex: certificateSerialHex(_certificateDer),
    certificateDer: _certificateDer,
    issuerCertificatesDer: _issuersDer,
  );

  @override
  Future<Uint8List> sign(String signingInput) async {
    try {
      final certificate = _certificate ??= CardCertificate.parse(
        _certificateDer,
      );
      final hash = SHA256Digest().process(
        Uint8List.fromList(ascii.encode(signingInput)),
      );
      var session = await _session();
      Uint8List signature;
      try {
        signature = await _client.signHash(session, hash);
      } on AtrustException catch (e) {
        if (e.problem != AtrustProblem.sessionExpired) rethrow;
        if (identical(session, _refused[_keeper])) {
          throw const AtrustException(AtrustProblem.refused);
        }
        _keeper.drop(session);
        session = await _session();
        try {
          signature = await _client.signHash(session, hash);
        } on AtrustException catch (e) {
          if (e.problem != AtrustProblem.sessionExpired) rethrow;
          // Q9: Auch die frisch geholte Sitzung signiert nicht. Für sie wird
          // nicht noch einmal angemeldet, solange der Halter sie ausgibt.
          _refused[_keeper] = session;
          throw const AtrustException(AtrustProblem.refused);
        }
      }
      if (!certificate.verify(hash, signature)) {
        throw const SignatureFailure(_mismatch);
      }
      _keeper.used(session);
      return signature;
    } on SignatureFailure {
      rethrow;
    } on AtrustException catch (e) {
      throw SignatureFailure(e.sentence);
    } catch (_) {
      throw const SignatureFailure(_failed);
    }
  }

  /// Fehlt die Sitzung und lässt sie sich nicht holen (außer bei Ablehnung
  /// oder ohne Zugangsdaten), beginnt eine Anmeldung im Hintergrund für den
  /// nächsten Bon.
  Future<AtrustSession> _session() async {
    try {
      return await _keeper.session();
    } on AtrustException catch (e) {
      if (e.problem != AtrustProblem.rejected &&
          e.problem != AtrustProblem.noCredentials) {
        _keeper.warmUp();
      }
      rethrow;
    } catch (_) {
      _keeper.warmUp();
      rethrow;
    }
  }

  @override
  String toString() => 'OnlineSignatureUnit';
}
