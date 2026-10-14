# GlowRim

A native macOS screen light for video calls. A soft, click-through contour lights your face while leaving the center of the display clear.

## Features

- A standalone control window, Dock icon, and menu bar controls. Launching opens the window; clicking the Dock icon reopens it.
- Real HDR/EDR rendering through Metal: a transparent `rgba16Float` surface in extended linear sRGB, with RGB values above SDR white. Brightness follows the selected display’s current EDR headroom. SDR displays work at standard brightness.
- Stable light or organic breathing: a soft inhale, a longer exhale, and a short rest. Intensity, width, and diffusion expand together; broad soft curves keep the inner contour from looking rigid.
- Automatic resource scaling on battery, in Low Power Mode, and under thermal pressure. The renderer only shades the halo, uses two small FP16 drawables, and stops redrawing a stable light until something changes.
- Five color presets and the native macOS color picker.
- Display selection, including external screens; disconnecting a selected display falls back to the primary screen.
- Settings saved automatically. Light and blackout always start off on launch.
- **⌥⌘L** toggles the light globally without Accessibility or Input Monitoring permissions. The window reports a shortcut conflict if another app already registered it.
- Optional low-battery pause below 15% on battery power, and automatic breathing after five minutes of stable lighting.
- Optional black background: move the pointer or click to dismiss it. Escape also dismisses it when GlowRim is focused.
- Light turns off when the Mac or display sleeps, or the session becomes inactive. It respects Reduce Motion.

The HDR pipeline follows [Apple’s EDR rendering guidance](https://developer.apple.com/documentation/metal/performing-your-own-tone-mapping).

## Requirements

macOS 14 or later and a Metal-capable Mac. An HDR-capable screen, such as the mini-LED Liquid Retina XDR display in compatible MacBook Pro models, is required for extended brightness. Actual brightness varies with display settings, power, temperature, and macOS’s available EDR headroom; GlowRim does not promise a fixed nit level.

## Build and test

Open `GlowRim.xcodeproj` in Xcode, or run:

```sh
./scripts/build.sh
```

The local ad hoc signed app is produced at `build/Build/Products/Release/GlowRim.app`.

```sh
./scripts/check.sh
```

Checks cover persistence and invalid values, offscreen Metal FP16 output, alpha/center transparency, SDR, blackout, rounded corners, breath timing and spatial shape, exact pixel agreement between the optimized bands and a full reference render, adaptive budgets, idle rendering, and the actual overlay’s power transitions. The overlay lifecycle check briefly shows the light on the primary screen.

See [rendering measurements and resource policy](docs/performance.md) for the 1.1/1.2 comparison. Run `./scripts/profile.sh Tests/Fixtures/Rim-1.1.metal` for a local Release-speed benchmark.

The icon is generated from resolution-independent AppKit artwork. Regenerate all asset sizes with `swift scripts/generate-icon.swift`.

## Usage

Open the app, choose your display and tint, then click **Allumer la lumière**. The contour is click-through and appears across Spaces, including supported fullscreen app spaces. Closing the control window keeps the app running; use **⌘Q** to quit. Use the Dock or menu bar to bring the controls back.

## Privacy

No network access, analytics, camera use, or data collection. No permissions are required for lighting or the shortcut.

## License

[MIT](LICENSE). Created by Thibault Bazin.
