//
//  ClipboardStateViewModel.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import AppKit
import Defaults
import Observation
import os

/// Clipboard history state and every action the notch UI can perform on it.
@Observable
final class ClipboardStateViewModel {
    private(set) var history: ClipboardHistory
    var filter: ClipboardFilter = .all {
        didSet {
            if filter != oldValue { selectedItemID = nil }
        }
    }
    var searchQuery = "" {
        // Text fields write their binding back when focused: only a real edit resets the selection.
        didSet {
            if searchQuery != oldValue { selectedItemID = nil }
        }
    }
    /// Incremented to ask the search field to take the keyboard focus.
    private(set) var searchFocusRequest = 0
    private(set) var selectedItemID: ClipboardItem.ID?
    /// The row currently showing the "Copied" confirmation.
    private(set) var recentlyCopiedItemID: ClipboardItem.ID?
    var isCapturePaused = false

    /// A new entry landed in the history (drives the notch sneak peek).
    @ObservationIgnored var onItemCaptured: ((ClipboardItem) -> Void)?
    /// An entry was written back to the pasteboard, to be pasted by hand.
    @ObservationIgnored var onItemCopied: ((ClipboardItem) -> Void)?
    /// An entry was written back to the pasteboard and must now be pasted into the frontmost app.
    @ObservationIgnored var onItemPasted: ((ClipboardItem) -> Void)?

    @ObservationIgnored let persistence: ClipboardPersistenceService
    @ObservationIgnored private let monitor: ClipboardMonitorService
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var settingsTask: Task<Void, Never>?

    init(
        persistence: ClipboardPersistenceService = .live,
        monitor: ClipboardMonitorService = ClipboardMonitorService()
    ) {
        self.persistence = persistence
        self.monitor = monitor
        history = ClipboardHistory(items: persistence.loadItems(), limit: Defaults[.clipboardHistoryLimit])
        persistence.deleteOrphanedAssets(keeping: history.items)

        monitor.onChange = { [weak self] in
            self?.capturePasteboard()
        }
    }

    /// Items shown in the strip for the current filter and search.
    var visibleItems: [ClipboardItem] {
        history.items(matching: filter, query: searchQuery)
    }

    func start() {
        monitor.start()
        settingsTask = Task { [weak self] in
            for await limit in Defaults.updates(.clipboardHistoryLimit, initial: false) {
                self?.applyHistoryLimit(limit)
            }
        }
    }

    func stop() {
        monitor.stop()
        settingsTask?.cancel()
    }

    /// Writes pending changes synchronously. Called when the app quits.
    func flushPendingChanges() {
        saveTask?.cancel()
        do {
            try persistence.save(history.items)
        } catch {
            Logger.persistence.error("Failed to save the clipboard history: \(error.localizedDescription)")
        }
    }

    // MARK: Actions

    /// What choosing an item does.
    enum Activation: Equatable {
        case paste
        case copy
        /// Pasting needs the Accessibility permission: copy now and ask for it.
        case copyAndRequestPermission
    }

    nonisolated static func activation(copyOnly: Bool, pasteDirectly: Bool, isTrusted: Bool) -> Activation {
        guard !copyOnly, pasteDirectly else { return .copy }
        return isTrusted ? .paste : .copyAndRequestPermission
    }

    /// Clicking a card or pressing ↩: pastes into the app in use, or only copies when `copyOnly` (⌥)
    /// or when direct paste is off in Settings.
    func activate(_ item: ClipboardItem, asPlainText: Bool = false, copyOnly: Bool = false) {
        switch Self.activation(copyOnly: copyOnly, pasteDirectly: Defaults[.pasteDirectly], isTrusted: PasteService.isTrusted) {
        case .paste:
            paste(item, asPlainText: asPlainText)
        case .copy:
            copy(item, asPlainText: asPlainText)
        case .copyAndRequestPermission:
            copy(item, asPlainText: asPlainText)
            PasteService.requestPermissionIfNeeded()
        }
    }

    func copy(_ item: ClipboardItem, asPlainText: Bool = false) {
        guard writeToPasteboard(item, asPlainText: asPlainText) else { return }
        recentlyCopiedItemID = item.id
        onItemCopied?(item)

        // Let the confirmation play on the card before it moves to the front of the strip.
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            self?.finishCopy(of: item.id)
        }
    }

    func paste(_ item: ClipboardItem, asPlainText: Bool = false) {
        guard writeToPasteboard(item, asPlainText: asPlainText) else { return }
        onItemPasted?(item)

        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            self?.finishCopy(of: item.id)
        }
    }

    private func writeToPasteboard(_ item: ClipboardItem, asPlainText: Bool) -> Bool {
        guard PasteboardWriter.write(item, asPlainText: asPlainText, persistence: persistence) else {
            Logger.clipboard.error("Failed to write a \(item.kind.rawValue) item to the pasteboard")
            NSSound.beep()
            return false
        }
        monitor.skipCurrentChange()
        return true
    }

    func togglePin(_ item: ClipboardItem) {
        history.update(id: item.id) { $0.isPinned.toggle() }
        scheduleSave()
    }

    func delete(_ item: ClipboardItem) {
        let items = visibleItems
        if selectedItemID == item.id, let index = items.firstIndex(of: item) {
            let neighbor = items.indices.contains(index + 1) ? items[index + 1] : items[safe: index - 1]
            selectedItemID = neighbor?.id
        }
        guard let removed = history.remove(id: item.id) else { return }
        persistence.deleteAssets(of: [removed])
        scheduleSave()
    }

    /// Clears every unpinned entry.
    func clearHistory() {
        persistence.deleteAssets(of: history.removeAll(keepingPinned: true))
        selectedItemID = nil
        scheduleSave()
    }

    func openLink(of item: ClipboardItem) {
        guard case let .link(link) = item.content else { return }
        NSWorkspace.shared.open(link.url)
    }

    func revealInFinder(_ item: ClipboardItem) {
        guard case let .files(urls) = item.content else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func imageURL(named fileName: String) -> URL {
        persistence.imageURL(named: fileName)
    }

    func itemProvider(for item: ClipboardItem) -> NSItemProvider {
        PasteboardWriter.itemProvider(for: item, persistence: persistence)
    }

    // MARK: Search

    var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func focusSearch() {
        searchFocusRequest += 1
    }

    func clearSearch() {
        searchQuery = ""
    }

    /// Forgets the search and the keyboard selection, so the next opening starts from the latest copies.
    func resetTransientState() {
        searchQuery = ""
        selectedItemID = nil
    }

    // MARK: Keyboard selection

    func select(_ item: ClipboardItem?) {
        selectedItemID = item?.id
    }

    /// The item ↩ would paste: the selection, or the first item until the user picks another one,
    /// so ↩ always has a target.
    var highlightedItemID: ClipboardItem.ID? {
        selectedItemID ?? visibleItems.first?.id
    }

    /// - Parameter wrapping: Goes back to the first item after the last one, and the other way round.
    func moveSelection(by offset: Int, wrapping: Bool = false) {
        let items = visibleItems
        guard !items.isEmpty else { return }

        guard let currentIndex = items.firstIndex(where: { $0.id == highlightedItemID }) else {
            selectedItemID = items.first?.id
            return
        }
        let newIndex = wrapping
            ? ((currentIndex + offset) % items.count + items.count) % items.count
            : min(max(currentIndex + offset, 0), items.count - 1)
        selectedItemID = items[newIndex].id
    }

    /// Activates the highlighted item, or the first one when nothing is highlighted.
    func activateSelectedItem(asPlainText: Bool = false, copyOnly: Bool = false) {
        guard let item = highlightedItem ?? visibleItems.first else { return }
        activate(item, asPlainText: asPlainText, copyOnly: copyOnly)
    }

    func deleteSelectedItem() {
        guard let highlightedItem else { return }
        delete(highlightedItem)
    }

    func togglePinOnSelectedItem() {
        guard let highlightedItem else { return }
        togglePin(highlightedItem)
    }

    private var highlightedItem: ClipboardItem? {
        highlightedItemID.flatMap { history.item(id: $0) }
    }

    // MARK: Capture

    private func capturePasteboard() {
        guard !isCapturePaused, let snapshot = PasteboardReader.snapshot(of: .general) else { return }

        let sourceApp = SourceApplication.frontmost
        let copiedAt = Date.now

        // Copying something already in the history only moves it to the front.
        if let existing = history.item(withFingerprint: snapshot.fingerprint) {
            var promoted = existing
            promoted.copiedAt = copiedAt
            promoted.sourceApp = sourceApp ?? existing.sourceApp
            history.record(promoted)
            scheduleSave()
            onItemCaptured?(promoted)
            return
        }

        let persistence = persistence
        Task { [weak self] in
            let item = await Task.detached(priority: .userInitiated) {
                do {
                    return try ClipboardItemFactory.makeItem(
                        from: snapshot,
                        sourceApp: sourceApp,
                        copiedAt: copiedAt,
                        persistence: persistence
                    )
                } catch {
                    Logger.clipboard.error("Failed to store a copied item: \(error.localizedDescription)")
                    return nil
                }
            }.value
            guard let self, let item else { return }
            insert(item)
        }
    }

    private func insert(_ item: ClipboardItem) {
        persistence.deleteAssets(of: history.record(item))
        scheduleSave()
        onItemCaptured?(item)

        if case let .link(link) = item.content, Defaults[.fetchLinkPreviews] {
            fetchPreview(for: item.id, url: link.url)
        }
    }

    private func fetchPreview(for itemID: ClipboardItem.ID, url: URL) {
        let persistence = persistence
        Task { [weak self] in
            guard let preview = await LinkPreviewService.fetchPreview(for: url) else { return }

            var imageName: String?
            if let imageData = preview.imageData {
                let fileName = "\(UUID().uuidString).png"
                do {
                    try persistence.writeImage(imageData, named: fileName)
                    imageName = fileName
                } catch {
                    Logger.clipboard.error("Failed to store a link preview: \(error.localizedDescription)")
                }
            }
            self?.applyPreview(title: preview.title, imageName: imageName, to: itemID)
        }
    }

    private func applyPreview(title: String?, imageName: String?, to itemID: ClipboardItem.ID) {
        guard history.item(id: itemID) != nil else {
            // The entry was deleted while the preview was loading.
            if let imageName {
                try? FileManager.default.removeItem(at: persistence.imageURL(named: imageName))
            }
            return
        }
        history.update(id: itemID) { item in
            guard case var .link(link) = item.content else { return }
            link.title = title ?? link.title
            link.previewImageName = imageName ?? link.previewImageName
            item.content = .link(link)
        }
        scheduleSave()
    }

    private func finishCopy(of itemID: ClipboardItem.ID) {
        if recentlyCopiedItemID == itemID {
            recentlyCopiedItemID = nil
        }
        history.promote(id: itemID, at: .now)
        scheduleSave()
    }

    private func applyHistoryLimit(_ limit: Int) {
        persistence.deleteAssets(of: history.setLimit(limit))
        scheduleSave()
    }

    // MARK: Persistence

    /// Coalesces bursts of changes into a single write, off the main thread.
    private func scheduleSave() {
        saveTask?.cancel()
        let persistence = persistence
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let items = self?.history.items, !Task.isCancelled else { return }

            await Task.detached(priority: .utility) {
                do {
                    try persistence.save(items)
                } catch {
                    Logger.persistence.error("Failed to save the clipboard history: \(error.localizedDescription)")
                }
            }.value
        }
    }
}

// MARK: - Helpers

private extension SourceApplication {
    static var frontmost: SourceApplication? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = app.bundleIdentifier,
              bundleIdentifier != Bundle.main.bundleIdentifier
        else { return nil }
        return SourceApplication(bundleIdentifier: bundleIdentifier, name: app.localizedName ?? bundleIdentifier)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
