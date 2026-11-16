package dev.meteora.meteora.engine

import android.content.Context
import android.util.Log
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLException
import com.yausername.youtubedl_android.YoutubeDLRequest
import com.yausername.youtubedl_android.YoutubeDLResponse
import java.io.File
import java.net.Inet4Address
import java.net.NetworkInterface
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

object NativeEngineManager {
    private const val TAG = "NativeEngineManager"
    private val mutex = Mutex()

    @Volatile
    private var isInitialized = false

    @Volatile
    private var cacheDirPath: String? = null

    @Volatile
    private var jsRuntime: JsRuntimeResolver.Runtime? = null

    suspend fun init(context: Context): Boolean = withContext(Dispatchers.IO) {
        if (isInitialized) return@withContext true
        mutex.withLock {
            if (isInitialized) return@withLock true
            try {
                Log.i(TAG, "Initializing embedded Python & yt-dlp runtime...")
                YoutubeDL.getInstance().init(context.applicationContext)
                Log.i(TAG, "Initializing embedded FFmpeg binaries...")
                FFmpeg.getInstance().init(context.applicationContext)
                // Persist the remote component cache so it is not evicted like
                // normal Android cache data between app launches.
                val cacheDir = File(context.applicationContext.filesDir, "ytdlp-cache")
                if (!cacheDir.exists()) {
                    cacheDir.mkdirs()
                }
                cacheDirPath = cacheDir.absolutePath
                jsRuntime = JsRuntimeResolver.resolve(context.applicationContext)
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

    /** Clears the official EJS remote-component cache for a fresh next fetch. */
    suspend fun refreshEjsComponents(context: Context): Boolean = withContext(Dispatchers.IO) {
        mutex.withLock {
            val cacheDir = File(context.applicationContext.filesDir, "ytdlp-cache")
            try {
                if (cacheDir.exists() && !cacheDir.deleteRecursively()) {
                    Log.w(TAG, "Unable to clear yt-dlp remote-component cache")
                    return@withLock false
                }
                if (!cacheDir.exists() && !cacheDir.mkdirs()) {
                    Log.w(TAG, "Unable to recreate yt-dlp remote-component cache")
                    return@withLock false
                }
                cacheDirPath = cacheDir.absolutePath
                true
            } catch (e: Throwable) {
                Log.e(TAG, "Unable to refresh EJS components", e)
                false
            }
        }
    }

    private fun hasActiveIpv4Interface(): Boolean {
        return try {
            val interfaces = NetworkInterface.getNetworkInterfaces() ?: return false
            while (interfaces.hasMoreElements()) {
                val iface = interfaces.nextElement()
                if (!iface.isUp || iface.isLoopback) continue
                val addrs = iface.inetAddresses
                while (addrs.hasMoreElements()) {
                    val addr = addrs.nextElement()
                    if (addr is Inet4Address && !addr.isLoopbackAddress) {
                        return true
                    }
                }
            }
            false
        } catch (_: Throwable) {
            false
        }
    }

    private fun applyRuntimeDefaults(request: YoutubeDLRequest) {
        cacheDirPath?.let { path ->
            if (!request.hasOption("--cache-dir")) {
                request.addOption("--cache-dir", path)
            }
        }
        if (!request.hasOption("--remote-components")) {
            request.addOption("--remote-components", "ejs:github")
        }
        // EJS challenge solving needs a real JavaScript runtime. yt-dlp only
        // enables deno by default, so the bundled QuickJS CLI must be enabled
        // explicitly with its exact path.
        jsRuntime?.let { runtime ->
            if (!request.hasOption("--js-runtimes") && !request.hasOption("--no-js-runtimes")) {
                val runtimeArg = "${runtime.kind.cliName}:${runtime.path}"
                request.addOption("--js-runtimes", runtimeArg)
                Log.i(TAG, "EJS runtime enabled: --js-runtimes $runtimeArg")
            }
        }
        if (!request.hasOption("--force-ipv4") && !request.hasOption("-4") && hasActiveIpv4Interface()) {
            request.addOption("--force-ipv4")
        }
    }

    suspend fun execute(
        request: YoutubeDLRequest,
        processId: String? = null,
        callback: ((Float, Long, String) -> Unit)? = null
    ): YoutubeDLResponse = withContext(Dispatchers.IO) {
        applyRuntimeDefaults(request)
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

    /** Snapshot of the JavaScript runtime used for EJS, for Settings + diagnostics. */
    fun getJsRuntimeInfo(): Map<String, Any?> {
        val runtime = jsRuntime
        return if (runtime == null) {
            mapOf(
                "available" to false,
                "name" to null,
                "path" to null,
                "version" to null,
            )
        } else {
            mapOf(
                "available" to true,
                "name" to runtime.kind.cliName,
                "path" to runtime.path,
                "version" to runtime.version,
            )
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
