package com.nischaypro.mobile

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

object IperfServiceBridge {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingResult: MethodChannel.Result? = null
    private var eventSink: EventChannel.EventSink? = null

    fun start(result: MethodChannel.Result) {
        pendingResult = result
    }

    fun attachEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun publishProgress(progress: Double, label: String) {
        mainHandler.post {
            eventSink?.success(
                mapOf(
                    "progress" to progress,
                    "label" to label,
                ),
            )
        }
    }

    fun finishWithSuccess(results: List<Map<String, Any?>>) {
        mainHandler.post {
            pendingResult?.success(results)
            pendingResult = null
        }
    }

    fun finishWithError(message: String) {
        mainHandler.post {
            pendingResult?.error("iperf_measurement_failed", message, null)
            pendingResult = null
        }
    }
}
