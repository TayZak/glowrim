import Foundation
import simd

/// A quiet inhale, a longer exhale, then a little rest. All joins have zero
/// velocity and acceleration, including the cycle boundary.
struct BreathingAnimation {
    static let cycleDuration = 8.6
    struct Sample: Equatable {
        var luminance: Float
        var width: Float
        var diffusion: Float
        var contour: Float
        var lobes: SIMD4<Float>
        static let still = Sample(luminance: 1, width: 1, diffusion: 1, contour: 0, lobes: .zero)
        func blended(to other: Sample, amount: Float) -> Sample {
            let t = max(0, min(1, amount))
            return Sample(luminance: luminance + (other.luminance - luminance) * t,
                width: width + (other.width - width) * t,
                diffusion: diffusion + (other.diffusion - diffusion) * t,
                contour: contour + (other.contour - contour) * t,
                lobes: lobes + (other.lobes - lobes) * t)
        }
    }
    static func easing(_ value: Double) -> Double {
        let t = max(0, min(1, value))
        return t * t * t * (t * (t * 6 - 15) + 10)
    }
    static func envelope(phase: Double) -> Double {
        let p = phase - floor(phase)
        if p < 0.36 { return easing(p / 0.36) }
        if p < 0.89 { return 1 - easing((p - 0.36) / 0.53) }
        return 0
    }
    static func sample(at time: TimeInterval) -> Sample {
        let time = max(0, time)
        // Slow, bounded variation in the timing; never change period at a join.
        let phase = time / cycleDuration + 0.012 * sin(time / 23) + 0.006 * sin(time / 57)
        let breath = Float(envelope(phase: phase))
        return Sample(luminance: 0.78 + 0.22 * breath,
            width: 0.86 + 0.20 * breath, diffusion: 0.93 + 0.18 * breath,
            contour: 0.65 + 0.35 * breath,
            lobes: SIMD4(Float(0.86 + 0.10 * sin(time * 0.061)),
                         Float(-0.68 + 0.12 * sin(time * 0.083 + 0.8)),
                         Float(0.70 + 0.13 * sin(time * 0.070 + 1.7)),
                         Float(-0.76 + 0.12 * sin(time * 0.067 + 2.4))))
    }
}
