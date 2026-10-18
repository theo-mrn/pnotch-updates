//
//  Companion.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Defaults
import Foundation

// MARK: - Appearance

/// How the robot companion looks. Chosen on its page, saved in the preferences.
nonisolated struct RobotAppearance: Codable, Equatable, Sendable, Defaults.Serializable {
    var bodyColor: RobotBodyColor = .silver
    var eyeColor: RobotEyeColor = .cyan
    var accessory: RobotAccessory = .none
}

nonisolated enum RobotBodyColor: String, CaseIterable, Codable, Sendable {
    case silver
    case mint
    case coral
    case sky
    case lemon
    case lavender
    case graphite
}

nonisolated enum RobotEyeColor: String, CaseIterable, Codable, Sendable {
    case cyan
    case green
    case amber
    case pink
    case white
}

nonisolated enum RobotAccessory: String, CaseIterable, Codable, Sendable {
    case none
    case headphones
    case crown
    case glasses
    case flower
}

// MARK: - Mood

/// What the robot feels, from what happens on the Mac. Drives its face, motion and particles.
nonisolated enum CompanionMood: Equatable, Sendable {
    /// Calm, looking around.
    case content
    /// Music is playing.
    case dancing
    /// The processor is busy or the Mac runs hot.
    case hot
    /// Late at night, or the user has been away for a while.
    case sleepy
    /// It just brought news: a copy, Claude Code done or waiting for you.
    case excited
    /// The user just petted it.
    case loved

    /// How long a pet or a copy keeps the robot reacting.
    static let reactionDuration: TimeInterval = 2.2
    static let busyCPUThreshold = 0.85
    static let idleThreshold: TimeInterval = 5 * 60

    /// Reacting to a pet or to news: nothing else shows meanwhile.
    var isReaction: Bool {
        self == .loved || self == .excited
    }

    /// Reactions to the user come first, then the Mac's state, then the time of day.
    static func resolve(_ context: CompanionContext) -> CompanionMood {
        if let pet = context.lastPetDate, context.date.timeIntervalSince(pet) < reactionDuration {
            return .loved
        }
        if let news = context.lastNewsDate, context.date.timeIntervalSince(news) < reactionDuration {
            return .excited
        }
        if context.thermalState == .serious || context.thermalState == .critical
            || (context.cpuUsage ?? 0) >= busyCPUThreshold {
            return .hot
        }
        if context.isMusicPlaying {
            return .dancing
        }
        let hour = context.calendar.component(.hour, from: context.date)
        if context.idleTime >= idleThreshold || hour >= 23 || hour < 6 {
            return .sleepy
        }
        return .content
    }
}

/// Everything the robot's mood depends on, at a given moment.
nonisolated struct CompanionContext: Sendable {
    var date: Date
    var isMusicPlaying: Bool
    var cpuUsage: Double?
    var thermalState: ProcessInfo.ThermalState
    /// Time since the last keyboard or mouse event, system-wide.
    var idleTime: TimeInterval
    var lastPetDate: Date?
    var lastNewsDate: Date?
    var calendar: Calendar = .current
}

/// What the robot announces, as the messenger of the notch.
nonisolated enum CompanionNews: Equatable, Sendable {
    case copy
    case claudeCodeFinished
    case claudeCodeNeedsYou
    /// A new song started while it listens on the music page.
    case newTrack
    /// A focus session was completed.
    case focusDone
    /// The break is over.
    case breakOver
}

// MARK: - Page activities

/// What the robot does on the page it's on, on top of its mood: each page gives it something to do.
/// Its reactions to a pet or to news still come first.
nonisolated enum CompanionActivity: Equatable, Sendable {
    /// Music: headphones on, dancing, notes in the cover's color.
    case listening
    /// Music, paused or nothing playing: headphones on, nodding gently while it waits for a song.
    case waitingForMusic
    /// Clipboard: reads the clipboard it holds, eyes going along the lines.
    case reading
    /// Clipboard: the search found nothing.
    case puzzled
    /// System: wired to the metric tiles, it tugs at the cables now and then.
    case wiring
    /// Claude Code, no session busy: its visor turns into a terminal waiting for a command.
    case terminal
    /// Claude Code: a session is working, Claude's star twinkling in its eyes.
    case thinking
    /// Claude Code: a session waits for you. A click on the robot takes you there.
    case alert
    /// Its own page, during a focus session: headband on, concentrating with you.
    case focusing
    /// Its own page, during the break: a cup of something warm.
    case resting

    struct Inputs: Sendable {
        var page: NotchPage
        var isMusicPlaying = false
        var searchQuery = ""
        var searchResultCount = 0
        var isClaudeCodeWorking = false
        var claudeCodeNeedsYou = false
        /// The focus phase running, if any.
        var focusPhase: FocusSession.Phase?
    }

    static func resolve(_ inputs: Inputs) -> CompanionActivity? {
        switch inputs.page {
        case .music:
            return inputs.isMusicPlaying ? .listening : .waitingForMusic
        case .clipboard:
            let isSearching = !inputs.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
            return isSearching && inputs.searchResultCount == 0 ? .puzzled : .reading
        case .system:
            return .wiring
        case .claudeCode:
            if inputs.claudeCodeNeedsYou {
                return .alert
            }
            return inputs.isClaudeCodeWorking ? .thinking : .terminal
        case .companion:
            switch inputs.focusPhase {
            case .focus: return .focusing
            case .rest: return .resting
            case nil: return nil
            }
        }
    }
}

/// How hard the processor works, shown by the antenna bulb on the System page.
nonisolated enum CompanionLoadLevel: Equatable, Sendable {
    case calm
    case busy
    case strained

    init(cpuUsage: Double) {
        switch cpuUsage {
        case ..<0.5: self = .calm
        case ..<CompanionMood.busyCPUThreshold: self = .busy
        default: self = .strained
        }
    }
}

// MARK: - Friendship

nonisolated enum CompanionFriendship {
    /// Whole days since the robot was first met, counting the first day as day 1.
    static func daysTogether(since birthDate: Date, now: Date = .now, calendar: Calendar = .current) -> Int {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: birthDate), to: calendar.startOfDay(for: now)).day ?? 0
        return max(days, 0) + 1
    }
}
