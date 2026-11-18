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
// Methoden: listUsb, listBluetooth, send, status. Fehlercodes: unreachable,
// no_permission, timeout. Alles Blockierende läuft auf dem Arbeits-Thread,
// jede Antwort geht genau einmal auf dem Haupt-Thread zurück.
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
                "listUsb" -> runOnWorker(result) { listUsb() }
                "listBluetooth" -> withBluetoothPermission(result) {
                    runOnWorker(result) { listBluetooth() }
                }
                "send" -> {
                    val kind = call.argument<String>("kind")
                    val address = call.argument<String>("address")
                    val bytes = call.argument<ByteArray>("bytes")
                    if (address == null || bytes == null) {
                        result.error(UNREACHABLE)
                        return
                    }
                    when (kind) {
                        "usb" -> withUsbPermission(result, address) { device ->
                            runOnWorker(result) { usbSend(device, bytes); null }
                        }
                        "bluetooth" -> withBluetoothPermission(result) {
                            runOnWorker(result) { bluetoothSend(address, bytes); null }
                        }
                        else -> result.error(UNREACHABLE)
                    }
                }
                "status" -> {
                    val kind = call.argument<String>("kind")
                    val address = call.argument<String>("address")
                    val request = call.argument<ByteArray>("request")
                    if (address == null || request == null) {
                        result.success(null)
                        return
                    }
                    // Die Zustandsfrage fragt nie nach einer Erlaubnis; das
                    // erledigt das folgende Senden.
                    runOnWorker(result) {
                        try {
                            when (kind) {
                                "usb" -> usbStatus(address, request)
                                "bluetooth" -> bluetoothStatus(address, request)
                                else -> null
                            }
                        } catch (e: Exception) {
                            null
                        }
                    }
                }
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

    // ---------------------------------------------------------------- Arbeit

    private fun runOnWorker(result: OnceResult, job: () -> Any?) {
        try {
            worker.execute {
                try {
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

    // Ruft [then] mit dem Gerät, sobald die Erlaubnis da ist.
    private fun withUsbPermission(result: OnceResult, address: String, then: (UsbDevice) -> Unit) {
        val manager = usbManager
        val device = findUsbDevice(address)
        if (manager == null || device == null) {
            result.error(UNREACHABLE)
            return
        }
        if (manager.hasPermission(device)) {
            then(device)
            return
        }
        if (question != null) {
            result.error(NO_PERMISSION)
            return
        }
        val ask = UsbQuestion(result, device, then)
        question = ask
        ask.start(manager)
    }

    private fun usbSend(device: UsbDevice, bytes: ByteArray) {
        withUsbConnection(device) { connection, intf ->
            val out = bulkEndpoint(intf, UsbConstants.USB_DIR_OUT) ?: throw ChannelError(UNREACHABLE)
            var offset = 0
            while (offset < bytes.size) {
                val length = minOf(USB_CHUNK, bytes.size - offset)
                val started = SystemClock.elapsedRealtime()
                val written = connection.bulkTransfer(out, bytes, offset, length, USB_SEND_LIMIT_MS)
                if (written <= 0) {
                    // -1 heißt Zeitgrenze oder Fehler; die verstrichene Zeit
                    // unterscheidet die beiden.
                    val elapsed = SystemClock.elapsedRealtime() - started
                    throw ChannelError(if (elapsed >= USB_SEND_LIMIT_MS - 100) TIMEOUT else UNREACHABLE)
                }
                offset += written
            }
        }
    }

    private fun usbStatus(address: String, request: ByteArray): Int? {
        val manager = usbManager ?: return null
        val device = findUsbDevice(address) ?: return null
        if (!manager.hasPermission(device)) return null
        return withUsbConnection(device) { connection, intf ->
            val out = bulkEndpoint(intf, UsbConstants.USB_DIR_OUT)
            val input = bulkEndpoint(intf, UsbConstants.USB_DIR_IN)
            if (out == null || input == null) return@withUsbConnection null
            if (connection.bulkTransfer(out, request, request.size, STATUS_LIMIT_MS) < request.size) {
                return@withUsbConnection null
            }
            val answer = ByteArray(maxOf(1, input.maxPacketSize))
            val read = connection.bulkTransfer(input, answer, answer.size, STATUS_LIMIT_MS)
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

    // Ab Android 12 braucht jeder Zugriff BLUETOOTH_CONNECT; darunter reicht
    // die Erlaubnis BLUETOOTH aus dem Manifest.
    private fun withBluetoothPermission(result: OnceResult, then: () -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            hasPermission(Manifest.permission.BLUETOOTH_CONNECT)
        ) {
            then()
            return
        }
        if (question != null) {
            result.error(NO_PERMISSION)
            return
        }
        val ask = BluetoothQuestion(result, then)
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

    private fun bluetoothSend(address: String, bytes: ByteArray) {
        val timedOut = AtomicBoolean(false)
        withBluetoothSocket(address, timedOut) { socket ->
            try {
                val out = socket.outputStream
                out.write(bytes)
                out.flush()
            } catch (e: IOException) {
                throw ChannelError(if (timedOut.get()) TIMEOUT else UNREACHABLE)
            }
        }
    }

    private fun bluetoothStatus(address: String, request: ByteArray): Int? {
        val timedOut = AtomicBoolean(false)
        return withBluetoothSocket(address, timedOut) { socket ->
            // Neue Zeitgrenze von 1 Sekunde für Frage und Antwort.
            val limit = timer.schedule({ closeQuietly(socket) }, STATUS_LIMIT_MS.toLong(), TimeUnit.MILLISECONDS)
            try {
                socket.outputStream.write(request)
                socket.outputStream.flush()
                val answer = socket.inputStream.read()
                if (answer < 0) null else answer and 0xFF
            } catch (e: IOException) {
                null
            } finally {
                limit.cancel(false)
            }
        }
    }

    // Verbindet über SPP; [block] läuft auf dem verbundenen Socket. Verbinden
    // und [block] zusammen haben 5 Sekunden, dann schließt der Zeitgeber den
    // Socket. Der Socket wird in jedem Fall geschlossen.
    private fun <T> withBluetoothSocket(
        address: String,
        timedOut: AtomicBoolean,
        block: (BluetoothSocket) -> T,
    ): T {
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
        val socket = device.createRfcommSocketToServiceRecord(SPP)
        var limit: ScheduledFuture<*>? = null
        try {
            limit = timer.schedule({
                timedOut.set(true)
                closeQuietly(socket)
            }, BLUETOOTH_LIMIT_MS, TimeUnit.MILLISECONDS)
            try {
                socket.connect()
            } catch (e: IOException) {
                throw ChannelError(if (timedOut.get()) TIMEOUT else UNREACHABLE)
            }
            return block(socket)
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
                if (granted) proceed() else denied()
            } catch (e: Exception) {
                denied()
            }
        }

        protected open fun cleanUp() {}
        protected abstract fun proceed()
        protected abstract fun denied()
    }

    private inner class BluetoothQuestion(
        private val result: OnceResult,
        private val then: () -> Unit,
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

        override fun proceed() = then()
        override fun denied() = result.error(NO_PERMISSION)
    }

    private inner class UsbQuestion(
        private val result: OnceResult,
        private val device: UsbDevice,
        private val then: (UsbDevice) -> Unit,
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

        override fun proceed() = then(device)
        override fun denied() = result.error(NO_PERMISSION)
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
        private const val BLUETOOTH_LIMIT_MS = 5000L
        private const val PERMISSION_LIMIT_MS = 30_000L

        private val SPP: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }
}
