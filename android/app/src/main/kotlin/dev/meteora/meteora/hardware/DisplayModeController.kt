package dev.meteora.meteora.hardware

import android.app.Activity
import android.os.Build
import android.util.Log
import android.view.Display
import android.view.Surface
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup

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

            val surfaceApplied = applyFlutterSurfaceFrameRate(activity, maxHz)
            if (!surfaceApplied) {
                // Flutter's SurfaceView is usually not attached yet on create/resume;
                // retry once the first frame exists so the surface hint lands too.
                window.decorView.postDelayed({
                    val applied = applyFlutterSurfaceFrameRate(activity, maxHz)
                    Log.i(
                        TAG,
                        if (applied) "Surface frame rate set to ${maxHz}Hz" else "Surface frame rate still unavailable",
                    )
                }, 1200)
            }

            val info = RefreshRateInfo(
                activeHz = display.refreshRate,
                maxHz = maxHz,
                modeId = active.modeId,
                modeCount = modes.size,
            )
            Log.i(
                TAG,
                "Requested ${maxHz}Hz via mode ${best.modeId}: ${modes.size} modes, active mode ${active.modeId} @ ${active.refreshRate}Hz, surface frame rate ${if (surfaceApplied) "set" else "unavailable"}",
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

    /**
     * Flutter renders into a `SurfaceView`, whose buffer is produced on its own
     * surface: the window's `preferredRefreshRate` alone is not always enough for
     * the platform to pick a high mode. `Surface.setFrameRate` (API 30+) is the
     * documented hint for content that owns its surface, so set it as well.
     */
    private fun applyFlutterSurfaceFrameRate(activity: Activity, maxHz: Float): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
        return try {
            val surfaceView = findSurfaceView(activity.window.decorView) ?: return false
            val surface = surfaceView.holder.surface
            if (surface == null || !surface.isValid) {
                Log.i(TAG, "Flutter surface not ready yet; window preference stands alone")
                return false
            }
            // A pure vsync hint lets the platform stay on the panel default when
            // it considers a switch "not seamless"; the UI is always animated, so
            // ask for the mode change outright.
            surface.setFrameRate(
                maxHz,
                Surface.FRAME_RATE_COMPATIBILITY_DEFAULT,
                Surface.CHANGE_FRAME_RATE_ALWAYS,
            )
            true
        } catch (e: Throwable) {
            Log.w(TAG, "Unable to set the surface frame rate", e)
            false
        }
    }

    private fun findSurfaceView(view: View): SurfaceView? {
        if (view is SurfaceView) return view
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                findSurfaceView(view.getChildAt(index))?.let { return it }
            }
        }
        return null
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
