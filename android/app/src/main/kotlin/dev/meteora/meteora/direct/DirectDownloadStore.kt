package dev.meteora.meteora.direct

import android.util.Log
import java.io.File
import java.io.FileOutputStream
import org.json.JSONObject

/**
 * Atomic JSON persistence for queued direct downloads.
 *
 * One file per task under `<filesDir>/direct_queue`, written to a sibling
 * `.tmp` file and renamed over the live name so a kill can never leave a
 * half-written queue record. A file that fails to parse is quarantined as
 * `.corrupt` instead of breaking the whole queue, and a task that was left
 * `RUNNING` by a crash is demoted to `PAUSED` so its ranges resume instead of
 * pretending to be in flight.
 */
class DirectDownloadStore(private val rootDir: File) {

    companion object {
        private const val TAG = "DirectDownloadStore"
        private const val EXTENSION = ".json"
    }

    private val writeLock = Any()

    init {
        if (!rootDir.exists()) rootDir.mkdirs()
    }

    fun loadAll(): List<DirectTask> {
        val files = rootDir.listFiles { file -> file.isFile && file.name.endsWith(EXTENSION) }
            ?: return emptyList()

        val tasks = mutableListOf<DirectTask>()
        for (file in files) {
            val task = parse(file)
            if (task == null) {
                quarantine(file)
                continue
            }
            if (task.status == DirectStatus.RUNNING) {
                task.status = DirectStatus.PAUSED
                task.touch()
                if (task.segments.isEmpty()) task.segments = DirectSegment.plan(task.totalBytes, task.spec.maxSegments).toMutableList()
                save(task)
            }
            tasks.add(task)
        }
        return tasks.sortedBy { it.createdAt }
    }

    /** Serialised: progress saves and status saves can land on different threads. */
    fun save(task: DirectTask) {
        synchronized(writeLock) {
            val target = fileFor(task.taskId)
            val temp = File(rootDir, "${target.name}.tmp")
            try {
                FileOutputStream(temp).use { out ->
                    out.write(task.toJson().toString().toByteArray(Charsets.UTF_8))
                    out.flush()
                    out.fd.sync()
                }
                if (target.exists() && !target.delete()) {
                    Log.w(TAG, "Could not delete stale queue record ${target.name}")
                }
                if (!temp.renameTo(target)) {
                    Log.e(TAG, "Failed to atomically publish queue record ${target.name}")
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Failed to persist direct download ${task.taskId}", e)
                temp.delete()
            }
        }
    }

    fun delete(taskId: String) {
        synchronized(writeLock) {
            val file = fileFor(taskId)
            if (file.exists()) file.delete()
        }
    }

    fun snapshot(): List<Map<String, Any?>> = loadAll().map { it.toChannelMap() }

    private fun fileFor(taskId: String): File {
        val safe = taskId.replace(Regex("[^a-zA-Z0-9._-]"), "_").take(120)
        return File(rootDir, "$safe$EXTENSION")
    }

    private fun parse(file: File): DirectTask? = try {
        DirectTask.fromJson(JSONObject(file.readText(Charsets.UTF_8)))
    } catch (e: Throwable) {
        Log.w(TAG, "Unreadable queue record ${file.name}: ${e.message}")
        null
    }

    private fun quarantine(file: File) {
        val target = File(rootDir, "${file.name}.corrupt")
        if (target.exists()) target.delete()
        file.renameTo(target)
    }
}
