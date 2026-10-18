//
//  SettingsWindowController.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import AppKit
import SwiftUI

/// Standard window hosting `SettingsView`.
///
/// The SwiftUI `Settings` scene can't be opened reliably from an accessory app's panel,
/// so PNotch manages the window itself.
final class SettingsWindowController: NSWindowController {
    init(clipboard: ClipboardStateViewModel, updates: UpdateManager, claudeCode: ClaudeCodeManager) {
        let hostingController = NSHostingController(
            rootView: SettingsView()
                .environment(clipboard)
                .environment(updates)
                .environment(claudeCode)
        )
        hostingController.sizingOptions = .preferredContentSize

        let window = NSWindow(contentViewController: hostingController)
        window.title = String(localized: "PNotch Settings")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        NSApp.activate()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
