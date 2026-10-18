//
//  SettingsView.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Defaults
import KeyboardShortcuts
import os
import ServiceManagement
import SwiftUI

/// Settings window: a sidebar of panes, like System Settings.
struct SettingsView: View {
    @State private var selection: SettingsPane = .general

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(SettingsPane.allCases) { pane in
                    Label {
                        Text(pane.title)
                    } icon: {
                        SettingsPaneIcon(pane: pane)
                    }
                    .tag(pane)
                }
            }
            .listStyle(.sidebar)
            .frame(width: 200)

            Divider()

            Group {
                switch selection {
                case .general: GeneralPane()
                case .tabs: TabsPane()
                case .clipboard: ClipboardPane()
                case .music: MusicPane()
                case .companion: CompanionPane()
                case .claudeCode: ClaudeCodePane()
                case .shortcuts: ShortcutsPane()
                case .about: AboutPane()
                }
            }
            .formStyle(.grouped)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 720, height: 520)
    }
}

// MARK: - Panes

enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case tabs
    case clipboard
    case music
    case companion
    case claudeCode
    case shortcuts
    case about

    var id: Self {
        self
    }

    var title: LocalizedStringKey {
        switch self {
        case .general: "General"
        case .tabs: "Tabs"
        case .clipboard: "Clipboard"
        case .music: "Music"
        case .companion: "Companion"
        case .claudeCode: "Claude Code"
        case .shortcuts: "Shortcuts"
        case .about: "About"
        }
    }

    fileprivate var symbolName: String {
        switch self {
        case .general: "gearshape.fill"
        case .tabs: "rectangle.topthird.inset.filled"
        case .clipboard: "doc.on.clipboard.fill"
        case .music: "music.note"
        case .companion: "face.smiling.inverse"
        case .claudeCode: "terminal.fill"
        case .shortcuts: "command"
        case .about: "info.circle.fill"
        }
    }

    fileprivate var tint: Color {
        switch self {
        case .general: .gray
        case .tabs: .indigo
        case .clipboard: .blue
        case .music: .pink
        case .companion: .mint
        case .claudeCode: ClaudeCodeSpinner.tint
        case .shortcuts: .orange
        case .about: .teal
        }
    }
}

/// Colored rounded tile behind the pane symbol, as in System Settings.
private struct SettingsPaneIcon: View {
    let pane: SettingsPane

    var body: some View {
        Image(systemName: pane.symbolName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(pane.tint.gradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - General

private struct GeneralPane: View {
    @Environment(UpdateManager.self) private var updates
    @Default(.menubarIcon) private var menubarIcon
    @Default(.openNotchOnHover) private var openNotchOnHover
    @Default(.enableHaptics) private var enableHaptics
    @State private var checksAutomatically = false

    var body: some View {
        Form {
            Section {
                LaunchAtLoginToggle()
                Toggle("Show menu bar icon", isOn: $menubarIcon)
                Toggle("Open the notch on hover", isOn: $openNotchOnHover)
                Toggle("Haptic feedback", isOn: $enableHaptics)
            }

            Section {
                if updates.isAvailable {
                    Toggle("Check for updates automatically", isOn: $checksAutomatically)
                        .onChange(of: checksAutomatically) { _, newValue in
                            updates.automaticallyChecksForUpdates = newValue
                        }
                    Button("Check for Updates Now") {
                        updates.checkForUpdates()
                    }
                } else {
                    LabeledContent("Automatic updates") {
                        Text("Available in published versions")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Updates")
            }
        }
        .onAppear {
            checksAutomatically = updates.automaticallyChecksForUpdates
        }
    }
}

// MARK: - Tabs

private struct TabsPane: View {
    @Default(.tabOrder) private var tabOrder
    @Default(.hiddenTabs) private var hiddenTabs
    @Default(.startPage) private var startPage

    var body: some View {
        let configuration = NotchTabsConfiguration(order: tabOrder, hidden: hiddenTabs)

        Form {
            Section {
                ForEach(Array(configuration.order.enumerated()), id: \.element) { index, page in
                    TabRow(
                        page: page,
                        isVisible: configuration.isVisible(page),
                        canHide: configuration.visiblePages.count > 1,
                        canMoveUp: index > 0,
                        canMoveDown: index < configuration.order.count - 1
                    ) { change in
                        update { change(&$0) }
                    }
                }
            } header: {
                Text("Tabs")
            } footer: {
                Text("The notch shows these pages as tabs, in this order. At least one stays visible.")
            }

            Section {
                Picker("Open the notch on", selection: $startPage) {
                    Text("The last page used").tag(NotchPage?.none)
                    Divider()
                    ForEach(configuration.visiblePages, id: \.self) { page in
                        Text(page.title).tag(NotchPage?.some(page))
                    }
                }
            } footer: {
                Text("The keyboard shortcuts always open the clipboard.")
            }
        }
    }

    private func update(_ change: (inout NotchTabsConfiguration) -> Void) {
        var configuration = NotchTabsConfiguration(order: tabOrder, hidden: hiddenTabs)
        change(&configuration)
        withAnimation(.smooth(duration: 0.2)) {
            tabOrder = configuration.order
            hiddenTabs = configuration.hidden
        }
    }
}

private struct TabRow: View {
    let page: NotchPage
    let isVisible: Bool
    let canHide: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onChange: ((inout NotchTabsConfiguration) -> Void) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: page.symbolName)
                .frame(width: 20)
                .foregroundStyle(isVisible ? .primary : .tertiary)
            Text(page.title)
                .foregroundStyle(isVisible ? .primary : .secondary)

            Spacer()

            Button {
                onChange { $0.move(page, by: -1) }
            } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(!canMoveUp)
            .help("Move up")

            Button {
                onChange { $0.move(page, by: 1) }
            } label: {
                Image(systemName: "chevron.down")
            }
            .disabled(!canMoveDown)
            .help("Move down")

            Toggle("Show", isOn: Binding(
                get: { isVisible },
                set: { visible in onChange { $0.setVisible(page, visible) } }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(isVisible && !canHide)
        }
        .buttonStyle(.borderless)
    }
}

// MARK: - Clipboard

private struct ClipboardPane: View {
    @Environment(ClipboardStateViewModel.self) private var clipboard
    @Default(.pasteDirectly) private var pasteDirectly
    @Default(.clipboardHistoryLimit) private var historyLimit
    @Default(.fetchLinkPreviews) private var fetchLinkPreviews
    @Default(.showCopySneakPeek) private var showCopySneakPeek
    @Default(.closeNotchAfterCopy) private var closeNotchAfterCopy
    @State private var isConfirmingClear = false

    var body: some View {
        Form {
            Section {
                Toggle("Paste directly into the app in use", isOn: $pasteDirectly)
                if pasteDirectly {
                    AccessibilityStatusRow()
                }
            } header: {
                Text("Pasting")
            } footer: {
                Text("Hold ⌥ (Option) while choosing an item to copy it without pasting.")
            }

            Section {
                Picker("Keep", selection: $historyLimit) {
                    ForEach(clipboardHistoryLimitOptions, id: \.self) { limit in
                        Text("\(limit) items").tag(limit)
                    }
                }
                Toggle("Fetch link previews", isOn: $fetchLinkPreviews)
                Toggle("Show a sneak peek when something is copied", isOn: $showCopySneakPeek)
                Toggle("Close the notch after copying", isOn: $closeNotchAfterCopy)
                Button("Clear History…", role: .destructive) {
                    isConfirmingClear = true
                }
                .confirmationDialog("Clear the clipboard history?", isPresented: $isConfirmingClear) {
                    Button("Clear History", role: .destructive) {
                        clipboard.clearHistory()
                    }
                } message: {
                    Text("Pinned items are kept.")
                }
            } header: {
                Text("History")
            } footer: {
                Text("Passwords and other content marked as confidential are never recorded. Pinned items are never removed automatically.")
            }

            Section("In the notch") {
                ShortcutRow(title: "Select", keys: "↑ ↓")
                ShortcutRow(title: pasteDirectly ? "Paste" : "Copy", keys: "↩")
                if pasteDirectly {
                    ShortcutRow(title: "Copy without pasting", keys: "⌥↩")
                }
                ShortcutRow(title: "Use as plain text", keys: "⇧↩")
                ShortcutRow(title: "Search", keys: "⌘F")
                ShortcutRow(title: "Pin / unpin", keys: "⌘P")
                ShortcutRow(title: "Delete", keys: "⌘⌫")
            }
        }
    }
}

/// Whether PNotch may paste, with the way to grant it. Refreshes while shown,
/// so it turns green as soon as access is given in System Settings.
private struct AccessibilityStatusRow: View {
    @State private var isTrusted = PasteService.isTrusted

    var body: some View {
        LabeledContent {
            if !isTrusted {
                Button("Open System Settings") {
                    PasteService.requestPermissionIfNeeded()
                    PasteService.openAccessibilitySettings()
                }
            }
        } label: {
            Label {
                Text(isTrusted ? "Accessibility access granted" : "Needs Accessibility access to paste")
            } icon: {
                Image(systemName: isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(isTrusted ? .green : .orange)
            }
        }
        .task {
            while !Task.isCancelled {
                isTrusted = PasteService.isTrusted
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

// MARK: - Music

private struct MusicPane: View {
    @Default(.showMusicLiveActivity) private var showMusicLiveActivity

    var body: some View {
        Form {
            Section {
                Toggle("Show what's playing around the closed notch", isOn: $showMusicLiveActivity)
            } footer: {
                Text("Works with any app that reports to Now Playing: Music, Spotify, podcasts, video in a browser…")
            }
        }
    }
}

// MARK: - Companion

private struct CompanionPane: View {
    @Default(.companionName) private var name
    @Default(.companionOnEveryPage) private var onEveryPage
    @Default(.companionAnnouncesCopies) private var announces
    @Default(.focusPlaysSound) private var focusPlaysSound

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Show \(name) on every page"), isOn: $onEveryPage)
                Toggle("Announce news around the closed notch", isOn: $announces)
                Toggle("Play a sound when a focus session or a break ends", isOn: $focusPlaysSound)
            } footer: {
                Text("\(name) reacts to what you do everywhere: it dances to your music, catches your copies and tells you when Claude Code is done or needs you. On its page, start a focus session with it. Click it to pet it; its looks are behind the paintbrush.")
            }
        }
    }
}

// MARK: - Claude Code

private struct ClaudeCodePane: View {
    @Environment(ClaudeCodeManager.self) private var claudeCode
    @Default(.showClaudeCodeLiveActivity) private var showLiveActivity
    @Default(.announceClaudeCode) private var announce
    @Default(.claudeCodeAnswersInNotch) private var answersInNotch

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    if claudeCode.isConnected {
                        Button("Disconnect") {
                            claudeCode.disconnect()
                        }
                    } else {
                        Button("Connect") {
                            claudeCode.connect()
                        }
                    }
                } label: {
                    Label {
                        Text(claudeCode.isConnected ? "Connected to Claude Code" : "Not connected")
                    } icon: {
                        Image(systemName: claudeCode.isConnected ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundStyle(claudeCode.isConnected ? .green : .secondary)
                    }
                }
                if let error = claudeCode.connectionError {
                    Text(error)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Connection")
            } footer: {
                Text("PNotch adds a hook to ~/.claude/settings.json (the previous version is kept next to it). Claude Code then tells PNotch what it's doing, through a socket only your account can open: nothing leaves your Mac. Sessions already open pick it up once restarted.")
            }

            Section {
                Toggle("Answer permission requests from the notch", isOn: $answersInNotch)
            } footer: {
                Text("While you're away from the session's terminal or editor, Claude Code waits for your answer in the notch: allow, always allow or deny. Back in the terminal, or with PNotch closed, it asks there as usual.")
            }

            Section {
                Toggle("Show Claude Code's activity around the closed notch", isOn: $showLiveActivity)
                Toggle("Show a sneak peek when Claude Code is done", isOn: $announce)
            } footer: {
                Text("A session waiting for your answer always stays visible until you reply. Quick answers in the app you're using don't get a sneak peek.")
            }
        }
        .onAppear { claudeCode.refreshConnection() }
    }
}

// MARK: - Shortcuts

private struct ShortcutsPane: View {
    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Clipboard", name: .clipboardList)
            } footer: {
                Text("Press the list shortcut again to move to the next item, then ↩ to use it.")
            }
        }
    }
}

// MARK: - About

private struct AboutPane: View {
    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("PNotch")
                            .font(.title2.weight(.semibold))
                        Text("Version \(appVersion)")
                            .foregroundStyle(.secondary)
                        Text("Music, clipboard, system monitor and a robot companion, in the notch.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Acknowledgements") {
                Credit(name: "DynamicNotchKit", detail: "Notch shape · MIT")
                Credit(name: "mediaremote-adapter", detail: "Now Playing · BSD 3-Clause")
                Credit(name: "Defaults, KeyboardShortcuts", detail: "Sindre Sorhus · MIT")
                Credit(name: "Sparkle", detail: "Updates · MIT")
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}

private struct Credit: View {
    let name: String
    let detail: String

    var body: some View {
        LabeledContent(name) {
            Text(detail)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Shared rows

private struct LaunchAtLoginToggle: View {
    @State private var isEnabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle("Launch at login", isOn: Binding(get: { isEnabled }, set: setEnabled))
    }

    private func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Logger.app.error("Failed to update the login item: \(error.localizedDescription)")
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}

private struct ShortcutRow: View {
    let title: LocalizedStringKey
    let keys: String

    var body: some View {
        LabeledContent(title) {
            Text(keys)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}
