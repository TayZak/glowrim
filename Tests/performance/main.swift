import AppKit
import MetalKit
import Darwin

// Release-speed measurements, separate from assertion tests. No camera/network use.
_ = NSApplication.shared
let overlay = ScreenGlowOverlay.shared
overlay.startMonitoring()
let settings = LightSettings.shared
settings.autoBreathing = false
settings.ringWidth = 35; settings.softness = 40; settings.cornerRadius = 0.035
let device = MTLCreateSystemDefaultDevice()!
func cpuTime() -> Double {
    var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
    return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1e6
}
print("Hardware: \(device.name); battery: \(!BatteryMonitor.shared.isCharging); low power: \(ProcessInfo.processInfo.isLowPowerModeEnabled)")
for (name, enabled, mode) in [("off", false, LightMode.constant), ("stable HDR", true, .constant), ("breathing HDR", true, .pulsating), ("off after use", false, .constant)] {
    settings.isEnabled = enabled; settings.mode = mode
    overlay.synchronize()
    RunLoop.main.run(until: Date().addingTimeInterval(1))
    let startCPU = cpuTime(); let start = CACurrentMediaTime(); let startDraws = overlay.renderedFrameCount
    RunLoop.main.run(until: Date().addingTimeInterval(8))
    let elapsed = CACurrentMediaTime()-start
    print("\(name): CPU \(String(format: "%.3f", (cpuTime()-startCPU)/elapsed*100))%; draws \(overlay.renderedFrameCount-startDraws); timer \(overlay.scheduledFramesPerSecond) Hz; surface \(String(describing: overlay.drawablePixelSize)); GPU allocation \(device.currentAllocatedSize / 1024 / 1024) MiB")
    fflush(stdout)
}
overlay.shutdown()

// Compare the GPU workload to an optional saved shader from the previous version.
let screen = NSScreen.screens.first!
let size = screen.frame.size
let budget = RenderBudget(onBattery: !BatteryMonitor.shared.isCharging, lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled, thermalPressure: false)
var variants: [(String,String,CGSize,Bool)] = [("current",HDRRingRenderer.shader,budget.drawableSize(for: size),true)]
if CommandLine.arguments.count > 1 {
    let baseline = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
    variants.insert(("previous",baseline,CGSize(width: size.width*screen.backingScaleFactor, height: size.height*screen.backingScaleFactor),false),at:0)
}
for (name, source, pixels, optimized) in variants {
    let library = try device.makeLibrary(source: source, options: nil)
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = library.makeFunction(name:"fullscreen")
    descriptor.fragmentFunction = library.makeFunction(name:"rim")
    descriptor.colorAttachments[0].pixelFormat = .rgba16Float
    let pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:Int(pixels.width),height:Int(pixels.height),mipmapped:false)
    textureDescriptor.usage = .renderTarget; textureDescriptor.storageMode = .private
    let texture = device.makeTexture(descriptor:textureDescriptor)!
    let queue = device.makeCommandQueue()!
    var times: [Double] = []
    var shadedPixels = 0
    for frame in 0..<120 {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        let command = queue.makeCommandBuffer()!
        let encoder = command.makeRenderCommandEncoder(descriptor: pass)!
        var u = HDRRingRenderer.uniforms(size:size,pixels:pixels,settings:settings,
            breath:BreathingAnimation.sample(at:Double(frame)/18),headroom:3,fade:1,blackout:false)
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&u,length:MemoryLayout<HDRRingRenderer.Uniforms>.stride,index:0)
        let bands = optimized ? HDRRingRenderer.bands(for:u,pixels:pixels) : [.init(x:0,y:0,width:Int(pixels.width),height:Int(pixels.height))]
        shadedPixels = bands.reduce(0) { $0 + $1.width*$1.height }
        for band in bands {
            encoder.setScissorRect(band)
            encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3)
        }
        encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
        precondition(command.status == .completed)
        if frame >= 20 { times.append((command.gpuEndTime-command.gpuStartTime)*1000) }
    }
    times.sort()
    print("GPU \(name): median \(String(format:"%.4f",times[times.count/2])) ms/frame; texture \(Int(pixels.width))×\(Int(pixels.height)); shaded pixels \(shadedPixels); one FP16 surface \(Int(pixels.width*pixels.height)*8/1024/1024) MiB")
}
