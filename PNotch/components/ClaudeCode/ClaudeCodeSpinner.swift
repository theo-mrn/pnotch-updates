//
//  ClaudeCodeSpinner.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// The twinkling star Claude Code shows in the terminal while it works, in its terracotta.
struct ClaudeCodeSpinner: View {
    static let tint = Color(hex: 0xD97757)
    /// Grows, then shrinks back, like in the terminal.
    static let frames = ["·", "✢", "✳", "✶", "✻", "✽", "✻", "✶", "✳", "✢"]
    static let frameDuration = 0.12

    var isSpinning = true
    var size: CGFloat = 13

    var body: some View {
        if isSpinning {
            TimelineView(.periodic(from: .now, by: Self.frameDuration)) { timeline in
                let frame = Int(timeline.date.timeIntervalSinceReferenceDate / Self.frameDuration) % Self.frames.count
                glyph(Self.frames[frame])
            }
        } else {
            glyph("✻")
        }
    }

    private func glyph(_ character: String) -> some View {
        Text(verbatim: character)
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(Self.tint)
            .frame(width: size * 1.2, height: size * 1.2)
            .accessibilityHidden(true)
    }
}
