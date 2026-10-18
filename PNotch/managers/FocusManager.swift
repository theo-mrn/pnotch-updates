//
//  FocusManager.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Defaults
import Foundation
import Observation

/// Focus sessions with the companion: a session, then a break, then ready for the next one.
@Observable
final class FocusManager {
    private(set) var session: FocusSession?
    private(set) var log: FocusLog

    /// A session or a break came to an end.
    @ObservationIgnored var onEvent: ((FocusTimer.Event) -> Void)?
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var ticking: Task<Void, Never>?

    init(now: @escaping () -> Date = { .now }) {
        self.now = now
        session = Defaults[.focusSession]
        log = (Defaults[.focusLog] ?? .empty(at: now())).today(at: now())
    }

    var rhythm: FocusRhythm {
        get { Defaults[.focusRhythm] }
        set { Defaults[.focusRhythm] = newValue }
    }

    /// The day's log, fresh after midnight.
    var today: FocusLog {
        log.today(at: now())
    }

    /// What the companion is busy with, while the clock runs.
    var runningPhase: FocusSession.Phase? {
        guard let session, !session.isPaused else { return nil }
        return session.phase
    }

    // MARK: Lifecycle

    /// Catches up with a session that ended while PNotch was closed, then follows the clock.
    func start() {
        tick()
        followClock()
    }

    func stop() {
        ticking?.cancel()
        ticking = nil
    }

    // MARK: Controls

    func startFocus() {
        update(.focus(rhythm: rhythm, at: now()))
    }

    func pause() {
        guard var session else { return }
        session.pause(at: now())
        update(session)
    }

    func resume() {
        guard var session else { return }
        session.resume(at: now())
        update(session)
    }

    /// Ends the focus session or the break early. An interrupted session isn't counted.
    func cancel() {
        update(nil)
    }

    /// Checks the clock: called every second while a session runs.
    func tick() {
        let step = FocusTimer.advance(session, log: log, rhythm: rhythm, at: now())
        guard let event = step.event else { return }
        log = step.log
        Defaults[.focusLog] = step.log
        update(step.session)
        onEvent?(event)
    }

    // MARK: Private

    private func update(_ session: FocusSession?) {
        self.session = session
        Defaults[.focusSession] = session
    }

    private func followClock() {
        ticking?.cancel()
        ticking = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.tick()
            }
        }
    }
}
