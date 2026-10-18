//
//  ClipboardFilter.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation

/// The chips of the notch header.
nonisolated enum ClipboardFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case images
    case links

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .all: String(localized: "All")
        case .images: String(localized: "Images")
        case .links: String(localized: "Links")
        }
    }

    /// The kind a chip narrows the history to, if any.
    var kind: ClipboardKind? {
        switch self {
        case .all: nil
        case .images: .image
        case .links: .link
        }
    }

    func matches(_ item: ClipboardItem) -> Bool {
        guard let kind else { return true }
        return item.kind == kind
    }
}
