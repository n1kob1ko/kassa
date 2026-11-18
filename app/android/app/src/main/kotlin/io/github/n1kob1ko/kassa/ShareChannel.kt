package io.github.n1kob1ko.kassa

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// Das Teilen-Fenster von Android für den Kanal `kassa/share`. Methode text
// mit subject und text: öffnet die Auswahl der Apps (ACTION_SEND, text/plain)
// und antwortet true, oder false, wenn Android kein Ziel hat. Alles läuft auf
// dem Haupt-Thread, nichts blockiert.
class ShareChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val answer = when (call.method) {
            "text" -> try {
                shareText(call)
            } catch (e: Exception) {
                false
            }
            else -> {
                result.notImplemented()
                return
            }
        }
        result.success(answer)
    }

    private fun shareText(call: MethodCall): Boolean {
        val subject = call.argument<String>("subject") ?: return false
        val text = call.argument<String>("text") ?: return false
        val send = Intent(Intent.ACTION_SEND)
            .setType("text/plain")
            .putExtra(Intent.EXTRA_SUBJECT, subject)
            .putExtra(Intent.EXTRA_TEXT, text)
        // Ab Android 11 sieht die Kassa andere Apps nur, weil das Manifest
        // ACTION_SEND mit text/plain unter <queries> nennt.
        if (send.resolveActivity(activity.packageManager) == null) return false
        return try {
            activity.startActivity(Intent.createChooser(send, null))
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    companion object {
        const val CHANNEL = "kassa/share"
    }
}
