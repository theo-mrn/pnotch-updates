//
//  CodeHighlighter.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// Lightweight, language-agnostic syntax coloring for code card previews.
/// Colors follow Xcode's default dark theme.
enum CodeHighlighter {
    static let plainColor = Color(hex: 0xE5E5E7)

    private struct Rule {
        let regex: NSRegularExpression
        let color: Color

        init(_ pattern: String, _ color: Color, options: NSRegularExpression.Options = []) {
            // The patterns are literals: failing to compile them is a programming error.
            regex = try! NSRegularExpression(pattern: pattern, options: options)
            self.color = color
        }
    }

    /// Ordered by precedence: a range claimed by a rule is not recolored by the following ones.
    private static let rules: [Rule] = [
        Rule(#"//[^\n]*|/\*[\s\S]*?\*/|^\s*#\s[^\n]*"#, Color(hex: 0x6C7986), options: .anchorsMatchLines),
        Rule(#""(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'|`[^`]*`"#, Color(hex: 0xFC6A5D)),
        Rule(
            #"\b(func|let|var|const|import|export|return|if|else|for|while|switch|case|default|break|continue|guard|struct|class|enum|protocol|extension|interface|type|def|fn|pub|public|private|static|async|await|try|catch|throw|new|true|false|nil|null|undefined|self|this|in|of|from|as|is|where|SELECT|FROM|WHERE|JOIN|INSERT|UPDATE|DELETE)\b"#,
            Color(hex: 0xFF7AB2)
        ),
        Rule(#"#[0-9a-fA-F]{3,8}\b|\b\d+(?:\.\d+)?(?:px|rem|em|%|ms|s)?\b"#, Color(hex: 0xD0BF69)),
        Rule(#"--[\w-]+|\b[A-Z][A-Za-z0-9]+\b"#, Color(hex: 0x5DD8FF)),
    ]

    static func highlight(_ code: String) -> AttributedString {
        var attributed = AttributedString(code)
        attributed.foregroundColor = plainColor

        let nsRange = NSRange(code.startIndex..., in: code)
        var claimed = IndexSet()

        for rule in rules {
            for match in rule.regex.matches(in: code, range: nsRange) {
                let range = match.range
                guard !claimed.intersects(integersIn: range.location ..< range.location + range.length),
                      let stringRange = Range(range, in: code),
                      let attributedRange = Range(stringRange, in: attributed)
                else { continue }

                attributed[attributedRange].foregroundColor = rule.color
                claimed.insert(integersIn: range.location ..< range.location + range.length)
            }
        }
        return attributed
    }

    /// First `maxLines` non-blank lines, with tabs expanded and the common indentation removed.
    nonisolated static func excerpt(of code: String, maxLines: Int) -> String {
        var lines = code
            .replacingOccurrences(of: "\t", with: "    ")
            .components(separatedBy: .newlines)
        while lines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            lines.removeFirst()
        }
        lines = Array(lines.prefix(maxLines))

        let indentation = lines
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.prefix(while: { $0 == " " }).count }
            .min() ?? 0
        return lines
            .map { String($0.dropFirst(min(indentation, $0.prefix(while: { $0 == " " }).count))) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .newlines)
    }
}
