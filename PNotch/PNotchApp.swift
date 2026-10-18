//
//  PNotchApp.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Defaults
import KeyboardShortcuts
import SwiftUI

@main
struct PNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Default(.menubarIcon) private var showMenuBarIcon

    var body: some Scene {
        MenuBarExtra("PNotch", systemImage: "clipboard", isInserted: $showMenuBarIcon) {
            Button("Open Clipboard") {
                appDelegate.showClipboardList()
            }
            Button("Settings…") {
                appDelegate.showSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            if appDelegate.updates.isAvailable {
                Button("Check for Updates…") {
                    appDelegate.updates.checkForUpdates()
                }
            }
            Divider()
            Button("Quit PNotch") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = PNotchViewCoordinator()
    private var notchViewModel: PNotchViewModel?
    private var clipboard: ClipboardStateViewModel?
    private var music: MusicManager?
    private let systemMonitor = SystemMonitor()
    private var companion: CompanionManager?
    private let claudeCode = ClaudeCodeManager()
    private let focus = FocusManager()
    let updates = UpdateManager()
    private var notchWindowController: NotchWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var screenParametersObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_: Notification) {
        // Unit tests are hosted by the app: keep the process inert so they don't touch the real pasteboard.
        guard !ProcessInfo.processInfo.isRunningTests else { return }

        let clipboard = ClipboardStateViewModel()
        let music = MusicManager()
        let companion = CompanionManager(music: music, system: systemMonitor)
        let notchViewModel = PNotchViewModel(screen: .preferredNotchScreen)

        clipboard.onItemCaptured = { [weak self] item in
            self?.companion?.noteCopy()
            self?.showCaptureSneakPeek(for: item)
        }
        clipboard.onItemCopied = { [weak notchViewModel] _ in
            notchViewModel?.closeAfterCopy()
        }
        clipboard.onItemPasted = { [weak notchViewModel] _ in
            notchViewModel?.dismissForPaste()
            PasteService.pasteIntoFrontmostApp()
        }
        notchViewModel.listItemCount = { [weak clipboard] in
            clipboard?.visibleItems.count ?? 0
        }
        // A permission request waiting in the notch: opening it goes straight to the answer.
        notchViewModel.urgentPage = { [claudeCode] in
            !claudeCode.approvals.isEmpty && NotchTabsConfiguration.current.isVisible(.claudeCode) ? .claudeCode : nil
        }
        coordinator.onShowSettings = { [weak self] in
            self?.showSettings()
        }
        claudeCode.onTransition = { [weak self] session, transition in
            self?.handleClaudeCode(session, transition)
        }
        focus.onEvent = { [weak self] event in
            self?.handleFocus(event)
        }

        self.clipboard = clipboard
        self.music = music
        self.companion = companion
        self.notchViewModel = notchViewModel
        notchWindowController = NotchWindowController(
            viewModel: notchViewModel,
            coordinator: coordinator,
            clipboard: clipboard,
            music: music,
            system: systemMonitor,
            companion: companion,
            claudeCode: claudeCode,
            focus: focus
        )

        // Key down rather than up: holding the shortcut keeps scrolling through the list.
        KeyboardShortcuts.onKeyDown(for: .clipboardList) { [weak self] in
            self?.handleClipboardListShortcut()
        }
        observeScreenParameters()
        clipboard.start()
        music.start()
        claudeCode.start()
        focus.start()

        if !LaunchContext.wasLaunchedAtLogin {
            notchViewModel.open(reason: .launch)
        }
    }

    func applicationWillTerminate(_: Notification) {
        clipboard?.flushPendingChanges()
        music?.stop()
        claudeCode.stop()
        focus.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    /// Opens the searchable list, focused and ready to type in.
    func showClipboardList() {
        guard let notchViewModel, let clipboard else { return }
        clipboard.filter = .all
        notchViewModel.open(reason: .keyboard, page: .clipboard)
    }

    /// First press opens the list, the following ones move down through it, like ⌘Tab.
    private func handleClipboardListShortcut() {
        guard let notchViewModel, let clipboard else { return }
        if notchViewModel.isShowingClipboard {
            clipboard.moveSelection(by: 1, wrapping: true)
        } else {
            showClipboardList()
        }
    }

    func showSettings() {
        guard let clipboard else { return }
        notchViewModel?.close(reason: .settings)

        let controller = settingsWindowController
            ?? SettingsWindowController(clipboard: clipboard, updates: updates, claudeCode: claudeCode)
        settingsWindowController = controller
        controller.present()
    }

    private func showCaptureSneakPeek(for item: ClipboardItem) {
        guard Defaults[.showCopySneakPeek], notchViewModel?.notchState == .closed else { return }
        coordinator.showSneakPeek(SneakPeek(item: item))
    }

    /// The robot brings the news; a sneak peek tells a finished turn, unless it was a quick one in plain sight.
    /// Waiting for the user needs no sneak peek: the closed notch keeps showing it until answered.
    private func handleClaudeCode(_ session: ClaudeCodeSession, _ transition: ClaudeCodeSession.Transition) {
        switch transition {
        case .startedWaiting:
            companion?.bring(.claudeCodeNeedsYou)
        case let .finished(turnDuration):
            guard ClaudeCodeAttention.announcesFinish(turnDuration: turnDuration, hostIsFrontmost: claudeCode.isFrontmost(session)) else {
                return
            }
            companion?.bring(.claudeCodeFinished)
            showClaudeCodeSneakPeek(.finished)
        case .failed:
            showClaudeCodeSneakPeek(.failed)
        }
    }

    /// The robot cheers a completed session, a chime rings, and the closed notch shows it.
    private func handleFocus(_ event: FocusTimer.Event) {
        companion?.bring(event == .focusFinished ? .focusDone : .breakOver)
        if Defaults[.focusPlaysSound] {
            NSSound(named: event == .focusFinished ? "Glass" : "Hero")?.play()
        }
        if notchViewModel?.notchState == .closed {
            coordinator.showSneakPeek(SneakPeek(focus: event), duration: .seconds(3))
        }
    }

    private func showClaudeCodeSneakPeek(_ outcome: SneakPeek.ClaudeCodeOutcome) {
        guard Defaults[.announceClaudeCode], notchViewModel?.notchState == .closed else { return }
        coordinator.showSneakPeek(SneakPeek(claudeCode: outcome), duration: .seconds(3))
    }

    private func observeScreenParameters() {
        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.notchWindowController?.updateScreen(.preferredNotchScreen)
            }
        }
    }
}
