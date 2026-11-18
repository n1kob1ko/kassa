package io.github.n1kob1ko.kassa

import android.app.Application
import com.sumup.reader.sdk.api.SumUpState

class KassaApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // SumUp verlangt das, bevor irgendein Aufruf des SDK kommt.
        SumUpState.init(this)
    }
}
