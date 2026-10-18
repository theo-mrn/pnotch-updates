//
//  ClipboardHistory.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation

/// Ordered, size-bounded list of clipboard items, most recent first.
///
/// Pure value type: it never touches the disk. Mutations that drop items return them so the caller
/// can delete the files they own.
nonisolated struct ClipboardHistory: Equatable, Sendable {
    private(set) var items: [ClipboardItem]
    private(set) var limit: Int

    init(items: [ClipboardItem] = [], limit: Int) {
        self.items = items.sorted { $0.copiedAt > $1.copiedAt }
        self.limit = max(1, limit)
    }

    var isEmpty: Bool {
        items.isEmpty
    }

    func item(id: ClipboardItem.ID) -> ClipboardItem? {
        items.first { $0.id == id }
    }

    func item(withFingerprint fingerprint: String) -> ClipboardItem? {
        items.first { $0.fingerprint == fingerprint }
    }

    func items(matching filter: ClipboardFilter, query: String = "") -> [ClipboardItem] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { item in
            filter.matches(item) && (query.isEmpty || item.matches(query: query))
        }
    }

    // MARK: Mutations

    /// Inserts `item` on top of the history. When an entry with the same fingerprint already exists,
    /// that entry is moved to the top instead, keeping its pin and identity.
    ///
    /// - Returns: The entries evicted to honour `limit`.
    @discardableResult
    mutating func record(_ item: ClipboardItem) -> [ClipboardItem] {
        if let index = items.firstIndex(where: { $0.fingerprint == item.fingerprint }) {
            var existing = items.remove(at: index)
            existing.copiedAt = item.copiedAt
            existing.sourceApp = item.sourceApp ?? existing.sourceApp
            items.insert(existing, at: 0)
            return []
        }
        items.insert(item, at: 0)
        return trimToLimit()
    }

    /// Moves an existing entry to the top, as if it had just been copied.
    mutating func promote(id: ClipboardItem.ID, at date: Date) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items.remove(at: index)
        item.copiedAt = date
        items.insert(item, at: 0)
    }

    mutating func update(id: ClipboardItem.ID, _ transform: (inout ClipboardItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        transform(&items[index])
    }

    @discardableResult
    mutating func remove(id: ClipboardItem.ID) -> ClipboardItem? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        return items.remove(at: index)
    }

    /// - Returns: The removed entries.
    @discardableResult
    mutating func removeAll(keepingPinned: Bool) -> [ClipboardItem] {
        let removed = keepingPinned ? items.filter { !$0.isPinned } : items
        items = keepingPinned ? items.filter(\.isPinned) : []
        return removed
    }

    /// - Returns: The entries evicted to honour the new limit.
    @discardableResult
    mutating func setLimit(_ newLimit: Int) -> [ClipboardItem] {
        limit = max(1, newLimit)
        return trimToLimit()
    }

    /// Drops the oldest unpinned entries until the history fits `limit`. Pinned entries are never evicted.
    private mutating func trimToLimit() -> [ClipboardItem] {
        var evicted: [ClipboardItem] = []
        var index = items.count - 1
        while items.count > limit, index >= 0 {
            if !items[index].isPinned {
                evicted.append(items.remove(at: index))
            }
            index -= 1
        }
        return evicted
    }
}

extension ClipboardItem {
    /// Every word of `query` must appear in the content, the kind ("image", "link"…) or the source app name.
    /// Case and diacritics are ignored, so "cafe" finds "Café".
    nonisolated func matches(query: String) -> Bool {
        let haystack = [content.searchableText, kind.title, sourceApp?.name ?? ""].joined(separator: "\n")
        return query
            .split(whereSeparator: \.isWhitespace)
            .allSatisfy { haystack.localizedStandardContains($0) }
    }
}
