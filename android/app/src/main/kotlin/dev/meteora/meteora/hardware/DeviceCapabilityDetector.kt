package dev.meteora.meteora.hardware

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.MediaCodecList
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.StatFs
import android.util.DisplayMetrics
import android.view.WindowManager

class DeviceCapabilityDetector(private val context: Context) {

    fun getCapabilities(): Map<String, Any> {
        val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val displayMetrics = DisplayMetrics()
        
        val width: Int
        val height: Int
        val refreshRate: Float

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val currentWindowMetrics = windowManager.currentWindowMetrics
            val bounds = currentWindowMetrics.bounds
            width = bounds.width()
            height = bounds.height()
            refreshRate = context.display?.refreshRate ?: 60.0f
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getMetrics(displayMetrics)
            width = displayMetrics.widthPixels
            height = displayMetrics.heightPixels
            @Suppress("DEPRECATION")
            refreshRate = windowManager.defaultDisplay.refreshRate
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
        // Universal fallback
        codecs.add("h264")
        return codecs.toList()
    }

    private fun detectAudioCodecs(): List<String> {
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
        return codecs.toList()
    }

    private fun getFreeStorageBytes(): Long {
        val stat = StatFs(context.filesDir.path)
        return stat.availableBlocksLong * stat.blockSizeLong
    }

    private fun isNetworkMetered(): Boolean {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return false
        val activeNetwork = cm.activeNetwork ?: return false
        val capabilities = cm.getNetworkCapabilities(activeNetwork) ?: return false

        return !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
    }

    private fun getBatteryStatus(): Pair<Int, Boolean> {
        val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        val batteryStatus: Intent? = context.registerReceiver(null, filter)

        val level = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val batteryPct = if (level >= 0 && scale > 0) (level * 100 / scale) else 100

        val status = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                status == BatteryManager.BATTERY_STATUS_FULL

        return Pair(batteryPct, isCharging)
    }
}
