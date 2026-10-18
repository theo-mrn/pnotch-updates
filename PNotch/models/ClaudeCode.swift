//
//  ClaudeCode.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation

// MARK: - Event

/// Something Claude Code reported through one of its hooks.
/// See https://code.claude.com/docs/en/hooks for the payloads.
nonisolated struct ClaudeCodeEvent: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case sessionStarted
        case promptSubmitted(String)
        case toolStarted(ClaudeCodeTool)
        /// The tool ran, successfully or not.
        case toolFinished(ClaudeCodeTool)
        /// Claude Code is about to ask the user to allow a tool.
        case permissionRequested(ClaudeCodeTool)
        /// The permission prompt has been waiting for a few seconds.
        case permissionPromptWaiting
        /// A form or a question waits for the user.
        case questionAsked(String?)
        case stopped(lastMessage: String?)
        /// The turn ended on an API error, e.g. `rate_limit`.
        case failed(String)
        case sessionEnded
    }

    let sessionID: String
    let kind: Kind
    var cwd: String?
    var transcriptPath: String?

    /// Reads a hook's JSON input. `nil` for events PNotch doesn't follow.
    init?(payload: JSONValue) {
        guard let sessionID = payload["session_id"]?.stringValue, !sessionID.isEmpty,
              let eventName = payload["hook_event_name"]?.stringValue else { return nil }

        let tool = ClaudeCodeTool(name: payload["tool_name"]?.stringValue ?? "", input: payload["tool_input"])
        switch eventName {
        case "SessionStart":
            kind = .sessionStarted
        case "UserPromptSubmit":
            kind = .promptSubmitted(ClaudeCodeText.summary(of: payload["prompt"]?.stringValue ?? ""))
        case "PreToolUse":
            kind = .toolStarted(tool)
        case "PostToolUse", "PostToolUseFailure":
            kind = .toolFinished(tool)
        case "PermissionRequest":
            kind = .permissionRequested(tool)
        case "Notification":
            switch payload["notification_type"]?.stringValue {
            case "permission_prompt":
                kind = .permissionPromptWaiting
            case "elicitation_dialog":
                kind = .questionAsked(payload["message"]?.stringValue.map { ClaudeCodeText.summary(of: $0) })
            default:
                return nil
            }
        case "Stop":
            kind = .stopped(lastMessage: payload["last_assistant_message"]?.stringValue.map { ClaudeCodeText.summary(of: $0) })
        case "StopFailure":
            kind = .failed(payload["error"]?.stringValue ?? "unknown")
        case "SessionEnd":
            kind = .sessionEnded
        default:
            return nil
        }

        self.sessionID = sessionID
        cwd = payload["cwd"]?.stringValue
        transcriptPath = payload["transcript_path"]?.stringValue
    }

    init(sessionID: String, kind: Kind, cwd: String? = nil, transcriptPath: String? = nil) {
        self.sessionID = sessionID
        self.kind = kind
        self.cwd = cwd
        self.transcriptPath = transcriptPath
    }
}

// MARK: - Tool

/// A tool call, reduced to what fits on a line: the tool and the gist of its input.
nonisolated struct ClaudeCodeTool: Equatable, Sendable {
    let name: String
    /// The command, the file, the pattern, the address…
    let detail: String?

    init(name: String, detail: String?) {
        self.name = name
        self.detail = detail
    }

    init(name: String, input: JSONValue?) {
        self.name = name
        let string = { (key: String) in input?[key]?.stringValue }
        let fileName = { (key: String) in string(key).map { URL(fileURLWithPath: $0).lastPathComponent } }

        let detail: String? = switch name {
        case "Bash": string("command")
        case "Read", "Edit", "MultiEdit", "Write": fileName("file_path")
        case "NotebookEdit": fileName("notebook_path")
        case "Grep", "Glob": string("pattern")
        case "WebFetch": string("url").map { URL(string: $0)?.host() ?? $0 }
        case "WebSearch": string("query")
        case "AskUserQuestion": input?["questions"]?.arrayValue?.first?["question"]?.stringValue
        default: string("description")
        }
        self.detail = detail
            .map { ClaudeCodeText.summary(of: $0, stripsMarkdown: false) }
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    /// Asking the user a question, or to approve a plan, blocks the turn like a permission prompt.
    var waitsForUser: ClaudeCodeRequest? {
        switch name {
        case "AskUserQuestion": .question(detail)
        case "ExitPlanMode": .planApproval
        default: nil
        }
    }
}

/// What a session waits for from the user.
nonisolated enum ClaudeCodeRequest: Equatable, Sendable {
    /// Allowing a tool. `nil` when only the notification told us, without the tool.
    case permission(ClaudeCodeTool?)
    case question(String?)
    case planApproval
}

// MARK: - Session

/// One Claude Code session, as followed through its hooks.
nonisolated struct ClaudeCodeSession: Identifiable, Equatable, Sendable {
    enum Status: Equatable, Sendable {
        /// Open, waiting for a prompt.
        case idle
        case working
        /// Blocked until the user answers in Claude Code.
        case waiting(ClaudeCodeRequest)
        case finished
        /// The turn ended on an API error.
        case failed(String)
    }

    /// What changed that the user may want to hear about.
    enum Transition: Equatable, Sendable {
        case startedWaiting
        case finished(turnDuration: TimeInterval)
        case failed
    }

    let id: String
    var projectPath: String?
    var transcriptPath: String?
    var status: Status = .idle
    /// The last prompt, on one line.
    var prompt: String?
    /// The tool running right now.
    var tool: ClaudeCodeTool?
    /// The beginning of Claude's last answer.
    var lastMessage: String?
    var turnStartedAt: Date?
    var updatedAt: Date
    /// The app Claude Code runs in: a terminal or an editor.
    var hostBundleIdentifier: String?
    /// Claude Code's process, to notice when it quits without saying so.
    var processIdentifier: pid_t?

    init(id: String, updatedAt: Date) {
        self.id = id
        self.updatedAt = updatedAt
    }

    var projectName: String {
        guard let projectPath, !projectPath.isEmpty else { return "Claude Code" }
        return URL(fileURLWithPath: projectPath).lastPathComponent
    }

    var isWorking: Bool {
        status == .working
    }

    var needsAttention: Bool {
        if case .waiting = status {
            return true
        }
        return false
    }

    /// Advances the session with an event received at `date`.
    mutating func apply(_ event: ClaudeCodeEvent, at date: Date) -> Transition? {
        let wasWaiting = needsAttention
        if let cwd = event.cwd {
            projectPath = cwd
        }
        if let path = event.transcriptPath {
            transcriptPath = path
        }
        updatedAt = date

        switch event.kind {
        case .sessionStarted:
            // Also sent after /clear and when resuming: the session is ready for a prompt.
            status = .idle
            tool = nil
            return nil

        case let .promptSubmitted(prompt):
            self.prompt = prompt
            status = .working
            tool = nil
            lastMessage = nil
            turnStartedAt = date
            return nil

        case let .toolStarted(tool):
            if turnStartedAt == nil {
                turnStartedAt = date
            }
            if let request = tool.waitsForUser {
                status = .waiting(request)
                self.tool = nil
                return wasWaiting ? nil : .startedWaiting
            }
            // A new call means the pending request was answered.
            status = .working
            self.tool = tool
            return nil

        case let .toolFinished(tool):
            // Parallel read-only calls keep finishing while a permission prompt is up:
            // only the call that was waiting ends the wait.
            if case let .waiting(request) = status, !Self.request(request, isAnsweredBy: tool) {
                return nil
            }
            status = .working
            self.tool = nil
            return nil

        case let .permissionRequested(tool):
            status = .waiting(.permission(tool))
            self.tool = nil
            return wasWaiting ? nil : .startedWaiting

        case .permissionPromptWaiting:
            guard !wasWaiting else { return nil }
            status = .waiting(.permission(tool))
            tool = nil
            return .startedWaiting

        case let .questionAsked(message):
            status = .waiting(.question(message))
            return wasWaiting ? nil : .startedWaiting

        case let .stopped(lastMessage):
            let duration = turnStartedAt.map { date.timeIntervalSince($0) } ?? 0
            status = .finished
            tool = nil
            self.lastMessage = lastMessage
            return .finished(turnDuration: duration)

        case let .failed(error):
            status = .failed(error)
            tool = nil
            return .failed

        case .sessionEnded:
            return nil
        }
    }

    /// The user interrupted the turn (esc): Claude Code doesn't run a hook for that.
    mutating func markInterrupted(at date: Date) {
        status = .idle
        tool = nil
        updatedAt = date
    }

    private static func request(_ request: ClaudeCodeRequest, isAnsweredBy finished: ClaudeCodeTool) -> Bool {
        switch request {
        case let .permission(tool):
            tool.map { $0.name == finished.name } ?? true
        case .question:
            finished.name == "AskUserQuestion"
        case .planApproval:
            finished.name == "ExitPlanMode"
        }
    }
}

// MARK: - Approvals

/// A permission request held open for an answer from the notch.
nonisolated struct ClaudeCodeApproval: Equatable, Sendable {
    let replyID: ClaudeCodeHookServer.ReplyID
    let sessionID: String
    let tool: ClaudeCodeTool
    /// The rule Claude Code suggests to stop asking, e.g. allowing this command in this project.
    let alwaysAllowRule: JSONValue?

    /// Reads a PermissionRequest hook's input.
    init?(payload: JSONValue, replyID: ClaudeCodeHookServer.ReplyID) {
        guard payload["hook_event_name"]?.stringValue == "PermissionRequest",
              let sessionID = payload["session_id"]?.stringValue else { return nil }
        self.replyID = replyID
        self.sessionID = sessionID
        tool = ClaudeCodeTool(name: payload["tool_name"]?.stringValue ?? "", input: payload["tool_input"])
        alwaysAllowRule = payload["permission_suggestions"]?.arrayValue?.first { $0["behavior"]?.stringValue == "allow" }
    }
}

/// The answer given in the notch, as the PermissionRequest hook hands it to Claude Code.
nonisolated enum ClaudeCodeDecision: Equatable, Sendable {
    case allow
    /// Allows, and adds Claude Code's suggested rule so it stops asking.
    case allowAlways(rule: JSONValue)
    case deny

    var hookOutput: JSONValue {
        var decision: [JSONValue.Member]
        switch self {
        case .allow:
            decision = [JSONValue.Member(key: "behavior", value: .string("allow"))]
        case let .allowAlways(rule):
            decision = [
                JSONValue.Member(key: "behavior", value: .string("allow")),
                JSONValue.Member(key: "updatedPermissions", value: .array([rule])),
            ]
        case .deny:
            decision = [
                JSONValue.Member(key: "behavior", value: .string("deny")),
                JSONValue.Member(key: "message", value: .string("The user declined this from PNotch, in the MacBook notch.")),
            ]
        }
        return .object([
            JSONValue.Member(key: "hookSpecificOutput", value: .object([
                JSONValue.Member(key: "hookEventName", value: .string("PermissionRequest")),
                JSONValue.Member(key: "decision", value: .object(decision)),
            ])),
        ])
    }
}

// MARK: - Attention

nonisolated enum ClaudeCodeAttention {
    /// Short answers in the app you're looking at don't need a sneak peek; long ones, or ones elsewhere, do.
    static let quickTurn: TimeInterval = 20

    static func announcesFinish(turnDuration: TimeInterval, hostIsFrontmost: Bool) -> Bool {
        !hostIsFrontmost || turnDuration >= quickTurn
    }

    /// A permission request waits for the notch only while you're away from the session's terminal or editor:
    /// there, Claude Code asks right away.
    static func holdsPermission(answersInNotch: Bool, hostIsFrontmost: Bool) -> Bool {
        answersInNotch && !hostIsFrontmost
    }
}

// MARK: - Transcript

/// Reads the end of a session's transcript, Claude Code's JSONL log of the conversation.
nonisolated enum ClaudeCodeTranscript {
    static let interruptionMarker = "[Request interrupted by user"

    /// Whether the conversation's last message is the marker Claude Code writes when the user presses esc.
    /// Bookkeeping lines (snapshots, queue operations…) after it are skipped; the first, partial line is ignored.
    static func endsWithInterruption(_ tail: String) -> Bool {
        for line in tail.split(separator: "\n").reversed() {
            guard let entry = try? JSONValue(parsing: String(line)),
                  let type = entry["type"]?.stringValue, type == "user" || type == "assistant" else { continue }
            guard type == "user", let content = entry["message"]?["content"] else { return false }
            if let text = content.stringValue {
                return text.contains(interruptionMarker)
            }
            return content.arrayValue?.contains { $0["text"]?.stringValue?.contains(interruptionMarker) == true } ?? false
        }
        return false
    }

    static func tail(of url: URL, maxLength: Int = 64 * 1024) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return nil }
        try? handle.seek(toOffset: size > UInt64(maxLength) ? size - UInt64(maxLength) : 0)
        guard let data = try? handle.readToEnd() else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}

// MARK: - Text

nonisolated enum ClaudeCodeText {
    static let maximumLength = 200

    /// The first meaningful line, short enough for a row.
    /// - Parameter stripsMarkdown: Drops headings, list markers, bold and code marks: for Claude's prose,
    ///   not for commands.
    static func summary(of text: String, stripsMarkdown: Bool = true) -> String {
        let markers = CharacterSet(charactersIn: stripsMarkdown ? "#>*- " : " ")
        var line = text
            .split(whereSeparator: \.isNewline)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: markers) }
            .first { !$0.isEmpty } ?? ""
        if stripsMarkdown {
            line = line.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
        }
        let collapsed = line.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard collapsed.count > maximumLength else { return collapsed }
        return String(collapsed.prefix(maximumLength - 1)) + "…"
    }
}
