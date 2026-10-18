//
//  NotchAnimations.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

extension Animation {
    /// Slightly bouncy, like the Dynamic Island growing.
    static let notchOpen = Animation.spring(response: 0.42, dampingFraction: 0.8)
    /// Critically damped: the notch folds back without overshooting above the screen edge.
    static let notchClose = Animation.spring(response: 0.38, dampingFraction: 1)
    static let notchHover = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let sneakPeek = Animation.spring(response: 0.36, dampingFraction: 0.74)
}

extension AnyTransition {
    static func blur(radius: CGFloat) -> AnyTransition {
        .modifier(active: BlurModifier(radius: radius), identity: BlurModifier(radius: 0))
    }

    /// Content of the opened notch: grows out of the camera housing and fades in once the shape has room.
    static var notchContent: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.92, anchor: .top))
                .combined(with: .blur(radius: 10))
                .animation(.smooth(duration: 0.32).delay(0.06)),
            removal: .opacity
                .combined(with: .scale(scale: 0.96, anchor: .top))
                .animation(.smooth(duration: 0.16))
        )
    }
}

private struct BlurModifier: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}
