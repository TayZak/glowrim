import AppKit
import SwiftUI

/// Borderless window that floats above all applications including fullscreen
final class RingLightWindow: NSWindow {
    private var ringView: RingLightView?

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        configureWindow()
    }

    convenience init() {
        let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        self.init(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
    }

    private func configureWindow() {
        // Window level above everything (including fullscreen apps)
        // CGShieldingWindowLevel is above fullscreen, we go even higher
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)

        // Allow window to appear on all spaces and in fullscreen
        collectionBehavior = [
            .canJoinAllSpaces,      // Appears on all Spaces
            .fullScreenAuxiliary,   // Can appear over fullscreen apps
            .stationary,            // Doesn't move with Space switches
            .ignoresCycle           // Not included in Cmd+Tab
        ]

        // Transparency settings
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false

        // Click-through - very important!
        ignoresMouseEvents = true

        // No title bar
        titlebarAppearsTransparent = true
        titleVisibility = .hidden

        // Can't become key or main (stays behind control panel)
        canHide = false

        // Create and set content view
        let ringView = RingLightView(frame: frame)
        self.ringView = ringView
        contentView = ringView

        // Listen for screen changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func screenDidChange() {
        // Update frame when screen configuration changes
        if let screen = NSScreen.main {
            setFrame(screen.frame, display: true)
            ringView?.updateRingPath()
        }
    }

    // MARK: - Public API

    /// Shows the ring light with fade-in animation
    func showRing() {
        alphaValue = 0
        orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Constants.fadeInDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().alphaValue = 1.0
        }

        ringView?.startAnimation()
    }

    /// Hides the ring light with fade-out animation
    func hideRing(completion: (() -> Void)? = nil) {
        ringView?.stopAnimation()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Constants.fadeOutDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            completion?()
        })
    }

    /// Updates ring light parameters
    func updateSettings() {
        ringView?.updateFromSettings()
    }

    /// Access to the ring view for direct updates
    var lightView: RingLightView? {
        ringView
    }
}

// MARK: - Window Controller

final class RingLightWindowController: NSWindowController {
    static let shared = RingLightWindowController()

    private var ringWindow: RingLightWindow?

    private init() {
        super.init(window: nil)
        setupWindow()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupWindow() {
        ringWindow = RingLightWindow()
        window = ringWindow
    }

    func show() {
        ringWindow?.showRing()
    }

    func hide(completion: (() -> Void)? = nil) {
        ringWindow?.hideRing(completion: completion)
    }

    func toggle() {
        if ringWindow?.isVisible == true && ringWindow?.alphaValue ?? 0 > 0 {
            hide()
            LightSettings.shared.isEnabled = false
        } else {
            show()
            LightSettings.shared.isEnabled = true
        }
    }

    func updateSettings() {
        ringWindow?.updateSettings()
    }

    var isVisible: Bool {
        ringWindow?.isVisible == true && (ringWindow?.alphaValue ?? 0) > 0
    }
}
