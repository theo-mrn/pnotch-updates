//
//  ClipboardItemFactory.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation

/// Turns a pasteboard snapshot into a history entry. Images are encoded and written to disk here,
/// so this runs off the main actor.
nonisolated enum ClipboardItemFactory {
    static func makeItem(
        from snapshot: PasteboardSnapshot,
        sourceApp: SourceApplication?,
        copiedAt date: Date,
        persistence: ClipboardPersistenceService
    ) throws -> ClipboardItem? {
        guard let content = try content(for: snapshot, persistence: persistence) else { return nil }
        return ClipboardItem(
            content: content,
            fingerprint: snapshot.fingerprint,
            copiedAt: date,
            sourceApp: sourceApp
        )
    }

    private static func content(
        for snapshot: PasteboardSnapshot,
        persistence: ClipboardPersistenceService
    ) throws -> ClipboardContent? {
        switch snapshot {
        case let .files(urls):
            return .files(urls)

        case let .contact(vCard, text):
            if let contact = ContactParser.contact(fromVCard: vCard) {
                return .contact(contact)
            }
            return text.map { ClipboardClassifier.content(forText: $0, rtf: nil) }

        case let .color(color):
            return .color(color)

        case let .text(text, rtf):
            return ClipboardClassifier.content(forText: text, rtf: rtf)

        case let .image(data):
            guard let image = ImageProcessing.pngImage(from: data) else { return nil }
            let fileName = "\(UUID().uuidString).png"
            try persistence.writeImage(image.data, named: fileName)
            return .image(.init(fileName: fileName, pixelWidth: image.pixelWidth, pixelHeight: image.pixelHeight))
        }
    }
}
