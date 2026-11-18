package io.github.n1kob1ko.kassa

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var printerChannel: PrinterChannel? = null
    private var sumUpChannel: SumUpChannel? = null
    private var internetChannel: InternetChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        disposeChannels()
        printerChannel = PrinterChannel(this, messenger)
        sumUpChannel = SumUpChannel(this, messenger)
        internetChannel = InternetChannel(applicationContext, messenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        disposeChannels()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun disposeChannels() {
        printerChannel?.dispose()
        printerChannel = null
        sumUpChannel?.dispose()
        sumUpChannel = null
        internetChannel?.dispose()
        internetChannel = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        printerChannel?.onRequestPermissionsResult(requestCode, grantResults)
    }

    // Die Bildschirme von SumUp antworten hier (FlutterActivity kennt keine
    // Result-Verträge).
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        sumUpChannel?.onActivityResult(requestCode, data)
    }
}
