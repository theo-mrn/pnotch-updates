//
//  ClaudeCodeLiveActivityView.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// Around the closed notch while a Claude Code session works (the star and the time it has been at it)
/// or waits for you (the robot, or the star, and a raised hand).
struct ClaudeCodeLiveActivityView: View {
    let activity: ClaudeCodeManager.LiveActivity
    let notchSize: CGSize

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(width: NotchMetrics.sneakPeekSideWidth)
            Color.clear
                .frame(width: notchSize.width)
            trailing
                .frame(width: NotchMetrics.sneakPeekSideWidth)
        }
        .frame(height: notchSize.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(activity.session.projectName): \(activity.session.statusLine)"))
    }

    @ViewBuilder
    private var leading: some View {
        switch activity {
        case .working:
            ClaudeCodeSpinner()
        case .needsYou:
            CompanionMessengerFace {
                ClaudeCodeSpinner(isSpinning: false)
            }
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch activity {
        case let .working(session):
            if let start = session.turnStartedAt {
                ElapsedTimeText(since: start)
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
                    .minimumScaleFactor(0.7)
            }
        case .needsYou:
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ClaudeCodeSpinner.tint)
                .symbolEffect(.pulse)
        }
    }
}

/// Flashes around the closed notch when a session is done, or stopped on an error.
struct ClaudeCodeSneakPeekView: View {
    let outcome: SneakPeek.ClaudeCodeOutcome
    let notchSize: CGSize

    @State private var hasAppeared = false

    var body: some View {
        HStack(spacing: 0) {
            CompanionMessengerFace {
                ClaudeCodeSpinner(isSpinning: false)
            }
            .frame(width: NotchMetrics.sneakPeekSideWidth)

            Color.clear
                .frame(width: notchSize.width)

            Image(systemName: outcome == .finished ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(outcome == .finished ? .green : .yellow)
                .symbolEffect(.bounce, value: hasAppeared)
                .frame(width: NotchMetrics.sneakPeekSideWidth)
        }
        .frame(height: notchSize.height)
        .onAppear { hasAppeared = true }
    }
}
