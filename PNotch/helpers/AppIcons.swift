//
//  AppIcons.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import AppKit

/// Application icons looked up by bundle identifier, cached for the session.
enum AppIcons {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(forBundleIdentifier bundleIdentifier: String) -> NSImage? {
        let key = bundleIdentifier as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return nil }

        let icon = NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
        cache.setObject(icon, forKey: key)
        return icon
    }
}
