//
//  generic.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation

enum NotchState {
    case closed
    case open
}

/// Why the notch was opened. It decides how the notch is allowed to close on its own.
enum NotchOpenReason {
    /// The pointer rested on the notch.
    case hover
    /// The user clicked the closed notch.
    case click
    /// The global shortcut or the menu bar item.
    case keyboard
    /// The user launched PNotch: the notch introduces itself until the next click elsewhere.
    case launch
}

/// Why the notch folded back. Logged, to make unexpected closings easy to trace.
enum NotchCloseReason {
    case pointerLeft
    case clickOutside
    case escape
    case shortcut
    case copied
    case pasted
    case settings
    /// The user jumped to another app from the notch, e.g. to a Claude Code session.
    case switchedApp
}

/// Pages of the opened notch, picked with the tabs of its header.
nonisolated enum NotchPage: String, CaseIterable, Sendable {
    case music
    case clipboard
    case system
    case companion
    case claudeCode
}

/// What the opened notch shows, which decides its size.
nonisolated enum NotchLayout: Equatable, Sendable {
    case music
    case system
    case companion
    case claudeCode
    /// The searchable list, shrinking around `itemCount` results.
    case clipboardList(itemCount: Int)
}
