import SwiftUI

struct ColorWheelView: View {
    @Bindable var settings: LightSettings

    @State private var hue: Double = 0.1
    @State private var saturation: Double = 0.1
    @State private var brightness: Double = 1.0

    private let wheelSize: CGFloat = 120

    var body: some View {
        VStack(spacing: 12) {
            Text("Color")
                .font(.caption)
                .foregroundColor(.secondary)

            ZStack {
                // Color wheel
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color(hue: 0.0, saturation: 0.8, brightness: 1.0),
                                Color(hue: 0.1, saturation: 0.8, brightness: 1.0),
                                Color(hue: 0.2, saturation: 0.8, brightness: 1.0),
                                Color(hue: 0.3, saturation: 0.8, brightness: 1.0),
                                Color(hue: 0.4, saturation: 0.8, brightness: 1.0),
                                Color(hue: 0.5, saturation: 0.8, brightness: 1.0),
                                Color(hue: 0.6, saturation: 0.8, brightness: 1.0),
                                Color(hue: 0.7, saturation: 0.8, brightness: 1.0),
                                Color(hue: 0.8, saturation: 0.8, brightness: 1.0),
                                Color(hue: 0.9, saturation: 0.8, brightness: 1.0),
                                Color(hue: 1.0, saturation: 0.8, brightness: 1.0)
                            ]),
                            center: .center
                        )
                    )
                    .frame(width: wheelSize, height: wheelSize)
                    .mask(
                        Circle()
                            .strokeBorder(lineWidth: 20)
                    )

                // Saturation overlay (radial gradient from center)
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.white,
                                Color.white.opacity(0)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: wheelSize / 2
                        )
                    )
                    .frame(width: wheelSize, height: wheelSize)
                    .allowsHitTesting(false)

                // Center preview
                Circle()
                    .fill(settings.color)
                    .frame(width: wheelSize - 50, height: wheelSize - 50)
                    .shadow(color: settings.color.opacity(0.5), radius: 8)

                // Selection indicator
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 16, height: 16)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .offset(selectorOffset)
            }
            .frame(width: wheelSize, height: wheelSize)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleColorSelection(at: value.location)
                    }
            )
            .onAppear {
                syncFromSettings()
            }

            // Brightness slider
            HStack(spacing: 8) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $brightness, in: 0.3...1.0)
                    .tint(settings.color)
                    .onChange(of: brightness) { _, newValue in
                        updateSettingsColor()
                    }

                Image(systemName: "circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Color picker")
    }

    private var selectorOffset: CGSize {
        let radius = (wheelSize / 2) - 10
        let angle = hue * 2 * .pi - .pi / 2
        let distance = radius * saturation

        return CGSize(
            width: Foundation.cos(angle) * distance,
            height: Foundation.sin(angle) * distance
        )
    }

    private func handleColorSelection(at point: CGPoint) {
        let center = CGPoint(x: wheelSize / 2, y: wheelSize / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y

        // Calculate hue from angle
        var angle = atan2(dy, dx)
        if angle < 0 {
            angle += 2 * .pi
        }
        hue = angle / (2 * .pi)

        // Calculate saturation from distance
        let distance = sqrt(dx * dx + dy * dy)
        let maxDistance = wheelSize / 2
        saturation = min(1.0, distance / maxDistance)

        updateSettingsColor()
    }

    private func updateSettingsColor() {
        let color = Color(hue: hue, saturation: saturation, brightness: brightness)
        settings.setColor(color)
        RingLightWindowController.shared.updateSettings()
    }

    private func syncFromSettings() {
        let hsb = settings.color.hsbComponents
        hue = hsb.hue
        saturation = hsb.saturation
        brightness = hsb.brightness
    }
}

#Preview {
    ColorWheelView(settings: LightSettings.shared)
        .padding()
        .frame(width: 350)
        .background(Color(NSColor.windowBackgroundColor))
}
