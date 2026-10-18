//
//  ClipboardSelectionTests.swift
//  PNotchTests
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation
import Testing
@testable import PNotch

/// Keyboard navigation through the list, including cycling with the global shortcut.
@MainActor
struct ClipboardSelectionTests {
    private func makeClipboard(itemCount: Int = 3) throws -> ClipboardStateViewModel {
        let persistence = ClipboardPersistenceService(
            rootDirectory: FileManager.default.temporaryDirectory.appending(path: "PNotchTests-\(UUID().uuidString)")
        )
        let items = (0 ..< itemCount).map { index in
            ClipboardItem(
                content: .text("item \(index)"),
                fingerprint: "\(index)",
                copiedAt: Date(timeIntervalSince1970: TimeInterval(1000 - index))
            )
        }
        try persistence.save(items)
        return ClipboardStateViewModel(persistence: persistence)
    }

    private func titles(_ clipboard: ClipboardStateViewModel) -> String? {
        clipboard.highlightedItemID.flatMap { id in clipboard.history.item(id: id)?.content.searchableText }
    }

    @Test func listHighlightsTheFirstItemRightAway() throws {
        let clipboard = try makeClipboard()
        #expect(titles(clipboard) == "item 0")
    }

    @Test func movingDownFromTheAutoHighlightGoesToTheSecondItem() throws {
        let clipboard = try makeClipboard()

        clipboard.moveSelection(by: 1)
        #expect(titles(clipboard) == "item 1")
    }

    @Test func shortcutCyclesBackToTheTop() throws {
        let clipboard = try makeClipboard()

        clipboard.moveSelection(by: 1, wrapping: true)
        clipboard.moveSelection(by: 1, wrapping: true)
        #expect(titles(clipboard) == "item 2")

        clipboard.moveSelection(by: 1, wrapping: true)
        #expect(titles(clipboard) == "item 0")

        clipboard.moveSelection(by: -1, wrapping: true)
        #expect(titles(clipboard) == "item 2")
    }

    @Test func arrowsStopAtTheEnds() throws {
        let clipboard = try makeClipboard()

        clipboard.moveSelection(by: -1)
        #expect(titles(clipboard) == "item 0")

        clipboard.moveSelection(by: 10)
        #expect(titles(clipboard) == "item 2")
    }

    @Test func typingASearchHighlightsTheBestMatch() throws {
        let clipboard = try makeClipboard()
        clipboard.moveSelection(by: 2)

        clipboard.searchQuery = "item 1"
        #expect(titles(clipboard) == "item 1")
    }

    @Test func listTitlesAreSingleLines() {
        #expect(ClipboardContent.text("\n\n  First line  \nSecond").listTitle == "First line")
        #expect(ClipboardContent.files([URL(fileURLWithPath: "/tmp/image001830.png")]).listTitle == "image001830.png")
        #expect(ClipboardContent.link(.init(url: URL(string: "https://www.twitch.tv/gunix7")!)).listTitle == "https://www.twitch.tv/gunix7")
    }
}
