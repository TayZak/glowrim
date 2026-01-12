import SwiftUI

struct PowerButton: View {
    @Bindable var settings: LightSettings

    @State private var isPressed = false
    @State private var pulseScale: CGFloat = 1.0

    private let size: CGFloat = Constants.powerButtonSize

    var body: some View {
        Button(action: togglePower) {
            ZStack {
                // Outer glow when enabled
                if settings.isEnabled {
                    Circle()
                        .fill(settings.color.opacity(0.3))
                        .frame(width: size + 20, height: size + 20)
                        .blur(radius: 10)
                        .scaleEffect(pulseScale)
                }

                // Main button circle
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                settings.isEnabled ? settings.color : Color.gray.opacity(0.3),
                                settings.isEnabled ? settings.color.opacity(0.7) : Color.gray.opacity(0.2)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .shadow(
                        color: settings.isEnabled ? settings.color.opacity(0.5) : .clear,
                        radius: 15,
                        x: 0,
                        y: 5
                    )

                // Inner circle (button face)
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.2),
                                Color.clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                    .frame(width: size - 10, height: size - 10)

                // Power icon
                Image(systemName: "power")
                    .font(.system(size: size * 0.35, weight: .medium))
                    .foregroundColor(settings.isEnabled ? .white : .gray)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(
            minimumDuration: 0,
            pressing: { pressing in
                isPressed = pressing
            },
            perform: {}
        )
        .onAppear {
            startPulseAnimation()
        }
        .accessibilityLabel(settings.isEnabled ? "Turn off ring light" : "Turn on ring light")
        .accessibilityHint("Double tap to toggle the ring light")
    }

    private func togglePower() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            settings.toggle()
        }

        // Haptic-like visual feedback
        if settings.isEnabled {
            withAnimation(.easeOut(duration: 0.3)) {
                pulseScale = 1.2
            }
            withAnimation(.easeIn(duration: 0.2).delay(0.3)) {
                pulseScale = 1.0
            }
        }

        // Notify ring window controller
        if settings.isEnabled {
            RingLightWindowController.shared.show()
        } else {
            RingLightWindowController.shared.hide()
        }
    }

    private func startPulseAnimation() {
        guard settings.isEnabled else { return }

        withAnimation(
            .easeInOut(duration: 2)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.05
        }
    }
}

#Preview {
    PowerButton(settings: LightSettings.shared)
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
}
