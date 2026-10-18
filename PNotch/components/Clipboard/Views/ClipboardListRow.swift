//
//  ClipboardListRow.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// One line of the clipboard list: thumbnail, title, source app and age.
struct ClipboardListRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let isCopied: Bool

    @Environment(ClipboardStateViewModel.self) private var clipboard
    @Environment(\.clipboardSearchQuery) private var searchQuery
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ClipboardListMetrics.rowCornerRadius, style: .continuous)

        HStack(spacing: 12) {
            ClipboardListThumbnail(item: item)

            VStack(alignment: .leading, spacing: 4) {
                Text(SearchHighlighter.highlighting(searchQuery, in: item.content.listTitle))
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
                    .truncationMode(titleTruncation)
                subtitle
            }

            Spacer(minLength: 8)

            trailingAccessory
        }
        .padding(.horizontal, 8)
        .frame(height: ClipboardListMetrics.rowHeight)
        .background {
            shape.fill(.white.opacity(isSelected ? 0.13 : isHovered ? 0.07 : 0.035))
        }
        .overlay {
            shape.strokeBorder(.white.opacity(isSelected ? 0.14 : 0.05), lineWidth: 1)
        }
        .contentShape(shape)
        .onHover { isHovered = $0 }
        .onTapGesture {
            clipboard.select(item)
            // ⌥-click only copies, like ⌥↩.
            clipboard.activate(item, copyOnly: NSEvent.modifierFlags.contains(.option))
        }
        .onDrag {
            clipboard.itemProvider(for: item)
        }
        .contextMenu {
            ClipboardItemMenu(item: item)
        }
        .animation(.smooth(duration: 0.12), value: isSelected)
        .animation(.smooth(duration: 0.12), value: isHovered)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// File names and addresses keep their end visible; sentences read from the start.
    private var titleTruncation: Text.TruncationMode {
        switch item.kind {
        case .file, .image, .link: .middle
        case .text, .richText, .code, .color, .contact: .tail
        }
    }

    private var subtitle: some View {
        HStack(spacing: 6) {
            if let app = item.sourceApp {
                SourceAppIcon(app: app, size: 14)
                Text(app.name)
            }
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(RelativeTimeFormatter.string(for: item.copiedAt, relativeTo: context.date, style: .spelledOut))
            }
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .font(.system(size: 11.5, weight: .medium))
        .foregroundStyle(.white.opacity(0.45))
        .lineLimit(1)
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        if isCopied {
            Label("Copied", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
        } else if isSelected {
            Image(systemName: "return")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.trailing, 6)
                .transition(.opacity)
        }
    }
}

// MARK: - ClipboardListThumbnail

/// Small square preview leading a list row.
private struct ClipboardListThumbnail: View {
    let item: ClipboardItem

    @Environment(ClipboardStateViewModel.self) private var clipboard

    var body: some View {
        let size = ClipboardListMetrics.thumbnailSize
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)

        content
            .frame(width: size, height: size)
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(.white.opacity(0.08), lineWidth: 1)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch item.content {
        case let .image(image):
            AsyncThumbnail(url: clipboard.imageURL(named: image.fileName), maxPixelSize: 120) { tileBackground }
        case let .files(urls) where item.kind == .image:
            AsyncThumbnail(url: urls[0], maxPixelSize: 120) { tileBackground }
        case let .files(urls):
            Image(nsImage: NSWorkspace.shared.icon(forFile: urls[0].path(percentEncoded: false)))
                .resizable()
                .padding(4)
                .background(tileBackground)
        case let .link(link):
            if let imageName = link.previewImageName {
                AsyncThumbnail(url: clipboard.imageURL(named: imageName), maxPixelSize: 120) { textTile(link.url.absoluteString) }
            } else {
                textTile(link.url.absoluteString)
            }
        case let .color(color):
            Color(color)
        case let .contact(contact):
            ContactAvatar(contact: contact, size: ClipboardListMetrics.thumbnailSize)
        case let .text(text):
            textTile(text)
        case let .richText(payload):
            textTile(payload.plainText)
        case let .code(code):
            Text(CodeHighlighter.highlight(CodeHighlighter.excerpt(of: code, maxLines: 5)))
                .font(.system(size: 5.5, design: .monospaced))
                .fixedSize()
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(ClipboardPalette.graphite)
        }
    }

    private var tileBackground: Color {
        Color(hex: 0x2C2C2E)
    }

    /// A miniature of the text, like a document icon.
    private func textTile(_ text: String) -> some View {
        Text(String(text.prefix(80)))
            .font(.system(size: 6.5, weight: .semibold))
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(4)
            .padding(4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(tileBackground)
    }
}

// MARK: - ContactAvatar

/// Initials on a color picked from the name, like Contacts does without a photo.
struct ContactAvatar: View {
    let contact: ClipboardContent.ContactPayload
    let size: CGFloat

    private static let colors: [Color] = [
        Color(hex: 0x5B4FD6),
        Color(hex: 0xE5484D),
        Color(hex: 0x12A594),
        Color(hex: 0xF76B15),
        Color(hex: 0x3E63DD),
        Color(hex: 0x8E4EC6),
        Color(hex: 0xD6409F),
    ]

    var body: some View {
        Text(contact.initials)
            .font(.system(size: size * 0.34, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: Circle())
    }

    /// Stable across launches, unlike `hashValue`.
    private var color: Color {
        let seed = contact.name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Self.colors[seed % Self.colors.count]
    }
}

// MARK: - List title

extension ClipboardContent {
    /// Single line describing the content in the list.
    var listTitle: String {
        switch self {
        case let .text(text), let .code(text):
            Self.firstLine(of: text)
        case let .richText(payload):
            Self.firstLine(of: payload.plainText)
        case let .link(link):
            link.title ?? link.url.absoluteString
        case let .color(color):
            color.rawValue.hasPrefix("#") ? color.hexString : "\(color.hexString)  ·  \(color.rawValue)"
        case let .image(image):
            String(localized: "Image  ·  \(image.pixelWidth) × \(image.pixelHeight)")
        case let .files(urls):
            urls.count == 1 ? urls[0].lastPathComponent : String(localized: "\(urls.count) files")
        case let .contact(contact):
            [contact.name, contact.organization].compactMap { $0 }.joined(separator: "  ·  ")
        }
    }

    private static func firstLine(of text: String) -> String {
        let line = text
            .split(whereSeparator: \.isNewline)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.trimmingCharacters(in: .whitespaces) }
        return String((line ?? "").prefix(200))
    }
}
