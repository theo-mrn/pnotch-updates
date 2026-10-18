//
//  PasteService.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Pastes into the app the user is working in by posting ⌘V. macOS only allows an app to do so
/// with the Accessibility permission (System Settings › Privacy & Security › Accessibility).
enum PasteService {
    private static var hasPromptedThisLaunch = false

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt, once per launch: later attempts quietly fall back to copying.
    static func requestPermissionIfNeeded() {
        guard !hasPromptedThisLaunch else { return }
        hasPromptedThisLaunch = true
        // "AXTrustedCheckOptionPrompt" is the value of `kAXTrustedCheckOptionPrompt`.
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Posts ⌘V after `delay`, which leaves the notch time to hand the keyboard back to the frontmost app.
    static func pasteIntoFrontmostApp(after delay: Duration = .milliseconds(150)) {
        Task {
            try? await Task.sleep(for: delay)
            postCommandV()
        }
    }

    private static func postCommandV() {
        let keyCode = KeyboardLayout.keyCode(for: "v") ?? CGKeyCode(kVK_ANSI_V)
        let source = CGEventSource(stateID: .combinedSessionState)
        for isKeyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isKeyDown)
            event?.flags = .maskCommand
            event?.post(tap: .cgSessionEventTap)
        }
    }
}
