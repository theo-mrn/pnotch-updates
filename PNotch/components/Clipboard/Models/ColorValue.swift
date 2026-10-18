//
//  ColorValue.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation

/// An sRGB color recognised in copied text, e.g. `#3A6FF2` or `rgb(58 111 242 / 50%)`.
nonisolated struct ColorValue: Hashable, Codable, Sendable {
    /// Components in the 0...1 range.
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    /// The text exactly as it was copied. Copying the item back writes this string.
    let rawValue: String

    init(red: Double, green: Double, blue: Double, alpha: Double = 1, rawValue: String) {
        self.red = red.clamped(to: 0 ... 1)
        self.green = green.clamped(to: 0 ... 1)
        self.blue = blue.clamped(to: 0 ... 1)
        self.alpha = alpha.clamped(to: 0 ... 1)
        self.rawValue = rawValue
    }

    /// `#RRGGBB`, or `#RRGGBBAA` for translucent colors.
    var hexString: String {
        let components = alpha < 1 ? [red, green, blue, alpha] : [red, green, blue]
        return "#" + components.map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined()
    }

    var rgbString: String {
        let channels = [red, green, blue].map { String(Int(($0 * 255).rounded())) }.joined(separator: ", ")
        guard alpha < 1 else { return "rgb(\(channels))" }
        return "rgba(\(channels), \(String(format: "%.2g", alpha)))"
    }

    /// WCAG relative luminance.
    var relativeLuminance: Double {
        func linearize(_ channel: Double) -> Double {
            channel <= 0.040_45 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
    }

    /// Whether dark text reads better than white text on top of this color.
    var prefersDarkForeground: Bool {
        // Contrast with black beats contrast with white above ~0.18 luminance.
        relativeLuminance > 0.18
    }
}

extension Comparable {
    nonisolated func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
