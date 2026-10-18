//
//  PasteboardSnapshot.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import CryptoKit
import Foundation

/// A `Sendable` copy of the relevant pasteboard data, taken on the main thread and processed off it.
nonisolated enum PasteboardSnapshot: Sendable {
    case files([URL])
    case contact(vCard: Data, text: String?)
    case color(ColorValue)
    case image(Data)
    case text(String, rtf: Data?)

    /// Stable digest of the payload. Two copies of the same content share a fingerprint
    /// whatever the formatting, so rich and plain copies of a text are deduplicated.
    var fingerprint: String {
        switch self {
        case let .files(urls):
            Self.digest("files", Data(urls.map(\.absoluteString).joined(separator: "\n").utf8))
        case let .contact(vCard, _):
            Self.digest("contact", vCard)
        case let .color(color):
            Self.digest("text", Data(color.rawValue.utf8))
        case let .image(data):
            Self.digest("image", data)
        case let .text(text, _):
            Self.digest("text", Data(text.utf8))
        }
    }

    private static func digest(_ namespace: String, _ data: Data) -> String {
        var hasher = SHA256()
        hasher.update(data: Data(namespace.utf8))
        hasher.update(data: data)
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
