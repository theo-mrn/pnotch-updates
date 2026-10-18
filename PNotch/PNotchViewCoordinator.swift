//
//  PNotchViewCoordinator.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Observation
import SwiftUI

/// A short-lived activity shown around the closed notch: something was copied, Claude Code is done…
struct SneakPeek: Equatable, Identifiable {
    enum Content: Equatable {
        case copy(Copy)
        case claudeCode(ClaudeCodeOutcome)
        case focus(FocusTimer.Event)
    }

    struct Copy: Equatable {
        let kind: ClipboardKind
        let sourceApp: SourceApplication?
        let color: ColorValue?
    }

    enum ClaudeCodeOutcome: Equatable {
        case finished
        case failed
    }

    let id = UUID()
    let content: Content

    init(item: ClipboardItem) {
        var color: ColorValue?
        if case let .color(value) = item.content {
            color = value
        }
        content = .copy(Copy(kind: item.kind, sourceApp: item.sourceApp, color: color))
    }

    init(claudeCode outcome: ClaudeCodeOutcome) {
        content = .claudeCode(outcome)
    }

    init(focus event: FocusTimer.Event) {
        content = .focus(event)
    }
}

/// App-wide UI state that is not tied to the notch geometry: sneak peeks, navigation to Settings.
@Observable
final class PNotchViewCoordinator {
    private(set) var sneakPeek: SneakPeek?

    @ObservationIgnored var onShowSettings: (() -> Void)?
    @ObservationIgnored private var sneakPeekTask: Task<Void, Never>?

    func showSneakPeek(_ peek: SneakPeek, duration: Duration = .seconds(1.8)) {
        sneakPeekTask?.cancel()
        sneakPeek = peek
        sneakPeekTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard let self, !Task.isCancelled, sneakPeek?.id == peek.id else { return }
            sneakPeek = nil
        }
    }

    func dismissSneakPeek() {
        sneakPeekTask?.cancel()
        sneakPeek = nil
    }

    func showSettings() {
        onShowSettings?()
    }
}
