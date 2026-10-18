//
//  NowPlayingStreamParser.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation

/// Decodes the JSON lines printed by `mediaremote-adapter.pl stream --no-diff --micros`:
///
/// ```json
/// {"type":"data","diff":false,"payload":{"title":"…","playing":true,"durationMicros":…}}
/// ```
///
/// An empty payload means nothing is playing.
nonisolated enum NowPlayingStreamParser {
    enum Event: Equatable, Sendable {
        case update(PlaybackState?)
    }

    /// - Returns: `nil` for lines that aren't now playing data.
    static func parse(_ line: String) -> Event? {
        guard let data = line.data(using: .utf8),
              let message = try? JSONDecoder().decode(Message.self, from: data),
              message.type == "data"
        else { return nil }

        return .update(message.payload.flatMap(PlaybackState.init(payload:)))
    }

    /// Decodes the output of `mediaremote-adapter.pl get --micros`: the payload itself, or `null`.
    static func parseSnapshot(_ output: String) -> Event? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "null" {
            return .update(nil)
        }
        guard let data = trimmed.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return nil }
        return .update(PlaybackState(payload: payload))
    }

    private struct Message: Decodable {
        let type: String
        let payload: Payload?
    }

    fileprivate struct Payload: Decodable {
        let title: String?
        let artist: String?
        let album: String?
        let playing: Bool?
        let playbackRate: Double?
        let durationMicros: Double?
        let elapsedTimeMicros: Double?
        let timestampEpochMicros: Double?
        let bundleIdentifier: String?
        let parentApplicationBundleIdentifier: String?
        let artworkData: String?
    }
}

private extension PlaybackState {
    nonisolated init?(payload: NowPlayingStreamParser.Payload) {
        guard let title = payload.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return nil
        }

        let timestamp = payload.timestampEpochMicros.map { Date(timeIntervalSince1970: $0 / 1_000_000) } ?? .now
        let artwork = payload.artworkData.flatMap { Data(base64Encoded: $0, options: .ignoreUnknownCharacters) }

        self.init(
            title: title,
            artist: payload.artist ?? "",
            album: payload.album ?? "",
            duration: (payload.durationMicros ?? 0) / 1_000_000,
            elapsedTime: (payload.elapsedTimeMicros ?? 0) / 1_000_000,
            timestamp: timestamp,
            playbackRate: payload.playbackRate ?? 1,
            isPlaying: payload.playing ?? false,
            bundleIdentifier: payload.parentApplicationBundleIdentifier ?? payload.bundleIdentifier,
            artworkData: artwork
        )
    }
}
