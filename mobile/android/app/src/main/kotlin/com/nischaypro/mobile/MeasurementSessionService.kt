package com.nischaypro.mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class MeasurementSessionService : Service() {
    private val notificationManager by lazy {
        getSystemService(NotificationManager::class.java)
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                ensureChannel()
                acquireWakeLock()
                startForeground(
                    NOTIFICATION_ID,
                    buildNotification(
                        contentText = intent.getStringExtra(EXTRA_LABEL) ?: "Running measurement",
                        progress = 0,
                    ),
                )
            }
            ACTION_UPDATE -> {
                val progress = intent.getIntExtra(EXTRA_PROGRESS, 0).coerceIn(0, 100)
                val label = intent.getStringExtra(EXTRA_LABEL) ?: "Running measurement"
                notificationManager.notify(
                    NOTIFICATION_ID,
                    buildNotification(
                        contentText = label,
                        progress = progress,
                    ),
                )
            }
            ACTION_STOP -> {
                releaseWakeLock()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            else -> {
                stopSelf(startId)
            }
        }

        return START_NOT_STICKY
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notificationManager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Measurements",
                    NotificationManager.IMPORTANCE_LOW,
                ),
            )
        }
    }

    private fun buildNotification(contentText: String, progress: Int): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentText(contentText)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(100, progress, false)
            .build()
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) {
            return
        }

        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock =
            powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "$packageName:measurementSession",
            ).apply {
                acquire(MAX_WAKE_LOCK_MS)
            }
    }

    private fun releaseWakeLock() {
        wakeLock?.let { lock ->
            if (lock.isHeld) {
                lock.release()
            }
        }
        wakeLock = null
    }

    companion object {
        private const val CHANNEL_ID = "whm_measurement_session"
        private const val NOTIFICATION_ID = 4000
        private const val ACTION_START = "start"
        private const val ACTION_UPDATE = "update"
        private const val ACTION_STOP = "stop"
        private const val EXTRA_PROGRESS = "progress"
        private const val EXTRA_LABEL = "label"
        private const val MAX_WAKE_LOCK_MS = 15 * 60 * 1000L

        fun start(context: Context, label: String) {
            context.startForegroundService(
                Intent(context, MeasurementSessionService::class.java).apply {
                    action = ACTION_START
                    putExtra(EXTRA_LABEL, label)
                },
            )
        }

        fun update(context: Context, progress: Int, label: String) {
            context.startService(
                Intent(context, MeasurementSessionService::class.java).apply {
                    action = ACTION_UPDATE
                    putExtra(EXTRA_PROGRESS, progress)
                    putExtra(EXTRA_LABEL, label)
                },
            )
        }

        fun stop(context: Context) {
            context.startService(
                Intent(context, MeasurementSessionService::class.java).apply {
                    action = ACTION_STOP
                },
            )
        }
    }
}
