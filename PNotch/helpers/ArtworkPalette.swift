//
//  ArtworkPalette.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import AppKit

/// Derives an accent color from album artwork, for the visualizer and the ambient glow.
nonisolated enum ArtworkPalette {
    /// Average color of the artwork, lifted so it stays visible on the black notch.
    static func accentColor(of imageData: Data) -> NSColor? {
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))

        let average = NSColor(
            srgbRed: CGFloat(pixel[0]) / 255,
            green: CGFloat(pixel[1]) / 255,
            blue: CGFloat(pixel[2]) / 255,
            alpha: 1
        )
        return readableOnBlack(average)
    }

    /// Keeps the hue, but guarantees enough brightness (and a bit of saturation) against black.
    static func readableOnBlack(_ color: NSColor) -> NSColor {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        color.usingColorSpace(.sRGB)?.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return NSColor(
            hue: hue,
            saturation: saturation < 0.08 ? saturation : min(saturation * 1.15, 0.85),
            brightness: max(brightness, 0.72),
            alpha: 1
        )
    }
}
