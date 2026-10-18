//
//  PlaybackState.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation

/// What the system "Now Playing" reports: track, position and the app playing it.
nonisolated struct PlaybackState: Equatable, Sendable {
    var title: String
    var artist: String
    var album: String
    /// Zero for live streams and media without a known length.
    var duration: TimeInterval
    /// Position at `timestamp`. Players only report it when it jumps (play, pause, seek).
    var elapsedTime: TimeInterval
    var timestamp: Date
    var playbackRate: Double
    var isPlaying: Bool
    /// The app to show and to open: the browser for web players rather than its helper process.
    var bundleIdentifier: String?
    var artworkData: Data?

    init(
        title: String,
        artist: String = "",
        album: String = "",
        duration: TimeInterval = 0,
        elapsedTime: TimeInterval = 0,
        timestamp: Date = .now,
        playbackRate: Double = 1,
        isPlaying: Bool = false,
        bundleIdentifier: String? = nil,
        artworkData: Data? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.timestamp = timestamp
        self.playbackRate = playbackRate
        self.isPlaying = isPlaying
        self.bundleIdentifier = bundleIdentifier
        self.artworkData = artworkData
    }

    var hasKnownDuration: Bool {
        duration > 0
    }

    /// Position extrapolated to `date` from the last report, kept within the track.
    func position(at date: Date) -> TimeInterval {
        var position = elapsedTime
        if isPlaying {
            position += date.timeIntervalSince(timestamp) * playbackRate
        }
        return hasKnownDuration ? min(max(position, 0), duration) : max(position, 0)
    }

    /// Freezes or resumes the clock locally, before the player confirms.
    func with(isPlaying playing: Bool, at date: Date = .now) -> PlaybackState {
        var state = self
        state.elapsedTime = position(at: date)
        state.timestamp = date
        state.isPlaying = playing
        return state
    }

    func seeking(to position: TimeInterval, at date: Date = .now) -> PlaybackState {
        var state = self
        state.elapsedTime = hasKnownDuration ? min(max(position, 0), duration) : max(position, 0)
        state.timestamp = date
        return state
    }
}
