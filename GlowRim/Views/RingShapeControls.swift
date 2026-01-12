import SwiftUI

struct RingShapeControls: View {
    @Bindable var settings: LightSettings

    var body: some View {
        VStack(spacing: 12) {
            // Ring Width
            SliderControl(
                label: "Ring Width",
                value: $settings.ringWidth,
                range: 10...200,
                unit: "pt"
            ) {
                RingLightWindowController.shared.updateSettings()
            }

            // Corner Radius
            SliderControl(
                label: "Corner Radius",
                value: Binding(
                    get: { settings.cornerRadius * 100 },
                    set: { settings.cornerRadius = $0 / 100 }
                ),
                range: 0...50,
                unit: "%"
            ) {
                RingLightWindowController.shared.updateSettings()
            }

            // Brightness
            SliderControl(
                label: "Brightness",
                value: Binding(
                    get: { settings.brightness * 100 },
                    set: { settings.brightness = $0 / 100 }
                ),
                range: 20...100,
                unit: "%"
            ) {
                RingLightWindowController.shared.updateSettings()
            }

            // Softness
            SliderControl(
                label: "Softness",
                value: $settings.softness,
                range: 0...50,
                unit: "px"
            ) {
                RingLightWindowController.shared.updateSettings()
            }
        }
    }
}

struct SliderControl: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    let onChange: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(value))\(unit)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            Slider(value: $value, in: range)
                .tint(LightSettings.shared.color)
                .onChange(of: value) { _, _ in
                    onChange()
                }
        }
    }
}

#Preview {
    RingShapeControls(settings: LightSettings.shared)
        .padding()
        .frame(width: 350)
        .background(Color(NSColor.windowBackgroundColor))
}
