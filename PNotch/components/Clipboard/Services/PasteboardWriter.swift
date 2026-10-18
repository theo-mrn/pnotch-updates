//
//  PasteboardWriter.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import AppKit
import UniformTypeIdentifiers

/// Puts history entries back on the pasteboard, and wraps them for drag and drop.
enum PasteboardWriter {
    private static let vCardType = NSPasteboard.PasteboardType(UTType.vCard.identifier)

    /// - Parameter asPlainText: Drops the formatting of rich text.
    /// - Returns: `false` when the content could not be written, e.g. a deleted image file.
    @discardableResult
    static func write(
        _ item: ClipboardItem,
        asPlainText: Bool = false,
        persistence: ClipboardPersistenceService,
        to pasteboard: NSPasteboard = .general
    ) -> Bool {
        let pasteboardItem = NSPasteboardItem()

        switch item.content {
        case let .text(text), let .code(text):
            pasteboardItem.setString(text, forType: .string)

        case let .richText(payload):
            if !asPlainText {
                pasteboardItem.setData(payload.rtfData, forType: .rtf)
            }
            pasteboardItem.setString(payload.plainText, forType: .string)

        case let .link(link):
            pasteboardItem.setString(link.url.absoluteString, forType: .URL)
            pasteboardItem.setString(link.url.absoluteString, forType: .string)

        case let .color(color):
            pasteboardItem.setString(color.rawValue, forType: .string)

        case let .image(image):
            guard let data = try? Data(contentsOf: persistence.imageURL(named: image.fileName)) else { return false }
            pasteboardItem.setData(data, forType: .png)
            // Many apps still only read TIFF.
            if let tiff = NSImage(data: data)?.tiffRepresentation {
                pasteboardItem.setData(tiff, forType: .tiff)
            }

        case let .files(urls):
            pasteboard.clearContents()
            return pasteboard.writeObjects(urls.map { $0 as NSURL })

        case let .contact(contact):
            pasteboardItem.setData(contact.vCardData, forType: vCardType)
            pasteboardItem.setString(contact.textRepresentation, forType: .string)
        }

        pasteboard.clearContents()
        return pasteboard.writeObjects([pasteboardItem])
    }

    /// Item provider used when a card is dragged out of the notch.
    static func itemProvider(for item: ClipboardItem, persistence: ClipboardPersistenceService) -> NSItemProvider {
        switch item.content {
        case let .text(text), let .code(text):
            NSItemProvider(object: text as NSString)
        case let .richText(payload):
            NSItemProvider(object: payload.plainText as NSString)
        case let .link(link):
            NSItemProvider(object: link.url as NSURL)
        case let .color(color):
            NSItemProvider(object: color.rawValue as NSString)
        case let .image(image):
            NSItemProvider(contentsOf: persistence.imageURL(named: image.fileName)) ?? NSItemProvider()
        case let .files(urls):
            urls.first.flatMap { NSItemProvider(contentsOf: $0) } ?? NSItemProvider()
        case let .contact(contact):
            NSItemProvider(item: contact.vCardData as NSData, typeIdentifier: UTType.vCard.identifier)
        }
    }
}
