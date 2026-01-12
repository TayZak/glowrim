import SwiftUI

struct IntensitySlider: View {
    @Bindable var settings: LightSettings

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Intensity")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(settings.intensity * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Image(systemName: "sun.min")
                    .font(.caption)
                    .foregroundColor(.secondary)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Track background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .frame(height: 8)

                        // Filled portion
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        settings.color.opacity(0.5),
                                        settings.color
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: filledWidth(for: geometry.size.width), height: 8)

                        // Thumb
                        Circle()
                            .fill(settings.color)
                            .frame(width: 20, height: 20)
                            .shadow(color: settings.color.opacity(0.5), radius: 4)
                            .offset(x: thumbOffset(for: geometry.size.width))
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        updateIntensity(for: value.location.x, in: geometry.size.width)
                                    }
                            )
                    }
                }
                .frame(height: 20)

                Image(systemName: "sun.max.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Intensity: \(Int(settings.intensity * 100)) percent")
        .accessibilityValue("\(Int(settings.intensity * 100)) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                settings.intensity = min(1.0, settings.intensity + 0.1)
            case .decrement:
                settings.intensity = max(0.2, settings.intensity - 0.1)
            @unknown default:
                break
            }
            RingLightWindowController.shared.updateSettings()
        }
    }

    private func filledWidth(for totalWidth: CGFloat) -> CGFloat {
        let normalizedValue = (settings.intensity - 0.2) / 0.8
        return totalWidth * normalizedValue
    }

    private func thumbOffset(for totalWidth: CGFloat) -> CGFloat {
        let normalizedValue = (settings.intensity - 0.2) / 0.8
        return (totalWidth - 20) * normalizedValue
    }

    private func updateIntensity(for x: CGFloat, in width: CGFloat) {
        let clampedX = max(0, min(width, x))
        let normalizedValue = clampedX / width
        let intensity = 0.2 + normalizedValue * 0.8

        withAnimation(.interactiveSpring()) {
            settings.intensity = intensity
        }

        RingLightWindowController.shared.updateSettings()
        BurnInProtection.shared.resetTimer()
    }
}

#Preview {
    IntensitySlider(settings: LightSettings.shared)
        .padding()
        .frame(width: 350)
        .background(Color(NSColor.windowBackgroundColor))
}
