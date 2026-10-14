import AppKit
import MetalKit

final class RingLightView: MTKView {
    private(set) var renderer: HDRRingRenderer?
    private(set) var failureReason: String?
    private var budget = RenderBudget(onBattery: false, lowPower: false, thermalPressure: false)

    init(frame: NSRect) {
        let device = MTLCreateSystemDefaultDevice()
        super.init(frame: frame, device: device)
        isPaused = true
        enableSetNeedsDisplay = true
        autoResizeDrawable = false
        colorPixelFormat = .rgba16Float
        colorspace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
        clearColor = MTLClearColorMake(0, 0, 0, 0)
        framebufferOnly = true
        wantsLayer = true
        if let metalLayer = layer as? CAMetalLayer {
            metalLayer.isOpaque = false
            metalLayer.wantsExtendedDynamicRangeContent = true
            metalLayer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
            metalLayer.maximumDrawableCount = 2
            metalLayer.allowsNextDrawableTimeout = true
        }
        applyBudget(budget)
        do {
            guard let device else { throw HDRRingRenderer.RendererError.unavailable }
            renderer = try HDRRingRenderer(view: self, device: device)
        } catch {
            failureReason = "Le rendu Metal est indisponible : \(error.localizedDescription)"
        }
    }
    required init(coder: NSCoder) { fatalError("Use init(frame:)") }
    override var isOpaque: Bool { false }
    override func layout() {
        super.layout()
        applyBudget(budget)
    }
    func applyBudget(_ budget: RenderBudget) {
        self.budget = budget
        let size = budget.drawableSize(for: bounds.size)
        if drawableSize != size { drawableSize = size; needsDisplay = true }
    }
    func updateFromSettings() { needsDisplay = true }
}
