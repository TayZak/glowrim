import SwiftUI

struct PresetGrid: View {
    @Bindable var settings: LightSettings

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(spacing: 8) {
            Text("Presets")
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(ColorPreset.allPresets) { preset in
                    PresetButton(
                        preset: preset,
                        isSelected: settings.selectedPresetId == preset.id,
                        action: { selectPreset(preset) }
                    )
                }
            }
        }
    }

    private func selectPreset(_ preset: ColorPreset) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            settings.applyPreset(preset)
        }
        RingLightWindowController.shared.updateSettings()
    }
}

struct PresetButton: View {
    let preset: ColorPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // Color swatch
                Circle()
                    .fill(preset.color)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(color: preset.color.opacity(0.4), radius: isSelected ? 6 : 2)

                // Label
                Text(preset.name)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color(NSColor.selectedContentBackgroundColor).opacity(0.3) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? preset.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preset.name) color preset")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    PresetGrid(settings: LightSettings.shared)
        .padding()
        .frame(width: 350)
        .background(Color(NSColor.windowBackgroundColor))
}
