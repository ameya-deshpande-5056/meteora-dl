package dev.meteora.meteora.direct

import java.net.URI
import org.json.JSONArray
import org.json.JSONObject

/**
 * Lifecycle of a direct (plain HTTP) download. The wire names match the
 * `DownloadStatus` values in `packages/download_engine` so the Flutter layer can
 * map a native payload without a translation table of its own.
 */
enum class DirectStatus(val wire: String) {
    QUEUED("queued"),
    RUNNING("running"),
    PAUSED("paused"),
    COMPLETED("completed"),
    FAILED("failed"),
    CANCELLED("cancelled");

    companion object {
        fun fromWire(value: String?): DirectStatus =
            values().firstOrNull { it.wire == value } ?: QUEUED
    }
}

/**
 * One contiguous byte range of the remote file. [downloaded] is the number of
 * bytes already written *into this range*, which is what makes resume work:
 * a range resumes at `start + downloaded`.
 */
class DirectSegment(val index: Int, val start: Long, val end: Long) {
    @Volatile
    var downloaded: Long = 0L

    val length: Long get() = end - start + 1
    val remaining: Long get() = (length - downloaded).coerceAtLeast(0L)
    val isComplete: Boolean get() = downloaded >= length

    fun toJson(): JSONObject = JSONObject().apply {
        put("index", index)
        put("start", start)
        put("end", end)
        put("downloaded", downloaded)
        put("completed", isComplete)
    }

    companion object {
        fun fromJson(json: JSONObject): DirectSegment = DirectSegment(
            index = json.optInt("index"),
            start = json.optLong("start"),
            end = json.optLong("end"),
        ).apply {
            downloaded = json.optLong("downloaded").coerceIn(0L, length)
        }

        /**
         * Mirror of `SegmentPlanner.plan` in `packages/download_engine`: split
         * [totalBytes] into at most [maxSegments] contiguous ranges, spreading
         * the remainder over the leading segments.
         */
        fun plan(totalBytes: Long, maxSegments: Int): List<DirectSegment> {
            if (totalBytes <= 0L) return emptyList()
            if (maxSegments <= 1) return listOf(DirectSegment(0, 0L, totalBytes - 1))
            val count = maxSegments
            val base = totalBytes / count
            val remainder = totalBytes % count
            val segments = mutableListOf<DirectSegment>()
            var cursor = 0L
            for (i in 0 until count) {
                if (cursor >= totalBytes) break
                val size = base + if (i < remainder) 1L else 0L
                if (size <= 0L) break
                val end = (cursor + size - 1).coerceAtMost(totalBytes - 1)
                segments.add(DirectSegment(segments.size, cursor, end))
                cursor = end + 1
            }
            return segments
        }
    }
}

/** Immutable description of what to fetch; everything else is mutable state. */
class DirectDownloadSpec(
    val taskId: String,
    val url: String,
    val title: String,
    val fileName: String?,
    val headers: Map<String, String>,
    val expectedBytes: Long,
    val maxSegments: Int,
    val allowResume: Boolean,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("taskId", taskId)
        put("url", url)
        put("title", title)
        put("fileName", fileName)
        put("headers", JSONObject().apply { headers.forEach { (k, v) -> put(k, v) } })
        put("expectedBytes", expectedBytes)
        put("maxSegments", maxSegments)
        put("allowResume", allowResume)
    }

    companion object {
        fun fromJson(json: JSONObject): DirectDownloadSpec {
            val headerJson = json.optJSONObject("headers")
            val headers = mutableMapOf<String, String>()
            headerJson?.keys()?.forEach { key ->
                headers[key] = headerJson.optString(key)
            }
            return DirectDownloadSpec(
                taskId = json.optString("taskId"),
                url = json.optString("url"),
                title = json.optString("title"),
                fileName = json.optString("fileName").takeIf { it.isNotBlank() },
                headers = headers,
                expectedBytes = json.optLong("expectedBytes"),
                maxSegments = json.optInt("maxSegments", 4),
                allowResume = json.optBoolean("allowResume", true),
            )
        }
    }
}

/**
 * Persisted state of one direct download: spec + probe results + per-range
 * progress. Written atomically by [DirectDownloadStore] after every meaningful
 * change, so a process kill loses at most one progress interval.
 */
class DirectTask(
    val spec: DirectDownloadSpec,
    var status: DirectStatus = DirectStatus.QUEUED,
    var totalBytes: Long = -1L,
    var segments: MutableList<DirectSegment> = mutableListOf(),
    var resolvedFileName: String? = null,
    var contentType: String? = null,
    var etag: String? = null,
    var supportsRanges: Boolean = false,
    var filePath: String? = null,
    var errorMessage: String? = null,
    var retryCount: Int = 0,
    val createdAt: Long = System.currentTimeMillis(),
    var updatedAt: Long = System.currentTimeMillis(),
) {
    val taskId: String get() = spec.taskId

    val host: String
        get() = runCatching { URI(spec.url).host?.lowercase() ?: "" }.getOrDefault("")

    fun downloadedBytes(): Long =
        if (segments.isEmpty()) 0L else segments.sumOf { it.downloaded.coerceAtMost(it.length) }

    fun percent(): Double {
        val total = totalBytes
        if (total <= 0L) return 0.0
        return (downloadedBytes().toDouble() / total.toDouble() * 100.0).coerceIn(0.0, 100.0)
    }

    /** Name the finished file will carry inside the public destination folder. */
    fun effectiveFileName(): String {
        val candidate = resolvedFileName ?: spec.fileName
        if (!candidate.isNullOrBlank()) return DirectFileName.sanitize(candidate)
        val fromUrl = DirectFileName.fromUrl(spec.url)
        if (!fromUrl.isNullOrBlank()) return DirectFileName.sanitize(fromUrl)
        return DirectFileName.sanitize("meteora_download_${spec.taskId}")
    }

    fun touch() {
        updatedAt = System.currentTimeMillis()
    }

    fun toJson(): JSONObject = JSONObject().apply {
        put("spec", spec.toJson())
        put("status", status.wire)
        put("totalBytes", totalBytes)
        put("segments", JSONArray().apply { segments.forEach { put(it.toJson()) } })
        put("resolvedFileName", resolvedFileName)
        put("contentType", contentType)
        put("etag", etag)
        put("supportsRanges", supportsRanges)
        put("filePath", filePath)
        put("errorMessage", errorMessage)
        put("retryCount", retryCount)
        put("createdAt", createdAt)
        put("updatedAt", updatedAt)
    }

    /** Flutter-facing snapshot; keys match `DirectDownloadSnapshot` in Dart. */
    fun toChannelMap(): Map<String, Any?> = mapOf(
        "id" to taskId,
        "url" to spec.url,
        "title" to spec.title,
        "status" to status.wire,
        "totalBytes" to totalBytes,
        "downloadedBytes" to downloadedBytes(),
        "percent" to percent(),
        "filePath" to filePath,
        "errorMessage" to errorMessage,
        "fileName" to effectiveFileName(),
        "supportsRanges" to supportsRanges,
        "segments" to segments.map { segment ->
            mapOf(
                "index" to segment.index,
                "start" to segment.start,
                "end" to segment.end,
                "downloaded" to segment.downloaded,
                "completed" to segment.isComplete,
            )
        },
        "createdAt" to createdAt,
        "updatedAt" to updatedAt,
    )

    companion object {
        fun fromJson(json: JSONObject): DirectTask? {
            val specJson = json.optJSONObject("spec") ?: return null
            val spec = DirectDownloadSpec.fromJson(specJson)
            if (spec.taskId.isBlank() || spec.url.isBlank()) return null

            val segments = mutableListOf<DirectSegment>()
            val segmentArray = json.optJSONArray("segments")
            if (segmentArray != null) {
                for (i in 0 until segmentArray.length()) {
                    val item = segmentArray.optJSONObject(i) ?: continue
                    segments.add(DirectSegment.fromJson(item))
                }
            }

            return DirectTask(
                spec = spec,
                status = DirectStatus.fromWire(json.optString("status")),
                totalBytes = json.optLong("totalBytes", -1L),
                segments = segments,
                resolvedFileName = json.optString("resolvedFileName").takeIf { it.isNotBlank() },
                contentType = json.optString("contentType").takeIf { it.isNotBlank() },
                etag = json.optString("etag").takeIf { it.isNotBlank() },
                supportsRanges = json.optBoolean("supportsRanges", false),
                filePath = json.optString("filePath").takeIf { it.isNotBlank() },
                errorMessage = json.optString("errorMessage").takeIf { it.isNotBlank() },
                retryCount = json.optInt("retryCount"),
                createdAt = json.optLong("createdAt", System.currentTimeMillis()),
                updatedAt = json.optLong("updatedAt", System.currentTimeMillis()),
            )
        }
    }
}
