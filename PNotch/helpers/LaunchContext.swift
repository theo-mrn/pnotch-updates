//
//  LaunchContext.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import AppKit

enum LaunchContext {
    /// Whether macOS started PNotch as a login item. Only meaningful while the app finishes launching.
    static var wasLaunchedAtLogin: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return event.eventID == kAEOpenApplication
            && event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
}
