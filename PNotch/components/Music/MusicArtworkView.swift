//
//  MusicArtworkView.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// Album cover with the player's icon as a badge. It recedes a little when paused, like in Music.
struct MusicArtworkView: View {
    var size: CGFloat = MusicMetrics.artworkSize
    var cornerRadius: CGFloat = MusicMetrics.artworkCornerRadius
    var showsAppBadge = true

    @Environment(MusicManager.self) private var music

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        Group {
            if let artwork = music.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                MusicArtworkPlaceholder(symbolSize: size * 0.32)
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: music.accentColor.opacity(music.artwork == nil ? 0 : 0.35), radius: size * 0.12, y: size * 0.04)
        .overlay(alignment: .bottomTrailing) {
            if showsAppBadge, let bundleIdentifier = music.playback?.bundleIdentifier ?? music.lastPlayerBundleIdentifier {
                SourceAppIcon(app: SourceApplication(bundleIdentifier: bundleIdentifier, name: ""), size: size * 0.22)
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                    .offset(x: size * 0.06, y: size * 0.06)
            }
        }
        .scaleEffect(music.isPlaying || music.playback == nil ? 1 : 0.93)
        .animation(.spring(response: 0.4, dampingFraction: 0.72), value: music.isPlaying)
    }
}

struct MusicArtworkPlaceholder: View {
    let symbolSize: CGFloat

    var body: some View {
        LinearGradient(
            colors: [Color(hex: 0x3A3A3C), Color(hex: 0x1C1C1E)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: "music.note")
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
        }
    }
}
