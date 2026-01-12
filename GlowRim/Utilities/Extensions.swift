import SwiftUI
import AppKit

// MARK: - Color Extensions

extension Color {
    /// Creates a Color from HSB values (0-1 range)
    init(hue: Double, saturation: Double, brightness: Double) {
        self.init(
            hue: hue,
            saturation: saturation,
            brightness: brightness,
            opacity: 1.0
        )
    }

    /// Returns HSB components
    var hsbComponents: (hue: Double, saturation: Double, brightness: Double) {
        let nsColor = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor.white
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        nsColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (Double(h), Double(s), Double(b))
    }

    /// Applies HDR intensity multiplier
    func withHDRIntensity(_ multiplier: Double) -> (red: Double, green: Double, blue: Double) {
        let nsColor = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor.white
        return (
            red: Double(nsColor.redComponent) * multiplier,
            green: Double(nsColor.greenComponent) * multiplier,
            blue: Double(nsColor.blueComponent) * multiplier
        )
    }
}

extension NSColor {
    /// Creates HDR color components with extended range
    func hdrComponents(multiplier: Double) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let rgb = self.usingColorSpace(.deviceRGB) ?? self
        return (
            red: rgb.redComponent * CGFloat(multiplier),
            green: rgb.greenComponent * CGFloat(multiplier),
            blue: rgb.blueComponent * CGFloat(multiplier)
        )
    }
}

// MARK: - CGFloat Extensions

extension CGFloat {
    /// Linear interpolation
    func lerp(to: CGFloat, progress: CGFloat) -> CGFloat {
        self + (to - self) * progress
    }

    /// Clamps value to range
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }

    /// Maps from one range to another
    func mapped(from: ClosedRange<CGFloat>, to: ClosedRange<CGFloat>) -> CGFloat {
        let normalized = (self - from.lowerBound) / (from.upperBound - from.lowerBound)
        return to.lowerBound + normalized * (to.upperBound - to.lowerBound)
    }
}

extension Double {
    /// Linear interpolation
    func lerp(to: Double, progress: Double) -> Double {
        self + (to - self) * progress
    }

    /// Clamps value to range
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - CGPoint Extensions

extension CGPoint {
    /// Distance to another point
    func distance(to point: CGPoint) -> CGFloat {
        sqrt(pow(x - point.x, 2) + pow(y - point.y, 2))
    }
}

// MARK: - CGRect Extensions

extension CGRect {
    /// Center point of the rect
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }

    /// Creates a centered rect with given size
    func centeredRect(size: CGSize) -> CGRect {
        CGRect(
            x: midX - size.width / 2,
            y: midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}

// MARK: - NSScreen Extensions

extension NSScreen {
    /// Returns the main screen's frame (accounting for menu bar and dock)
    static var mainScreenFrame: CGRect {
        main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
    }

    /// Returns true if the screen supports HDR
    var supportsHDR: Bool {
        if #available(macOS 10.15, *) {
            return maximumPotentialExtendedDynamicRangeColorComponentValue > 1.0
        }
        return false
    }

    /// Returns the maximum HDR headroom multiplier
    var hdrHeadroom: CGFloat {
        if #available(macOS 10.15, *) {
            return maximumPotentialExtendedDynamicRangeColorComponentValue
        }
        return 1.0
    }

    /// Checks if this is a MacBook Pro with notch
    var hasNotch: Bool {
        if #available(macOS 12.0, *) {
            return safeAreaInsets.top > 0
        }
        return false
    }
}

// MARK: - Animation Extensions

extension Animation {
    /// Smooth spring animation for UI elements
    static var smoothSpring: Animation {
        .spring(response: 0.4, dampingFraction: 0.8)
    }

    /// Quick spring for toggles
    static var quickSpring: Animation {
        .spring(response: 0.25, dampingFraction: 0.7)
    }
}

// MARK: - View Extensions

extension View {
    /// Applies a glow effect
    func glow(color: Color, radius: CGFloat) -> some View {
        self
            .shadow(color: color.opacity(0.5), radius: radius / 2)
            .shadow(color: color.opacity(0.3), radius: radius)
            .shadow(color: color.opacity(0.1), radius: radius * 2)
    }
}
