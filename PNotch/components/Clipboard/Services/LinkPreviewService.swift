//
//  LinkPreviewService.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation
import LinkPresentation
import UniformTypeIdentifiers

/// Title and image of a web page, as shown in link cards.
nonisolated struct LinkPreview: Sendable {
    let title: String?
    /// Downsampled PNG.
    let imageData: Data?
}

/// Fetches page metadata (Open Graph title and image, or favicon) with LinkPresentation.
nonisolated enum LinkPreviewService {
    private static let maxImagePixelSize = 600

    static func fetchPreview(for url: URL) async -> LinkPreview? {
        guard let metadata = await fetchMetadata(for: url) else { return nil }

        let imageData = await loadImageData(from: metadata.imageProvider ?? metadata.iconProvider)
            .flatMap { ImageProcessing.thumbnailPNG(from: $0, maxPixelSize: maxImagePixelSize) }
        return LinkPreview(title: metadata.title, imageData: imageData)
    }

    // MARK: Private

    private struct Metadata: @unchecked Sendable {
        let title: String?
        // NSItemProvider is thread-safe; LinkPresentation hands it over from a background queue.
        let imageProvider: NSItemProvider?
        let iconProvider: NSItemProvider?
    }

    private static func fetchMetadata(for url: URL) async -> Metadata? {
        let provider = LPMetadataProvider()
        provider.timeout = 10
        let metadata = await withCheckedContinuation { continuation in
            provider.startFetchingMetadata(for: url) { metadata, _ in
                continuation.resume(returning: metadata.map {
                    Metadata(title: $0.title, imageProvider: $0.imageProvider, iconProvider: $0.iconProvider)
                })
            }
        }
        // The provider cancels its request when deallocated: keep it alive until it answers.
        withExtendedLifetime(provider) {}
        return metadata
    }

    private static func loadImageData(from provider: NSItemProvider?) async -> Data? {
        guard let provider, provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }
}
