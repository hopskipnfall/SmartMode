// Renders the app icon: the menu-bar glyph (SF Symbol circle.lefthalf.filled) in white on a
// rounded square. To regenerate Resources/AppIcon.icns:
//   swift scripts/make-icon.swift /tmp/AppIcon.iconset
//   iconutil -c icns /tmp/AppIcon.iconset -o Resources/AppIcon.icns
import AppKit

func render(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    defer { NSGraphicsContext.restoreGraphicsState() }

    let s = CGFloat(pixels) / 1024
    // Apple's icon grid: an 824-pt rounded square centered on a 1024 canvas, leaving room for the shadow.
    let body = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185 * s, yRadius: 185 * s)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 24 * s
    shadow.shadowOffset = NSSize(width: 0, height: -12 * s)
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Dusk-to-night gradient, lighter at the top.
    let gradient = NSGradient(
        starting: NSColor(srgbRed: 0.36, green: 0.42, blue: 0.86, alpha: 1),
        ending: NSColor(srgbRed: 0.08, green: 0.10, blue: 0.28, alpha: 1))!
    gradient.draw(in: shape, angle: -90)

    let config = NSImage.SymbolConfiguration(pointSize: 600, weight: .regular)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    guard let symbol = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else { fatalError("SF Symbol not available") }
    // Fit the glyph into about 58% of the body, centered.
    let target = 478 * s
    let ratio = min(target / symbol.size.width, target / symbol.size.height)
    let drawn = NSSize(width: symbol.size.width * ratio, height: symbol.size.height * ratio)
    symbol.draw(in: NSRect(x: body.midX - drawn.width / 2, y: body.midY - drawn.height / 2,
                           width: drawn.width, height: drawn.height))
    return rep
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <output.iconset>\n".utf8))
    exit(2)
}
let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

// (file name, pixel size) pairs an .iconset needs.
let files: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, pixels) in files {
    let png = render(pixels: pixels).representation(using: .png, properties: [:])!
    try png.write(to: outDir.appendingPathComponent("\(name).png"))
}
print("wrote \(files.count) images to \(outDir.path)")
