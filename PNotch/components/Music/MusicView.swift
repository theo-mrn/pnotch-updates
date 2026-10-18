//
//  MusicView.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// The music page of the opened notch: what is playing, where it is, and the controls.
struct MusicView: View {
    @Environment(MusicManager.self) private var music

    var body: some View {
        VStack(spacing: 0) {
            NotchHeaderView()

            HStack(spacing: 20) {
                MusicArtworkView()
                    .onTapGesture { music.openPlayer() }
                    .help("Open the player")

                VStack(alignment: .leading, spacing: 0) {
                    trackInfo
                    Spacer(minLength: 10)
                    MusicProgressView()
                    Spacer(minLength: 4)
                    MusicControlsView()
                        .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: MusicMetrics.artworkSize)
            }
            .padding(.horizontal, MusicMetrics.horizontalPadding)
            .frame(height: MusicMetrics.bodyHeight)
            .padding(.bottom, 4)
        }
        .background {
            MusicAmbientGlow()
        }
    }

    private var trackInfo: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(music.playback?.title ?? String(localized: "Nothing playing"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .lineLimit(1)
            .contentTransition(.opacity)
            .animation(.smooth, value: music.playback?.title)

            Spacer(minLength: 0)

            AudioBarsView(isPlaying: music.isPlaying, color: music.accentColor, height: 16)
                .padding(.top, 3)
        }
    }

    private var subtitle: String {
        guard let playback = music.playback else {
            return String(localized: "Play something in Music, Spotify or your browser.")
        }
        return [playback.artist, playback.album].filter { !$0.isEmpty }.joined(separator: " — ")
    }
}

// MARK: - MusicAmbientGlow

/// A soft halo of the cover's color, radiating from the artwork: the page takes the tint of what's playing.
/// A gradient rather than the blurred cover, which turns light covers into a grey smudge.
private struct MusicAmbientGlow: View {
    @Environment(MusicManager.self) private var music

    var body: some View {
        RadialGradient(
            colors: [music.accentColor.opacity(0.42), music.accentColor.opacity(0.1), .clear],
            center: UnitPoint(x: 0.14, y: 0.62),
            startRadius: 8,
            endRadius: 460
        )
        .opacity(music.artwork == nil ? 0 : 1)
        // Pure black next to the camera housing, so the notch keeps blending with it.
        .mask {
            LinearGradient(colors: [.clear, .black], startPoint: UnitPoint(x: 0.5, y: 0.05), endPoint: UnitPoint(x: 0.5, y: 0.45))
        }
        .animation(.smooth(duration: 0.6), value: music.accentColor)
        .animation(.smooth(duration: 0.6), value: music.artwork == nil)
        .allowsHitTesting(false)
    }
}
