//
//  ClaudeCodePresentation.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

extension ClaudeCodeTool {
    /// What Claude is doing with the tool, e.g. "Running npm test".
    var activity: String {
        guard let detail else {
            return switch name {
            case "TodoWrite": String(localized: "Updating its to-do list")
            case "Task", "Agent": String(localized: "Running an agent")
            default: String(localized: "Using \(displayName)")
            }
        }
        return switch name {
        case "Bash": String(localized: "Running \(detail)")
        case "Read": String(localized: "Reading \(detail)")
        case "Edit", "MultiEdit", "NotebookEdit": String(localized: "Editing \(detail)")
        case "Write": String(localized: "Writing \(detail)")
        case "Grep", "Glob": String(localized: "Searching for “\(detail)”")
        case "WebFetch": String(localized: "Reading \(detail)")
        case "WebSearch": String(localized: "Searching the web for “\(detail)”")
        case "Task", "Agent": String(localized: "Running an agent: \(detail)")
        default: String(localized: "Using \(displayName): \(detail)")
        }
    }

    /// What Claude asks to be allowed, e.g. "Wants to run npm install".
    var request: String {
        guard let detail else {
            return String(localized: "Wants to use \(displayName)")
        }
        return switch name {
        case "Bash": String(localized: "Wants to run \(detail)")
        case "Read": String(localized: "Wants to read \(detail)")
        case "Edit", "MultiEdit", "NotebookEdit": String(localized: "Wants to edit \(detail)")
        case "Write": String(localized: "Wants to write \(detail)")
        case "WebFetch": String(localized: "Wants to open \(detail)")
        default: String(localized: "Wants to use \(displayName): \(detail)")
        }
    }

    var symbolName: String {
        switch name {
        case "Bash": "terminal"
        case "Read": "doc.text"
        case "Edit", "MultiEdit", "Write", "NotebookEdit": "pencil"
        case "Grep", "Glob": "magnifyingglass"
        case "WebFetch", "WebSearch": "globe"
        case "Task", "Agent": "person.2"
        case "TodoWrite": "checklist"
        default: "wrench.and.screwdriver"
        }
    }

    /// MCP tools are named `mcp__server__tool`: shown as "server tool".
    private var displayName: String {
        guard name.hasPrefix("mcp__") else { return name }
        return name.dropFirst(5).split(separator: "_", omittingEmptySubsequences: true).joined(separator: " ")
    }
}

extension ClaudeCodeSession {
    /// One line on what the session is up to.
    var statusLine: String {
        switch status {
        case .idle:
            return String(localized: "Waiting for your next prompt")
        case .working:
            return tool?.activity ?? String(localized: "Thinking…")
        case let .waiting(.permission(tool)):
            return tool?.request ?? String(localized: "Asks for your permission")
        case let .waiting(.question(question)):
            return question ?? String(localized: "Has a question for you")
        case .waiting(.planApproval):
            return String(localized: "Has a plan for you to review")
        case .finished:
            return lastMessage ?? String(localized: "Finished")
        case let .failed(error):
            return Self.describe(error: error)
        }
    }

    var statusSymbol: String {
        switch status {
        case .idle: "text.cursor"
        case .working: tool?.symbolName ?? "ellipsis"
        case .waiting: "hand.raised.fill"
        case .finished: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    var statusTint: Color {
        switch status {
        case .idle: .white.opacity(0.45)
        case .working: .white.opacity(0.7)
        case .waiting: ClaudeCodeSpinner.tint
        case .finished: .green
        case .failed: .yellow
        }
    }

    /// The `error` codes of Claude Code's StopFailure hook.
    static func describe(error: String) -> String {
        switch error {
        case "rate_limit": String(localized: "Stopped: usage limit reached")
        case "overloaded", "server_error": String(localized: "Stopped: Claude is unavailable right now")
        case "authentication_failed", "oauth_org_not_allowed": String(localized: "Stopped: sign in to Claude Code again")
        case "billing_error", "account_on_hold": String(localized: "Stopped: check your Claude account")
        case "max_output_tokens": String(localized: "Stopped: the answer was too long")
        default: String(localized: "Stopped by an error")
        }
    }
}
