import Foundation
import AppKit
import Carbon

final class HotKeyManager {
    static let shared = HotKeyManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var onToggle: (() -> Void)?

    private init() {}

    /// Registers the global hotkey (Cmd+Option+L)
    func register(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle

        // Create event tap for key down events
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }

                let manager = Unmanaged<HotKeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("GlowRim: Failed to create event tap. Accessibility permissions required.")
            requestAccessibilityPermissions()
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("GlowRim: Global hotkey registered (Cmd+Option+L)")
        }
    }

    /// Unregisters the global hotkey
    func unregister() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        onToggle = nil

        print("GlowRim: Global hotkey unregistered")
    }

    private func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // Check if it's our hotkey: Cmd+Option+L
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // L key = 0x25 (37)
        let isLKey = keyCode == 0x25

        // Check for Cmd+Option modifiers
        let hasCommand = flags.contains(.maskCommand)
        let hasOption = flags.contains(.maskAlternate)
        let hasShift = flags.contains(.maskShift)
        let hasControl = flags.contains(.maskControl)

        if isLKey && hasCommand && hasOption && !hasShift && !hasControl {
            // Trigger toggle on main thread
            DispatchQueue.main.async { [weak self] in
                self?.onToggle?()
            }
            // Consume the event
            return nil
        }

        // Pass through other events
        return Unmanaged.passRetained(event)
    }

    private func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if !trusted {
            print("GlowRim: Please grant Accessibility permissions in System Settings > Privacy & Security > Accessibility")
        }
    }

    /// Checks if accessibility permissions are granted
    static var hasAccessibilityPermissions: Bool {
        AXIsProcessTrusted()
    }
}
