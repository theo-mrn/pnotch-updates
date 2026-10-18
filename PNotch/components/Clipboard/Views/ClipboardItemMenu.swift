//
//  ClipboardItemMenu.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Defaults
import SwiftUI

/// Context menu shared by cards and list rows.
struct ClipboardItemMenu: View {
    let item: ClipboardItem

    @Environment(ClipboardStateViewModel.self) private var clipboard
    @Default(.pasteDirectly) private var pasteDirectly

    var body: some View {
        if pasteDirectly {
            Button("Paste", systemImage: "doc.on.clipboard") {
                clipboard.activate(item)
            }
        }
        Button("Copy", systemImage: "doc.on.doc") {
            clipboard.activate(item, copyOnly: true)
        }
        if case .richText = item.content {
            Button(pasteDirectly ? "Paste as Plain Text" : "Copy as Plain Text", systemImage: "textformat") {
                clipboard.activate(item, asPlainText: true)
            }
        }
        if item.kind == .link {
            Button("Open Link", systemImage: "safari") {
                clipboard.openLink(of: item)
            }
        }
        if case .files = item.content {
            Button("Show in Finder", systemImage: "folder") {
                clipboard.revealInFinder(item)
            }
        }
        Divider()
        Button(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin") {
            clipboard.togglePin(item)
        }
        Button("Delete", systemImage: "trash", role: .destructive) {
            clipboard.delete(item)
        }
    }
}
