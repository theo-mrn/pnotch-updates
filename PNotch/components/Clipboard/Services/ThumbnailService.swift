//
//  ThumbnailService.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import AppKit
import QuickLookThumbnailing

/// Decodes and caches the small images shown in cards, off the main thread.
final class ThumbnailService {
    static let shared = ThumbnailService()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 300
    }

    func cachedImage(at url: URL, maxPixelSize: Int) -> NSImage? {
        cache.object(forKey: Self.cacheKey(url, maxPixelSize))
    }

    /// Downsampled image stored at `url` (copied images, picture files, link previews).
    func image(at url: URL, maxPixelSize: Int) async -> NSImage? {
        if let cached = cachedImage(at: url, maxPixelSize: maxPixelSize) { return cached }

        var decoded = await Task.detached(priority: .userInitiated) {
            ImageProcessing.thumbnail(at: url, maxPixelSize: maxPixelSize)
        }.value
        if decoded == nil {
            // Quick Look covers the formats ImageIO can't read, such as SVG.
            let side = CGFloat(maxPixelSize) / 2
            decoded = await Self.generateQuickLookThumbnail(for: url, size: CGSize(width: side, height: side))
        }
        guard let decoded else { return nil }

        let image = NSImage(cgImage: decoded.cgImage, size: .zero)
        cache.setObject(image, forKey: Self.cacheKey(url, maxPixelSize))
        return image
    }

    /// Quick Look preview of any file (documents, images, folders…).
    func fileThumbnail(for url: URL, size: CGSize) async -> NSImage? {
        let maxPixelSize = Int(max(size.width, size.height) * 2)
        if let cached = cachedImage(at: url, maxPixelSize: maxPixelSize) { return cached }

        guard let decoded = await Self.generateQuickLookThumbnail(for: url, size: size) else { return nil }
        let image = NSImage(cgImage: decoded.cgImage, size: size)
        cache.setObject(image, forKey: Self.cacheKey(url, maxPixelSize))
        return image
    }

    // MARK: Private

    private nonisolated static func cacheKey(_ url: URL, _ maxPixelSize: Int) -> NSString {
        "\(url.absoluteString)#\(maxPixelSize)" as NSString
    }

    private nonisolated static func generateQuickLookThumbnail(
        for url: URL,
        size: CGSize
    ) async -> ImageProcessing.DecodedImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: 2,
            representationTypes: .thumbnail
        )
        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                continuation.resume(returning: representation.map { ImageProcessing.DecodedImage(cgImage: $0.cgImage) })
            }
        }
    }
}
