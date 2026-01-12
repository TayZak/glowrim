import SwiftUI
import Combine

@Observable
final class LightSettings {
    static let shared = LightSettings()

    // MARK: - Published State

    var isEnabled: Bool = false {
        didSet { saveSettings() }
    }

    var mode: LightMode = .constant {
        didSet { saveSettings() }
    }

    var intensity: Double = 0.8 {
        didSet {
            intensity = max(0.2, min(1.0, intensity))
            saveSettings()
        }
    }

    var red: Double = 1.0 {
        didSet { saveSettings() }
    }

    var green: Double = 0.95 {
        didSet { saveSettings() }
    }

    var blue: Double = 0.9 {
        didSet { saveSettings() }
    }

    var animationSpeed: Double = 1.0 {
        didSet {
            animationSpeed = max(0.5, min(2.0, animationSpeed))
            saveSettings()
        }
    }

    var selectedPresetId: String = "warm" {
        didSet { saveSettings() }
    }

    // MARK: - Ring Shape Parameters

    /// Ring width in points (10-200)
    var ringWidth: Double = 60 {
        didSet {
            ringWidth = Swift.max(10, Swift.min(200, ringWidth))
            saveSettings()
        }
    }

    /// Corner radius as percentage of screen size (0-50%)
    var cornerRadius: Double = 0.05 {
        didSet {
            cornerRadius = Swift.max(0, Swift.min(0.5, cornerRadius))
            saveSettings()
        }
    }

    /// Brightness/intensity (0.2-1.0)
    var brightness: Double = 0.8 {
        didSet {
            brightness = Swift.max(0.2, Swift.min(1.0, brightness))
            saveSettings()
        }
    }

    /// Softness/blur of the glow (0-50)
    var softness: Double = 15 {
        didSet {
            softness = Swift.max(0, Swift.min(50, softness))
            saveSettings()
        }
    }

    // MARK: - Computed Properties

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: 1.0)
    }

    var hdrIntensity: Double {
        // Map 0.2-1.0 to 0.5-4.0 for HDR (higher values = brighter on HDR displays)
        let normalized = (intensity - 0.2) / 0.8
        return 0.5 + normalized * 3.5
    }

    // MARK: - Initialization

    private init() {
        loadSettings()
    }

    // MARK: - Persistence

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let isEnabled = "glowrim.isEnabled"
        static let mode = "glowrim.mode"
        static let intensity = "glowrim.intensity"
        static let red = "glowrim.red"
        static let green = "glowrim.green"
        static let blue = "glowrim.blue"
        static let animationSpeed = "glowrim.animationSpeed"
        static let selectedPresetId = "glowrim.selectedPresetId"
        static let ringWidth = "glowrim.ringWidth"
        static let cornerRadius = "glowrim.cornerRadius"
        static let brightness = "glowrim.brightness"
        static let softness = "glowrim.softness"
    }

    private func loadSettings() {
        if defaults.object(forKey: Keys.isEnabled) != nil {
            isEnabled = defaults.bool(forKey: Keys.isEnabled)
        }

        if let modeString = defaults.string(forKey: Keys.mode),
           let savedMode = LightMode(rawValue: modeString) {
            mode = savedMode
        }

        if defaults.object(forKey: Keys.intensity) != nil {
            intensity = defaults.double(forKey: Keys.intensity)
        }

        if defaults.object(forKey: Keys.red) != nil {
            red = defaults.double(forKey: Keys.red)
        }

        if defaults.object(forKey: Keys.green) != nil {
            green = defaults.double(forKey: Keys.green)
        }

        if defaults.object(forKey: Keys.blue) != nil {
            blue = defaults.double(forKey: Keys.blue)
        }

        if defaults.object(forKey: Keys.animationSpeed) != nil {
            animationSpeed = defaults.double(forKey: Keys.animationSpeed)
        }

        if let presetId = defaults.string(forKey: Keys.selectedPresetId) {
            selectedPresetId = presetId
        }

        if defaults.object(forKey: Keys.ringWidth) != nil {
            ringWidth = defaults.double(forKey: Keys.ringWidth)
        }

        if defaults.object(forKey: Keys.cornerRadius) != nil {
            cornerRadius = defaults.double(forKey: Keys.cornerRadius)
        }

        if defaults.object(forKey: Keys.brightness) != nil {
            brightness = defaults.double(forKey: Keys.brightness)
        }

        if defaults.object(forKey: Keys.softness) != nil {
            softness = defaults.double(forKey: Keys.softness)
        }
    }

    private func saveSettings() {
        defaults.set(isEnabled, forKey: Keys.isEnabled)
        defaults.set(mode.rawValue, forKey: Keys.mode)
        defaults.set(intensity, forKey: Keys.intensity)
        defaults.set(red, forKey: Keys.red)
        defaults.set(green, forKey: Keys.green)
        defaults.set(blue, forKey: Keys.blue)
        defaults.set(animationSpeed, forKey: Keys.animationSpeed)
        defaults.set(selectedPresetId, forKey: Keys.selectedPresetId)
        defaults.set(ringWidth, forKey: Keys.ringWidth)
        defaults.set(cornerRadius, forKey: Keys.cornerRadius)
        defaults.set(brightness, forKey: Keys.brightness)
        defaults.set(softness, forKey: Keys.softness)
    }

    // MARK: - Actions

    func toggle() {
        isEnabled.toggle()
    }

    func applyPreset(_ preset: ColorPreset) {
        red = preset.red
        green = preset.green
        blue = preset.blue
        selectedPresetId = preset.id
    }

    func setColor(_ color: Color) {
        if let components = NSColor(color).usingColorSpace(.deviceRGB) {
            red = Double(components.redComponent)
            green = Double(components.greenComponent)
            blue = Double(components.blueComponent)
            selectedPresetId = "custom"
        }
    }
}
