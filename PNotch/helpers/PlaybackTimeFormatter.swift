//
//  PlaybackTimeFormatter.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation

/// Track positions as players show them: "3:07", "1:02:45".
nonisolated enum PlaybackTimeFormatter {
    static func string(from interval: TimeInterval) -> String {
        let totalSeconds = Int(max(interval, 0).rounded(.down))
        let hours = totalSeconds / 3600
        let minutes = totalSeconds % 3600 / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
