import AppKit

final class RingLightWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        level = .init(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        canHide = false
        isReleasedWhenClosed = false
        contentView = RingLightView(frame: NSRect(origin: .zero, size: screen.frame.size))
    }
}

// Compatibility for the small reusable controls; all output uses the same renderer.
final class RingLightWindowController {
    static let shared = RingLightWindowController()
    func show() { LightSettings.shared.isEnabled = true }
    func hide(completion: (() -> Void)? = nil) { LightSettings.shared.isEnabled = false; completion?() }
    func toggle() { LightSettings.shared.toggle() }
    func updateSettings() { ScreenGlowOverlay.shared.synchronize() }
    var isVisible: Bool { ScreenGlowOverlay.shared.isVisible }
}
