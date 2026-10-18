//
//  ClipboardEmptyStateView.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// Shown in place of the cards when there is nothing to display.
struct ClipboardEmptyStateView: View {
    @Environment(ClipboardStateViewModel.self) private var clipboard

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbolName)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.white.opacity(0.35))
                .padding(.bottom, 2)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text(message)
                .font(.system(size: 11.5))
                .foregroundStyle(.white.opacity(0.45))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 9)
    }

    private var isSearching: Bool {
        clipboard.isSearching
    }

    private var symbolName: String {
        if isSearching {
            return "magnifyingglass"
        }
        return clipboard.filter.kind?.symbolName ?? "doc.on.clipboard"
    }

    private var title: String {
        if isSearching {
            return String(localized: "No results for “\(clipboard.searchQuery)”")
        }
        switch clipboard.filter {
        case .all: return String(localized: "Your clipboard is empty")
        case .images: return String(localized: "No images yet")
        case .links: return String(localized: "No links yet")
        }
    }

    private var message: String {
        if isSearching {
            return String(localized: "Try another word, or clear the search with esc.")
        }
        switch clipboard.filter {
        case .all:
            return String(localized: "Copy anything — text, links, images, colors — and it lands here.")
        case .images:
            return String(localized: "Screenshots, pictures from the web and image files from Finder show up here.")
        case .links:
            return String(localized: "Web addresses you copy show up here, with a preview of the page.")
        }
    }
}
