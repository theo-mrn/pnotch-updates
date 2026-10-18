//
//  ClipboardFilterChip.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

struct ClipboardFilterChip: View {
    let filter: ClipboardFilter
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                marker
                Text(filter.title)
                    .font(.system(size: 11.5, weight: .medium))
            }
            .foregroundStyle(.white.opacity(isSelected ? 1 : isHovered ? 0.85 : 0.62))
            .padding(.horizontal, 9)
            .frame(height: NotchHeaderMetrics.controlHeight)
            .background {
                Capsule().fill(.white.opacity(isSelected ? 0.18 : isHovered ? 0.11 : 0.07))
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.smooth(duration: 0.15), value: isHovered)
        .animation(.smooth(duration: 0.2), value: isSelected)
    }

    @ViewBuilder
    private var marker: some View {
        if let kind = filter.kind {
            Circle()
                .fill(kind.tint)
                .frame(width: 6, height: 6)
        } else {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 9, weight: .semibold))
        }
    }
}

/// The filter chips, side by side.
struct ClipboardFilterBar: View {
    @Environment(ClipboardStateViewModel.self) private var clipboard

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ClipboardFilter.allCases) { filter in
                ClipboardFilterChip(filter: filter, isSelected: clipboard.filter == filter) {
                    clipboard.filter = filter
                }
            }
        }
        .fixedSize()
    }
}
