//
//  ClipboardItem.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation

/// One entry of the clipboard history.
nonisolated struct ClipboardItem: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var content: ClipboardContent
    /// Digest of the copied payload, used to recognise the same content copied again.
    let fingerprint: String
    var copiedAt: Date
    var sourceApp: SourceApplication?
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        content: ClipboardContent,
        fingerprint: String,
        copiedAt: Date = .now,
        sourceApp: SourceApplication? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.content = content
        self.fingerprint = fingerprint
        self.copiedAt = copiedAt
        self.sourceApp = sourceApp
        self.isPinned = isPinned
    }

    var kind: ClipboardKind {
        content.kind
    }
}

/// The application that was frontmost when an item was copied.
nonisolated struct SourceApplication: Hashable, Codable, Sendable {
    let bundleIdentifier: String
    let name: String
}
