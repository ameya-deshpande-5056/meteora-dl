package dev.meteora.meteora.direct

import java.io.File
import java.io.IOException
import java.io.OutputStream
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.Collections
import java.util.concurrent.atomic.AtomicInteger
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Exercises the real transport against a real HTTP server: range requests,
 * `.part` staging, resume after a failed range, and the single-stream fallback
 * for servers that ignore `Range`.
 */
class SegmentedHttpDownloaderTest {

    private val servers = mutableListOf<RangeServer>()
    private val tempDirs = mutableListOf<File>()

    @After
    fun tearDown() {
        servers.forEach { it.stop() }
        tempDirs.forEach { it.deleteRecursively() }
    }

    private fun payload(size: Int): ByteArray =
        ByteArray(size) { index -> ((index * 31) % 251).toByte() }

    private fun stagingDir(): File {
        val dir = File.createTempFile("meteora-download", "").apply { delete() ; mkdirs() }
        tempDirs.add(dir)
        return dir
    }

    private fun task(url: String, maxSegments: Int = 2): DirectTask = DirectTask(
        spec = DirectDownloadSpec(
            taskId = "test-task",
            url = url,
            title = "test file",
            fileName = "test.bin",
            headers = emptyMap(),
            expectedBytes = -1L,
            maxSegments = maxSegments,
            allowResume = true,
        ),
    )

    private fun newDownloader(maxAttempts: Int = 5) = SegmentedHttpDownloader(
        maxSegmentThreads = 4,
        maxAttempts = maxAttempts,
        connectTimeoutMs = 5_000,
        readTimeoutMs = 5_000,
        enforceUrlPolicy = false,
    )

    @Test
    fun `downloads a file as concurrent byte ranges`() {
        val bytes = payload(2 * 1024 * 1024)
        val server = RangeServer(bytes).start()
        servers.add(server)
        val dir = stagingDir()
        val partFile = File(dir, "download.part")

        val task = task(server.url)
        val file = newDownloader().download(task, partFile) { _, _, _ -> }

        assertEquals(bytes.size.toLong(), file.length())
        assertTrue(bytes.contentEquals(file.readBytes()))
        assertFalse("staging file should be renamed on success", partFile.exists())
        assertEquals("test.bin", file.name)
        assertEquals(bytes.size.toLong(), task.totalBytes)
        assertEquals(2, task.segments.size)
        assertTrue(task.segments.all { it.isComplete })
        assertTrue("expected a probe plus two range requests", server.requests.get() >= 3)
        assertTrue(server.rangeRequests.any { it.first == 0L && it.second > 0L })
        assertTrue(server.rangeRequests.any { it.first >= bytes.size / 2 })
    }

    @Test
    fun `resumes only the unfinished range after a failure`() {
        val bytes = payload(2 * 1024 * 1024)
        val half = bytes.size / 2L
        val server = RangeServer(bytes).start()
        servers.add(server)
        server.failRangesFrom = half

        val dir = stagingDir()
        val partFile = File(dir, "download.part")
        val task = task(server.url)

        val failure = runCatching {
            newDownloader(maxAttempts = 1).download(task, partFile) { _, _, _ -> }
        }
        assertTrue("first attempt should fail", failure.isFailure)
        assertTrue("staged .part must survive a failure", partFile.exists())
        assertTrue("finished range must stay complete", task.segments[0].isComplete)
        assertFalse(task.segments[1].isComplete)

        server.failRangesFrom = null
        val requestedBeforeResume = server.rangeRequests.size
        val file = newDownloader().download(task, partFile) { _, _, _ -> }

        assertTrue(bytes.contentEquals(file.readBytes()))
        assertFalse(partFile.exists())
        assertTrue(task.segments.all { it.isComplete })

        val resumedRequests = server.rangeRequests.drop(requestedBeforeResume)
        assertTrue("resume should fetch something", resumedRequests.isNotEmpty())
        assertFalse(
            "the already-finished range must not be downloaded again",
            resumedRequests.any { it.first == 0L && it.second > 0L },
        )
    }

    @Test
    fun `restarts instead of trusting offsets when the staged file is gone`() {
        val bytes = payload(2 * 1024 * 1024)
        val server = RangeServer(bytes).start()
        servers.add(server)
        val dir = stagingDir()
        val partFile = File(dir, "download.part")

        // Simulates a task record whose cache was cleared: the stored offsets
        // claim half the file is present, but no .part file exists.
        val task = task(server.url)
        task.totalBytes = bytes.size.toLong()
        task.segments = DirectSegment.plan(bytes.size.toLong(), 2).toMutableList()
        task.segments.forEach { it.downloaded = it.length }

        val file = newDownloader().download(task, partFile) { _, _, _ -> }

        assertTrue(bytes.contentEquals(file.readBytes()))
        assertTrue(task.segments.all { it.isComplete })
        assertTrue("everything must be fetched again", server.requests.get() > 2)
    }

    @Test
    fun `falls back to a single stream when the server ignores ranges`() {
        val bytes = payload(1536 * 1024)
        val server = RangeServer(bytes, honorRanges = false).start()
        servers.add(server)
        val dir = stagingDir()
        val partFile = File(dir, "download.part")

        val task = task(server.url)
        val file = newDownloader().download(task, partFile) { _, _, _ -> }

        assertTrue(bytes.contentEquals(file.readBytes()))
        assertFalse(task.supportsRanges)
        assertEquals(bytes.size.toLong(), task.totalBytes)
        assertEquals(2, server.requests.get()) // one probe + one full stream
    }

    @Test
    fun `retries a transient server error and still completes`() {
        val bytes = payload(1024 * 1024)
        val server = RangeServer(bytes).start()
        servers.add(server)
        server.failNextRequests = 2

        val dir = stagingDir()
        val task = task(server.url, maxSegments = 2)
        val file = newDownloader(maxAttempts = 4).download(task, File(dir, "download.part")) { _, _, _ -> }

        assertTrue(bytes.contentEquals(file.readBytes()))
        assertTrue("server should have been hit more than once", server.requests.get() > 3)
    }

    @Test
    fun `aborting stops the transfer and keeps the staged file`() {
        val bytes = payload(4 * 1024 * 1024)
        val server = RangeServer(bytes).start()
        servers.add(server)
        val dir = stagingDir()
        val partFile = File(dir, "download.part")
        val task = task(server.url, maxSegments = 4)

        val downloader = newDownloader()
        var aborted = false
        val failure = runCatching {
            downloader.download(task, partFile) { downloaded, _, _ ->
                if (!aborted && downloaded > 0) {
                    aborted = true
                    downloader.abort()
                }
            }
        }

        assertTrue(aborted)
        assertTrue(failure.isFailure)
        assertTrue(failure.exceptionOrNull() is DownloadAbortedException)
        assertTrue("paused download keeps its .part file", partFile.exists())
    }

    /**
     * Minimal HTTP/1.1 server over a raw socket: the Android unit-test classpath
     * has no `com.sun.net.httpserver`, and this keeps the test dependency-free
     * while still exercising real sockets and real range semantics.
     */
    private class RangeServer(
        private val payload: ByteArray,
        private val honorRanges: Boolean = true,
    ) {
        private val serverSocket = ServerSocket(0, 50, InetAddress.getByName("127.0.0.1"))
        private val acceptThread = Thread { acceptLoop() }.apply {
            isDaemon = true
            name = "range-server"
        }

        @Volatile
        private var running = true

        val requests = AtomicInteger()
        val rangeRequests: MutableList<Pair<Long, Long>> =
            Collections.synchronizedList(mutableListOf())

        @Volatile
        var failRangesFrom: Long? = null

        @Volatile
        var failNextRequests: Int = 0

        fun start(): RangeServer {
            acceptThread.start()
            return this
        }

        fun stop() {
            running = false
            runCatching { serverSocket.close() }
        }

        val url: String
            get() = "http://127.0.0.1:${serverSocket.localPort}/file.bin"

        private fun acceptLoop() {
            while (running) {
                val socket = try {
                    serverSocket.accept()
                } catch (_: IOException) {
                    break
                }
                Thread { handle(socket) }.apply { isDaemon = true }.start()
            }
        }

        private fun handle(socket: Socket) {
            socket.use { client ->
                client.soTimeout = 5_000
                try {
                    val input = client.getInputStream().bufferedReader()
                    input.readLine() ?: return
                    val headers = mutableMapOf<String, String>()
                    while (true) {
                        val line = input.readLine() ?: break
                        if (line.isEmpty()) break
                        val separator = line.indexOf(':')
                        if (separator > 0) {
                            headers[line.substring(0, separator).trim().lowercase()] =
                                line.substring(separator + 1).trim()
                        }
                    }

                    requests.incrementAndGet()
                    val output = client.getOutputStream()

                    if (failNextRequests > 0) {
                        failNextRequests -= 1
                        respond(output, 503, emptyMap(), ByteArray(0))
                        return
                    }

                    val rangeHeader = headers["range"]
                    if (rangeHeader != null) {
                        val spec = rangeHeader.removePrefix("bytes=").split("-")
                        val start = spec.getOrNull(0)?.toLongOrNull() ?: 0L
                        val end = (spec.getOrNull(1)?.toLongOrNull() ?: (payload.size - 1L))
                            .coerceAtMost(payload.size - 1L)
                        rangeRequests.add(start to end)

                        val failFrom = failRangesFrom
                        if (failFrom != null && start >= failFrom) {
                            respond(output, 500, emptyMap(), ByteArray(0))
                            return
                        }

                        if (honorRanges) {
                            val length = (end - start + 1).toInt()
                            respond(
                                output = output,
                                status = 206,
                                extraHeaders = mapOf(
                                    "Accept-Ranges" to "bytes",
                                    "Content-Range" to "bytes $start-$end/${payload.size}",
                                    "ETag" to "\"v1\"",
                                    "Content-Type" to "application/octet-stream",
                                ),
                                body = payload.copyOfRange(start.toInt(), end.toInt() + 1),
                            )
                            return
                        }
                    }

                    respond(
                        output = output,
                        status = 200,
                        extraHeaders = mapOf(
                            "ETag" to "\"v1\"",
                            "Content-Type" to "application/octet-stream",
                        ),
                        body = payload,
                    )
                } catch (_: IOException) {
                    // Client disconnected (pause/abort) — expected in that test.
                }
            }
        }

        private fun respond(
            output: OutputStream,
            status: Int,
            extraHeaders: Map<String, String>,
            body: ByteArray,
        ) {
            val reason = when (status) {
                200 -> "OK"
                206 -> "Partial Content"
                500 -> "Internal Server Error"
                503 -> "Service Unavailable"
                else -> "Response"
            }
            val builder = StringBuilder("HTTP/1.1 $status $reason\r\n")
            extraHeaders.forEach { (key, value) -> builder.append("$key: $value\r\n") }
            builder.append("Content-Length: ${body.size}\r\n")
            builder.append("Connection: close\r\n\r\n")
            output.write(builder.toString().toByteArray())
            if (body.isNotEmpty()) output.write(body)
            output.flush()
        }
    }
}
