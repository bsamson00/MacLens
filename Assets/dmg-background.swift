// Renders the DMG installer-window background at 1x and 2x.
// Run: swift Assets/dmg-background.swift
// Output: Assets/dmg-background.png (560x380) and Assets/dmg-background@2x.png (1120x760).
import AppKit

let WPT: CGFloat = 560, HPT: CGFloat = 380   // window content size in points

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> NSColor {
    NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a)
}
let indigo = rgb(92, 99, 224)
let purple = rgb(140, 92, 237)

func drawText(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, centerY: CGFloat) {
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color, .paragraphStyle: para,
    ]
    let str = NSAttributedString(string: s, attributes: attrs)
    let h = str.size().height
    str.draw(in: NSRect(x: 0, y: centerY - h/2, width: WPT, height: h))
}

func render(scale: CGFloat) -> Data {
    let pw = Int(WPT * scale), ph = Int(HPT * scale)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pw, pixelsHigh: ph,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: WPT, height: HPT)   // point size → sets DPI for the scale

    NSGraphicsContext.saveGraphicsState()
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gctx
    gctx.cgContext.scaleBy(x: scale, y: scale)   // draw everything in point space

    // Soft vertical gradient backdrop.
    NSGradient(colors: [rgb(243, 244, 253), rgb(255, 255, 255)])!
        .draw(in: NSRect(x: 0, y: 0, width: WPT, height: HPT), angle: -90)

    // Title + subtitle (AppKit origin is bottom-left; icon row sits at y≈185).
    drawText("MacLens", size: 26, weight: .bold, color: rgb(38, 38, 79), centerY: 322)
    drawText("Drag the app into the Applications folder to install",
             size: 12, weight: .regular, color: rgb(122, 122, 140), centerY: 292)

    // Arrow between the two icons.
    let y: CGFloat = 186
    let shaft = NSBezierPath()
    shaft.lineWidth = 5.5
    shaft.lineCapStyle = .round
    shaft.move(to: NSPoint(x: 238, y: y))
    shaft.line(to: NSPoint(x: 322, y: y))
    indigo.withAlphaComponent(0.9).setStroke()
    shaft.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 345, y: y))
    head.line(to: NSPoint(x: 318, y: y + 15))
    head.line(to: NSPoint(x: 318, y: y - 15))
    head.close()
    purple.withAlphaComponent(0.95).setFill()
    head.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try! render(scale: 1).write(to: URL(fileURLWithPath: "Assets/dmg-background.png"))
try! render(scale: 2).write(to: URL(fileURLWithPath: "Assets/dmg-background@2x.png"))
print("✓ wrote Assets/dmg-background.png + @2x")
