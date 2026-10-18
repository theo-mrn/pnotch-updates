//
//  MusicTests.swift
//  PNotchTests
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation
import Testing
@testable import PNotch

struct NowPlayingStreamParserTests {
    @Test func readsAFullPayload() throws {
        let artwork = Data([0x89, 0x50, 0x4E, 0x47]).base64EncodedString()
        let line = """
        {"type":"data","diff":false,"payload":{"title":"Windowlicker","artist":"Aphex Twin","album":"Windowlicker",\
        "playing":true,"playbackRate":1,"durationMicros":367000000,"elapsedTimeMicros":61500000,\
        "timestampEpochMicros":1760695200000000,"bundleIdentifier":"com.apple.WebKit.GPU",\
        "parentApplicationBundleIdentifier":"com.apple.Safari","artworkData":"\(artwork)"}}
        """

        guard case let .update(playback?) = NowPlayingStreamParser.parse(line) else {
            Issue.record("Expected a playback update")
            return
        }
        #expect(playback.title == "Windowlicker")
        #expect(playback.artist == "Aphex Twin")
        #expect(playback.duration == 367)
        #expect(playback.elapsedTime == 61.5)
        #expect(playback.timestamp == Date(timeIntervalSince1970: 1_760_695_200))
        #expect(playback.isPlaying)
        #expect(playback.bundleIdentifier == "com.apple.Safari")
        #expect(playback.artworkData == Data([0x89, 0x50, 0x4E, 0x47]))
    }

    @Test func emptyPayloadMeansNothingIsPlaying() {
        #expect(NowPlayingStreamParser.parse(#"{"type":"data","diff":false,"payload":{}}"#) == .update(nil))
    }

    @Test func mediaWithoutTitleIsIgnored() {
        let line = #"{"type":"data","diff":false,"payload":{"title":"  ","playing":true}}"#
        #expect(NowPlayingStreamParser.parse(line) == .update(nil))
    }

    @Test func readsGetSnapshots() {
        #expect(NowPlayingStreamParser.parseSnapshot("null\n") == .update(nil))

        let snapshot = #"{"title":"Song","playing":false,"durationMicros":120000000,"elapsedTimeMicros":30000000}"#
        guard case let .update(playback?) = NowPlayingStreamParser.parseSnapshot(snapshot) else {
            Issue.record("Expected a playback update")
            return
        }
        #expect(!playback.isPlaying)
        #expect(playback.elapsedTime == 30)
    }

    @Test(arguments: ["", "not json", #"{"type":"error","message":"boom"}"#])
    func otherLinesAreSkipped(line: String) {
        #expect(NowPlayingStreamParser.parse(line) == nil)
    }
}

struct PlaybackStateTests {
    private let start = Date(timeIntervalSince1970: 1000)

    @Test func positionAdvancesWhilePlaying() {
        let playback = PlaybackState(title: "Song", duration: 200, elapsedTime: 30, timestamp: start, isPlaying: true)
        #expect(playback.position(at: start.addingTimeInterval(12)) == 42)
    }

    @Test func positionIsFrozenWhilePaused() {
        let playback = PlaybackState(title: "Song", duration: 200, elapsedTime: 30, timestamp: start, isPlaying: false)
        #expect(playback.position(at: start.addingTimeInterval(12)) == 30)
    }

    @Test func positionStaysWithinTheTrack() {
        let playback = PlaybackState(title: "Song", duration: 200, elapsedTime: 195, timestamp: start, isPlaying: true)
        #expect(playback.position(at: start.addingTimeInterval(60)) == 200)
    }

    @Test func pausingKeepsTheCurrentPosition() {
        let playing = PlaybackState(title: "Song", duration: 200, elapsedTime: 30, timestamp: start, isPlaying: true)
        let paused = playing.with(isPlaying: false, at: start.addingTimeInterval(10))

        #expect(!paused.isPlaying)
        #expect(paused.position(at: start.addingTimeInterval(100)) == 40)
    }
}

@MainActor
struct MusicManagerTests {
    private final class FakeController: MediaControllerProtocol {
        var onPlaybackChange: ((PlaybackState?) -> Void)?
        private(set) var sentCommands: [MediaCommand] = []
        private(set) var seekPositions: [TimeInterval] = []

        func start() {}
        func stop() {}
        func send(_ command: MediaCommand) {
            sentCommands.append(command)
        }
        func seek(to position: TimeInterval) {
            seekPositions.append(position)
        }
    }

    @Test func reflectsWhatThePlayerReports() {
        let controller = FakeController()
        let music = MusicManager(controller: controller)

        controller.onPlaybackChange?(PlaybackState(title: "Song", isPlaying: true, bundleIdentifier: "com.spotify.client"))

        #expect(music.isPlaying)
        #expect(music.lastPlayerBundleIdentifier == "com.spotify.client")

        controller.onPlaybackChange?(nil)
        #expect(music.playback == nil)
        #expect(music.lastPlayerBundleIdentifier == "com.spotify.client")
    }

    @Test func playPauseUpdatesTheUIBeforeThePlayerAnswers() {
        let controller = FakeController()
        let music = MusicManager(controller: controller)
        controller.onPlaybackChange?(PlaybackState(title: "Song", duration: 100, isPlaying: true))

        music.togglePlayPause()

        #expect(!music.isPlaying)
        #expect(controller.sentCommands == [.togglePlayPause])
    }

    @Test func keepsTheCoverWhenAReportLeavesItOut() {
        let controller = FakeController()
        let music = MusicManager(controller: controller)
        let cover = Data([1, 2, 3])
        controller.onPlaybackChange?(PlaybackState(title: "Song", artist: "Band", isPlaying: true, artworkData: cover))

        controller.onPlaybackChange?(PlaybackState(title: "Song", artist: "Band", isPlaying: false))
        #expect(music.playback?.artworkData == cover)

        controller.onPlaybackChange?(PlaybackState(title: "Other song", artist: "Band", isPlaying: true))
        #expect(music.playback?.artworkData == nil)
    }

    @Test func playWithNothingReportedResumesTheLastPlayer() {
        let controller = FakeController()
        let music = MusicManager(controller: controller)

        music.togglePlayPause()

        #expect(controller.sentCommands == [.play])
    }

    @Test func seekingMovesThePositionRightAway() throws {
        let controller = FakeController()
        let music = MusicManager(controller: controller)
        controller.onPlaybackChange?(PlaybackState(title: "Song", duration: 100, elapsedTime: 10, isPlaying: false))

        music.seek(to: 64)

        #expect(controller.seekPositions == [64])
        #expect(try #require(music.playback).position(at: .now) == 64)
    }
}

struct PlaybackTimeFormatterTests {
    @Test(arguments: [(0.0, "0:00"), (7.9, "0:07"), (187, "3:07"), (3765, "1:02:45"), (-4, "0:00")])
    func formatsLikePlayers(seconds: TimeInterval, expected: String) {
        #expect(PlaybackTimeFormatter.string(from: seconds) == expected)
    }
}
