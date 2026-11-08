package dev.meteora.meteora.service

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import dev.meteora.meteora.MainActivity
import dev.meteora.meteora.R
import dev.meteora.meteora.process.SafeProcessExecutor
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class DownloadForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "meteora_downloads_channel"
        const val NOTIFICATION_ID = 1001

        const val ACTION_START = "dev.meteora.ACTION_START_DOWNLOAD"
        const val ACTION_CANCEL = "dev.meteora.ACTION_CANCEL_DOWNLOAD"
        const val ACTION_PAUSE = "dev.meteora.ACTION_PAUSE_DOWNLOAD"

        const val EXTRA_TASK_ID = "extra_task_id"
        const val EXTRA_COMMAND = "extra_command"
        const val EXTRA_TITLE = "extra_title"

        // Callback interface for streaming download progress events to Flutter
        var progressListener: ((Map<String, Any>) -> Unit)? = null
    }

    private val serviceScope = CoroutineScope(Dispatchers.IO + Job())
    private val activeTasks = ConcurrentHashMap<String, Job>()
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private lateinit var notificationManager: NotificationManager
    private val processExecutor = SafeProcessExecutor()

    override fun onCreate() {
        super.onCreate()
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
        acquireLocks()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: return START_NOT_STICKY
        val taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: return START_NOT_STICKY

        when (action) {
            ACTION_START -> {
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "Downloading media"
                val command = intent.getStringArrayListExtra(EXTRA_COMMAND) ?: return START_NOT_STICKY
                startForeground(NOTIFICATION_ID, buildNotification(title, "Starting download...", 0, true))
                launchDownloadTask(taskId, title, command)
            }
            ACTION_CANCEL, ACTION_PAUSE -> {
                cancelTask(taskId)
            }
        }

        return START_NOT_STICKY
    }

    private fun launchDownloadTask(taskId: String, title: String, command: List<String>) {
        val job = serviceScope.launch {
            emitEvent(taskId, "downloading", 0.0, "0 B/s", "Starting...")

            val progressRegex = Regex("""\[download\]\s+([\d.]+)%\s+of\s+~?([\d.]+)(\w+)\s+at\s+([\d.]+)(\w+/s)\s+ETA\s+([\d:]+)""")

            val result = processExecutor.execute(
                command = command,
                workingDir = filesDir,
                onLineOutput = { line ->
                    val match = progressRegex.find(line)
                    if (match != null) {
                        val percent = match.groupValues[1].toDoubleOrNull() ?: 0.0
                        val totalSize = "${match.groupValues[2]} ${match.groupValues[3]}"
                        val speed = "${match.groupValues[4]} ${match.groupValues[5]}"
                        val eta = match.groupValues[6]

                        updateNotification(title, "$speed • ETA $eta", percent.toInt())
                        emitEvent(taskId, "downloading", percent, speed, eta, totalSize)
                    }
                }
            )

            if (result.isCancelled) {
                emitEvent(taskId, "cancelled", 0.0, "0 B/s", "")
            } else if (result.exitCode == 0) {
                emitEvent(taskId, "completed", 100.0, "0 B/s", "Done")
                updateNotification(title, "Download complete", 100)
            } else {
                emitEvent(taskId, "error", 0.0, "0 B/s", "Failed with code ${result.exitCode}")
            }

            activeTasks.remove(taskId)
            if (activeTasks.isEmpty()) {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }

        activeTasks[taskId] = job
    }

    private fun cancelTask(taskId: String) {
        activeTasks[taskId]?.cancel()
        activeTasks.remove(taskId)
        emitEvent(taskId, "cancelled", 0.0, "0 B/s", "")
        if (activeTasks.isEmpty()) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    private fun emitEvent(
        taskId: String,
        status: String,
        percent: Double,
        speed: String,
        eta: String,
        totalSize: String = ""
    ) {
        val event = mapOf(
            "taskId" to taskId,
            "status" to status,
            "percent" to percent,
            "speed" to speed,
            "eta" to eta,
            "totalSize" to totalSize
        )
        progressListener?.invoke(event)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Media Downloads",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows live progress for active media downloads"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(
        title: String,
        content: String,
        progress: Int,
        indeterminate: Boolean = false
    ): android.app.Notification {
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentIntent(pendingIntent)
            .setProgress(100, progress, indeterminate)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun updateNotification(title: String, content: String, progress: Int) {
        val notification = buildNotification(title, content, progress, false)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun acquireLocks() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
        wakeLock = powerManager?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Meteora:DownloadWakeLock")?.apply {
            acquire(3 * 60 * 60 * 1000L) // 3 hours safety timeout
        }

        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        wifiLock = wifiManager?.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "Meteora:DownloadWifiLock")?.apply {
            acquire()
        }
    }

    private fun releaseLocks() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wifiLock?.let {
            if (it.isHeld) it.release()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
        releaseLocks()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
