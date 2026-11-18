package io.github.n1kob1ko.kassa

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

// Meldet über den Kanal `kassa/internet`, ob das Standardnetz Internet hat
// (NET_CAPABILITY_VALIDATED): gleich beim Anmelden und danach bei jeder
// Änderung, jeweils true oder false. Alles läuft auf dem Haupt-Thread.
class InternetChannel(
    context: Context,
    messenger: BinaryMessenger,
) : EventChannel.StreamHandler {

    private val channel = EventChannel(messenger, CHANNEL)
    private val main = Handler(Looper.getMainLooper())
    private val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager

    private var sink: EventChannel.EventSink? = null
    private var callback: ConnectivityManager.NetworkCallback? = null
    private var last: Boolean? = null

    init {
        channel.setStreamHandler(this)
    }

    fun dispose() {
        channel.setStreamHandler(null)
        stop()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        stop()
        sink = events
        val manager = manager
        if (manager == null) {
            report(false)
            return
        }
        report(manager.getNetworkCapabilities(manager.activeNetwork)?.let(::hasInternet) ?: false)
        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
                report(hasInternet(capabilities))
            }

            override fun onLost(network: Network) {
                report(false)
            }
        }
        try {
            manager.registerDefaultNetworkCallback(cb, main)
            callback = cb
        } catch (e: Exception) {
            // Ohne Rückruf bleibt der erste Stand stehen.
        }
    }

    override fun onCancel(arguments: Any?) = stop()

    private fun hasInternet(capabilities: NetworkCapabilities) =
        capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)

    // Meldet nur Änderungen.
    private fun report(online: Boolean) {
        if (online == last) return
        last = online
        try {
            sink?.success(online)
        } catch (e: Exception) {
            // Engine schon weg.
        }
    }

    private fun stop() {
        callback?.let { cb -> runCatching { manager?.unregisterNetworkCallback(cb) } }
        callback = null
        sink = null
        last = null
    }

    companion object {
        const val CHANNEL = "kassa/internet"
    }
}
