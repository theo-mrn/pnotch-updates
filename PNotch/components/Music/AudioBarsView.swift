//
//  AudioBarsView.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// Equalizer-style bars bouncing while music plays, resting low when it's paused.
///
/// Decorative: reading the real audio spectrum would require capturing system audio.
struct AudioBarsView: View {
    let isPlaying: Bool
    let color: Color
    var barCount = 4
    var barWidth: CGFloat = 3
    var height: CGFloat = 14

    /// Per-bar speed and phase, so the bars never move in sync.
    private static let rhythms: [(speed: Double, phase: Double)] = [
        (5.1, 0.0), (6.7, 1.3), (4.3, 2.4), (7.4, 0.7), (5.8, 1.9),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isPlaying)) { context in
            let time = context.date.timeIntervalSinceReferenceDate

            HStack(alignment: .center, spacing: barWidth * 0.7) {
                ForEach(0 ..< barCount, id: \.self) { index in
                    Capsule()
                        .fill(color)
                        .frame(width: barWidth, height: height * level(of: index, at: time))
                }
            }
            .frame(height: height)
        }
        .animation(.smooth(duration: 0.35), value: isPlaying)
        .accessibilityHidden(true)
    }

    private func level(of index: Int, at time: TimeInterval) -> CGFloat {
        guard isPlaying else { return 0.22 }
        let rhythm = Self.rhythms[index % Self.rhythms.count]
        let wave = sin(time * rhythm.speed + rhythm.phase) * 0.6 + sin(time * rhythm.speed * 1.7 + rhythm.phase * 2) * 0.4
        return 0.3 + 0.7 * CGFloat(abs(wave))
    }
}
