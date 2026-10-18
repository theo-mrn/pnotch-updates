//
//  ClaudeCodeManager.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import AppKit
import Defaults
import Observation
import os

/// The Claude Code sessions followed from the notch, fed by the hook PNotch adds to Claude Code's settings.
/// Permission requests can be answered from the notch while you're away from the session's terminal.
@Observable
final class ClaudeCodeManager {
    /// What the closed notch shows: a session that needs you wins over busy ones.
    enum LiveActivity: Equatable {
        case needsYou(ClaudeCodeSession)
        case working(ClaudeCodeSession)

        var session: ClaudeCodeSession {
            switch self {
            case let .needsYou(session), let .working(session): session
            }
        }

        var isWaiting: Bool {
            if case .needsYou = self {
                return true
            }
            return false
        }
    }

    /// A session with no known process is forgotten after this long without news.
    static let forgottenAfter: TimeInterval = 60 * 60
    /// A turn with no news for this long was most likely interrupted without a trace in the transcript.
    static let presumedInterruptedAfter: TimeInterval = 15 * 60
    /// The transcript is checked for an interruption once the session has been quiet for this long.
    static let interruptionCheckDelay: TimeInterval = 2

    private(set) var sessions: [ClaudeCodeSession] = []
    /// Permission requests waiting for an answer in the notch, by session.
    private(set) var approvals: [String: ClaudeCodeApproval] = [:]
    /// Whether the hook is in Claude Code's settings.
    private(set) var isConnected = false
    private(set) var connectionError: String?

    /// A session started waiting for the user, finished or failed.
    @ObservationIgnored var onTransition: ((ClaudeCodeSession, ClaudeCodeSession.Transition) -> Void)?
    @ObservationIgnored private let installer: ClaudeCodeHookInstaller
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let frontmostApplication: () -> String?
    @ObservationIgnored private var server: ClaudeCodeHookServer?
    @ObservationIgnored private var housekeeping: Task<Void, Never>?
    @ObservationIgnored private var activationObserver: NSObjectProtocol?

    /// - Parameter frontmostApplication: Bundle identifier of the app in front. Injectable for tests.
    init(
        installer: ClaudeCodeHookInstaller = .standard,
        now: @escaping () -> Date = { .now },
        frontmostApplication: @escaping () -> String? = { NSWorkspace.shared.frontmostApplication?.bundleIdentifier }
    ) {
        self.installer = installer
        self.now = now
        self.frontmostApplication = frontmostApplication
    }

    // MARK: Lifecycle

    func start() {
        do {
            try installer.updateIfConnected()
        } catch {
            Logger.claudeCode.error("Failed to update the Claude Code hook: \(error.localizedDescription)")
        }
        refreshConnection()

        let server = ClaudeCodeHookServer(socketURL: installer.socketURL) { [weak self] delivery in
            Task { @MainActor in
                self?.receive(delivery)
            }
        } onAbandon: { [weak self] replyID in
            Task { @MainActor in
                self?.forgetApproval(replyID)
            }
        }
        do {
            try server.start()
            self.server = server
        } catch {
            Logger.claudeCode.error("Failed to listen for Claude Code hooks: \(String(describing: error))")
        }

        housekeeping = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                await self?.tidyUp()
            }
        }

        // Back in the session's terminal or editor: Claude Code asks there instead.
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleIdentifier = app?.bundleIdentifier
            MainActor.assumeIsolated {
                self?.handOverApprovals(toApp: bundleIdentifier)
            }
        }
    }

    func stop() {
        housekeeping?.cancel()
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        // Whatever is still waiting goes back to the terminal.
        for approval in approvals.values {
            server?.reply(to: approval.replyID, with: nil)
        }
        approvals.removeAll()
        server?.stop()
        server = nil
    }

    // MARK: Connection

    func connect() {
        do {
            try installer.install()
            connectionError = nil
        } catch {
            Logger.claudeCode.error("Failed to add the Claude Code hook: \(error.localizedDescription)")
            connectionError = error.localizedDescription
        }
        refreshConnection()
    }

    func disconnect() {
        do {
            try installer.uninstall()
            connectionError = nil
        } catch {
            Logger.claudeCode.error("Failed to remove the Claude Code hook: \(error.localizedDescription)")
            connectionError = error.localizedDescription
        }
        refreshConnection()
    }

    /// The settings can change behind PNotch's back, e.g. edited by hand.
    func refreshConnection() {
        isConnected = installer.isInstalled
    }

    // MARK: Sessions

    /// Sessions waiting for you first, then busy ones, then the most recent.
    var orderedSessions: [ClaudeCodeSession] {
        sessions.sorted { lhs, rhs in
            let lhsRank = Self.rank(of: lhs.status)
            let rhsRank = Self.rank(of: rhs.status)
            return lhsRank != rhsRank ? lhsRank < rhsRank : lhs.updatedAt > rhs.updatedAt
        }
    }

    var liveActivity: LiveActivity? {
        let ordered = orderedSessions
        if let waiting = ordered.first(where: \.needsAttention) {
            return .needsYou(waiting)
        }
        if let working = ordered.first(where: \.isWorking) {
            return .working(working)
        }
        return nil
    }

    var needsAttention: Bool {
        sessions.contains(where: \.needsAttention)
    }

    func receive(_ delivery: ClaudeCodeHookServer.Delivery) {
        guard let payload = try? JSONValue(parsing: delivery.body), let event = ClaudeCodeEvent(payload: payload) else {
            if let replyID = delivery.replyID {
                server?.reply(to: replyID, with: nil)
            }
            return
        }
        let hostApp = delivery.headers["x-pnotch-host-app"].flatMap { $0.isEmpty ? nil : $0 }
            ?? Self.hostApplication(in: delivery.ancestry)
        receive(event, hostBundleIdentifier: hostApp, processIdentifier: ProcessTree.claudeCodeProcess(in: delivery.ancestry))

        if let replyID = delivery.replyID {
            hold(ClaudeCodeApproval(payload: payload, replyID: replyID), replyID: replyID)
        }
    }

    // MARK: Approvals

    func approval(for session: ClaudeCodeSession) -> ClaudeCodeApproval? {
        approvals[session.id]
    }

    /// Answers a permission request from the notch.
    func answer(_ session: ClaudeCodeSession, with decision: ClaudeCodeDecision) {
        guard let approval = approvals.removeValue(forKey: session.id) else { return }
        server?.reply(to: approval.replyID, with: Data(decision.hookOutput.formatted().utf8))
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index].status = .working
            sessions[index].tool = decision == .deny ? nil : approval.tool
            sessions[index].updatedAt = now()
        }
    }

    /// Lets Claude Code ask in the terminal: you went back to it, or chose to answer there.
    func handOver(_ session: ClaudeCodeSession) {
        guard let approval = approvals.removeValue(forKey: session.id) else { return }
        server?.reply(to: approval.replyID, with: nil)
    }

    /// Waits for the notch, unless you're already in front of the session: Claude Code asks there right away.
    private func hold(_ approval: ClaudeCodeApproval?, replyID: ClaudeCodeHookServer.ReplyID) {
        guard let approval, let session = sessions.first(where: { $0.id == approval.sessionID }),
              ClaudeCodeAttention.holdsPermission(
                  answersInNotch: Defaults[.claudeCodeAnswersInNotch],
                  hostIsFrontmost: isFrontmost(session)
              )
        else {
            server?.reply(to: replyID, with: nil)
            return
        }
        // A newer request from the same session replaces the older one, which goes back to the terminal.
        if let previous = approvals[approval.sessionID] {
            server?.reply(to: previous.replyID, with: nil)
        }
        approvals[approval.sessionID] = approval
    }

    private func handOverApprovals(toApp bundleIdentifier: String?) {
        guard let bundleIdentifier else { return }
        for session in sessions where session.hostBundleIdentifier == bundleIdentifier {
            handOver(session)
        }
    }

    /// The hook stopped waiting: answered in the terminal, interrupted, or too long.
    private func forgetApproval(_ replyID: ClaudeCodeHookServer.ReplyID) {
        guard let sessionID = approvals.first(where: { $0.value.replyID == replyID })?.key else { return }
        approvals.removeValue(forKey: sessionID)
    }

    func receive(_ event: ClaudeCodeEvent, hostBundleIdentifier: String? = nil, processIdentifier: pid_t? = nil) {
        if case .sessionEnded = event.kind {
            sessions.removeAll { $0.id == event.sessionID }
            approvals.removeValue(forKey: event.sessionID)
            return
        }
        let date = now()
        var session = sessions.first { $0.id == event.sessionID } ?? ClaudeCodeSession(id: event.sessionID, updatedAt: date)
        session.hostBundleIdentifier = session.hostBundleIdentifier ?? hostBundleIdentifier
        session.processIdentifier = session.processIdentifier ?? processIdentifier
        let transition = session.apply(event, at: date)

        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        if let transition {
            onTransition?(session, transition)
        }
    }

    /// Brings back the terminal or editor the session runs in. A pending request is answered there.
    func open(_ session: ClaudeCodeSession) {
        handOver(session)
        guard let bundleIdentifier = session.hostBundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
        // PNotch is never the active app: asking Launch Services is what reliably brings another app forward.
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    func isFrontmost(_ session: ClaudeCodeSession) -> Bool {
        guard let bundleIdentifier = session.hostBundleIdentifier else { return false }
        return frontmostApplication() == bundleIdentifier
    }

    // MARK: Housekeeping

    /// Forgets sessions whose Claude Code quit without a word, and notices interrupted turns:
    /// Claude Code doesn't run any hook when the user presses esc.
    func tidyUp() async {
        let date = now()
        sessions.removeAll { session in
            if let pid = session.processIdentifier {
                return !ProcessTree.isAlive(pid)
            }
            return !session.isWorking && date.timeIntervalSince(session.updatedAt) > Self.forgottenAfter
        }
        approvals = approvals.filter { sessionID, _ in sessions.contains { $0.id == sessionID } }

        let quiet = sessions.filter { session in
            (session.isWorking || session.needsAttention) && date.timeIntervalSince(session.updatedAt) > Self.interruptionCheckDelay
        }
        for session in quiet {
            let interrupted: Bool
            if session.isWorking, date.timeIntervalSince(session.updatedAt) > Self.presumedInterruptedAfter {
                interrupted = true
            } else if let path = session.transcriptPath {
                interrupted = await Self.transcriptEndsWithInterruption(at: URL(fileURLWithPath: path))
            } else {
                interrupted = false
            }
            // Only if nothing happened in the session while the transcript was being read.
            if interrupted, let index = sessions.firstIndex(where: { $0.id == session.id }),
               sessions[index].updatedAt == session.updatedAt {
                sessions[index].markInterrupted(at: date)
            }
        }
    }

    /// Off the main actor: transcripts can have long lines to parse.
    @concurrent
    private nonisolated static func transcriptEndsWithInterruption(at url: URL) async -> Bool {
        ClaudeCodeTranscript.tail(of: url).map(ClaudeCodeTranscript.endsWithInterruption) ?? false
    }

    private static func rank(of status: ClaudeCodeSession.Status) -> Int {
        switch status {
        case .waiting: 0
        case .working: 1
        case .finished, .failed: 2
        case .idle: 3
        }
    }

    /// The first ancestor of the hook that is a regular app: the terminal or the editor running Claude Code.
    private static func hostApplication(in ancestry: [ProcessTree.Entry]) -> String? {
        ancestry.lazy
            .compactMap { NSRunningApplication(processIdentifier: $0.pid) }
            .first { $0.activationPolicy == .regular }?
            .bundleIdentifier
    }
}
