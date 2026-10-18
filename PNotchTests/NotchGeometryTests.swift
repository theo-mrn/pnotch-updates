//
//  NotchGeometryTests.swift
//  PNotchTests
//
//  Created by Theo Morin on 17/10/2026.
//

import CoreGraphics
import Foundation
import Testing
@testable import PNotch

struct NotchGeometryTests {
    /// 14" MacBook Pro at its default resolution.
    private let macBookPro14 = NotchGeometry(
        screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        physicalNotchSize: CGSize(width: 185, height: 32)
    )

    @Test func usesThePhysicalNotch() {
        #expect(macBookPro14.hasPhysicalNotch)
        #expect(macBookPro14.closedSize == CGSize(width: 185, height: 32))
    }

    @Test func fallsBackToADrawnNotch() {
        let externalDisplay = NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 2560, height: 1440), physicalNotchSize: nil)

        #expect(!externalDisplay.hasPhysicalNotch)
        #expect(externalDisplay.closedSize == NotchMetrics.fallbackNotchSize)
    }

    @Test func clipboardIsAListAsWideAsTheOtherPages() {
        let list = macBookPro14.openedSize(for: .clipboardList(itemCount: .max))

        #expect(list.width == ClipboardListMetrics.width)
        #expect(list.width == MusicMetrics.width)
        // It grows with the results, up to six rows; the empty state gets two.
        #expect(macBookPro14.openedSize(for: .clipboardList(itemCount: 2)).height < list.height)
        #expect(macBookPro14.openedSize(for: .clipboardList(itemCount: 0)).height == macBookPro14.openedSize(for: .clipboardList(itemCount: 2)).height)
        #expect(macBookPro14.windowFrame.height >= list.height)
    }

    @Test func windowIsNoWiderThanTheWidestPage() {
        let overflow = NotchCornerRadii.opened.top + NotchMetrics.shadowPadding
        #expect(macBookPro14.windowFrame.width == SystemMetricsLayout.width + 2 * overflow)
    }

    @Test func musicIsACompactPlayer() {
        let music = macBookPro14.openedSize(for: .music)

        #expect(music.width == MusicMetrics.width)
        #expect(music.width < macBookPro14.openedSize(for: .system).width)
        #expect(macBookPro14.windowFrame.height >= music.height)
    }

    @Test func systemFitsItsTilesAndTheWindow() {
        let system = macBookPro14.openedSize(for: .system)

        #expect(system.width == SystemMetricsLayout.width)
        #expect(macBookPro14.windowFrame.width >= system.width)
        #expect(macBookPro14.windowFrame.height >= system.height)
    }

    @Test func companionLeavesRoomForTheRobot() {
        let companion = macBookPro14.openedSize(for: .companion)
        #expect(companion == CGSize(width: CompanionMetrics.width, height: 32 + CompanionMetrics.bodyHeight))
        #expect(CompanionMetrics.robotSize.height < CompanionMetrics.bodyHeight)
        #expect(macBookPro14.windowFrame.width >= companion.width)
        #expect(macBookPro14.windowFrame.height >= companion.height)
    }

    @Test func claudeCodeFitsItsRowsAndTheWindow() {
        let claudeCode = macBookPro14.openedSize(for: .claudeCode)
        #expect(claudeCode == CGSize(width: ClaudeCodeMetrics.width, height: 32 + ClaudeCodeMetrics.bodyHeight))
        // Three sessions are visible without scrolling.
        let rows = 3 * ClaudeCodeMetrics.rowHeight + 2 * ClaudeCodeMetrics.rowSpacing + 2 * ClaudeCodeMetrics.verticalPadding
        #expect(rows <= ClaudeCodeMetrics.bodyHeight)
        #expect(macBookPro14.windowFrame.height >= claudeCode.height)
    }

    @Test func headerWingsHoldTheTabsSideAndTheRobotSide() {
        // Right of the camera: the robot, up to two page buttons (the clipboard's) and settings.
        let buttons = CompanionMetrics.headerRobotSize.width + 4 + 3 * NotchHeaderMetrics.controlHeight + 3 * 6
        for layout in [NotchLayout.music, .system, .companion, .claudeCode, .clipboardList(itemCount: 3)] {
            let width = macBookPro14.openedSize(for: layout).width
            let wing = (width - 2 * NotchHeaderMetrics.horizontalPadding - 185 - NotchMetrics.cameraClearance) / 2
            #expect(buttons <= wing, "\(layout)")
        }
    }

    @Test func windowHangsFromTheTopCenterOfItsScreen() {
        let secondaryDisplay = NotchGeometry(
            screenFrame: CGRect(x: 1512, y: 200, width: 1920, height: 1080),
            physicalNotchSize: nil
        )
        let frame = secondaryDisplay.windowFrame

        #expect(frame.maxY == secondaryDisplay.screenFrame.maxY)
        #expect(frame.midX == secondaryDisplay.screenFrame.midX)
        #expect(frame.width <= secondaryDisplay.screenFrame.width)
        #expect(frame.height >= secondaryDisplay.openedSize(for: .clipboardList(itemCount: .max)).height)
    }
}

struct RelativeTimeFormatterTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test(arguments: [
        (5.0, "now"),
        (59.0, "now"),
        (60.0, "1m"),
        (45 * 60.0, "45m"),
        (3 * 3600.0, "3h"),
        (2 * 86400.0, "2d"),
    ])
    func formatsRecentDates(secondsAgo: TimeInterval, expected: String) {
        let string = RelativeTimeFormatter.string(
            for: now.addingTimeInterval(-secondsAgo),
            relativeTo: now,
            locale: Locale(identifier: "en_US")
        )
        #expect(string == expected)
    }

    @Test func formatsOlderDatesAsADay() {
        let date = Date(timeIntervalSince1970: 15 * 86400) // Mid-January 1970, whatever the time zone.
        let twoMonthsLater = date.addingTimeInterval(60 * 86400)
        let string = RelativeTimeFormatter.string(for: date, relativeTo: twoMonthsLater, locale: Locale(identifier: "en_US"))
        #expect(string.contains("Jan"))
    }
}
