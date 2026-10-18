//
//  ClipboardMonitorService.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import AppKit

/// Watches the pasteboard for new content.
///
/// macOS has no pasteboard change notification: like every clipboard manager, this polls `changeCount`,
/// which is a cheap integer read.
final class ClipboardMonitorService {
    var onChange: (() -> Void)?

    private let pasteboard: NSPasteboard
    private let pollingInterval: Duration
    private var lastChangeCount: Int
    private var pollingTask: Task<Void, Never>?

    init(pasteboard: NSPasteboard = .general, pollingInterval: Duration = .milliseconds(350)) {
        self.pasteboard = pasteboard
        self.pollingInterval = pollingInterval
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard pollingTask == nil else { return }
        lastChangeCount = pasteboard.changeCount

        pollingTask = Task { [weak self, pollingInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: pollingInterval)
                self?.checkForChanges()
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Marks the current pasteboard content as already seen. Called after PNotch writes to the pasteboard itself.
    func skipCurrentChange() {
        lastChangeCount = pasteboard.changeCount
    }

    private func checkForChanges() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount
        onChange?()
    }
}
