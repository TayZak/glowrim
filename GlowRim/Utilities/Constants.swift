import Foundation
import CoreGraphics

enum Constants {
    // MARK: - Ring Dimensions

    /// Ring outer radius as percentage of screen min dimension
    static let ringOuterRadiusPercent: CGFloat = 0.85

    /// Ring thickness as percentage of screen width
    static let ringThicknessPercent: CGFloat = 0.08

    /// Minimum ring thickness in points
    static let ringMinThickness: CGFloat = 40

    /// Maximum ring thickness in points
    static let ringMaxThickness: CGFloat = 120

    // MARK: - Control Panel

    /// Control panel window size
    static let controlPanelSize = CGSize(width: 350, height: 450)

    /// Power button size
    static let powerButtonSize: CGFloat = 100

    // MARK: - Animation Timings

    /// Fade in duration in seconds
    static let fadeInDuration: TimeInterval = 3.0

    /// Fade out duration in seconds
    static let fadeOutDuration: TimeInterval = 2.0

    /// Transition between modes duration
    static let modeTransitionDuration: TimeInterval = 0.5

    // MARK: - Pulsating Mode

    /// Pulsating cycle duration range (seconds)
    static let pulsatingCycleMin: TimeInterval = 8.0
    static let pulsatingCycleMax: TimeInterval = 12.0

    /// Pulsating intensity values
    static let pulsatingIntensities: [Double] = [1.0, 0.85, 0.95, 0.80]

    // MARK: - Protection

    /// Time before auto-pulsate kicks in (constant mode)
    static let burnInProtectionDelay: TimeInterval = 300 // 5 minutes

    /// Battery threshold for auto-pause
    static let batteryThreshold: Double = 0.15 // 15%

    // MARK: - HDR

    /// Maximum HDR multiplier (for peak brightness)
    static let maxHDRMultiplier: Double = 4.0

    /// Standard display multiplier
    static let standardMultiplier: Double = 1.0

    // MARK: - Intensity Range

    /// Minimum intensity
    static let minIntensity: Double = 0.20

    /// Maximum intensity
    static let maxIntensity: Double = 1.0

    // MARK: - Animation Speed Range

    /// Minimum animation speed multiplier
    static let minAnimationSpeed: Double = 0.5

    /// Maximum animation speed multiplier
    static let maxAnimationSpeed: Double = 2.0

    // MARK: - Global Hotkey

    /// Default hotkey: Cmd+Option+L
    static let hotkeyKeyCode: UInt16 = 0x25 // L key
    static let hotkeyModifiers: UInt32 = UInt32(CGEventFlags.maskCommand.rawValue | CGEventFlags.maskAlternate.rawValue)
}
