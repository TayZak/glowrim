import AppKit
import QuartzCore

/// NSView that renders the screen border ring light with animations
final class RingLightView: NSView {
    // MARK: - Layers

    private var ringLayer: CAShapeLayer!
    private var glowLayer: CAShapeLayer!

    // MARK: - Animation

    private var animationTimer: Timer?
    private var isAnimating = false
    private var animationStartTime: CFTimeInterval = 0

    // MARK: - Cached values

    private var cachedPath: CGPath?
    private var lastBounds: CGRect = .zero
    private var lastRingWidth: CGFloat = 0
    private var lastCornerRadius: CGFloat = 0

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    deinit {
        stopAnimation()
    }

    private func setupLayers() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        // Create glow layer (behind ring for soft glow effect)
        glowLayer = CAShapeLayer()
        glowLayer.fillColor = nil
        glowLayer.lineCap = .round
        glowLayer.lineJoin = .round

        // Create main ring layer
        ringLayer = CAShapeLayer()
        ringLayer.fillColor = nil
        ringLayer.lineCap = .round
        ringLayer.lineJoin = .round

        // Add layers
        layer?.addSublayer(glowLayer)
        layer?.addSublayer(ringLayer)

        // Initial update
        updateRingPath()
        updateFromSettings()
    }

    override func layout() {
        super.layout()
        updateRingPath()
    }

    // MARK: - Ring Path (Rectangle border)

    func updateRingPath() {
        let settings = LightSettings.shared
        let ringWidth = CGFloat(settings.ringWidth)
        let cornerRadiusPercent = CGFloat(settings.cornerRadius)

        // Check if we need to recalculate
        guard bounds != lastBounds || ringWidth != lastRingWidth || cornerRadiusPercent != lastCornerRadius else {
            return
        }

        lastBounds = bounds
        lastRingWidth = ringWidth
        lastCornerRadius = cornerRadiusPercent

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        glowLayer.frame = bounds
        ringLayer.frame = bounds

        // Calculate corner radius based on screen size
        let minDimension = Swift.min(bounds.width, bounds.height)
        let cornerRadius = minDimension * cornerRadiusPercent

        // Create rounded rectangle path for the screen border
        // The path is the CENTER of the stroke, so inset by half the ring width
        let inset = ringWidth / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)

        let path = CGPath(
            roundedRect: rect,
            cornerWidth: Swift.max(0, cornerRadius - inset),
            cornerHeight: Swift.max(0, cornerRadius - inset),
            transform: nil
        )

        ringLayer.path = path
        ringLayer.lineWidth = ringWidth

        glowLayer.path = path
        glowLayer.lineWidth = ringWidth + CGFloat(settings.softness) * 2

        cachedPath = path

        CATransaction.commit()
    }

    // MARK: - Settings

    func updateFromSettings() {
        let settings = LightSettings.shared

        // Update path if dimensions changed
        updateRingPath()

        // Update colors
        let color = NSColor(
            red: settings.red,
            green: settings.green,
            blue: settings.blue,
            alpha: 1.0
        ).cgColor

        let brightness = CGFloat(settings.brightness)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Main ring with full brightness
        ringLayer.strokeColor = color
        ringLayer.opacity = Float(brightness)

        // Glow layer with softness
        let softness = CGFloat(settings.softness)
        glowLayer.strokeColor = color
        glowLayer.opacity = Float(brightness * 0.4)
        glowLayer.shadowColor = color
        glowLayer.shadowRadius = softness
        glowLayer.shadowOpacity = Float(brightness * 0.6)
        glowLayer.shadowOffset = .zero

        CATransaction.commit()
    }

    // MARK: - Animation

    func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true

        animationStartTime = CACurrentMediaTime()

        // Use Timer for smooth animation (60fps = 1/60 seconds interval)
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.updateAnimation()
        }
        // Ensure timer runs during UI events
        if let timer = animationTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stopAnimation() {
        isAnimating = false
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func updateAnimation() {
        guard isAnimating else { return }

        let settings = LightSettings.shared
        let speed = settings.animationSpeed

        switch settings.mode {
        case .constant:
            // Static - no animation needed
            break

        case .pulsating:
            updatePulsatingAnimation(speed: speed)
        }
    }

    private func updatePulsatingAnimation(speed: Double) {
        let settings = LightSettings.shared
        let time = (CACurrentMediaTime() - animationStartTime) * speed * 0.5

        // Smooth sine wave between 80% and 100% of base brightness
        let oscillation = (sin(time) + 1) / 2
        let minBrightness = settings.brightness * 0.80
        let maxBrightness = settings.brightness * 1.0
        let currentBrightness = minBrightness + oscillation * (maxBrightness - minBrightness)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ringLayer.opacity = Float(currentBrightness)
        glowLayer.opacity = Float(currentBrightness * 0.4)
        glowLayer.shadowOpacity = Float(currentBrightness * 0.6)
        CATransaction.commit()
    }
}
