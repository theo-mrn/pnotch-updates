//
//  NotchHeaderView.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Defaults
import SwiftUI

/// Top row of the opened notch, level with the menu bar and split around the camera housing:
/// tabs on the left; the companion, the page's own buttons, then settings, on the right.
struct NotchHeaderView<PageActions: View>: View {
    @ViewBuilder let pageActions: () -> PageActions

    @Environment(PNotchViewModel.self) private var vm
    @Environment(PNotchViewCoordinator.self) private var coordinator
    @Default(.companionOnEveryPage) private var companionOnEveryPage

    var body: some View {
        HStack(spacing: 0) {
            NotchTabBar()
                .frame(maxWidth: .infinity, alignment: .leading)

            Color.clear
                .frame(width: vm.geometry.notchSize.width + NotchMetrics.cameraClearance)

            HStack(spacing: 6) {
                // Its own page already shows it in full.
                if companionOnEveryPage, vm.page != .companion {
                    HeaderCompanionView()
                        .padding(.trailing, 4)
                }

                pageActions()

                HoverButton(systemImage: "gearshape.fill") {
                    coordinator.showSettings()
                }
                .help("Settings")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, NotchHeaderMetrics.horizontalPadding)
        .frame(height: vm.geometry.notchSize.height)
    }
}

extension NotchHeaderView where PageActions == EmptyView {
    init() {
        self.init { EmptyView() }
    }
}
