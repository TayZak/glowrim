import SwiftUI
import AppKit

struct ControlPanelView: View {
    @Bindable private var settings = LightSettings.shared
    @Bindable private var overlay = ScreenGlowOverlay.shared
    @State private var showAdvanced = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let presets: [ColorPreset] = [.daylight, .warm, .cool, .goldenHour, .sunset]

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 24).padding(.vertical, 20)
            Divider()
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 20) {
                    preview
                    Picker("Écran", selection: $settings.selectedDisplayID) {
                        Text("Écran principal").tag("")
                        ForEach(overlay.displays) { display in Text(display.name).tag(display.id) }
                        if !settings.selectedDisplayID.isEmpty && !overlay.displays.contains(where: { $0.id == settings.selectedDisplayID }) {
                            Text("Écran déconnecté").tag(settings.selectedDisplayID)
                        }
                    }.font(.subheadline)
                    Text("La lumière reste disponible quand tu fermes cette fenêtre. Rouvre-la depuis le Dock ou la barre de menus.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(HotKeyManager.shared.isRegistered ? "⌥⌘L  Allumer / éteindre" : "⌥⌘L est déjà utilisé")
                        Text("Réglages sauvegardés automatiquement")
                    }.font(.caption2).foregroundStyle(.secondary)
                }
                .padding(24).frame(width: 290)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        lighting
                        colors
                        shape
                        DisclosureGroup("Options", isExpanded: $showAdvanced) {
                            advanced.padding(.top, 14)
                        }
                        .font(.headline)
                        .padding(18)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
                    }.padding(20)
                }.defaultScrollAnchor(.top)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(.accentColor)
        .onExitCommand { settings.blackScreen = false }
    }
    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable().frame(width: 46, height: 46)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("GlowRim").font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Une belle lumière, tout autour.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text(settings.isEnabled ? "Allumée" : "Éteinte")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(settings.isEnabled ? Color.green.opacity(0.12) : Color.secondary.opacity(0.1), in: Capsule())
        }
    }
    private var preview: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 22).fill(Color(red: 0.075, green: 0.085, blue: 0.11))
                PreviewContour(organic: settings.mode == .pulsating)
                    .stroke(settings.color.opacity(settings.isEnabled ? 0.65 : 0.25), lineWidth: 12)
                    .blur(radius: 9)
                PreviewContour(organic: settings.mode == .pulsating)
                    .stroke(settings.color.opacity(settings.isEnabled ? 0.7 : 0.3), lineWidth: CGFloat(settings.ringWidth / 10).clamped(to: 2...14))
                    .blur(radius: 3)
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 42, weight: .ultraLight)).foregroundStyle(.white.opacity(0.7))
                    Text(overlay.selectedDisplayName).font(.caption).foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(height: 148)
            .accessibilityLabel("Aperçu du contour lumineux")
            Button { settings.toggle() } label: {
                Label(settings.isEnabled ? "Éteindre la lumière" : "Allumer la lumière", systemImage: "power")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .help("Raccourci global : ⌥⌘L")
            HStack(spacing: 6) {
                Image(systemName: hdrCapable ? "sparkles" : "display")
                Text(hdrDescription)
            }
            .font(.caption).foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            if let error = overlay.renderError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
            if settings.batteryProtection && BatteryMonitor.shared.shouldPauseDueToLowBattery {
                Label("Lumière en pause : batterie sous 15 %. Branche ton Mac ou désactive la pause automatique.", systemImage: "battery.0percent")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }
    private var hdrCapable: Bool { overlay.potentialHeadroom > 1 }
    private var hdrDescription: String {
        if !settings.hdrEnabled { return "Luminosité standard" }
        if !hdrCapable { return "Écran SDR · luminosité standard" }
        if !settings.isEnabled { return "Écran HDR détecté · prêt pour la lumière HDR" }
        if overlay.currentHeadroom <= 1.01 { return "HDR activé · réserve de luminosité limitée par l’écran" }
        return String(format: "HDR activé · réserve actuelle ×%.1f", overlay.currentHeadroom)
    }
    private var lighting: some View {
        card("Lumière", symbol: "sun.max") {
            SliderRow(label: "Intensité", value: Binding(get: { settings.intensity * 100 }, set: { settings.intensity = $0 / 100 }), range: 20...100, unit: "%")
            Picker("Animation", selection: $settings.mode) {
                Text("Stable").tag(LightMode.constant)
                Text("Respiration").tag(LightMode.pulsating)
            }.pickerStyle(.segmented)
            Text(settings.mode == .constant ? "Une lumière régulière pour tes appels vidéo." : "Une inspiration douce, une expiration plus longue. Le halo se déploie et se relâche avec la lumière.")
                .font(.caption).foregroundStyle(.secondary)
            if settings.mode == .pulsating && !reduceMotion {
                SliderRow(label: "Rythme", value: $settings.animationSpeed, range: 0.5...2, unit: "×", fractionDigits: 1)
                Text("Un souffle toutes les \((BreathingAnimation.cycleDuration / settings.animationSpeed).formatted(.number.precision(.fractionLength(1)))) secondes.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if reduceMotion && settings.mode == .pulsating {
                Text("Animation suspendue par l’option macOS Réduire les animations.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var colors: some View {
        card("Teinte", symbol: "paintpalette") {
            HStack(spacing: 8) {
                ForEach(presets) { preset in
                    Button { settings.applyPreset(preset) } label: {
                        VStack(spacing: 7) {
                            Circle().fill(preset.color)
                                .frame(width: 32, height: 32)
                                .overlay(Circle().strokeBorder(.black.opacity(0.12)))
                                .overlay {
                                    if settings.selectedPresetId == preset.id {
                                        Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.black.opacity(0.7))
                                    }
                                }
                            Text(preset.name).font(.system(size: 10)).lineLimit(1)
                        }.frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(settings.selectedPresetId == preset.id ? Color.accentColor.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain)
                    .accessibilityLabel(preset.name)
                    .accessibilityAddTraits(settings.selectedPresetId == preset.id ? .isSelected : [])
                }
            }
            ColorPicker("Couleur personnalisée", selection: Binding(get: { settings.color }, set: { settings.setColor($0) }), supportsOpacity: false)
                .font(.subheadline)
        }
    }
    private var shape: some View {
        card("Contour", symbol: "rectangle.inset.filled") {
            SliderRow(label: "Épaisseur", value: $settings.ringWidth, range: 10...200, unit: " pt")
            SliderRow(label: "Diffusion", value: $settings.softness, range: 0...80, unit: " pt")
            SliderRow(label: "Arrondi", value: Binding(get: { settings.cornerRadius * 100 }, set: { settings.cornerRadius = $0 / 100 }), range: 0...50, unit: "%")
        }
    }
    private var advanced: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Utiliser la luminosité HDR", isOn: $settings.hdrEnabled)
            Text("La luminosité disponible dépend de l’écran, de ses réglages et de la réserve HDR autorisée par macOS.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Toggle("Fond noir", isOn: $settings.blackScreen).disabled(!settings.isEnabled)
            Text("Masque le contenu derrière la lumière. Bouge la souris ou clique pour retrouver ton écran.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Toggle("Pause si la batterie passe sous 15 %", isOn: $settings.batteryProtection)
            Toggle("Respiration automatique après 5 minutes", isOn: $settings.autoBreathing)
            Text("Fait varier la lumière lors des longues sessions.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Label("Économie d’énergie automatique", systemImage: "leaf")
            Text("La respiration s’adapte à la batterie et au mode économie d’énergie de macOS. Une lumière stable ne se redessine que si nécessaire.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Rétablir les réglages de lumière") { settings.resetAppearance() }
                .controlSize(.small)
        }
        .font(.subheadline)
        .toggleStyle(.switch)
    }
    private func card<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: symbol).font(.headline)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.05)))
    }
}

struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    var fractionDigits = 0
    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Text(label)
                Spacer()
                Text(value.formatted(.number.precision(.fractionLength(fractionDigits))) + unit)
                    .monospacedDigit().foregroundStyle(.secondary)
            }.font(.subheadline)
            Slider(value: $value, in: range).accessibilityLabel(label)
        }
    }
}

// A still illustration. The preview has no animation timer or second Metal surface.
private struct PreviewContour: Shape {
    let organic: Bool
    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: 8, dy: 8)
        guard organic else { return Path(roundedRect: r, cornerRadius: 16) }
        let radius: CGFloat = 18
        var p = Path()
        p.move(to: CGPoint(x:r.minX+radius,y:r.minY))
        p.addCurve(to: CGPoint(x:r.maxX-radius,y:r.minY),
            control1:CGPoint(x:r.minX+r.width*0.35,y:r.minY+7),control2:CGPoint(x:r.minX+r.width*0.65,y:r.minY+7))
        p.addQuadCurve(to:CGPoint(x:r.maxX,y:r.minY+radius),control:CGPoint(x:r.maxX,y:r.minY))
        p.addCurve(to:CGPoint(x:r.maxX,y:r.maxY-radius),
            control1:CGPoint(x:r.maxX-4,y:r.midY-16),control2:CGPoint(x:r.maxX-4,y:r.midY+16))
        p.addQuadCurve(to:CGPoint(x:r.maxX-radius,y:r.maxY),control:CGPoint(x:r.maxX,y:r.maxY))
        p.addCurve(to:CGPoint(x:r.minX+radius,y:r.maxY),
            control1:CGPoint(x:r.minX+r.width*0.65,y:r.maxY-3),control2:CGPoint(x:r.minX+r.width*0.35,y:r.maxY-3))
        p.addQuadCurve(to:CGPoint(x:r.minX,y:r.maxY-radius),control:CGPoint(x:r.minX,y:r.maxY))
        p.addCurve(to:CGPoint(x:r.minX,y:r.minY+radius),
            control1:CGPoint(x:r.minX+6,y:r.midY+16),control2:CGPoint(x:r.minX+6,y:r.midY-16))
        p.addQuadCurve(to:CGPoint(x:r.minX+radius,y:r.minY),control:CGPoint(x:r.minX,y:r.minY))
        p.closeSubpath()
        return p
    }
}

#Preview { ControlPanelView().frame(width: 800, height: 680) }
