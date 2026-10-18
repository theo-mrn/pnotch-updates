//
//  ClaudeCodeView.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// The Claude Code page: every running session, what it's doing, and a click to get back to it.
struct ClaudeCodeView: View {
    @Environment(ClaudeCodeManager.self) private var claudeCode

    var body: some View {
        VStack(spacing: 0) {
            NotchHeaderView()

            Group {
                if !claudeCode.isConnected {
                    ClaudeCodeConnectView()
                } else if claudeCode.sessions.isEmpty {
                    ClaudeCodeEmptyView()
                } else {
                    sessionList
                }
            }
            .frame(height: ClaudeCodeMetrics.bodyHeight)
        }
        .onAppear { claudeCode.refreshConnection() }
    }

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: ClaudeCodeMetrics.rowSpacing) {
                ForEach(claudeCode.orderedSessions) { session in
                    ClaudeCodeSessionRow(session: session)
                }
            }
            .padding(.horizontal, ClaudeCodeMetrics.horizontalPadding)
            .padding(.vertical, ClaudeCodeMetrics.verticalPadding)
            .animation(.smooth(duration: 0.3), value: claudeCode.orderedSessions.map(\.id))
        }
        .scrollIndicators(.never)
    }
}

// MARK: - Session row

private struct ClaudeCodeSessionRow: View {
    let session: ClaudeCodeSession

    @Environment(ClaudeCodeManager.self) private var claudeCode
    @Environment(PNotchViewModel.self) private var vm
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ClaudeCodeMetrics.rowCornerRadius, style: .continuous)

        // Not a button: the answer buttons inside it must stay their own.
        HStack(spacing: 10) {
            HostAppIcon(bundleIdentifier: session.hostBundleIdentifier)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(session.projectName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .layoutPriority(1)
                    if let prompt = session.prompt, !prompt.isEmpty {
                        Text(prompt)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                Label {
                    Text(session.statusLine)
                } icon: {
                    Image(systemName: session.statusSymbol)
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(session.statusTint)
                .labelStyle(CompactLabelStyle())
            }
            .lineLimit(1)

            Spacer(minLength: 8)

            if let approval = claudeCode.approval(for: session) {
                ClaudeCodeApprovalButtons(session: session, approval: approval)
            } else {
                ClaudeCodeStatusBadge(session: session)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: ClaudeCodeMetrics.rowHeight)
        .background(.white.opacity(session.needsAttention ? 0.1 : isHovered ? 0.09 : 0.05), in: shape)
        .overlay {
            if session.needsAttention {
                shape.strokeBorder(ClaudeCodeSpinner.tint.opacity(0.6), lineWidth: 1)
            }
        }
        .contentShape(shape)
        .onTapGesture {
            claudeCode.open(session)
            vm.close(reason: .switchedApp)
        }
        .onHover { isHovered = $0 }
        .help(session.hostBundleIdentifier == nil ? "" : String(localized: "Go to this session"))
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
    }
}

/// Deny, always allow and allow, right in the row: Claude Code waits for one of them.
private struct ClaudeCodeApprovalButtons: View {
    let session: ClaudeCodeSession
    let approval: ClaudeCodeApproval

    @Environment(ClaudeCodeManager.self) private var claudeCode

    var body: some View {
        HStack(spacing: 6) {
            ApprovalButton(title: "Deny", isProminent: false) {
                claudeCode.answer(session, with: .deny)
            }
            if let rule = approval.alwaysAllowRule {
                ApprovalButton(title: "Always", isProminent: false) {
                    claudeCode.answer(session, with: .allowAlways(rule: rule))
                }
                .help(Self.describe(rule))
            }
            ApprovalButton(title: "Allow", isProminent: true) {
                claudeCode.answer(session, with: .allow)
            }
        }
    }

    /// What "Always" adds: the rule's scope, from Claude Code's suggestion.
    private static func describe(_ rule: JSONValue) -> String {
        let content = rule["rules"]?.arrayValue?.first?["ruleContent"]?.stringValue
        let scope = switch rule["destination"]?.stringValue {
        case "session": String(localized: "for this session")
        case "userSettings": String(localized: "everywhere")
        default: String(localized: "in this project")
        }
        if let content {
            return String(localized: "Don't ask again for “\(content)” \(scope)")
        }
        return String(localized: "Don't ask again \(scope)")
    }
}

private struct ApprovalButton: View {
    let title: LocalizedStringKey
    let isProminent: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background {
                    Capsule().fill(isProminent ? ClaudeCodeSpinner.tint : .white.opacity(isHovered ? 0.2 : 0.12))
                }
                .brightness(isProminent && isHovered ? 0.06 : 0)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

/// Elapsed time while working, "Needs you" while waiting, how long ago once done.
private struct ClaudeCodeStatusBadge: View {
    let session: ClaudeCodeSession

    var body: some View {
        switch session.status {
        case .working:
            HStack(spacing: 4) {
                ClaudeCodeSpinner(size: 12)
                if let start = session.turnStartedAt {
                    ElapsedTimeText(since: start)
                        .font(.system(size: 11.5, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        case .waiting:
            Text("Needs you")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(ClaudeCodeSpinner.tint, in: Capsule())
        case .idle, .finished, .failed:
            Text(RelativeTimeFormatter.string(for: session.updatedAt, style: .spelledOut))
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}

/// The terminal or editor the session runs in.
private struct HostAppIcon: View {
    let bundleIdentifier: String?

    var body: some View {
        Group {
            if let bundleIdentifier, let icon = AppIcons.icon(forBundleIdentifier: bundleIdentifier) {
                Image(nsImage: icon)
                    .resizable()
            } else {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
        }
        .frame(width: 28, height: 28)
    }
}

/// "0:42", ticking every second.
struct ElapsedTimeText: View {
    let since: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            Text(PlaybackTimeFormatter.string(from: timeline.date.timeIntervalSince(since)))
        }
    }
}

private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon
                .frame(width: 12)
            configuration.title
        }
    }
}

// MARK: - Connect

/// Shown until Claude Code is connected: what the page does, and the button that adds the hook.
private struct ClaudeCodeConnectView: View {
    @Environment(ClaudeCodeManager.self) private var claudeCode

    var body: some View {
        HStack(spacing: 18) {
            ClaudeCodeSpinner(isSpinning: false, size: 40)
                .frame(width: 76, height: 76)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("Follow Claude Code from the notch")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text("See what Claude is working on, when it needs you and when it's done, without leaving your app.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button("Connect Claude Code") {
                        claudeCode.connect()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 26)
                    .background(ClaudeCodeSpinner.tint, in: Capsule())

                    Text("Adds a hook to ~/.claude/settings.json")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.top, 4)

                if let error = claudeCode.connectionError {
                    Text(error)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.yellow)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 26)
    }
}

// MARK: - Empty

private struct ClaudeCodeEmptyView: View {
    var body: some View {
        VStack(spacing: 6) {
            ClaudeCodeSpinner(isSpinning: false, size: 22)
                .padding(.bottom, 2)
            Text("No Claude Code session")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text("Start claude in a terminal or your editor and it shows up here. Sessions opened before connecting need a restart.")
                .font(.system(size: 11.5))
                .foregroundStyle(.white.opacity(0.45))
                .frame(maxWidth: 420)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
