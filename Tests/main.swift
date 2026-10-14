import AppKit
import MetalKit

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
    print("PASS: \(message)")
}
let suite = "GlowRimChecks.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
defaults.set(0.7, forKey: "glowrim.intensity")
defaults.set(92.0, forKey: "glowrim.ringWidth")
defaults.set(0.42, forKey: "glowrim.green")
defaults.set(true, forKey: "glowrim.isEnabled")
let settings = LightSettings(defaults: defaults)
check(settings.intensity == 0.7 && settings.ringWidth == 92 && settings.green == 0.42, "Loading preserves every saved setting")
check(!settings.isEnabled && !settings.blackScreen, "Launch starts with light and blackout off")
settings.intensity = 20
settings.softness = -4
settings.red = .nan
check(settings.intensity == 1 && settings.softness == 0 && settings.red == 0, "Invalid settings are clamped")
settings.applyPreset(.cool)
settings.hdrEnabled = false
settings.selectedDisplayID = "test-display"
settings.saveSettings()
let restored = LightSettings(defaults: defaults)
check(restored.selectedPresetId == "cool" && restored.blue == 1 && !restored.hdrEnabled && restored.selectedDisplayID == "test-display", "Color, HDR and screen selection persist")

// Timing, shape and power contracts independent of the machine's display settings.
let inhale = (0...100).map { BreathingAnimation.envelope(phase: Double($0)/100*0.36) }
let exhale = (0...100).map { BreathingAnimation.envelope(phase: 0.36+Double($0)/100*0.53) }
check(zip(inhale, inhale.dropFirst()).allSatisfy { $0 <= $1 }, "Inhalation grows smoothly")
check(zip(exhale, exhale.dropFirst()).allSatisfy { $0 >= $1 }, "The longer exhalation relaxes smoothly")
check(BreathingAnimation.envelope(phase: 0.95) == 0, "Breathing includes a quiet resting phase")
for join in [0.0,0.36,0.89,1.0] {
    let before = BreathingAnimation.envelope(phase: join-0.0001)
    let at = BreathingAnimation.envelope(phase: join)
    let after = BreathingAnimation.envelope(phase: join+0.0001)
    check(abs(before-at) < 0.000001 && abs(after-at) < 0.000001, "Breathing join has no visible jump at phase \(join)")
}
let resting = BreathingAnimation.sample(at: 0)
let expanded = BreathingAnimation.sample(at: 3)
check(expanded.width > resting.width && expanded.diffusion > resting.diffusion && expanded.luminance > resting.luminance,
    "The contour, softness and intensity expand together")
for n in 0...3000 {
    let sample = BreathingAnimation.sample(at: Double(n)/10)
    checkSampleBounds(sample)
}
func checkSampleBounds(_ sample: BreathingAnimation.Sample) {
    precondition(sample.luminance >= 0.78 && sample.luminance <= 1.001 && sample.width >= 0.86 && sample.width <= 1.061 && sample.contour > 0)
}
print("PASS: Five minutes of breathing remain bounded")
let pluggedBudget = RenderBudget(onBattery: false, lowPower: false, thermalPressure: false)
let batteryBudget = RenderBudget(onBattery: true, lowPower: false, thermalPressure: false)
let lowBudget = RenderBudget(onBattery: false, lowPower: true, thermalPressure: false)
check(batteryBudget.framesPerSecond < pluggedBudget.framesPerSecond && batteryBudget.maximumDimension < pluggedBudget.maximumDimension, "Battery reduces animation and surface cost")
check(lowBudget.framesPerSecond < batteryBudget.framesPerSecond && lowBudget.maximumDimension < batteryBudget.maximumDimension, "Low Power Mode reduces the budget further")
check(RenderBudget(onBattery: false, lowPower: false, thermalPressure: true) == lowBudget, "Thermal pressure uses the smallest budget")
let scaled = batteryBudget.drawableSize(for: CGSize(width: 2000,height: 1000))
check(scaled.width == 850 && scaled.height == 425, "Render scaling preserves the display aspect ratio")

let device = MTLCreateSystemDefaultDevice()!
let library = try device.makeLibrary(source: HDRRingRenderer.shader, options: nil)
let descriptor = MTLRenderPipelineDescriptor()
descriptor.vertexFunction = library.makeFunction(name: "fullscreen")
descriptor.fragmentFunction = library.makeFunction(name: "rim")
descriptor.colorAttachments[0].pixelFormat = .rgba16Float
let pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: 200, height: 120, mipmapped: false)
textureDescriptor.storageMode = .shared
textureDescriptor.usage = [.renderTarget]
let texture = device.makeTexture(descriptor: textureDescriptor)!
let queue = device.makeCommandQueue()!
func render(luminance: Float, fade: Float = 1, blackout: Float = 0, radius: Float = 0) -> [Float] {
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    let command = queue.makeCommandBuffer()!
    let encoder = command.makeRenderCommandEncoder(descriptor: pass)!
    var uniforms = HDRRingRenderer.Uniforms(size: SIMD2(200,120), width: 10, softness: 10,
        color: SIMD4(1,1,1,1), radius: radius, luminance: luminance, fade: fade, blackout: blackout)
    encoder.setRenderPipelineState(pipeline)
    encoder.setFragmentBytes(&uniforms, length: MemoryLayout<HDRRingRenderer.Uniforms>.stride, index: 0)
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    encoder.endEncoding()
    command.commit(); command.waitUntilCompleted()
    check(command.status == .completed, "Metal command completed")
    var pixels = [UInt16](repeating: 0, count: 200*120*4)
    pixels.withUnsafeMutableBytes { buffer in
        texture.getBytes(buffer.baseAddress!, bytesPerRow: 200*8, from: MTLRegionMake2D(0,0,200,120), mipmapLevel: 0)
    }
    return pixels.map { Float(Float16(bitPattern: $0)) }
}
let hdr = render(luminance: 3)
let edge = (60*200+2)*4
let center = (60*200+100)*4
check(hdr[edge] > 1, "FP16 HDR preserves RGB above SDR white")
check(stride(from: 3, to: hdr.count, by: 4).allSatisfy { hdr[$0] >= 0 && hdr[$0] <= 1 }, "All alpha values remain valid")
check(hdr[center+3] < 0.0001, "The center is transparent")
let sdr = render(luminance: 0.8)
check(sdr[edge] <= 1 && sdr[edge] > 0.7, "SDR mode stays within standard brightness")
let black = render(luminance: 3, blackout: 1)
check(black[center+3] == 1 && black[center] < 0.0001, "Blackout makes the center opaque black")
let faded = render(luminance: 3, fade: 0.5)
check(abs(faded[edge] - hdr[edge]*0.5) < 0.01 && abs(faded[edge+3] - hdr[edge+3]*0.5) < 0.01, "Fade keeps alpha and HDR RGB premultiplied")
let rounded = render(luminance: 3, radius: 25)
check(rounded[3] < 0.01, "Rounded corners leave pixels outside the contour clear")

try checkRimRendering(device: device)

// Window lifecycle with the actual Metal view and controller.
_ = NSApplication.shared
ScreenGlowOverlay.shared.startMonitoring()
LightSettings.shared.mode = .constant
LightSettings.shared.hdrEnabled = false
LightSettings.shared.isEnabled = true
ScreenGlowOverlay.shared.synchronize()
RunLoop.main.run(until: Date().addingTimeInterval(0.35))
check(ScreenGlowOverlay.shared.renderError == nil && ScreenGlowOverlay.shared.isVisible, "Real Metal overlay starts")
check(ScreenGlowOverlay.shared.scheduledFramesPerSecond == 0, "Static SDR light has no render timer")
let stillDraws = ScreenGlowOverlay.shared.renderedFrameCount
RunLoop.main.run(until: Date().addingTimeInterval(0.25))
check(ScreenGlowOverlay.shared.renderedFrameCount == stillDraws, "Unchanged static light submits no GPU work")
let drawable = ScreenGlowOverlay.shared.drawablePixelSize!
check(max(drawable.width, drawable.height) <= 1000, "Real overlay uses a bounded low-resolution surface")
LightSettings.shared.isEnabled = false
ScreenGlowOverlay.shared.synchronize()
LightSettings.shared.isEnabled = true
ScreenGlowOverlay.shared.synchronize()
RunLoop.main.run(until: Date().addingTimeInterval(0.35))
check(ScreenGlowOverlay.shared.isVisible, "Rapid off/on cannot hide a newly enabled light")
LightSettings.shared.isEnabled = false
ScreenGlowOverlay.shared.synchronize()
RunLoop.main.run(until: Date().addingTimeInterval(0.35))
check(!ScreenGlowOverlay.shared.isVisible, "Fade-out completes and closes the overlay")
check(ScreenGlowOverlay.shared.scheduledFramesPerSecond == 0 && ScreenGlowOverlay.shared.drawablePixelSize == nil, "Light off releases the surface and has no timer")
ScreenGlowOverlay.shared.shutdown()

// Actual AppDelegate lifecycle: independent window, Dock reopen, central power state.
let appDelegate = AppDelegate()
NSApp.delegate = appDelegate
appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
RunLoop.main.run(until: Date().addingTimeInterval(0.2))
let panel = NSApp.windows.first { $0.title == "GlowRim" }!
check(panel.isVisible && NSApp.activationPolicy() == .regular, "Launch opens a normal Dock-accessible control window")
check(!appDelegate.hasProtectionTimer, "App idle has no protection polling timer")
check(BatteryMonitor.shared.hasNotificationSource, "Battery changes use a live system notification source")
check(panel.contentView!.bounds.width >= 740, "Window keeps the desktop controls readable")
panel.close()
check(!panel.isVisible, "Closing the panel keeps the app available")
_ = appDelegate.applicationShouldHandleReopen(NSApp, hasVisibleWindows: false)
check(panel.isVisible, "Dock reopen restores the same control window")
LightSettings.shared.batteryProtection = false
LightSettings.shared.autoBreathing = true
LightSettings.shared.isEnabled = true
RunLoop.main.run(until: Date().addingTimeInterval(0.35))
check(ScreenGlowOverlay.shared.isVisible, "App state changes drive the overlay without the panel")
check(appDelegate.hasProtectionTimer, "Stable mode schedules one protection deadline")
LightSettings.shared.mode = .pulsating
RunLoop.main.run(until: Date().addingTimeInterval(0.9))
check(!appDelegate.hasProtectionTimer, "Breathing cancels the protection deadline")
let startFrames = ScreenGlowOverlay.shared.renderedFrameCount
RunLoop.main.run(until: Date().addingTimeInterval(0.6))
let frames = ScreenGlowOverlay.shared.renderedFrameCount - startFrames
check(frames > 0 && frames <= 12, "Real breathing obeys the adaptive frame budget")
RunLoop.main.run(until: Date().addingTimeInterval(1))
let breathingView = NSApp.windows.compactMap { $0.contentView as? RingLightView }.first!
let beforeSpeed = breathingView.renderer!.breath
LightSettings.shared.animationSpeed = 2
ScreenGlowOverlay.shared.synchronize()
check(abs(breathingView.renderer!.breath.luminance - beforeSpeed.luminance) < 0.01, "Changing the rhythm does not jump to a different breath phase")
LightSettings.shared.animationSpeed = 1
LightSettings.shared.isEnabled = false
RunLoop.main.run(until: Date().addingTimeInterval(0.35))
check(!ScreenGlowOverlay.shared.isVisible, "App state changes shut down the overlay")
appDelegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
panel.close()
print("All GlowRim checks passed.")
