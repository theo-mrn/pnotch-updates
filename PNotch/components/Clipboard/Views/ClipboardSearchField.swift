//
//  ClipboardSearchField.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// Large borderless search field topping the clipboard list, filtering it as you type.
struct ClipboardSearchField: View {
    @Environment(PNotchViewModel.self) private var vm
    @Environment(ClipboardStateViewModel.self) private var clipboard
    @FocusState private var isFocused: Bool
    @State private var isHovered = false

    var body: some View {
        @Bindable var clipboard = clipboard

        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(isFocused ? 0.85 : 0.5))

            TextField("Search clipboard…", text: $clipboard.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .focused($isFocused)

            trailingAccessory
        }
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            vm.requestKeyboardFocus()
            isFocused = true
        }
        .onHover { isHovered = $0 }
        .onChange(of: clipboard.searchFocusRequest) {
            isFocused = true
        }
        .task {
            // Opened with the keyboard or a click: the window became key before this field existed.
            await Task.yield()
            if vm.isKeyboardFocused() {
                isFocused = true
            }
        }
        .animation(.smooth(duration: 0.18), value: isFocused)
        .animation(.smooth(duration: 0.15), value: isHovered)
        .animation(.smooth(duration: 0.15), value: clipboard.isSearching)
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        if clipboard.isSearching {
            HStack(spacing: 6) {
                Text(resultCount)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.45))
                    .contentTransition(.numericText())

                Button {
                    clipboard.clearSearch()
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.5))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Clear search (esc)")
            }
            .transition(.opacity)
        }
    }

    private var resultCount: LocalizedStringKey {
        let count = clipboard.visibleItems.count
        return count == 0 ? "No results" : "^[\(count) result](inflect: true)"
    }
}
