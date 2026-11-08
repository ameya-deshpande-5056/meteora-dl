package dev.meteora.meteora.engine

import android.content.Context
import android.util.Log
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLException
import com.yausername.youtubedl_android.YoutubeDLRequest
import com.yausername.youtubedl_android.YoutubeDLResponse
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

object NativeEngineManager {
    private const val TAG = "NativeEngineManager"
    private val mutex = Mutex()

    @Volatile
    private var isInitialized = false

    suspend fun init(context: Context): Boolean = withContext(Dispatchers.IO) {
        if (isInitialized) return@withContext true
        mutex.withLock {
            if (isInitialized) return@withLock true
            try {
                Log.i(TAG, "Initializing embedded Python & yt-dlp runtime...")
                YoutubeDL.getInstance().init(context.applicationContext)
                Log.i(TAG, "Initializing embedded FFmpeg binaries...")
                FFmpeg.getInstance().init(context.applicationContext)
                isInitialized = true
                val ver = getVersion(context)
                Log.i(TAG, "Native yt-dlp engine ($ver) & FFmpeg initialized successfully.")
                true
            } catch (e: Throwable) {
                Log.e(TAG, "Failed to initialize embedded media engine", e)
                false
            }
        }
    }

    fun isReady(): Boolean = isInitialized

    fun getVersion(context: Context): String {
        return try {
            YoutubeDL.getInstance().version(context.applicationContext) ?: "yt-dlp embedded"
        } catch (e: Throwable) {
            "yt-dlp"
        }
    }

    suspend fun update(context: Context): String = withContext(Dispatchers.IO) {
        try {
            if (!isInitialized) {
                init(context)
            }
            val status = YoutubeDL.getInstance().updateYoutubeDL(
                context.applicationContext,
                YoutubeDL.UpdateChannel.STABLE
            )
            status?.name ?: "UNKNOWN"
        } catch (e: Throwable) {
            Log.e(TAG, "Update yt-dlp failed", e)
            throw e
        }
    }

    suspend fun execute(
        request: YoutubeDLRequest,
        processId: String? = null,
        callback: ((Float, Long, String) -> Unit)? = null
    ): YoutubeDLResponse = withContext(Dispatchers.IO) {
        if (processId != null && callback != null) {
            YoutubeDL.getInstance().execute(request, processId) { progress, etaInSeconds, line ->
                callback(progress, etaInSeconds, line)
            }
        } else if (processId != null) {
            YoutubeDL.getInstance().execute(request, processId)
        } else {
            YoutubeDL.getInstance().execute(request)
        }
    }

    fun cancel(processId: String): Boolean {
        return try {
            YoutubeDL.getInstance().destroyProcessById(processId)
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to cancel process $processId", e)
            false
        }
    }
}
