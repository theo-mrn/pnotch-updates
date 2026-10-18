//
//  ClipboardPersistenceService.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation
import os

/// Stores the history as JSON and the copied images as PNG files under Application Support.
///
/// ```
/// ~/Library/Application Support/com.pnotch.PNotch/
/// ├── history.json
/// └── Images/<uuid>.png
/// ```
nonisolated struct ClipboardPersistenceService: Sendable {
    let rootDirectory: URL

    static let live = ClipboardPersistenceService(
        rootDirectory: URL.applicationSupportDirectory
            .appending(path: Bundle.main.bundleIdentifier ?? "com.pnotch.PNotch", directoryHint: .isDirectory)
    )

    var historyFileURL: URL {
        rootDirectory.appending(path: "history.json", directoryHint: .notDirectory)
    }

    var imagesDirectory: URL {
        rootDirectory.appending(path: "Images", directoryHint: .isDirectory)
    }

    func imageURL(named fileName: String) -> URL {
        imagesDirectory.appending(path: fileName, directoryHint: .notDirectory)
    }

    // MARK: History

    func loadItems() -> [ClipboardItem] {
        guard FileManager.default.fileExists(atPath: historyFileURL.path(percentEncoded: false)) else { return [] }
        do {
            let data = try Data(contentsOf: historyFileURL)
            return try JSONDecoder().decode(StoredHistory.self, from: data).items
        } catch {
            Logger.persistence.error("Failed to load the clipboard history: \(error.localizedDescription)")
            return []
        }
    }

    func save(_ items: [ClipboardItem]) throws {
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(StoredHistory(items: items))
        try data.write(to: historyFileURL, options: .atomic)
    }

    // MARK: Assets

    func writeImage(_ data: Data, named fileName: String) throws {
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        try data.write(to: imageURL(named: fileName), options: .atomic)
    }

    func deleteAssets(of items: [ClipboardItem]) {
        for fileName in items.flatMap(\.content.assetFileNames) {
            try? FileManager.default.removeItem(at: imageURL(named: fileName))
        }
    }

    /// Removes image files no history entry refers to anymore (e.g. after a crash before a save).
    func deleteOrphanedAssets(keeping items: [ClipboardItem]) {
        let referenced = Set(items.flatMap(\.content.assetFileNames))
        let files = (try? FileManager.default.contentsOfDirectory(atPath: imagesDirectory.path(percentEncoded: false))) ?? []
        for fileName in files where !referenced.contains(fileName) {
            try? FileManager.default.removeItem(at: imageURL(named: fileName))
        }
    }
}

/// On-disk envelope, versioned to allow future migrations.
private nonisolated struct StoredHistory: Codable {
    var version = 1
    var items: [ClipboardItem]
}
