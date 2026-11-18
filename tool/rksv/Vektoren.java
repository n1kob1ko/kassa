// Erzeugt Vergleichswerte für den Rechenkern der Kassa mit dem Mustercode des
// Finanzministeriums (BMF-RKSV-Technik/at-registrierkassen-mustercode).
// Die Kassa rechnet diese Werte in Dart nach; die Tests vergleichen beide.
// Aufruf: siehe tool/rksv/vektoren.sh. Die Bibliotheken des Mustercodes
// liegen nicht im Repo.

import at.asitplus.regkassen.common.RKSuite;
import at.asitplus.regkassen.common.util.CashBoxUtils;
import at.asitplus.regkassen.common.util.CryptoUtil;
import at.asitplus.regkassen.core.base.receiptdata.ReceiptRepresentationForSignature;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.text.SimpleDateFormat;
import javax.crypto.SecretKey;

public class Vektoren {
  static final String KEY = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=";
  static final String BOX = "BSPIMB01";

  static String q(String s) {
    return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
  }

  static String counter(String receiptId, long cents) throws Exception {
    byte[] hash = MessageDigest.getInstance("SHA-256")
        .digest((BOX + receiptId).getBytes(StandardCharsets.UTF_8));
    byte[] iv = new byte[16];
    System.arraycopy(hash, 0, iv, 0, 16);
    SecretKey key = CryptoUtil.convertBase64KeyToSecretKey(KEY);
    return CryptoUtil.encryptCTR(iv, cents, key, 8);
  }

  static String chain(String input) throws Exception {
    byte[] hash = MessageDigest.getInstance("SHA-256").digest(input.getBytes(StandardCharsets.UTF_8));
    byte[] first = new byte[8];
    System.arraycopy(hash, 0, first, 0, 8);
    return CashBoxUtils.base64Encode(first, false);
  }

  static String text(String receiptId, String date, double[] sums, String enc, String serial,
      String chain) throws Exception {
    ReceiptRepresentationForSignature r = new ReceiptRepresentationForSignature();
    r.setCashBoxID(BOX);
    r.setReceiptIdentifier(receiptId);
    r.setReceiptDateAndTime(new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss").parse(date));
    r.setSumTaxSetNormal(sums[0]);
    r.setSumTaxSetErmaessigt1(sums[1]);
    r.setSumTaxSetErmaessigt2(sums[2]);
    r.setSumTaxSetNull(sums[3]);
    r.setSumTaxSetBesonders(sums[4]);
    r.setEncryptedTurnoverValue(enc);
    r.setSignatureCertificateSerialNumber(serial);
    r.setSignatureValuePreviousReceipt(chain);
    return r.getDataToBeSigned(RKSuite.R1_AT1);
  }

  public static void main(String[] args) throws Exception {
    StringBuilder o = new StringBuilder("{\n");
    o.append(" \"aesKeyBase64\": ").append(q(KEY)).append(",\n");
    o.append(" \"cashBoxId\": ").append(q(BOX)).append(",\n");

    o.append(" \"counters\": [\n");
    Object[][] counters = {
        {"1", 0L}, {"2", 1290L}, {"3", 1L}, {"17", 123456789L}, {"18", -500L},
        {"4711", 99999999999L}, {"5", -1L},
    };
    for (int i = 0; i < counters.length; i++) {
      String id = (String) counters[i][0];
      long c = (Long) counters[i][1];
      o.append("  {\"receiptId\": ").append(q(id)).append(", \"cents\": ").append(c)
          .append(", \"encrypted\": ").append(q(counter(id, c))).append("}")
          .append(i + 1 < counters.length ? ",\n" : "\n");
    }
    o.append(" ],\n");

    String header = "eyJhbGciOiJFUzI1NiJ9";
    String sto = CashBoxUtils.base64Encode("STO".getBytes(), false);
    String chain0 = chain(BOX);
    String t1 = text("1", "2026-11-18T13:05:09", new double[] {0, 0, 0, 0, 0}, counter("1", 0),
        "1a2b3c", chain0);
    // Feste, erfundene 64 Byte als "Signatur": Es geht hier nur um die Form.
    byte[] fake = new byte[64];
    for (int i = 0; i < 64; i++) fake[i] = (byte) (i * 3 + 1);
    String jws1 = header + "." + CashBoxUtils.base64Encode(t1.getBytes(StandardCharsets.UTF_8), true)
        + "." + CashBoxUtils.base64Encode(fake, true);
    String chain1 = chain(jws1);
    String t2 = text("2", "2026-11-18T13:07:41", new double[] {12.90, 4.50, 0, 0.25, 0},
        counter("2", 1765), "1a2b3c", chain1);
    String jws2Damaged = header + "."
        + CashBoxUtils.base64Encode(t2.getBytes(StandardCharsets.UTF_8), true) + "."
        + CashBoxUtils.base64Encode("Sicherheitseinrichtung ausgefallen".getBytes(), true);
    String chain2 = chain(jws2Damaged);
    String t3 = text("3", "2026-12-01T00:00:00", new double[] {-12.90, -4.50, 0, -0.25, 0}, sto,
        "1a2b3c", chain2);
    String t4 = text("4", "2027-01-02T09:00:00", new double[] {999.99, 0, 0.05, 0, -0.01},
        counter("4", 100003), "1a2b3c", chain2);

    o.append(" \"chainFromCashBoxId\": ").append(q(chain0)).append(",\n");
    o.append(" \"stornoMarker\": ").append(q(sto)).append(",\n");
    o.append(" \"text1\": ").append(q(t1)).append(",\n");
    o.append(" \"fakeSignatureBase64\": ").append(q(CashBoxUtils.base64Encode(fake, false))).append(",\n");
    o.append(" \"jws1\": ").append(q(jws1)).append(",\n");
    o.append(" \"qr1\": ").append(q(CashBoxUtils.getQRCodeRepresentationFromJWSCompactRepresentation(jws1))).append(",\n");
    o.append(" \"chainAfterJws1\": ").append(q(chain1)).append(",\n");
    o.append(" \"text2\": ").append(q(t2)).append(",\n");
    o.append(" \"jws2Damaged\": ").append(q(jws2Damaged)).append(",\n");
    o.append(" \"qr2Damaged\": ").append(q(CashBoxUtils.getQRCodeRepresentationFromJWSCompactRepresentation(jws2Damaged))).append(",\n");
    o.append(" \"damagedDetected\": ").append(CashBoxUtils.checkReceiptForDamagedSigatureCreationDevice(jws2Damaged)).append(",\n");
    o.append(" \"chainAfterJws2\": ").append(q(chain2)).append(",\n");
    o.append(" \"text3Storno\": ").append(q(t3)).append(",\n");
    o.append(" \"text4\": ").append(q(t4)).append(",\n");

    // DER-Signatur in die Form R|S, wie sie die Chipkarte in Stufe 2 braucht.
    byte[] der = java.util.HexFormat.of().parseHex(
        "3045022001020304050607080910111213141516171819202122232425262728293031320221"
            + "00a1a2a3a4a5a6a7a8a9b0b1b2b3b4b5b6b7b8b9c0c1c2c3c4c5c6c7c8c9d0d1d2");
    o.append(" \"derSignatureHex\": ").append(q(java.util.HexFormat.of().formatHex(der))).append(",\n");
    o.append(" \"concatSignatureBase64\": ").append(q(CashBoxUtils.base64Encode(CryptoUtil.convertDEREncodedSignatureToJWSConcatenated(der), false))).append("\n");
    o.append("}\n");
    System.out.print(o);
  }
}
