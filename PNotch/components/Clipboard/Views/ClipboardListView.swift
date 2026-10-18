//
//  ClipboardListView.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// The clipboard page: a searchable list dropping from the notch, filtered by kind.
/// ↑ ↓ (or the shortcut again) move through it, ↩ pastes.
struct ClipboardListView: View {
    @Environment(ClipboardStateViewModel.self) private var clipboard

    var body: some View {
        VStack(spacing: 0) {
            NotchHeaderView {
                ClipboardActionsView()
            }

            HStack(spacing: 12) {
                ClipboardSearchField()
                ClipboardFilterBar()
            }
            .padding(.horizontal, ClipboardListMetrics.horizontalPadding + 8)
            .frame(height: ClipboardListMetrics.searchHeight)

            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, ClipboardListMetrics.horizontalPadding + 4)

            rows
                .padding(.bottom, ClipboardListMetrics.bottomInset)
        }
        .environment(\.clipboardSearchQuery, clipboard.searchQuery)
        .onDisappear {
            clipboard.resetTransientState()
        }
    }

    @ViewBuilder
    private var rows: some View {
        let items = clipboard.visibleItems

        if items.isEmpty {
            ClipboardEmptyStateView()
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: ClipboardListMetrics.rowSpacing) {
                        ForEach(items) { item in
                            ClipboardListRow(
                                item: item,
                                isSelected: item.id == clipboard.highlightedItemID,
                                isCopied: item.id == clipboard.recentlyCopiedItemID
                            )
                            .id(item.id)
                        }
                    }
                    .padding(.horizontal, ClipboardListMetrics.horizontalPadding)
                    .padding(.vertical, ClipboardListMetrics.verticalPadding)
                }
                .scrollIndicators(.automatic)
                .clipped()
                .onChange(of: clipboard.highlightedItemID) { _, highlightedID in
                    guard let highlightedID else { return }
                    // No anchor: scrolls just enough to reveal the row, like a native list.
                    withAnimation(.smooth(duration: 0.2)) {
                        proxy.scrollTo(highlightedID)
                    }
                }
            }
        }
    }
}
