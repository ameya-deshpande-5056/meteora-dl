package dev.meteora.meteora.direct

import android.content.Context
import android.util.Log
import dev.meteora.meteora.storage.DownloadStorageManager
import java.io.File
import java.util.Locale
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/**
 * Scheduler + persistence for direct downloads.
 *
 * This is the native counterpart of `DownloadScheduler` in
 * `packages/download_engine` (same policy: a global concurrency cap plus a
 * per-host cap, so one fast server cannot starve the rest). It lives in the
 * service rather than in Flutter because transfers must keep going when the
 * activity is gone.
 *
 * Queue order is arrival order; a task starts only when both caps allow it, and
 * every state change is written through [DirectDownloadStore] before the next
 * event is emitted, so what the UI shows is what is on disk.
 */
class DirectDownloadQueue(
    context: Context,
    private val store: DirectDownloadStore,
    private val storageManager: DownloadStorageManager,
    private val scope: CoroutineScope,
    private val emitter: (Map<String, Any>) -> Unit,
    private val notifier: (title: String, content: String, progress: Int) -> Unit,
    private val onIdle: () -> Unit,
    private val policy: SchedulerPolicy = SchedulerPolicy(),
) {

    data class SchedulerPolicy(
        val maxConcurrent: Int = 3,
        val maxPerHost: Int = 1,
    )

    private class Running(val job: Job, val downloader: SegmentedHttpDownloader)

    companion object {
        private const val TAG = "DirectDownloadQueue"
        private const val NOTIFICATION_THROTTLE_MS = 1_000L

        /**
         * Range progress is written to disk while downloading so a kill resumes
         * from real offsets instead of replaying the whole file.
         */
        private const val PROGRESS_PERSIST_MS = 2_000L
    }

    private val appContext = context.applicationContext
    private val stagingBase: File =
        appContext.getExternalFilesDir(null) ?: appContext.filesDir

    private val lock = Any()
    private val tasks = LinkedHashMap<String, DirectTask>()
    private val running = HashMap<String, Running>()
    private val reserved = HashSet<String>()
    private val lastNotificationAt = HashMap<String, Long>()
    private val lastProgressPersistAt = HashMap<String, Long>()

    /** Loads the persisted queue. Interrupted tasks come back as paused. */
    fun restore() {
        val restored = store.loadAll()
        synchronized(lock) {
            restored.forEach { task -> tasks[task.taskId] = task }
        }
        if (restored.isNotEmpty()) {
            Log.i(TAG, "Restored ${restored.size} direct download(s) from disk")
        }
    }

    fun enqueue(spec: DirectDownloadSpec): DirectTask {
        val task = DirectTask(spec = spec)
        synchronized(lock) { tasks[task.taskId] = task }
        persist(task)
        emitStatus(task, "queued", percent = 0.0, speed = "", eta = "Queued")
        pump()
        return task
    }

    fun pause(taskId: String) {
        val handle = synchronized(lock) {
            val task = tasks[taskId]
            if (task == null ||
                (task.status != DirectStatus.RUNNING && task.status != DirectStatus.QUEUED)
            ) {
                return
            }
            task.status = DirectStatus.PAUSED
            task.touch()
            running.remove(taskId)
        }
        handle?.downloader?.abort()
        handle?.job?.cancel()

        val task = synchronized(lock) { tasks[taskId] } ?: return
        persist(task)
        emitStatus(task, "paused", task.percent(), "0 B/s", "Paused")
        pump()
    }

    fun resume(taskId: String) {
        val task = synchronized(lock) { tasks[taskId] } ?: return
        if (task.status == DirectStatus.RUNNING ||
            task.status == DirectStatus.QUEUED ||
            task.status == DirectStatus.COMPLETED
        ) {
            return
        }
        task.status = DirectStatus.QUEUED
        task.errorMessage = null
        task.touch()
        persist(task)
        emitStatus(task, "queued", task.percent(), "", "Queued")
        pump()
    }

    fun cancel(taskId: String) {
        val task = synchronized(lock) { tasks[taskId] } ?: return
        val handle = synchronized(lock) { running.remove(taskId) }
        task.status = DirectStatus.CANCELLED
        task.touch()
        handle?.downloader?.abort()
        handle?.job?.cancel()
        persist(task)
        deleteStaging(taskId)
        emitStatus(task, "cancelled", task.percent(), "0 B/s", "")
        pump()
    }

    /** Drops the record entirely (the UI removed the row). */
    fun remove(taskId: String) {
        val handle: Running? = synchronized(lock) {
            tasks.remove(taskId)
            running.remove(taskId)
        }
        handle?.downloader?.abort()
        handle?.job?.cancel()
        store.delete(taskId)
        deleteStaging(taskId)
        lastNotificationAt.remove(taskId)
        pump()
    }

    fun snapshot(): List<Map<String, Any?>> = synchronized(lock) {
        tasks.values.sortedBy { it.createdAt }.map { it.toChannelMap() }
    }

    fun hasActiveWork(): Boolean = synchronized(lock) {
        tasks.values.any { it.status == DirectStatus.QUEUED || it.status == DirectStatus.RUNNING }
    }

    /** Called when the service is going away: every transfer becomes paused. */
    fun suspendAll() {
        val handles = synchronized(lock) {
            val snapshot = running.values.toList()
            running.clear()
            reserved.clear()
            snapshot
        }
        handles.forEach { handle ->
            handle.downloader.abort()
            handle.job.cancel()
        }
        synchronized(lock) {
            tasks.values
                .filter { it.status == DirectStatus.RUNNING || it.status == DirectStatus.QUEUED }
                .forEach { task ->
                    task.status = DirectStatus.PAUSED
                    task.touch()
                    persist(task)
                }
        }
    }

    private fun pump() {
        val toStart = mutableListOf<DirectTask>()
        synchronized(lock) {
            var available = policy.maxConcurrent - running.size - reserved.size
            if (available <= 0) return

            val perHost = HashMap<String, Int>()
            (running.keys + reserved).forEach { id ->
                val host = tasks[id]?.host ?: ""
                perHost[host] = (perHost[host] ?: 0) + 1
            }

            val queued = tasks.values
                .filter { it.status == DirectStatus.QUEUED && !running.containsKey(it.taskId) }
                .sortedBy { it.createdAt }

            for (task in queued) {
                if (available <= 0) break
                val hostCount = perHost[task.host] ?: 0
                if (hostCount >= policy.maxPerHost) continue
                perHost[task.host] = hostCount + 1
                // Marked RUNNING inside the lock so a concurrent pump (a job
                // finishing on another thread) cannot schedule it twice.
                task.status = DirectStatus.RUNNING
                task.errorMessage = null
                task.touch()
                reserved.add(task.taskId)
                available--
                toStart.add(task)
            }
        }
        toStart.forEach { task ->
            synchronized(lock) { reserved.remove(task.taskId) }
            start(task)
        }
    }

    private fun start(task: DirectTask) {
        val downloader = SegmentedHttpDownloader()
        val stagingDir = stagingDir(task.taskId)
        val partFile = File(stagingDir, "download.part")

        // Paused or removed between scheduling and launch: leave it alone.
        val stillWanted = synchronized(lock) {
            tasks[task.taskId] === task && task.status == DirectStatus.RUNNING
        }
        if (!stillWanted) return

        persist(task)

        val job = scope.launch(start = CoroutineStart.LAZY) {
            try {
                emitStatus(task, "downloading", task.percent(), "", "Connecting...")
                notifier(task.spec.title, "Starting download...", 0)

                val file = downloader.download(task, partFile) { downloaded, total, bps ->
                    val percent = if (total > 0) downloaded.toDouble() / total * 100.0 else 0.0
                    emitStatus(
                        task,
                        "downloading",
                        percent.coerceIn(0.0, 100.0),
                        formatSpeed(bps),
                        formatEta(downloaded, total, bps),
                    )
                    persistProgress(task)
                    maybeNotify(task, percent, bps)
                }

                val published = storageManager.publishFile(file)
                runCatching { file.delete() }
                stagingDir.deleteRecursively()

                if (published == null) {
                    fail(task, "Downloaded file could not be saved to the destination folder")
                    return@launch
                }

                task.status = DirectStatus.COMPLETED
                task.filePath = published.uriOrPath
                task.touch()
                persist(task)
                emitStatus(
                    task,
                    "completed",
                    100.0,
                    "0 B/s",
                    "Done",
                    formatSize(published.sizeBytes),
                    published.uriOrPath,
                )
                notifier(task.spec.title, "Download complete", 100)
            } catch (_: DownloadAbortedException) {
                handlePauseOrCancel(task, stagingDir)
            } catch (_: CancellationException) {
                handlePauseOrCancel(task, stagingDir)
            } catch (e: Throwable) {
                Log.e(TAG, "Direct download failed: ${task.taskId}", e)
                fail(task, e.localizedMessage ?: "Download failed")
            } finally {
                synchronized(lock) { running.remove(task.taskId) }
                lastNotificationAt.remove(task.taskId)
                lastProgressPersistAt.remove(task.taskId)
                pump()
                if (!hasActiveWork()) onIdle()
            }
        }

        synchronized(lock) { running[task.taskId] = Running(job, downloader) }
        job.start()
    }

    private fun handlePauseOrCancel(task: DirectTask, stagingDir: File) {
        // A removed row must not be written back by its own dying job.
        val tracked = synchronized(lock) { tasks[task.taskId] === task }
        if (!tracked) {
            runCatching { stagingDir.deleteRecursively() }
            return
        }
        if (task.status == DirectStatus.CANCELLED) {
            stagingDir.deleteRecursively()
            emitStatus(task, "cancelled", task.percent(), "0 B/s", "")
            return
        }
        if (task.status != DirectStatus.PAUSED) {
            task.status = DirectStatus.PAUSED
        }
        task.touch()
        persist(task)
        // Keep the .part file: its per-range progress is what makes resume work.
        emitStatus(task, "paused", task.percent(), "0 B/s", "Paused")
    }

    private fun fail(task: DirectTask, message: String) {
        if (!synchronized(lock) { tasks[task.taskId] === task }) return
        task.status = DirectStatus.FAILED
        task.errorMessage = message
        task.retryCount += 1
        task.touch()
        persist(task)
        emitStatus(task, "error", task.percent(), "0 B/s", message)
        notifier(task.spec.title, "Download error", 0)
    }

    private fun persistProgress(task: DirectTask) {
        val now = System.currentTimeMillis()
        synchronized(lastProgressPersistAt) {
            val last = lastProgressPersistAt[task.taskId] ?: 0L
            if (now - last < PROGRESS_PERSIST_MS) return
            lastProgressPersistAt[task.taskId] = now
        }
        persist(task)
    }

    private fun maybeNotify(task: DirectTask, percent: Double, bytesPerSecond: Double) {
        val now = System.currentTimeMillis()
        val last = lastNotificationAt[task.taskId] ?: 0L
        if (now - last < NOTIFICATION_THROTTLE_MS) return
        lastNotificationAt[task.taskId] = now
        notifier(task.spec.title, formatSpeed(bytesPerSecond), percent.toInt())
    }

    private fun persist(task: DirectTask) {
        store.save(task)
    }

    private fun stagingDir(taskId: String): File {
        val safe = taskId.replace(Regex("[^a-zA-Z0-9._-]"), "_").take(120)
        return File(stagingBase, "direct/$safe")
    }

    private fun deleteStaging(taskId: String) {
        runCatching { stagingDir(taskId).deleteRecursively() }
    }

    private fun emitStatus(
        task: DirectTask,
        status: String,
        percent: Double,
        speed: String,
        eta: String,
        totalSize: String = "",
        filePath: String? = null,
    ) {
        val event = mutableMapOf<String, Any>(
            "taskId" to task.taskId,
            "status" to status,
            "percent" to percent,
            "speed" to speed,
            "eta" to eta,
            "totalSize" to totalSize,
        )
        filePath?.let { event["filePath"] = it }
        try {
            emitter(event)
        } catch (e: Throwable) {
            Log.w(TAG, "Failed to deliver direct download event: ${e.message}")
        }
    }

    private fun formatSpeed(bytesPerSecond: Double): String {
        if (bytesPerSecond <= 0.0) return "0 B/s"
        val kb = 1024.0
        val mb = kb * 1024.0
        val gb = mb * 1024.0
        return when {
            bytesPerSecond >= gb -> String.format(Locale.US, "%.2f GB/s", bytesPerSecond / gb)
            bytesPerSecond >= mb -> String.format(Locale.US, "%.1f MB/s", bytesPerSecond / mb)
            bytesPerSecond >= kb -> String.format(Locale.US, "%.0f KB/s", bytesPerSecond / kb)
            else -> String.format(Locale.US, "%.0f B/s", bytesPerSecond)
        }
    }

    private fun formatEta(downloaded: Long, total: Long, bytesPerSecond: Double): String {
        if (total <= 0 || downloaded >= total) return ""
        if (bytesPerSecond <= 1.0) return "--:--"
        val remainingSeconds = ((total - downloaded) / bytesPerSecond).toLong().coerceAtLeast(0L)
        val hours = remainingSeconds / 3600
        val minutes = (remainingSeconds % 3600) / 60
        val seconds = remainingSeconds % 60
        return if (hours > 0) {
            String.format(Locale.US, "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            String.format(Locale.US, "%02d:%02d", minutes, seconds)
        }
    }

    private fun formatSize(bytes: Long): String {
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
}
