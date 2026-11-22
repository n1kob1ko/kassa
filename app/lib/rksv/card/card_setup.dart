// Der Schritt "Karte und PIN": die Probe-Unterschrift von "Karte prüfen" mit
// der PIN vom Zahlenfeld und, wenn sie gelingt, die PIN im geschützten
// Speicher, zusammen mit Kartenart und Kartennummer genau dieser Karte
// (Plan C3).
//
// Schutz der Karte: Die PIN geht nur über [CardCheck.sign] zur Karte, also
// mit dem PIN-Wächter von "Karte prüfen". Sie lebt nur als Parameter von
// [CardSetup.signAndStore] und, beim Probelauf mit der gespeicherten PIN,
// als lokaler Wert in [CardSetup.signWithStored]; sie steht in keinem Feld,
// keinem Rückgabewert und keinem Text.

import '../rksv_secrets.dart';
import 'card_check.dart';
import 'card_facts.dart';
import 'card_signer.dart';

class CardSetup {
  CardSetup({
    required this._check,
    required this._secrets,
    required this._signer,
  });

  /// Der Satz, wenn der geschützte Speicher die PIN nicht nimmt.
  static const storeProblem =
      'Das Tablet konnte die PIN nicht sicher speichern.';

  final CardCheck _check;
  final RksvSecrets _secrets;
  final CardSigner _signer;

  /// Probe-Unterschrift mit [pin] ([CardCheck.sign]). Ist Zeile 5 danach
  /// grün, speichert es die PIN für Art und Nummer dieser Karte, liest sie
  /// zur Kontrolle zurück, sagt es dem Halter ([CardSigner.pinChanged]) und
  /// gibt `null` zurück. Nimmt der Speicher sie nicht: [storeProblem]. Ohne
  /// grüne Zeile 5: `''` (der Bildschirm zeigt dann die Zeile).
  Future<String?> signAndStore(String pin) async {
    await _check.sign(pin);
    final facts = _check.facts;
    if (facts == null) return '';
    try {
      await _secrets
          .writeCardPin(
            CardPin(kind: facts.kind, numberHex: facts.numberHex, pin: pin),
          )
          .timeout(CardSigner.storageLimit);
      final back = await _secrets.cardPin().timeout(CardSigner.storageLimit);
      if (back == null ||
          back.kind != facts.kind ||
          back.numberHex != facts.numberHex ||
          back.pin != pin) {
        return storeProblem;
      }
    } catch (_) {
      return storeProblem;
    }
    _signer.pinChanged();
    return null;
  }

  /// Für die Karte von [facts] ist eine PIN gespeichert, und sie ist nicht
  /// abgelehnt (keine Ablehnung, weniger als zwei VERIFY ohne Antwort). Ein
  /// Speicher, der nicht liest, zählt als nicht gespeichert.
  Future<bool> storedFor(CardFacts facts) async =>
      (await _validPin(facts.kind, facts.numberHex)) != null;

  /// Wie [storedFor] für die Karte, die der letzte Lauf gelesen hat
  /// ([CardCheck.readCard]); ohne gelesene Karte `false`.
  Future<bool> storedForReadCard() async {
    final read = _check.readCard;
    if (read == null) return false;
    return (await _validPin(read.kind, read.numberHex)) != null;
  }

  /// Probe-Unterschrift mit der gespeicherten PIN, ohne Zahlenfeld, damit
  /// Zeile 5 grün wird und es [CardCheck.facts] gibt. Nur wenn die PIN für
  /// die gelesene Karte gespeichert und nicht abgelehnt ist und der Wächter
  /// es erlaubt; sonst geht nichts zur Karte. `null`: Zeile 5 ist grün.
  /// `''`: nicht. Hat der Versuch die Karte einen Versuch der PIN gekostet
  /// (VERIFY abgelehnt oder ohne Antwort,
  /// [CardCheck.lastSignCountedAgainstPin]), gilt die gespeicherte PIN als
  /// abgelehnt (Plan C4), bis der Chef sie neu eingibt. Ein Fehler von Leser
  /// oder Karte vor dem VERIFY oder nach einem angenommenen VERIFY ändert
  /// ihren Stand nicht: Eine laufende Kette mit Karte signiert weiter.
  Future<String?> signWithStored() async {
    final read = _check.readCard;
    if (read == null || !_check.state.canSign) return '';
    final stored = await _validPin(read.kind, read.numberHex);
    if (stored == null) return '';
    await _check.sign(stored.pin);
    if (_check.facts != null) return null;
    if (_check.lastSignCountedAgainstPin) {
      try {
        await _secrets
            .writeCardPinStatus(const CardPinStatus(rejected: true))
            .timeout(CardSigner.storageLimit);
      } catch (_) {
        // Der Halter prüft den Stand selbst; der Wächter zählt den Versuch.
      }
    }
    return '';
  }

  /// Die gespeicherte PIN, wenn sie zu [kind] und [numberHex] gehört und
  /// nicht abgelehnt ist; sonst `null`, auch wenn der Speicher nicht liest.
  Future<CardPin?> _validPin(String kind, String numberHex) async {
    try {
      final pin = await _secrets.cardPin().timeout(CardSigner.storageLimit);
      if (pin == null || pin.kind != kind || pin.numberHex != numberHex) {
        return null;
      }
      final status = await _secrets.cardPinStatus().timeout(
        CardSigner.storageLimit,
      );
      if (status.rejected || status.unanswered >= 2) return null;
      return pin;
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 'CardSetup';
}
