//
//  MetricSparkline.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// History of a metric, newest value on the right edge, scrolling left as samples arrive.
struct MetricSparkline: View {
    let values: [Double]
    let color: Color
    /// Draws a second series as a plain line, e.g. upload next to download.
    var secondaryValues: [Double] = []
    var secondaryColor: Color = .white
    /// Top of the scale. `nil` scales to the largest value shown, never below `minimumScale`.
    var maxValue: Double? = 1
    var minimumScale: Double = 1
    var capacity = SystemMonitor.historyLength

    var body: some View {
        GeometryReader { geometry in
            let scale = maxValue ?? max(values.max() ?? 0, secondaryValues.max() ?? 0, minimumScale)
            let points = points(for: values, scale: scale, in: geometry.size)

            ZStack {
                // Baseline, so a chart that just started filling doesn't look broken.
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height - 0.5))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height - 0.5))
                }
                .stroke(.white.opacity(0.08), lineWidth: 1)

                if points.count > 1 {
                    area(through: points, height: geometry.size.height)
                        .fill(LinearGradient(colors: [color.opacity(0.35), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                    line(through: points)
                        .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }

                let secondaryPoints = self.points(for: secondaryValues, scale: scale, in: geometry.size)
                if secondaryPoints.count > 1 {
                    line(through: secondaryPoints)
                        .stroke(secondaryColor, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func points(for values: [Double], scale: Double, in size: CGSize) -> [CGPoint] {
        guard scale > 0 else { return [] }
        let step = size.width / CGFloat(max(capacity - 1, 1))
        return values.enumerated().map { index, value in
            let x = size.width - CGFloat(values.count - 1 - index) * step
            let y = size.height * (1 - CGFloat(min(max(value / scale, 0), 1)))
            return CGPoint(x: x, y: y)
        }
    }

    private func line(through points: [CGPoint]) -> Path {
        Path { path in
            path.addLines(points)
        }
    }

    private func area(through points: [CGPoint], height: CGFloat) -> Path {
        Path { path in
            guard let first = points.first, let last = points.last else { return }
            path.move(to: CGPoint(x: first.x, y: height))
            path.addLines(points)
            path.addLine(to: CGPoint(x: last.x, y: height))
            path.closeSubpath()
        }
    }
}
