//
//  Focus.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Defaults
import Foundation

/// How long to focus, then rest, in a row.
nonisolated enum FocusRhythm: String, CaseIterable, Codable, Sendable, Defaults.Serializable {
    /// 25 minutes of focus, 5 of rest: the classic Pomodoro.
    case short
    /// 50 minutes of focus, 10 of rest, for deep work.
    case long

    var focusDuration: TimeInterval {
        switch self {
        case .short: 25 * 60
        case .long: 50 * 60
        }
    }

    var breakDuration: TimeInterval {
        switch self {
        case .short: 5 * 60
        case .long: 10 * 60
        }
    }
}

/// A running focus session or break. Kept in the preferences, so it survives quitting PNotch.
nonisolated struct FocusSession: Equatable, Codable, Sendable, Defaults.Serializable {
    enum Phase: String, Codable, Sendable {
        case focus
        /// The break after a focus session.
        case rest
    }

    var phase: Phase
    var startedAt: Date
    var duration: TimeInterval
    /// Time that was left when it was paused. `nil` while running.
    var pausedRemaining: TimeInterval?

    static func focus(rhythm: FocusRhythm, at date: Date) -> FocusSession {
        FocusSession(phase: .focus, startedAt: date, duration: rhythm.focusDuration)
    }

    static func rest(rhythm: FocusRhythm, at date: Date) -> FocusSession {
        FocusSession(phase: .rest, startedAt: date, duration: rhythm.breakDuration)
    }

    var isPaused: Bool {
        pausedRemaining != nil
    }

    func remaining(at date: Date) -> TimeInterval {
        if let pausedRemaining {
            return pausedRemaining
        }
        return max(duration - date.timeIntervalSince(startedAt), 0)
    }

    /// 0 at the start, 1 when the time is up.
    func progress(at date: Date) -> Double {
        guard duration > 0 else { return 1 }
        return 1 - remaining(at: date) / duration
    }

    func isOver(at date: Date) -> Bool {
        !isPaused && remaining(at: date) <= 0
    }

    mutating func pause(at date: Date) {
        guard !isPaused else { return }
        pausedRemaining = remaining(at: date)
    }

    /// Picks up where it was paused: the start moves forward by the time spent paused.
    mutating func resume(at date: Date) {
        guard let pausedRemaining else { return }
        startedAt = date.addingTimeInterval(pausedRemaining - duration)
        self.pausedRemaining = nil
    }
}

/// The day's focus: how many sessions were completed, for how long.
nonisolated struct FocusLog: Equatable, Codable, Sendable, Defaults.Serializable {
    /// The start of the day it counts.
    var day: Date
    var completedSessions = 0
    var focusedTime: TimeInterval = 0

    static func empty(at date: Date, calendar: Calendar = .current) -> FocusLog {
        FocusLog(day: calendar.startOfDay(for: date))
    }

    /// The log for the day of `date`: a fresh one once the day has changed.
    func today(at date: Date, calendar: Calendar = .current) -> FocusLog {
        calendar.isDate(day, inSameDayAs: date) ? self : .empty(at: date, calendar: calendar)
    }

    func recording(_ duration: TimeInterval, at date: Date, calendar: Calendar = .current) -> FocusLog {
        var log = today(at: date, calendar: calendar)
        log.completedSessions += 1
        log.focusedTime += duration
        return log
    }
}

/// What happens when the clock runs out.
nonisolated enum FocusTimer {
    enum Event: Equatable, Sendable {
        /// A focus session was completed: the break begins.
        case focusFinished
        /// The break is over: ready for the next session.
        case breakFinished
    }

    struct Step: Equatable, Sendable {
        var session: FocusSession?
        var log: FocusLog
        var event: Event?
    }

    /// Moves on once the current phase is over: focus leads to a break, which leads back to idle.
    /// The break starts when the focus ended, even if PNotch only notices later.
    static func advance(_ session: FocusSession?, log: FocusLog, rhythm: FocusRhythm, at date: Date, calendar: Calendar = .current) -> Step {
        guard let session, session.isOver(at: date) else {
            return Step(session: session, log: log, event: nil)
        }
        let end = session.startedAt.addingTimeInterval(session.duration)
        switch session.phase {
        case .focus:
            let rest = FocusSession.rest(rhythm: rhythm, at: end)
            let log = log.recording(session.duration, at: end, calendar: calendar)
            // Away for longer than the break too: skip straight to idle.
            if rest.isOver(at: date) {
                return Step(session: nil, log: log, event: .breakFinished)
            }
            return Step(session: rest, log: log, event: .focusFinished)
        case .rest:
            return Step(session: nil, log: log, event: .breakFinished)
        }
    }
}
