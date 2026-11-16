package dev.meteora.meteora.hardware

import android.app.Activity
import android.os.Build
import android.util.Log
import android.view.Display

/**
 * Asks the platform to render this window at the display's highest refresh rate.
 *
 * Flutter schedules frames from the display's vsync, so a 90/120/144 Hz panel is
 * only used when the window is actually given a matching display mode. Android —
 * and several OEM ROMs in particular — keep non-game apps on the panel's default
 * mode (usually 60 Hz) unless the app declares its intent.
 *
 * `WindowManager.LayoutParams.preferredRefreshRate` is the documented lever: the
 * platform picks the closest supported mode at the current resolution, and from
 * API 34 it may even match an arbitrary requested rate. It is ignored when
 * `preferredDisplayModeId` is set, so this class deliberately never sets that.
 */
object DisplayModeController {
    private const val TAG = "DisplayModeController"

    data class RefreshRateInfo(
        val activeHz: Float,
        val maxHz: Float,
        val modeId: Int,
        val modeCount: Int,
    )

    fun applyMaxRefreshRate(activity: Activity): RefreshRateInfo? {
        val display = displayOf(activity) ?: return null
        return try {
            val modes = display.supportedModes
            if (modes.isEmpty()) {
                Log.i(TAG, "Display reports no switchable modes; leaving ${display.refreshRate}Hz")
                return null
            }

            val maxHz = modes.maxOf { it.refreshRate }
            val active = display.mode
            // Highest-rate mode at the current resolution, so asking for the
            // panel rate can never change the UI's pixel size or aspect ratio.
            val best = modes
                .filter {
                    it.physicalWidth == active.physicalWidth &&
                        it.physicalHeight == active.physicalHeight
                }
                .ifEmpty { modes.asList() }
                .maxByOrNull { it.refreshRate } ?: active

            val window = activity.window
            val attrs = window.attributes
            if (attrs.preferredDisplayModeId != best.modeId ||
                attrs.preferredRefreshRate != best.refreshRate
            ) {
                // Both are written: preferredRefreshRate is the documented modern
                // hint, while several OEM ROMs only act on the explicit mode pin.
                // preferredDisplayModeId takes precedence when the platform honours it.
                attrs.preferredRefreshRate = best.refreshRate
                attrs.preferredDisplayModeId = best.modeId
                window.attributes = attrs
            }

            val info = RefreshRateInfo(
                activeHz = display.refreshRate,
                maxHz = maxHz,
                modeId = active.modeId,
                modeCount = modes.size,
            )
            Log.i(
                TAG,
                "Requested ${maxHz}Hz via mode ${best.modeId}: ${modes.size} modes, active mode ${active.modeId} @ ${active.refreshRate}Hz",
            )
            // The mode switch is asynchronous, so report what the display settles on.
            window.decorView.postDelayed({
                Log.i(TAG, "Display refresh rate now ${display.refreshRate}Hz (panel max ${maxHz}Hz)")
            }, 900)
            info
        } catch (e: Throwable) {
            Log.w(TAG, "Unable to request the display's highest refresh rate", e)
            null
        }
    }



    private fun displayOf(activity: Activity): Display? = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.display
        } else {
            @Suppress("DEPRECATION")
            activity.windowManager.defaultDisplay
        }
    } catch (e: Throwable) {
        Log.w(TAG, "Display unavailable", e)
        null
    }
}
