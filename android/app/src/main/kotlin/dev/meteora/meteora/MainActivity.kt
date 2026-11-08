package dev.meteora.meteora

import android.content.Intent
import android.os.Bundle
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
    }

    private var sharedUrl: String? = null
    private val scope = CoroutineScope(Dispatchers.Main)
    private val processExecutor = SafeProcessExecutor()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val capabilityDetector = DeviceCapabilityDetector(this)
        val mediaStoreHelper = MediaStoreHelper(applicationContext)

        // 1. MethodChannel for RPC actions
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceCapabilities" -> {
                    val caps = capabilityDetector.getCapabilities()
                    result.success(caps)
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
                            val execResult = processExecutor.execute(command, filesDir)
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
