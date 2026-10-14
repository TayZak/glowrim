import AppKit
import MetalKit

func checkRimRendering(device: MTLDevice) throws {
    let library = try device.makeLibrary(source: HDRRingRenderer.shader, options: nil)
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = library.makeFunction(name: "fullscreen")
    descriptor.fragmentFunction = library.makeFunction(name: "rim")
    descriptor.colorAttachments[0].pixelFormat = .rgba16Float
    let pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: 400, height: 256, mipmapped: false)
    textureDescriptor.storageMode = .shared; textureDescriptor.usage = .renderTarget
    let texture = device.makeTexture(descriptor: textureDescriptor)!
    let queue = device.makeCommandQueue()!
    let suite = "GlowRimRendering.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let settings = LightSettings(defaults: defaults)
    let size = CGSize(width: 1000, height: 640)
    let pixels = CGSize(width: 400, height: 256)
    func render(_ u: HDRRingRenderer.Uniforms, bands: Bool) -> [UInt16] {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0,0,0,Double(u.blackout*u.fade))
        pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
        let command = queue.makeCommandBuffer()!
        let encoder = command.makeRenderCommandEncoder(descriptor: pass)!
        var uniforms = u
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<HDRRingRenderer.Uniforms>.stride, index: 0)
        let scissors = bands ? HDRRingRenderer.bands(for: u, pixels: pixels) : [.init(x:0,y:0,width:400,height:256)]
        for rect in scissors { encoder.setScissorRect(rect); encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3) }
        encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
        precondition(command.status == .completed)
        var data = [UInt16](repeating:0,count:400*256*4)
        data.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!,bytesPerRow:400*8,from:MTLRegionMake2D(0,0,400,256),mipmapLevel:0) }
        return data
    }
    for (width, softness, radius, time, black) in [(10.0,0.0,0.0,0.0,false), (35,40,0.035,3,false),
        (35,40,0.5,7,false), (200,80,0.5,3,false), (35,40,0.035,0,true)] {
        settings.ringWidth = width; settings.softness = softness; settings.cornerRadius = radius
        let u = HDRRingRenderer.uniforms(size:size,pixels:pixels,settings:settings,
            breath:BreathingAnimation.sample(at:time),headroom:3,fade:0.7,blackout:black)
        let reference = render(u,bands:false)
        let optimized = render(u,bands:true)
        check(reference == optimized, "Bands preserve every FP16 pixel (width \(width), softness \(softness), radius \(radius), blackout \(black))")
    }
    settings.ringWidth = 35; settings.softness = 40; settings.cornerRadius = 0
    let rest = HDRRingRenderer.uniforms(size:size,pixels:pixels,settings:settings,
        breath:BreathingAnimation.sample(at:0),headroom:3,fade:1,blackout:false)
    let inhale = HDRRingRenderer.uniforms(size:size,pixels:pixels,settings:settings,
        breath:BreathingAnimation.sample(at:3),headroom:3,fade:1,blackout:false)
    let restingImage = render(rest,bands:true)
    let inhalingImage = render(inhale,bands:true)
    func alpha(_ image:[UInt16], x:Int,y:Int) -> Float { Float(Float16(bitPattern:image[(y*400+x)*4+3])) }
    check(abs(alpha(inhalingImage,x:200,y:20)-alpha(inhalingImage,x:80,y:20)) > 0.01, "The light's inner contour curves along a straight display edge")
    check(alpha(inhalingImage,x:200,y:20) > alpha(restingImage,x:200,y:20), "Actual pixels show the halo expanding on inhale")
    let area = HDRRingRenderer.bands(for:inhale,pixels:pixels).reduce(0) { $0+$1.width*$1.height }
    check(area < 400*256*3/4, "Default breathing skips the transparent center's fragment work")
    check(alpha(inhalingImage,x:200,y:128) == 0, "Organic breathing keeps the display center completely clear")

    if let output = ProcessInfo.processInfo.environment["GLOWRIM_VISUAL_CHECK_DIR"] {
        try FileManager.default.createDirectory(atPath:output,withIntermediateDirectories:true)
        settings.cornerRadius = 0.035
        for frame in 0..<130 {
            let u = HDRRingRenderer.uniforms(size:size,pixels:pixels,settings:settings,
                breath:BreathingAnimation.sample(at:Double(frame)/15),headroom:1.4,fade:1,blackout:false)
            let image = render(u,bands:true)
            let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:400,pixelsHigh:256,bitsPerSample:8,
                samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:400*4,bitsPerPixel:32)!
            for index in 0..<(400*256) {
                let a = Double(Float16(bitPattern:image[index*4+3]))
                for channel in 0..<3 {
                    let value = Double(Float16(bitPattern:image[index*4+channel])) + 0.025*(1-a)
                    let srgb = value <= 0.0031308 ? value*12.92 : 1.055*pow(value,1/2.4)-0.055
                    bitmap.bitmapData![index*4+channel] = UInt8(max(0,min(255,srgb*255)))
                }
                bitmap.bitmapData![index*4+3] = 255
            }
            try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:output).appendingPathComponent(String(format:"frame-%03d.png",frame)))
        }
    }
}
