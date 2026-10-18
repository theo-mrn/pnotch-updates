//
//  CompanionCables.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import CoreGraphics
import Foundation

/// On the System page the companion holds a multi-socket plug, one cable per metric coming up to it from below,
/// data climbing each cable as fast as the metric is busy. Every few seconds it gives them a tug.
/// Coordinates are in the robot's design space (see `RobotRenderer.bustBounds`).
nonisolated enum CompanionCables {
    /// How often the robot tugs at the cables, and how long a tug lasts.
    static let tugPeriod: TimeInterval = 4.5
    static let tugDuration: TimeInterval = 0.6

    /// Center of the plug held in front of the mouth, at rest: just under the eyes, high enough for the cables
    /// to show below it.
    static let plugCenter = CGPoint(x: 60, y: 75)
    static let plugSize = CGSize(width: 46, height: 14)
    /// How high a tug lifts the plug.
    static let tugLift: CGFloat = 4

    /// 0 at rest, rising to 1 and back during a tug. The pose and the cables read the same clock.
    static func tug(at time: TimeInterval) -> Double {
        let phase = time.truncatingRemainder(dividingBy: tugPeriod)
        guard phase >= 0, phase < tugDuration else { return 0 }
        return sin(phase / tugDuration * .pi)
    }

    /// Network traffic on a 0...1 scale: logarithmic, so a few kB/s already show and 100 MB/s fills it.
    static func networkFlow(bytesPerSecond: Double) -> Double {
        guard bytesPerSecond > 0 else { return 0 }
        return min(max(log10(bytesPerSecond / 100) / 6, 0), 1)
    }

    /// Laps per second of the data along a cable.
    static func packetSpeed(flow: Double) -> Double {
        0.2 + min(max(flow, 0), 1) * 1.3
    }

    /// Where the plug is: lifted during a tug.
    static func plug(tug: Double) -> CGRect {
        CGRect(
            x: plugCenter.x - plugSize.width / 2,
            y: plugCenter.y - plugSize.height / 2 - tugLift * tug,
            width: plugSize.width,
            height: plugSize.height
        )
    }

    /// Cable `index` of `count`: from its socket under the plug, fanning out and down out of the frame.
    /// Pulled straighter during a tug.
    static func cable(_ index: Int, of count: Int, tug: Double) -> Cubic {
        let plug = plug(tug: tug)
        let spread = count > 1 ? CGFloat(index) / CGFloat(count - 1) - 0.5 : 0
        let start = CGPoint(x: plug.midX + spread * (plug.width - 10), y: plug.maxY - 1)
        let end = CGPoint(x: 60 + spread * 130, y: 112)
        let slack = 9 * (1 - 0.7 * tug)
        return Cubic(
            start: start,
            control1: CGPoint(x: start.x, y: start.y + slack),
            control2: CGPoint(x: end.x, y: end.y - 6 - slack),
            end: end
        )
    }

    struct Cubic: Equatable, Sendable {
        let start: CGPoint
        let control1: CGPoint
        let control2: CGPoint
        let end: CGPoint

        func point(at u: Double) -> CGPoint {
            let v = 1 - u
            let a = v * v * v, b = 3 * v * v * u, c = 3 * v * u * u, d = u * u * u
            return CGPoint(
                x: a * start.x + b * control1.x + c * control2.x + d * end.x,
                y: a * start.y + b * control1.y + c * control2.y + d * end.y
            )
        }
    }
}
