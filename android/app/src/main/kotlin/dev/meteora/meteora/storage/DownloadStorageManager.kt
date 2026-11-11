package dev.meteora.meteora.storage

import android.content.ContentResolver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.util.Log
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

data class PublishedFileResult(
    val uriOrPath: String,
    val sizeBytes: Long,
    val mimeType: String,
)

class DownloadStorageManager(private val context: Context) {

    companion object {
        private const val TAG = "DownloadStorageManager"
        private const val PREFS_NAME = "meteora_storage_prefs"
        private const val KEY_TREE_URI = "custom_tree_uri"
        private const val KEY_DISPLAY_PATH = "custom_display_path"
        const val DEFAULT_DISPLAY_PATH = "Internal Storage/Download/MeteoraDL"

        fun sanitizeFilename(name: String): String {
            val cleaned = name.replace(Regex("[\\\\/:*?\"<>|\\x00-\\x1F]"), "_").trim()
            return if (cleaned.isEmpty() || cleaned == "." || cleaned == "..") {
                "meteora_download_${System.currentTimeMillis()}"
            } else {
                cleaned
            }
        }

        fun resolveSystemCompatibleMimeType(fileName: String): String {
            val ext = fileName.substringAfterLast('.', "").lowercase()
            val systemMime = if (ext.isNotEmpty()) {
                MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
            } else {
                null
            }
            if (!systemMime.isNullOrBlank()) return systemMime
            return when (ext) {
                "mkv" -> "video/x-matroska"
                "webm" -> "video/webm"
                "m4a" -> "audio/mp4"
                "opus" -> "audio/opus"
                "ogg", "oga" -> "audio/ogg"
                "flac" -> "audio/flac"
                "srt" -> "application/x-subrip"
                "vtt" -> "text/vtt"
                "ass", "ssa" -> "text/x-ssa"
                else -> "application/octet-stream"
            }
        }

        fun resolveOpenMimeType(
            contentResolver: ContentResolver,
            uri: Uri,
            filePath: String,
            isVideo: Boolean,
        ): String {
            if (uri.scheme == "content") {
                val resolved = contentResolver.getType(uri)
                if (!resolved.isNullOrBlank() && resolved != "application/octet-stream") {
                    return resolved
                }
            }

            val ext = filePath.substringAfterLast('.', "").lowercase()
            if (ext.isNotEmpty()) {
                val mime = resolveSystemCompatibleMimeType(filePath)
                if (mime != "application/octet-stream") {
                    return mime
                }
            }

            return if (isVideo) "video/*" else "audio/*"
        }

        fun isSubtitleFile(fileName: String): Boolean {
            val ext = fileName.substringAfterLast('.', "").lowercase()
            return ext in setOf("srt", "vtt", "ass", "ssa", "ttml", "lrc")
        }

        fun formatDisplayPathFromTreeUri(treeUri: Uri): String {
            return try {
                val docId = DocumentsContract.getTreeDocumentId(treeUri)
                val colonIndex = docId.indexOf(':')
                if (colonIndex >= 0) {
                    val volume = docId.substring(0, colonIndex)
                    val relative = docId.substring(colonIndex + 1).trimStart('/')
                    val volumeLabel = when {
                        volume.equals("primary", ignoreCase = true) -> "Internal Storage"
                        volume.equals("home", ignoreCase = true) -> "Documents"
                        else -> "Storage ($volume)"
                    }
                    if (relative.isEmpty()) volumeLabel else "$volumeLabel/$relative"
                } else {
                    docId.ifBlank { treeUri.lastPathSegment ?: DEFAULT_DISPLAY_PATH }
                }
            } catch (_: Throwable) {
                treeUri.lastPathSegment ?: DEFAULT_DISPLAY_PATH
            }
        }
    }

    private val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun getDownloadLocationInfo(): Map<String, Any?> {
        val validUri = getValidCustomTreeUri()
        return if (validUri != null) {
            val savedPath = prefs.getString(KEY_DISPLAY_PATH, null)
                ?: formatDisplayPathFromTreeUri(validUri)
            mapOf(
                "isCustom" to true,
                "displayPath" to savedPath,
                "uri" to validUri.toString(),
            )
        } else {
            mapOf(
                "isCustom" to false,
                "displayPath" to DEFAULT_DISPLAY_PATH,
                "uri" to null,
            )
        }
    }

    fun setCustomDownloadDirectory(treeUri: Uri): Map<String, Any?> {
        val resolver = context.contentResolver
        val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        try {
            resolver.takePersistableUriPermission(treeUri, flags)
        } catch (e: SecurityException) {
            Log.w(TAG, "Failed to persist tree URI permission for $treeUri", e)
        }

        val displayPath = formatDisplayPathFromTreeUri(treeUri)
        prefs.edit()
            .putString(KEY_TREE_URI, treeUri.toString())
            .putString(KEY_DISPLAY_PATH, displayPath)
            .apply()

        return getDownloadLocationInfo()
    }

    fun resetToDefaultDirectory(): Map<String, Any?> {
        val oldUriStr = prefs.getString(KEY_TREE_URI, null)
        if (!oldUriStr.isNullOrBlank()) {
            try {
                val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                context.contentResolver.releasePersistableUriPermission(Uri.parse(oldUriStr), flags)
            } catch (_: Throwable) {
                // Ignore if permission was already revoked or not persisted
            }
        }
        prefs.edit()
            .remove(KEY_TREE_URI)
            .remove(KEY_DISPLAY_PATH)
            .apply()

        return getDownloadLocationInfo()
    }

    private fun getValidCustomTreeUri(): Uri? {
        val uriStr = prefs.getString(KEY_TREE_URI, null) ?: return null
        val treeUri = Uri.parse(uriStr)
        val hasPersistedPermission = context.contentResolver.persistedUriPermissions.any { perm ->
            perm.uri == treeUri && perm.isWritePermission
        }
        if (!hasPersistedPermission) {
            prefs.edit().remove(KEY_TREE_URI).remove(KEY_DISPLAY_PATH).apply()
            return null
        }
        return treeUri
    }

    suspend fun publishFile(sourceFile: File): PublishedFileResult? = withContext(Dispatchers.IO) {
        if (!sourceFile.exists() || !sourceFile.isFile) return@withContext null

        val safeName = sanitizeFilename(sourceFile.name)
        val mimeType = resolveSystemCompatibleMimeType(safeName)
        val sizeBytes = sourceFile.length()

        val customTreeUri = getValidCustomTreeUri()
        if (customTreeUri != null) {
            val safResult = publishToSafTree(customTreeUri, sourceFile, safeName, mimeType, sizeBytes)
            if (safResult != null) {
                return@withContext safResult
            }
            Log.w(TAG, "SAF write failed for $customTreeUri; falling back to default public Downloads folder")
        }

        publishToDefaultPublicFolder(sourceFile, safeName, mimeType, sizeBytes)
    }

    private fun publishToSafTree(
        treeUri: Uri,
        sourceFile: File,
        safeName: String,
        mimeType: String,
        sizeBytes: Long,
    ): PublishedFileResult? {
        val resolver = context.contentResolver
        return try {
            val docId = DocumentsContract.getTreeDocumentId(treeUri)
            val parentDocUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)

            // Prevent Android ExternalStorageProvider from appending a duplicate extension
            // when MimeTypeMap maps a MIME type to a different extension string.
            val ext = safeName.substringAfterLast('.', "").lowercase()
            val mappedExt = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType)?.lowercase()
            val safMimeType = if (mappedExt == null || mappedExt == ext) {
                mimeType
            } else {
                "application/x-meteora-media"
            }

            val targetUri = DocumentsContract.createDocument(resolver, parentDocUri, safMimeType, safeName)
                ?: return null

            resolver.openOutputStream(targetUri)?.use { outputStream ->
                FileInputStream(sourceFile).use { inputStream ->
                    inputStream.copyTo(outputStream)
                }
            } ?: run {
                try {
                    DocumentsContract.deleteDocument(resolver, targetUri)
                } catch (_: Throwable) {}
                return null
            }

            PublishedFileResult(
                uriOrPath = targetUri.toString(),
                sizeBytes = sizeBytes,
                mimeType = mimeType,
            )
        } catch (e: Throwable) {
            Log.e(TAG, "Error publishing file to custom SAF directory", e)
            null
        }
    }

    private fun publishToDefaultPublicFolder(
        sourceFile: File,
        safeName: String,
        mimeType: String,
        sizeBytes: Long,
    ): PublishedFileResult? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = context.contentResolver
            val downloadsUri = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val relativePath = Environment.DIRECTORY_DOWNLOADS

            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, safeName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }

            val itemUri = resolver.insert(downloadsUri, values) ?: return null

            return try {
                resolver.openOutputStream(itemUri)?.use { outputStream ->
                    FileInputStream(sourceFile).use { inputStream ->
                        inputStream.copyTo(outputStream)
                    }
                } ?: throw IllegalStateException("Failed to open output stream for $itemUri")

                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(itemUri, values, null, null)

                triggerMediaScanForUri(itemUri, mimeType)

                PublishedFileResult(
                    uriOrPath = itemUri.toString(),
                    sizeBytes = sizeBytes,
                    mimeType = mimeType,
                )
            } catch (e: Throwable) {
                Log.e(TAG, "Failed writing to MediaStore.Downloads", e)
                try {
                    resolver.delete(itemUri, null, null)
                } catch (_: Throwable) {}
                null
            }
        } else {
            @Suppress("DEPRECATION")
            val targetDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!targetDir.exists() && !targetDir.mkdirs()) {
                return null
            }

            val destFile = resolveCollisionFreeFile(targetDir, safeName)
            return try {
                FileInputStream(sourceFile).use { input ->
                    FileOutputStream(destFile).use { output ->
                        input.copyTo(output)
                    }
                }
                MediaScannerConnection.scanFile(
                    context,
                    arrayOf(destFile.absolutePath),
                    arrayOf(mimeType),
                    null,
                )
                PublishedFileResult(
                    uriOrPath = destFile.absolutePath,
                    sizeBytes = sizeBytes,
                    mimeType = mimeType,
                )
            } catch (e: Throwable) {
                Log.e(TAG, "Failed writing to legacy public Downloads folder", e)
                null
            }
        }
    }

    private fun triggerMediaScanForUri(uri: Uri, mimeType: String) {
        try {
            context.contentResolver.query(
                uri,
                arrayOf(MediaStore.MediaColumns.DATA),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val colIdx = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
                    if (colIdx >= 0) {
                        val realPath = cursor.getString(colIdx)
                        if (!realPath.isNullOrBlank()) {
                            MediaScannerConnection.scanFile(
                                context,
                                arrayOf(realPath),
                                arrayOf(mimeType),
                                null,
                            )
                        }
                    }
                }
            }
        } catch (_: Throwable) {
            // Best-effort scan; MediaStore entry is already valid
        }
    }

    private fun resolveCollisionFreeFile(dir: File, fileName: String): File {
        var candidate = File(dir, fileName)
        if (!candidate.exists()) return candidate

        val dotIdx = fileName.lastIndexOf('.')
        val base = if (dotIdx > 0) fileName.substring(0, dotIdx) else fileName
        val ext = if (dotIdx > 0) fileName.substring(dotIdx) else ""

        var counter = 1
        while (candidate.exists()) {
            candidate = File(dir, "$base ($counter)$ext")
            counter++
        }
        return candidate
    }
}
