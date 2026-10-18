//
//  NSScreen+Notch.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import AppKit

extension NSScreen {
    /// Size of the camera housing, or `nil` on displays without a notch.
    var notchSize: CGSize? {
        guard safeAreaInsets.top > 0,
              let leftArea = auxiliaryTopLeftArea,
              let rightArea = auxiliaryTopRightArea
        else { return nil }

        return CGSize(
            width: frame.width - leftArea.width - rightArea.width,
            height: safeAreaInsets.top
        )
    }

    var hasNotch: Bool {
        notchSize != nil
    }

    var isBuiltIn: Bool {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let displayID = (deviceDescription[key] as? NSNumber)?.uint32Value else { return false }
        return CGDisplayIsBuiltin(displayID) != 0
    }

    /// The display PNotch lives on: the built-in notched display when there is one, the main display otherwise.
    static var preferredNotchScreen: NSScreen? {
        screens.first { $0.isBuiltIn && $0.hasNotch } ?? screens.first(where: \.hasNotch) ?? main ?? screens.first
    }
}
