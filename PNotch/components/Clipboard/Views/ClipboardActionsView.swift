//
//  ClipboardActionsView.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// Clipboard buttons of the notch header: pause recording and clear the history.
struct ClipboardActionsView: View {
    @Environment(ClipboardStateViewModel.self) private var clipboard

    @State private var isClearArmed = false
    @State private var disarmTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 6) {
            HoverButton(
                systemImage: clipboard.isCapturePaused ? "play.fill" : "pause.fill",
                isActive: clipboard.isCapturePaused
            ) {
                clipboard.isCapturePaused.toggle()
            }
            .help(clipboard.isCapturePaused ? "Resume recording copies" : "Pause recording copies")

            HoverButton(systemImage: isClearArmed ? "trash.fill" : "trash", tint: isClearArmed ? .red : nil) {
                handleClearTap()
            }
            .help(isClearArmed ? "Click again to clear unpinned items" : "Clear history")
        }
    }

    /// Clearing takes two clicks: the first one arms the button for a few seconds.
    private func handleClearTap() {
        disarmTask?.cancel()
        guard isClearArmed else {
            isClearArmed = true
            disarmTask = Task {
                try? await Task.sleep(for: .seconds(2.5))
                guard !Task.isCancelled else { return }
                isClearArmed = false
            }
            return
        }
        isClearArmed = false
        clipboard.clearHistory()
    }
}
