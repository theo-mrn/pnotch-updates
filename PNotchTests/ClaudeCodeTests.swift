//
//  ClaudeCodeTests.swift
//  PNotchTests
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation
import Testing
@testable import PNotch

// MARK: - Events

struct ClaudeCodeEventTests {
    private func event(_ json: String) throws -> ClaudeCodeEvent? {
        try ClaudeCodeEvent(payload: JSONValue(parsing: json))
    }

    @Test func readsHookPayloads() throws {
        let common = #""session_id": "s1", "cwd": "/Users/theo/Developer/PNotch", "transcript_path": "/tmp/s1.jsonl""#

        let prompt = try #require(try event(#"{\#(common), "hook_event_name": "UserPromptSubmit", "prompt": "Add a **search** bar\nwith care"}"#))
        #expect(prompt.kind == .promptSubmitted("Add a search bar"))
        #expect(prompt.cwd == "/Users/theo/Developer/PNotch")
        #expect(prompt.transcriptPath == "/tmp/s1.jsonl")

        let bash = try event(#"{\#(common), "hook_event_name": "PreToolUse", "tool_name": "Bash", "tool_input": {"command": "npm test\nnpm run lint", "description": "Run tests"}}"#)
        #expect(bash?.kind == .toolStarted(ClaudeCodeTool(name: "Bash", detail: "npm test")))

        let permission = try event(#"{\#(common), "hook_event_name": "PermissionRequest", "tool_name": "Edit", "tool_input": {"file_path": "/a/b/ContentView.swift"}}"#)
        #expect(permission?.kind == .permissionRequested(ClaudeCodeTool(name: "Edit", detail: "ContentView.swift")))

        let waiting = try event(#"{\#(common), "hook_event_name": "Notification", "notification_type": "permission_prompt", "message": "Claude needs your permission"}"#)
        #expect(waiting?.kind == .permissionPromptWaiting)

        let stop = try event(###"{\###(common), "hook_event_name": "Stop", "last_assistant_message": "## Done\n\nThe tests pass."}"###)
        #expect(stop?.kind == .stopped(lastMessage: "Done"))

        let failure = try event(#"{\#(common), "hook_event_name": "StopFailure", "error": "rate_limit"}"#)
        #expect(failure?.kind == .failed("rate_limit"))

        #expect(try event(#"{\#(common), "hook_event_name": "SessionEnd", "reason": "other"}"#)?.kind == .sessionEnded)
    }

    @Test func ignoresWhatTheNotchDoesNotShow() throws {
        #expect(try event(#"{"session_id": "s1", "hook_event_name": "PreCompact"}"#) == nil)
        #expect(try event(#"{"session_id": "s1", "hook_event_name": "Notification", "notification_type": "idle_prompt"}"#) == nil)
        #expect(try event(#"{"hook_event_name": "Stop"}"#) == nil)
    }

    @Test func summarizesToolInput() throws {
        func tool(_ name: String, _ input: String) throws -> ClaudeCodeTool {
            try ClaudeCodeTool(name: name, input: JSONValue(parsing: input))
        }
        #expect(try tool("WebFetch", #"{"url": "https://code.claude.com/docs/en/hooks"}"#).detail == "code.claude.com")
        #expect(try tool("Grep", #"{"pattern": "TODO"}"#).detail == "TODO")
        #expect(try tool("Task", #"{"description": "Explore the codebase"}"#).detail == "Explore the codebase")
        #expect(try tool("AskUserQuestion", #"{"questions": [{"question": "Which layout?"}]}"#).detail == "Which layout?")
        // Commands are kept as typed, backticks and all.
        #expect(try tool("Bash", #"{"command": "echo `date` **"}"#).detail == "echo `date` **")
        #expect(try tool("Bash", #"{"command": "  "}"#).detail == nil)
    }

    @Test func shortensLongText() {
        let long = String(repeating: "word ", count: 100)
        let summary = ClaudeCodeText.summary(of: long)
        #expect(summary.count == ClaudeCodeText.maximumLength)
        #expect(summary.hasSuffix("…"))
        #expect(ClaudeCodeText.summary(of: "\n\n- **First** `point`\n- second") == "First point")
    }
}

// MARK: - Sessions

struct ClaudeCodeSessionTests {
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let bash = ClaudeCodeTool(name: "Bash", detail: "npm install")
    private let read = ClaudeCodeTool(name: "Read", detail: "Package.swift")

    private func session(after kinds: [ClaudeCodeEvent.Kind]) -> (ClaudeCodeSession, [ClaudeCodeSession.Transition]) {
        var session = ClaudeCodeSession(id: "s1", updatedAt: start)
        var transitions: [ClaudeCodeSession.Transition] = []
        for (index, kind) in kinds.enumerated() {
            let event = ClaudeCodeEvent(sessionID: "s1", kind: kind, cwd: "/Users/theo/Developer/PNotch")
            if let transition = session.apply(event, at: start.addingTimeInterval(Double(index) * 10)) {
                transitions.append(transition)
            }
        }
        return (session, transitions)
    }

    @Test func worksThenFinishes() {
        let (working, _) = session(after: [.sessionStarted, .promptSubmitted("Fix the build"), .toolStarted(bash)])
        #expect(working.status == .working)
        #expect(working.tool == bash)
        #expect(working.prompt == "Fix the build")
        #expect(working.projectName == "PNotch")

        let (finished, transitions) = session(after: [
            .promptSubmitted("Fix the build"), .toolStarted(bash), .toolFinished(bash), .stopped(lastMessage: "Fixed."),
        ])
        #expect(finished.status == .finished)
        #expect(finished.tool == nil)
        #expect(finished.lastMessage == "Fixed.")
        #expect(transitions == [.finished(turnDuration: 30)])
    }

    @Test func waitsForPermissionOnce() {
        let (waiting, transitions) = session(after: [
            .promptSubmitted("Install"), .permissionRequested(bash), .permissionPromptWaiting,
        ])
        #expect(waiting.status == .waiting(.permission(bash)))
        #expect(waiting.needsAttention)
        // The notification that follows the request doesn't announce it twice.
        #expect(transitions == [.startedWaiting])
    }

    @Test func parallelCallsDontEndTheWait() {
        let (stillWaiting, _) = session(after: [
            .promptSubmitted("Install"), .toolStarted(read), .permissionRequested(bash), .toolFinished(read),
        ])
        #expect(stillWaiting.needsAttention)

        let (approved, _) = session(after: [
            .promptSubmitted("Install"), .permissionRequested(bash), .toolFinished(bash),
        ])
        #expect(approved.status == .working)

        // Denied: Claude moves on to something else.
        let (movedOn, _) = session(after: [
            .promptSubmitted("Install"), .permissionRequested(bash), .toolStarted(read),
        ])
        #expect(movedOn.status == .working)
    }

    @Test func questionsAndPlansWaitForTheUser() {
        let question = ClaudeCodeTool(name: "AskUserQuestion", detail: "Which layout?")
        let (asking, transitions) = session(after: [.promptSubmitted("Design it"), .toolStarted(question)])
        #expect(asking.status == .waiting(.question("Which layout?")))
        #expect(transitions == [.startedWaiting])

        let (answered, _) = session(after: [.promptSubmitted("Design it"), .toolStarted(question), .toolFinished(question)])
        #expect(answered.status == .working)

        let plan = ClaudeCodeTool(name: "ExitPlanMode", detail: nil)
        #expect(session(after: [.promptSubmitted("Plan it"), .toolStarted(plan)]).0.status == .waiting(.planApproval))
    }

    @Test func failsAndRestarts() {
        let (failed, transitions) = session(after: [.promptSubmitted("Go"), .failed("rate_limit")])
        #expect(failed.status == .failed("rate_limit"))
        #expect(transitions == [.failed])

        let (cleared, _) = session(after: [.promptSubmitted("Go"), .toolStarted(bash), .sessionStarted])
        #expect(cleared.status == .idle)
        #expect(cleared.tool == nil)
    }

    @Test func announcesLongOrUnseenTurns() {
        #expect(!ClaudeCodeAttention.announcesFinish(turnDuration: 10, hostIsFrontmost: true))
        #expect(ClaudeCodeAttention.announcesFinish(turnDuration: 10, hostIsFrontmost: false))
        #expect(ClaudeCodeAttention.announcesFinish(turnDuration: ClaudeCodeAttention.quickTurn, hostIsFrontmost: true))
    }
}

// MARK: - Transcript

struct ClaudeCodeTranscriptTests {
    private func line(type: String, text: String) -> String {
        #"{"type":"\#(type)","message":{"role":"\#(type)","content":[{"type":"text","text":"\#(text)"}]},"uuid":"x"}"#
    }

    @Test func noticesInterruptions() {
        let interrupted = [
            #"ial line cut by the tail","type":"assistant"}"#,
            line(type: "assistant", text: "Let me run the tests."),
            line(type: "user", text: "[Request interrupted by user for tool use]"),
            #"{"type":"file-history-snapshot","snapshot":{}}"#,
            #"{"type":"queue-operation","operation":"enqueue"}"#,
        ].joined(separator: "\n")
        #expect(ClaudeCodeTranscript.endsWithInterruption(interrupted))

        let plain = #"{"type":"user","message":{"role":"user","content":"[Request interrupted by user]"}}"#
        #expect(ClaudeCodeTranscript.endsWithInterruption(plain))
    }

    @Test func ignoresConversationsStillGoing() {
        let resumed = [
            line(type: "user", text: "[Request interrupted by user]"),
            line(type: "user", text: "Try again"),
        ].joined(separator: "\n")
        #expect(!ClaudeCodeTranscript.endsWithInterruption(resumed))
        #expect(!ClaudeCodeTranscript.endsWithInterruption(line(type: "assistant", text: "[Request interrupted by user]")))
        #expect(!ClaudeCodeTranscript.endsWithInterruption(""))
    }

    @Test func readsTheEndOfLongFiles() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "transcript-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: url) }
        let body = String(repeating: line(type: "assistant", text: "Working") + "\n", count: 2000)
        try (body + line(type: "user", text: "[Request interrupted by user]") + "\n").write(to: url, atomically: true, encoding: .utf8)

        let tail = try #require(ClaudeCodeTranscript.tail(of: url, maxLength: 4096))
        #expect(tail.utf8.count == 4096)
        #expect(ClaudeCodeTranscript.endsWithInterruption(tail))
    }
}

// MARK: - Hooks in the settings

struct ClaudeCodeHooksTests {
    private let command = "'/Users/theo/.claude/hooks/pnotch.sh'"

    private let userSettings = """
    {
      "model": "opus",
      "hooks": {
        "Stop": [
          {
            "hooks": [
              {
                "type": "command",
                "command": "afplay /System/Library/Sounds/Glass.aiff"
              }
            ]
          }
        ],
        "PreCompact": []
      },
      "theme": "dark"
    }
    """

    @Test func addsOneBackgroundHandlerPerEvent() throws {
        let installed = try #require(ClaudeCodeHooks.installing(command: command, in: .object([])))
        #expect(ClaudeCodeHooks.isInstalled(command: command, in: installed))
        for event in ClaudeCodeHooks.events where event != "PermissionRequest" {
            let handler = installed["hooks"]?[event]?.arrayValue?.last?["hooks"]?.arrayValue?.first
            #expect(handler?["command"]?.stringValue == command)
            #expect(handler?["async"]?.boolValue == (event == "SessionEnd" ? nil : true))
        }
        // Permission requests wait for the notch's answer.
        let permission = installed["hooks"]?["PermissionRequest"]?.arrayValue?.last?["hooks"]?.arrayValue?.first
        #expect(permission?["command"]?.stringValue == command + " permission")
        #expect(permission?["async"] == nil)
        #expect(permission?["timeout"] == .number("600"))
    }

    @Test func upgradesAnOlderConnection() throws {
        // Version 1 ran every hook in the background, permission requests included.
        let old = try JSONValue(parsing: """
        {"hooks": {"PermissionRequest": [{"hooks": [{"type": "command", "command": "\(command)", "async": true}]}],
                   "Stop": [{"hooks": [{"type": "command", "command": "\(command)", "async": true}]}]}}
        """)
        #expect(ClaudeCodeHooks.hasPNotchHandler(in: old))
        #expect(!ClaudeCodeHooks.isInstalled(command: command, in: old))

        let upgraded = try #require(ClaudeCodeHooks.installing(command: command, in: old))
        #expect(ClaudeCodeHooks.isInstalled(command: command, in: upgraded))
        // The old handler is replaced, not kept next to the new one.
        #expect(upgraded["hooks"]?["PermissionRequest"]?.arrayValue?.count == 1)
        #expect(!ClaudeCodeHooks.hasPNotchHandler(in: .object([])))
    }

    @Test func leavesTheUsersSettingsAlone() throws {
        let settings = try JSONValue(parsing: userSettings)
        let installed = try #require(ClaudeCodeHooks.installing(command: command, in: settings))

        // The user's Stop hook stays first, PNotch's comes after it.
        let stopGroups = try #require(installed["hooks"]?["Stop"]?.arrayValue)
        #expect(stopGroups.count == 2)
        #expect(stopGroups[0] == settings["hooks"]?["Stop"]?.arrayValue?.first)
        #expect(installed["model"] == .string("opus"))
        #expect(installed["theme"] == .string("dark"))

        // Installing again doesn't duplicate anything.
        #expect(ClaudeCodeHooks.installing(command: command, in: installed) == installed)

        // Removing gives back the file as it was, character for character.
        #expect(ClaudeCodeHooks.removing(from: installed).formatted() == userSettings)
    }

    @Test func removesOnlyPNotchsHandlers() throws {
        let mixed = try JSONValue(parsing: """
        {"hooks": {"Stop": [{"hooks": [
          {"type": "command", "command": "afplay Glass.aiff"},
          {"type": "command", "command": "'/Users/someone/.claude/hooks/pnotch.sh'", "async": true}
        ]}]}}
        """)
        let cleaned = ClaudeCodeHooks.removing(from: mixed)
        #expect(cleaned["hooks"]?["Stop"]?.arrayValue?.first?["hooks"]?.arrayValue?.count == 1)

        let onlyOurs = try #require(ClaudeCodeHooks.installing(command: command, in: .object([])))
        #expect(ClaudeCodeHooks.removing(from: onlyOurs) == .object([]))
    }

    @Test func refusesUnexpectedShapes() throws {
        #expect(ClaudeCodeHooks.installing(command: command, in: try JSONValue(parsing: #"{"hooks": []}"#)) == nil)
        #expect(ClaudeCodeHooks.installing(command: command, in: try JSONValue(parsing: #"{"hooks": {"Stop": {}}}"#)) == nil)
        #expect(ClaudeCodeHooks.installing(command: command, in: try JSONValue(parsing: "[]")) == nil)
    }

    @Test func quotesPathsForTheShell() {
        #expect(ClaudeCodeHooks.shellQuoted("/Users/o'brien/a b") == #"'/Users/o'\''brien/a b'"#)
    }
}

// MARK: - Installer

struct ClaudeCodeHookInstallerTests {
    private let directory = FileManager.default.temporaryDirectory.appending(path: "PNotchClaude-\(UUID().uuidString)", directoryHint: .isDirectory)

    private var installer: ClaudeCodeHookInstaller {
        ClaudeCodeHookInstaller(
            claudeDirectory: directory.appending(path: ".claude", directoryHint: .isDirectory),
            socketURL: directory.appending(path: "claude-code.sock")
        )
    }

    @Test func installsAndUninstalls() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let installer = installer
        #expect(!installer.isInstalled)

        try installer.install()
        #expect(installer.isInstalled)
        #expect(FileManager.default.isExecutableFile(atPath: installer.scriptURL.path(percentEncoded: false)))
        let written = try String(contentsOf: installer.settingsURL, encoding: .utf8)
        #expect(written.hasSuffix("}\n"))
        #expect(written.contains(#""async": true"#))

        try installer.uninstall()
        #expect(!installer.isInstalled)
        #expect(!FileManager.default.fileExists(atPath: installer.scriptURL.path(percentEncoded: false)))
        #expect(try String(contentsOf: installer.settingsURL, encoding: .utf8) == "{}\n")
    }

    @Test func keepsABackupAndWritesThroughSymlinks() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let installer = installer
        let dotfiles = directory.appending(path: "dotfiles-settings.json")
        try FileManager.default.createDirectory(at: installer.claudeDirectory, withIntermediateDirectories: true)
        let original = "{\n  \"model\": \"opus\"\n}"
        try original.write(to: dotfiles, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: installer.settingsURL, withDestinationURL: dotfiles)

        try installer.install()

        let attributes = try FileManager.default.attributesOfItem(atPath: installer.settingsURL.path(percentEncoded: false))
        #expect(attributes[.type] as? FileAttributeType == .typeSymbolicLink)
        #expect(try String(contentsOf: dotfiles, encoding: .utf8).contains("pnotch.sh"))
        let backup = dotfiles.appendingPathExtension("pnotch-backup")
        #expect(try String(contentsOf: backup, encoding: .utf8) == original)
        // No trailing newline before, none after.
        #expect(try !String(contentsOf: dotfiles, encoding: .utf8).hasSuffix("\n"))
    }

    @Test func upgradesAnOlderConnectionOnLaunch() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let installer = installer
        try FileManager.default.createDirectory(at: installer.claudeDirectory, withIntermediateDirectories: true)

        // Not connected: nothing is written.
        try installer.updateIfConnected()
        #expect(!FileManager.default.fileExists(atPath: installer.settingsURL.path(percentEncoded: false)))

        let old = """
        {"hooks": {"PermissionRequest": [{"hooks": [{"type": "command", "command": "\(installer.command)", "async": true}]}]}}
        """
        try old.write(to: installer.settingsURL, atomically: true, encoding: .utf8)
        #expect(!installer.isInstalled)

        try installer.updateIfConnected()
        #expect(installer.isInstalled)
    }

    @Test func neverOverwritesUnreadableSettings() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let installer = installer
        try FileManager.default.createDirectory(at: installer.claudeDirectory, withIntermediateDirectories: true)
        let broken = "{\n  \"model\": \"opus\",\n}"
        try broken.write(to: installer.settingsURL, atomically: true, encoding: .utf8)

        #expect(throws: ClaudeCodeHookInstaller.InstallError.self) {
            try installer.install()
        }
        #expect(try String(contentsOf: installer.settingsURL, encoding: .utf8) == broken)
        #expect(!FileManager.default.fileExists(atPath: installer.scriptURL.path(percentEncoded: false)))
    }
}

// MARK: - Approvals

struct ClaudeCodeApprovalTests {
    private let replyID = ClaudeCodeHookServer.ReplyID(rawValue: 7)

    @Test func readsThePermissionRequest() throws {
        let payload = try JSONValue(parsing: """
        {"session_id": "s1", "hook_event_name": "PermissionRequest", "tool_name": "Bash",
         "tool_input": {"command": "npm install left-pad"},
         "permission_suggestions": [
           {"type": "setMode", "mode": "acceptEdits", "destination": "session"},
           {"type": "addRules", "rules": [{"toolName": "Bash", "ruleContent": "npm install:*"}], "behavior": "allow", "destination": "localSettings"}
         ]}
        """)
        let approval = try #require(ClaudeCodeApproval(payload: payload, replyID: replyID))
        #expect(approval.sessionID == "s1")
        #expect(approval.tool == ClaudeCodeTool(name: "Bash", detail: "npm install left-pad"))
        #expect(approval.alwaysAllowRule?["rules"]?.arrayValue?.first?["ruleContent"]?.stringValue == "npm install:*")

        let other = try JSONValue(parsing: #"{"session_id": "s1", "hook_event_name": "PreToolUse"}"#)
        #expect(ClaudeCodeApproval(payload: other, replyID: replyID) == nil)
    }

    @Test func answersInClaudeCodesFormat() throws {
        #expect(ClaudeCodeDecision.allow.hookOutput == (try JSONValue(parsing: """
        {"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": {"behavior": "allow"}}}
        """)))

        let rule = try JSONValue(parsing: #"{"type": "addRules", "rules": [{"toolName": "Bash", "ruleContent": "ls"}], "behavior": "allow", "destination": "localSettings"}"#)
        let always = ClaudeCodeDecision.allowAlways(rule: rule).hookOutput
        #expect(always["hookSpecificOutput"]?["decision"]?["updatedPermissions"] == .array([rule]))

        let deny = ClaudeCodeDecision.deny.hookOutput["hookSpecificOutput"]?["decision"]
        #expect(deny?["behavior"] == .string("deny"))
        #expect(deny?["message"]?.stringValue?.isEmpty == false)
    }

    @Test func waitsOnlyWhenYoureAwayFromTheTerminal() {
        #expect(ClaudeCodeAttention.holdsPermission(answersInNotch: true, hostIsFrontmost: false))
        #expect(!ClaudeCodeAttention.holdsPermission(answersInNotch: true, hostIsFrontmost: true))
        #expect(!ClaudeCodeAttention.holdsPermission(answersInNotch: false, hostIsFrontmost: false))
    }
}

// MARK: - HTTP

struct HTTPRequestTests {
    @Test func parsesARequestOnceComplete() {
        let head = "POST /claude-code/events HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: 11\r\n\r\n"
        #expect(HTTPRequest.parse(Data(head.prefix(20).utf8)) == .incomplete)
        #expect(HTTPRequest.parse(Data((head + "{\"a\":").utf8)) == .incomplete)

        guard case let .complete(request) = HTTPRequest.parse(Data((head + "{\"a\": true}").utf8)) else {
            Issue.record("Expected a complete request")
            return
        }
        #expect(request.method == "POST")
        #expect(request.path == "/claude-code/events")
        #expect(request.headers["content-type"] == "application/json")
        #expect(request.body == Data("{\"a\": true}".utf8))
    }

    @Test func rejectsWhatItDoesntSpeak() {
        #expect(HTTPRequest.parse(Data("GARBAGE\r\n\r\n".utf8)) == .invalid)
        #expect(HTTPRequest.parse(Data("POST / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n".utf8)) == .invalid)
        #expect(HTTPRequest.parse(Data("POST / HTTP/1.1\r\nContent-Length: -1\r\n\r\n".utf8)) == .invalid)
        #expect(HTTPRequest.parse(Data(String(repeating: "a", count: HTTPRequest.maximumHeaderLength + 1).utf8)) == .invalid)
    }
}

// MARK: - Process tree

struct ProcessTreeTests {
    @Test func walksUpFromAChildProcess() throws {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["5"]
        try child.run()
        defer { child.terminate() }

        let ancestry = ProcessTree.ancestry(of: child.processIdentifier)
        #expect(ancestry.map(\.pid).prefix(2) == [child.processIdentifier, getpid()])
        #expect(ancestry.first?.name == "sleep")
        #expect(ProcessTree.isAlive(child.processIdentifier))
        #expect(!ProcessTree.isAlive(pid_t.max))
    }

    @Test func findsClaudeCodeAboveTheHook() {
        let ancestry: [ProcessTree.Entry] = [
            .init(pid: 40, name: "curl"),
            .init(pid: 39, name: "sh"),
            .init(pid: 38, name: "zsh"),
            .init(pid: 37, name: "claude"),
            .init(pid: 12, name: "Code Helper (Plugin)"),
        ]
        #expect(ProcessTree.claudeCodeProcess(in: ancestry) == 37)
        #expect(ProcessTree.claudeCodeProcess(in: Array(ancestry.prefix(3))) == nil)
    }
}

// MARK: - Manager

@MainActor
struct ClaudeCodeManagerTests {
    private final class Clock {
        var now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    }

    private let clock = Clock()
    private let directory = FileManager.default.temporaryDirectory.appending(path: "PNotchClaude-\(UUID().uuidString)", directoryHint: .isDirectory)

    private func makeManager() -> ClaudeCodeManager {
        let clock = clock
        let installer = ClaudeCodeHookInstaller(
            claudeDirectory: directory.appending(path: ".claude", directoryHint: .isDirectory),
            socketURL: directory.appending(path: "claude-code.sock")
        )
        return ClaudeCodeManager(installer: installer) { clock.now }
    }

    private func event(_ session: String, _ kind: ClaudeCodeEvent.Kind, transcript: String? = nil) -> ClaudeCodeEvent {
        ClaudeCodeEvent(sessionID: session, kind: kind, cwd: "/Users/theo/Developer/\(session)", transcriptPath: transcript)
    }

    @Test func putsWhatNeedsYouFirst() {
        let manager = makeManager()
        var transitions: [ClaudeCodeSession.Transition] = []
        manager.onTransition = { _, transition in transitions.append(transition) }

        manager.receive(event("api", .promptSubmitted("Refactor")))
        clock.now += 5
        manager.receive(event("web", .promptSubmitted("Fix CSS")))
        #expect(manager.liveActivity == .working(manager.sessions[1]))

        clock.now += 5
        manager.receive(event("api", .permissionRequested(ClaudeCodeTool(name: "Bash", detail: "rm -rf build"))))
        #expect(manager.orderedSessions.map(\.id) == ["api", "web"])
        #expect(manager.liveActivity?.isWaiting == true)
        #expect(manager.liveActivity?.session.id == "api")
        #expect(manager.needsAttention)
        #expect(transitions == [.startedWaiting])

        manager.receive(event("api", .sessionEnded))
        #expect(manager.sessions.map(\.id) == ["web"])
        #expect(manager.liveActivity?.isWaiting == false)
    }

    @Test func remembersWhereTheSessionRuns() {
        let manager = makeManager()
        manager.receive(event("api", .sessionStarted), hostBundleIdentifier: "com.apple.Terminal", processIdentifier: getpid())
        manager.receive(event("api", .promptSubmitted("Go")), hostBundleIdentifier: "com.other.App", processIdentifier: 1)
        #expect(manager.sessions.first?.hostBundleIdentifier == "com.apple.Terminal")
        #expect(manager.sessions.first?.processIdentifier == getpid())
    }

    @Test func forgetsSessionsWhoseClaudeQuit() async {
        let manager = makeManager()
        manager.receive(event("gone", .promptSubmitted("Go")), processIdentifier: pid_t.max)
        manager.receive(event("alive", .stopped(lastMessage: nil)), processIdentifier: getpid())
        manager.receive(event("unknown", .stopped(lastMessage: nil)))

        await manager.tidyUp()
        #expect(Set(manager.sessions.map(\.id)) == ["alive", "unknown"])

        clock.now += ClaudeCodeManager.forgottenAfter + 1
        await manager.tidyUp()
        #expect(manager.sessions.map(\.id) == ["alive"])
    }

    @Test func noticesInterruptedTurns() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let transcript = directory.appending(path: "s.jsonl")
        try #"{"type":"user","message":{"role":"user","content":"Go"}}"#.write(to: transcript, atomically: true, encoding: .utf8)

        let manager = makeManager()
        manager.receive(event("s", .promptSubmitted("Go"), transcript: transcript.path(percentEncoded: false)))
        clock.now += ClaudeCodeManager.interruptionCheckDelay + 1
        await manager.tidyUp()
        #expect(manager.sessions.first?.status == .working)

        let interrupted = #"{"type":"user","message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]}}"#
        try interrupted.write(to: transcript, atomically: true, encoding: .utf8)
        await manager.tidyUp()
        #expect(manager.sessions.first?.status == .idle)
    }
}

// MARK: - End to end

/// The hook script PNotch installs, run like Claude Code runs it, talking to the server through the socket.
@MainActor
struct ClaudeCodeHookEndToEndTests {
    @Test func theScriptDeliversEventsToTheNotch() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "pn-\(UUID().uuidString.prefix(8))", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let installer = ClaudeCodeHookInstaller(
            claudeDirectory: directory.appending(path: ".claude", directoryHint: .isDirectory),
            socketURL: directory.appending(path: "cc.sock")
        )
        try installer.install()

        let manager = ClaudeCodeManager(installer: installer)
        manager.start()
        defer { manager.stop() }

        let process = Process()
        process.executableURL = installer.scriptURL
        process.environment = ["HOME": directory.path(percentEncoded: false), "PATH": "/usr/bin:/bin", "__CFBundleIdentifier": "com.apple.Terminal"]
        let input = Pipe()
        process.standardInput = input
        try process.run()
        let payload = #"{"session_id": "e2e", "hook_event_name": "UserPromptSubmit", "cwd": "/tmp/project", "prompt": "Hello from the hook"}"#
        input.fileHandleForWriting.write(Data(payload.utf8))
        try input.fileHandleForWriting.close()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)

        let deadline = ContinuousClock.now + .seconds(5)
        while manager.sessions.isEmpty, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        let session = try #require(manager.sessions.first)
        #expect(session.id == "e2e")
        #expect(session.prompt == "Hello from the hook")
        #expect(session.status == .working)
        #expect(session.hostBundleIdentifier == "com.apple.Terminal")
        // Above the hook's shell and curl: the process that ran it, here the test host.
        #expect(session.processIdentifier == getpid())
    }

    /// Runs the hook in "permission" mode with `payload` on its input, like Claude Code does.
    private func runPermissionHook(_ installer: ClaudeCodeHookInstaller, payload: String) throws -> (Process, Pipe) {
        let process = Process()
        process.executableURL = installer.scriptURL
        process.arguments = ["permission"]
        process.environment = ["PATH": "/usr/bin:/bin", "__CFBundleIdentifier": "com.apple.Terminal"]
        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        try process.run()
        input.fileHandleForWriting.write(Data(payload.utf8))
        try input.fileHandleForWriting.close()
        return (process, output)
    }

    private func waitFor(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(30))
        }
    }

    /// Never `waitUntilExit()`: it would block the main actor, which receives the request and sends the answer.
    private func waitForExit(_ process: Process) async throws {
        try await waitFor { !process.isRunning }
        #expect(!process.isRunning)
    }

    private func makeInstalledDirectory() throws -> (URL, ClaudeCodeHookInstaller) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "pn-\(UUID().uuidString.prefix(8))", directoryHint: .isDirectory)
        let installer = ClaudeCodeHookInstaller(
            claudeDirectory: directory.appending(path: ".claude", directoryHint: .isDirectory),
            socketURL: directory.appending(path: "cc.sock")
        )
        try installer.install()
        return (directory, installer)
    }

    private let permissionPayload = #"{"session_id": "e2e", "hook_event_name": "PermissionRequest", "cwd": "/tmp/project", "tool_name": "Bash", "tool_input": {"command": "rm -rf build"}}"#

    @Test func aPermissionRequestWaitsForTheNotchsAnswer() async throws {
        let (directory, installer) = try makeInstalledDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        // You're in another app: the request waits for the notch.
        let manager = ClaudeCodeManager(installer: installer, frontmostApplication: { "com.apple.Safari" })
        manager.start()
        defer { manager.stop() }

        let (process, output) = try runPermissionHook(installer, payload: permissionPayload)
        try await waitFor { !manager.approvals.isEmpty }
        let session = try #require(manager.sessions.first)
        #expect(manager.approval(for: session)?.tool.detail == "rm -rf build")
        #expect(session.needsAttention)
        #expect(process.isRunning)

        manager.answer(session, with: .allow)
        try await waitForExit(process)
        let printed = try JSONValue(parsing: output.fileHandleForReading.readDataToEndOfFile())
        #expect(printed == ClaudeCodeDecision.allow.hookOutput)
        #expect(process.terminationStatus == 0)
        #expect(manager.approvals.isEmpty)
        #expect(manager.sessions.first?.status == .working)
    }

    @Test func inFrontOfTheTerminalClaudeCodeAsksThere() async throws {
        let (directory, installer) = try makeInstalledDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = ClaudeCodeManager(installer: installer, frontmostApplication: { "com.apple.Terminal" })
        manager.start()
        defer { manager.stop() }

        let (process, output) = try runPermissionHook(installer, payload: permissionPayload)
        try await waitForExit(process)
        // No decision printed: Claude Code shows its own prompt.
        #expect(output.fileHandleForReading.readDataToEndOfFile().isEmpty)
        #expect(manager.approvals.isEmpty)
        #expect(manager.sessions.first?.needsAttention == true)
    }

    @Test func answeringInTheTerminalClearsTheNotch() async throws {
        let (directory, installer) = try makeInstalledDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = ClaudeCodeManager(installer: installer, frontmostApplication: { "com.apple.Safari" })
        manager.start()
        defer { manager.stop() }

        let (process, _) = try runPermissionHook(installer, payload: permissionPayload)
        try await waitFor { !manager.approvals.isEmpty }
        // Claude Code got its answer elsewhere and stopped the hook.
        process.terminate()
        try await waitFor { manager.approvals.isEmpty }
        #expect(manager.approvals.isEmpty)
    }

    @Test func goingToTheSessionHandsTheRequestBack() async throws {
        let (directory, installer) = try makeInstalledDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = ClaudeCodeManager(installer: installer, frontmostApplication: { "com.apple.Safari" })
        manager.start()
        defer { manager.stop() }

        let (process, output) = try runPermissionHook(installer, payload: permissionPayload)
        try await waitFor { !manager.approvals.isEmpty }
        manager.handOver(try #require(manager.sessions.first))
        try await waitForExit(process)
        #expect(output.fileHandleForReading.readDataToEndOfFile().isEmpty)
        #expect(manager.approvals.isEmpty)
    }

    @Test func theScriptStaysQuietWithoutPNotch() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "pn-\(UUID().uuidString.prefix(8))", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let installer = ClaudeCodeHookInstaller(
            claudeDirectory: directory.appending(path: ".claude", directoryHint: .isDirectory),
            socketURL: directory.appending(path: "cc.sock")
        )
        try installer.install()

        let process = Process()
        process.executableURL = installer.scriptURL
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        #expect(output.fileHandleForReading.readDataToEndOfFile().isEmpty)
    }
}
