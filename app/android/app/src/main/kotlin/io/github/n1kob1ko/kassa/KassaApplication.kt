package io.github.n1kob1ko.kassa

import android.app.Application
import com.sumup.reader.sdk.api.SumUpState

class KassaApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // SumUp verlangt das, bevor irgendein Aufruf des SDK kommt. Scheitert
        // es, startet die Kassa trotzdem; die Kartenzahlung gilt dann als
        // nicht eingerichtet (SumUpChannel fragt sumUpReady).
        sumUpReady = try {
            SumUpState.init(this)
            true
        } catch (e: Throwable) {
            false
        }
    }

    companion object {
        // Ob SumUpState.init geklappt hat. Nur in onCreate geschrieben, vor
        // jeder Activity.
        @Volatile
        var sumUpReady = false
            private set
    }
}
