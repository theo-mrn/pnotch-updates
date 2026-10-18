//
//  MusicManager.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import AppKit
import Observation
import SwiftUI

/// Now playing state shown by the notch, and the playback actions it offers.
@Observable
final class MusicManager {
    private(set) var playback: PlaybackState?
    private(set) var artwork: NSImage?
    /// Accent derived from the artwork, white when there is none.
    private(set) var accentColor: Color = .white
    /// The player last seen, kept after it quits so the notch can still offer to open it.
    private(set) var lastPlayerBundleIdentifier: String?

    @ObservationIgnored private let controller: MediaControllerProtocol
    @ObservationIgnored private var artworkTask: Task<Void, Never>?

    init(controller: MediaControllerProtocol = NowPlayingController()) {
        self.controller = controller
        controller.onPlaybackChange = { [weak self] playback in
            self?.apply(playback)
        }
    }

    var isPlaying: Bool {
        playback?.isPlaying == true
    }

    func start() {
        controller.start()
    }

    func stop() {
        controller.stop()
    }

    // MARK: Actions

    /// Updates the UI right away; the player's own report follows a moment later.
    func togglePlayPause() {
        guard let playback else {
            // Nothing reported: asks the last player to resume.
            controller.send(.play)
            return
        }
        self.playback = playback.with(isPlaying: !playback.isPlaying)
        controller.send(.togglePlayPause)
    }

    func nextTrack() {
        controller.send(.nextTrack)
    }

    func previousTrack() {
        controller.send(.previousTrack)
    }

    func seek(to position: TimeInterval) {
        guard let playback else { return }
        self.playback = playback.seeking(to: position)
        controller.seek(to: position)
    }

    func openPlayer() {
        guard let bundleIdentifier = playback?.bundleIdentifier ?? lastPlayerBundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: Updates

    private func apply(_ reported: PlaybackState?) {
        var newPlayback = reported
        // Some reports leave the cover out: keep it as long as the track is the same.
        if newPlayback?.artworkData == nil, let current = playback,
           newPlayback?.title == current.title, newPlayback?.artist == current.artist {
            newPlayback?.artworkData = current.artworkData
        }

        let artworkChanged = newPlayback?.artworkData != playback?.artworkData
        playback = newPlayback
        if let bundleIdentifier = newPlayback?.bundleIdentifier {
            lastPlayerBundleIdentifier = bundleIdentifier
        }
        if artworkChanged {
            updateArtwork(from: newPlayback?.artworkData)
        }
    }

    /// Artwork is decoded and analysed off the main actor: a full-size cover can weigh a few megabytes.
    private func updateArtwork(from data: Data?) {
        artworkTask?.cancel()
        guard let data else {
            withAnimation(.smooth) {
                artwork = nil
                accentColor = .white
            }
            return
        }

        artworkTask = Task { [weak self] in
            let decoded = await Task.detached(priority: .userInitiated) {
                (ImageProcessing.thumbnail(from: data, maxPixelSize: 512), ArtworkPalette.accentColor(of: data))
            }.value
            guard let self, !Task.isCancelled else { return }

            withAnimation(.smooth) {
                artwork = decoded.0.map { NSImage(cgImage: $0.cgImage, size: .zero) }
                accentColor = decoded.1.map(Color.init(nsColor:)) ?? .white
            }
        }
    }
}
