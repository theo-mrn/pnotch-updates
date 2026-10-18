//
//  FocusLiveActivityView.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// Around the closed notch during a focus session or its break: the companion busy with you,
/// and the time left.
struct FocusLiveActivityView: View {
    let session: FocusSession
    let notchSize: CGSize

    var body: some View {
        HStack(spacing: 0) {
            CompanionMessengerFace(mood: .content, activity: session.phase == .focus ? .focusing : .resting) {
                Image(systemName: session.phase == .focus ? "timer" : "cup.and.saucer.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
            }
            .frame(width: NotchMetrics.sneakPeekSideWidth)

            Color.clear
                .frame(width: notchSize.width)

            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                Text(PlaybackTimeFormatter.string(from: session.remaining(at: timeline.date)))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(session.isPaused ? .white.opacity(0.5) : color)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: NotchMetrics.sneakPeekSideWidth)
        }
        .frame(height: notchSize.height)
    }

    private var color: Color {
        session.phase == .focus ? FocusColor.focus : FocusColor.rest
    }
}

/// Flashes around the closed notch when a focus session or a break comes to an end.
struct FocusSneakPeekView: View {
    let event: FocusTimer.Event
    let notchSize: CGSize

    @State private var hasAppeared = false

    var body: some View {
        HStack(spacing: 0) {
            CompanionMessengerFace {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FocusColor.focus)
            }
            .frame(width: NotchMetrics.sneakPeekSideWidth)

            Color.clear
                .frame(width: notchSize.width)

            Image(systemName: event == .focusFinished ? "checkmark.seal.fill" : "play.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(event == .focusFinished ? FocusColor.focus : .white)
                .symbolEffect(.bounce, value: hasAppeared)
                .frame(width: NotchMetrics.sneakPeekSideWidth)
        }
        .frame(height: notchSize.height)
        .onAppear { hasAppeared = true }
    }
}
