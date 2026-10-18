//
//  NotchAutoCloseTests.swift
//  PNotchTests
//
//  Created by Theo Morin on 17/10/2026.
//

import AppKit
import Testing
@testable import PNotch

/// The notch must only fold back on its own when the user is really done with it.
@MainActor
struct NotchAutoCloseTests {
    /// Long enough for the pointer-away check (100 ms polling + 250 ms grace) to conclude.
    private let settleTime: Duration = .milliseconds(700)

    private final class Pointer {
        var location: CGPoint = .zero
    }

    private let pointer = Pointer()

    private func makeOpenedNotch(reason: NotchOpenReason = .click) -> PNotchViewModel {
        let pointer = pointer
        let vm = PNotchViewModel(screen: nil, page: .clipboard) { pointer.location }
        pointer.location = CGPoint(x: vm.openedScreenRect.midX, y: vm.openedScreenRect.midY)
        vm.open(reason: reason)
        return vm
    }

    /// Waits for the notch to fold back on its own. The whole suite shares the main actor,
    /// so the pointer-away polling can run late: a fixed delay would make the test flaky.
    private func waitUntilClosed(_ vm: PNotchViewModel, timeout: Duration = .seconds(5)) async throws {
        let deadline = ContinuousClock.now + timeout
        while vm.notchState != .closed, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    private func movePointerAway(from vm: PNotchViewModel) {
        pointer.location = CGPoint(x: vm.openedScreenRect.midX, y: vm.openedScreenRect.minY - 120)
    }

    @Test func closesOnceThePointerHasLeft() async throws {
        let vm = makeOpenedNotch()
        movePointerAway(from: vm)
        vm.handleHover(false)

        try await waitUntilClosed(vm)
        #expect(vm.notchState == .closed)
    }

    @Test func ignoresHoverExitsWhileThePointerIsStillOnThePanel() async throws {
        let vm = makeOpenedNotch()
        // SwiftUI reports an exit, e.g. when the pointer crosses into the search field.
        vm.handleHover(false)

        try await Task.sleep(for: settleTime)
        #expect(vm.notchState == .open)

        // Leaving for real afterwards still closes it, even without a new hover event.
        movePointerAway(from: vm)
        try await waitUntilClosed(vm)
        #expect(vm.notchState == .closed)
    }

    @Test func staysOpenWhileTyping() async throws {
        let vm = makeOpenedNotch()
        var isTyping = true
        vm.isKeyboardFocused = { isTyping }
        movePointerAway(from: vm)
        vm.handleHover(false)

        try await Task.sleep(for: settleTime)
        #expect(vm.notchState == .open)

        isTyping = false
        try await waitUntilClosed(vm)
        #expect(vm.notchState == .closed)
    }

    @Test func keyboardOpenedNotchIgnoresThePointer() async throws {
        let vm = makeOpenedNotch(reason: .keyboard)
        movePointerAway(from: vm)
        vm.handleHover(false)

        try await Task.sleep(for: settleTime)
        #expect(vm.notchState == .open)
    }

    @Test func clicksOnThePanelAreNotOutsideClicks() {
        let vm = makeOpenedNotch()
        let panel = vm.openedScreenRect

        vm.handleClick(at: CGPoint(x: panel.midX, y: panel.maxY - 10))
        #expect(vm.notchState == .open)

        vm.handleClick(at: CGPoint(x: panel.midX, y: panel.minY - 50))
        #expect(vm.notchState == .closed)
    }
}
