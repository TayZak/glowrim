import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var controlWindow: NSWindow?
    private var observers: [NSObjectProtocol] = []
    private var updateScheduled = false
    private var protectionTimer: Timer?
    var hasProtectionTimer: Bool { protectionTimer?.isValid == true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupMenuBar()
        ScreenGlowOverlay.shared.startMonitoring()
        HotKeyManager.shared.register { LightSettings.shared.toggle() }
        observe(LightSettings.changed) { [weak self] in self?.scheduleUpdate() }
        observe(.glowrimLowBattery) { [weak self] in self?.pauseForBattery() }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { _ in
                LightSettings.shared.isEnabled = false
                LightSettings.shared.blackScreen = false
                ScreenGlowOverlay.shared.hideImmediately()
            })
        }
        observe(.glowrimPowerSourceChanged) { [weak self] in self?.scheduleUpdate() }
        observe(.NSProcessInfoPowerStateDidChange) { [weak self] in self?.scheduleUpdate() }
        observe(ProcessInfo.thermalStateDidChangeNotification) { [weak self] in self?.scheduleUpdate() }
        _ = BatteryMonitor.shared
        showControlWindow()
        synchronize()
    }
    private func observe(_ name: Notification.Name, action: @escaping () -> Void) {
        observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in action() })
    }
    private func scheduleUpdate() {
        guard !updateScheduled else { return }
        updateScheduled = true
        DispatchQueue.main.async { [weak self] in self?.updateScheduled = false; self?.synchronize() }
    }
    private func synchronize() {
        pauseForBattery()
        updateProtection()
        ScreenGlowOverlay.shared.synchronize()
        statusItem?.button?.image = NSImage(systemSymbolName: LightSettings.shared.isEnabled ? "sun.max.fill" : "sun.max", accessibilityDescription: "GlowRim")
        statusItem?.button?.toolTip = "GlowRim — \(LightSettings.shared.isEnabled ? "Lumière allumée" : "Lumière éteinte")"
        statusItem?.menu?.item(withTag: 1)?.title = LightSettings.shared.isEnabled ? "Éteindre la lumière" : "Allumer la lumière"
        controlWindow?.level = LightSettings.shared.blackScreen ? .init(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 2) : .normal
    }
    private func pauseForBattery() {
        if LightSettings.shared.batteryProtection && BatteryMonitor.shared.shouldPauseDueToLowBattery && LightSettings.shared.isEnabled {
            LightSettings.shared.isEnabled = false
        }
    }
    private func updateProtection() {
        let settings = LightSettings.shared
        guard settings.isEnabled, settings.mode == .constant, settings.autoBreathing else {
            protectionTimer?.invalidate(); protectionTimer = nil; return
        }
        guard protectionTimer == nil else { return }
        // A single deadline replaces the permanent one-second polling timer.
        protectionTimer = Timer.scheduledTimer(withTimeInterval: Constants.burnInProtectionDelay, repeats: false) { [weak self] _ in
            self?.protectionTimer = nil
            if settings.isEnabled && settings.mode == .constant && settings.autoBreathing { settings.mode = .pulsating }
        }
        protectionTimer?.tolerance = 1
    }
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "sun.max", accessibilityDescription: "GlowRim")
        let menu = NSMenu()
        let open = menu.addItem(withTitle: "Ouvrir GlowRim…", action: #selector(showControlWindow), keyEquivalent: "")
        open.target = self
        let toggle = menu.addItem(withTitle: "Allumer la lumière", action: #selector(toggleLight), keyEquivalent: "l")
        toggle.keyEquivalentModifierMask = [.command, .option]
        toggle.target = self; toggle.tag = 1
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quitter GlowRim", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        statusItem?.menu = menu
    }
    @objc func showControlWindow() {
        if controlWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 680),
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "GlowRim"
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
            window.contentMinSize = NSSize(width: 740, height: 540)
            window.isReleasedWhenClosed = false
            window.acceptsMouseMovedEvents = true
            window.contentViewController = NSHostingController(rootView: ControlPanelView())
            window.setContentSize(NSSize(width: 800, height: 680))
            window.setFrameAutosaveName("GlowRimControlWindowV2")
            if !window.setFrameUsingName("GlowRimControlWindowV2") { window.center() }
            controlWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        controlWindow?.makeKeyAndOrderFront(nil)
    }
    @objc private func toggleLight() { LightSettings.shared.toggle() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showControlWindow(); return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) {
        LightSettings.shared.saveSettings()
        ScreenGlowOverlay.shared.shutdown()
        HotKeyManager.shared.unregister()
        protectionTimer?.invalidate()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
