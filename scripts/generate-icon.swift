// Build-time drawing only. This helper never starts Padlock or installs an input tap.
import AppKit

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: generate-icon <output.iconset>\n", stderr)
    exit(1)
}
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

func render(pixels: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    context.setAllowsAntialiasing(true)

    let tile = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896),
                           xRadius: 194, yRadius: 194)
    let tileGradient = NSGradient(starting: NSColor(srgbRed: 0.20, green: 0.37, blue: 0.48, alpha: 1),
                                  ending: NSColor(srgbRed: 0.09, green: 0.20, blue: 0.29, alpha: 1))!
    tileGradient.draw(in: tile, angle: -90)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 18,
                      color: NSColor.black.withAlphaComponent(0.22).cgColor)
    let shackle = NSBezierPath(roundedRect: NSRect(x: 337, y: 430, width: 350, height: 338),
                              xRadius: 175, yRadius: 175)
    shackle.lineWidth = 76
    NSColor(srgbRed: 0.84, green: 0.89, blue: 0.91, alpha: 1).setStroke()
    shackle.stroke()
    context.restoreGState()

    let body = NSBezierPath(roundedRect: NSRect(x: 254, y: 237, width: 516, height: 355),
                           xRadius: 62, yRadius: 62)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -14), blur: 22,
                      color: NSColor.black.withAlphaComponent(0.23).cgColor)
    NSColor(srgbRed: 0.82, green: 0.59, blue: 0.22, alpha: 1).setFill()
    body.fill()
    context.restoreGState()
    NSGradient(starting: NSColor(srgbRed: 0.96, green: 0.80, blue: 0.42, alpha: 1),
               ending: NSColor(srgbRed: 0.80, green: 0.57, blue: 0.20, alpha: 1))!
        .draw(in: body, angle: -90)

    NSColor(srgbRed: 0.16, green: 0.22, blue: 0.25, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 473, y: 409, width: 78, height: 78)).fill()
    let keyhole = NSBezierPath()
    keyhole.move(to: NSPoint(x: 491, y: 435))
    keyhole.line(to: NSPoint(x: 476, y: 352))
    keyhole.line(to: NSPoint(x: 548, y: 352))
    keyhole.line(to: NSPoint(x: 533, y: 435))
    keyhole.close()
    keyhole.fill()

    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "Padlock.Icon", code: 1)
    }
    return png
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 1 ? "" : "@2x"
        let file = directory.appendingPathComponent("icon_\(points)x\(points)\(suffix).png")
        try render(pixels: points * scale).write(to: file)
    }
}
