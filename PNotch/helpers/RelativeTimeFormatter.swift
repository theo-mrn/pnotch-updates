//
//  RelativeTimeFormatter.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation

/// Elapsed time shown next to clipboard items, then the date after a week.
nonisolated enum RelativeTimeFormatter {
    enum Style {
        /// "now", "4m", "2h", "3d": card headers.
        case compact
        /// "just now", "4m ago", "2h ago", "3d ago": list rows.
        case spelledOut
    }

    static func string(
        for date: Date,
        relativeTo now: Date = .now,
        style: Style = .compact,
        locale: Locale = .current
    ) -> String {
        let elapsed = max(0, now.timeIntervalSince(date))
        let compact = style == .compact

        // One string per unit: units are words in other languages ("4 min", "3 j").
        switch elapsed {
        case ..<60:
            return compact ? String(localized: "now") : String(localized: "just now")
        case ..<3600:
            let minutes = Int(elapsed / 60)
            return compact ? String(localized: "\(minutes)m") : String(localized: "\(minutes)m ago")
        case ..<86400:
            let hours = Int(elapsed / 3600)
            return compact ? String(localized: "\(hours)h") : String(localized: "\(hours)h ago")
        case ..<(7 * 86400):
            let days = Int(elapsed / 86400)
            return compact ? String(localized: "\(days)d") : String(localized: "\(days)d ago")
        default:
            return date.formatted(.dateTime.day().month(.abbreviated).locale(locale))
        }
    }
}
