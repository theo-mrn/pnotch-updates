//
//  EventMonitor.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import AppKit

/// Owns an `NSEvent` monitor and removes it when released.
final class EventMonitor {
    nonisolated(unsafe) private var token: Any?

    private init(token: Any?) {
        self.token = token
    }

    deinit {
        if let token {
            NSEvent.removeMonitor(token)
        }
    }

    /// Events sent to PNotch's own windows. Return `nil` from `handler` to swallow the event.
    static func local(
        matching mask: NSEvent.EventTypeMask,
        handler: @escaping (NSEvent) -> NSEvent?
    ) -> EventMonitor {
        EventMonitor(token: NSEvent.addLocalMonitorForEvents(matching: mask, handler: handler))
    }

    /// Events sent to other applications. They can be observed but not modified.
    static func global(
        matching mask: NSEvent.EventTypeMask,
        handler: @escaping (NSEvent) -> Void
    ) -> EventMonitor {
        EventMonitor(token: NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler))
    }

    func stop() {
        if let token {
            NSEvent.removeMonitor(token)
        }
        token = nil
    }
}
