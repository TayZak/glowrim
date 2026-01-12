# GlowRim

Native macOS HDR ring light that displays **over all applications** (including fullscreen) for FaceTime, Zoom, and selfies on MacBook OLED Retina displays.

## Features

- **HDR Peak Brightness** - Up to 1600 nits on MacBook Pro XDR displays
- **Overlay Mode** - Displays above all apps including fullscreen video calls
- **2 Lighting Modes**:
  - **Constant** - Fixed intensity (20-100%)
  - **Pulsating** - Anti burn-in oscillation (100% -> 85% -> 95% -> 80%)
- **Menu Bar Integration** - Quick access from the top right corner
- **Global Hotkey** - Cmd+Option+L toggles the ring light from anywhere
- **Smart Protection** - Auto-pause when battery < 15%, anti burn-in after 5 minutes
- **Color Presets** - Warm, Cool, Daylight, Golden Hour, Sunset, Custom RGB

## Requirements

- macOS 14.0+ (Sonoma or later)
- Apple Silicon (M1, M2, M3, M4)
- HDR display recommended (MacBook Pro with XDR display)

## Installation

### From GitHub Releases
1. Download the latest `.dmg` from [Releases](https://github.com/yourusername/glowrim/releases)
2. Drag GlowRim to Applications
3. Open GlowRim from Applications
4. Grant accessibility permissions when prompted (required for global hotkey)

### Build from Source
1. Clone this repository
2. Open `GlowRim.xcodeproj` in Xcode 15+
3. Build and run (Cmd+R)

## Usage

1. Click the GlowRim icon in the menu bar (circle icon near the clock)
2. Toggle the ring light with the central power button
3. Select a lighting mode (Constant or Pulsating)
4. Adjust intensity, color, and animation speed as needed
5. Use **Cmd+Option+L** to quickly toggle from any app

## How It Works

GlowRim creates a borderless, transparent window at a high window level that floats above all other applications, including those in fullscreen mode. The ring is rendered using Core Animation and Metal for smooth 120fps animations and HDR brightness support.

The transparent center ensures your FaceTime camera remains visible while the luminous ring provides soft, even lighting for your face.

## Privacy & Permissions

GlowRim requires **Accessibility** permissions to register the global hotkey (Cmd+Option+L). No data is collected or transmitted.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## Author

Created by Thibault Bazin
