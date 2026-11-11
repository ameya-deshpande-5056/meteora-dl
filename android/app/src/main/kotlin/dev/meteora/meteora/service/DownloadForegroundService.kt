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
import android.util.Log
import androidx.core.app.NotificationCompat
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import dev.meteora.meteora.MainActivity
import dev.meteora.meteora.engine.NativeEngineManager
import dev.meteora.meteora.process.SafeProcessExecutor
import dev.meteora.meteora.storage.DownloadStorageManager
import dev.meteora.meteora.storage.PublishedFileResult
import java.io.File
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class DownloadForegroundService : Service() {

    companion object {
        private const val TAG = "DownloadFGService"
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

    private val exceptionHandler = CoroutineExceptionHandler { _, throwable ->
        Log.e(TAG, "Unhandled exception in background download service", throwable)
    }

    private val serviceScope = CoroutineScope(Dispatchers.IO + Job() + exceptionHandler)
    private val activeTasks = ConcurrentHashMap<String, Job>()
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private lateinit var notificationManager: NotificationManager
    private val processExecutor = SafeProcessExecutor()
    private val storageManager by lazy { DownloadStorageManager(applicationContext) }

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

    private fun resolveCommand(rawCommand: List<String>): List<String> {
        if (rawCommand.isEmpty()) return rawCommand
        val first = rawCommand.first()
        
        // If the binary isn't absolute, check if it exists in the active packages directory
        if (!first.startsWith("/")) {
            val candidate = File(filesDir, "packages/active/ytdlp/$first")
            if (candidate.exists()) {
                val resolved = rawCommand.toMutableList()
                resolved[0] = candidate.absolutePath
                return resolved
            }
        }
        return rawCommand
    }

    private fun launchDownloadTask(taskId: String, title: String, rawCommand: List<String>) {
        val safeTaskId = taskId.replace(Regex("[^a-zA-Z0-9._-]"), "_")
        val stagingBase = applicationContext.getExternalFilesDir(null) ?: applicationContext.filesDir
        val stagingDir = File(stagingBase, "staging/$safeTaskId")

        val job = serviceScope.launch {
            try {
                emitEvent(taskId, "downloading", 0.0, "0 B/s", "Starting...")

                if (!NativeEngineManager.isReady()) {
                    NativeEngineManager.init(applicationContext)
                }

                if (!stagingDir.exists()) {
                    stagingDir.mkdirs()
                }

                val args = if (rawCommand.firstOrNull() == "yt-dlp") rawCommand.drop(1) else rawCommand
                val speedRegex = Regex("""(\d+(\.\d+)?\s*(K|M|G)?i?B/s)""")

                executeWithRecovery(args, stagingDir, taskId, title, speedRegex)

                val producedFiles = stagingDir.listFiles()
                    ?.filter { file ->
                        file.isFile &&
                            !file.name.endsWith(".part", ignoreCase = true) &&
                            !file.name.endsWith(".ytdl", ignoreCase = true) &&
                            !file.name.endsWith(".tmp", ignoreCase = true)
                    }
                    ?.sortedBy { file ->
                        if (DownloadStorageManager.isSubtitleFile(file.name)) 1 else 0
                    }
                    .orEmpty()

                if (producedFiles.isEmpty()) {
                    val errorMsg = if (args.contains("--skip-download")) {
                        "No subtitles were available for this item"
                    } else {
                        "No output file was produced"
                    }
                    emitEvent(taskId, "error", 0.0, "0 B/s", errorMsg)
                    updateNotification(title, errorMsg, 0)
                    return@launch
                }

                var primaryPublished: PublishedFileResult? = null
                for (file in producedFiles) {
                    val published = storageManager.publishFile(file)
                    if (published != null && primaryPublished == null) {
                        primaryPublished = published
                    }
                }

                if (primaryPublished == null) {
                    val errorMsg = "Failed to save downloaded file to destination folder"
                    emitEvent(taskId, "error", 0.0, "0 B/s", errorMsg)
                    updateNotification(title, errorMsg, 0)
                    return@launch
                }

                val formattedSize = formatByteSize(primaryPublished.sizeBytes)
                emitEvent(
                    taskId = taskId,
                    status = "completed",
                    percent = 100.0,
                    speed = "0 B/s",
                    eta = "Done",
                    totalSize = formattedSize,
                    filePath = primaryPublished.uriOrPath,
                )
                updateNotification(title, "Download complete", 100)
            } catch (e: YoutubeDL.CanceledException) {
                emitEvent(taskId, "cancelled", 0.0, "0 B/s", "")
            } catch (e: Throwable) {
                Log.e(TAG, "Exception during download task execution", e)
                emitEvent(taskId, "error", 0.0, "0 B/s", e.localizedMessage ?: "Unknown error")
                updateNotification(title, "Download error", 0)
            } finally {
                stagingDir.deleteRecursively()
                activeTasks.remove(taskId)
                if (activeTasks.isEmpty()) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                }
            }
        }

        activeTasks[taskId] = job
    }

    private suspend fun executeWithRecovery(
        args: List<String>,
        stagingDir: File,
        taskId: String,
        title: String,
        speedRegex: Regex,
    ) {
        val isSubtitlesOnly = args.contains("--skip-download")
        try {
            executeYtDlpRequest(buildRequest(args, stagingDir), taskId, title, speedRegex)
        } catch (e: YoutubeDL.CanceledException) {
            throw e
        } catch (e: Throwable) {
            val errText = e.message ?: e.localizedMessage ?: ""
            val isSubtitleError =
                errText.contains("Unable to download video subtitles", ignoreCase = true) ||
                    errText.contains("timedtext", ignoreCase = true)
            val isForbiddenError =
                errText.contains("HTTP Error 403", ignoreCase = true) ||
                    errText.contains("unable to download video data", ignoreCase = true)
            val hasSubtitleFlags =
                args.contains("--write-subs") || args.contains("--write-auto-subs")

            if (isSubtitleError && hasSubtitleFlags && !isSubtitlesOnly) {
                Log.w(TAG, "Subtitle download failed ($errText); retrying media download without subtitles", e)
                emitEvent(taskId, "downloading", 0.0, "0 B/s", "Subtitles rate-limited, continuing...")
                updateNotification(title, "Subtitles unavailable, downloading media...", 0)
                val noSubArgs = stripSubtitleArgs(args)
                executeWithRecovery(noSubArgs, stagingDir, taskId, title, speedRegex)
            } else if (isForbiddenError && !isSubtitlesOnly && !args.contains("--extractor-args")) {
                Log.w(TAG, "Stream returned 403 Forbidden; retrying with fallback player clients", e)
                cleanupPartialFiles(stagingDir)
                emitEvent(taskId, "downloading", 0.0, "0 B/s", "Switching stream client...")
                updateNotification(title, "Retrying with compatible stream...", 0)
                val fallbackArgs = buildFallback403Args(args)
                try {
                    executeYtDlpRequest(buildRequest(fallbackArgs, stagingDir), taskId, title, speedRegex)
                } catch (retryErr: Throwable) {
                    val retryMsg = retryErr.message ?: retryErr.localizedMessage ?: ""
                    val retrySubErr =
                        retryMsg.contains("Unable to download video subtitles", ignoreCase = true) ||
                            retryMsg.contains("timedtext", ignoreCase = true)
                    if (retrySubErr && (fallbackArgs.contains("--write-subs") || fallbackArgs.contains("--write-auto-subs"))) {
                        executeYtDlpRequest(
                            buildRequest(stripSubtitleArgs(fallbackArgs), stagingDir),
                            taskId,
                            title,
                            speedRegex,
                        )
                    } else {
                        throw retryErr
                    }
                }
            } else if (isSubtitleError && errText.contains("429")) {
                throw IllegalStateException(
                    "Subtitles were rate-limited by YouTube (HTTP 429). Please retry in a moment.",
                    e,
                )
            } else {
                throw e
            }
        }
    }

    private fun cleanupPartialFiles(stagingDir: File) {
        stagingDir.listFiles()?.forEach { file ->
            if (file.isFile && (file.name.endsWith(".part", true) || file.name.endsWith(".ytdl", true))) {
                file.delete()
            }
        }
    }

    private fun buildFallback403Args(args: List<String>): List<String> {
        val updated = mutableListOf<String>()
        val isAudioOnly = args.contains("-x")
        var i = 0
        var replacedFormat = false
        while (i < args.size) {
            val token = args[i]
            if (token == "-f" && i + 1 < args.size) {
                val origFmt = args[i + 1]
                val fallbackFmt = when {
                    isAudioOnly -> "bestaudio/best"
                    origFmt.contains("+") -> "bestvideo+bestaudio/best"
                    else -> "bestvideo/best"
                }
                updated.add("-f")
                updated.add(fallbackFmt)
                replacedFormat = true
                i += 2
            } else {
                updated.add(token)
                i += 1
            }
        }
        val insertPos = if (updated.isNotEmpty()) updated.size - 1 else 0
        val extra = mutableListOf<String>()
        if (!replacedFormat && !isAudioOnly) {
            extra.addAll(listOf("-f", "bestvideo+bestaudio/best"))
        }
        extra.addAll(listOf("--extractor-args", "youtube:player_client=tv,android_vr,visionos"))
        if (!updated.contains("--force-ipv4") && !updated.contains("-4")) {
            extra.add("--force-ipv4")
        }
        updated.addAll(insertPos, extra)
        return updated
    }

    private fun buildRequest(args: List<String>, stagingDir: File): YoutubeDLRequest {
        val request = YoutubeDLRequest(emptyList())
        request.addCommands(args)
        if (!request.hasOption("--retries")) {
            request.addOption("--retries", "5")
        }
        if (!request.hasOption("--fragment-retries")) {
            request.addOption("--fragment-retries", "10")
        }
        if (!request.hasOption("--extractor-retries")) {
            request.addOption("--extractor-retries", "3")
        }
        // Stage downloads inside isolated task directory before publishing to public/user storage
        if (!request.hasOption("-o") && !request.hasOption("--output")) {
            request.addOption("-o", "${stagingDir.absolutePath}/%(title)s [%(id)s].%(ext)s")
        }
        return request
    }

    private suspend fun executeYtDlpRequest(
        request: YoutubeDLRequest,
        taskId: String,
        title: String,
        speedRegex: Regex,
    ) {
        NativeEngineManager.execute(request, processId = taskId) { progress, etaInSeconds, line ->
            val speedMatch = speedRegex.find(line)
            val speed = speedMatch?.value ?: ""
            val etaStr = if (etaInSeconds > 0) "${etaInSeconds}s" else ""
            updateNotification(
                title,
                if (speed.isNotEmpty()) "$speed • ETA $etaStr" else "Downloading...",
                progress.toInt(),
            )
            emitEvent(taskId, "downloading", progress.toDouble(), speed, etaStr)
        }
    }

    private fun stripSubtitleArgs(args: List<String>): List<String> {
        val valueFlags = setOf("--sub-langs", "--sub-format", "--sleep-subtitles")
        val boolFlags = setOf("--write-subs", "--write-auto-subs", "--embed-subs")
        val filtered = mutableListOf<String>()
        var i = 0
        while (i < args.size) {
            val token = args[i]
            when {
                token in valueFlags -> {
                    i += 2
                }
                token in boolFlags -> {
                    i += 1
                }
                else -> {
                    filtered.add(token)
                    i += 1
                }
            }
        }
        return filtered
    }

    private fun formatByteSize(bytes: Long): String {
        if (bytes <= 0L) return ""
        val kb = 1024.0
        val mb = kb * 1024.0
        val gb = mb * 1024.0
        return when {
            bytes >= gb -> String.format(Locale.US, "%.2f GB", bytes / gb)
            bytes >= mb -> String.format(Locale.US, "%.1f MB", bytes / mb)
            bytes >= kb -> String.format(Locale.US, "%.0f KB", bytes / kb)
            else -> "$bytes B"
        }
    }

    private fun cancelTask(taskId: String) {
        NativeEngineManager.cancel(taskId)
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
        totalSize: String = "",
        filePath: String? = null,
    ) {
        val event = mutableMapOf<String, Any>(
            "taskId" to taskId,
            "status" to status,
            "percent" to percent,
            "speed" to speed,
            "eta" to eta,
            "totalSize" to totalSize
        )
        if (filePath != null) {
            event["filePath"] = filePath
        }
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
        wakeLock = powerManager?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "MeteoraDL:DownloadWakeLock")?.apply {
            acquire(3 * 60 * 60 * 1000L) // 3 hours safety timeout
        }

        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        @Suppress("DEPRECATION")
        wifiLock = wifiManager?.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "MeteoraDL:DownloadWifiLock")?.apply {
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
