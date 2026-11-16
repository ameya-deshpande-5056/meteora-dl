# Wavy Progress Indicator Specification (Morphe & MicroG RE Architecture)

## 1. Context & Origin
In **Morphe Manager** (`MorpheApp/morphe-manager`, `WavyProgress.kt`) and **MicroG RE** (`MorpheApp/MicroG-RE`), the wavy progress indicators are built on Google's **Material 3 Expressive** design specification (`androidx.compose.material3.LinearWavyProgressIndicator` and `CircularWavyProgressIndicator`).

Prior implementations suffered from a critical divergence: they rendered a wavy track and clipped it, which produced unnatural wave segments and artificial floating edge dots.

In contrast, the authentic Morphe / MicroG RE / M3 Expressive implementation operates on these principles:
1. **The Track is FLAT**: The background track is a clean, straight horizontal line (at $y = \text{centerY}$) rendered in `trackColor` (`surfaceContainerHighest`) with `StrokeCap.round`.
2. **The Active Indicator is WAVY**: Only the active completed progress portion undulates in a sinusoidal waveform.
3. **Quadratic Bezier Curve Plotting**: Rather than stepping through individual pixels, the wave is constructed using alternating quadratic Bezier control points:
   $$\text{anchorX} += \frac{\text{wavelength}}{2}, \quad \text{controlX} += \frac{\text{wavelength}}{2}, \quad \text{controlY} = \pm(\text{height} - \text{strokeWidth}) \times \text{amplitude}$$
   This creates an authentic, harmonic sine wave that never clips or exceeds the container boundary.
4. **Physical Gap (`LinearIndicatorTrackGapSize = 4.dp`)**: A distinct gap separates the rounded tip of the active wavy progress from the straight background track.
5. **No Stop Dot (`stopSize = 0.dp`)**: Morphe explicitly sets `stopSize = 0.dp` to eliminate the trailing end-dot for visual elegance and parity between linear and circular progress.
6. **Morphe Standard Dimensions**:
   - `BarStrokeWidth`: `6.dp`
   - `BarHeight`: `16.dp`
   - `RingStrokeWidth`: `10.dp` (for circular progress rings)
   - `LinearDeterminateWavelength`: `24.dp`
   - `LinearIndeterminateWavelength`: `20.dp`
   - `GapSize`: `4.dp`

---

## 2. States & Behavior

### 2.1 Determinate Progress ($0.0 \le \text{progress} \le 1.0$)
- **At 0.0**: Only the flat straight track is visible from start to end with rounded caps.
- **Between 0.0 and 1.0**:
  - The wave path is sampled from $x = \text{capRadius}$ to $x = \text{filledWidth}$.
  - The track is drawn as a flat line from $x = \text{filledWidth} + \text{gapSize} + \text{capRadius}$ to $x = \text{width} - \text{capRadius}$.
  - Both segments end in rounded caps (`StrokeCap.round`).
- **At 1.0**: The full wave spans the entire width; the track is completely hidden.

### 2.2 Indeterminate Progress ($\text{progress} = \text{null}$)
- The flat track runs across the entire width.
- An expressive wavy wave pulse travels smoothly from left to right across the track.
- The wave pulse undulates while traveling, with `gapSize` clearing the flat track on both sides.
- If accessibility reduced motion is enabled (`MediaQuery.disableAnimations`), falls back cleanly to a linear bar.

### 2.3 Circular Wavy Progress Ring (`CircularWavyProgressIndicator` / `WavyProgressRing`)
- Matches Morphe's `WavyProgressRing`:
  - `strokeWidth = 10.dp`
  - Wavy sinusoidal circular arc with `trackColor = surfaceContainerHighest`
  - Smooth clockwise sweep and wave translation
