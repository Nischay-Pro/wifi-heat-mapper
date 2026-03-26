package com.nischaypro.mobile

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.TimeUnit

class IperfForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action != ACTION_RUN_MEASUREMENT) {
            stopSelf(startId)
            return START_NOT_STICKY
        }

        val host = intent.getStringExtra(EXTRA_HOST)
        val port = intent.getIntExtra(EXTRA_PORT, 5201)
        val tcpDownload = intent.getBooleanExtra(EXTRA_TCP_DOWNLOAD, false)
        val tcpUpload = intent.getBooleanExtra(EXTRA_TCP_UPLOAD, false)
        val udpDownload = intent.getBooleanExtra(EXTRA_UDP_DOWNLOAD, false)
        val udpUpload = intent.getBooleanExtra(EXTRA_UDP_UPLOAD, false)

        if (host.isNullOrBlank()) {
            IperfServiceBridge.finishWithError("Enter a valid local iperf3 server host or IP address.")
            stopSelf(startId)
            return START_NOT_STICKY
        }

        Thread {
            try {
                val executable = prepareIperfExecutable(applicationContext)
                val configuredModes =
                    listOfNotNull(
                        if (tcpDownload) IperfMode("tcp", true) else null,
                        if (tcpUpload) IperfMode("tcp", false) else null,
                        if (udpDownload) IperfMode("udp", true) else null,
                        if (udpUpload) IperfMode("udp", false) else null,
                    )

                if (configuredModes.isEmpty()) {
                    IperfServiceBridge.finishWithSuccess(emptyList())
                    return@Thread
                }

                IperfServiceBridge.publishProgress(0.0, "Preparing local test")
                val results = mutableListOf<Map<String, Any?>>()

                configuredModes.forEachIndexed { index, mode ->
                    IperfServiceBridge.publishProgress(
                        index.toDouble() / configuredModes.size.toDouble(),
                        mode.label,
                    )

                    val stdout = runMode(
                        executablePath = executable.absolutePath,
                        host = host,
                        port = port,
                        mode = mode,
                    )

                    results +=
                        mapOf(
                            "protocol" to mode.protocol,
                            "download" to mode.download,
                            "json" to stdout,
                        )

                    IperfServiceBridge.publishProgress(
                        (index + 1).toDouble() / configuredModes.size.toDouble(),
                        mode.label,
                    )
                }

                IperfServiceBridge.finishWithSuccess(results)
            } catch (error: Throwable) {
                IperfServiceBridge.finishWithError(error.message ?: error.toString())
            } finally {
                stopSelf(startId)
            }
        }.start()

        return START_NOT_STICKY
    }

    private fun runMode(
        executablePath: String,
        host: String,
        port: Int,
        mode: IperfMode,
    ): String {
        val arguments =
            mutableListOf(
                executablePath,
                "-c",
                host,
                "-p",
                port.toString(),
                "-t",
                MODE_DURATION_SECONDS.toString(),
                "-J",
                "--forceflush",
            )

        if (mode.download) {
            arguments += "-R"
        }
        if (mode.protocol == "udp") {
            arguments += "-u"
        }

        val process = ProcessBuilder(arguments).start()
        val stdoutThread = StreamReader(process.inputStream)
        val stderrThread = StreamReader(process.errorStream)
        stdoutThread.start()
        stderrThread.start()

        val finished = process.waitFor(MODE_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        if (!finished) {
            process.destroyForcibly()
            throw IllegalStateException(
                "iperf3 ${mode.label} timed out after $MODE_TIMEOUT_SECONDS seconds.",
            )
        }

        stdoutThread.join()
        stderrThread.join()

        val stdoutText = stdoutThread.content.trim()
        val stderrText = stderrThread.content.trim()
        if (process.exitValue() != 0) {
            throw IllegalStateException(
                when {
                    stderrText.isNotEmpty() -> stderrText
                    stdoutText.isNotEmpty() -> stdoutText
                    else -> "iperf3 exited with code ${process.exitValue()}."
                },
            )
        }

        if (stdoutText.isEmpty()) {
            throw IllegalStateException("iperf3 did not return JSON output.")
        }

        return stdoutText
    }

    data class IperfMode(val protocol: String, val download: Boolean) {
        val label: String
            get() {
                val direction = if (download) "download" else "upload"
                val transport = if (protocol == "tcp") "TCP" else "UDP"
                return "$transport $direction"
            }
    }

    class StreamReader(private val stream: java.io.InputStream) : Thread() {
        @Volatile var content: String = ""
            private set

        override fun run() {
            content = stream.bufferedReader().use { it.readText() }
        }
    }

    companion object {
        private const val ACTION_RUN_MEASUREMENT = "run_measurement"
        private const val EXTRA_HOST = "host"
        private const val EXTRA_PORT = "port"
        private const val EXTRA_TCP_DOWNLOAD = "tcp_download"
        private const val EXTRA_TCP_UPLOAD = "tcp_upload"
        private const val EXTRA_UDP_DOWNLOAD = "udp_download"
        private const val EXTRA_UDP_UPLOAD = "udp_upload"
        private const val MODE_DURATION_SECONDS = 10
        private const val MODE_TIMEOUT_SECONDS = 45L
        fun startMeasurement(
            context: Context,
            host: String,
            port: Int,
            tcpDownload: Boolean,
            tcpUpload: Boolean,
            udpDownload: Boolean,
            udpUpload: Boolean,
            result: MethodChannel.Result,
        ) {
            IperfServiceBridge.start(result)
            val intent =
                Intent(context, IperfForegroundService::class.java).apply {
                    action = ACTION_RUN_MEASUREMENT
                    putExtra(EXTRA_HOST, host)
                    putExtra(EXTRA_PORT, port)
                    putExtra(EXTRA_TCP_DOWNLOAD, tcpDownload)
                    putExtra(EXTRA_TCP_UPLOAD, tcpUpload)
                    putExtra(EXTRA_UDP_DOWNLOAD, udpDownload)
                    putExtra(EXTRA_UDP_UPLOAD, udpUpload)
                }
            context.startService(intent)
        }

        fun prepareIperfExecutable(context: Context): File {
            val source = File(context.applicationInfo.nativeLibraryDir, "libiperf_bundle.so")
            require(source.exists()) {
                "Bundled iperf binary is missing from nativeLibraryDir. " +
                    "Check android:extractNativeLibs/useLegacyPackaging."
            }
            return source
        }
    }
}
