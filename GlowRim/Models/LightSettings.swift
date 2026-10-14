import SwiftUI

/// One source of truth for the window, menu bar, shortcuts, and renderer.
@Observable
final class LightSettings {
    static let shared = LightSettings()
    static let changed = Notification.Name("GlowRimSettingsChanged")

    // Power and blackout are session-only: launching must never cover the screen.
    var isEnabled = false { didSet { changedSettings() } }
    var blackScreen = false { didSet { changedSettings() } }
    var mode: LightMode = .constant { didSet { changedSettings() } }
    var intensity = 0.8 { didSet { let value = Self.clamp(intensity, 0.2...1); if intensity != value { intensity = value; return }; changedSettings() } }
    var red = 1.0 { didSet { let value = Self.clamp(red, 0...1); if red != value { red = value; return }; changedSettings() } }
    var green = 0.95 { didSet { let value = Self.clamp(green, 0...1); if green != value { green = value; return }; changedSettings() } }
    var blue = 0.9 { didSet { let value = Self.clamp(blue, 0...1); if blue != value { blue = value; return }; changedSettings() } }
    var animationSpeed = 1.0 { didSet { let value = Self.clamp(animationSpeed, 0.5...2); if animationSpeed != value { animationSpeed = value; return }; changedSettings() } }
    var selectedPresetId = "warm" { didSet { changedSettings() } }
    var ringWidth = 35.0 { didSet { let value = Self.clamp(ringWidth, 10...200); if ringWidth != value { ringWidth = value; return }; changedSettings() } }
    var cornerRadius = 0.035 { didSet { let value = Self.clamp(cornerRadius, 0...0.5); if cornerRadius != value { cornerRadius = value; return }; changedSettings() } }
    var softness = 40.0 { didSet { let value = Self.clamp(softness, 0...80); if softness != value { softness = value; return }; changedSettings() } }
    var hdrEnabled = true { didSet { changedSettings() } }
    var selectedDisplayID = "" { didSet { changedSettings() } }
    var batteryProtection = true { didSet { changedSettings() } }
    var autoBreathing = true { didSet { changedSettings() } }
    var brightness: Double { get { intensity } set { intensity = newValue } }
    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: 1) }
    var nsColor: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: 1) }

    private let defaults: UserDefaults
    private var isLoading = true
    private var saveTask: DispatchWorkItem?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func number(_ key: String, _ fallback: Double) -> Double {
            defaults.object(forKey: "glowrim." + key) == nil ? fallback : defaults.double(forKey: "glowrim." + key)
        }
        mode = LightMode(rawValue: defaults.string(forKey: "glowrim.mode") ?? "constant") ?? .constant
        intensity = Self.clamp(number("intensity", number("brightness", 0.8)), 0.2...1)
        red = Self.clamp(number("red", 1), 0...1)
        green = Self.clamp(number("green", 0.95), 0...1)
        blue = Self.clamp(number("blue", 0.9), 0...1)
        animationSpeed = Self.clamp(number("animationSpeed", 1), 0.5...2)
        ringWidth = Self.clamp(number("ringWidth", 35), 10...200)
        cornerRadius = Self.clamp(number("cornerRadius", 0.035), 0...0.5)
        softness = Self.clamp(number("softness", 40), 0...80)
        selectedPresetId = defaults.string(forKey: "glowrim.selectedPresetId") ?? "warm"
        selectedDisplayID = defaults.string(forKey: "glowrim.selectedDisplayID") ?? ""
        hdrEnabled = defaults.object(forKey: "glowrim.hdrEnabled") as? Bool ?? true
        batteryProtection = defaults.object(forKey: "glowrim.batteryProtection") as? Bool ?? true
        autoBreathing = defaults.object(forKey: "glowrim.autoBreathing") as? Bool ?? true
        isLoading = false
    }

    private static func clamp(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : range.lowerBound
    }

    private func changedSettings() {
        guard !isLoading else { return }
        NotificationCenter.default.post(name: Self.changed, object: self)
        saveTask?.cancel()
        let task = DispatchWorkItem { [weak self] in self?.saveSettings() }
        saveTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: task)
    }

    func saveSettings() {
        let values: [String: Any] = ["mode": mode.rawValue, "intensity": intensity,
            "red": red, "green": green, "blue": blue, "animationSpeed": animationSpeed,
            "selectedPresetId": selectedPresetId, "ringWidth": ringWidth,
            "cornerRadius": cornerRadius, "softness": softness, "hdrEnabled": hdrEnabled,
            "selectedDisplayID": selectedDisplayID, "batteryProtection": batteryProtection,
            "autoBreathing": autoBreathing]
        for (key, value) in values { defaults.set(value, forKey: "glowrim." + key) }
    }

    func toggle() { isEnabled.toggle() }
    func applyPreset(_ preset: ColorPreset) {
        red = preset.red; green = preset.green; blue = preset.blue
        selectedPresetId = preset.id
    }
    func setColor(_ color: Color) {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return }
        red = rgb.redComponent; green = rgb.greenComponent; blue = rgb.blueComponent
        selectedPresetId = "custom"
    }
    func resetAppearance() {
        intensity = 0.8; ringWidth = 35; softness = 40; cornerRadius = 0.035
        mode = .constant; animationSpeed = 1; hdrEnabled = true
        applyPreset(.daylight)
    }
}
