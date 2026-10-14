import Foundation
import CoreGraphics

/// A diffuse light does not need a full Retina surface or display-rate updates.
struct RenderBudget: Equatable {
    let framesPerSecond: Double
    let maximumDimension: CGFloat
    init(onBattery: Bool, lowPower: Bool, thermalPressure: Bool) {
        if lowPower || thermalPressure {
            framesPerSecond = 8; maximumDimension = 640
        } else if onBattery {
            framesPerSecond = 12; maximumDimension = 850
        } else {
            framesPerSecond = 15; maximumDimension = 1000
        }
    }
    func drawableSize(for size: CGSize) -> CGSize {
        let scale = min(1, maximumDimension / max(1, max(size.width, size.height)))
        return CGSize(width: max(1, ceil(size.width * scale)), height: max(1, ceil(size.height * scale)))
    }
}
