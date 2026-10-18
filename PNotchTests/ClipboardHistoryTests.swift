//
//  ClipboardHistoryTests.swift
//  PNotchTests
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation
import SwiftUI
import Testing
@testable import PNotch

struct ClipboardHistoryTests {
    @Test func newestItemComesFirst() {
        var history = ClipboardHistory(limit: 10)
        history.record(.text("first", at: 1))
        history.record(.text("second", at: 2))

        #expect(history.items.map(\.content.searchableText) == ["second", "first"])
    }

    @Test func copyingTheSameContentPromotesTheExistingEntry() {
        var history = ClipboardHistory(limit: 10)
        let original = ClipboardItem.text("hello", at: 1, isPinned: true)
        history.record(original)
        history.record(.text("other", at: 2))

        let evicted = history.record(.text("hello", at: 3))

        #expect(evicted.isEmpty)
        #expect(history.items.count == 2)
        #expect(history.items.first?.id == original.id)
        #expect(history.items.first?.isPinned == true)
        #expect(history.items.first?.copiedAt == Date(timeIntervalSince1970: 3))
    }

    @Test func evictsOldestUnpinnedItemsBeyondTheLimit() {
        var history = ClipboardHistory(limit: 2)
        history.record(.text("pinned", at: 1, isPinned: true))
        history.record(.text("old", at: 2))
        let evicted = history.record(.text("new", at: 3))

        #expect(evicted.map(\.content.searchableText) == ["old"])
        #expect(history.items.map(\.content.searchableText) == ["new", "pinned"])
    }

    @Test func pinnedItemsSurviveALowerLimit() {
        var history = ClipboardHistory(limit: 10)
        history.record(.text("a", at: 1, isPinned: true))
        history.record(.text("b", at: 2, isPinned: true))
        history.record(.text("c", at: 3))

        let evicted = history.setLimit(1)

        #expect(evicted.map(\.content.searchableText) == ["c"])
        #expect(history.items.count == 2)
    }

    @Test func clearingKeepsPinnedItems() {
        var history = ClipboardHistory(limit: 10)
        history.record(.text("keep", at: 1, isPinned: true))
        history.record(.text("drop", at: 2))

        let removed = history.removeAll(keepingPinned: true)

        #expect(removed.map(\.content.searchableText) == ["drop"])
        #expect(history.items.map(\.content.searchableText) == ["keep"])
    }

    @Test func filtersAndSearches() {
        var history = ClipboardHistory(limit: 10)
        history.record(.text("Quarterly report", at: 1))
        history.record(ClipboardItem(
            content: .link(.init(url: URL(string: "https://example.com/report")!)),
            fingerprint: "link",
            copiedAt: Date(timeIntervalSince1970: 2)
        ))
        history.record(ClipboardItem(
            content: .files([URL(fileURLWithPath: "/Users/me/Desktop/Report cover.png")]),
            fingerprint: "png",
            copiedAt: Date(timeIntervalSince1970: 3)
        ))

        #expect(history.items(matching: .links).count == 1)
        #expect(history.items(matching: .images).count == 1)
        #expect(history.items(matching: .all, query: "REPORT").count == 3)
        #expect(history.items(matching: .links, query: "quarterly").isEmpty)
    }

    @Test func searchMatchesEveryWordAnywhere() {
        var history = ClipboardHistory(limit: 10)
        history.record(.text("Thanks Maya — the revised brief works. Let's lock the palette on Friday.", at: 1))
        history.record(.text("Café meeting on Friday", at: 2))

        #expect(history.items(matching: .all, query: "friday maya").count == 1)
        #expect(history.items(matching: .all, query: "  cafe   FRIDAY ").count == 1)
        #expect(history.items(matching: .all, query: "friday").count == 2)
        #expect(history.items(matching: .all, query: "friday sunday").isEmpty)
        #expect(history.items(matching: .all, query: "text").count == 2)
    }

    @Test func pictureFilesCountAsImages() {
        let pictures = ClipboardContent.files([
            URL(fileURLWithPath: "/tmp/shot.png"),
            URL(fileURLWithPath: "/tmp/photo.HEIC"),
            URL(fileURLWithPath: "/tmp/logo.svg"),
        ])
        let mixed = ClipboardContent.files([URL(fileURLWithPath: "/tmp/shot.png"), URL(fileURLWithPath: "/tmp/notes.pdf")])
        let document = ClipboardContent.files([URL(fileURLWithPath: "/tmp/notes.pdf")])

        #expect(pictures.kind == .image)
        #expect(mixed.kind == .file)
        #expect(document.kind == .file)
    }

    @Test func promoteMovesAnItemToTheTop() {
        var history = ClipboardHistory(limit: 10)
        let first = ClipboardItem.text("first", at: 1)
        history.record(first)
        history.record(.text("second", at: 2))

        history.promote(id: first.id, at: Date(timeIntervalSince1970: 5))

        #expect(history.items.first?.id == first.id)
    }
}

private extension ClipboardItem {
    static func text(_ text: String, at timestamp: TimeInterval, isPinned: Bool = false) -> ClipboardItem {
        ClipboardItem(
            content: .text(text),
            fingerprint: PasteboardSnapshot.text(text, rtf: nil).fingerprint,
            copiedAt: Date(timeIntervalSince1970: timestamp),
            isPinned: isPinned
        )
    }
}

struct SearchHighlighterTests {
    private func highlightedText(_ attributed: AttributedString) -> [String] {
        attributed.runs
            .filter { $0.backgroundColor != nil }
            .map { String(attributed[$0.range].characters) }
    }

    @Test func highlightsEveryWordIgnoringCaseAndAccents() {
        let attributed = SearchHighlighter.highlighting("cafe FRIDAY", in: "Café on Friday, then friday again")
        #expect(highlightedText(attributed) == ["Café", "Friday", "friday"])
    }

    @Test func emptyQueryHighlightsNothing() {
        #expect(highlightedText(SearchHighlighter.highlighting("  ", in: "Anything")).isEmpty)
    }
}
