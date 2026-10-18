//
//  AsyncThumbnail.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// Image file decoded off the main thread, filling its frame (aspect fill, clipped).
struct AsyncThumbnail<Placeholder: View>: View {
    let url: URL
    let maxPixelSize: Int
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: NSImage?

    init(url: URL, maxPixelSize: Int, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.maxPixelSize = maxPixelSize
        self.placeholder = placeholder
        _image = State(initialValue: ThumbnailService.shared.cachedImage(at: url, maxPixelSize: maxPixelSize))
    }

    var body: some View {
        Color.clear
            .overlay {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                } else {
                    placeholder()
                }
            }
            .clipped()
            .task(id: url) {
                guard image == nil else { return }
                image = await ThumbnailService.shared.image(at: url, maxPixelSize: maxPixelSize)
            }
    }
}
