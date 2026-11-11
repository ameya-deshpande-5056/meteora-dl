package dev.meteora.meteora

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.yausername.youtubedl_android.YoutubeDLRequest
import dev.meteora.meteora.engine.NativeEngineManager
import dev.meteora.meteora.hardware.DeviceCapabilityDetector
import dev.meteora.meteora.process.SafeProcessExecutor
import dev.meteora.meteora.service.DownloadForegroundService
import dev.meteora.meteora.storage.DownloadStorageManager
import dev.meteora.meteora.storage.MediaStoreHelper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {

    companion object {
        const val METHOD_CHANNEL = "dev.meteora/engine"
        const val EVENT_CHANNEL = "dev.meteora/downloads"
        private const val PERMISSION_REQUEST_CODE = 1002
        private const val DIR_PICKER_REQUEST_CODE = 1003
    }

    private var sharedUrl: String? = null
    private var pendingDirectoryResult: MethodChannel.Result? = null
    private var pendingPermissionsResult: MethodChannel.Result? = null
    private val scope = CoroutineScope(Dispatchers.Main)
    private val processExecutor = SafeProcessExecutor()
    private val storageManager by lazy { DownloadStorageManager(applicationContext) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
        scope.launch {
            NativeEngineManager.init(applicationContext)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val pending = pendingPermissionsResult
            pendingPermissionsResult = null
            pending?.success(buildPermissionStatusMap())
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == DIR_PICKER_REQUEST_CODE) {
            val pending = pendingDirectoryResult
            pendingDirectoryResult = null
            if (pending != null) {
                if (resultCode == Activity.RESULT_OK && data?.data != null) {
                    val info = storageManager.setCustomDownloadDirectory(data.data!!)
                    pending.success(info)
                } else {
                    pending.success(null)
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (!text.isNullOrBlank()) {
                sharedUrl = text
            }
        }
    }

    private fun requiredRuntimePermissions(): List<String> {
        val needed = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            needed.add(Manifest.permission.POST_NOTIFICATIONS)
            needed.add(Manifest.permission.READ_MEDIA_VIDEO)
            needed.add(Manifest.permission.READ_MEDIA_AUDIO)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            needed.add(Manifest.permission.READ_EXTERNAL_STORAGE)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            needed.add(Manifest.permission.READ_EXTERNAL_STORAGE)
            needed.add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        }
        return needed
    }

    private fun missingRuntimePermissions(): List<String> {
        return requiredRuntimePermissions().filter { perm ->
            ContextCompat.checkSelfPermission(this, perm) != PackageManager.PERMISSION_GRANTED
        }
    }

    private fun buildPermissionStatusMap(): Map<String, Boolean> {
        val missing = missingRuntimePermissions()
        val notificationsGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
        val storageGranted = missing.none { it != Manifest.permission.POST_NOTIFICATIONS }
        return mapOf(
            "notificationsGranted" to notificationsGranted,
            "storageGranted" to storageGranted,
            "allGranted" to missing.isEmpty(),
        )
    }

    private fun resolveCommand(rawCommand: List<String>): List<String> {
        if (rawCommand.isEmpty()) return rawCommand
        val first = rawCommand.first()
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val capabilityDetector = DeviceCapabilityDetector(this)
        val mediaStoreHelper = MediaStoreHelper(applicationContext)

        // 1. MethodChannel for RPC actions
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceCapabilities" -> {
                    scope.launch {
                        try {
                            val caps = capabilityDetector.getCapabilities()
                            result.success(caps)
                        } catch (e: Throwable) {
                            result.error("CAPABILITY_ERROR", e.localizedMessage ?: "Unknown error", null)
                        }
                    }
                }

                "isEngineInstalled" -> {
                    scope.launch {
                        if (!NativeEngineManager.isReady()) {
                            NativeEngineManager.init(applicationContext)
                        }
                        result.success(NativeEngineManager.isReady())
                    }
                }

                "getEngineVersion" -> {
                    result.success(NativeEngineManager.getVersion(applicationContext))
                }

                "updateEngine" -> {
                    scope.launch {
                        try {
                            val status = NativeEngineManager.update(applicationContext)
                            result.success(status)
                        } catch (e: Throwable) {
                            result.error("UPDATE_ERROR", e.localizedMessage ?: "Update failed", null)
                        }
                    }
                }

                "getPermissionStatus" -> {
                    result.success(buildPermissionStatusMap())
                }

                "requestPermissions" -> {
                    val missing = missingRuntimePermissions()
                    if (missing.isEmpty()) {
                        result.success(buildPermissionStatusMap())
                    } else {
                        pendingPermissionsResult?.success(buildPermissionStatusMap())
                        pendingPermissionsResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            missing.toTypedArray(),
                            PERMISSION_REQUEST_CODE,
                        )
                    }
                }

                "getInitialSharedUrl" -> {
                    result.success(sharedUrl)
                    sharedUrl = null
                }

                "executeExtraction" -> {
                    val command = call.argument<List<String>>("command")
                    if (command.isNullOrEmpty()) {
                        result.error("INVALID_ARGS", "Command list cannot be empty", null)
                        return@setMethodCallHandler
                    }

                    scope.launch {
                        try {
                            if (!NativeEngineManager.isReady()) {
                                val ok = NativeEngineManager.init(applicationContext)
                                if (!ok) {
                                    result.error("INIT_FAILED", "Failed to initialize embedded yt-dlp engine", null)
                                    return@launch
                                }
                            }

                            val args = if (command.first() == "yt-dlp") command.drop(1) else command
                            val request = YoutubeDLRequest(emptyList())
                            request.addCommands(args)

                            val response = NativeEngineManager.execute(request)
                            result.success(response.out)
                        } catch (e: Throwable) {
                            result.error("EXTRACTION_FAILED", e.localizedMessage ?: "Unknown error", null)
                        }
                    }
                }

                "startForegroundDownload" -> {
                    val taskId = call.argument<String>("taskId") ?: ""
                    val title = call.argument<String>("title") ?: "Downloading"
                    val command = call.argument<List<String>>("command") ?: emptyList()

                    val intent = Intent(applicationContext, DownloadForegroundService::class.java).apply {
                        action = DownloadForegroundService.ACTION_START
                        putExtra(DownloadForegroundService.EXTRA_TASK_ID, taskId)
                        putExtra(DownloadForegroundService.EXTRA_TITLE, title)
                        putStringArrayListExtra(DownloadForegroundService.EXTRA_COMMAND, ArrayList(command))
                    }
                    ContextCompat.startForegroundService(applicationContext, intent)
                    result.success(true)
                }

                "cancelDownload" -> {
                    val taskId = call.argument<String>("taskId") ?: ""
                    val intent = Intent(applicationContext, DownloadForegroundService::class.java).apply {
                        action = DownloadForegroundService.ACTION_CANCEL
                        putExtra(DownloadForegroundService.EXTRA_TASK_ID, taskId)
                    }
                    startService(intent)
                    result.success(true)
                }

                "publishToMediaStore" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    val displayName = call.argument<String>("displayName") ?: ""
                    val mimeType = call.argument<String>("mimeType") ?: "video/mp4"
                    val isVideo = call.argument<Boolean>("isVideo") ?: true

                    scope.launch {
                        val uri = mediaStoreHelper.publishToMediaStore(
                            sourceFile = File(filePath),
                            displayName = displayName,
                            mimeType = mimeType,
                            isVideo = isVideo
                        )
                        result.success(uri?.toString())
                    }
                }

                "getDownloadLocation" -> {
                    result.success(storageManager.getDownloadLocationInfo())
                }

                "pickDownloadDirectory" -> {
                    pendingDirectoryResult?.success(null)
                    pendingDirectoryResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                        addFlags(
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                                Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
                        )
                    }
                    try {
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, DIR_PICKER_REQUEST_CODE)
                    } catch (_: ActivityNotFoundException) {
                        pendingDirectoryResult = null
                        result.success(null)
                    }
                }

                "resetDownloadLocation" -> {
                    result.success(storageManager.resetToDefaultDirectory())
                }

                "playMedia" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    val title = call.argument<String>("title") ?: "Open with"
                    val isVideo = call.argument<Boolean>("isVideo") ?: true
                    val mimeTypeArg = call.argument<String>("mimeType")

                    if (filePath.isBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    try {
                        val uri = when {
                            filePath.startsWith("content://") -> Uri.parse(filePath)
                            filePath.startsWith("http://") || filePath.startsWith("https://") -> Uri.parse(filePath)
                            else -> {
                                val rawPath = if (filePath.startsWith("file://")) {
                                    Uri.parse(filePath).path ?: filePath
                                } else {
                                    filePath
                                }
                                val file = File(rawPath)
                                if (!file.exists()) {
                                    result.success(false)
                                    return@setMethodCallHandler
                                }
                                FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                            }
                        }

                        val resolvedMime = mimeTypeArg?.takeIf { it.isNotBlank() }
                            ?: DownloadStorageManager.resolveOpenMimeType(contentResolver, uri, filePath, isVideo)

                        val viewIntent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, resolvedMime)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            clipData = ClipData.newRawUri(title, uri)
                            putExtra("title", title)
                        }

                        val chooser = Intent.createChooser(viewIntent, "Open with").apply {
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(chooser)
                        result.success(true)
                    } catch (_: ActivityNotFoundException) {
                        result.success(false)
                    } catch (e: Throwable) {
                        result.error("OPEN_MEDIA_ERROR", e.localizedMessage ?: "Failed to open external player", null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        // 2. EventChannel for streaming live download progress
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    DownloadForegroundService.progressListener = { eventMap ->
                        scope.launch {
                            events?.success(eventMap)
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    DownloadForegroundService.progressListener = null
                }
            }
        )
    }
}
