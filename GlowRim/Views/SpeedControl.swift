import SwiftUI

struct SpeedControl: View {
    @Bindable var settings: LightSettings

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Animation Speed")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(speedLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Image(systemName: "tortoise")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(
                    value: $settings.animationSpeed,
                    in: Constants.minAnimationSpeed...Constants.maxAnimationSpeed,
                    step: 0.1
                )
                .tint(settings.color)
                .onChange(of: settings.animationSpeed) { _, _ in
                    RingLightWindowController.shared.updateSettings()
                }

                Image(systemName: "hare")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .opacity(settings.mode == .constant ? 0.4 : 1.0)
        .disabled(settings.mode == .constant)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Animation speed: \(speedLabel)")
        .accessibilityValue(speedLabel)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                settings.animationSpeed = min(Constants.maxAnimationSpeed, settings.animationSpeed + 0.1)
            case .decrement:
                settings.animationSpeed = max(Constants.minAnimationSpeed, settings.animationSpeed - 0.1)
            @unknown default:
                break
            }
        }
    }

    private var speedLabel: String {
        let value = settings.animationSpeed
        if value < 0.7 {
            return "Slow"
        } else if value < 1.3 {
            return "Normal"
        } else {
            return "Fast"
        }
    }
}

#Preview {
    SpeedControl(settings: LightSettings.shared)
        .padding()
        .frame(width: 350)
        .background(Color(NSColor.windowBackgroundColor))
}
