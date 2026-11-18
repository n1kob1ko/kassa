package io.github.n1kob1ko.kassa

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.app.PendingIntent
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
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
import java.io.IOException
import java.util.UUID
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

// Bondrucker über USB und Bluetooth für den Kanal `kassa/printer`.
// Methoden: listUsb, listBluetooth, requestAccess, send, status. Fehlercodes:
// unreachable, no_permission, timeout. Alles Blockierende läuft auf dem
// Arbeits-Thread, jede Antwort geht genau einmal auf dem Haupt-Thread zurück.
// send und status bringen budgetMs mit: so lange darf der Aufruf ab seiner
// Ankunft dauern. Danach wird nichts mehr zum Drucker geschrieben.
@SuppressLint("MissingPermission") // Erlaubnisse werden vor jedem Aufruf geprüft.
class PrinterChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)
    private val main = Handler(Looper.getMainLooper())

    // Ein Thread für alle Ein- und Ausgaben: zwei Aufrufe greifen nie
    // gleichzeitig auf denselben Drucker zu.
    private val worker: ExecutorService = Executors.newSingleThreadExecutor()

    // Schließt hängende Bluetooth-Sockets nach der Zeitgrenze.
    private val timer: ScheduledExecutorService = Executors.newSingleThreadScheduledExecutor()

    private val usbManager: UsbManager? =
        activity.getSystemService(Context.USB_SERVICE) as? UsbManager

    // Höchstens eine offene Erlaubnis-Frage (USB oder Bluetooth); nur auf dem
    // Haupt-Thread gelesen und geschrieben.
    private var question: PermissionQuestion? = null

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        question?.answer(false)
        question = null
        worker.shutdown()
        timer.shutdown()
    }

    override fun onMethodCall(call: MethodCall, rawResult: MethodChannel.Result) {
        val result = OnceResult(rawResult, main)
        try {
            when (call.method) {
                "listUsb" -> runOnWorker(result, null) { listUsb() }
                "listBluetooth" -> askBluetooth { granted ->
                    if (granted) runOnWorker(result, null) { listBluetooth() } else result.error(NO_PERMISSION)
                }
                "requestAccess" -> requestAccess(
                    result,
                    call.argument<String>("kind"),
                    call.argument<String>("address"),
                )
                "send" -> send(result, call)
                "status" -> status(result, call)
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error(UNREACHABLE)
        }
    }

    // Von MainActivity weitergereicht.
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != BLUETOOTH_REQUEST_CODE) return
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        val open = question as? BluetoothQuestion ?: return
        open.answer(granted)
    }

    // ------------------------------------------------------------ Aufrufe

    // Ende des Aufrufs auf der Uhr elapsedRealtime: Ankunft plus budgetMs,
    // ohne Angabe plus 5 Sekunden.
    private fun deadlineOf(call: MethodCall): Long {
        val budget = (call.argument<Any>("budgetMs") as? Number)?.toLong() ?: DEFAULT_BUDGET_MS
        return SystemClock.elapsedRealtime() + budget.coerceAtLeast(0L)
    }

    private fun remainingMs(deadline: Long) = deadline - SystemClock.elapsedRealtime()

    private fun isLate(deadline: Long) = remainingMs(deadline) <= 0

    // Vor jedem Schreiben: nach dem Ende geht nichts mehr zum Drucker.
    private fun checkDeadline(deadline: Long) {
        if (isLate(deadline)) throw ChannelError(TIMEOUT)
    }

    private fun send(result: OnceResult, call: MethodCall) {
        val deadline = deadlineOf(call)
        val kind = call.argument<String>("kind")
        val address = call.argument<String>("address")
        val bytes = call.argument<ByteArray>("bytes")
        if (address == null || bytes == null) {
            result.error(UNREACHABLE)
            return
        }
        when (kind) {
            "usb" -> {
                val device = findUsbDevice(address)
                if (device == null) {
                    result.error(UNREACHABLE)
                    return
                }
                askUsb(device) { granted ->
                    when {
                        !granted -> result.error(NO_PERMISSION)
                        isLate(deadline) -> result.error(TIMEOUT)
                        else -> runOnWorker(result, deadline) { usbSend(device, bytes, deadline); null }
                    }
                }
            }
            "bluetooth" -> askBluetooth { granted ->
                when {
                    !granted -> result.error(NO_PERMISSION)
                    isLate(deadline) -> result.error(TIMEOUT)
                    else -> runOnWorker(result, deadline) { bluetoothSend(address, bytes, deadline); null }
                }
            }
            else -> result.error(UNREACHABLE)
        }
    }

    // Die Zustandsfrage fragt nie nach einer Erlaubnis (das erledigen
    // requestAccess und das Senden) und scheitert nie: keine Antwort ist null.
    // Bluetooth fragt gar nicht, damit ein Druck nur eine Verbindung braucht.
    private fun status(result: OnceResult, call: MethodCall) {
        val deadline = deadlineOf(call)
        val address = call.argument<String>("address")
        val request = call.argument<ByteArray>("request")
        if (call.argument<String>("kind") != "usb" || address == null || request == null) {
            result.success(null)
            return
        }
        runOnWorker(result, null) {
            try {
                if (isLate(deadline)) null else usbStatus(address, request, deadline)
            } catch (e: Exception) {
                null
            }
        }
    }

    // Fragt nach der Erlaubnis, ohne etwas zu senden; Antwort true/false.
    private fun requestAccess(result: OnceResult, kind: String?, address: String?) {
        when (kind) {
            "usb" -> {
                val device = address?.let { findUsbDevice(it) }
                if (device == null) result.success(false) else askUsb(device) { result.success(it) }
            }
            "bluetooth" -> askBluetooth { result.success(it) }
            else -> result.success(false)
        }
    }

    // ---------------------------------------------------------------- Arbeit

    // Führt [job] auf dem Arbeits-Thread aus. Mit [deadline]: ist die Zeit
    // abgelaufen, bevor der Job drankommt, läuft er nicht und die Antwort ist
    // timeout.
    private fun runOnWorker(result: OnceResult, deadline: Long?, job: () -> Any?) {
        try {
            worker.execute {
                try {
                    if (deadline != null) checkDeadline(deadline)
                    result.success(job())
                } catch (e: ChannelError) {
                    result.error(e.code)
                } catch (e: SecurityException) {
                    result.error(NO_PERMISSION)
                } catch (e: Exception) {
                    result.error(UNREACHABLE)
                }
            }
        } catch (e: Exception) {
            // Ausführer schon beendet.
            result.error(UNREACHABLE)
        }
    }

    // ------------------------------------------------------------------ USB

    private fun listUsb(): List<Map<String, String>> {
        val manager = usbManager ?: return emptyList()
        return manager.deviceList.values
            .filter { printerInterface(it) != null }
            .map { device ->
                val name = try {
                    device.productName?.takeIf { it.isNotBlank() }
                        ?: device.manufacturerName?.takeIf { it.isNotBlank() }
                } catch (e: Exception) {
                    null
                }
                mapOf(
                    "name" to (name ?: "USB-Drucker"),
                    "address" to usbAddress(device),
                )
            }
    }

    private fun usbAddress(device: UsbDevice) = "${device.vendorId}:${device.productId}"

    private fun findUsbDevice(address: String): UsbDevice? {
        val manager = usbManager ?: return null
        return manager.deviceList.values.firstOrNull {
            usbAddress(it) == address && printerInterface(it) != null
        }
    }

    private fun printerInterface(device: UsbDevice): UsbInterface? {
        for (i in 0 until device.interfaceCount) {
            val intf = device.getInterface(i)
            if (intf.interfaceClass == UsbConstants.USB_CLASS_PRINTER) return intf
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

    // Nur auf dem Haupt-Thread. [answer] bekommt true, wenn die Kassa das
    // Gerät verwenden darf; false bei Ablehnung, nach 30 Sekunden ohne
    // Antwort oder wenn schon eine andere Frage offen ist.
    private fun askUsb(device: UsbDevice, answer: (Boolean) -> Unit) {
        val manager = usbManager
        if (manager == null) {
            answer(false)
            return
        }
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

    // Schickt in Stücken von 4096 Bytes; vor jedem Stück wird die Frist
    // geprüft. Ein mitten im Bon abgebrochener Druck meldet ebenfalls timeout.
    private fun usbSend(device: UsbDevice, bytes: ByteArray, deadline: Long) {
        withUsbConnection(device) { connection, intf ->
            val out = bulkEndpoint(intf, UsbConstants.USB_DIR_OUT) ?: throw ChannelError(UNREACHABLE)
            var offset = 0
            while (offset < bytes.size) {
                checkDeadline(deadline)
                val length = minOf(USB_CHUNK, bytes.size - offset)
                val limit = limitMs(deadline, USB_SEND_LIMIT_MS)
                val started = SystemClock.elapsedRealtime()
                val written = connection.bulkTransfer(out, bytes, offset, length, limit)
                if (written <= 0) {
                    // -1 heißt Zeitgrenze oder Fehler; die verstrichene Zeit
                    // unterscheidet die beiden.
                    val elapsed = SystemClock.elapsedRealtime() - started
                    throw ChannelError(if (elapsed >= limit - 100) TIMEOUT else UNREACHABLE)
                }
                offset += written
            }
        }
    }

    // Die kleinere von [cap] und der verbleibenden Zeit, mindestens 1 ms.
    private fun limitMs(deadline: Long, cap: Int): Int =
        remainingMs(deadline).coerceIn(1L, cap.toLong()).toInt()

    private fun usbStatus(address: String, request: ByteArray, deadline: Long): Int? {
        val manager = usbManager ?: return null
        val device = findUsbDevice(address) ?: return null
        if (!manager.hasPermission(device)) return null
        return withUsbConnection(device) { connection, intf ->
            val out = bulkEndpoint(intf, UsbConstants.USB_DIR_OUT)
            val input = bulkEndpoint(intf, UsbConstants.USB_DIR_IN)
            if (out == null || input == null || isLate(deadline)) return@withUsbConnection null
            if (connection.bulkTransfer(out, request, request.size, limitMs(deadline, STATUS_LIMIT_MS)) < request.size) {
                return@withUsbConnection null
            }
            val answer = ByteArray(maxOf(1, input.maxPacketSize))
            val read = connection.bulkTransfer(input, answer, answer.size, limitMs(deadline, STATUS_LIMIT_MS))
            if (read >= 1) answer[0].toInt() and 0xFF else null
        }
    }

    // Öffnet das Gerät, beansprucht die Drucker-Schnittstelle und gibt beides
    // in jedem Fall wieder frei.
    private fun <T> withUsbConnection(
        device: UsbDevice,
        block: (UsbDeviceConnection, UsbInterface) -> T,
    ): T {
        val manager = usbManager ?: throw ChannelError(UNREACHABLE)
        val intf = printerInterface(device) ?: throw ChannelError(UNREACHABLE)
        val connection = manager.openDevice(device) ?: throw ChannelError(UNREACHABLE)
        try {
            if (!connection.claimInterface(intf, true)) throw ChannelError(UNREACHABLE)
            try {
                return block(connection, intf)
            } finally {
                try {
                    connection.releaseInterface(intf)
                } catch (e: Exception) {
                    // Gerät schon abgezogen.
                }
            }
        } finally {
            connection.close()
        }
    }

    // ------------------------------------------------------------ Bluetooth

    private fun bluetoothAdapter(): BluetoothAdapter? {
        val manager = activity.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        return manager?.adapter
    }

    private fun hasPermission(permission: String) =
        activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    // Nur auf dem Haupt-Thread. Ab Android 12 braucht jeder Zugriff
    // BLUETOOTH_CONNECT; darunter reicht die Erlaubnis BLUETOOTH aus dem
    // Manifest. [answer] wie bei [askUsb].
    private fun askBluetooth(answer: (Boolean) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            hasPermission(Manifest.permission.BLUETOOTH_CONNECT)
        ) {
            answer(true)
            return
        }
        if (question != null) {
            answer(false)
            return
        }
        val ask = BluetoothQuestion(answer)
        question = ask
        ask.start()
    }

    private fun listBluetooth(): List<Map<String, String>> {
        val adapter = bluetoothAdapter() ?: return emptyList()
        if (!adapter.isEnabled) return emptyList()
        val devices = adapter.bondedDevices ?: return emptyList()
        return devices.map { device ->
            val name = try {
                device.name?.takeIf { it.isNotBlank() }
            } catch (e: Exception) {
                null
            }
            mapOf("name" to (name ?: device.address), "address" to device.address)
        }
    }

    // Verbindet über SPP und schreibt. Verbinden und Schreiben zusammen haben
    // höchstens 5 Sekunden und nie mehr als die Frist, dann schließt der
    // Zeitgeber den Socket. Ist die Frist nach dem Verbinden abgelaufen, geht
    // nichts zum Drucker. Der Socket wird in jedem Fall geschlossen.
    private fun bluetoothSend(address: String, bytes: ByteArray, deadline: Long) {
        val adapter = bluetoothAdapter()
        if (adapter == null || !adapter.isEnabled) throw ChannelError(UNREACHABLE)
        if (!BluetoothAdapter.checkBluetoothAddress(address)) throw ChannelError(UNREACHABLE)
        val device = adapter.getRemoteDevice(address)
        val scanPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            Manifest.permission.BLUETOOTH_SCAN
        } else {
            Manifest.permission.BLUETOOTH_ADMIN
        }
        if (hasPermission(scanPermission)) {
            try {
                adapter.cancelDiscovery()
            } catch (e: Exception) {
                // Nicht nötig fürs Drucken, nur schneller.
            }
        }
        checkDeadline(deadline)
        val socket = device.createRfcommSocketToServiceRecord(SPP)
        val timedOut = AtomicBoolean(false)
        var limit: ScheduledFuture<*>? = null
        try {
            limit = timer.schedule({
                timedOut.set(true)
                closeQuietly(socket)
            }, limitMs(deadline, BLUETOOTH_LIMIT_MS).toLong(), TimeUnit.MILLISECONDS)
            try {
                socket.connect()
            } catch (e: IOException) {
                throw ChannelError(if (timedOut.get()) TIMEOUT else UNREACHABLE)
            }
            if (timedOut.get()) throw ChannelError(TIMEOUT)
            checkDeadline(deadline)
            try {
                val out = socket.outputStream
                out.write(bytes)
                out.flush()
            } catch (e: IOException) {
                throw ChannelError(if (timedOut.get()) TIMEOUT else UNREACHABLE)
            }
        } finally {
            limit?.cancel(false)
            closeQuietly(socket)
        }
    }

    private fun closeQuietly(socket: BluetoothSocket) {
        try {
            socket.close()
        } catch (e: Exception) {
            // schon zu
        }
    }

    // --------------------------------------------------------- Erlaubnisse

    private abstract inner class PermissionQuestion {
        private var answered = false

        // Ohne Antwort binnen 30 Sekunden gilt die Frage als abgelehnt.
        private val giveUp = Runnable { answer(false) }

        protected fun startLimit() {
            main.postDelayed(giveUp, PERMISSION_LIMIT_MS)
        }

        // Nur auf dem Haupt-Thread; wirkt nur beim ersten Aufruf.
        fun answer(granted: Boolean) {
            if (answered) return
            answered = true
            main.removeCallbacks(giveUp)
            if (question === this) question = null
            cleanUp()
            try {
                deliver(granted)
            } catch (e: Exception) {
                // Die Antwort an Dart fängt OnceResult ab; hier nichts mehr.
            }
        }

        protected open fun cleanUp() {}
        protected abstract fun deliver(granted: Boolean)
    }

    private inner class BluetoothQuestion(
        private val then: (Boolean) -> Unit,
    ) : PermissionQuestion() {
        fun start() {
            startLimit()
            try {
                activity.requestPermissions(
                    arrayOf(Manifest.permission.BLUETOOTH_CONNECT),
                    BLUETOOTH_REQUEST_CODE,
                )
            } catch (e: Exception) {
                answer(false)
            }
        }

        override fun deliver(granted: Boolean) = then(granted)
    }

    private inner class UsbQuestion(
        private val device: UsbDevice,
        private val then: (Boolean) -> Unit,
    ) : PermissionQuestion() {
        private var registered = false

        private val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action != usbAction) return
                val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false) ||
                    usbManager?.hasPermission(device) == true
                answer(granted)
            }
        }

        private val usbAction get() = "${activity.packageName}.USB_PERMISSION"

        // Unter Android 13 gibt es die Angabe RECEIVER_NOT_EXPORTED nicht.
        @SuppressLint("UnspecifiedRegisterReceiverFlag")
        fun start(manager: UsbManager) {
            startLimit()
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
                val pending = PendingIntent.getBroadcast(activity, 0, intent, flags)
                manager.requestPermission(device, pending)
            } catch (e: Exception) {
                answer(false)
            }
        }

        override fun cleanUp() {
            if (!registered) return
            registered = false
            try {
                activity.unregisterReceiver(receiver)
            } catch (e: Exception) {
                // nicht mehr angemeldet
            }
        }

        override fun deliver(granted: Boolean) = then(granted)
    }

    // ------------------------------------------------------------ Hilfen

    private class ChannelError(val code: String) : Exception(code)

    // Gibt die Antwort genau einmal und immer auf dem Haupt-Thread zurück.
    private class OnceResult(
        private val result: MethodChannel.Result,
        private val main: Handler,
    ) {
        private val done = AtomicBoolean(false)

        fun success(value: Any?) = deliver { result.success(value) }

        fun error(code: String) = deliver { result.error(code, null, null) }

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
        const val CHANNEL = "kassa/printer"
        const val BLUETOOTH_REQUEST_CODE = 4711

        private const val UNREACHABLE = "unreachable"
        private const val NO_PERMISSION = "no_permission"
        private const val TIMEOUT = "timeout"

        private const val USB_CHUNK = 4096
        private const val USB_SEND_LIMIT_MS = 5000
        private const val STATUS_LIMIT_MS = 1000
        private const val BLUETOOTH_LIMIT_MS = 5000
        private const val DEFAULT_BUDGET_MS = 5000L
        private const val PERMISSION_LIMIT_MS = 30_000L

        private val SPP: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }
}
