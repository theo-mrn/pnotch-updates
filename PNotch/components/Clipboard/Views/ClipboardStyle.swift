//
//  ClipboardStyle.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

enum ClipboardPalette {
    /// Behind code previews.
    static let graphite = Color(hex: 0x1C1C1E)
}

extension ClipboardKind {
    /// Accent of the kind: filter chip dots, sneak peek glyph.
    var tint: Color {
        switch self {
        case .text: .white
        case .richText: Color(hex: 0xF2C94C)
        case .code: Color(hex: 0xFF9F43)
        case .link: Color(hex: 0x4C8DFF)
        case .color: Color(hex: 0xB07CFF)
        case .image: Color(hex: 0x34C77B)
        case .file: Color(hex: 0x40C8E0)
        case .contact: Color(hex: 0x7B6CF6)
        }
    }
}
