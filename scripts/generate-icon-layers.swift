// Generates the layers of PNotch's app icon (PNotch/AppIcon.icon), plus a flattened preview.
//
//   swift scripts/generate-icon-layers.swift <output folder>
//
// Copy Notch.png and Cards.png into PNotch/AppIcon.icon/Assets. The background gradient, glass
// and shadows are set in PNotch/AppIcon.icon/icon.json and rendered by the system (Icon Composer format).
import AppKit

let size: CGFloat = 1024
let outDir = URL(fileURLWithPath: CommandLine.arguments[1])

func render(_ name: String, _ draw: (CGContext) -> Void) -> CGImage {
    let context = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Flip to a top-left origin, like the design.
    context.translateBy(x: 0, y: size); context.scaleBy(x: 1, y: -1)
    draw(context)
    let image = context.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent("\(name).png"))
    return image
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Notch outline from DynamicNotchKit: concave ears at the top, rounded bottom corners.
func notchPath(in rect: CGRect, top: CGFloat, bottom: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addQuadCurve(to: CGPoint(x: rect.minX + top, y: rect.minY + top), control: CGPoint(x: rect.minX + top, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.minX + top, y: rect.maxY - bottom))
    path.addQuadCurve(to: CGPoint(x: rect.minX + top + bottom, y: rect.maxY), control: CGPoint(x: rect.minX + top, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.maxX - top - bottom, y: rect.maxY))
    path.addQuadCurve(to: CGPoint(x: rect.maxX - top, y: rect.maxY - bottom), control: CGPoint(x: rect.maxX - top, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY + top))
    path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.maxX - top, y: rect.minY))
    path.closeSubpath()
    return path
}

let panelRect = CGRect(x: 172, y: 0, width: 680, height: 640)

let notch = render("Notch") { context in
    context.addPath(notchPath(in: panelRect, top: 44, bottom: 150))
    context.setFillColor(color(0x0A0A0B))
    context.fillPath()
    // Camera.
    context.setFillColor(color(0x1F2633))
    context.fillEllipse(in: CGRect(x: size / 2 - 17, y: 54, width: 34, height: 34))
}

let cards = render("Cards") { context in
    // Three clipboard cards sitting in the opened notch.
    let cardSize = CGSize(width: 170, height: 170)
    let spacing: CGFloat = 26
    let totalWidth = cardSize.width * 3 + spacing * 2
    let startX = (size - totalWidth) / 2
    let y: CGFloat = 300
    let fills: [UInt32] = [0xF4F0E6, 0x4C8DFF, 0xFF9F43]
    for (index, fill) in fills.enumerated() {
        let rect = CGRect(x: startX + CGFloat(index) * (cardSize.width + spacing), y: y, width: cardSize.width, height: cardSize.height)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: 38, cornerHeight: 38, transform: nil))
        context.setFillColor(color(fill))
        context.fillPath()
    }
    // Text lines on the paper card.
    let paper = CGRect(x: startX, y: y, width: cardSize.width, height: cardSize.height)
    context.setFillColor(color(0x1E1C18, 0.28))
    for (row, width) in [(0, 0.66), (1, 0.5), (2, 0.58)] {
        let line = CGRect(x: paper.minX + 30, y: paper.minY + 42 + CGFloat(row) * 32, width: (paper.width - 60) * width, height: 15)
        context.addPath(CGPath(roundedRect: line, cornerWidth: 7.5, cornerHeight: 7.5, transform: nil))
        context.fillPath()
    }
}

// Flattened preview: background gradient + layers, clipped to the macOS squircle.
_ = render("Preview") { context in
    let squircle = CGPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size), cornerWidth: 230, cornerHeight: 230, transform: nil)
    context.addPath(squircle); context.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [color(0xE3D3B4), color(0xA8977A)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size, y: size), options: [])
    // CGImages are drawn bottom-up: flip back locally.
    for image in [notch, cards] {
        context.saveGState()
        context.translateBy(x: 0, y: size); context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        context.restoreGState()
    }
}
print("done")
