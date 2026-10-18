//
//  NotchWindowController.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Hosts `ContentView` in a `PNotchWindow` pinned to the top of the notched display,
/// and routes keyboard and outside clicks to the view models.
final class NotchWindowController: NSWindowController {
    /// Text editing shortcuts. PNotch never becomes the active app, so the Edit menu can't deliver them.
    private static let editingActions: [String: Selector] = [
        "a": #selector(NSResponder.selectAll(_:)),
        "c": #selector(NSText.copy(_:)),
        "v": #selector(NSText.paste(_:)),
        "x": #selector(NSText.cut(_:)),
        "z": Selector(("undo:")),
    ]

    private let viewModel: PNotchViewModel
    private let clipboard: ClipboardStateViewModel
    private var keyDownMonitor: EventMonitor?
    private var outsideClickMonitor: EventMonitor?

    init(
        viewModel: PNotchViewModel,
        coordinator: PNotchViewCoordinator,
        clipboard: ClipboardStateViewModel,
        music: MusicManager,
        system: SystemMonitor,
        companion: CompanionManager,
        claudeCode: ClaudeCodeManager,
        focus: FocusManager
    ) {
        self.viewModel = viewModel
        self.clipboard = clipboard

        let window = PNotchWindow(contentRect: viewModel.geometry.windowFrame)
        super.init(window: window)

        let rootView = ContentView()
            .environment(viewModel)
            .environment(coordinator)
            .environment(clipboard)
            .environment(music)
            .environment(system)
            .environment(companion)
            .environment(claudeCode)
            .environment(focus)
        let hostingView = NSHostingView(rootView: rootView)
        // The window frame is driven by the display geometry, never by the SwiftUI content.
        hostingView.sizingOptions = []
        window.contentView = hostingView
        window.setFrame(viewModel.geometry.windowFrame, display: false)
        window.orderFrontRegardless()

        viewModel.onKeyboardFocusRequest = { [weak self] wantsFocus in
            self?.setKeyboardFocus(wantsFocus)
        }
        viewModel.isKeyboardFocused = { [weak window] in
            window?.isKeyWindow == true
        }
        installEventMonitors()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateScreen(_ screen: NSScreen?) {
        viewModel.updateGeometry(for: screen)
        window?.setFrame(viewModel.geometry.windowFrame, display: true)
    }

    // MARK: Keyboard focus

    private func setKeyboardFocus(_ wantsFocus: Bool) {
        guard let window else { return }

        if wantsFocus {
            window.makeKey()
            // The search bar is the only text input: with the keyboard at hand, typing searches right away.
            clipboard.focusSearch()
        } else if window.isKeyWindow {
            // A non-activating panel can't hand key status back directly: ordering it out returns
            // the keyboard to the frontmost app, so ⌘V lands where the user was typing.
            window.orderOut(nil)
            window.orderFrontRegardless()
        }
    }

    // MARK: Event monitors

    private func installEventMonitors() {
        keyDownMonitor = .local(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event) ?? event
        }
        outsideClickMonitor = .global(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.viewModel.handleClick(at: NSEvent.mouseLocation)
        }
    }

    /// Keyboard navigation inside the opened notch. Returns `nil` when the event was handled.
    ///
    /// Arrows move between cards even while typing in the search bar, like in Spotlight;
    /// with a modifier (⌥←, ⌘→…) they keep editing the text.
    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard viewModel.notchState == .open, event.window === window else { return event }

        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let isEditingText = (window?.firstResponder as? NSTextView)?.isFieldEditor == true
        let isEditingQuery = isEditingText && clipboard.isSearching

        if isEditingText, modifiers == .command,
           let action = Self.editingActions[event.charactersIgnoringModifiers?.lowercased() ?? ""] {
            return NSApp.sendAction(action, to: nil, from: self) ? nil : event
        }

        // Other pages only close with esc; the rest belongs to their text fields (e.g. the robot's name).
        guard viewModel.page == .clipboard else {
            guard Int(event.keyCode) == kVK_Escape else { return event }
            viewModel.close(reason: .escape)
            return nil
        }

        switch Int(event.keyCode) {
        case kVK_Escape:
            if clipboard.isSearching {
                clipboard.clearSearch()
            } else {
                viewModel.close(reason: .escape)
            }
        case kVK_Return, kVK_ANSI_KeypadEnter:
            clipboard.activateSelectedItem(
                asPlainText: modifiers.contains(.shift),
                copyOnly: modifiers.contains(.option)
            )
        // ← → stay with the search field's cursor.
        case kVK_UpArrow where modifiers.isEmpty:
            clipboard.moveSelection(by: -1)
        case kVK_DownArrow where modifiers.isEmpty:
            clipboard.moveSelection(by: 1)
        case kVK_ANSI_F where modifiers == .command:
            viewModel.requestKeyboardFocus()
        case kVK_Delete where modifiers == .command && !isEditingQuery:
            clipboard.deleteSelectedItem()
        case kVK_ANSI_P where modifiers == .command:
            clipboard.togglePinOnSelectedItem()
        default:
            return event
        }
        return nil
    }
}
