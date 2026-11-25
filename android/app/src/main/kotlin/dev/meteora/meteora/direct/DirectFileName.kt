package dev.meteora.meteora.direct

import java.net.URLDecoder

/**
 * Resolves the on-disk name for a direct download the same way a browser's
 * download manager does: `Content-Disposition` first (with RFC 5987 `filename*`
 * support), then the URL leaf, then a generated fallback. The extension comes
 * from the response content type when the server did not provide one.
 */
object DirectFileName {

    private val DISPOSITION_FILENAME_STAR = Regex(
        """filename\*\s*=\s*([^']*)'[^']*'([^;]+)""",
        RegexOption.IGNORE_CASE,
    )
    private val DISPOSITION_FILENAME = Regex(
        """filename\s*=\s*(?:"([^"]*)"|([^;]+))""",
        RegexOption.IGNORE_CASE,
    )

    private val MIME_EXTENSIONS = mapOf(
        "video/mp4" to "mp4",
        "video/webm" to "webm",
        "video/x-matroska" to "mkv",
        "video/quicktime" to "mov",
        "video/x-flv" to "flv",
        "audio/mpeg" to "mp3",
        "audio/mp4" to "m4a",
        "audio/x-m4a" to "m4a",
        "audio/aac" to "aac",
        "audio/ogg" to "ogg",
        "audio/opus" to "opus",
        "audio/flac" to "flac",
        "audio/wav" to "wav",
        "image/jpeg" to "jpg",
        "image/png" to "png",
        "image/webp" to "webp",
        "image/gif" to "gif",
        "application/pdf" to "pdf",
        "application/zip" to "zip",
        "application/x-7z-compressed" to "7z",
        "application/vnd.rar" to "rar",
        "application/x-rar-compressed" to "rar",
        "application/x-tar" to "tar",
        "application/gzip" to "gz",
        "application/vnd.android.package-archive" to "apk",
        "application/epub+zip" to "epub",
        "text/plain" to "txt",
        "text/vtt" to "vtt",
        "application/x-subrip" to "srt",
    )

    fun fromContentDisposition(header: String?): String? {
        if (header.isNullOrBlank()) return null

        DISPOSITION_FILENAME_STAR.find(header)?.let { match ->
            val encoded = match.groupValues.getOrNull(2)?.trim()
            if (!encoded.isNullOrBlank()) {
                val decoded = percentDecode(encoded)
                if (decoded.isNotBlank()) return decoded
            }
        }

        DISPOSITION_FILENAME.find(header)?.let { match ->
            val quoted = match.groupValues.getOrNull(1)?.trim()
            val bare = match.groupValues.getOrNull(2)?.trim()
            val value = quoted?.takeIf { it.isNotBlank() } ?: bare
            if (!value.isNullOrBlank()) return percentDecode(value)
        }
        return null
    }

    fun fromUrl(url: String): String? {
        val path = try {
            java.net.URI(url).path ?: return null
        } catch (_: Throwable) {
            return null
        }
        val leaf = path.substringAfterLast('/').trim()
        if (leaf.isEmpty()) return null
        val decoded = percentDecode(leaf)
        return decoded.takeIf { it.isNotBlank() }
    }

    /** Appends a content-type derived extension when the name has none. */
    fun withExtension(name: String, contentType: String?): String {
        if (name.substringAfterLast('.', "").isNotBlank()) return name
        val mime = contentType?.substringBefore(';')?.trim()?.lowercase() ?: return name
        val ext = MIME_EXTENSIONS[mime] ?: return name
        return "$name.$ext"
    }

    fun sanitize(name: String): String {
        val cleaned = name
            .replace(Regex("[\\\\/:*?\"<>|\\x00-\\x1F]"), "_")
            .trim()
            .trimStart('.')
            .take(180)
        return if (cleaned.isBlank()) "meteora_download_${System.currentTimeMillis()}" else cleaned
    }

    private fun percentDecode(value: String): String {
        // URLDecoder treats '+' as a space; a filename may legitimately contain
        // a plus sign, so protect it before decoding.
        val protected = value.replace("+", "%2B")
        return try {
            URLDecoder.decode(protected, "UTF-8")
        } catch (_: Throwable) {
            value
        }
    }
}
