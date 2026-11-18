package io.github.n1kob1ko.kassa

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import com.sumup.checkout.core.models.TransactionInfo
import com.sumup.merchant.reader.api.SumUpAPI
import com.sumup.merchant.reader.api.SumUpLogin
import com.sumup.merchant.reader.api.SumUpPayment
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.math.BigDecimal

// Kartenzahlung mit dem SumUp-SDK für den Kanal `kassa/sumup`.
// Methoden: status, login, logout, openReaderPage, prepare, pay.
// Fehlercodes: busy (zu dieser Anfrage wartet schon eine Antwort),
// not_configured (kein Schlüssel im Build), invalid, failed (nichts wurde
// begonnen), unknown (die Antwort von SumUp war nicht lesbar).
// login, openReaderPage und pay öffnen Bildschirme von SumUp; ihre Antwort
// kommt erst mit MainActivity.onActivityResult. Alles läuft auf dem
// Haupt-Thread. Der Schlüssel wird nie ausgegeben oder protokolliert.
class SumUpChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)

    // Je Anfrage-Nummer höchstens eine wartende Antwort.
    private val waiting = mutableMapOf<Int, MethodChannel.Result>()

    private val affiliateKey get() = BuildConfig.SUMUP_AFFILIATE_KEY

    private val configured get() = affiliateKey.isNotEmpty()

    init {
        channel.setMethodCallHandler(this)
    }

    // Die Engine ist weg: wartende Antworten können nicht mehr ankommen.
    fun dispose() {
        channel.setMethodCallHandler(null)
        waiting.clear()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "status" -> result.success(status())
                "login" -> whenConfigured(result) {
                    open(REQUEST_LOGIN, result) {
                        SumUpAPI.openLoginActivity(
                            activity,
                            SumUpLogin.builder(affiliateKey).build(),
                            REQUEST_LOGIN,
                        )
                    }
                }
                "logout" -> {
                    SumUpAPI.logout()
                    result.success(null)
                }
                "openReaderPage" -> whenConfigured(result) {
                    open(REQUEST_READER, result) {
                        SumUpAPI.openCardReaderPage(activity, REQUEST_READER)
                    }
                }
                "prepare" -> {
                    // Weckt den Leser; ein Fehler hier hält keinen Verkauf auf.
                    if (configured) runCatching { SumUpAPI.prepareForCheckout() }
                    result.success(null)
                }
                "pay" -> whenConfigured(result) { pay(call, result) }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error(FAILED, e.message, null)
        }
    }

    // Von MainActivity weitergereicht; fremde Anfrage-Nummern bleiben liegen.
    fun onActivityResult(requestCode: Int, data: Intent?) {
        val result = waiting.remove(requestCode) ?: return
        val answer = try {
            val extras = data?.extras
            when (requestCode) {
                REQUEST_PAY -> extras?.let { paymentAnswer(it) }
                REQUEST_LOGIN -> extras
                    ?.takeIf { it.containsKey(SumUpAPI.Response.RESULT_CODE) }
                    ?.getInt(SumUpAPI.Response.RESULT_CODE)
                else -> null
            }
        } catch (e: Exception) {
            // Die Antwort von SumUp ist nicht lesbar: Ob bezahlt wurde, ist offen.
            try {
                result.error(UNKNOWN, null, null)
            } catch (e: Exception) {
                // Engine schon weg.
            }
            return
        }
        try {
            result.success(answer)
        } catch (e: Exception) {
            // Engine schon weg.
        }
    }

    // ------------------------------------------------------------ Aufrufe

    private fun status(): Map<String, Any?> {
        val loggedIn = configured && runCatching { SumUpAPI.isLoggedIn() }.getOrDefault(false)
        val merchant = if (loggedIn) {
            runCatching { SumUpAPI.getCurrentMerchant()?.merchantCode }.getOrNull()
        } else {
            null
        }
        return mapOf(
            "configured" to configured,
            "loggedIn" to loggedIn,
            "merchant" to merchant,
        )
    }

    private fun pay(call: MethodCall, result: MethodChannel.Result) {
        val paymentId = call.argument<String>("paymentId")
        val amountCents = (call.argument<Any>("amountCents") as? Number)?.toLong()
        val title = call.argument<String>("title")
        if (paymentId == null || amountCents == null || title == null) {
            result.error(INVALID, null, null)
            return
        }
        open(REQUEST_PAY, result) {
            val payment = SumUpPayment.builder()
                .total(BigDecimal.valueOf(amountCents, 2))
                .currency(SumUpPayment.Currency.EUR)
                .title(title)
                .foreignTransactionId(paymentId)
                .skipSuccessScreen()
                // Bei unklarem Stand fragt SumUp alle 2 s nach, höchstens
                // 60 s lang; die Zurück-Taste ist dabei gesperrt.
                .configureRetryPolicy(2000, 60000, true)
                .build()
            SumUpAPI.checkout(activity, payment, REQUEST_PAY)
        }
    }

    // Antwort auf pay, aus den Angaben in SumUpAPI.Response. Ohne
    // Ergebniscode (Bildschirm ohne Ergebnis geschlossen): null.
    private fun paymentAnswer(extras: Bundle): Map<String, Any?>? {
        if (!extras.containsKey(SumUpAPI.Response.RESULT_CODE)) return null
        val info = runCatching { transactionInfo(extras) }.getOrNull()
        val card = info?.card
        return mapOf(
            "resultCode" to extras.getInt(SumUpAPI.Response.RESULT_CODE),
            "message" to extras.getString(SumUpAPI.Response.MESSAGE),
            "txCode" to (extras.getString(SumUpAPI.Response.TX_CODE) ?: info?.transactionCode),
            "cardType" to card?.type,
            "last4" to card?.last4Digits,
        )
    }

    private fun transactionInfo(extras: Bundle): TransactionInfo? =
        // Die Fassung mit Klasse ist erst ab Android 14 verlässlich.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            extras.getParcelable(SumUpAPI.Response.TX_INFO, TransactionInfo::class.java)
        } else {
            @Suppress("DEPRECATION")
            extras.getParcelable(SumUpAPI.Response.TX_INFO)
        }

    // ------------------------------------------------------------ Hilfen

    private fun whenConfigured(result: MethodChannel.Result, action: () -> Unit) {
        if (configured) action() else result.error(NOT_CONFIGURED, null, null)
    }

    // Merkt sich die Antwort zur Anfrage-Nummer und öffnet den Bildschirm.
    private fun open(requestCode: Int, result: MethodChannel.Result, start: () -> Unit) {
        if (waiting.containsKey(requestCode)) {
            result.error(BUSY, null, null)
            return
        }
        waiting[requestCode] = result
        try {
            start()
        } catch (e: Exception) {
            waiting.remove(requestCode)
            result.error(FAILED, e.message, null)
        }
    }

    companion object {
        const val CHANNEL = "kassa/sumup"

        // Neben PrinterChannel.BLUETOOTH_REQUEST_CODE (4711).
        const val REQUEST_LOGIN = 4721
        const val REQUEST_READER = 4722
        const val REQUEST_PAY = 4723

        private const val BUSY = "busy"
        private const val NOT_CONFIGURED = "not_configured"
        private const val INVALID = "invalid"
        private const val FAILED = "failed"
        private const val UNKNOWN = "unknown"
    }
}
