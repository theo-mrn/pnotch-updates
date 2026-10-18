//
//  MusicLiveActivityView.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// Shown around the closed notch while music plays: the cover on the left, the equalizer on the right.
struct MusicLiveActivityView: View {
    let notchSize: CGSize

    @Environment(MusicManager.self) private var music

    var body: some View {
        HStack(spacing: 0) {
            MusicArtworkView(size: 20, cornerRadius: 5, showsAppBadge: false)
                .frame(width: NotchMetrics.sneakPeekSideWidth)

            Color.clear
                .frame(width: notchSize.width)

            AudioBarsView(isPlaying: music.isPlaying, color: music.accentColor, barWidth: 2.5, height: 13)
                .frame(width: NotchMetrics.sneakPeekSideWidth)
        }
        .frame(height: notchSize.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(music.playback.map { "\($0.title), \($0.artist)" } ?? ""))
    }
}
