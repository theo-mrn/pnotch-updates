//
//  NotchTabBar.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Defaults
import SwiftUI

/// Switches between the notch pages chosen in Settings. The selected tab shows its name, the others
/// only their icon, which keeps the bar narrow enough for the wing next to the camera. On narrow pages,
/// where even that would slip under the camera housing, every tab is an icon.
/// Hidden when a single page is enabled.
struct NotchTabBar: View {
    @Environment(PNotchViewModel.self) private var vm
    @Default(.tabOrder) private var tabOrder
    @Default(.hiddenTabs) private var hiddenTabs
    @Namespace private var selection

    var body: some View {
        let pages = NotchTabsConfiguration(order: tabOrder, hidden: hiddenTabs).visiblePages
        if pages.count > 1 {
            ViewThatFits(in: .horizontal) {
                tabs(pages, showsSelectedTitle: true)
                tabs(pages, showsSelectedTitle: false)
            }
        }
    }

    private func tabs(_ pages: [NotchPage], showsSelectedTitle: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(pages, id: \.self) { page in
                NotchTab(page: page, isSelected: vm.page == page, showsTitle: showsSelectedTitle, selection: selection) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        vm.select(page)
                    }
                }
            }
        }
        .padding(3)
        .background(.white.opacity(0.06), in: Capsule())
    }
}

private struct NotchTab: View {
    let page: NotchPage
    let isSelected: Bool
    /// Whether the selected tab spells out its name.
    let showsTitle: Bool
    let selection: Namespace.ID
    let action: () -> Void

    @Environment(ClaudeCodeManager.self) private var claudeCode
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if page == .companion {
                    // The robot's own face, blinking in the tab bar.
                    RobotView(framing: .face, followsPointer: false)
                        .frame(width: 16, height: 11)
                } else {
                    Image(systemName: page.symbolName)
                        .font(.system(size: 10.5, weight: .semibold))
                        .overlay(alignment: .topTrailing) {
                            if page == .claudeCode, claudeCode.needsAttention {
                                Circle()
                                    .fill(ClaudeCodeSpinner.tint)
                                    .frame(width: 6, height: 6)
                                    .offset(x: 4, y: -3)
                            }
                        }
                }
                if isSelected, showsTitle {
                    Text(page.title)
                        .font(.system(size: 11.5, weight: .semibold))
                        .fixedSize()
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
                }
            }
            .foregroundStyle(.white.opacity(isSelected ? 1 : isHovered ? 0.85 : 0.55))
            .padding(.horizontal, isSelected && showsTitle ? 10 : 8)
            .frame(height: NotchHeaderMetrics.controlHeight - 4)
            .background {
                if isSelected {
                    Capsule()
                        .fill(.white.opacity(0.16))
                        .matchedGeometryEffect(id: "selectedTab", in: selection)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(page.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension NotchPage {
    var title: String {
        switch self {
        case .music: String(localized: "Music")
        case .clipboard: String(localized: "Clipboard")
        case .system: String(localized: "System")
        case .companion: Defaults[.companionName]
        case .claudeCode: "Claude Code"
        }
    }

    var symbolName: String {
        switch self {
        case .music: "music.note"
        case .clipboard: "doc.on.clipboard"
        case .system: "gauge.with.dots.needle.67percent"
        case .companion: "face.smiling"
        case .claudeCode: "terminal"
        }
    }
}
