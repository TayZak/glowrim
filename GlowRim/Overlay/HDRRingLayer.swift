import AppKit
import MetalKit

/// FP16 EDR, rendered only in the thin bands occupied by the diffuse light.
final class HDRRingRenderer: NSObject, MTKViewDelegate {
    private struct Resources {
        let queue: MTLCommandQueue
        let pipeline: MTLRenderPipelineState
    }
    // Reuse the compiled shader when the lightweight overlay is opened again.
    private static var resources: [UInt64: Resources] = [:]
    private let gpu: Resources
    private var style = Style(settings: .shared)
    var breath = BreathingAnimation.Sample.still
    var fade: Float = 0
    var headroom: Float = 1
    var blackout = false
    private(set) var drawCount = 0

    init(view: MTKView, device: MTLDevice) throws {
        if let cached = Self.resources[device.registryID] {
            gpu = cached
        } else {
            guard let queue = device.makeCommandQueue() else { throw RendererError.unavailable }
            let library = try device.makeLibrary(source: Self.shader, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "fullscreen")
            descriptor.fragmentFunction = library.makeFunction(name: "rim")
            descriptor.colorAttachments[0].pixelFormat = .rgba16Float
            gpu = Resources(queue: queue, pipeline: try device.makeRenderPipelineState(descriptor: descriptor))
            Self.resources[device.registryID] = gpu
        }
        super.init()
        view.delegate = self
    }
    enum RendererError: Error { case unavailable }

    struct Uniforms {
        var size: SIMD2<Float>
        var width: Float
        var softness: Float
        var color: SIMD4<Float>
        var radius: Float
        var luminance: Float
        var fade: Float
        var blackout: Float
        var contour: Float = 0
        var pixelWidth: Float = 1
        var lobes: SIMD4<Float> = .zero
    }
    private struct Style {
        let width: Float
        let softness: Float
        let color: SIMD4<Float>
        let radius: Float
        let intensity: Float
        let hdr: Bool
        init(settings: LightSettings) {
            func linear(_ v: Double) -> Float { Float(v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)) }
            width = Float(settings.ringWidth); softness = Float(settings.softness)
            color = SIMD4(linear(settings.red), linear(settings.green), linear(settings.blue), 1)
            radius = Float(settings.cornerRadius); intensity = Float(settings.intensity); hdr = settings.hdrEnabled
        }
    }
    func updateStyle(from settings: LightSettings) { style = Style(settings: settings) }
    static func uniforms(size: CGSize, pixels: CGSize, settings: LightSettings,
                         breath: BreathingAnimation.Sample, headroom: Float, fade: Float, blackout: Bool) -> Uniforms {
        uniforms(size: size, pixels: pixels, style: Style(settings: settings), breath: breath,
                 headroom: headroom, fade: fade, blackout: blackout)
    }
    private static func uniforms(size: CGSize, pixels: CGSize, style: Style,
                                 breath: BreathingAnimation.Sample, headroom: Float, fade: Float, blackout: Bool) -> Uniforms {
        Uniforms(size: SIMD2(Float(size.width), Float(size.height)),
            width: style.width * breath.width, softness: style.softness * breath.diffusion,
            color: style.color, radius: Float(min(size.width, size.height)) * style.radius,
            luminance: style.intensity * (style.hdr ? max(1, headroom) : 1) * breath.luminance,
            fade: fade, blackout: blackout ? 1 : 0,
            contour: min(42, max(12, style.width * 0.55)) * breath.contour,
            pixelWidth: Float(max(size.width / max(1, pixels.width), size.height / max(1, pixels.height))),
            lobes: breath.lobes)
    }

    /// Four non-overlapping scissors. The transparent center never runs the shader.
    /// The bound includes the rounded corners and the entire finite Gaussian tail.
    static func bands(for u: Uniforms, pixels: CGSize) -> [MTLScissorRect] {
        let width = max(1, Int(pixels.width)); let height = max(1, Int(pixels.height))
        let sigma = (u.width + abs(u.contour)) * 0.42 + u.softness * 0.42
        let reach = max(1, sigma) * 3.95 + u.pixelWidth * 2
        let radius = min(u.radius, min(u.size.x, u.size.y) * 0.5)
        let band = max(reach, radius * (1 - 1 / sqrt(Float(2))) + reach / sqrt(Float(2)))
        let x = min(width / 2 + width % 2, max(1, Int(ceil(band / u.size.x * Float(width)))))
        let y = min(height / 2 + height % 2, max(1, Int(ceil(band / u.size.y * Float(height)))))
        if x * 2 >= width || y * 2 >= height { return [.init(x: 0, y: 0, width: width, height: height)] }
        return [.init(x: 0, y: 0, width: width, height: y),
                .init(x: 0, y: height-y, width: width, height: y),
                .init(x: 0, y: y, width: x, height: height-y*2),
                .init(x: width-x, y: y, width: x, height: height-y*2)]
    }
    func draw(in view: MTKView) {
        autoreleasepool { drawFrame(in: view) }
    }
    private func drawFrame(in view: MTKView) {
        guard view.bounds.width > 0, view.bounds.height > 0 else { return }
        view.clearColor = MTLClearColorMake(0, 0, 0, blackout ? Double(fade) : 0)
        guard let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable,
              let command = gpu.queue.makeCommandBuffer(),
              let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
        var u = Self.uniforms(size: view.bounds.size, pixels: view.drawableSize, style: style,
            breath: breath, headroom: headroom, fade: fade, blackout: blackout)
        encoder.setRenderPipelineState(gpu.pipeline)
        encoder.setFragmentBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 0)
        for band in Self.bands(for: u, pixels: view.drawableSize) {
            encoder.setScissorRect(band)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        }
        encoder.endEncoding()
        command.present(drawable)
        command.commit()
        drawCount += 1
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    static let shader = """
    #include <metal_stdlib>
    using namespace metal;
    struct Vertex { float4 position [[position]]; float2 uv; };
    struct Uniforms {
        float2 size; float width; float softness; float4 color;
        float radius; float luminance; float fade; float blackout;
        float contour; float pixelWidth; float4 lobes;
    };
    vertex Vertex fullscreen(uint id [[vertex_id]]) {
        float2 positions[3] = {float2(-1,-1), float2(3,-1), float2(-1,3)};
        Vertex v; v.position = float4(positions[id],0,1);
        v.uv = positions[id] * 0.5 + 0.5; return v;
    }
    fragment half4 rim(Vertex v [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
        float2 p = v.uv * u.size;
        float radius = clamp(u.radius, 0.0, min(u.size.x,u.size.y)*0.5);
        float2 q = abs(p-u.size*0.5) - (u.size*0.5-radius);
        float distance = length(max(q,float2(0))) + min(max(q.x,q.y),0.0) - radius;
        float outside = 1.0-smoothstep(-u.pixelWidth,u.pixelWidth,distance);
        // Broad polynomial lobes: smooth at every corner, no per-pixel trig.
        float2 t = clamp(v.uv,0.0,1.0);
        float2 arches = 16.0*t*t*(1.0-t)*(1.0-t);
        float wave = 0.5*(arches.x*mix(u.lobes.x,u.lobes.y,t.y)
                         + arches.y*mix(u.lobes.z,u.lobes.w,t.x));
        float localWidth = max(1.0,u.width+u.contour*wave);
        float sigma = max(1.0,0.42*(localWidth+u.softness));
        // Smooth the interior corner join so the light never forms a hard
        // diagonal crease where two nearest edges meet.
        float join = max(1.0,sigma*1.4);
        float h = max(join-abs(q.x-q.y),0.0)/join;
        float smoothMax = max(q.x,q.y)+h*h*join*0.25;
        float innerDistance = length(max(q,float2(0)))+min(smoothMax,0.0)-radius;
        float inset = max(0.0,-innerDistance);
        float normalized = inset/sigma;
        // A continuous falloff instead of an opaque band with a straight inner edge.
        float coverage = exp(-0.5*normalized*normalized)
                         * (1.0-smoothstep(3.2,3.6,normalized)) * outside;
        float a = clamp(coverage*u.fade,0.0,1.0);
        float3 rgb = u.color.rgb*u.luminance*a;
        float blackAlpha = u.blackout*u.fade;
        return half4(half3(rgb),half(a+blackAlpha*(1.0-a)));
    }
    """
}
