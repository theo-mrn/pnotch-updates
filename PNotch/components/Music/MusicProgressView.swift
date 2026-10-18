//
//  MusicProgressView.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// Scrubbable progress bar with elapsed and remaining time. Seeks when the drag ends.
struct MusicProgressView: View {
    @Environment(MusicManager.self) private var music
    @State private var dragFraction: Double?
    @State private var isHovered = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.5, paused: !music.isPlaying || dragFraction != nil)) { context in
            let playback = music.playback
            let duration = playback?.duration ?? 0
            let position = dragFraction.map { $0 * duration } ?? playback?.position(at: context.date) ?? 0
            let fraction = duration > 0 ? position / duration : 0

            VStack(spacing: 5) {
                bar(fraction: fraction, isEnabled: playback?.hasKnownDuration == true)

                HStack {
                    Text(PlaybackTimeFormatter.string(from: position))
                    Spacer()
                    Text(duration > 0 ? "-" + PlaybackTimeFormatter.string(from: duration - position) : "--:--")
                }
                .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private func bar(fraction: Double, isEnabled: Bool) -> some View {
        let isActive = isEnabled && (isHovered || dragFraction != nil)

        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.18))
                Capsule()
                    .fill(isActive ? music.accentColor : .white.opacity(0.85))
                    .frame(width: geometry.size.width * min(max(fraction, 0), 1))
            }
            .frame(height: isActive ? 7 : 5)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled else { return }
                        dragFraction = min(max(value.location.x / geometry.size.width, 0), 1)
                    }
                    .onEnded { _ in
                        guard let dragFraction, let duration = music.playback?.duration else { return }
                        music.seek(to: dragFraction * duration)
                        self.dragFraction = nil
                    }
            )
        }
        .frame(height: 14)
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isActive)
        .accessibilityElement()
        .accessibilityLabel("Playback position")
        .accessibilityValue(Text(PlaybackTimeFormatter.string(from: fraction * (music.playback?.duration ?? 0))))
    }
}
