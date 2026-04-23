# Spirit Level

A clean, minimal spirit level app for iOS built with SwiftUI and CoreMotion.

## Features

- **Bull's eye level** -- when the device is lying flat on its back, a circular bubble level shows tilt in both axes with spring-physics animation.
- **Tube level** -- when the device is held upright, a single horizontal bubble level measures roll (landscape) or pitch (portrait).
- **Live angle readout** -- large monospaced display shows the current angle in degrees, rounded to one decimal place.
- **Adaptive layout** -- automatically switches between portrait and landscape, adjusting graphics and typography to fit.
- **Zero calibration** -- tap the ZERO button to set any surface as your reference level; tap again to reset.
- **Haptic feedback** -- a subtle vibration fires when the device crosses the level threshold.
- **Colour-coded feedback** -- green when level, transitioning through yellow to red as tilt increases.
- **Scene-aware** -- motion updates pause when the app is backgrounded to save battery.

## Requirements

- iOS 16.0+
- Xcode 14+
- Physical device (CoreMotion does not function in the Simulator)

## Setup

1. Create a new SwiftUI project in Xcode (App template, SwiftUI lifecycle).
2. Replace the contents of your main app file with the code from this project.
3. In your target settings, ensure both **Portrait** and **Landscape Left** / **Landscape Right** orientations are enabled under **Deployment Info > Device Orientation**.
4. Build and run on a physical device.

No external dependencies, packages, or additional configuration required.

## Usage

### Flat mode (device on its back)

Lay the device flat on any surface. The bull's eye level appears with a green bubble that drifts toward the centre when the surface is level. The angle readout shows the total tilt magnitude.

### Upright mode (device held in hand)

Hold the device upright. A single tube level appears:

- **Portrait** -- measures pitch (forward and back tilt).
- **Landscape** -- measures roll (left and right lean).

The bubble drifts toward the centre mark when the axis is level. The signed angle readout indicates direction and magnitude.

### Calibration

Tap the **ZERO** button in the top-right corner to set the current orientation as the zero reference. This is useful when you need to measure relative angles from a surface that is not perfectly level. Tap again to reset to the device's absolute reference.

## Architecture

| Component | Responsibility |
|---|---|
| `MotionManager` | Wraps `CMMotionManager`, publishes angle data, handles flat/upright detection with hysteresis, and manages zero calibration. |
| `ContentView` | Adaptive layout that switches between bull's eye and tube level based on device orientation. |
| `BullseyeLevel` | Circular bubble level with concentric rings, crosshair, and radial-gradient bubble. |
| `TubeLevel` | Horizontal capsule level with graduation marks and colour-coded bubble. |
| `StatusBadge` | Compact pill showing LEVEL or degree offset with colour transition. |

### Angle calculation

- **Flat mode** -- angles derived from gravity vector components relative to the Z axis using `atan2`.
- **Upright mode** -- angles derived from the attitude rotation matrix (`m21`/`m22` vs `m23`), which provides accurate readings regardless of whether the device is in portrait, landscape, or any intermediate orientation.

### Flat detection

The app monitors the gravity Z component with hysteresis (threshold at -0.85 to enter flat, -0.7 to leave) to prevent flickering at the transition angle. Calibration resets automatically when switching between modes.

## Design

- **Typography** -- DM Mono for all text, ultra-light weight for the main readout.
- **Colour palette** -- dark background (`#08080C`) with a green-to-red spectrum driven by tilt magnitude.
- **Motion** -- spring-based bubble physics (`stiffness: 150, damping: 14`) for natural feel.
- **Texture** -- subtle grid overlay at 2% opacity for depth.

## Licence

MIT
