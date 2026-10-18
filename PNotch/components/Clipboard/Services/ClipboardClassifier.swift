//
//  ClipboardClassifier.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import AppKit

/// Decides how copied text is displayed: color, link, code, rich text or plain text.
nonisolated enum ClipboardClassifier {
    static func content(forText text: String, rtf: Data?) -> ClipboardContent {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let color = ColorParser.parse(trimmed) {
            return .color(color)
        }
        if let url = webURL(from: trimmed) {
            return .link(.init(url: url))
        }
        if looksLikeCode(text) {
            return .code(text)
        }
        if let rtf, hasMeaningfulFormatting(rtf) {
            return .richText(.init(plainText: text, rtfData: rtf))
        }
        return .text(text)
    }

    /// A single `http(s)` URL, without surrounding prose.
    static func webURL(from string: String) -> URL? {
        guard !string.isEmpty, !string.contains(where: \.isWhitespace),
              let url = URL(string: string),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host(), host.contains(".") || host == "localhost"
        else { return nil }
        return url
    }

    // MARK: Code detection

    static func looksLikeCode(_ text: String) -> Bool {
        codeScore(text) >= 3
    }

    private static let keywordPattern = try! NSRegularExpression(
        pattern: #"^\s*(func|let|var|const|import|export|return|guard|struct|class|enum|interface|def|fn|pub|public|private|protected|static|async|await|#include|#import|#define|package|using|namespace|SELECT|INSERT|UPDATE|DELETE|CREATE|@media|@import)\b"#,
        options: [.anchorsMatchLines]
    )
    private static let controlFlowPattern = try! NSRegularExpression(
        pattern: #"\b(if|for|while|switch|catch)\s*\("#
    )
    private static let shellCommandPattern = try! NSRegularExpression(
        pattern: #"^(\$ )?(git|npm|npx|yarn|pnpm|bun|brew|cd|curl|wget|docker|kubectl|swift|xcodebuild|xcrun|sudo|pip3?|python3?|node|ssh|scp|ls|mkdir|rm|cp|mv|cat|echo|export|chmod|make|cargo|go|gh) [^\n]+$"#
    )
    private static let sqlPattern = try! NSRegularExpression(
        pattern: #"^\s*(SELECT\b.+\bFROM|INSERT INTO|UPDATE\b.+\bSET|DELETE FROM)\b"#,
        options: [.anchorsMatchLines]
    )
    private static let sentencePattern = try! NSRegularExpression(
        pattern: #"\p{L}{2,}[.!?](\s|$)"#
    )

    private static func codeScore(_ text: String) -> Int {
        let lines = text.split(whereSeparator: \.isNewline)
        guard !lines.isEmpty else { return 0 }
        let range = NSRange(text.startIndex..., in: text)
        let sentenceCount = sentencePattern.numberOfMatches(in: text, range: range)

        if lines.count == 1, sentenceCount == 0, shellCommandPattern.firstMatch(in: text, range: range) != nil {
            return 3
        }

        var score = 0
        if text.contains("{"), text.contains("}") {
            score += 2
        }
        let terminatedLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasSuffix(";") || trimmed.hasSuffix("{")
        }.count
        score += min(terminatedLines, 2)

        if lines.count > 1, lines.contains(where: { $0.hasPrefix("    ") || $0.hasPrefix("\t") }) {
            score += 1
        }
        score += min(keywordPattern.numberOfMatches(in: text, range: range), 3)
        if controlFlowPattern.firstMatch(in: text, range: range) != nil {
            score += 1
        }
        if sqlPattern.firstMatch(in: text, range: range) != nil {
            score += 2
        }
        if ["=>", "->", "===", "!=", "&&", "||", "::", "</"].contains(where: { text.contains($0) }) {
            score += 1
        }

        // Prose made of full sentences needs much stronger evidence.
        if sentenceCount >= 2 || (sentenceCount == 1 && lines.count == 1) {
            score -= 3
        }
        return score
    }

    // MARK: Rich text detection

    /// Whether the RTF carries formatting worth showing: several text styles, links or tables.
    /// Most apps attach RTF to every copy, even for unformatted text.
    static func hasMeaningfulFormatting(_ rtf: Data) -> Bool {
        guard let attributed = NSAttributedString(rtf: rtf, documentAttributes: nil), attributed.length > 0 else {
            return false
        }

        var styles = Set<String>()
        var hasLinkOrTable = false
        let fullRange = NSRange(location: 0, length: attributed.length)
        attributed.enumerateAttributes(in: fullRange) { attributes, _, stop in
            if attributes[.link] != nil {
                hasLinkOrTable = true
            }
            if let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle, !paragraph.textBlocks.isEmpty {
                hasLinkOrTable = true
            }
            if let font = attributes[.font] as? NSFont {
                let traits = font.fontDescriptor.symbolicTraits.intersection([.bold, .italic])
                styles.insert("\(traits.rawValue)-\(Int(font.pointSize.rounded()))")
            }
            if hasLinkOrTable || styles.count > 1 {
                stop.pointee = true
            }
        }
        return hasLinkOrTable || styles.count > 1
    }
}
