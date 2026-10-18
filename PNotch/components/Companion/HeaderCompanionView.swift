//
//  HeaderCompanionView.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import AppKit
import Defaults
import SwiftUI

/// The companion on every page, next to the header buttons, with something to do on each:
/// headphones on for the music, reading the clipboard, wired to the system metrics through the plug it holds,
/// Claude's star in its eyes while Claude works. A click pets it, or takes you
/// to Claude Code when it calls you; a right-click has the page's shortcuts.
struct HeaderCompanionView: View {
    @Environment(CompanionManager.self) private var companion
    @Environment(PNotchViewModel.self) private var vm
    @Environment(MusicManager.self) private var music
    @Environment(ClipboardStateViewModel.self) private var clipboard
    @Environment(ClaudeCodeManager.self) private var claudeCode
    @Default(.companionName) private var name

    var body: some View {
        RobotView(framing: .bust, variant: variant)
            .frame(width: CompanionMetrics.headerRobotSize.width, height: CompanionMetrics.headerRobotSize.height)
            .contentShape(Rectangle())
            .onTapGesture(perform: handleClick)
            .help(activity == .alert ? String(localized: "Answer Claude Code") : String(localized: "Pet \(name)"))
            .contextMenu {
                pageActions
                Divider()
                Button(String(localized: "Pet \(name)")) {
                    companion.pet()
                }
                Button(String(localized: "Go to \(name)'s Page")) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        vm.select(.companion)
                    }
                }
            }
            // A new song while it listens: it jumps with joy.
            .onChange(of: music.playback?.title) { previous, current in
                if vm.page == .music, previous != nil, current != nil, previous != current {
                    companion.bring(.newTrack)
                }
            }
            // The CPU reading feeds the "hot" mood and the antenna on the System page.
            .onAppear { companion.system.startObserving() }
            .onDisappear { companion.system.stopObserving() }
    }

    // MARK: Variant

    private var activity: CompanionActivity? {
        CompanionActivity.resolve(CompanionActivity.Inputs(
            page: vm.page,
            isMusicPlaying: music.isPlaying,
            searchQuery: clipboard.searchQuery,
            searchResultCount: clipboard.visibleItems.count,
            isClaudeCodeWorking: claudeCode.sessions.contains(where: \.isWorking),
            claudeCodeNeedsYou: claudeCode.needsAttention
        ))
    }

    private var variant: RobotVariant {
        RobotVariant(
            activity: activity,
            noteColor: vm.page == .music ? music.accentColor : nil,
            bulbColor: bulbColor,
            cables: vm.page == .system ? cables : []
        )
    }

    /// Processor, graphics, memory and network, in the colors of their tiles.
    private var cables: [RobotCable] {
        let system = companion.system
        let traffic = system.network.map { $0.download + $0.upload } ?? 0
        return [
            RobotCable(tint: MetricColor.cpu, flow: system.cpu?.total ?? 0),
            RobotCable(tint: MetricColor.gpu, flow: system.gpuUtilization ?? 0),
            RobotCable(tint: MetricColor.good, flow: (system.memory?.fraction ?? 0) * 0.6),
            RobotCable(tint: MetricColor.download, flow: CompanionCables.networkFlow(bytesPerSecond: traffic)),
        ]
    }

    private var bulbColor: Color? {
        switch activity {
        case .thinking, .alert:
            return ClaudeCodeSpinner.tint
        default:
            guard vm.page == .system, let cpu = companion.system.cpu?.total else { return nil }
            switch CompanionLoadLevel(cpuUsage: cpu) {
            case .calm: return .green
            case .busy: return Color(hex: 0xFFB340)
            case .strained: return Color(hex: 0xFF5F57)
            }
        }
    }

    // MARK: Interactions

    private func handleClick() {
        if activity == .alert, case let .needsYou(session) = claudeCode.liveActivity {
            claudeCode.open(session)
            vm.close(reason: .switchedApp)
        } else {
            companion.pet()
        }
    }

    @ViewBuilder
    private var pageActions: some View {
        switch vm.page {
        case .music:
            if music.playback != nil {
                Button(music.isPlaying ? "Pause" : "Play") {
                    music.togglePlayPause()
                }
                Button("Next track") {
                    music.nextTrack()
                    companion.bring(.newTrack)
                }
            }
        case .clipboard:
            if clipboard.isSearching {
                Button("Clear the Search") {
                    clipboard.clearSearch()
                }
            }
        case .system:
            Button("Open Activity Monitor") {
                guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") else { return }
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            }
        case .claudeCode:
            if case let .needsYou(session) = claudeCode.liveActivity {
                Button(String(localized: "Answer Claude in \(session.projectName)")) {
                    claudeCode.open(session)
                    vm.close(reason: .switchedApp)
                }
            }
        case .companion:
            EmptyView()
        }
    }
}
