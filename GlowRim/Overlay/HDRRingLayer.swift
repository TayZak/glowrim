import AppKit
import QuartzCore
import CoreGraphics

/// CALayer that renders HDR ring light with bloom effect
final class HDRRingLayer: CALayer {
    // MARK: - Properties

    private var ringPath: CGPath?
    private var ringCenter: CGPoint = .zero
    private var outerRadius: CGFloat = 0
    private var innerRadius: CGFloat = 0

    private var red: CGFloat = 1.0
    private var green: CGFloat = 0.95
    private var blue: CGFloat = 0.9
    private var intensity: CGFloat = 0.8

    private var bloomLayer: CALayer?

    // MARK: - Initialization

    override init() {
        super.init()
        setupLayer()
    }

    override init(layer: Any) {
        super.init(layer: layer)
        if let other = layer as? HDRRingLayer {
            ringPath = other.ringPath
            ringCenter = other.ringCenter
            outerRadius = other.outerRadius
            innerRadius = other.innerRadius
            red = other.red
            green = other.green
            blue = other.blue
            intensity = other.intensity
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    private func setupLayer() {
        // Enable HDR rendering
        if #available(macOS 10.15, *) {
            wantsExtendedDynamicRangeContent = true
        }

        // Use extended linear display P3 for HDR
        if let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3) {
            self.colorspace = colorSpace
        }

        isOpaque = false
        backgroundColor = CGColor.clear

        // Create bloom sublayer for glow effect
        let bloom = CALayer()
        bloom.isOpaque = false
        bloom.backgroundColor = CGColor.clear
        addSublayer(bloom)
        bloomLayer = bloom
    }

    // MARK: - Path Updates

    func updatePath(_ path: CGPath, center: CGPoint, outerRadius: CGFloat, innerRadius: CGFloat) {
        self.ringPath = path
        self.ringCenter = center
        self.outerRadius = outerRadius
        self.innerRadius = innerRadius

        setNeedsDisplay()
        updateBloom()
    }

    // MARK: - Color and Intensity

    func setColor(red: Double, green: Double, blue: Double) {
        self.red = CGFloat(red)
        self.green = CGFloat(green)
        self.blue = CGFloat(blue)
        setNeedsDisplay()
        updateBloom()
    }

    func setIntensity(_ value: Double) {
        self.intensity = CGFloat(value)
        setNeedsDisplay()
        updateBloom()
    }

    // MARK: - Drawing

    override func draw(in ctx: CGContext) {
        guard let path = ringPath else { return }

        // Calculate HDR color values
        let hdrMultiplier = calculateHDRMultiplier()

        let hdrRed = red * hdrMultiplier
        let hdrGreen = green * hdrMultiplier
        let hdrBlue = blue * hdrMultiplier

        // Create HDR color (values > 1.0 for extended brightness)
        let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3) ?? CGColorSpaceCreateDeviceRGB()
        let components: [CGFloat] = [hdrRed, hdrGreen, hdrBlue, 1.0]

        guard let hdrColor = CGColor(colorSpace: colorSpace, components: components) else { return }

        // Draw ring
        ctx.saveGState()

        // Fill rule for ring (outer - inner)
        ctx.addPath(path)
        ctx.setFillColor(hdrColor)
        ctx.fillPath(using: .evenOdd)

        ctx.restoreGState()

        // Draw gradient for depth effect
        drawGradientOverlay(in: ctx)
    }

    private func calculateHDRMultiplier() -> CGFloat {
        // Check if display supports HDR
        guard let screen = NSScreen.main else {
            return intensity
        }

        if #available(macOS 10.15, *) {
            let headroom = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
            if headroom > 1.0 {
                // Scale intensity to use HDR headroom
                // intensity 1.0 = full HDR (up to 4x brightness on XDR displays)
                return intensity * min(Constants.maxHDRMultiplier, headroom)
            }
        }

        return intensity
    }

    private func drawGradientOverlay(in ctx: CGContext) {
        guard innerRadius > 0, outerRadius > innerRadius else { return }

        ctx.saveGState()

        // Create subtle gradient for 3D effect
        let locations: [CGFloat] = [0.0, 0.3, 0.7, 1.0]
        let components: [CGFloat] = [
            1.0, 1.0, 1.0, 0.0,    // Inner edge - transparent
            1.0, 1.0, 1.0, 0.1,    // Inner highlight
            1.0, 1.0, 1.0, 0.05,   // Outer shadow
            1.0, 1.0, 1.0, 0.0     // Outer edge - transparent
        ]

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(
            colorSpace: colorSpace,
            colorComponents: components,
            locations: locations,
            count: locations.count
        ) else {
            ctx.restoreGState()
            return
        }

        // Clip to ring path
        if let path = ringPath {
            ctx.addPath(path)
            ctx.clip(using: .evenOdd)
        }

        // Draw radial gradient
        ctx.drawRadialGradient(
            gradient,
            startCenter: ringCenter,
            startRadius: innerRadius,
            endCenter: ringCenter,
            endRadius: outerRadius,
            options: []
        )

        ctx.restoreGState()
    }

    // MARK: - Bloom Effect

    private func updateBloom() {
        guard let bloom = bloomLayer else { return }

        bloom.frame = bounds

        // Create bloom image
        let bloomSize = bounds.size
        guard bloomSize.width > 0, bloomSize.height > 0 else { return }

        // Bloom is a blurred, semi-transparent version of the ring
        let bloomImage = createBloomImage(size: bloomSize)
        bloom.contents = bloomImage
        bloom.opacity = Float(intensity * 0.3)
    }

    private func createBloomImage(size: CGSize) -> CGImage? {
        guard let path = ringPath else { return nil }

        // Create context for bloom
        let scale = contentsScale
        let pixelWidth = Int(size.width * scale)
        let pixelHeight = Int(size.height * scale)

        guard pixelWidth > 0, pixelHeight > 0 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.scaleBy(x: scale, y: scale)

        // Draw ring with glow color
        let glowColor = CGColor(red: red, green: green, blue: blue, alpha: 0.5)
        ctx.addPath(path)
        ctx.setFillColor(glowColor)
        ctx.fillPath(using: .evenOdd)

        return ctx.makeImage()
    }
}

// MARK: - CALayer HDR Extension

extension CALayer {
    /// Enables extended dynamic range content if available
    @available(macOS 10.15, *)
    var wantsExtendedDynamicRangeContent: Bool {
        get {
            value(forKey: "wantsExtendedDynamicRangeContent") as? Bool ?? false
        }
        set {
            setValue(newValue, forKey: "wantsExtendedDynamicRangeContent")
        }
    }

    /// Sets the color space for HDR rendering
    var colorspace: CGColorSpace? {
        get {
            let val = value(forKey: "colorspace")
            return val as! CGColorSpace?
        }
        set {
            setValue(newValue, forKey: "colorspace")
        }
    }
}
