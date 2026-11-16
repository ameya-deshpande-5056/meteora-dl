# Material 3 Expressive Component Specifications (Morphe Architecture)

## 1. ConnectedShapes Primitive
```
ConnectedShapes
  variants  inRow (leading, middle, trailing, single), inColumn (top, middle, bottom, single)
  radii     outer: 20dp (card) or 999dp (pill), inner: 4dp
  behavior  Seamless visual grouping where adjoining items share 4dp subtle inner corners,
            giving multiple items the appearance of a single, coherent segmented surface.
```

## 2. SettingsGroup / Inset Grouped SurfaceCard
```
SettingsGroup
  variants  Grouped container holding 1..N items
  layout    Column with 2dp gaps between items (SegmentGap)
  items     Each item is a SurfaceCard styled via ConnectedShapes.inColumn(index, count)
  tokens    bg: surfaceContainerLow / surfaceContainer, border: outlineVariant (alpha 0.25)
  states    default, pressed (ink splash with rounded shape), focused (focus ring)
  used on   SettingsScreen, Home Format Selectors, Library Filters
```

## 3. ConnectedButtonGroup
```
ConnectedButtonGroup
  variants  Pill segmented button row (e.g. Video+Audio / Video / Audio / Subs)
  sizes     height 44px
  tokens    active bg: primaryContainer, active text: onPrimaryContainer, inactive bg: surfaceContainerHigh
  shapes    ConnectedShapes.Pill.inRow(index, count)
  motion    Smooth spring indicator / container morph
  used on   HomeScreen download mode switcher
```

## 4. HeaderBar & HeaderTitle
```
HeaderBar
  variants  Large header with Wordmark/Title, Subtitle, and Trailing Action Icons
  tokens    title font: headerTitle (20sp, weight 600, line height 26sp)
            leading/trailing icon containers: 40x40 squircle, primaryContainer / secondaryContainer
  motion    Collapsible or pinned with subtle elevation on scroll
  used on   All primary app screens
```

## 5. StatusBadge & ThemedIconContainer
```
StatusBadge
  variants  Compact status indicators: Success, Downloading, Waiting, Error, Paused
  tokens    background: tonal container (e.g., successContainer, primaryContainer, errorContainer)
            content: matching on-container high contrast color
  radius    Pill (999dp) or Squircle (10dp)
  used on   Download task items, Playlist cards, Hardware Diagnostic tiles
```

## 6. WavyProgressIndicator
```
WavyProgressIndicator
  variants  Indeterminate traveling wave, Determinate filling wave
  tokens    strokeWidth: 3.5dp, amplitude: 3dp, wavelength: 26dp, cycle: 1600ms
  a11y      Falls back to plain linear progress indicator when reduce-motion is active
  used on   Stream analysis on HomeScreen, Active download cards on DownloadsScreen
```
