package dev.meteora.meteora

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import dev.meteora.meteora.hardware.DeviceCapabilityDetector
import dev.meteora.meteora.process.SafeProcessExecutor
import dev.meteora.meteora.service.DownloadForegroundService
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
    }

    private var sharedUrl: String? = null
    private val scope = CoroutineScope(Dispatchers.Main)
    private val processExecutor = SafeProcessExecutor()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
        checkAndRequestPermissions()
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

    private fun checkAndRequestPermissions() {
        val permissionsToRequest = mutableListOf<String>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.POST_NOTIFICATIONS)
            }
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_VIDEO) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.READ_MEDIA_VIDEO)
            }
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.READ_MEDIA_AUDIO)
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
            }
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.READ_EXTERNAL_STORAGE)
            }
        }

        if (permissionsToRequest.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, permissionsToRequest.toTypedArray(), PERMISSION_REQUEST_CODE)
        }
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
                    val candidate = File(filesDir, "packages/active/ytdlp/yt-dlp")
                    result.success(candidate.exists() && candidate.canExecute())
                }

                "requestPermissions" -> {
                    checkAndRequestPermissions()
                    result.success(true)
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

                    val resolvedCommand = resolveCommand(command)
                    val executableFile = File(resolvedCommand.first())
                    if (!executableFile.isAbsolute && !File("/system/bin/${resolvedCommand.first()}").exists()) {
                        val candidate = File(filesDir, "packages/active/ytdlp/yt-dlp")
                        if (!candidate.exists()) {
                            result.error(
                                "ENGINE_NOT_INSTALLED",
                                "yt-dlp binary is not installed in app storage.",
                                null
                            )
                            return@setMethodCallHandler
                        }
                    }

                    scope.launch {
                        try {
                            val execResult = processExecutor.execute(resolvedCommand, filesDir)
                            if (execResult.exitCode == 0) {
                                result.success(execResult.output)
                            } else {
                                val err = execResult.errorMessage ?: "Exit code ${execResult.exitCode}: ${execResult.output}"
                                result.error("EXTRACTION_FAILED", err, null)
                            }
                        } catch (e: Throwable) {
                            result.error("EXECUTION_ERROR", e.localizedMessage ?: "Unknown error", null)
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

                "playMedia" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    val title = call.argument<String>("title") ?: "Media Playback"
                    val isVideo = call.argument<Boolean>("isVideo") ?: true

                    val intent = Intent(this, dev.meteora.meteora.player.PlayerActivity::class.java).apply {
                        putExtra(dev.meteora.meteora.player.PlayerActivity.EXTRA_MEDIA_PATH, filePath)
                        putExtra(dev.meteora.meteora.player.PlayerActivity.EXTRA_MEDIA_TITLE, title)
                        putExtra(dev.meteora.meteora.player.PlayerActivity.EXTRA_IS_VIDEO, isVideo)
                    }
                    startActivity(intent)
                    result.success(true)
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
