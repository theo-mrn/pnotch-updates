//
//  CompanionTests.swift
//  PNotchTests
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation
import SwiftUI
import Testing
@testable import PNotch

struct CompanionMoodTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    /// 17 October 2026, at the given time in Paris.
    private static func date(hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: hour, minute: minute))!
    }

    /// A calm afternoon: nothing playing, a quiet processor, the user at the keyboard.
    private static func context(
        at date: Date = date(hour: 14),
        music: Bool = false,
        cpu: Double? = 0.2,
        thermal: ProcessInfo.ThermalState = .nominal,
        idle: TimeInterval = 3,
        petAgo: TimeInterval? = nil,
        newsAgo: TimeInterval? = nil
    ) -> CompanionContext {
        CompanionContext(
            date: date,
            isMusicPlaying: music,
            cpuUsage: cpu,
            thermalState: thermal,
            idleTime: idle,
            lastPetDate: petAgo.map { date.addingTimeInterval(-$0) },
            lastNewsDate: newsAgo.map { date.addingTimeInterval(-$0) },
            calendar: calendar
        )
    }

    @Test func isContentByDefault() {
        #expect(CompanionMood.resolve(Self.context()) == .content)
        #expect(CompanionMood.resolve(Self.context(cpu: nil)) == .content)
    }

    @Test func reactsToTheUserFirst() {
        // A pet wins over everything, even a copy, a hot Mac and music at night.
        let everything = Self.context(at: Self.date(hour: 2), music: true, cpu: 0.99, thermal: .critical, idle: 900, petAgo: 0.5, newsAgo: 0.2)
        #expect(CompanionMood.resolve(everything) == .loved)

        let copied = Self.context(music: true, cpu: 0.99, newsAgo: 1)
        #expect(CompanionMood.resolve(copied) == .excited)
    }

    @Test func reactionsWearOff() {
        let justAfter = CompanionMood.reactionDuration + 0.01
        #expect(CompanionMood.resolve(Self.context(petAgo: justAfter)) == .content)
        #expect(CompanionMood.resolve(Self.context(newsAgo: justAfter)) == .content)
    }

    @Test func overheatsWithABusyOrHotMac() {
        #expect(CompanionMood.resolve(Self.context(cpu: CompanionMood.busyCPUThreshold)) == .hot)
        #expect(CompanionMood.resolve(Self.context(thermal: .serious)) == .hot)
        #expect(CompanionMood.resolve(Self.context(thermal: .fair)) == .content)
        // Being hot beats dancing.
        #expect(CompanionMood.resolve(Self.context(music: true, cpu: 0.9)) == .hot)
    }

    @Test func dancesToMusicEvenAtNight() {
        #expect(CompanionMood.resolve(Self.context(music: true)) == .dancing)
        #expect(CompanionMood.resolve(Self.context(at: Self.date(hour: 1), music: true, idle: 900)) == .dancing)
    }

    @Test func dozesOffLateOrWhenLeftAlone() {
        #expect(CompanionMood.resolve(Self.context(at: Self.date(hour: 23))) == .sleepy)
        #expect(CompanionMood.resolve(Self.context(at: Self.date(hour: 5, minute: 59))) == .sleepy)
        #expect(CompanionMood.resolve(Self.context(at: Self.date(hour: 6))) == .content)
        #expect(CompanionMood.resolve(Self.context(idle: CompanionMood.idleThreshold)) == .sleepy)
        #expect(CompanionMood.resolve(Self.context(idle: CompanionMood.idleThreshold - 1)) == .content)
    }
}

struct CompanionFriendshipTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    private func date(_ day: Int, _ month: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test func countsCalendarDaysFromTheFirstOne() {
        #expect(CompanionFriendship.daysTogether(since: date(17, 10, 9), now: date(17, 10, 23, 59), calendar: calendar) == 1)
        #expect(CompanionFriendship.daysTogether(since: date(17, 10, 23, 50), now: date(18, 10, 0, 5), calendar: calendar) == 2)
    }

    @Test func survivesDaylightSavingAndClockChanges() {
        // Clocks went forward in Paris on 29 March 2026: that day had 23 hours.
        #expect(CompanionFriendship.daysTogether(since: date(28, 3, 23, 30), now: date(30, 3, 0, 10), calendar: calendar) == 3)
        // A clock set back before the first meeting doesn't give a day 0.
        #expect(CompanionFriendship.daysTogether(since: date(17, 10, 12), now: date(15, 10, 12), calendar: calendar) == 1)
    }
}

struct RobotTests {
    @Test func appearanceSurvivesARoundTrip() throws {
        let appearance = RobotAppearance(bodyColor: .coral, eyeColor: .amber, accessory: .crown)
        let data = try JSONEncoder().encode(appearance)
        #expect(try JSONDecoder().decode(RobotAppearance.self, from: data) == appearance)
    }

    @Test func posesArePureFunctionsOfTime() {
        for mood in [CompanionMood.content, .dancing, .hot, .sleepy, .excited, .loved] {
            let first = RobotAnimator.pose(mood: mood, time: 1234.5, gaze: CGVector(dx: 0.3, dy: -0.2), sinceReaction: 0.4)
            let second = RobotAnimator.pose(mood: mood, time: 1234.5, gaze: CGVector(dx: 0.3, dy: -0.2), sinceReaction: 0.4)
            #expect(first == second)
        }
    }

    @Test func blinksBrieflyEveryFewSeconds() {
        let samples = stride(from: 0.0, to: 36, by: 0.01).map(RobotAnimator.blink(at:))
        #expect(samples.allSatisfy { (0 ... 1).contains($0) })

        // About one blink per 3.6 s period, each lasting a fraction of a second.
        let closings = zip(samples, samples.dropFirst()).filter { $0 == 0 && $1 > 0 }.count
        #expect((9 ... 11).contains(closings))
        let closedShare = Double(samples.filter { $0 > 0 }.count) / Double(samples.count)
        #expect(closedShare < 0.06)
    }

    @Test func jumpsThenLandsWhenCopying() {
        let hop = RobotAnimator.pose(mood: .excited, time: 10, gaze: .zero, sinceReaction: 0.225)
        #expect(hop.bob < -11)
        #expect(hop.squash > 1)

        let landing = RobotAnimator.pose(mood: .excited, time: 10, gaze: .zero, sinceReaction: 0.6)
        #expect(landing.squash < 1)

        let settled = RobotAnimator.pose(mood: .excited, time: 10, gaze: .zero, sinceReaction: 1.5)
        #expect(settled.squash == 1)
        #expect(abs(settled.bob) <= 2.5)
    }

    @Test func overscanKeepsTheRobotInItsSlot() {
        let padding = RobotRenderer.overscanPadding(fitting: RobotRenderer.designSize)
        #expect(padding.top == -RobotRenderer.overscan.top)
        #expect(padding.leading == -RobotRenderer.overscan.leading)

        // Scales with the slot's limiting side: the companion page's slot is height-bound.
        let slot = CompanionMetrics.robotSize
        let scale = slot.height / RobotRenderer.designSize.height
        let scaled = RobotRenderer.overscanPadding(fitting: slot)
        #expect(abs(scaled.trailing + RobotRenderer.overscan.trailing * scale) < 0.001)
    }
}

struct CompanionActivityTests {
    private typealias Inputs = CompanionActivity.Inputs

    @Test func eachPageGivesItSomethingToDo() {
        #expect(CompanionActivity.resolve(Inputs(page: .music, isMusicPlaying: true)) == .listening)
        // Paused or nothing playing: headphones on all the same, waiting for a song.
        #expect(CompanionActivity.resolve(Inputs(page: .music)) == .waitingForMusic)

        // It always reads the clipboard; only a search that finds nothing puzzles it.
        #expect(CompanionActivity.resolve(Inputs(page: .clipboard)) == .reading)
        #expect(CompanionActivity.resolve(Inputs(page: .clipboard, searchQuery: "invoice", searchResultCount: 3)) == .reading)
        #expect(CompanionActivity.resolve(Inputs(page: .clipboard, searchQuery: "zzz", searchResultCount: 0)) == .puzzled)
        #expect(CompanionActivity.resolve(Inputs(page: .clipboard, searchQuery: "  ", searchResultCount: 0)) == .reading)

        #expect(CompanionActivity.resolve(Inputs(page: .system)) == .wiring)

        #expect(CompanionActivity.resolve(Inputs(page: .claudeCode)) == .terminal)
        #expect(CompanionActivity.resolve(Inputs(page: .claudeCode, isClaudeCodeWorking: true)) == .thinking)
        // Waiting for you beats working, even with other sessions busy.
        #expect(CompanionActivity.resolve(Inputs(page: .claudeCode, isClaudeCodeWorking: true, claudeCodeNeedsYou: true)) == .alert)
    }

    @Test func focusesWithYouOnItsPage() {
        #expect(CompanionActivity.resolve(Inputs(page: .companion, focusPhase: .focus)) == .focusing)
        #expect(CompanionActivity.resolve(Inputs(page: .companion, focusPhase: .rest)) == .resting)
        #expect(CompanionActivity.resolve(Inputs(page: .companion)) == nil)
        // The other pages keep their own activity during a session.
        #expect(CompanionActivity.resolve(Inputs(page: .system, focusPhase: .focus)) == .wiring)
    }

    @Test func activitiesStayOnTheirPage() {
        let everything = Inputs(
            page: .companion, isMusicPlaying: true, searchQuery: "x", isClaudeCodeWorking: true, claudeCodeNeedsYou: true
        )
        #expect(CompanionActivity.resolve(everything) == nil)

        var onMusic = everything
        onMusic.page = .music
        #expect(CompanionActivity.resolve(onMusic) == .listening)
    }

    @Test func showsTheProcessorsLoad() {
        #expect(CompanionLoadLevel(cpuUsage: 0.2) == .calm)
        #expect(CompanionLoadLevel(cpuUsage: 0.5) == .busy)
        #expect(CompanionLoadLevel(cpuUsage: CompanionMood.busyCPUThreshold) == .strained)
    }

    @Test func reactionsComeBeforeThePage() {
        let petted = RobotAnimator.pose(mood: .loved, activity: .reading, time: 3, gaze: .zero, sinceReaction: 0.5)
        #expect(petted.expression == .love)

        let reading = RobotAnimator.pose(mood: .content, activity: .reading, time: 3, gaze: .zero, sinceReaction: nil)
        #expect(reading.expression == .reading)
        // Even hot, it reads along.
        #expect(RobotAnimator.pose(mood: .hot, activity: .reading, time: 3, gaze: .zero, sinceReaction: nil).expression == .reading)
    }

    @Test func listeningIsDancing() {
        let listening = RobotAnimator.pose(mood: .content, activity: .listening, time: 7.3, gaze: .zero, sinceReaction: nil)
        let dancing = RobotAnimator.pose(mood: .dancing, time: 7.3, gaze: .zero, sinceReaction: nil)
        #expect(listening == dancing)
    }

    @Test func readingSweepsAlongTheLine() {
        let gazes = stride(from: 0.0, to: 3, by: 0.1).map {
            RobotAnimator.pose(mood: .content, activity: .reading, time: $0, gaze: CGVector(dx: 1, dy: -1), sinceReaction: nil).gaze
        }
        // The pointer doesn't matter: the eyes go left and right, looking down at the text.
        #expect(gazes.map(\.dx).min()! < -0.5)
        #expect(gazes.map(\.dx).max()! > 0.5)
        #expect(gazes.allSatisfy { $0.dy > 0 })
    }

    @Test func alertShakesThenHoldsStill() {
        let shaking = RobotAnimator.pose(mood: .content, activity: .alert, time: 0.1, gaze: .zero, sinceReaction: nil)
        let still = RobotAnimator.pose(mood: .content, activity: .alert, time: 1, gaze: .zero, sinceReaction: nil)
        #expect(shaking.sway != 0)
        #expect(still.sway == 0)
        #expect(still.expression == .excited)
    }
}

struct CompanionCablesTests {
    @Test func tugsNowAndThen() {
        let samples = stride(from: 0.0, to: CompanionCables.tugPeriod * 4, by: 0.05).map(CompanionCables.tug(at:))
        #expect(samples.allSatisfy { (0 ... 1).contains($0) })
        #expect(samples.max()! > 0.95)
        // Mostly at rest: the tugs are short.
        let pulling = Double(samples.filter { $0 > 0 }.count) / Double(samples.count)
        #expect(pulling < 0.2)
    }

    @Test func leansBackWhenPulling() {
        let midTug = CompanionCables.tugDuration / 2
        let pulling = RobotAnimator.pose(mood: .content, activity: .wiring, time: midTug, gaze: .zero, sinceReaction: nil)
        let resting = RobotAnimator.pose(mood: .content, activity: .wiring, time: CompanionCables.tugPeriod / 2, gaze: .zero, sinceReaction: nil)
        #expect(pulling.headTilt.degrees > resting.headTilt.degrees)
        #expect(pulling.expression == .hot)
        #expect(resting.expression == .neutral)
    }

    @Test func networkTrafficShowsOnALogScale() {
        #expect(CompanionCables.networkFlow(bytesPerSecond: 0) == 0)
        let kilobytes = CompanionCables.networkFlow(bytesPerSecond: 5_000)
        let megabytes = CompanionCables.networkFlow(bytesPerSecond: 5_000_000)
        #expect(kilobytes > 0.1)
        #expect(megabytes > kilobytes)
        #expect(CompanionCables.networkFlow(bytesPerSecond: 1e12) == 1)
        #expect(CompanionCables.packetSpeed(flow: 1) > CompanionCables.packetSpeed(flow: 0))
    }

    @Test func cablesComeUpToThePlugFromBelowTheFrame() {
        let plug = CompanionCables.plug(tug: 0)
        let cables = (0 ..< 4).map { CompanionCables.cable($0, of: 4, tug: 0) }
        for cable in cables {
            #expect(cable.start.y == plug.maxY - 1)
            #expect((plug.minX ... plug.maxX).contains(cable.start.x))
            // They leave the robot's frame at the bottom: nothing spills over the page.
            #expect(cable.end.y > RobotRenderer.bustBounds.maxY)
        }
        // Fanned out evenly, left to right.
        #expect(cables.map(\.end.x) == cables.map(\.end.x).sorted())
        #expect(abs((cables[0].end.x + cables[3].end.x) / 2 - plug.midX) < 0.001)
    }

    @Test func aTugLiftsThePlugAndStraightensTheCables() {
        #expect(CompanionCables.plug(tug: 1).minY < CompanionCables.plug(tug: 0).minY)
        let resting = CompanionCables.cable(0, of: 4, tug: 0)
        let pulled = CompanionCables.cable(0, of: 4, tug: 1)
        #expect(pulled.control1.y - pulled.start.y < resting.control1.y - resting.start.y)
    }
}
