import AppKit
import SwiftUI
import QuartzCore

final class ScreenGlowOverlay {
    static let shared = ScreenGlowOverlay()

    private var overlayWindow: NSWindow?
    private var glowView: GlowView?

    // Base values (from UI)
    private var baseColor: NSColor = .white
    private var baseWidth: CGFloat = 25
    private var baseBrightness: CGFloat = 0.8
    private var baseSoftness: CGFloat = 40
    private var breathingEnabled: Bool = true
    private var blackScreenEnabled: Bool = false

    // Animation
    private var animationTimer: Timer?
    private var animationStartTime: CFTimeInterval = 0
    private var fadeInProgress: CGFloat = 0
    private var isFadingIn = false

    // Event monitors for black screen auto-disable
    private var mouseClickMonitor: Any?
    private var keyboardMonitor: Any?
    private var mouseTrackingTimer: Timer?
    private var lastMouseLocation: NSPoint = .zero
    private var mouseIdleTimer: Timer?
    private var isMouseActive: Bool = false

    static let blackScreenDisabledNotification = Notification.Name("GlowRimBlackScreenDisabled")

    // Configurable performance settings
    private(set) var fps: Double = 18.0
    private let gradientLevels: Int = 128 // Enough for smooth transitions

    // Precalculated breathing animation
    private var breathingLookup: [(brightness: CGFloat, width: CGFloat, softness: CGFloat)] = []
    private var breathingCycleFrames: Int = 1620 // 90s * 18fps (covers full intensity cycle)
    private var currentFrame = 0

    private init() {
        precalculateBreathingCycle()
    }

    // MARK: - Performance Settings

    func setFPS(_ newFPS: Double) {
        let clampedFPS = max(10, min(144, newFPS))
        guard clampedFPS != fps else { return }
        fps = clampedFPS
        breathingCycleFrames = Int(90.0 * fps) // 90 second cycle (covers full intensity envelope)
        precalculateBreathingCycle()

        // Restart animation with new FPS if running
        if animationTimer != nil {
            updateTimerRate()
        }
    }

    func show(color: NSColor, width: CGFloat, brightness: CGFloat, softness: CGFloat, breathingEnabled: Bool, blackScreen: Bool = false) {
        baseColor = color
        baseWidth = width
        baseBrightness = brightness
        baseSoftness = softness
        self.breathingEnabled = breathingEnabled
        self.blackScreenEnabled = blackScreen

        if overlayWindow == nil {
            createWindow()
        }

        // Update black screen state
        glowView?.setBlackScreen(blackScreen)
        updateEventMonitors()

        // Precalculate gradients based on mode
        if breathingEnabled {
            glowView?.precalculateBreathingGradients(for: color)
        }

        // Start fade-in
        fadeInProgress = 0
        isFadingIn = true
        animationStartTime = CACurrentMediaTime()

        overlayWindow?.alphaValue = 0
        overlayWindow?.orderFront(nil)

        startAnimation()
    }

    private func updateEventMonitors() {
        if blackScreenEnabled {
            startEventMonitors()
        } else {
            stopEventMonitors()
        }
    }

    private func startEventMonitors() {
        guard mouseClickMonitor == nil else { return }

        // Monitor mouse clicks - disable black screen
        mouseClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.disableBlackScreen()
        }

        // Monitor keyboard - disable black screen
        keyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            self?.disableBlackScreen()
        }

        // Poll mouse position to detect movement
        lastMouseLocation = NSEvent.mouseLocation
        mouseTrackingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkMouseMovement()
        }
    }

    private func checkMouseMovement() {
        guard blackScreenEnabled else { return }

        let currentLocation = NSEvent.mouseLocation
        let dx = abs(currentLocation.x - lastMouseLocation.x)
        let dy = abs(currentLocation.y - lastMouseLocation.y)

        // If mouse moved more than 5 pixels
        if dx > 5 || dy > 5 {
            lastMouseLocation = currentLocation
            handleMouseMoved()
        }
    }

    private func handleMouseMoved() {
        // Cancel existing idle timer
        mouseIdleTimer?.invalidate()

        // Fade out black screen when mouse moves
        if !isMouseActive {
            isMouseActive = true
            glowView?.animateBlackScreenOpacity(to: 0, duration: 0.3)
        }

        // Fade in black screen again after 3 seconds of inactivity
        mouseIdleTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.handleMouseIdle()
        }
    }

    private func handleMouseIdle() {
        guard blackScreenEnabled, isMouseActive else { return }
        isMouseActive = false
        glowView?.animateBlackScreenOpacity(to: 1.0, duration: 0.5)
    }

    private func stopEventMonitors() {
        if let monitor = mouseClickMonitor {
            NSEvent.removeMonitor(monitor)
            mouseClickMonitor = nil
        }
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
        mouseTrackingTimer?.invalidate()
        mouseTrackingTimer = nil
        mouseIdleTimer?.invalidate()
        mouseIdleTimer = nil
        isMouseActive = false
    }

    private func disableBlackScreen() {
        guard blackScreenEnabled else { return }
        blackScreenEnabled = false
        mouseIdleTimer?.invalidate()
        mouseIdleTimer = nil
        isMouseActive = false
        glowView?.setBlackScreen(false)
        stopEventMonitors()
        NotificationCenter.default.post(name: ScreenGlowOverlay.blackScreenDisabledNotification, object: nil)
    }

    func hide() {
        stopAnimation()
        stopEventMonitors()

        // Fade out
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            overlayWindow?.animator().alphaValue = 0
        }, completionHandler: {
            self.overlayWindow?.orderOut(nil)
        })
    }

    func update(color: NSColor, width: CGFloat, brightness: CGFloat, softness: CGFloat, breathingEnabled: Bool, blackScreen: Bool = false) {
        baseColor = color
        baseWidth = width
        baseBrightness = brightness
        baseSoftness = softness
        self.breathingEnabled = breathingEnabled
        self.blackScreenEnabled = blackScreen

        // Update black screen state
        glowView?.setBlackScreen(blackScreen)
        updateEventMonitors()

        // Precalculate gradients based on mode
        if breathingEnabled {
            glowView?.precalculateBreathingGradients(for: color)
        }

        // Update timer rate based on mode
        updateTimerRate()
    }

    var isVisible: Bool {
        overlayWindow?.isVisible ?? false
    }

    private func createWindow() {
        guard let screen = NSScreen.main else { return }

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true

        let glowView = GlowView(frame: screen.frame)
        window.contentView = glowView
        self.glowView = glowView

        overlayWindow = window

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func updateTimerRate() {
        guard animationTimer != nil else { return }
        stopAnimation()
        startAnimation()
    }

    private func startAnimation() {
        stopAnimation()

        // Reset frame counter for breathing animation
        currentFrame = 0

        // Use configured FPS for breathing, minimal for static
        let effectiveFPS: Double = breathingEnabled ? fps : 0.5

        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/effectiveFPS, repeats: true) { [weak self] _ in
            self?.updateAnimation()
        }
        if let timer = animationTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func updateAnimation() {
        let time = CACurrentMediaTime() - animationStartTime

        // Fade in over 2 seconds
        if isFadingIn {
            fadeInProgress = Swift.min(1.0, CGFloat(time) / 2.0)
            overlayWindow?.alphaValue = easeOutCubic(fadeInProgress)
            if fadeInProgress >= 1.0 {
                isFadingIn = false
            }
        }

        if breathingEnabled {
            updateNormalBreathing(time: time)
        } else {
            // Static mode - just draw once
            glowView?.updateNormal(
                color: baseColor,
                width: baseWidth,
                brightness: baseBrightness,
                softness: baseSoftness
            )
        }
    }

    // Precalculate entire breathing cycle (done once at startup or when FPS changes)
    private func precalculateBreathingCycle() {
        breathingLookup.removeAll()
        breathingLookup.reserveCapacity(breathingCycleFrames)

        for frame in 0..<breathingCycleFrames {
            let time = Double(frame) / fps // Convert frame to time

            // Intensity envelope: cycles through light → marked → full → light
            // Uses a 90 second cycle for the intensity variation
            let intensityCycle = sin(time * 0.07) // ~90 sec cycle
            let easedIntensity = easeInOutSine(intensityCycle)
            // Map -1...1 to 0.3...1.0 (minimum 30% intensity, max 100%)
            let intensity = 0.3 + (easedIntensity + 1) * 0.35

            // Primary breathing wave (adapts speed slightly based on intensity)
            let breathSpeed = 0.18 + intensity * 0.04 // Faster when more intense
            let breathe1 = sin(time * breathSpeed) // Primary breath
            let breathe2 = sin(time * 0.5) * 0.3 // Secondary wave for organic feel
            let breathe3 = sin(time * 0.1) // Ultra slow drift

            // Apply smooth easing to sine waves
            let eased1 = easeInOutSine(breathe1)
            let eased2 = easeInOutSine(breathe2)
            let eased3 = easeInOutSine(breathe3)

            // Combined breath: ranges from -1 to +1
            let combinedBreath = (eased1 + eased2) / 1.3

            // Scale amplitude by intensity
            // Light: subtle breathing, light never disappears
            // Full: light can completely disappear (like emptying lungs fully)

            // Brightness: at full intensity, goes from 0 to 1.2 (complete disappearance)
            // At light intensity, goes from 0.85 to 1.05
            // combinedBreath goes from -1 (exhale) to +1 (inhale)
            let minBrightness = 0.85 - intensity * 0.85 // 0.85 at light, 0 at full
            let maxBrightness = 1.0 + intensity * 0.15 // 1.0 at light, 1.15 at full
            let breathNormalized = (combinedBreath + 1) / 2 // 0 to 1
            let brightnessMultiplier = minBrightness + breathNormalized * (maxBrightness - minBrightness)

            // Width: retracts more at full intensity exhale
            let minWidth = 1.0 - intensity * 0.6 // 1.0 at light, 0.4 at full (retracts to 40%)
            let maxWidth = 1.0 + intensity * 0.15 // 1.0 at light, 1.15 at full
            let widthMultiplier = minWidth + breathNormalized * (maxWidth - minWidth) + eased3 * 0.02

            // Softness: more variation at full intensity
            let softnessRange = 0.05 + intensity * 0.25 // 5% to 30% variation
            let softnessMultiplier = 1.0 + eased2 * softnessRange

            breathingLookup.append((
                brightness: CGFloat(brightnessMultiplier),
                width: CGFloat(widthMultiplier),
                softness: CGFloat(softnessMultiplier)
            ))
        }
    }

    // Smooth easing function for sine waves
    private func easeInOutSine(_ x: Double) -> Double {
        // Convert -1...1 range to 0...1, apply easing, convert back
        let normalized = (x + 1) / 2 // -1...1 -> 0...1
        let eased = -(cos(Double.pi * normalized) - 1) / 2
        return eased * 2 - 1 // 0...1 -> -1...1
    }

    private func updateNormalBreathing(time: Double) {
        guard !breathingLookup.isEmpty else { return }

        // Lookup precalculated values (zero CPU cost per frame)
        let frame = breathingLookup[currentFrame]
        currentFrame = (currentFrame + 1) % breathingCycleFrames

        let currentWidth = baseWidth * frame.width
        let currentSoftness = baseSoftness * frame.softness

        // Use precalculated gradient based on brightness multiplier
        glowView?.updateBreathing(
            width: currentWidth,
            brightnessMultiplier: frame.brightness,
            softness: currentSoftness
        )
    }

    private func easeOutCubic(_ t: CGFloat) -> CGFloat {
        let t1 = t - 1
        return t1 * t1 * t1 + 1
    }

    @objc private func screenDidChange() {
        guard let screen = NSScreen.main else { return }
        overlayWindow?.setFrame(screen.frame, display: true)
        glowView?.frame = screen.frame.offsetBy(dx: -screen.frame.origin.x, dy: -screen.frame.origin.y)
        glowView?.needsDisplay = true
    }
}

final class GlowView: NSView {
    private var glowColor: NSColor = .white
    private var ringWidth: CGFloat = 25
    private var brightness: CGFloat = 0.8
    private var softness: CGFloat = 40

    // Cached color space
    private let hdrColorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB) ?? CGColorSpaceCreateDeviceRGB()

    // Cached gradient for normal mode (reused)
    private var cachedGradient: CGGradient?
    private var cachedGradientKey: String = ""

    // Precalculated breathing gradients (enough for smooth transitions)
    private var breathingGradients: [CGGradient] = []
    private var breathingGradientsColorKey: String = ""
    private let breathingLevels: Int = 128

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        // Enable HDR
        if let layer = self.layer {
            layer.wantsExtendedDynamicRangeContent = true
            layer.contentsFormat = .RGBA16Float
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateNormal(color: NSColor, width: CGFloat, brightness: CGFloat, softness: CGFloat) {
        self.glowColor = color
        self.ringWidth = width
        self.brightness = brightness
        self.softness = softness
        self.isBreathingMode = false
        needsDisplay = true
    }

    // Call this when color changes to rebuild breathing gradient cache
    func precalculateBreathingGradients(for color: NSColor) {
        var red: CGFloat = 1, green: CGFloat = 1, blue: CGFloat = 1, alpha: CGFloat = 1
        if let rgbColor = color.usingColorSpace(.sRGB) {
            rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        }

        let colorKey = "\(red),\(green),\(blue),\(breathingLevels)"
        guard colorKey != breathingGradientsColorKey else { return }

        breathingGradients.removeAll()
        breathingGradients.reserveCapacity(breathingLevels)
        let hdrMultiplier: CGFloat = 2.5

        // Precalculate gradients: 0% to 120% brightness with ultra-smooth falloff
        for i in 0..<breathingLevels {
            let brightnessMultiplier = CGFloat(i) / CGFloat(breathingLevels - 1) * 1.20 // 0 to 1.20
            let hdrBrightness = brightnessMultiplier * hdrMultiplier

            // Ultra-smooth gradient with 12 color stops for silky falloff
            let locations: [CGFloat] = [0, 0.02, 0.05, 0.10, 0.18, 0.28, 0.40, 0.55, 0.70, 0.85, 0.95, 1.0]
            let alphas: [CGFloat] = [
                hdrBrightness,
                hdrBrightness * 0.95,
                hdrBrightness * 0.85,
                hdrBrightness * 0.70,
                hdrBrightness * 0.52,
                hdrBrightness * 0.35,
                hdrBrightness * 0.22,
                hdrBrightness * 0.12,
                hdrBrightness * 0.05,
                hdrBrightness * 0.02,
                hdrBrightness * 0.005,
                0
            ]

            var components: [CGFloat] = []
            for a in alphas {
                components.append(contentsOf: [red * hdrBrightness, green * hdrBrightness, blue * hdrBrightness, a])
            }

            if let gradient = CGGradient(
                colorSpace: hdrColorSpace,
                colorComponents: components,
                locations: locations,
                count: locations.count
            ) {
                breathingGradients.append(gradient)
            }
        }

        breathingGradientsColorKey = colorKey
    }

    // Get precalculated gradient for a brightness multiplier (0 to 1.20)
    func getBreathingGradient(brightnessMultiplier: CGFloat) -> CGGradient? {
        guard !breathingGradients.isEmpty else { return nil }
        let normalizedValue = brightnessMultiplier / 1.20 // Map 0-1.20 to 0-1
        let index = Int(normalizedValue * CGFloat(breathingLevels - 1))
        let clampedIndex = Swift.max(0, Swift.min(breathingLevels - 1, index))
        return breathingGradients[clampedIndex]
    }

    // Breathing mode: uses precalculated gradients
    private var isBreathingMode = false
    private var breathingBrightnessMultiplier: CGFloat = 1.0

    // Black screen mode (for mini-LED)
    private var blackScreenEnabled = false
    private var blackScreenOpacity: CGFloat = 1.0
    private var blackScreenTargetOpacity: CGFloat = 1.0
    private var blackScreenFadeTimer: Timer?

    func setBlackScreen(_ enabled: Bool) {
        blackScreenEnabled = enabled
        blackScreenOpacity = 1.0
        blackScreenTargetOpacity = 1.0
        blackScreenFadeTimer?.invalidate()
        blackScreenFadeTimer = nil
        needsDisplay = true
    }

    // Precalculated fade steps for energy efficiency
    private static let fadeFrameRate: Double = 24
    private var fadeSteps: [(opacity: CGFloat, frameIndex: Int)] = []
    private var fadeCurrentFrame: Int = 0

    func animateBlackScreenOpacity(to targetOpacity: CGFloat, duration: TimeInterval) {
        blackScreenFadeTimer?.invalidate()
        blackScreenTargetOpacity = targetOpacity

        // Precalculate all fade steps
        let totalFrames = max(1, Int(duration * Self.fadeFrameRate))
        let startOpacity = blackScreenOpacity
        fadeSteps = (0...totalFrames).map { frame in
            let progress = CGFloat(frame) / CGFloat(totalFrames)
            let opacity = startOpacity + (targetOpacity - startOpacity) * progress
            return (opacity: opacity, frameIndex: frame)
        }
        fadeCurrentFrame = 0

        let stepDuration = 1.0 / Self.fadeFrameRate
        blackScreenFadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }

            if self.fadeCurrentFrame >= self.fadeSteps.count {
                self.blackScreenOpacity = targetOpacity
                timer.invalidate()
                self.blackScreenFadeTimer = nil
                self.fadeSteps = []
            } else {
                self.blackScreenOpacity = self.fadeSteps[self.fadeCurrentFrame].opacity
                self.fadeCurrentFrame += 1
            }
            self.needsDisplay = true
        }
    }

    func updateBreathing(width: CGFloat, brightnessMultiplier: CGFloat, softness: CGFloat) {
        self.ringWidth = width
        self.softness = softness
        self.breathingBrightnessMultiplier = brightnessMultiplier
        self.isBreathingMode = true
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)

        // Fill with black if enabled (for mini-LED pixel shutdown)
        // Fades out when mouse moves to allow user to see UI
        if blackScreenEnabled && blackScreenOpacity > 0 {
            context.setFillColor(NSColor.black.withAlphaComponent(blackScreenOpacity).cgColor)
            context.fill(bounds)
        }

        if isBreathingMode {
            drawBreathingGlow(context: context)
        } else {
            drawNormalGlow(context: context)
        }
    }

    // MARK: - Breathing Glow (uses precalculated gradients)

    private func drawBreathingGlow(context: CGContext) {
        let totalGlowWidth = ringWidth + softness

        guard let gradient = getBreathingGradient(brightnessMultiplier: breathingBrightnessMultiplier) else {
            // Fallback to normal if gradients not precalculated
            drawNormalGlow(context: context)
            return
        }

        drawAllEdges(context: context, gradient: gradient, glowWidth: totalGlowWidth)
    }

    // MARK: - Normal Glow

    private func drawNormalGlow(context: CGContext) {
        let totalGlowWidth = ringWidth + softness
        let hdrMultiplier: CGFloat = 2.5

        var red: CGFloat = 1, green: CGFloat = 1, blue: CGFloat = 1, alpha: CGFloat = 1
        if let rgbColor = glowColor.usingColorSpace(.sRGB) {
            rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        }

        let hdrBrightness = brightness * hdrMultiplier

        // Cache key for gradient reuse
        let key = "\(red),\(green),\(blue),\(hdrBrightness)"

        let gradient: CGGradient
        if key == cachedGradientKey, let cached = cachedGradient {
            gradient = cached
        } else {
            // Ultra-smooth gradient with 12 color stops for silky falloff
            let locations: [CGFloat] = [0, 0.02, 0.05, 0.10, 0.18, 0.28, 0.40, 0.55, 0.70, 0.85, 0.95, 1.0]
            let alphas: [CGFloat] = [
                hdrBrightness,
                hdrBrightness * 0.95,
                hdrBrightness * 0.85,
                hdrBrightness * 0.70,
                hdrBrightness * 0.52,
                hdrBrightness * 0.35,
                hdrBrightness * 0.22,
                hdrBrightness * 0.12,
                hdrBrightness * 0.05,
                hdrBrightness * 0.02,
                hdrBrightness * 0.005,
                0
            ]

            var components: [CGFloat] = []
            for a in alphas {
                components.append(contentsOf: [red * hdrBrightness, green * hdrBrightness, blue * hdrBrightness, a])
            }

            guard let newGradient = CGGradient(
                colorSpace: hdrColorSpace,
                colorComponents: components,
                locations: locations,
                count: locations.count
            ) else { return }

            cachedGradient = newGradient
            cachedGradientKey = key
            gradient = newGradient
        }

        drawAllEdges(context: context, gradient: gradient, glowWidth: totalGlowWidth)
    }

    // MARK: - Draw edges

    private func drawAllEdges(context: CGContext, gradient: CGGradient, glowWidth: CGFloat) {
        let edges: [(CGRect, CGPoint, CGPoint)] = [
            (CGRect(x: 0, y: bounds.height - glowWidth, width: bounds.width, height: glowWidth),
             CGPoint(x: bounds.midX, y: bounds.height),
             CGPoint(x: bounds.midX, y: bounds.height - glowWidth)),
            (CGRect(x: 0, y: 0, width: bounds.width, height: glowWidth),
             CGPoint(x: bounds.midX, y: 0),
             CGPoint(x: bounds.midX, y: glowWidth)),
            (CGRect(x: 0, y: 0, width: glowWidth, height: bounds.height),
             CGPoint(x: 0, y: bounds.midY),
             CGPoint(x: glowWidth, y: bounds.midY)),
            (CGRect(x: bounds.width - glowWidth, y: 0, width: glowWidth, height: bounds.height),
             CGPoint(x: bounds.width, y: bounds.midY),
             CGPoint(x: bounds.width - glowWidth, y: bounds.midY))
        ]

        for (rect, start, end) in edges {
            context.saveGState()
            context.clip(to: rect)
            context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsAfterEndLocation])
            context.restoreGState()
        }

        // Corners
        let corners: [(CGRect, CGPoint)] = [
            (CGRect(x: 0, y: bounds.height - glowWidth, width: glowWidth, height: glowWidth),
             CGPoint(x: 0, y: bounds.height)),
            (CGRect(x: bounds.width - glowWidth, y: bounds.height - glowWidth, width: glowWidth, height: glowWidth),
             CGPoint(x: bounds.width, y: bounds.height)),
            (CGRect(x: 0, y: 0, width: glowWidth, height: glowWidth),
             CGPoint(x: 0, y: 0)),
            (CGRect(x: bounds.width - glowWidth, y: 0, width: glowWidth, height: glowWidth),
             CGPoint(x: bounds.width, y: 0))
        ]

        for (rect, center) in corners {
            context.saveGState()
            context.clip(to: rect)
            context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: glowWidth, options: [.drawsAfterEndLocation])
            context.restoreGState()
        }
    }
}
