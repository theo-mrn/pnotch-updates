//
//  Constants.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Defaults
import Foundation

extension Defaults.Keys {
    // MARK: General

    static let menubarIcon = Key<Bool>("menubarIcon", default: true)
    static let openNotchOnHover = Key<Bool>("openNotchOnHover", default: true)
    static let minimumHoverDuration = Key<TimeInterval>("minimumHoverDuration", default: 0.2)
    static let enableHaptics = Key<Bool>("enableHaptics", default: true)
    /// The page the notch was left on.
    static let lastNotchPage = Key<NotchPage>("lastNotchPage", default: .music)
    /// The page the notch opens on; `nil` reopens the last one used.
    static let startPage = Key<NotchPage?>("startPage", default: nil)
    static let tabOrder = Key<[NotchPage]>("tabOrder", default: NotchPage.allCases)
    static let hiddenTabs = Key<Set<NotchPage>>("hiddenTabs", default: [])

    // MARK: Music

    static let showMusicLiveActivity = Key<Bool>("showMusicLiveActivity", default: true)

    // MARK: Companion

    static let companionName = Key<String>("companionName", default: "Pixel")
    static let companionAppearance = Key<RobotAppearance>("companionAppearance", default: RobotAppearance())
    /// The day the robot was first shown, for "together for N days".
    static let companionBirthDate = Key<Date?>("companionBirthDate", default: nil)
    static let companionPetCount = Key<Int>("companionPetCount", default: 0)
    /// Copies the robot has caught and delivered since it arrived.
    static let companionCopyCount = Key<Int>("companionCopyCount", default: 0)
    /// The robot lives in the header of every page, not only on its own.
    static let companionOnEveryPage = Key<Bool>("companionOnEveryPage", default: true)
    /// The robot's face announces news around the closed notch: copies, Claude Code done or waiting.
    static let companionAnnouncesCopies = Key<Bool>("companionAnnouncesCopies", default: true)

    // MARK: Focus

    static let focusRhythm = Key<FocusRhythm>("focusRhythm", default: .short)
    /// The session or break in progress, kept across launches.
    static let focusSession = Key<FocusSession?>("focusSession", default: nil)
    static let focusLog = Key<FocusLog?>("focusLog", default: nil)
    /// A chime when a focus session or a break ends.
    static let focusPlaysSound = Key<Bool>("focusPlaysSound", default: true)

    // MARK: Claude Code

    /// The closed notch shows when a Claude Code session works or waits for you.
    static let showClaudeCodeLiveActivity = Key<Bool>("showClaudeCodeLiveActivity", default: true)
    /// A sneak peek when a Claude Code session is done.
    static let announceClaudeCode = Key<Bool>("announceClaudeCode", default: true)
    /// Permission requests wait for an answer in the notch while the session's terminal isn't in front.
    static let claudeCodeAnswersInNotch = Key<Bool>("claudeCodeAnswersInNotch", default: true)

    // MARK: Clipboard

    static let clipboardHistoryLimit = Key<Int>("clipboardHistoryLimit", default: 200)
    static let fetchLinkPreviews = Key<Bool>("fetchLinkPreviews", default: true)
    static let showCopySneakPeek = Key<Bool>("showCopySneakPeek", default: true)
    static let closeNotchAfterCopy = Key<Bool>("closeNotchAfterCopy", default: true)
    /// Choosing an item pastes it into the app in use (needs the Accessibility permission), ⌥ only copies.
    static let pasteDirectly = Key<Bool>("pasteDirectly", default: true)
}

/// History sizes offered in Settings.
let clipboardHistoryLimitOptions = [50, 100, 200, 500]

extension NotchPage: Defaults.Serializable {}
