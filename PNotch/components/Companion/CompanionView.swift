//
//  CompanionView.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// The companion's page: the robot on the left, focus sessions with it on the right,
/// or its wardrobe while customizing.
struct CompanionView: View {
    @Environment(CompanionManager.self) private var companion
    @Environment(FocusManager.self) private var focus
    @State private var isCustomizing = false

    var body: some View {
        VStack(spacing: 0) {
            NotchHeaderView {
                HoverButton(systemImage: "paintbrush.fill", isActive: isCustomizing) {
                    withAnimation(.smooth(duration: 0.25)) { isCustomizing.toggle() }
                }
                .help("Customize")
            }

            HStack(spacing: 18) {
                RobotView(variant: RobotVariant(activity: activity))
                    .frame(width: CompanionMetrics.robotSize.width, height: CompanionMetrics.robotSize.height)
                    .contentShape(Rectangle())
                    .onTapGesture { companion.pet() }
                    .help("Pet")

                Group {
                    if isCustomizing {
                        CompanionCustomizationView {
                            withAnimation(.smooth(duration: 0.25)) { isCustomizing = false }
                        }
                    } else {
                        CompanionFocusView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .transition(.opacity)
            }
            .padding(.horizontal, CompanionMetrics.horizontalPadding)
            .frame(height: CompanionMetrics.bodyHeight)
        }
        // The CPU reading feeds the "hot" mood: sample only while the robot is on screen.
        .onAppear { companion.system.startObserving() }
        .onDisappear { companion.system.stopObserving() }
    }

    /// Headband on while you focus, a warm drink during the break.
    private var activity: CompanionActivity? {
        CompanionActivity.resolve(CompanionActivity.Inputs(page: .companion, focusPhase: focus.runningPhase))
    }
}
