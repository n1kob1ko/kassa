package io.github.n1kob1ko.kassa

import android.annotation.SuppressLint
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

// USB-Kartenleser (Klasse 0x0B, CCID) für den Kanal `kassa/cardreader`.
// Methoden: list, open, exchange, close, info. Fehlercodes: not_found,
// no_permission, not_ccid, busy (open), not_open, timeout, io (exchange).
// Der Kanal kennt keine Nachrichtentypen und verändert keine Bytes: exchange
// schreibt, was Dart schickt, und liest genau eine vollständige Nachricht.
// Alles Blockierende läuft auf dem Arbeits-Thread dieses Kanals, jede Antwort
// geht genau einmal auf dem Haupt-Thread zurück. Der Drucker-Kanal bleibt
// unberührt (K3); Antwort-Hilfe und Erlaubnis-Frage stehen hier ein zweites
// Mal.
class CardReaderChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)
    private val main = Handler(Looper.getMainLooper())

    // Ein Thread für alles am Leser: zwei Aufrufe (auch zwei exchange
    // gleichzeitig) laufen nacheinander, nie gleichzeitig am Gerät.
    private val worker: ExecutorService = Executors.newSingleThreadExecutor()

    private val usbManager: UsbManager? =
        activity.getSystemService(Context.USB_SERVICE) as? UsbManager

    // Der offene Leser; höchstens einer. Nur auf dem Arbeits-Thread gelesen
    // und geschrieben.
    private var reader: OpenReader? = null

    // Höchstens eine offene Erlaubnis-Frage; nur auf dem Haupt-Thread.
    private var question: UsbQuestion? = null

    init {
        channel.setMethodCallHandler(this)
    }

    // Ein laufender Aufruf endet spätestens mit seiner Zeitgrenze; danach gibt
    // der Arbeits-Thread den Leser frei. Seine Antwort geht ins Leere.
    fun dispose() {
        channel.setMethodCallHandler(null)
        question?.answer(false)
        question = null
        try {
            worker.execute { closeReader() }
        } catch (e: Exception) {
            // Ausführer schon beendet.
        }
        worker.shutdown()
    }

    override fun onMethodCall(call: MethodCall, rawResult: MethodChannel.Result) {
        val result = OnceResult(rawResult, main)
        try {
            when (call.method) {
                "list" -> list(result)
                "open" -> open(result, call.argument<String>("address"))
                "exchange" -> exchange(result, call)
                "close" -> close(result)
                "info" -> result.success(info())
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error(fallbackCode(call.method))
        }
    }

    // ------------------------------------------------------------ Aufrufe

    // Kennt keinen Fehler: ohne USB oder bei einem Fehler eine leere Liste.
    private fun list(result: OnceResult) {
        runOnWorker(result, IO) {
            try {
                listDevices()
            } catch (e: Exception) {
                emptyList<Map<String, Any>>()
            }
        }
    }

    // Ein schon offener Leser wird zuerst freigegeben, auch wenn das neue
    // Öffnen scheitert: danach ist der neue oder gar keiner offen. Die
    // Schnittstelle wird vor der Erlaubnis geprüft, damit für ein Gerät ohne
    // Kartenleser (etwa den Drucker) nie ein Dialog erscheint.
    private fun open(result: OnceResult, address: String?) {
        enqueueClose()
        val manager = usbManager
        val device = address?.let { findDevice(it) }
        if (manager == null || device == null) {
            result.error(NOT_FOUND)
            return
        }
        if (readerInterface(device) == null) {
            result.error(NOT_CCID)
            return
        }
        askUsb(manager, device) { granted ->
            if (!granted) {
                result.error(NO_PERMISSION)
            } else {
                runOnWorker(result, BUSY) { openReader(manager, device) }
            }
        }
    }

    private fun exchange(result: OnceResult, call: MethodCall) {
        val started = SystemClock.elapsedRealtime()
        val out = call.argument<ByteArray>("out")
        val timeoutMs = (call.argument<Any>("timeoutMs") as? Number)?.toLong()
        if (timeoutMs == null) {
            result.error(IO)
            return
        }
        // Die Zeitgrenze gilt ab der Ankunft, auch das Warten auf einen
        // vorherigen Aufruf am Arbeits-Thread zählt mit.
        val deadline = started + timeoutMs.coerceAtLeast(0L)
        runOnWorker(result, IO) {
            val open = reader ?: throw ChannelError(NOT_OPEN)
            if (out != null) write(open, out, started, deadline)
            readMessage(open, started, deadline)
        }
    }

    // Gelingt immer. Eine noch offene Frage nach der USB-Erlaubnis gilt als
    // abgelehnt: das wartende open antwortet no_permission und öffnet nichts.
    // Kam die Erlaubnis schon, steht dessen openReader vor diesem closeReader
    // auf demselben Thread und wird gleich danach wieder geschlossen.
    private fun close(result: OnceResult) {
        question?.answer(false)
        try {
            worker.execute {
                closeReader()
                result.success(null)
            }
        } catch (e: Exception) {
            // Ausführer schon beendet: dann ist auch nichts mehr offen.
            result.success(null)
        }
    }

    private fun info(): Map<String, String> = mapOf(
        "model" to "${Build.MANUFACTURER} ${Build.MODEL}",
        "android" to "${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
    )

    // ---------------------------------------------------------------- Arbeit

    // Führt [job] auf dem Arbeits-Thread aus. Ein unerwarteter Fehler wird
    // [fallback], damit jede Antwort einen der bekannten Codes trägt.
    private fun runOnWorker(result: OnceResult, fallback: String, job: () -> Any?) {
        try {
            worker.execute {
                try {
                    result.success(job())
                } catch (e: ChannelError) {
                    result.error(e.code, e.detail)
                } catch (e: Exception) {
                    result.error(fallback)
                }
            }
        } catch (e: Exception) {
            // Ausführer schon beendet.
            result.error(fallback)
        }
    }

    private fun fallbackCode(method: String) = when (method) {
        "open" -> BUSY
        else -> IO
    }

    private fun enqueueClose() {
        try {
            worker.execute { closeReader() }
        } catch (e: Exception) {
            // Ausführer schon beendet.
        }
    }

    // ------------------------------------------------------------------ USB

    private fun listDevices(): List<Map<String, Any>> {
        val manager = usbManager ?: return emptyList()
        return manager.deviceList.values.map { device ->
            val name = try {
                device.productName?.takeIf { it.isNotBlank() }
            } catch (e: Exception) {
                null
            }
            val granted = try {
                manager.hasPermission(device)
            } catch (e: Exception) {
                false
            }
            mapOf(
                "address" to usbAddress(device),
                "name" to (name ?: ""),
                "vendorId" to device.vendorId,
                "productId" to device.productId,
                "deviceClass" to device.deviceClass,
                "granted" to granted,
                "interfaces" to (0 until device.interfaceCount).map { i ->
                    val intf = device.getInterface(i)
                    mapOf(
                        "klass" to intf.interfaceClass,
                        "subclass" to intf.interfaceSubclass,
                        "protocol" to intf.interfaceProtocol,
                    )
                },
            )
        }
    }

    private fun usbAddress(device: UsbDevice) = "${device.vendorId}:${device.productId}"

    // Sind zwei gleiche Geräte angesteckt, gilt das erste.
    private fun findDevice(address: String): UsbDevice? =
        usbManager?.deviceList?.values?.firstOrNull { usbAddress(it) == address }

    // Die erste Schnittstelle der Klasse 0x0B mit je einem Bulk-Endpunkt
    // hinein und hinaus. Den Interrupt-Endpunkt (Karte gesteckt/gezogen)
    // braucht die Kassa nicht: sie fragt den Leser selbst.
    private fun readerInterface(device: UsbDevice): ReaderInterface? {
        for (i in 0 until device.interfaceCount) {
            val intf = device.getInterface(i)
            if (intf.interfaceClass != UsbConstants.USB_CLASS_CSCID) continue
            val input = bulkEndpoint(intf, UsbConstants.USB_DIR_IN) ?: continue
            val output = bulkEndpoint(intf, UsbConstants.USB_DIR_OUT) ?: continue
            return ReaderInterface(intf, input, output)
        }
        return null
    }

    private fun bulkEndpoint(intf: UsbInterface, direction: Int): UsbEndpoint? {
        for (i in 0 until intf.endpointCount) {
            val e = intf.getEndpoint(i)
            if (e.type == UsbConstants.USB_ENDPOINT_XFER_BULK && e.direction == direction) return e
        }
        return null
    }

    // Nur auf dem Arbeits-Thread. Der vorige Leser ist schon zu (enqueueClose
    // lief vorher auf demselben Thread); hier zur Sicherheit noch einmal.
    private fun openReader(manager: UsbManager, device: UsbDevice): Map<String, Any> {
        closeReader()
        // Zwischen der Erlaubnis und jetzt abgezogen?
        if (manager.deviceList.values.none { it.deviceName == device.deviceName }) {
            throw ChannelError(NOT_FOUND)
        }
        val found = readerInterface(device) ?: throw ChannelError(NOT_CCID)
        val opened: UsbDeviceConnection? = try {
            manager.openDevice(device)
        } catch (e: SecurityException) {
            throw ChannelError(NO_PERMISSION)
        }
        // null: das Gerät lässt sich gerade nicht öffnen.
        val connection = opened ?: throw ChannelError(BUSY)
        try {
            // true: ein Treiber von Android, der die Schnittstelle hält, wird
            // abgelöst. false heißt, eine andere App hat sie.
            if (!connection.claimInterface(found.intf, true)) throw ChannelError(BUSY)
            val descriptors = connection.rawDescriptors ?: throw ChannelError(BUSY)
            reader = OpenReader(connection, found)
            return mapOf("descriptors" to descriptors)
        } catch (e: Exception) {
            releaseQuietly(connection, found.intf)
            throw e
        }
    }

    // Nur auf dem Arbeits-Thread; schluckt jeden Fehler (Gerät abgezogen).
    private fun closeReader() {
        val open = reader ?: return
        reader = null
        releaseQuietly(open.connection, open.found.intf)
    }

    private fun releaseQuietly(connection: UsbDeviceConnection, intf: UsbInterface) {
        try {
            connection.releaseInterface(intf)
        } catch (e: Exception) {
            // Gerät schon abgezogen.
        }
        try {
            connection.close()
        } catch (e: Exception) {
            // schon zu
        }
    }

    private fun remainingMs(deadline: Long) = deadline - SystemClock.elapsedRealtime()

    // Zeitgrenze für einen einzelnen bulkTransfer: die verbleibende Zeit,
    // mindestens 1 ms (0 hieße bei Android "ohne Ende"). Ist nichts mehr
    // übrig, ist der Aufruf vorbei.
    private fun transferLimit(step: String, started: Long, done: Int, deadline: Long): Int {
        val left = remainingMs(deadline)
        if (left <= 0) throw ChannelError(TIMEOUT, detail(step, started, done, null))
        return left.coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
    }

    // Für den Bericht: welcher Schritt, nach wie vielen ms seit Ankunft des
    // Aufrufs, wie viele Bytes bis dahin übertragen waren, und was
    // bulkTransfer zurückgab. Nie die Bytes selbst.
    private fun detail(step: String, started: Long, done: Int, raw: Int?): String =
        "$step, ${SystemClock.elapsedRealtime() - started} ms, $done Bytes, " +
            "Rückgabe ${raw?.toString() ?: "-"}"


    // Vor Android 9 bewegt ein bulkTransfer höchstens 16 384 Bytes; mehr
    // scheitert dort. Die Zahl ist ein Vielfaches jeder Paketgröße, ein Teil
    // einer langen Antwort endet also immer an einer Paketgrenze.
    private fun maxTransfer(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) Int.MAX_VALUE else OLD_MAX_TRANSFER

    // bulkTransfer meldet Zeitgrenze und Fehler gleich (-1). Ist die Zeit des
    // Aufrufs (fast) um, war es die Zeitgrenze; kommt -1 früher, etwa weil der
    // Leser abgezogen wurde, ist es ein Fehler.
    private fun failure(step: String, started: Long, done: Int, raw: Int, deadline: Long): ChannelError =
        ChannelError(
            if (remainingMs(deadline) <= TIMEOUT_SLACK_MS) TIMEOUT else IO,
            detail(step, started, done, raw),
        )

    private fun write(open: OpenReader, bytes: ByteArray, started: Long, deadline: Long) {
        val endpoint = open.found.output
        var offset = 0
        while (offset < bytes.size) {
            val length = minOf(bytes.size - offset, maxTransfer())
            val written = open.connection.bulkTransfer(
                endpoint, bytes, offset, length, transferLimit(WRITE, started, offset, deadline),
            )
            if (written <= 0) throw failure(WRITE, started, offset, written, deadline)
            offset += written
        }
        // Endet die Nachricht genau an einer Paketgrenze, weiß der Leser erst
        // durch ein leeres Paket, dass sie vollständig ist.
        val packet = endpoint.maxPacketSize
        if (bytes.isNotEmpty() && packet > 0 && bytes.size % packet == 0) {
            val zero = open.connection.bulkTransfer(
                endpoint, ByteArray(0), 0, transferLimit(WRITE, started, offset, deadline),
            )
            if (zero < 0) throw failure(WRITE, started, offset, zero, deadline)
        }
    }

    // Liest, bis eine vollständige Nachricht da ist: 10 Bytes Kopf, die Bytes
    // 1 bis 4 nennen die Länge der Daten (little endian). Ein einzelner
    // bulkTransfer kann die ganze Nachricht bringen oder nur einen Teil.
    private fun readMessage(open: OpenReader, started: Long, deadline: Long): ByteArray {
        val endpoint = open.found.input
        val buffer = ByteArray(READ_BUFFER)
        var total = 0
        var expected = -1
        while (expected < 0 || total < expected) {
            if (total >= buffer.size) throw ChannelError(IO)
            val length = minOf(buffer.size - total, maxTransfer())
            val read = open.connection.bulkTransfer(
                endpoint, buffer, total, length, transferLimit(READ, started, total, deadline),
            )
            if (read < 0) throw failure(READ, started, total, read, deadline)
            total += read
            if (expected < 0 && total >= HEADER) {
                val length = (buffer[1].toLong() and 0xFF) or
                    ((buffer[2].toLong() and 0xFF) shl 8) or
                    ((buffer[3].toLong() and 0xFF) shl 16) or
                    ((buffer[4].toLong() and 0xFF) shl 24)
                if (length > MAX_DATA) throw ChannelError(IO)
                expected = HEADER + length.toInt()
            }
        }
        // Mehr als eine Nachricht kommt bei CCID nie auf einmal; was nach dem
        // Ende steht, gehört nicht dazu.
        return buffer.copyOf(expected)
    }

    // Nur auf dem Haupt-Thread. [answer] bekommt true, wenn die Kassa das
    // Gerät verwenden darf; false bei Ablehnung, nach 60 Sekunden ohne
    // Antwort oder wenn schon eine andere Frage offen ist.
    private fun askUsb(manager: UsbManager, device: UsbDevice, answer: (Boolean) -> Unit) {
        if (manager.hasPermission(device)) {
            answer(true)
            return
        }
        if (question != null) {
            answer(false)
            return
        }
        val ask = UsbQuestion(device, answer)
        question = ask
        ask.start(manager)
    }

    // --------------------------------------------------------- Erlaubnisse

    // Eine Frage nach der USB-Erlaubnis. Wie im Drucker-Kanal, aber mit
    // eigener Aktion und eigener Anfrage-Nummer, damit sich die beiden
    // Antworten nie vermischen.
    private inner class UsbQuestion(
        private val device: UsbDevice,
        private val then: (Boolean) -> Unit,
    ) {
        private var answered = false
        private var registered = false

        // Schließt jemand den Dialog, ohne zu antworten, kommt manchmal keine
        // Nachricht: nach 60 Sekunden gilt die Frage als abgelehnt.
        private val giveUp = Runnable { answer(false) }

        private val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action != usbAction) return
                val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false) ||
                    usbManager?.hasPermission(device) == true
                answer(granted)
            }
        }

        private val usbAction get() = "${activity.packageName}.CARD_READER_PERMISSION"

        // Unter Android 13 gibt es die Angabe RECEIVER_NOT_EXPORTED nicht.
        @SuppressLint("UnspecifiedRegisterReceiverFlag")
        fun start(manager: UsbManager) {
            main.postDelayed(giveUp, PERMISSION_LIMIT_MS)
            try {
                val filter = IntentFilter(usbAction)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    activity.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
                } else {
                    activity.registerReceiver(receiver, filter)
                }
                registered = true
                // Ab Android 12 muss die Absicht veränderbar sein, damit das
                // System das Gerät und die Antwort eintragen kann; das Paket
                // ist gesetzt, damit nur die Kassa sie empfängt.
                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_MUTABLE
                } else {
                    0
                }
                val intent = Intent(usbAction).setPackage(activity.packageName)
                val pending = PendingIntent.getBroadcast(activity, PERMISSION_REQUEST_CODE, intent, flags)
                manager.requestPermission(device, pending)
            } catch (e: Exception) {
                answer(false)
            }
        }

        // Nur auf dem Haupt-Thread; wirkt nur beim ersten Aufruf.
        fun answer(granted: Boolean) {
            if (answered) return
            answered = true
            main.removeCallbacks(giveUp)
            if (question === this) question = null
            if (registered) {
                registered = false
                try {
                    activity.unregisterReceiver(receiver)
                } catch (e: Exception) {
                    // nicht mehr angemeldet
                }
            }
            try {
                then(granted)
            } catch (e: Exception) {
                // Die Antwort an Dart fängt OnceResult ab; hier nichts mehr.
            }
        }
    }

    // ------------------------------------------------------------ Hilfen

    private class ReaderInterface(
        val intf: UsbInterface,
        val input: UsbEndpoint,
        val output: UsbEndpoint,
    )

    private class OpenReader(
        val connection: UsbDeviceConnection,
        val found: ReaderInterface,
    )

    // [detail] geht als message des Fehlers an Dart; nie Bytes der Nachricht.
    private class ChannelError(val code: String, val detail: String? = null) : Exception(code)

    // Gibt die Antwort genau einmal und immer auf dem Haupt-Thread zurück.
    private class OnceResult(
        private val result: MethodChannel.Result,
        private val main: Handler,
    ) {
        private val done = AtomicBoolean(false)

        fun success(value: Any?) = deliver { result.success(value) }

        fun error(code: String, detail: String? = null) = deliver { result.error(code, detail, null) }

        fun notImplemented() = deliver { result.notImplemented() }

        private fun deliver(action: () -> Unit) {
            if (!done.compareAndSet(false, true)) return
            val run = Runnable {
                try {
                    action()
                } catch (e: Exception) {
                    // Engine schon weg.
                }
            }
            if (Looper.myLooper() == Looper.getMainLooper()) run.run() else main.post(run)
        }
    }

    companion object {
        const val CHANNEL = "kassa/cardreader"

        private const val NOT_FOUND = "not_found"
        private const val NO_PERMISSION = "no_permission"
        private const val NOT_CCID = "not_ccid"
        private const val BUSY = "busy"
        private const val NOT_OPEN = "not_open"
        private const val TIMEOUT = "timeout"
        private const val IO = "io"

        // Die Schritte eines exchange in der Angabe zum Fehler.
        private const val WRITE = "write"
        private const val READ = "read"

        // Kopf einer Nachricht des Lesers und die größte Nachricht, die in
        // den Lesepuffer passt.
        private const val HEADER = 10
        private const val READ_BUFFER = 65_556
        private const val MAX_DATA = 65_546L
        private const val OLD_MAX_TRANSFER = 16_384

        // Wie knapp vor dem Ende ein -1 noch als Zeitgrenze zählt.
        private const val TIMEOUT_SLACK_MS = 100L

        private const val PERMISSION_LIMIT_MS = 60_000L

        // Eine andere Nummer als der Drucker-Kanal (0).
        private const val PERMISSION_REQUEST_CODE = 1
    }
}
