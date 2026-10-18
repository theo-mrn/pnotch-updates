//
//  CompanionManager.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import CoreGraphics
import Defaults
import Foundation
import Observation

/// The robot companion's life: what it reacts to, and the bond it keeps with the user.
@Observable
final class CompanionManager {
    private(set) var lastPetDate: Date?
    /// The last news the robot brought, and when.
    private(set) var lastNews: (kind: CompanionNews, date: Date)?

    @ObservationIgnored let music: MusicManager
    @ObservationIgnored let system: SystemMonitor
    @ObservationIgnored private var idleTimeCache: (date: Date, value: TimeInterval)?

    init(music: MusicManager, system: SystemMonitor) {
        self.music = music
        self.system = system
        if Defaults[.companionBirthDate] == nil {
            Defaults[.companionBirthDate] = .now
        }
    }

    func context(at date: Date = .now) -> CompanionContext {
        CompanionContext(
            date: date,
            isMusicPlaying: music.isPlaying,
            cpuUsage: system.cpu?.total,
            thermalState: system.thermalState,
            idleTime: idleTime(at: date),
            lastPetDate: lastPetDate,
            lastNewsDate: lastNews?.date
        )
    }

    func mood(at date: Date = .now) -> CompanionMood {
        CompanionMood.resolve(context(at: date))
    }

    var daysTogether: Int {
        CompanionFriendship.daysTogether(since: Defaults[.companionBirthDate] ?? .now)
    }

    // MARK: Interactions

    func pet() {
        lastPetDate = .now
        Defaults[.companionPetCount] += 1
    }

    func noteCopy() {
        bring(.copy)
        Defaults[.companionCopyCount] += 1
    }

    /// The robot jumps and its face announces the news around the closed notch.
    func bring(_ news: CompanionNews) {
        lastNews = (news, .now)
    }

    /// Time since the last pet or news, while the robot is still reacting to it.
    func reactionElapsed(at date: Date) -> TimeInterval? {
        let latest = [lastPetDate, lastNews?.date].compactMap { $0 }.max()
        guard let latest else { return nil }
        let elapsed = date.timeIntervalSince(latest)
        return elapsed < CompanionMood.reactionDuration ? elapsed : nil
    }

    // MARK: Private

    /// Seconds since the last keyboard, mouse or trackpad event anywhere. Needs no permission.
    /// Read at most once a second: the robot asks on every frame.
    private func idleTime(at date: Date) -> TimeInterval {
        if let cache = idleTimeCache, date.timeIntervalSince(cache.date) < 1 {
            return cache.value + date.timeIntervalSince(cache.date)
        }
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        let value = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
        idleTimeCache = (date, value)
        return value
    }
}
