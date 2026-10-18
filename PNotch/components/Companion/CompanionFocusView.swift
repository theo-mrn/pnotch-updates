//
//  CompanionFocusView.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Defaults
import SwiftUI

/// Focus sessions with the companion: the rhythm, the countdown and its controls, and the day so far.
struct CompanionFocusView: View {
    @Environment(CompanionManager.self) private var companion
    @Environment(FocusManager.self) private var focus
    @Default(.companionName) private var name
    @Default(.companionPetCount) private var petCount
    @Default(.focusRhythm) private var rhythm

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let date = timeline.date
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(moodLine(at: date))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    FocusRhythmPicker(selection: $rhythm)
                        .disabled(focus.session != nil)
                        .opacity(focus.session != nil ? 0.4 : 1)
                }

                Spacer(minLength: 6)

                HStack(alignment: .center, spacing: 16) {
                    Text(PlaybackTimeFormatter.string(from: remaining(at: date)))
                        .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.smooth, value: remaining(at: date))

                    VStack(alignment: .leading, spacing: 7) {
                        Text(phaseTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(phaseColor)
                        FocusProgressBar(progress: focus.session?.progress(at: date) ?? 0, color: phaseColor)
                            .frame(width: 150, height: 6)
                    }

                    Spacer(minLength: 0)

                    controls
                }

                Spacer(minLength: 6)

                Text(caption)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(1)
            }
            .padding(.vertical, 14)
        }
    }

    // MARK: Countdown

    private func remaining(at date: Date) -> TimeInterval {
        focus.session?.remaining(at: date) ?? rhythm.focusDuration
    }

    private var phaseTitle: String {
        guard let session = focus.session else { return String(localized: "Ready to focus?") }
        if session.isPaused {
            return String(localized: "Paused")
        }
        return session.phase == .focus ? String(localized: "Focus") : String(localized: "Break")
    }

    private var phaseColor: Color {
        guard let session = focus.session, !session.isPaused else { return .white.opacity(0.55) }
        return session.phase == .focus ? FocusColor.focus : FocusColor.rest
    }

    @ViewBuilder
    private var controls: some View {
        if let session = focus.session {
            HStack(spacing: 8) {
                switch (session.phase, session.isPaused) {
                case (.focus, false):
                    FocusControlButton(systemImage: "pause.fill", help: "Pause") { focus.pause() }
                case (.focus, true):
                    FocusControlButton(systemImage: "play.fill", help: "Resume") { focus.resume() }
                case (.rest, _):
                    FocusControlButton(systemImage: "forward.end.fill", help: "Skip the break") { focus.cancel() }
                }
                if session.phase == .focus {
                    FocusControlButton(systemImage: "stop.fill", help: "Stop") { focus.cancel() }
                }
            }
        } else {
            Button {
                focus.startFocus()
            } label: {
                Label("Start", systemImage: "play.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(FocusColor.focus.opacity(0.9), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Words

    /// The day so far, and your bond.
    private var caption: String {
        let today = focus.today
        let minutes = Int(today.focusedTime / 60)
        return [
            String(localized: "\(today.completedSessions) sessions today"),
            String(localized: "\(minutes) min of focus"),
            String(localized: "\(companion.daysTogether) days together"),
            String(localized: "\(petCount) pets"),
        ].joined(separator: " · ")
    }

    private func moodLine(at date: Date) -> String {
        let mood = companion.mood(at: date)
        if mood == .excited, let news = companion.lastNews?.kind {
            switch news {
            case .focusDone: return String(localized: "\(name) is proud of you!")
            case .breakOver: return String(localized: "\(name) is ready when you are.")
            case .claudeCodeFinished: return String(localized: "\(name) says Claude Code is done.")
            case .claudeCodeNeedsYou: return String(localized: "\(name) says Claude Code needs you.")
            case .newTrack: return String(localized: "\(name) likes this song.")
            case .copy: return String(localized: "\(name) caught your copy!")
            }
        }
        if let session = focus.session {
            if session.isPaused {
                return String(localized: "\(name) is waiting for you.")
            }
            return session.phase == .focus
                ? String(localized: "\(name) is focusing with you.")
                : String(localized: "\(name) is taking a break too.")
        }

        switch mood {
        case .content, .excited:
            return String(localized: "\(name) is keeping an eye on your Mac.")
        case .dancing:
            if let title = companion.music.playback?.title {
                return String(localized: "\(name) is dancing to “\(title)”.")
            }
            return String(localized: "\(name) is dancing.")
        case .hot:
            if let cpu = companion.system.cpu?.total, cpu >= CompanionMood.busyCPUThreshold {
                return String(localized: "\(name) is overheating: CPU at \(MetricFormatter.percent(cpu)).")
            }
            return String(localized: "\(name) is overheating: the Mac is running hot.")
        case .sleepy:
            let hour = Calendar.current.component(.hour, from: date)
            if hour >= 23 || hour < 6 {
                return String(localized: "It's late, \(name) is dozing off.")
            }
            return String(localized: "\(name) dozed off while you were away.")
        case .loved:
            return String(localized: "\(name) loves that.")
        }
    }
}

// MARK: - Pieces

enum FocusColor {
    /// The headband's red.
    static let focus = Color(hex: 0xFF6B6F)
    static let rest = Color(hex: 0x34C77B)
}

/// 25 / 5 or 50 / 10.
private struct FocusRhythmPicker: View {
    @Binding var selection: FocusRhythm

    var body: some View {
        HStack(spacing: 2) {
            ForEach(FocusRhythm.allCases, id: \.self) { rhythm in
                Button {
                    selection = rhythm
                } label: {
                    Text(verbatim: "\(Int(rhythm.focusDuration / 60))/\(Int(rhythm.breakDuration / 60))")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(selection == rhythm ? 1 : 0.5))
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                        .background {
                            if selection == rhythm {
                                Capsule().fill(.white.opacity(0.16))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(.white.opacity(0.06), in: Capsule())
        .help("Minutes of focus, then of break")
    }
}

private struct FocusProgressBar: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule()
                    .fill(color)
                    .frame(width: max(proxy.size.width * min(max(progress, 0), 1), progress > 0 ? proxy.size.height : 0))
            }
        }
        .animation(.linear(duration: 1), value: progress)
    }
}

private struct FocusControlButton: View {
    let systemImage: String
    let help: LocalizedStringKey
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(.white.opacity(isHovered ? 0.2 : 0.12)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
    }
}
