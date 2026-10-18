//
//  SearchHighlighter.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// Marks the words of the search query in displayed text, like Spotlight and Mail do.
enum SearchHighlighter {
    /// Find-in-page yellow with dark ink, readable on light cards and dark ones (code, list rows) alike.
    static let highlightColor = Color(hex: 0xFFD60A, opacity: 0.85)
    static let highlightInk = Color(hex: 0x1E1C18)

    static func highlighting(_ query: String, in text: String) -> AttributedString {
        highlighting(query, in: AttributedString(text))
    }

    /// Adds a highlight behind every occurrence of every query word, keeping existing attributes
    /// (e.g. syntax colors). Case and diacritics are ignored, as in the search itself.
    static func highlighting(_ query: String, in attributed: AttributedString) -> AttributedString {
        let words = query.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return attributed }

        let text = String(attributed.characters)
        var result = attributed
        for word in words {
            var searchStart = text.startIndex
            while let found = text.range(
                of: word,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: searchStart ..< text.endIndex
            ) {
                if let range = Range(found, in: result) {
                    result[range].backgroundColor = highlightColor
                    result[range].foregroundColor = highlightInk
                }
                searchStart = found.upperBound
            }
        }
        return result
    }
}

extension EnvironmentValues {
    /// The clipboard search, for views that highlight what matched.
    @Entry var clipboardSearchQuery = ""
}
