//
//  ImageProcessing.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// ImageIO helpers. Thread-safe, meant to run off the main actor.
nonisolated enum ImageProcessing {
    struct EncodedImage: Sendable {
        let data: Data
        let pixelWidth: Int
        let pixelHeight: Int
    }

    /// `CGImage` is immutable and thread-safe, but not annotated `Sendable` by CoreGraphics.
    struct DecodedImage: @unchecked Sendable {
        let cgImage: CGImage
    }

    /// Normalises any ImageIO-readable data (TIFF, PNG, JPEG, HEIC…) to PNG.
    static func pngImage(from data: Data) -> EncodedImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source)
        else { return nil }

        if UTType(type as String) == .png, let size = pixelSize(of: source) {
            return EncodedImage(data: data, pixelWidth: size.width, pixelHeight: size.height)
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let png = encode(image, as: .png)
        else { return nil }
        return EncodedImage(data: png, pixelWidth: image.width, pixelHeight: image.height)
    }

    /// Downsampled PNG, used for link previews which can be several megapixels.
    static func thumbnailPNG(from data: Data, maxPixelSize: Int) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = thumbnail(from: source, maxPixelSize: maxPixelSize)
        else { return nil }
        return encode(image, as: .png)
    }

    static func thumbnail(from data: Data, maxPixelSize: Int) -> DecodedImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = thumbnail(from: source, maxPixelSize: maxPixelSize)
        else { return nil }
        return DecodedImage(cgImage: image)
    }

    static func thumbnail(at url: URL, maxPixelSize: Int) -> DecodedImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = thumbnail(from: source, maxPixelSize: maxPixelSize)
        else { return nil }
        return DecodedImage(cgImage: image)
    }

    // MARK: Private

    private static func thumbnail(from source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func pixelSize(of source: CGImageSource) -> (width: Int, height: Int)? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (width, height)
    }

    private static func encode(_ image: CGImage, as type: UTType) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
