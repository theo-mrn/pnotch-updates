//
//  ClaudeCodeHookInstaller.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation

/// The hooks PNotch adds to Claude Code's user settings, and how to add or take them out
/// without touching anything else in the file.
nonisolated enum ClaudeCodeHooks {
    /// Every event the notch follows.
    static let events = [
        "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure",
        "PermissionRequest", "Notification", "Stop", "StopFailure", "SessionEnd",
    ]

    static let scriptName = "pnotch.sh"
    /// Hooks wait this long at most. Permission requests can wait for an answer in the notch up to it.
    static let permissionTimeout = 600

    static func isPNotchCommand(_ command: String) -> Bool {
        command.contains("/hooks/\(scriptName)")
    }

    /// Hooks run in the background (`async`), so Claude Code never waits for PNotch, except:
    /// - permission requests, which wait for an answer given in the notch;
    /// - the end of a session: Claude Code may quit before a background hook gets to run.
    static func handler(command: String, for event: String) -> JSONValue {
        var members = [JSONValue.Member(key: "type", value: .string("command"))]
        switch event {
        case "PermissionRequest":
            members.append(JSONValue.Member(key: "command", value: .string(command + " permission")))
            members.append(JSONValue.Member(key: "timeout", value: .number(String(permissionTimeout))))
        case "SessionEnd":
            members.append(JSONValue.Member(key: "command", value: .string(command)))
        default:
            members.append(JSONValue.Member(key: "command", value: .string(command)))
            members.append(JSONValue.Member(key: "async", value: .bool(true)))
        }
        return .object(members)
    }

    /// `settings` with one PNotch handler per event, added after the user's own hooks.
    /// `nil` when the settings aren't shaped as expected, rather than guessing.
    static func installing(command: String, in settings: JSONValue) -> JSONValue? {
        var settings = removing(from: settings)
        guard case .object = settings else { return nil }
        var hooks = settings["hooks"] ?? .object([])
        guard case .object = hooks else { return nil }

        for event in events {
            let groups: [JSONValue]
            switch hooks[event] {
            case nil: groups = []
            case let .array(existing)?: groups = existing
            default: return nil
            }
            let group = JSONValue.object([
                JSONValue.Member(key: "hooks", value: .array([handler(command: command, for: event)])),
            ])
            hooks.set(event, to: .array(groups + [group]))
        }
        settings.set("hooks", to: hooks)
        return settings
    }

    /// `settings` without PNotch's handlers. Matcher groups and events left empty by the removal go too;
    /// the user's own, even empty ones, stay as they are.
    static func removing(from settings: JSONValue) -> JSONValue {
        guard case let .object(events) = settings["hooks"] else { return settings }

        var remainingEvents: [JSONValue.Member] = []
        for event in events {
            guard case let .array(groups) = event.value else {
                remainingEvents.append(event)
                continue
            }
            var remainingGroups: [JSONValue] = []
            var removedAny = false
            for group in groups {
                guard var handlers = group["hooks"]?.arrayValue else {
                    remainingGroups.append(group)
                    continue
                }
                let count = handlers.count
                handlers.removeAll { $0["command"]?.stringValue.map(isPNotchCommand) == true }
                if handlers.count == count {
                    remainingGroups.append(group)
                } else {
                    removedAny = true
                    if !handlers.isEmpty {
                        var group = group
                        group.set("hooks", to: .array(handlers))
                        remainingGroups.append(group)
                    }
                }
            }
            if !remainingGroups.isEmpty || !removedAny {
                remainingEvents.append(JSONValue.Member(key: event.key, value: .array(remainingGroups)))
            }
        }

        var settings = settings
        settings.set("hooks", to: remainingEvents.isEmpty && !events.isEmpty ? nil : .object(remainingEvents))
        return settings
    }

    /// Every event has this version's handler, exactly.
    static func isInstalled(command: String, in settings: JSONValue) -> Bool {
        events.allSatisfy { event in
            let handler = handler(command: command, for: event)
            return settings["hooks"]?[event]?.arrayValue?.contains { group in
                group["hooks"]?.arrayValue?.contains(handler) == true
            } == true
        }
    }

    /// Some PNotch handler is there, maybe from an older version.
    static func hasPNotchHandler(in settings: JSONValue) -> Bool {
        guard case let .object(events) = settings["hooks"] else { return false }
        return events.contains { event in
            event.value.arrayValue?.contains { group in
                group["hooks"]?.arrayValue?.contains { $0["command"]?.stringValue.map(isPNotchCommand) == true } == true
            } == true
        }
    }

    /// The hook itself: hands the event Claude Code writes on its input to PNotch, through a socket
    /// only the user can open. The app it runs in comes along, so a click can bring it back.
    /// For a permission request it waits for the answer given in the notch and prints it for Claude Code.
    static func script(socketPath: String) -> String {
        """
        #!/bin/sh
        # PNotch: shows what Claude Code is doing in the MacBook notch, and lets you answer its permission requests there.
        # Claude Code runs this hook for each event, the event as JSON on its input. It goes to PNotch through
        # a socket only your user can open, and nowhere else. For a permission request ("permission"), it waits
        # for your answer in the notch and prints it for Claude Code; without one, Claude Code asks as usual.
        # Does nothing while PNotch isn't running. Added and removed in PNotch › Settings › Claude Code.
        socket=\(shellQuoted(socketPath))
        [ -S "$socket" ] || exit 0
        if [ "$1" = "permission" ]; then
            curl --silent --max-time \(permissionTimeout - 10) --unix-socket "$socket" \\
                --header 'Content-Type: application/json' --header 'Expect:' \\
                --header "X-PNotch-Host-App: ${__CFBundleIdentifier:-}" \\
                --data-binary @- http://localhost\(ClaudeCodeHookServer.permissionPath) 2> /dev/null
            exit 0
        fi
        curl --silent --max-time 2 --unix-socket "$socket" \\
            --header 'Content-Type: application/json' --header 'Expect:' \\
            --header "X-PNotch-Host-App: ${__CFBundleIdentifier:-}" \\
            --data-binary @- http://localhost\(ClaudeCodeHookServer.eventsPath) > /dev/null 2>&1
        exit 0

        """
    }

    static func shellQuoted(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }
}

// MARK: - Installer

/// Adds PNotch's hook to Claude Code's user settings (`~/.claude/settings.json`) or takes it out.
nonisolated struct ClaudeCodeHookInstaller: Sendable {
    enum InstallError: LocalizedError {
        /// PNotch won't rewrite a settings file it can't fully read.
        case unreadableSettings

        var errorDescription: String? {
            String(localized: "~/.claude/settings.json isn't valid JSON. Fix it, then try again.")
        }
    }

    let claudeDirectory: URL
    let socketURL: URL

    static let standard = ClaudeCodeHookInstaller(
        claudeDirectory: URL.homeDirectory.appending(path: ".claude", directoryHint: .isDirectory),
        socketURL: ClaudeCodeHookServer.defaultSocketURL
    )

    var settingsURL: URL {
        claudeDirectory.appending(path: "settings.json")
    }

    var scriptURL: URL {
        claudeDirectory.appending(path: "hooks", directoryHint: .isDirectory).appending(path: ClaudeCodeHooks.scriptName)
    }

    var command: String {
        ClaudeCodeHooks.shellQuoted(scriptURL.path(percentEncoded: false))
    }

    var isInstalled: Bool {
        guard FileManager.default.isExecutableFile(atPath: scriptURL.path(percentEncoded: false)),
              let settings = try? readSettings()?.value else { return false }
        return ClaudeCodeHooks.isInstalled(command: command, in: settings)
    }

    func install() throws {
        // Settings first: nothing is written if they can't be read.
        let current = try readSettings()
        guard let updated = ClaudeCodeHooks.installing(command: command, in: current?.value ?? .object([])) else {
            throw InstallError.unreadableSettings
        }
        try writeScript()
        try writeSettings(updated, replacing: current)
    }

    func uninstall() throws {
        if let current = try readSettings() {
            let updated = ClaudeCodeHooks.removing(from: current.value)
            if updated != current.value {
                try writeSettings(updated, replacing: current)
            }
        }
        if FileManager.default.fileExists(atPath: scriptURL.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: scriptURL)
        }
    }

    /// Brings a connection made by an older version of PNotch up to date: its script, and its hooks
    /// in the settings (rewritten with a backup, as when connecting). Does nothing when not connected.
    func updateIfConnected() throws {
        guard let settings = try readSettings()?.value, ClaudeCodeHooks.hasPNotchHandler(in: settings) else { return }
        if !ClaudeCodeHooks.isInstalled(command: command, in: settings) {
            try install()
            return
        }
        let script = ClaudeCodeHooks.script(socketPath: socketURL.path(percentEncoded: false))
        if (try? String(contentsOf: scriptURL, encoding: .utf8)) != script {
            try writeScript()
        }
    }

    // MARK: Files

    private struct Settings {
        let value: JSONValue
        let text: String
    }

    /// `nil` when Claude Code has no user settings yet.
    private func readSettings() throws -> Settings? {
        guard let data = try? Data(contentsOf: settingsURL) else { return nil }
        let text = String(decoding: data, as: UTF8.self)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Settings(value: .object([]), text: text)
        }
        guard let value = try? JSONValue(parsing: data) else { throw InstallError.unreadableSettings }
        return Settings(value: value, text: text)
    }

    private func writeSettings(_ settings: JSONValue, replacing current: Settings?) throws {
        // Dotfile managers often link settings.json: write through the link, not over it.
        let destination = settingsURL.resolvingSymlinksInPath()
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

        if let current {
            let backup = destination.appendingPathExtension("pnotch-backup")
            try Data(current.text.utf8).write(to: backup, options: .atomic)
        }
        let endsWithNewline = current.map { $0.text.hasSuffix("\n") } ?? true
        let text = settings.formatted() + (endsWithNewline ? "\n" : "")
        try Data(text.utf8).write(to: destination, options: .atomic)
    }

    private func writeScript() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: scriptURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let script = ClaudeCodeHooks.script(socketPath: socketURL.path(percentEncoded: false))
        try Data(script.utf8).write(to: scriptURL, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path(percentEncoded: false))
    }
}
