//
//  ClipboardSneakPeekView.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// Live activity flanking the closed notch after a copy: source app on the left, what was copied on the right.
struct ClipboardSneakPeekView: View {
    let peek: SneakPeek.Copy
    /// Changes with every copy, to replay the symbol's bounce.
    let id: UUID
    let notchSize: CGSize

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(width: NotchMetrics.sneakPeekSideWidth)
            Color.clear
                .frame(width: notchSize.width)
            trailing
                .frame(width: NotchMetrics.sneakPeekSideWidth)
        }
        .frame(height: notchSize.height)
    }

    private var leading: some View {
        CompanionMessengerFace {
            if let app = peek.sourceApp, AppIcons.icon(forBundleIdentifier: app.bundleIdentifier) != nil {
                SourceAppIcon(app: app, size: 18)
            } else {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if let color = peek.color {
            Circle()
                .fill(Color(color))
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                .frame(width: 14, height: 14)
        } else {
            Image(systemName: peek.kind.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(peek.kind.tint)
                .symbolEffect(.bounce, value: id)
        }
    }
}
