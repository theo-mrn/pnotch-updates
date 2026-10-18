//
//  NotchGeometry.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import CoreGraphics

/// Sizes and screen-space rectangles of the notch on a given display.
///
/// Every rectangle is expressed in AppKit global coordinates (origin at the bottom-left of the primary display).
nonisolated struct NotchGeometry: Equatable, Sendable {
    let screenFrame: CGRect
    /// Size of the camera housing, or `NotchMetrics.fallbackNotchSize` on displays without one.
    let notchSize: CGSize
    let hasPhysicalNotch: Bool

    init(screenFrame: CGRect, physicalNotchSize: CGSize?) {
        self.screenFrame = screenFrame
        if let physicalNotchSize, physicalNotchSize.width > 0, physicalNotchSize.height > 0 {
            notchSize = physicalNotchSize
            hasPhysicalNotch = true
        } else {
            notchSize = NotchMetrics.fallbackNotchSize
            hasPhysicalNotch = false
        }
    }

    var closedSize: CGSize {
        notchSize
    }

    var hoveredSize: CGSize {
        CGSize(
            width: notchSize.width + NotchMetrics.hoverGrowth.width,
            height: notchSize.height + NotchMetrics.hoverGrowth.height
        )
    }

    var sneakPeekSize: CGSize {
        CGSize(width: notchSize.width + NotchMetrics.sneakPeekSideWidth * 2, height: notchSize.height)
    }

    func openedSize(for layout: NotchLayout) -> CGSize {
        switch layout {
        case .music:
            return CGSize(
                width: min(MusicMetrics.width, screenFrame.width - 40),
                height: notchSize.height + MusicMetrics.bodyHeight
            )
        case .companion:
            return CGSize(
                width: min(CompanionMetrics.width, screenFrame.width - 40),
                height: notchSize.height + CompanionMetrics.bodyHeight
            )
        case .claudeCode:
            return CGSize(
                width: min(ClaudeCodeMetrics.width, screenFrame.width - 40),
                height: notchSize.height + ClaudeCodeMetrics.bodyHeight
            )
        case .system:
            return CGSize(
                width: min(SystemMetricsLayout.width, screenFrame.width - 40),
                height: notchSize.height + SystemMetricsLayout.bodyHeight
            )
        case let .clipboardList(itemCount):
            return CGSize(
                width: min(ClipboardListMetrics.width, screenFrame.width - 40),
                height: notchSize.height
                    + ClipboardListMetrics.bodyHeight(rows: ClipboardListMetrics.visibleRows(forItemCount: itemCount))
            )
        }
    }

    /// Screen area covered by the opened notch, ears included.
    func openedScreenRect(for layout: NotchLayout) -> CGRect {
        let size = openedSize(for: layout)
        return screenRect(for: CGSize(width: size.width + NotchCornerRadii.opened.top * 2, height: size.height))
    }

    /// Frame of the transparent window hosting the notch: large enough for every opened layout,
    /// their ears and their shadow.
    var windowFrame: CGRect {
        let largest = [NotchLayout.music, .system, .companion, .claudeCode, .clipboardList(itemCount: .max)].map(openedSize(for:))
        let horizontalOverflow = NotchCornerRadii.opened.top + NotchMetrics.shadowPadding
        let size = CGSize(
            width: min(largest.map(\.width).max()! + horizontalOverflow * 2, screenFrame.width),
            height: largest.map(\.height).max()! + NotchMetrics.shadowPadding
        )
        return CGRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    /// Screen rectangle of a notch body of `size`, hanging from the top-center of the display.
    func screenRect(for size: CGSize) -> CGRect {
        CGRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }
}
