//
//  MediaControllerProtocol.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation

/// A source of "Now Playing" information that can also drive the player.
protocol MediaControllerProtocol: AnyObject {
    /// Called on the main actor whenever playback changes; `nil` when nothing is playing.
    var onPlaybackChange: ((PlaybackState?) -> Void)? { get set }

    func start()
    func stop()
    func send(_ command: MediaCommand)
    func seek(to position: TimeInterval)
}

/// MediaRemote command identifiers (`MRMediaRemoteCommand`).
nonisolated enum MediaCommand: Int, Sendable {
    case play = 0
    case pause = 1
    case togglePlayPause = 2
    case nextTrack = 4
    case previousTrack = 5
}
