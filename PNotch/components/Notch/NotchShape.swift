//
//  NotchShape.swift
//  PNotch
//
//  Adapted from DynamicNotchKit by Kai Azim (MIT License).
//  https://github.com/MrKai77/DynamicNotchKit
//

import SwiftUI

/// Outline of the notch: concave "ears" blending into the top edge of the screen, rounded bottom corners.
///
/// The ears take `topCornerRadius` points on each side, so the content should be inset horizontally by that amount.
nonisolated struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    init(radii: NotchCornerRadii) {
        topCornerRadius = radii.top
        bottomCornerRadius = radii.bottom
    }

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let top = topCornerRadius
        let bottom = min(bottomCornerRadius, rect.height - top, (rect.width - top * 2) / 2)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Leading ear and edge.
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + top, y: rect.minY + top),
            control: CGPoint(x: rect.minX + top, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + top, y: rect.maxY - bottom))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + top + bottom, y: rect.maxY),
            control: CGPoint(x: rect.minX + top, y: rect.maxY)
        )

        // Bottom edge.
        path.addLine(to: CGPoint(x: rect.maxX - top - bottom, y: rect.maxY))

        // Trailing edge and ear.
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - top, y: rect.maxY - bottom),
            control: CGPoint(x: rect.maxX - top, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY + top))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - top, y: rect.minY)
        )

        path.closeSubpath()
        return path
    }
}

#Preview {
    NotchShape(radii: .opened)
        .frame(width: 420, height: 120)
        .padding(20)
}
