//
//  FocusTests.swift
//  PNotchTests
//
//  Created by Theo Morin on 17/10/2026.
//

import Defaults
import Foundation
import Testing
@testable import PNotch

struct FocusSessionTests {
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func countsDown() {
        let session = FocusSession.focus(rhythm: .short, at: start)
        #expect(session.remaining(at: start) == 25 * 60)
        #expect(session.remaining(at: start + 60) == 24 * 60)
        #expect(session.progress(at: start + 12.5 * 60) == 0.5)
        #expect(!session.isOver(at: start + 24 * 60))
        #expect(session.isOver(at: start + 25 * 60))
        #expect(session.remaining(at: start + 40 * 60) == 0)
    }

    @Test func pausesAndResumesWhereItWas() {
        var session = FocusSession.focus(rhythm: .short, at: start)
        session.pause(at: start + 10 * 60)
        // Paused for an hour: no time passes, and it never runs out.
        #expect(session.remaining(at: start + 70 * 60) == 15 * 60)
        #expect(!session.isOver(at: start + 70 * 60))

        session.resume(at: start + 70 * 60)
        #expect(!session.isPaused)
        #expect(session.remaining(at: start + 75 * 60) == 10 * 60)
    }

    @Test func rhythms() {
        #expect(FocusRhythm.short.focusDuration == 25 * 60)
        #expect(FocusRhythm.short.breakDuration == 5 * 60)
        #expect(FocusRhythm.long.focusDuration == 50 * 60)
        #expect(FocusRhythm.long.breakDuration == 10 * 60)
    }
}

struct FocusTimerTests {
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let calendar = Calendar(identifier: .gregorian)

    @Test func focusLeadsToABreakThenToIdle() {
        let log = FocusLog.empty(at: start, calendar: calendar)
        let session = FocusSession.focus(rhythm: .short, at: start)

        let running = FocusTimer.advance(session, log: log, rhythm: .short, at: start + 60, calendar: calendar)
        #expect(running == FocusTimer.Step(session: session, log: log, event: nil))

        // Noticed 30 s late: the break still starts when the focus ended.
        let finished = FocusTimer.advance(session, log: log, rhythm: .short, at: start + 25 * 60 + 30, calendar: calendar)
        #expect(finished.event == .focusFinished)
        #expect(finished.session?.phase == .rest)
        #expect(finished.session?.startedAt == start + 25 * 60)
        #expect(finished.log.completedSessions == 1)
        #expect(finished.log.focusedTime == 25 * 60)

        let rested = FocusTimer.advance(finished.session, log: finished.log, rhythm: .short, at: start + 30 * 60, calendar: calendar)
        #expect(rested.event == .breakFinished)
        #expect(rested.session == nil)
        #expect(rested.log.completedSessions == 1)
    }

    @Test func comingBackLongAfterSkipsTheBreak() {
        let log = FocusLog.empty(at: start, calendar: calendar)
        let session = FocusSession.focus(rhythm: .short, at: start)
        let step = FocusTimer.advance(session, log: log, rhythm: .short, at: start + 3 * 3600, calendar: calendar)
        #expect(step.session == nil)
        #expect(step.event == .breakFinished)
        // The session was completed all the same.
        #expect(step.log.completedSessions == 1)
    }

    @Test func pausedSessionsNeverEnd() {
        var session = FocusSession.focus(rhythm: .short, at: start)
        session.pause(at: start + 60)
        let log = FocusLog.empty(at: start, calendar: calendar)
        #expect(FocusTimer.advance(session, log: log, rhythm: .short, at: start + 3600, calendar: calendar).event == nil)
    }

    @Test func eachDayStartsAFreshLog() {
        let log = FocusLog.empty(at: start, calendar: calendar).recording(25 * 60, at: start, calendar: calendar)
        #expect(log.today(at: start + 3600, calendar: calendar) == log)

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: start)!
        #expect(log.today(at: tomorrow, calendar: calendar).completedSessions == 0)
        #expect(log.recording(50 * 60, at: tomorrow, calendar: calendar).focusedTime == 50 * 60)
    }
}

@MainActor
struct FocusManagerTests {
    private final class Clock {
        var now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    }

    @Test func runsASessionAndItsBreak() throws {
        // The manager keeps its state in the preferences: restore them afterwards.
        let saved = (Defaults[.focusSession], Defaults[.focusLog], Defaults[.focusRhythm])
        defer {
            Defaults[.focusSession] = saved.0
            Defaults[.focusLog] = saved.1
            Defaults[.focusRhythm] = saved.2
        }
        Defaults[.focusSession] = nil
        Defaults[.focusLog] = nil
        Defaults[.focusRhythm] = .short

        let clock = Clock()
        let focus = FocusManager { clock.now }
        var events: [FocusTimer.Event] = []
        focus.onEvent = { events.append($0) }

        focus.startFocus()
        #expect(focus.runningPhase == .focus)
        clock.now += 10 * 60
        focus.pause()
        #expect(focus.runningPhase == nil)
        clock.now += 60 * 60
        focus.tick()
        #expect(events.isEmpty)

        focus.resume()
        clock.now += 15 * 60
        focus.tick()
        #expect(events == [.focusFinished])
        #expect(focus.runningPhase == .rest)
        #expect(focus.today.completedSessions == 1)

        // A new manager, as after relaunching PNotch, picks the break up.
        let relaunched = FocusManager { clock.now }
        #expect(relaunched.session == focus.session)

        clock.now += 5 * 60
        focus.tick()
        #expect(events == [.focusFinished, .breakFinished])
        #expect(focus.session == nil)
    }

    @Test func stoppingDoesntCount() {
        let saved = (Defaults[.focusSession], Defaults[.focusLog])
        defer {
            Defaults[.focusSession] = saved.0
            Defaults[.focusLog] = saved.1
        }
        Defaults[.focusSession] = nil
        Defaults[.focusLog] = nil

        let clock = Clock()
        let focus = FocusManager { clock.now }
        focus.startFocus()
        clock.now += 20 * 60
        focus.cancel()
        focus.tick()
        #expect(focus.session == nil)
        #expect(focus.today.completedSessions == 0)
    }
}
