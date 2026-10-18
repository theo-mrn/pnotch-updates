//
//  MetricFormatter.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation

/// Compact strings for the System page, sized for small tiles.
nonisolated enum MetricFormatter {
    static func percent(_ fraction: Double) -> String {
        "\(Int((min(max(fraction, 0), 1) * 100).rounded()))%"
    }

    /// Memory sizes, in binary units like Activity Monitor ("16 GB" of RAM).
    static func memory(_ bytes: UInt64) -> String {
        Int64(clamping: bytes).formatted(.byteCount(style: .memory))
    }

    /// Disk sizes, in decimal units like Finder.
    static func storage(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file))
    }

    /// Network throughput: "820 KB/s", "1.4 MB/s" ("1,4 Mo/s" in French). Decimal units, one decimal below 10.
    static func rate(_ bytesPerSecond: Double, locale: Locale = .current) -> String {
        let units = [
            String(localized: "B", comment: "Symbol of the byte, in network rates"),
            String(localized: "KB", comment: "Symbol of the kilobyte, in network rates"),
            String(localized: "MB", comment: "Symbol of the megabyte, in network rates"),
            String(localized: "GB", comment: "Symbol of the gigabyte, in network rates"),
        ]
        var value = max(bytesPerSecond, 0)
        var unitIndex = 0
        while value >= 1000, unitIndex < units.count - 1 {
            value /= 1000
            unitIndex += 1
        }
        let fractionDigits = value < 10 && unitIndex > 0 ? 1 : 0
        let number = value.formatted(.number.precision(.fractionLength(fractionDigits)).locale(locale))
        return "\(number) \(units[unitIndex])/s"
    }

    /// "1h 17m", "45m".
    static func duration(minutes: Int) -> String {
        guard minutes >= 60 else { return String(localized: "\(minutes)m") }
        return String(localized: "\(minutes / 60)h \(minutes % 60)m")
    }

    /// "3d 4h", "5h 12m", "42m".
    static func uptime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        let days = minutes / 1440
        if days > 0 {
            return String(localized: "\(days)d \(minutes % 1440 / 60)h")
        }
        return duration(minutes: minutes)
    }
}
