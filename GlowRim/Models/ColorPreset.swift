import SwiftUI

struct ColorPreset: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let red: Double
    let green: Double
    let blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: 1.0)
    }

    static let warm = ColorPreset(
        id: "warm",
        name: "Chaud",
        red: 1.0,
        green: 0.85,
        blue: 0.7
    )

    static let cool = ColorPreset(
        id: "cool",
        name: "Froid",
        red: 0.85,
        green: 0.92,
        blue: 1.0
    )

    static let daylight = ColorPreset(
        id: "daylight",
        name: "Jour",
        red: 1.0,
        green: 0.98,
        blue: 0.95
    )

    static let goldenHour = ColorPreset(
        id: "golden",
        name: "Doré",
        red: 1.0,
        green: 0.78,
        blue: 0.45
    )

    static let sunset = ColorPreset(
        id: "sunset",
        name: "Soleil",
        red: 1.0,
        green: 0.55,
        blue: 0.35
    )

    static let custom = ColorPreset(
        id: "custom",
        name: "Libre",
        red: 1.0,
        green: 1.0,
        blue: 1.0
    )

    static let allPresets: [ColorPreset] = [
        .warm, .cool, .daylight, .goldenHour, .sunset, .custom
    ]
}
