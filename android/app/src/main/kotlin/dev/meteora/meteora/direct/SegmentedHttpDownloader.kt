package dev.meteora.meteora.direct

import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.io.RandomAccessFile
import java.net.HttpURLConnection
import java.net.URL
import java.nio.ByteBuffer
import java.nio.channels.FileChannel
import java.util.Collections
import java.util.concurrent.Callable
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.min

/** Thrown when the user paused or cancelled the download. */
class DownloadAbortedException(message: String = "Download paused") : IOException(message)

/** Thrown when a server answers a ranged request with the whole body. */
private class RangeNotHonoredException : IOException("Server ignored the byte range")

/**
 * Plain-HTTP transport for direct file downloads.
 *
 * The file is fetched as several contiguous `Range` requests written into one
 * pre-sized `.part` file through positional channel writes, so ranges never
 * contend with each other. Each range tracks its own progress, which is the
 * resume currency: a paused or crashed task restarts every range at
 * `start + downloaded` and nothing already on disk is fetched twice.
 *
 * Where a server cannot do ranges (or the length is unknown), the downloader
 * degrades to a single sequential stream rather than failing. Transient errors
 * are retried per range with exponential backoff; a range is only abandoned
 * once its attempts are exhausted, leaving the rest of the file intact.
 */
class SegmentedHttpDownloader(
    private val maxSegmentThreads: Int = 4,
    private val maxAttempts: Int = 5,
    private val connectTimeoutMs: Int = 20_000,
    private val readTimeoutMs: Int = 30_000,
    private val progressIntervalNanos: Long = 200_000_000L,
    /**
     * Enforces [DirectUrlGuard] on the request URL and every redirect hop. Only
     * tests turn this off, to reach a loopback server that production blocks.
     */
    private val enforceUrlPolicy: Boolean = true,
) {

    companion object {
        private const val MIN_SEGMENT_BYTES = 1L * 1024 * 1024
        private const val BUFFER_BYTES = 64 * 1024
        private const val MAX_REDIRECTS = 5
        private val REDIRECT_CODES = setOf(301, 302, 303, 307, 308)
    }

    class Probe(
        val totalBytes: Long,
        val supportsRanges: Boolean,
        val etag: String?,
        val contentType: String?,
        val contentDisposition: String?,
    )

    /** Throttles progress callbacks and turns bytes over time into a speed. */
    private class ProgressPump(
        private val counter: AtomicLong,
        private val baseline: Long,
        private val total: Long,
        private val intervalNanos: Long,
        private val onProgress: (Long, Long, Double) -> Unit,
    ) {
        private val startedAt = System.nanoTime()
        private var lastEmitNanos = 0L

        fun emit(force: Boolean = false) {
            val now = System.nanoTime()
            if (!force && now - lastEmitNanos < intervalNanos) return
            lastEmitNanos = now
            val done = counter.get()
            val elapsedSeconds = (now - startedAt) / 1_000_000_000.0
            val bps = if (elapsedSeconds > 0.2) {
                (done - baseline).coerceAtLeast(0L) / elapsedSeconds
            } else {
                0.0
            }
            onProgress(done, total, bps)
        }
    }

    @Volatile
    private var aborted = false

    private val liveConnections: MutableList<HttpURLConnection> =
        Collections.synchronizedList(mutableListOf())

    /** Cooperative stop: also disconnects in-flight sockets so a pause is instant. */
    fun abort() {
        aborted = true
        synchronized(liveConnections) {
            liveConnections.forEach { connection ->
                runCatching { connection.disconnect() }
            }
            liveConnections.clear()
        }
    }

    /**
     * Downloads [task] into `partFile` and renames it to the resolved file name
     * on success. [onProgress] receives `(downloadedBytes, totalBytes, bytesPerSecond)`
     * including progress inherited from an earlier run.
     */
    fun download(
        task: DirectTask,
        partFile: File,
        onProgress: (Long, Long, Double) -> Unit,
    ): File {
        checkAborted()
        partFile.parentFile?.mkdirs()

        val probe = probe(task)
        task.contentType = probe.contentType ?: task.contentType
        resolveFileName(task, probe)

        val previousTotal = task.totalBytes
        val previousEtag = task.etag
        val previousSegments = task.segments

        val sameResource = previousEtag == null || probe.etag == null || previousEtag == probe.etag
        // Offsets are only trustworthy when the staged bytes are still there: a
        // cleared cache with a surviving task record must restart, not assume.
        val stagedBytesPresent = partFile.exists()
        val canResume = stagedBytesPresent &&
            probe.supportsRanges &&
            previousSegments.isNotEmpty() &&
            sameResource &&
            previousTotal == probe.totalBytes &&
            probe.totalBytes > 0 &&
            previousSegments.first().start == 0L &&
            previousSegments.last().end == probe.totalBytes - 1

        task.supportsRanges = probe.supportsRanges
        if (probe.totalBytes > 0) task.totalBytes = probe.totalBytes
        task.etag = probe.etag

        val canSegment = probe.supportsRanges &&
            task.totalBytes >= MIN_SEGMENT_BYTES &&
            task.spec.maxSegments > 1

        if (!canSegment) {
            streamSequential(task, partFile, onProgress)
            return finish(task, partFile)
        }

        task.segments = if (canResume) {
            previousSegments
        } else {
            DirectSegment.plan(task.totalBytes, task.spec.maxSegments).toMutableList()
        }

        try {
            downloadSegments(task, partFile, onProgress)
        } catch (e: RangeNotHonoredException) {
            // The server dropped range support between requests: restart as one
            // stream instead of leaving a half-ranged file behind.
            task.segments = mutableListOf()
            streamSequential(task, partFile, onProgress)
        }
        return finish(task, partFile)
    }

    private fun downloadSegments(
        task: DirectTask,
        partFile: File,
        onProgress: (Long, Long, Double) -> Unit,
    ) {
        val raf = RandomAccessFile(partFile, "rw")
        try {
            if (raf.length() != task.totalBytes) raf.setLength(task.totalBytes)
            val channel = raf.channel
            val baseline = task.segments.sumOf { it.downloaded.coerceAtMost(it.length) }
            val counter = AtomicLong(baseline)
            val pump = ProgressPump(counter, baseline, task.totalBytes, progressIntervalNanos, onProgress)

            val pending = task.segments.filter { !it.isComplete }
            if (pending.isEmpty()) {
                pump.emit(force = true)
                channel.force(true)
                return
            }

            val executor = Executors.newFixedThreadPool(min(maxSegmentThreads, pending.size))
            var failure: Throwable? = null
            try {
                val futures = pending.map { segment ->
                    executor.submit(Callable { downloadSegment(task, segment, channel, counter, pump) })
                }
                for (future in futures) {
                    try {
                        future.get()
                    } catch (e: ExecutionException) {
                        val cause = e.cause ?: e
                        if (cause !is DownloadAbortedException && failure == null) {
                            failure = cause
                        }
                        abort()
                    } catch (_: InterruptedException) {
                        Thread.currentThread().interrupt()
                        abort()
                        if (failure == null) {
                            failure = DownloadAbortedException("Download interrupted")
                        }
                    }
                }
            } finally {
                executor.shutdownNow()
            }

            failure?.let { throw it }
            checkAborted()
            pump.emit(force = true)
            channel.force(true)
        } finally {
            runCatching { raf.close() }
        }
    }

    private fun downloadSegment(
        task: DirectTask,
        segment: DirectSegment,
        channel: FileChannel,
        counter: AtomicLong,
        pump: ProgressPump,
    ) {
        var attempt = 0
        while (segment.remaining > 0) {
            checkAborted()
            attempt++
            var connection: HttpURLConnection? = null
            try {
                val from = segment.start + segment.downloaded
                connection = open(task, range = "bytes=$from-${segment.end}")
                when (val code = connection.responseCode) {
                    206 -> copyRange(segment, connection.inputStream, channel, counter, pump)
                    200 -> throw RangeNotHonoredException()
                    // The range is inside the file we just probed, so 416 means the
                    // remote file changed under us; never mark it downloaded.
                    416 -> throw IOException("Server rejected byte range ${segment.index}")
                    else -> throw IOException("HTTP $code for ${task.spec.url}")
                }
                attempt = 0
            } catch (e: DownloadAbortedException) {
                throw e
            } catch (e: RangeNotHonoredException) {
                throw e
            } catch (e: Throwable) {
                if (aborted) throw DownloadAbortedException()
                if (attempt >= maxAttempts) {
                    throw IOException(
                        "Byte range ${segment.index} failed after $attempt attempts: " +
                            (e.localizedMessage ?: e.javaClass.simpleName),
                        e,
                    )
                }
                sleepBackoff(attempt)
            } finally {
                connection?.let {
                    unregister(it)
                    it.disconnect()
                }
            }
        }
    }

    private fun copyRange(
        segment: DirectSegment,
        input: InputStream,
        channel: FileChannel,
        counter: AtomicLong,
        pump: ProgressPump,
    ) {
        val buffer = ByteArray(BUFFER_BYTES)
        input.use { stream ->
            while (segment.remaining > 0) {
                checkAborted()
                val want = min(BUFFER_BYTES.toLong(), segment.remaining).toInt()
                val read = stream.read(buffer, 0, want)
                if (read < 0) {
                    throw IOException(
                        "Connection closed with ${segment.remaining} bytes of range " +
                            "${segment.index} outstanding",
                    )
                }
                if (read == 0) continue

                val position = segment.start + segment.downloaded
                var written = 0
                while (written < read) {
                    written += channel.write(
                        ByteBuffer.wrap(buffer, written, read - written),
                        position + written,
                    )
                }
                segment.downloaded += read
                counter.addAndGet(read.toLong())
                pump.emit()
            }
        }
    }

    /** Single stream fallback: no ranges, no resume, but it still completes. */
    private fun streamSequential(
        task: DirectTask,
        partFile: File,
        onProgress: (Long, Long, Double) -> Unit,
    ) {
        var attempt = 0
        while (true) {
            checkAborted()
            attempt++
            var connection: HttpURLConnection? = null
            try {
                connection = open(task, range = null)
                val code = connection.responseCode
                if (code !in 200..299) throw IOException("HTTP $code for ${task.spec.url}")

                val total = connection.contentLengthLong
                if (total > 0) task.totalBytes = total

                val counter = AtomicLong(0L)
                val pump = ProgressPump(counter, 0L, task.totalBytes, progressIntervalNanos, onProgress)
                val buffer = ByteArray(BUFFER_BYTES)

                if (partFile.exists()) partFile.delete()
                connection.inputStream.use { input ->
                    FileOutputStream(partFile).use { output ->
                        while (true) {
                            checkAborted()
                            val read = input.read(buffer)
                            if (read < 0) break
                            if (read == 0) continue
                            output.write(buffer, 0, read)
                            counter.addAndGet(read.toLong())
                            pump.emit()
                        }
                        output.flush()
                        output.fd.sync()
                    }
                }

                val written = counter.get()
                if (task.totalBytes <= 0) task.totalBytes = written
                task.segments = mutableListOf(
                    DirectSegment(0, 0L, (task.totalBytes - 1).coerceAtLeast(0L)).apply {
                        downloaded = written
                    },
                )
                pump.emit(force = true)
                return
            } catch (e: DownloadAbortedException) {
                throw e
            } catch (e: Throwable) {
                if (aborted) throw DownloadAbortedException()
                if (attempt >= maxAttempts) throw e
                sleepBackoff(attempt)
            } finally {
                connection?.let {
                    unregister(it)
                    it.disconnect()
                }
            }
        }
    }

    private fun finish(task: DirectTask, partFile: File): File {
        checkAborted()
        val length = partFile.length()
        if (task.totalBytes > 0 && length != task.totalBytes) {
            throw IOException("Staged file is $length bytes but the server reported ${task.totalBytes}")
        }
        if (task.totalBytes <= 0) task.totalBytes = length

        val target = File(partFile.parentFile, task.effectiveFileName())
        if (target.exists() && !target.delete()) {
            throw IOException("Could not replace existing staging file ${target.name}")
        }
        if (!partFile.renameTo(target)) {
            partFile.copyTo(target, overwrite = true)
            partFile.delete()
        }
        return target
    }

    /**
     * Probe with the same retry policy as the ranges themselves: a transient
     * 5xx or a dropped connection at connect time should not fail a download
     * that has not transferred a byte yet.
     */
    fun probe(task: DirectTask): Probe {
        var attempt = 0
        while (true) {
            attempt++
            try {
                return probeOnce(task)
            } catch (e: DownloadAbortedException) {
                throw e
            } catch (e: Throwable) {
                if (aborted) throw DownloadAbortedException()
                if (attempt >= maxAttempts) throw e
                sleepBackoff(attempt)
            }
        }
    }

    /** One probe request yields length, range support, ETag and the filename hints. */
    private fun probeOnce(task: DirectTask): Probe {
        try {
            val connection = open(task, range = "bytes=0-0")
            try {
                val code = connection.responseCode
                val etag = connection.getHeaderField("ETag")
                val contentType = connection.contentType?.substringBefore(';')?.trim()
                val disposition = connection.getHeaderField("Content-Disposition")
                when {
                    code == 206 -> {
                        val total = connection.getHeaderField("Content-Range")
                            ?.substringAfterLast('/')
                            ?.trim()
                            ?.toLongOrNull()
                            ?: -1L
                        return Probe(total, total > 0, etag, contentType, disposition)
                    }
                    code == 200 -> {
                        return Probe(connection.contentLengthLong, false, etag, contentType, disposition)
                    }
                    code == 416 -> Unit
                    else -> throw IOException("HTTP $code for ${task.spec.url}")
                }
            } finally {
                unregister(connection)
                connection.disconnect()
            }
        } catch (e: RangeNotHonoredException) {
            throw e
        }

        // 416 on the 0-0 probe means the resource is likely empty; ask plainly.
        val connection = open(task, range = null)
        try {
            val code = connection.responseCode
            if (code !in 200..299) throw IOException("HTTP $code for ${task.spec.url}")
            return Probe(
                totalBytes = connection.contentLengthLong,
                supportsRanges = false,
                etag = connection.getHeaderField("ETag"),
                contentType = connection.contentType?.substringBefore(';')?.trim(),
                contentDisposition = connection.getHeaderField("Content-Disposition"),
            )
        } finally {
            unregister(connection)
            connection.disconnect()
        }
    }

    private fun resolveFileName(task: DirectTask, probe: Probe) {
        val fromDisposition = DirectFileName.fromContentDisposition(probe.contentDisposition)
        val fromUrl = DirectFileName.fromUrl(task.spec.url)
        val base = fromDisposition
            ?: task.spec.fileName
            ?: fromUrl
            ?: "meteora_download_${task.spec.taskId}"
        task.resolvedFileName = DirectFileName.withExtension(
            DirectFileName.sanitize(base),
            probe.contentType,
        )
    }

    private fun open(task: DirectTask, range: String?): HttpURLConnection {
        var currentUrl = task.spec.url
        var hops = 0
        while (true) {
            checkAborted()
            if (enforceUrlPolicy) {
                DirectUrlGuard.validate(currentUrl)?.let { throw IOException(it) }
            }

            val connection = URL(currentUrl).openConnection() as HttpURLConnection
            connection.instanceFollowRedirects = false
            connection.connectTimeout = connectTimeoutMs
            connection.readTimeout = readTimeoutMs
            connection.requestMethod = "GET"
            connection.useCaches = false
            connection.setRequestProperty("Accept", "*/*")

            task.spec.headers.forEach { (key, value) ->
                val lower = key.lowercase()
                if (value.isNotBlank() && lower != "range" && lower != "host") {
                    connection.setRequestProperty(key, value)
                }
            }
            if (task.spec.headers.keys.none { it.equals("User-Agent", true) }) {
                connection.setRequestProperty("User-Agent", "MeteoraDL/1.0 (Android)")
            }
            if (task.spec.headers.keys.none { it.equals("Accept-Encoding", true) }) {
                // Ranges only line up when the body is not transparently compressed.
                connection.setRequestProperty("Accept-Encoding", "identity")
            }
            range?.let { connection.setRequestProperty("Range", it) }

            register(connection)
            val code = try {
                connection.responseCode
            } catch (e: Throwable) {
                unregister(connection)
                connection.disconnect()
                throw e
            }

            if (code in REDIRECT_CODES) {
                val location = connection.getHeaderField("Location")
                unregister(connection)
                connection.disconnect()
                if (location.isNullOrBlank()) throw IOException("HTTP $code without a Location header")
                currentUrl = URL(URL(currentUrl), location).toString()
                hops++
                if (hops > MAX_REDIRECTS) throw IOException("Too many redirects for ${task.spec.url}")
                continue
            }
            return connection
        }
    }

    private fun register(connection: HttpURLConnection) {
        liveConnections.add(connection)
    }

    private fun unregister(connection: HttpURLConnection) {
        liveConnections.remove(connection)
    }

    private fun checkAborted() {
        if (aborted) throw DownloadAbortedException()
    }

    private fun sleepBackoff(attempt: Int) {
        val base = 500L * (1L shl (attempt - 1).coerceIn(0, 5))
        val jitter = (0..250).random().toLong()
        try {
            Thread.sleep(base + jitter)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            throw DownloadAbortedException()
        }
    }
}
