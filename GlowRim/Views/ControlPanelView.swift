import SwiftUI
import AppKit

struct ControlPanelView: View {
    @State private var isEnabled = false
    @State private var ringWidth: Double = 25
    @State private var brightness: Double = 80
    @State private var softness: Double = 40
    @State private var selectedColorIndex: Int = 0
    @State private var isBreathingEnabled = true
    @State private var isBlackScreenEnabled = false

    // Performance settings
    @State private var fps: Double = 18

    // 8 color presets
    private let colorPresets: [(String, Color, NSColor)] = [
        ("White", .white, .white),
        ("Warm White", Color(red: 1, green: 0.95, blue: 0.9), NSColor(red: 1, green: 0.95, blue: 0.9, alpha: 1)),
        ("Soft Yellow", Color(red: 1, green: 0.92, blue: 0.7), NSColor(red: 1, green: 0.92, blue: 0.7, alpha: 1)),
        ("Golden", Color(red: 1, green: 0.85, blue: 0.5), NSColor(red: 1, green: 0.85, blue: 0.5, alpha: 1)),
        ("Orange", .orange, .orange),
        ("Warm Orange", Color(red: 1, green: 0.6, blue: 0.3), NSColor(red: 1, green: 0.6, blue: 0.3, alpha: 1)),
        ("Sunset", Color(red: 1, green: 0.45, blue: 0.25), NSColor(red: 1, green: 0.45, blue: 0.25, alpha: 1)),
        ("Red", Color(red: 1, green: 0.3, blue: 0.2), NSColor(red: 1, green: 0.3, blue: 0.2, alpha: 1))
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Header
                HStack {
                    Text("GlowRim")
                        .font(.headline)
                    Spacer()
                }

                // Power button
                Button(action: { togglePower() }) {
                    ZStack {
                        Circle()
                            .fill(isEnabled ? colorPresets[selectedColorIndex].1 : Color.gray.opacity(0.3))
                            .frame(width: 70, height: 70)

                        Image(systemName: "power")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)

                Text(isEnabled ? "ON" : "OFF")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                // Breathing toggle
                Toggle(isOn: $isBreathingEnabled) {
                    HStack {
                        Image(systemName: "wind")
                            .foregroundColor(isBreathingEnabled ? .blue : .secondary)
                        Text("Breathing")
                            .font(.subheadline)
                    }
                }
                .toggleStyle(.switch)
                .tint(.blue)

                // Black screen toggle (for mini-LED)
                Toggle(isOn: $isBlackScreenEnabled) {
                    HStack {
                        Image(systemName: "rectangle.fill")
                            .foregroundColor(isBlackScreenEnabled ? .blue : .secondary)
                        Text("Black Screen")
                            .font(.subheadline)
                    }
                }
                .toggleStyle(.switch)
                .tint(.blue)
                .onChange(of: isBlackScreenEnabled) { updateOverlay() }

                Divider()

                // Settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Settings")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    SliderRow(label: "Width", value: $ringWidth, range: 10...200, unit: "pt")
                    SliderRow(label: "Brightness", value: $brightness, range: 20...100, unit: "%")
                    SliderRow(label: "Softness", value: $softness, range: 0...80, unit: "px")
                }

                Divider()

                // Color presets
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 36))], spacing: 8) {
                        ForEach(0..<colorPresets.count, id: \.self) { index in
                            Button(action: { selectedColorIndex = index }) {
                                Circle()
                                    .fill(colorPresets[index].1)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColorIndex == index ? Color.primary : Color.clear, lineWidth: 2)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider()

                // Performance settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Performance")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    SliderRow(label: "FPS", value: $fps, range: 10...144, unit: "fps")
                }

                Spacer()
            }
            .padding(16)
        }
        .frame(width: 340, height: 540)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        .onChange(of: ringWidth) { updateOverlay() }
        .onChange(of: brightness) { updateOverlay() }
        .onChange(of: softness) { updateOverlay() }
        .onChange(of: selectedColorIndex) { updateOverlay() }
        .onChange(of: isBreathingEnabled) { updateOverlay() }
        .onChange(of: fps) { updateFPS() }
        .onReceive(NotificationCenter.default.publisher(for: ScreenGlowOverlay.blackScreenDisabledNotification)) { _ in
            isBlackScreenEnabled = false
        }
    }

    private func togglePower() {
        isEnabled.toggle()
        if isEnabled {
            showOverlay()
        } else {
            ScreenGlowOverlay.shared.hide()
        }
    }

    private func showOverlay() {
        let nsColor = colorPresets[selectedColorIndex].2
        ScreenGlowOverlay.shared.show(
            color: nsColor,
            width: CGFloat(ringWidth),
            brightness: CGFloat(brightness / 100),
            softness: CGFloat(softness),
            breathingEnabled: isBreathingEnabled,
            blackScreen: isBlackScreenEnabled
        )
    }

    private func updateOverlay() {
        guard isEnabled else { return }
        let nsColor = colorPresets[selectedColorIndex].2
        ScreenGlowOverlay.shared.update(
            color: nsColor,
            width: CGFloat(ringWidth),
            brightness: CGFloat(brightness / 100),
            softness: CGFloat(softness),
            breathingEnabled: isBreathingEnabled,
            blackScreen: isBlackScreenEnabled
        )
    }

    private func updateFPS() {
        ScreenGlowOverlay.shared.setFPS(fps)
    }
}

struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String

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
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

#Preview {
    ControlPanelView()
}
