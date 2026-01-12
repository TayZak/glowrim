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
    private var campfireMode: Bool = false
    private var breathingEnabled: Bool = true

    // Animation
    private var animationTimer: Timer?
    private var animationStartTime: CFTimeInterval = 0
    private var fadeInProgress: CGFloat = 0
    private var isFadingIn = false

    private init() {}

    func show(color: NSColor, width: CGFloat, brightness: CGFloat, softness: CGFloat, campfireMode: Bool, breathingEnabled: Bool) {
        baseColor = color
        baseWidth = width
        baseBrightness = brightness
        baseSoftness = softness
        self.campfireMode = campfireMode
        self.breathingEnabled = breathingEnabled

        if overlayWindow == nil {
            createWindow()
        }

        // Precalculate gradients based on mode
        if campfireMode {
            glowView?.precalculateFireGradients(baseBrightness: brightness)
        } else if breathingEnabled {
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

    func hide() {
        stopAnimation()

        // Fade out
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            overlayWindow?.animator().alphaValue = 0
        }, completionHandler: {
            self.overlayWindow?.orderOut(nil)
        })
    }

    func update(color: NSColor, width: CGFloat, brightness: CGFloat, softness: CGFloat, campfireMode: Bool, breathingEnabled: Bool) {
        let brightnessChanged = baseBrightness != brightness

        baseColor = color
        baseWidth = width
        baseBrightness = brightness
        baseSoftness = softness
        self.campfireMode = campfireMode
        self.breathingEnabled = breathingEnabled

        // Precalculate gradients based on mode
        if campfireMode {
            // Invalidate fire gradients if brightness changed
            if brightnessChanged {
                glowView?.invalidateFireGradients()
            }
            glowView?.precalculateFireGradients(baseBrightness: brightness)
        } else if breathingEnabled {
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

        // Ultra-low frame rates for minimal CPU:
        // - Campfire: 12fps (still smooth enough for fire)
        // - Breathing: 8fps (very slow animation)
        // - Static: 0.5fps (just keep-alive)
        let fps: Double
        if campfireMode {
            fps = 12.0
        } else if breathingEnabled {
            fps = 8.0
        } else {
            fps = 0.5
        }

        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/fps, repeats: true) { [weak self] _ in
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

        if campfireMode {
            updateCampfire(time: time)
        } else if breathingEnabled {
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

    private func updateNormalBreathing(time: Double) {
        // EXTREME breathing like lungs - can go to 0%
        let breathe1 = sin(time * 0.15) // Very slow primary breath (40 sec cycle)
        let breathe2 = sin(time * 0.4) * 0.4 // Secondary wave
        let breathe3 = sin(time * 0.08) // Ultra slow drift (80 sec cycle)

        // Combined breath: ranges from -1 to +1
        let combinedBreath = (breathe1 + breathe2) / 1.4

        // Brightness multiplier: 0 to 1.3 (maps to precalculated gradients)
        let brightnessMultiplier = Swift.max(0, (combinedBreath + 1) * 0.65) // 0 to 1.3

        // Width: 40% to 180% of base (dramatic expansion/contraction)
        let widthMultiplier = 0.4 + (breathe1 + 1) * 0.7 + breathe3 * 0.2
        let currentWidth = baseWidth * CGFloat(widthMultiplier)

        // Softness: 30% to 200% of base
        let softnessMultiplier = 0.3 + (breathe2 + 1) * 0.85 + breathe3 * 0.3
        let currentSoftness = baseSoftness * CGFloat(softnessMultiplier)

        // Use precalculated gradient based on brightness multiplier
        glowView?.updateBreathing(
            width: currentWidth,
            brightnessMultiplier: CGFloat(brightnessMultiplier),
            softness: currentSoftness
        )
    }

    private func updateCampfire(time: Double) {
        // Width breathing for fire
        let widthBreath = 1.0 + sin(time * 2.0) * 0.2 + sin(time * 4.5) * 0.1
        let currentWidth = baseWidth * CGFloat(widthBreath)

        // Softness variation
        let softnessBreath = 1.0 + sin(time * 1.5) * 0.3
        let currentSoftness = baseSoftness * CGFloat(softnessBreath)

        glowView?.updateCampfireOptimized(
            time: time,
            width: currentWidth,
            brightness: baseBrightness,
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
    private var isCampfire: Bool = false
    private var campfireTime: Double = 0

    // Pre-computed noise offsets (small array = less RAM)
    private let noiseOffsets: [Double] = (0..<50).map { _ in Double.random(in: 0...100) }

    // Cached color space
    private let hdrColorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB) ?? CGColorSpaceCreateDeviceRGB()

    // Cached gradient for normal mode (reused)
    private var cachedGradient: CGGradient?
    private var cachedGradientKey: String = ""

    // Precalculated breathing gradients (64 levels from 0% to 130% brightness for smooth transitions)
    private var breathingGradients: [CGGradient] = []
    private var breathingGradientsColorKey: String = ""
    private let breathingLevels = 64

    // Precalculated fire gradients: 32 intensity levels × 8 color levels = 256 gradients
    private var fireGradients: [[CGGradient]] = [] // [intensityIndex][colorIndex]
    private var fireGradientsReady = false
    private let fireIntensityLevels = 32
    private let fireColorLevels = 8

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
        self.isCampfire = false
        self.isBreathingMode = false
        needsDisplay = true
    }

    // Call this when color changes to rebuild breathing gradient cache
    func precalculateBreathingGradients(for color: NSColor) {
        var red: CGFloat = 1, green: CGFloat = 1, blue: CGFloat = 1, alpha: CGFloat = 1
        if let rgbColor = color.usingColorSpace(.sRGB) {
            rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        }

        let colorKey = "\(red),\(green),\(blue)"
        guard colorKey != breathingGradientsColorKey else { return }

        breathingGradients.removeAll()
        let hdrMultiplier: CGFloat = 2.5

        // Precalculate 16 gradients: 0%, 8.7%, 17.3%, ..., 130% brightness
        for i in 0..<breathingLevels {
            let brightnessMultiplier = CGFloat(i) / CGFloat(breathingLevels - 1) * 1.3
            let hdrBrightness = brightnessMultiplier * hdrMultiplier

            let locations: [CGFloat] = [0, 0.05, 0.15, 0.35, 0.6, 1.0]
            let alphas: [CGFloat] = [hdrBrightness, hdrBrightness * 0.8, hdrBrightness * 0.5, hdrBrightness * 0.2, hdrBrightness * 0.05, 0]

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

    // Get precalculated gradient for a brightness multiplier (0 to 1.3)
    func getBreathingGradient(brightnessMultiplier: CGFloat) -> CGGradient? {
        guard !breathingGradients.isEmpty else { return nil }
        let index = Int((brightnessMultiplier / 1.3) * CGFloat(breathingLevels - 1))
        let clampedIndex = Swift.max(0, Swift.min(breathingLevels - 1, index))
        return breathingGradients[clampedIndex]
    }

    // Precalculate fire gradients (called once at startup or when campfire mode enabled)
    func precalculateFireGradients(baseBrightness: CGFloat) {
        guard !fireGradientsReady else { return }

        let hdrMultiplier: CGFloat = 3.0
        fireGradients = []

        // Intensity range: 0.5 to 1.1 (based on flameValue calculation)
        // Color shift range: 0 to 1 (maps to green 0.35 to 0.65)
        for intensityIdx in 0..<fireIntensityLevels {
            var colorRow: [CGGradient] = []
            let intensity = 0.5 + CGFloat(intensityIdx) / CGFloat(fireIntensityLevels - 1) * 0.6

            for colorIdx in 0..<fireColorLevels {
                let colorShift = CGFloat(colorIdx) / CGFloat(fireColorLevels - 1)

                let red: CGFloat = 1.0
                let green: CGFloat = 0.35 + colorShift * 0.3
                let blue: CGFloat = 0.05

                let hdrBrightness = baseBrightness * hdrMultiplier * intensity

                let locations: [CGFloat] = [0, 0.08, 0.25, 0.5, 0.8, 1.0]
                let alphas: [CGFloat] = [hdrBrightness, hdrBrightness * 0.7, hdrBrightness * 0.35, hdrBrightness * 0.12, hdrBrightness * 0.02, 0]

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
                    colorRow.append(gradient)
                }
            }
            fireGradients.append(colorRow)
        }

        fireGradientsReady = true
    }

    // Get precalculated fire gradient
    // intensity: 0.5 to 1.1, colorShift: 0 to 1
    func getFireGradient(intensity: CGFloat, colorShift: CGFloat) -> CGGradient? {
        guard fireGradientsReady, !fireGradients.isEmpty else { return nil }

        let normalizedIntensity = (intensity - 0.5) / 0.6 // 0 to 1
        let intensityIdx = Int(normalizedIntensity * CGFloat(fireIntensityLevels - 1))
        let clampedIntensityIdx = Swift.max(0, Swift.min(fireIntensityLevels - 1, intensityIdx))

        let colorIdx = Int(colorShift * CGFloat(fireColorLevels - 1))
        let clampedColorIdx = Swift.max(0, Swift.min(fireColorLevels - 1, colorIdx))

        return fireGradients[clampedIntensityIdx][clampedColorIdx]
    }

    // Invalidate fire gradients when brightness changes
    func invalidateFireGradients() {
        fireGradientsReady = false
        fireGradients.removeAll()
    }

    // Breathing mode: uses precalculated gradients
    private var isBreathingMode = false
    private var breathingBrightnessMultiplier: CGFloat = 1.0

    func updateBreathing(width: CGFloat, brightnessMultiplier: CGFloat, softness: CGFloat) {
        self.ringWidth = width
        self.softness = softness
        self.breathingBrightnessMultiplier = brightnessMultiplier
        self.isBreathingMode = true
        self.isCampfire = false
        needsDisplay = true
    }

    func updateCampfireOptimized(time: Double, width: CGFloat, brightness: CGFloat, softness: CGFloat) {
        self.campfireTime = time
        self.ringWidth = width
        self.isBreathingMode = false
        self.brightness = brightness
        self.softness = softness
        self.isCampfire = true
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)

        if isCampfire {
            drawOptimizedFire(context: context)
        } else if isBreathingMode {
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

    // MARK: - Fast noise (optimized)

    @inline(__always)
    private func fastNoise(_ x: Double, _ offset: Double) -> Double {
        // Simplified 2-octave noise - much faster
        let n1 = sin(x * 0.03 + offset)
        let n2 = sin(x * 0.07 + offset * 1.3) * 0.5
        return (n1 + n2) / 1.5
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
            let locations: [CGFloat] = [0, 0.05, 0.15, 0.35, 0.6, 1.0]
            let alphas: [CGFloat] = [hdrBrightness, hdrBrightness * 0.8, hdrBrightness * 0.5, hdrBrightness * 0.2, hdrBrightness * 0.05, 0]

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

    // MARK: - Optimized Fire (low CPU)

    private func drawOptimizedFire(context: CGContext) {
        let totalGlowWidth = ringWidth + softness
        let hdrMultiplier: CGFloat = 3.0
        let time = campfireTime

        // OPTIMIZATION: Sample every 20 pixels (10x less work than original)
        let step: CGFloat = 20

        // Draw all 4 edges with optimized sampling
        drawOptimizedFireEdge(context: context, edge: .top, time: time, glowWidth: totalGlowWidth, hdrMultiplier: hdrMultiplier, step: step)
        drawOptimizedFireEdge(context: context, edge: .bottom, time: time, glowWidth: totalGlowWidth, hdrMultiplier: hdrMultiplier, step: step)
        drawOptimizedFireEdge(context: context, edge: .left, time: time, glowWidth: totalGlowWidth, hdrMultiplier: hdrMultiplier, step: step)
        drawOptimizedFireEdge(context: context, edge: .right, time: time, glowWidth: totalGlowWidth, hdrMultiplier: hdrMultiplier, step: step)

        // Corners
        drawOptimizedFireCorner(context: context, corner: .topLeft, time: time, glowWidth: totalGlowWidth, hdrMultiplier: hdrMultiplier)
        drawOptimizedFireCorner(context: context, corner: .topRight, time: time, glowWidth: totalGlowWidth, hdrMultiplier: hdrMultiplier)
        drawOptimizedFireCorner(context: context, corner: .bottomLeft, time: time, glowWidth: totalGlowWidth, hdrMultiplier: hdrMultiplier)
        drawOptimizedFireCorner(context: context, corner: .bottomRight, time: time, glowWidth: totalGlowWidth, hdrMultiplier: hdrMultiplier)
    }

    private enum Edge { case top, bottom, left, right }
    private enum Corner { case topLeft, topRight, bottomLeft, bottomRight }

    private func drawOptimizedFireEdge(context: CGContext, edge: Edge, time: Double, glowWidth: CGFloat, hdrMultiplier: CGFloat, step: CGFloat) {
        let edgeLength: CGFloat
        switch edge {
        case .top, .bottom: edgeLength = bounds.width
        case .left, .right: edgeLength = bounds.height
        }

        let sampleCount = Int(edgeLength / step)

        for i in 0..<sampleCount {
            let pos = CGFloat(i) * step
            let nextPos = CGFloat(i + 1) * step

            // Fast noise lookup using pre-computed offsets
            let noiseIndex = i % noiseOffsets.count
            let offset = noiseOffsets[noiseIndex]

            // Simplified flame calculation
            let n1 = fastNoise(time * 40 + Double(pos) * 0.1, offset)
            let n2 = fastNoise(time * 80 + Double(pos) * 0.15, offset * 1.7) * 0.4
            let flicker = sin(time * 12 + offset) > 0.7 ? 0.2 : 0.0

            let flameValue = (n1 + n2) * 0.5 + 0.5 + flicker
            let intensity = CGFloat(0.5 + flameValue * 0.6)

            // Color shift: 0 to 1
            let colorShift = CGFloat((n1 + 1) * 0.5)

            let localGlowWidth = glowWidth * CGFloat(0.75 + flameValue * 0.5)

            // Use precalculated gradient
            guard let gradient = getFireGradient(intensity: intensity, colorShift: colorShift) else { continue }

            context.saveGState()

            let clipRect: CGRect
            let gradStart: CGPoint
            let gradEnd: CGPoint

            switch edge {
            case .top:
                clipRect = CGRect(x: pos, y: bounds.height - localGlowWidth, width: nextPos - pos, height: localGlowWidth)
                gradStart = CGPoint(x: (pos + nextPos) / 2, y: bounds.height)
                gradEnd = CGPoint(x: (pos + nextPos) / 2, y: bounds.height - localGlowWidth)
            case .bottom:
                clipRect = CGRect(x: pos, y: 0, width: nextPos - pos, height: localGlowWidth)
                gradStart = CGPoint(x: (pos + nextPos) / 2, y: 0)
                gradEnd = CGPoint(x: (pos + nextPos) / 2, y: localGlowWidth)
            case .left:
                clipRect = CGRect(x: 0, y: pos, width: localGlowWidth, height: nextPos - pos)
                gradStart = CGPoint(x: 0, y: (pos + nextPos) / 2)
                gradEnd = CGPoint(x: localGlowWidth, y: (pos + nextPos) / 2)
            case .right:
                clipRect = CGRect(x: bounds.width - localGlowWidth, y: pos, width: localGlowWidth, height: nextPos - pos)
                gradStart = CGPoint(x: bounds.width, y: (pos + nextPos) / 2)
                gradEnd = CGPoint(x: bounds.width - localGlowWidth, y: (pos + nextPos) / 2)
            }

            context.clip(to: clipRect)
            context.drawLinearGradient(gradient, start: gradStart, end: gradEnd, options: [.drawsAfterEndLocation])
            context.restoreGState()
        }
    }

    private func drawOptimizedFireCorner(context: CGContext, corner: Corner, time: Double, glowWidth: CGFloat, hdrMultiplier: CGFloat) {
        let center: CGPoint
        let clipRect: CGRect
        let cornerIndex: Int

        switch corner {
        case .topLeft:
            center = CGPoint(x: 0, y: bounds.height)
            clipRect = CGRect(x: 0, y: bounds.height - glowWidth, width: glowWidth, height: glowWidth)
            cornerIndex = 0
        case .topRight:
            center = CGPoint(x: bounds.width, y: bounds.height)
            clipRect = CGRect(x: bounds.width - glowWidth, y: bounds.height - glowWidth, width: glowWidth, height: glowWidth)
            cornerIndex = 1
        case .bottomLeft:
            center = CGPoint(x: 0, y: 0)
            clipRect = CGRect(x: 0, y: 0, width: glowWidth, height: glowWidth)
            cornerIndex = 2
        case .bottomRight:
            center = CGPoint(x: bounds.width, y: 0)
            clipRect = CGRect(x: bounds.width - glowWidth, y: 0, width: glowWidth, height: glowWidth)
            cornerIndex = 3
        }

        let offset = noiseOffsets[cornerIndex]
        let n1 = fastNoise(time * 40, offset)
        let intensity = CGFloat(0.6 + n1 * 0.3)
        let colorShift = CGFloat((n1 + 1) * 0.5)

        // Use precalculated gradient
        guard let gradient = getFireGradient(intensity: intensity, colorShift: colorShift) else { return }

        context.saveGState()
        context.clip(to: clipRect)
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: glowWidth, options: [.drawsAfterEndLocation])
        context.restoreGState()
    }

    // MARK: - Normal edges

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
