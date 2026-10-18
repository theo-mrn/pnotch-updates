//
//  ClipboardContent.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation
import UniformTypeIdentifiers

/// What was copied, already classified for display.
nonisolated enum ClipboardContent: Hashable, Codable, Sendable {
    case text(String)
    case richText(RichTextPayload)
    case code(String)
    case link(LinkPayload)
    case color(ColorValue)
    case image(ImagePayload)
    case files([URL])
    case contact(ContactPayload)

    struct RichTextPayload: Hashable, Codable, Sendable {
        let plainText: String
        let rtfData: Data
    }

    struct LinkPayload: Hashable, Codable, Sendable {
        let url: URL
        var title: String?
        /// File name, in the history image folder, of the page preview fetched after the copy.
        var previewImageName: String?
    }

    struct ImagePayload: Hashable, Codable, Sendable {
        /// File name in the history image folder.
        let fileName: String
        let pixelWidth: Int
        let pixelHeight: Int
    }

    struct ContactPayload: Hashable, Codable, Sendable {
        let name: String
        let organization: String?
        let email: String?
        let phone: String?
        let vCardData: Data

        var initials: String {
            let letters = name
                .split(whereSeparator: \.isWhitespace)
                .prefix(2)
                .compactMap(\.first)
            return letters.isEmpty ? "?" : String(letters).uppercased()
        }

        /// Plain-text fallback written next to the vCard.
        var textRepresentation: String {
            [name, organization, email, phone].compactMap { $0 }.joined(separator: "\n")
        }
    }

    var kind: ClipboardKind {
        switch self {
        case .text: .text
        case .richText: .richText
        case .code: .code
        case .link: .link
        case .color: .color
        case .image: .image
        // Pictures copied from Finder arrive as files, but they are images to the user.
        case let .files(urls): urls.allSatisfy(\.isImageFile) ? .image : .file
        case .contact: .contact
        }
    }

    /// Text used by search. Images have none.
    var searchableText: String {
        switch self {
        case let .text(text), let .code(text):
            text
        case let .richText(payload):
            payload.plainText
        case let .link(link):
            [link.title, link.url.absoluteString].compactMap { $0 }.joined(separator: " ")
        case let .color(color):
            "\(color.rawValue) \(color.hexString)"
        case .image:
            ""
        case let .files(urls):
            urls.map(\.lastPathComponent).joined(separator: " ")
        case let .contact(contact):
            contact.textRepresentation
        }
    }

    /// File names, in the history image folder, owned by this content.
    var assetFileNames: [String] {
        switch self {
        case let .image(image):
            [image.fileName]
        case let .link(link):
            link.previewImageName.map { [$0] } ?? []
        default:
            []
        }
    }
}

/// Display category of a clipboard item.
nonisolated enum ClipboardKind: String, CaseIterable, Sendable {
    case text
    case richText
    case code
    case link
    case color
    case image
    case file
    case contact

    var title: String {
        switch self {
        case .text: String(localized: "Text")
        case .richText: String(localized: "Rich Text")
        case .code: String(localized: "Code")
        case .link: String(localized: "Link")
        case .color: String(localized: "Color")
        case .image: String(localized: "Image")
        case .file: String(localized: "File")
        case .contact: String(localized: "Contact")
        }
    }

    var symbolName: String {
        switch self {
        case .text: "text.alignleft"
        case .richText: "textformat"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .link: "link"
        case .color: "paintpalette.fill"
        case .image: "photo.fill"
        case .file: "doc.fill"
        case .contact: "person.crop.circle.fill"
        }
    }
}

extension URL {
    /// Whether the file extension denotes a picture (PNG, JPEG, HEIC, GIF, WebP…).
    nonisolated var isImageFile: Bool {
        isFileURL && UTType(filenameExtension: pathExtension)?.conforms(to: .image) == true
    }
}
