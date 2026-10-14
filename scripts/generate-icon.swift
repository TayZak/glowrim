import AppKit

// Resolution-independent AppKit artwork, rasterized at the exact asset sizes.
let destination = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "GlowRim/Assets.xcassets/AppIcon.appiconset")
let entries: [(Int, Int)] = [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]
var images: [[String: String]] = []
for (points, scale) in entries {
    let size = points * scale
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let tile = NSBezierPath(roundedRect: NSRect(x: 82, y: 82, width: 860, height: 860), xRadius: 195, yRadius: 195)
    context.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowBlurRadius = 32
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.set()
    NSColor(red: 0.08, green: 0.10, blue: 0.16, alpha: 1).setFill()
    tile.fill()
    context.restoreGraphicsState()
    NSGradient(starting: NSColor(red: 0.19, green: 0.23, blue: 0.32, alpha: 1),
        ending: NSColor(red: 0.055, green: 0.065, blue: 0.11, alpha: 1))!.draw(in: tile, angle: -70)
    context.saveGraphicsState()
    tile.addClip()
    let rim = NSBezierPath(roundedRect: NSRect(x: 224, y: 256, width: 576, height: 512), xRadius: 118, yRadius: 118)
    for (width, alpha) in [(110.0,0.025),(85.0,0.05),(65.0,0.10),(48.0,0.20)] {
        rim.lineWidth = width
        NSColor(red: 1, green: 0.78, blue: 0.5, alpha: alpha).setStroke()
        rim.stroke()
    }
    rim.lineWidth = 26
    NSColor(red: 1, green: 0.91, blue: 0.73, alpha: 1).setStroke()
    rim.stroke()
    rim.lineWidth = 8
    NSColor(red: 1, green: 0.99, blue: 0.93, alpha: 1).setStroke()
    rim.stroke()
    // A quiet, centered light source keeps the silhouette readable in the Dock.
    let center = NSBezierPath(ovalIn: NSRect(x: 452, y: 452, width: 120, height: 120))
    NSColor(red: 1, green: 0.90, blue: 0.73, alpha: 0.95).setFill()
    center.fill()
    context.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()
    let name = "icon_\(points)x\(points)@\(scale)x.png"
    try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent(name))
    images.append(["idiom":"mac", "size":"\(points)x\(points)", "scale":"\(scale)x", "filename":name])
}
let catalog: [String: Any] = ["images":images, "info":["author":"xcode", "version":1]]
try JSONSerialization.data(withJSONObject: catalog, options: [.prettyPrinted, .sortedKeys]).write(to: destination.appendingPathComponent("Contents.json"))
