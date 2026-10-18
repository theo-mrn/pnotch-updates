//
//  RichTextRenderer.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import AppKit
import SwiftUI

/// Turns copied RTF into a card-sized preview: keeps bold, italic and headings, drops sizes and colors.
enum RichTextRenderer {
    private static let maximumLength = 600

    static func preview(of rtfData: Data, baseSize: CGFloat) -> AttributedString? {
        guard let source = NSAttributedString(rtf: rtfData, documentAttributes: nil), source.length > 0 else {
            return nil
        }

        let length = min(source.length, maximumLength)
        let bodySize = dominantFontSize(in: source, length: length)
        var preview = AttributedString()

        source.enumerateAttribute(.font, in: NSRange(location: 0, length: length)) { value, range, _ in
            let font = value as? NSFont
            let traits = font?.fontDescriptor.symbolicTraits ?? []
            let isHeading = (font?.pointSize ?? bodySize) > bodySize * 1.15

            var run = AttributedString(source.attributedSubstring(from: range).string)
            var swiftUIFont = Font.system(
                size: isHeading ? baseSize + 1.5 : baseSize,
                weight: traits.contains(.bold) || isHeading ? .semibold : .regular
            )
            if traits.contains(.italic) {
                swiftUIFont = swiftUIFont.italic()
            }
            run.font = swiftUIFont
            preview += run
        }
        return preview
    }

    /// Point size covering the most characters, i.e. the body text size.
    private static func dominantFontSize(in source: NSAttributedString, length: Int) -> CGFloat {
        var characterCountBySize: [CGFloat: Int] = [:]
        source.enumerateAttribute(.font, in: NSRange(location: 0, length: length)) { value, range, _ in
            let size = (value as? NSFont)?.pointSize ?? NSFont.systemFontSize
            characterCountBySize[size, default: 0] += range.length
        }
        return characterCountBySize.max { $0.value < $1.value }?.key ?? NSFont.systemFontSize
    }
}
