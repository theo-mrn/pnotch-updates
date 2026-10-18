//
//  PasteboardRoundTripTests.swift
//  PNotchTests
//
//  Created by Theo Morin on 17/10/2026.
//

import AppKit
import Testing
@testable import PNotch

/// Writes items to a private pasteboard and reads them back, as PNotch does with the general one.
@MainActor
struct PasteboardRoundTripTests {
    private let pasteboard = NSPasteboard.withUniqueName()
    private let persistence = ClipboardPersistenceService(
        rootDirectory: FileManager.default.temporaryDirectory.appending(path: "PNotchTests-\(UUID().uuidString)")
    )

    @Test(arguments: [
        ClipboardContent.text("Thanks Maya"),
        .code("let answer = compute(42);\nprint(answer);"),
        .color(ColorParser.parse("#3A6FF2")!),
        .link(.init(url: URL(string: "https://example.com")!)),
    ])
    func textualContentSurvivesTheRoundTrip(content: ClipboardContent) throws {
        let item = ClipboardItem(content: content, fingerprint: "test")

        #expect(PasteboardWriter.write(item, persistence: persistence, to: pasteboard))
        let snapshot = try #require(PasteboardReader.snapshot(of: pasteboard))
        let restored = try #require(try ClipboardItemFactory.makeItem(
            from: snapshot,
            sourceApp: nil,
            copiedAt: .now,
            persistence: persistence
        ))

        #expect(restored.content == content)
    }

    @Test func plainTextCopyDropsFormatting() throws {
        let attributed = NSAttributedString(string: "Bold", attributes: [.font: NSFont.boldSystemFont(ofSize: 13)])
        let rtf = try attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        let item = ClipboardItem(content: .richText(.init(plainText: "Bold", rtfData: rtf)), fingerprint: "test")

        PasteboardWriter.write(item, asPlainText: true, persistence: persistence, to: pasteboard)

        #expect(pasteboard.string(forType: .string) == "Bold")
        #expect(pasteboard.data(forType: .rtf) == nil)
    }

    @Test func concealedContentIsIgnored() {
        let item = NSPasteboardItem()
        item.setString("hunter2", forType: .string)
        item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        pasteboard.clearContents()
        pasteboard.writeObjects([item])

        #expect(PasteboardReader.snapshot(of: pasteboard) == nil)
    }

    @Test(arguments: ["", "IMG_2041.jpeg", "https://example.com/cat.png"])
    func imageWithCompanionTextIsAnImage(text: String) throws {
        try writeImage(withText: text)

        guard case .image = PasteboardReader.snapshot(of: pasteboard) else {
            Issue.record("Expected an image snapshot")
            return
        }
    }

    @Test func imageNextToRealTextIsText() throws {
        try writeImage(withText: "Quarterly numbers are in, see attached.")

        guard case .text = PasteboardReader.snapshot(of: pasteboard) else {
            Issue.record("Expected a text snapshot")
            return
        }
    }

    @Test func sameTextSharesAFingerprintWhateverItsFormatting() {
        let plain = PasteboardSnapshot.text("Hello", rtf: nil)
        let rich = PasteboardSnapshot.text("Hello", rtf: Data("{\\rtf1 Hello}".utf8))

        #expect(plain.fingerprint == rich.fingerprint)
        #expect(plain.fingerprint != PasteboardSnapshot.text("Hello!", rtf: nil).fingerprint)
    }

    /// Mimics apps that put a picture and a bit of text on the pasteboard at once.
    private func writeImage(withText text: String) throws {
        let image = NSImage(size: NSSize(width: 4, height: 4), flipped: false) { rect in
            NSColor.systemTeal.setFill()
            rect.fill()
            return true
        }
        let item = NSPasteboardItem()
        item.setData(try #require(image.tiffRepresentation), forType: .tiff)
        if !text.isEmpty {
            item.setString(text, forType: .string)
        }
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }
}
