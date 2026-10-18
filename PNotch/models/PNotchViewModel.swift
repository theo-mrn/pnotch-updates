//
//  PNotchViewModel.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import AppKit
import Defaults
import Observation
import os

/// Owns the open / closed state of the notch and the rules deciding when it opens or closes on its own.
@Observable
final class PNotchViewModel {
    private(set) var notchState: NotchState = .closed
    /// The tab shown by the opened notch, remembered across launches.
    private(set) var page: NotchPage
    /// How the clipboard page is laid out: cards under the pointer, a list under the keyboard.
    private(set) var openReason: NotchOpenReason?
    private(set) var geometry: NotchGeometry
    private(set) var isHovering = false

    /// Asks the hosting window to take (`true`) or give back (`false`) keyboard focus.
    @ObservationIgnored var onKeyboardFocusRequest: ((Bool) -> Void)?
    /// Whether the user is typing in the notch. Read live by the auto-close rules, set by the window controller.
    @ObservationIgnored var isKeyboardFocused: () -> Bool = { false }
    /// A page that needs the user more than the usual one, e.g. Claude Code waiting for an answer.
    /// Opening the notch shows it.
    @ObservationIgnored var urgentPage: () -> NotchPage? = { nil }
    /// Number of items the list shows, so it can shrink around few results.
    @ObservationIgnored var listItemCount: () -> Int = { .max }

    @ObservationIgnored private let pointerLocation: () -> CGPoint
    @ObservationIgnored private var hoverTask: Task<Void, Never>?
    @ObservationIgnored private var pointerAwayTask: Task<Void, Never>?
    @ObservationIgnored private var copyCloseTask: Task<Void, Never>?
    @ObservationIgnored private var hasPointerVisitedOpenNotch = false
    @ObservationIgnored private var isMenuTracking = false
    @ObservationIgnored private var menuObservers: [NSObjectProtocol] = []

    /// - Parameters:
    ///   - page: The tab shown first, the last one used by default.
    ///   - pointerLocation: Pointer position in screen coordinates. Injectable for tests.
    init(
        screen: NSScreen?,
        page: NotchPage = Defaults[.lastNotchPage],
        pointerLocation: @escaping () -> CGPoint = { NSEvent.mouseLocation }
    ) {
        geometry = NotchGeometry(screen: screen)
        self.page = page
        self.pointerLocation = pointerLocation
        observeMenuTracking()
    }

    var notchSize: CGSize {
        switch notchState {
        case .open:
            openedSize
        case .closed:
            isHovering ? geometry.hoveredSize : geometry.closedSize
        }
    }

    var layout: NotchLayout {
        switch page {
        case .music: .music
        case .system: .system
        case .companion: .companion
        case .claudeCode: .claudeCode
        case .clipboard: .clipboardList(itemCount: listItemCount())
        }
    }

    /// Size of the opened notch for the current layout, ears excluded.
    var openedSize: CGSize {
        geometry.openedSize(for: layout)
    }

    /// Screen area of the opened notch, used to tell clicks and pointer moves inside it from outside ones.
    var openedScreenRect: CGRect {
        geometry.openedScreenRect(for: layout)
    }

    func updateGeometry(for screen: NSScreen?) {
        geometry = NotchGeometry(screen: screen)
    }

    // MARK: Opening and closing

    /// Opens the notch, or switches an opened notch to `page`.
    /// - Parameter page: `nil` keeps the page the notch was left on.
    func open(reason: NotchOpenReason, page: NotchPage? = nil) {
        cancelPendingTransitions()
        if let page {
            self.page = page
        } else if notchState != .open {
            self.page = urgentPage()
                ?? NotchTabsConfiguration.current.pageToOpen(startPage: Defaults[.startPage], lastPage: self.page)
        }

        if notchState != .open {
            openReason = reason
            // Leaving the notch only closes it once the pointer has been inside.
            hasPointerVisitedOpenNotch = reason == .hover || reason == .click
            notchState = .open
        }
        // Explicit opens of the clipboard take the keyboard so typing searches right away.
        // Hovering never steals it.
        if reason == .keyboard || (reason == .click && self.page == .clipboard) {
            onKeyboardFocusRequest?(true)
        }
    }

    var isShowingClipboard: Bool {
        notchState == .open && page == .clipboard
    }

    /// Switches tab from the header. The choice is remembered for the next opening.
    func select(_ page: NotchPage) {
        guard page != self.page else { return }
        self.page = page
        Defaults[.lastNotchPage] = page
    }

    func close(reason: NotchCloseReason) {
        cancelPendingTransitions()
        guard notchState == .open else { return }

        Logger.app.info("Closing the notch: \(String(describing: reason), privacy: .public)")
        notchState = .closed
        openReason = nil
        onKeyboardFocusRequest?(false)
    }

    /// Requests keyboard focus without changing the notch state, e.g. when the search field is clicked.
    func requestKeyboardFocus() {
        onKeyboardFocusRequest?(true)
    }

    /// Gets out of the way before ⌘V is sent.
    func dismissForPaste() {
        close(reason: .pasted)
    }

    /// Lets the "Copied" feedback play before folding the notch back.
    func closeAfterCopy() {
        guard Defaults[.closeNotchAfterCopy], notchState == .open else { return }

        copyCloseTask?.cancel()
        copyCloseTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard let self, !Task.isCancelled else { return }
            close(reason: .copied)
        }
    }

    // MARK: Pointer events

    func handleHover(_ hovering: Bool) {
        isHovering = hovering

        if hovering {
            pointerAwayTask?.cancel()
            if notchState == .open {
                hasPointerVisitedOpenNotch = true
            } else if Defaults[.openNotchOnHover] {
                scheduleHoverOpen()
            }
        } else {
            hoverTask?.cancel()
            if notchState == .open, hasPointerVisitedOpenNotch {
                closeOncePointerIsAway()
            }
        }
    }

    func handleTapOnClosedNotch() {
        open(reason: .click)
    }

    /// Called for clicks reported by the global monitor, i.e. landing in other apps.
    func handleClick(at location: CGPoint) {
        guard notchState == .open, !openedScreenRect.contains(location) else { return }
        close(reason: .clickOutside)
    }

    // MARK: Private

    private func scheduleHoverOpen() {
        hoverTask?.cancel()
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Defaults[.minimumHoverDuration]))
            guard let self, !Task.isCancelled, isHovering else { return }
            open(reason: .hover)
        }
    }

    /// Closes the notch once the pointer has really been outside of it for a moment.
    ///
    /// SwiftUI hover callbacks alone are not trusted: they also fire when the pointer crosses into the AppKit
    /// text field, when macOS hides the cursor during typing, or when the cards move under it.
    /// The pointer position is checked against the panel instead, and typing, menus, drags and the pin
    /// all keep the notch open.
    private func closeOncePointerIsAway() {
        pointerAwayTask?.cancel()
        pointerAwayTask = Task { [weak self] in
            var awaySince: ContinuousClock.Instant?

            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, !Task.isCancelled, notchState == .open else { return }

                if isHeldOpen || openedScreenRect.contains(pointerLocation()) {
                    awaySince = nil
                } else if let awaySince, ContinuousClock.now - awaySince >= .milliseconds(250) {
                    close(reason: .pointerLeft)
                    return
                } else if awaySince == nil {
                    awaySince = .now
                }
            }
        }
    }

    private var isHeldOpen: Bool {
        isMenuTracking || isKeyboardFocused() || NSEvent.pressedMouseButtons != 0
    }

    private func cancelPendingTransitions() {
        hoverTask?.cancel()
        pointerAwayTask?.cancel()
        copyCloseTask?.cancel()
    }

    private func observeMenuTracking() {
        let center = NotificationCenter.default
        let began = center.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isMenuTracking = true }
        }
        let ended = center.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isMenuTracking = false }
        }
        menuObservers = [began, ended]
    }
}

// MARK: - NotchGeometry + NSScreen

extension NotchGeometry {
    init(screen: NSScreen?) {
        self.init(
            screenFrame: screen?.frame ?? CGRect(x: 0, y: 0, width: 1512, height: 982),
            physicalNotchSize: screen?.notchSize
        )
    }
}
