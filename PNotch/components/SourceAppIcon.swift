//
//  SourceAppIcon.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// Icon of the application something was copied from.
struct SourceAppIcon: View {
    let app: SourceApplication?
    var size: CGFloat = 18

    var body: some View {
        if let app, let icon = AppIcons.icon(forBundleIdentifier: app.bundleIdentifier) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .help(app.name)
                .accessibilityLabel(app.name)
        }
    }
}
