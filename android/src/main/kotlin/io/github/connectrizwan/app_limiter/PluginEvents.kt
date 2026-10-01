package io.github.connectrizwan.app_limiter

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/** Forwards native events (from the plugin or the service) to the `app_limiter/events` channel. */
internal object PluginEvents {
    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }

    @Volatile
    var sink: EventChannel.EventSink? = null

    fun emit(name: String, payload: Map<String, Any?> = emptyMap()) {
        if (sink == null) return
        val event = mapOf(
            "name" to name,
            "payload" to payload,
            "timestamp" to System.currentTimeMillis() / 1000,
        )
        mainHandler.post { sink?.success(event) }
    }
}
