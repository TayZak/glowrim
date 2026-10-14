import SwiftUI

@main
struct GlowRimApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("Ouvrir GlowRim…") { appDelegate.showControlWindow() }
                        .keyboardShortcut(",")
                }
                CommandMenu("Lumière") {
                    Button(LightSettings.shared.isEnabled ? "Éteindre" : "Allumer") { LightSettings.shared.toggle() }
                        .keyboardShortcut("l", modifiers: [.command, .option])
                    Button("Afficher les réglages") { appDelegate.showControlWindow() }
                        .keyboardShortcut("0", modifiers: .command)
                }
            }
    }
}
