package dev.meteora.meteora.hardware

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.display.DisplayManager
import android.media.MediaCodecList
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.StatFs
import android.util.DisplayMetrics
import android.util.Log
import android.view.Display
import android.view.WindowManager

class DeviceCapabilityDetector(private val context: Context) {

    companion object {
        private const val TAG = "CapabilityDetector"
    }

    fun getCapabilities(): Map<String, Any> {
        var width = 1080
        var height = 2400
        var refreshRate = 60.0f

        try {
            if (context is Activity) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    val windowMetrics = context.windowManager.currentWindowMetrics
                    val bounds = windowMetrics.bounds
                    width = bounds.width()
                    height = bounds.height()
                    refreshRate = try {
                        context.display?.refreshRate ?: 60.0f
                    } catch (_: Throwable) {
                        60.0f
                    }
                } else {
                    val displayMetrics = DisplayMetrics()
                    @Suppress("DEPRECATION")
                    context.windowManager.defaultDisplay.getMetrics(displayMetrics)
                    width = displayMetrics.widthPixels
                    height = displayMetrics.heightPixels
                    @Suppress("DEPRECATION")
                    refreshRate = context.windowManager.defaultDisplay.refreshRate
                }
            } else {
                // Fallback for non-Activity context (e.g. background service or Application context)
                val displayManager = context.getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager
                val display = displayManager?.getDisplay(Display.DEFAULT_DISPLAY)
                if (display != null) {
                    val displayMetrics = DisplayMetrics()
                    @Suppress("DEPRECATION")
                    display.getRealMetrics(displayMetrics)
                    width = displayMetrics.widthPixels
                    height = displayMetrics.heightPixels
                    refreshRate = display.refreshRate
                }
            }
        } catch (e: Throwable) {
            Log.w(TAG, "Display inspection fallback: ${e.message}")
        }

        val supportedVideoCodecs = detectVideoCodecs()
        val supportedAudioCodecs = detectAudioCodecs()
        val freeBytes = getFreeStorageBytes()
        val isMetered = isNetworkMetered()
        val (batteryLevel, isCharging) = getBatteryStatus()

        return mapOf(
            "displayWidth" to width,
            "displayHeight" to height,
            "displayRefreshRate" to refreshRate.toDouble(),
            "supportedVideoCodecs" to supportedVideoCodecs,
            "supportedAudioCodecs" to supportedAudioCodecs,
            "freeStorageBytes" to freeBytes,
            "isMeteredNetwork" to isMetered,
            "batteryLevelPercent" to batteryLevel,
            "isCharging" to isCharging
        )
    }

    private fun detectVideoCodecs(): List<String> {
        return try {
            val list = MediaCodecList(MediaCodecList.REGULAR_CODECS)
            val codecs = mutableSetOf<String>()

            for (info in list.codecInfos) {
                if (info.isEncoder) continue
                for (type in info.supportedTypes) {
                    when (type.lowercase()) {
                        "video/av01" -> codecs.add("av1")
                        "video/x-vnd.on2.vp9" -> codecs.add("vp9")
                        "video/hevc" -> codecs.add("hevc")
                        "video/avc" -> codecs.add("h264")
                    }
                }
            }
            codecs.add("h264")
            codecs.toList()
        } catch (e: Throwable) {
            listOf("h264", "vp9", "av1", "hevc")
        }
    }

    private fun detectAudioCodecs(): List<String> {
        return try {
            val list = MediaCodecList(MediaCodecList.REGULAR_CODECS)
            val codecs = mutableSetOf<String>()

            for (info in list.codecInfos) {
                if (info.isEncoder) continue
                for (type in info.supportedTypes) {
                    when (type.lowercase()) {
                        "audio/opus" -> codecs.add("opus")
                        "audio/mp4a-latm" -> codecs.add("aac")
                        "audio/mpeg" -> codecs.add("mp3")
                        "audio/flac" -> codecs.add("flac")
                        "audio/vorbis" -> codecs.add("vorbis")
                    }
                }
            }
            codecs.addAll(listOf("aac", "opus", "mp3"))
            codecs.toList()
        } catch (e: Throwable) {
            listOf("aac", "opus", "mp3", "flac")
        }
    }

    private fun getFreeStorageBytes(): Long {
        return try {
            val stat = StatFs(context.filesDir.path)
            stat.availableBlocksLong * stat.blockSizeLong
        } catch (e: Throwable) {
            10L * 1024 * 1024 * 1024 // 10 GB fallback
        }
    }

    private fun isNetworkMetered(): Boolean {
        return try {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return false
            val activeNetwork = cm.activeNetwork ?: return false
            val capabilities = cm.getNetworkCapabilities(activeNetwork) ?: return false
            !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
        } catch (e: Throwable) {
            false
        }
    }

    private fun getBatteryStatus(): Pair<Int, Boolean> {
        return try {
            val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            val batteryStatus: Intent? = context.registerReceiver(null, filter)

            val level = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
            val batteryPct = if (level >= 0 && scale > 0) (level * 100 / scale) else 100

            val status = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                    status == BatteryManager.BATTERY_STATUS_FULL

            Pair(batteryPct, isCharging)
        } catch (e: Throwable) {
            Pair(100, true)
        }
    }
}
