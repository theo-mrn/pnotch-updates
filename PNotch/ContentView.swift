//
//  ContentView.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Defaults
import SwiftUI

/// Root view of the notch window: the black notch shape, growing from the camera housing
/// into the opened panel, a sneak peek or the music live activity.
struct ContentView: View {
    @Environment(PNotchViewModel.self) private var vm
    @Environment(PNotchViewCoordinator.self) private var coordinator
    @Environment(MusicManager.self) private var music
    @Environment(ClaudeCodeManager.self) private var claudeCode
    @Environment(FocusManager.self) private var focus
    @Default(.showMusicLiveActivity) private var showMusicLiveActivity
    @Default(.showClaudeCodeLiveActivity) private var showClaudeCodeLiveActivity
    @State private var hoverFeedbackTrigger = false

    var body: some View {
        notch
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .preferredColorScheme(.dark)
    }

    // MARK: Notch

    private var isOpen: Bool {
        vm.notchState == .open
    }

    private var sneakPeek: SneakPeek? {
        isOpen ? nil : coordinator.sneakPeek
    }

    // What the closed notch shows around the camera, most important first: a sneak peek, a Claude Code
    // session waiting for you, the focus countdown, the music, then a busy Claude Code session.

    private var isClosedAndFree: Bool {
        !isOpen && sneakPeek == nil
    }

    private var claudeCodeWaiting: ClaudeCodeManager.LiveActivity? {
        guard isClosedAndFree, showClaudeCodeLiveActivity, let activity = claudeCode.liveActivity, activity.isWaiting else { return nil }
        return activity
    }

    private var focusSession: FocusSession? {
        guard isClosedAndFree, claudeCodeWaiting == nil else { return nil }
        return focus.session
    }

    /// The closed notch widens around the camera while music plays.
    private var showsMusicActivity: Bool {
        isClosedAndFree && claudeCodeWaiting == nil && focusSession == nil && showMusicLiveActivity && music.isPlaying
    }

    private var claudeCodeActivity: ClaudeCodeManager.LiveActivity? {
        if let claudeCodeWaiting {
            return claudeCodeWaiting
        }
        guard isClosedAndFree, focusSession == nil, !showsMusicActivity, showClaudeCodeLiveActivity else { return nil }
        return claudeCode.liveActivity
    }

    /// Something is shown on both sides of the camera.
    private var showsSideActivity: Bool {
        sneakPeek != nil || claudeCodeActivity != nil || focusSession != nil || showsMusicActivity
    }

    /// Size of the notch body, ears excluded.
    private var bodySize: CGSize {
        if isOpen {
            return vm.openedSize
        }
        if showsSideActivity {
            return vm.geometry.sneakPeekSize
        }
        return vm.notchSize
    }

    private var cornerRadii: NotchCornerRadii {
        if isOpen {
            return .opened
        }
        return showsSideActivity || vm.isHovering ? .sneakPeek : .closed
    }

    private var notch: some View {
        let radii = cornerRadii

        return ZStack(alignment: .top) {
            if isOpen {
                ZStack(alignment: .top) {
                    // Pages cross-fade while the notch resizes from one to the other.
                    openedContent
                        .id(vm.page)
                        .transition(.asymmetric(
                            insertion: .opacity.animation(.smooth(duration: 0.25).delay(0.1)),
                            removal: .opacity.animation(.smooth(duration: 0.1))
                        ))
                }
                .frame(width: vm.openedSize.width, height: vm.openedSize.height, alignment: .top)
                .transition(.notchContent)
            } else if let sneakPeek {
                Group {
                    switch sneakPeek.content {
                    case let .copy(copy):
                        ClipboardSneakPeekView(peek: copy, id: sneakPeek.id, notchSize: vm.geometry.notchSize)
                    case let .claudeCode(outcome):
                        ClaudeCodeSneakPeekView(outcome: outcome, notchSize: vm.geometry.notchSize)
                    case let .focus(event):
                        FocusSneakPeekView(event: event, notchSize: vm.geometry.notchSize)
                    }
                }
                .transition(.opacity.combined(with: .blur(radius: 6)))
            } else if let claudeCodeWaiting {
                ClaudeCodeLiveActivityView(activity: claudeCodeWaiting, notchSize: vm.geometry.notchSize)
                    .transition(.opacity.combined(with: .blur(radius: 6)))
            } else if let focusSession {
                FocusLiveActivityView(session: focusSession, notchSize: vm.geometry.notchSize)
                    .id(focusSession.phase)
                    .transition(.opacity.combined(with: .blur(radius: 6)))
            } else if let claudeCodeActivity {
                ClaudeCodeLiveActivityView(activity: claudeCodeActivity, notchSize: vm.geometry.notchSize)
                    .transition(.opacity.combined(with: .blur(radius: 6)))
            } else if showsMusicActivity {
                MusicLiveActivityView(notchSize: vm.geometry.notchSize)
                    .transition(.opacity.combined(with: .blur(radius: 6)))
            }
        }
        .frame(width: bodySize.width, height: bodySize.height, alignment: .top)
        .padding(.horizontal, radii.top)
        .background {
            NotchBackground(isOpen: isOpen)
        }
        .clipShape(NotchShape(radii: radii))
        .shadow(color: .black.opacity(isOpen ? 0.5 : 0), radius: 16, y: 6)
        .contentShape(NotchShape(radii: radii))
        .onHover(perform: handleHover)
        .gesture(
            TapGesture().onEnded { vm.handleTapOnClosedNotch() },
            including: isOpen ? .subviews : .all
        )
        .sensoryFeedback(.alignment, trigger: hoverFeedbackTrigger) { _, _ in
            Defaults[.enableHaptics]
        }
        .animation(isOpen ? .notchOpen : .notchClose, value: isOpen)
        // Switching page or to the list, or the list following its results as you type.
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: vm.openedSize)
        .animation(.sneakPeek, value: sneakPeek)
        .animation(.sneakPeek, value: showsMusicActivity)
        .animation(.sneakPeek, value: claudeCodeActivity?.isWaiting)
        .animation(.sneakPeek, value: focusSession?.phase)
        .animation(.notchHover, value: vm.isHovering)
    }

    @ViewBuilder
    private var openedContent: some View {
        switch vm.layout {
        case .music:
            MusicView()
        case .system:
            SystemView()
        case .companion:
            CompanionView()
        case .claudeCode:
            ClaudeCodeView()
        case .clipboardList:
            ClipboardListView()
        }
    }

    private func handleHover(_ hovering: Bool) {
        if hovering, !isOpen {
            hoverFeedbackTrigger.toggle()
        }
        vm.handleHover(hovering)
    }
}

// MARK: - NotchBackground

/// Pure black where the panel meets the camera housing, lifting slightly towards the bottom when opened.
private struct NotchBackground: View {
    let isOpen: Bool

    var body: some View {
        Rectangle()
            .fill(.black)
            .overlay {
                LinearGradient(
                    colors: [.clear, Color(hex: 0x1B1A17)],
                    startPoint: UnitPoint(x: 0.5, y: 0.3),
                    endPoint: .bottom
                )
                .opacity(isOpen ? 1 : 0)
            }
    }
}
