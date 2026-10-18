//
//  NotchTabsConfiguration.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Defaults
import Foundation

/// Which tabs the notch shows, in which order, and the page it opens on.
nonisolated struct NotchTabsConfiguration: Equatable, Sendable {
    /// Every page exactly once, in display order.
    private(set) var order: [NotchPage]
    private(set) var hidden: Set<NotchPage>

    init(order: [NotchPage], hidden: Set<NotchPage>) {
        // Keeps the stored order, drops duplicates, appends pages added in later versions.
        var normalized: [NotchPage] = []
        for page in order + NotchPage.allCases where !normalized.contains(page) {
            normalized.append(page)
        }
        self.order = normalized
        self.hidden = hidden.count < NotchPage.allCases.count ? hidden : []
    }

    var visiblePages: [NotchPage] {
        order.filter { !hidden.contains($0) }
    }

    func isVisible(_ page: NotchPage) -> Bool {
        !hidden.contains(page)
    }

    /// The page an opening notch shows: the chosen start page, else the last one used, else the first tab.
    func pageToOpen(startPage: NotchPage?, lastPage: NotchPage) -> NotchPage {
        if let startPage, isVisible(startPage) {
            return startPage
        }
        if isVisible(lastPage) {
            return lastPage
        }
        return visiblePages.first ?? lastPage
    }

    /// Hiding the last visible tab is refused: the notch always has something to show.
    mutating func setVisible(_ page: NotchPage, _ isVisible: Bool) {
        if isVisible {
            hidden.remove(page)
        } else if visiblePages.count > 1 {
            hidden.insert(page)
        }
    }

    mutating func move(_ page: NotchPage, by offset: Int) {
        guard let index = order.firstIndex(of: page) else { return }
        let destination = min(max(index + offset, 0), order.count - 1)
        order.remove(at: index)
        order.insert(page, at: destination)
    }
}

extension NotchTabsConfiguration {
    /// The configuration saved in Settings.
    static var current: NotchTabsConfiguration {
        get { NotchTabsConfiguration(order: Defaults[.tabOrder], hidden: Defaults[.hiddenTabs]) }
        set {
            Defaults[.tabOrder] = newValue.order
            Defaults[.hiddenTabs] = newValue.hidden
        }
    }
}
