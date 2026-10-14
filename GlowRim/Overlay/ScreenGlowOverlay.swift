import AppKit
import QuartzCore

@Observable
final class ScreenGlowOverlay {
    static let shared = ScreenGlowOverlay()
    private(set) var displays: [Display] = []
    private(set) var potentialHeadroom: Double = 1
    private(set) var currentHeadroom: Double = 1
    private(set) var renderError: String?
    private(set) var selectedDisplayName = "Écran principal"
    private(set) var isVisible = false
    @ObservationIgnored private var window: RingLightWindow?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var localMonitor: Any?
    @ObservationIgnored private var globalMonitor: Any?
    @ObservationIgnored private var transitionStart = CACurrentMediaTime()
    @ObservationIgnored private var transitionFrom: Float = 0
    @ObservationIgnored private var visibility: Float = 0
    @ObservationIgnored private var targetVisibility: Float = 0
    @ObservationIgnored private var timerRate: Double = 0
    @ObservationIgnored private var lastTick = CACurrentMediaTime()
    @ObservationIgnored private var breathingTime: Double = 0
    @ObservationIgnored private var breathFrom = BreathingAnimation.Sample.still
    @ObservationIgnored private var breathTransitionStart: Double = -.infinity
    @ObservationIgnored private var breathing = false
    @ObservationIgnored private var reduceMotion = false
    @ObservationIgnored private var forceRedraw = true
    @ObservationIgnored private var lastHeadroomCheck: Double = -.infinity
    @ObservationIgnored private var mouseOrigin = NSEvent.mouseLocation
    @ObservationIgnored private var blackoutStarted = CACurrentMediaTime()
    @ObservationIgnored private var wasBlackout = false
    @ObservationIgnored private var displayID: String?
    @ObservationIgnored private var targetScreen: NSScreen?
    @ObservationIgnored private var completedDraws = 0
    @ObservationIgnored private var budget = RenderBudget(onBattery: false, lowPower: false, thermalPressure: false)

    // Diagnostics used by the lifecycle and performance checks, not UI observations.
    var renderedFrameCount: Int { completedDraws + (lightView?.renderer?.drawCount ?? 0) }
    var scheduledFramesPerSecond: Double { timerRate }
    var drawablePixelSize: CGSize? { lightView?.drawableSize }
    private var lightView: RingLightView? { window?.contentView as? RingLightView }

    struct Display: Identifiable { let id: String; let name: String }
    static func id(for screen: NSScreen) -> String {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? ""
    }
    private init() {}
    func startMonitoring() {
        guard observers.isEmpty else { return }
        refreshDisplays()
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in self?.refreshDisplays(); self?.synchronize() })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil, queue: .main) { [weak self] _ in self?.synchronize() })
    }
    private func refreshDisplays() {
        displays = NSScreen.screens.map { Display(id: Self.id(for: $0), name: $0.localizedName) }
    }
    private var selectedScreen: NSScreen? {
        let id = LightSettings.shared.selectedDisplayID
        return NSScreen.screens.first(where: { Self.id(for: $0) == id }) ?? NSScreen.screens.first
    }
    func synchronize() {
        let settings = LightSettings.shared
        guard let screen = selectedScreen else { hideImmediately(); return }
        targetScreen = screen
        if selectedDisplayName != screen.localizedName { selectedDisplayName = screen.localizedName }
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let pressure = ProcessInfo.processInfo.thermalState
        budget = RenderBudget(onBattery: !BatteryMonitor.shared.isCharging,
            lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermalPressure: pressure == .serious || pressure == .critical)
        let newID = Self.id(for: screen)
        if settings.isEnabled && (window == nil || displayID != newID) {
            releaseWindow()
            window = RingLightWindow(screen: screen)
            displayID = newID
            renderError = lightView?.failureReason
            if renderError != nil {
                hideImmediately()
                settings.isEnabled = false
                return
            }
            window?.orderFrontRegardless()
            isVisible = true
        }
        if window?.frame != screen.frame { window?.setFrame(screen.frame, display: false) }
        lightView?.applyBudget(budget)
        lightView?.renderer?.updateStyle(from: settings)
        updateHeadroom()
        let now = CACurrentMediaTime()
        let target: Float = settings.isEnabled ? 1 : 0
        if target != targetVisibility {
            transitionFrom = visibility
            transitionStart = now
            targetVisibility = target
            if settings.isEnabled { lastTick = now; breathingTime = 0 }
        }
        let nextBreathing = settings.mode == .pulsating && !reduceMotion
        if breathing != nextBreathing {
            breathFrom = lightView?.renderer?.breath ?? .still
            breathTransitionStart = now
            if nextBreathing { breathingTime = 0 }
            breathing = nextBreathing
        }
        if settings.blackScreen && !settings.isEnabled { settings.blackScreen = false }
        updateBlackout(settings.isEnabled && settings.blackScreen)
        forceRedraw = true
        render()
        updateTimer()
    }
    private func updateHeadroom() {
        guard let screen = targetScreen else { return }
        let potential = max(1, Double(screen.maximumPotentialExtendedDynamicRangeColorComponentValue))
        let current = max(1, Double(screen.maximumExtendedDynamicRangeColorComponentValue))
        if potentialHeadroom != potential { potentialHeadroom = potential }
        if currentHeadroom != current { currentHeadroom = current }
        lastHeadroomCheck = CACurrentMediaTime()
    }
    private func updateTimer() {
        guard targetVisibility > 0 || visibility > 0 else {
            timer?.invalidate(); timer = nil; timerRate = 0; return
        }
        let animated = visibility != targetVisibility || breathing || CACurrentMediaTime() - breathTransitionStart < 0.8
        // A still SDR light needs no timer. HDR availability can change with system
        // brightness; check infrequently, and only draw if the gain actually changes.
        let rate: Double = animated ? budget.framesPerSecond :
            (LightSettings.shared.hdrEnabled && potentialHeadroom > 1 ? 0.5 : 0)
        guard timerRate != rate || (rate > 0 && timer == nil) else { return }
        timer?.invalidate(); timer = nil; timerRate = rate
        guard rate > 0 else { return }
        let next = Timer(timeInterval: 1 / rate, repeats: true) { [weak self] _ in
            self?.render(); self?.updateTimer()
        }
        next.tolerance = rate < 1 ? 0.3 : 0.008
        timer = next
        RunLoop.main.add(next, forMode: .common)
    }
    private func render() {
        guard let view = lightView, let renderer = view.renderer else { return }
        let settings = LightSettings.shared
        let now = CACurrentMediaTime()
        let dt = max(0, now - lastTick)
        lastTick = now
        if breathing { breathingTime += dt * settings.animationSpeed }
        let t = reduceMotion ? 1 : min(1, (now - transitionStart) / 0.28)
        visibility = transitionFrom + (targetVisibility - transitionFrom) * Float(BreathingAnimation.easing(t))
        if t >= 1 { visibility = targetVisibility }
        if visibility == 0 && targetVisibility == 0 {
            releaseWindow(); isVisible = false; return
        }
        if now - lastHeadroomCheck >= 2 { updateHeadroom() }
        let gain = settings.hdrEnabled ? Float(min(potentialHeadroom, currentHeadroom)) : 1
        let targetBreath = breathing ? BreathingAnimation.sample(at: breathingTime) : .still
        let blend = reduceMotion ? 1 : Float(BreathingAnimation.easing((now - breathTransitionStart) / 0.8))
        let breath = breathFrom.blended(to: targetBreath, amount: blend)
        let black = settings.blackScreen && settings.isEnabled
        let changed = forceRedraw || renderer.fade != visibility || renderer.breath != breath ||
            abs(renderer.headroom - gain) > 0.01 || renderer.blackout != black
        renderer.fade = visibility
        renderer.breath = breath
        renderer.blackout = black
        // Avoid thrashing the surface for tiny EDR measurement fluctuations.
        if abs(renderer.headroom - gain) > 0.01 { renderer.headroom = gain }
        if changed { view.draw() }
        forceRedraw = false
    }
    private func updateBlackout(_ enabled: Bool) {
        guard enabled != wasBlackout else { return }
        wasBlackout = enabled
        removeMonitors()
        guard enabled else { return }
        mouseOrigin = NSEvent.mouseLocation
        blackoutStarted = CACurrentMediaTime()
        let mouseEvents: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .leftMouseDown, .rightMouseDown]
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseEvents.union(.keyDown)) { [weak self] event in
            if event.type == .keyDown {
                if event.keyCode == 53 { LightSettings.shared.blackScreen = false; return nil }
            } else { self?.handleMouseEvent(event) }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseEvents) { [weak self] event in self?.handleMouseEvent(event) }
    }
    private func handleMouseEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown || event.type == .rightMouseDown { LightSettings.shared.blackScreen = false; return }
        guard CACurrentMediaTime() - blackoutStarted > 0.6 else { return }
        let mouse = NSEvent.mouseLocation
        if hypot(mouse.x - mouseOrigin.x, mouse.y - mouseOrigin.y) > 5 { LightSettings.shared.blackScreen = false }
    }
    private func removeMonitors() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil; globalMonitor = nil
    }
    private func releaseWindow() {
        completedDraws += lightView?.renderer?.drawCount ?? 0
        window?.orderOut(nil)
        lightView?.releaseDrawables()
        window?.contentView = nil
        window?.close()
        window = nil; displayID = nil
    }
    func hideImmediately() {
        timer?.invalidate(); timer = nil; timerRate = 0
        visibility = 0; targetVisibility = 0; isVisible = false
        releaseWindow()
        wasBlackout = false
        removeMonitors()
    }
    func shutdown() {
        hideImmediately()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
    }
}
