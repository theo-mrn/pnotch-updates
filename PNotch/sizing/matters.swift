//
//  matters.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import CoreGraphics

/// Corner radii fed to `NotchShape` for each notch state.
nonisolated struct NotchCornerRadii: Equatable, Sendable {
    let top: CGFloat
    let bottom: CGFloat

    static let closed = NotchCornerRadii(top: 6, bottom: 14)
    static let sneakPeek = NotchCornerRadii(top: 8, bottom: 16)
    static let opened = NotchCornerRadii(top: 14, bottom: 30)
}

nonisolated enum NotchMetrics {
    /// Used on displays without a camera housing, where PNotch draws its own notch.
    static let fallbackNotchSize = CGSize(width: 190, height: 32)
    /// Room left below the opened notch so its shadow is not clipped by the window.
    static let shadowPadding: CGFloat = 36
    /// Width added on each side of the notch while a sneak peek is shown.
    static let sneakPeekSideWidth: CGFloat = 40
    /// Growth of the closed notch while the pointer rests on it.
    static let hoverGrowth = CGSize(width: 14, height: 3)
    /// Free space kept around the camera housing in the opened header.
    static let cameraClearance: CGFloat = 28
}

nonisolated enum MusicMetrics {
    static let width: CGFloat = 640
    static let bodyHeight: CGFloat = 156
    static let artworkSize: CGFloat = 120
    static let artworkCornerRadius: CGFloat = 16
    static let horizontalPadding: CGFloat = 22
}

nonisolated enum SystemMetricsLayout {
    static let tileCount = 6
    static let tileSize = CGSize(width: 132, height: 122)
    static let tileSpacing: CGFloat = 10
    static let tileCornerRadius: CGFloat = 14
    static let horizontalPadding: CGFloat = 18
    static let bodyHeight: CGFloat = 146

    static var width: CGFloat {
        let tiles = CGFloat(tileCount)
        return tiles * tileSize.width + (tiles - 1) * tileSpacing + horizontalPadding * 2
    }
}

nonisolated enum CompanionMetrics {
    static let width: CGFloat = 640
    static let bodyHeight: CGFloat = 156
    static let robotSize = CGSize(width: 150, height: 142)
    /// The bust in the header of the other pages, as tall as the header allows.
    static let headerRobotSize = CGSize(width: 40, height: 30)
    static let horizontalPadding: CGFloat = 22
}

nonisolated enum ClaudeCodeMetrics {
    static let width: CGFloat = 640
    static let bodyHeight: CGFloat = 156
    /// Three sessions fit without scrolling.
    static let rowHeight: CGFloat = 42
    static let rowSpacing: CGFloat = 6
    static let rowCornerRadius: CGFloat = 12
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 8
}

nonisolated enum ClipboardListMetrics {
    /// As wide as the music, companion and Claude Code pages.
    static let width: CGFloat = 640
    static let searchHeight: CGFloat = 50
    static let rowHeight: CGFloat = 56
    static let rowSpacing: CGFloat = 6
    static let rowCornerRadius: CGFloat = 12
    static let thumbnailSize: CGFloat = 40
    static let horizontalPadding: CGFloat = 10
    /// Same as `rowSpacing`, so the visible rows fill the list exactly, without a sliver of the next one.
    static let verticalPadding: CGFloat = 6
    /// Keeps the scrolling rows clear of the notch's rounded bottom corners.
    static let bottomInset: CGFloat = 10
    static let maxVisibleRows = 6

    /// Rows the list makes room for: one per result up to `maxVisibleRows`, two for the empty state.
    static func visibleRows(forItemCount count: Int) -> Int {
        count == 0 ? 2 : min(count, maxVisibleRows)
    }

    static func bodyHeight(rows: Int) -> CGFloat {
        let rows = CGFloat(rows)
        return searchHeight + 1 + verticalPadding * 2 + rows * rowHeight + max(rows - 1, 0) * rowSpacing + bottomInset
    }
}

/// The top row of every page, level with the menu bar.
nonisolated enum NotchHeaderMetrics {
    static let horizontalPadding: CGFloat = 18
    /// Tabs and buttons.
    static let controlHeight: CGFloat = 24
}
