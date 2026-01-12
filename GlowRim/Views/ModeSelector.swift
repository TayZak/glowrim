import SwiftUI

struct ModeSelector: View {
    @Bindable var settings: LightSettings

    var body: some View {
        VStack(spacing: 8) {
            Text("Mode")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                ForEach(LightMode.allCases) { mode in
                    ModeButton(
                        mode: mode,
                        isSelected: settings.mode == mode,
                        accentColor: settings.color
                    ) {
                        selectMode(mode)
                    }
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
    }

    private func selectMode(_ mode: LightMode) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            settings.mode = mode
        }

        // Update burn-in protection
        if mode == .constant {
            BurnInProtection.shared.onConstantModeEnabled()
        } else {
            BurnInProtection.shared.onConstantModeDisabled()
        }

        // Update ring view
        RingLightWindowController.shared.updateSettings()
    }
}

struct ModeButton: View {
    let mode: LightMode
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: mode.iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? .white : .secondary)

                Text(mode.displayName)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mode.displayName) mode")
        .accessibilityHint(mode.description)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    ModeSelector(settings: LightSettings.shared)
        .padding()
        .frame(width: 350)
        .background(Color(NSColor.windowBackgroundColor))
}
