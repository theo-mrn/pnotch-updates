//
//  ColorParser.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation

/// Recognises CSS-style color notations: hex (`#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`, `0xRRGGBB`),
/// `rgb()` / `rgba()` and `hsl()` / `hsla()`, with comma or space separated arguments.
nonisolated enum ColorParser {
    static func parse(_ string: String) -> ColorValue? {
        let raw = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, raw.count <= 64 else { return nil }

        let lowercased = raw.lowercased()
        if lowercased.hasPrefix("#") {
            return parseHex(String(lowercased.dropFirst()), allowedLengths: [3, 4, 6, 8], rawValue: raw)
        }
        if lowercased.hasPrefix("0x") {
            return parseHex(String(lowercased.dropFirst(2)), allowedLengths: [6, 8], rawValue: raw)
        }
        if let arguments = functionArguments(in: lowercased, names: ["rgba", "rgb"]) {
            return parseRGB(arguments, rawValue: raw)
        }
        if let arguments = functionArguments(in: lowercased, names: ["hsla", "hsl"]) {
            return parseHSL(arguments, rawValue: raw)
        }
        return nil
    }

    // MARK: Hex

    private static func parseHex(_ digits: String, allowedLengths: Set<Int>, rawValue: String) -> ColorValue? {
        guard allowedLengths.contains(digits.count),
              digits.allSatisfy(\.isHexDigit),
              let value = UInt64(digits, radix: 16)
        else { return nil }

        let isShortForm = digits.count <= 4
        let channelCount = isShortForm ? digits.count : digits.count / 2
        let bitsPerChannel: UInt64 = isShortForm ? 4 : 8
        let maxChannelValue = Double((1 << bitsPerChannel) - 1)

        let channels = (0 ..< channelCount).map { index -> Double in
            let shift = UInt64(channelCount - 1 - index) * bitsPerChannel
            return Double((value >> shift) & ((1 << bitsPerChannel) - 1)) / maxChannelValue
        }
        return ColorValue(
            red: channels[0],
            green: channels[1],
            blue: channels[2],
            alpha: channels.count == 4 ? channels[3] : 1,
            rawValue: rawValue
        )
    }

    // MARK: Functional notations

    private static func functionArguments(in string: String, names: [String]) -> [String]? {
        for name in names where string.hasPrefix("\(name)(") && string.hasSuffix(")") {
            let inner = string.dropFirst(name.count + 1).dropLast()
            let separators = CharacterSet(charactersIn: ",/").union(.whitespaces)
            return inner.components(separatedBy: separators).filter { !$0.isEmpty }
        }
        return nil
    }

    private static func parseRGB(_ arguments: [String], rawValue: String) -> ColorValue? {
        guard arguments.count == 3 || arguments.count == 4 else { return nil }
        guard let red = channel(arguments[0]),
              let green = channel(arguments[1]),
              let blue = channel(arguments[2]),
              let alpha = arguments.count == 4 ? alphaValue(arguments[3]) : 1
        else { return nil }

        return ColorValue(red: red, green: green, blue: blue, alpha: alpha, rawValue: rawValue)
    }

    private static func parseHSL(_ arguments: [String], rawValue: String) -> ColorValue? {
        guard arguments.count == 3 || arguments.count == 4 else { return nil }

        let hueString = arguments[0].replacingOccurrences(of: "deg", with: "")
        guard let hue = Double(hueString),
              let saturation = percentage(arguments[1]),
              let lightness = percentage(arguments[2]),
              let alpha = arguments.count == 4 ? alphaValue(arguments[3]) : 1
        else { return nil }

        let (red, green, blue) = rgbComponents(hue: hue, saturation: saturation, lightness: lightness)
        return ColorValue(red: red, green: green, blue: blue, alpha: alpha, rawValue: rawValue)
    }

    /// An 8-bit channel (`0...255`) or a percentage, normalised to 0...1.
    private static func channel(_ argument: String) -> Double? {
        if let percentage = percentage(argument) { return percentage }
        guard let value = Double(argument), (0 ... 255).contains(value) else { return nil }
        return value / 255
    }

    /// A 0...1 number or a percentage.
    private static func alphaValue(_ argument: String) -> Double? {
        if let percentage = percentage(argument) { return percentage }
        guard let value = Double(argument), (0 ... 1).contains(value) else { return nil }
        return value
    }

    private static func percentage(_ argument: String) -> Double? {
        guard argument.hasSuffix("%"), let value = Double(argument.dropLast()), (0 ... 100).contains(value) else {
            return nil
        }
        return value / 100
    }

    private static func rgbComponents(hue: Double, saturation: Double, lightness: Double) -> (Double, Double, Double) {
        let normalizedHue = (hue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360
        guard saturation > 0 else { return (lightness, lightness, lightness) }

        let q = lightness < 0.5 ? lightness * (1 + saturation) : lightness + saturation - lightness * saturation
        let p = 2 * lightness - q

        func component(_ offset: Double) -> Double {
            var t = normalizedHue + offset
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            switch t {
            case ..<(1.0 / 6): return p + (q - p) * 6 * t
            case ..<(1.0 / 2): return q
            case ..<(2.0 / 3): return p + (q - p) * (2.0 / 3 - t) * 6
            default: return p
            }
        }
        return (component(1.0 / 3), component(0), component(-1.0 / 3))
    }
}
