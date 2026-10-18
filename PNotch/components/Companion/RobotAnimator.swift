//
//  RobotAnimator.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// The robot's face.
enum RobotExpression: Equatable {
    case neutral
    case happy
    case sleepy
    case hot
    case excited
    case love
    /// Eyes narrowed on the lines it reads.
    case reading
    /// One eye wide, the other squinting.
    case puzzled
    /// Claude's star twinkling in each eye.
    case thinking
    /// The visor shows a terminal prompt.
    case terminal
}

/// Everything that moves, for one frame. Lengths are in the 120 × 140 design space of `RobotRenderer`.
struct RobotPose: Equatable {
    var expression: RobotExpression = .neutral
    /// Where the eyes look, each axis in -1...1.
    var gaze: CGVector = .zero
    /// 0 open, 1 closed.
    var blink: CGFloat = 0
    /// Vertical offset, negative goes up.
    var bob: CGFloat = 0
    var sway: CGFloat = 0
    var headTilt: Angle = .zero
    /// Vertical scale around the floor: below 1 squashes, above 1 stretches.
    var squash: CGFloat = 1
    var antennaAngle: Angle = .zero
    /// Positive raises the arm away from the body.
    var leftArm: Angle = .zero
    var rightArm: Angle = .zero
    /// Brightness of the eyes and the antenna bulb.
    var glow: CGFloat = 1
    var blush: CGFloat = 0
    /// Steps of what the visor shows when it isn't eyes: the star's frame, the cursor blinking.
    var visorTick = 0
}

/// Turns a mood and the clock into a pose. Pure functions of time: the same instant always gives the same frame.
enum RobotAnimator {
    /// - Parameters:
    ///   - activity: What the page it's on gives it to do. Ignored while it reacts to a pet or to news.
    ///   - gaze: Where the user's pointer is, as seen from the robot.
    ///   - sinceReaction: Time since the last pet or news, which make it jump.
    static func pose(
        mood: CompanionMood,
        activity: CompanionActivity? = nil,
        time t: TimeInterval,
        gaze: CGVector,
        sinceReaction: TimeInterval?
    ) -> RobotPose {
        var pose = moodPose(mood, time: t, gaze: gaze, sinceReaction: sinceReaction)
        if let activity, !mood.isReaction {
            apply(activity, to: &pose, time: t)
        }
        return pose
    }

    private static func moodPose(_ mood: CompanionMood, time t: TimeInterval, gaze: CGVector, sinceReaction: TimeInterval?) -> RobotPose {
        var pose = RobotPose()
        pose.gaze = gaze
        pose.blink = blink(at: t)
        pose.bob = sin(t * 2.1) * 2.5
        pose.headTilt = .degrees(Double(gaze.dx) * 5)
        pose.antennaAngle = .degrees(sin(t * 1.7) * 5)
        pose.leftArm = .degrees(6 + sin(t * 2.1 + 1) * 4)
        pose.rightArm = .degrees(6 - sin(t * 2.1 + 1) * 4)

        switch mood {
        case .content:
            break

        case .dancing:
            let beat = t * 6.2
            pose.expression = .happy
            pose.blink = 0
            pose.bob = sin(beat) * 4
            pose.sway = sin(beat / 2) * 5
            pose.headTilt = .degrees(sin(beat / 2) * 8)
            pose.antennaAngle = .degrees(sin(beat) * 14)
            pose.leftArm = .degrees(30 + sin(beat) * 35)
            pose.rightArm = .degrees(30 - sin(beat) * 35)
            pose.gaze = CGVector(dx: sin(beat / 2) * 0.6, dy: -0.2)

        case .hot:
            pose.expression = .hot
            pose.blink = 0
            pose.sway = sin(t * 40) * 0.8
            pose.bob = sin(t * 3) * 1.5
            pose.glow = 0.75 + 0.25 * sin(t * 8)
            pose.rightArm = .degrees(70 + sin(t * 14) * 20)
            pose.blush = 0.5

        case .sleepy:
            pose.expression = .sleepy
            pose.blink = 0
            pose.bob = sin(t * 0.9) * 1.5
            pose.headTilt = .degrees(9 + sin(t * 0.9) * 2)
            pose.antennaAngle = .degrees(20 + sin(t * 0.9) * 3)
            pose.leftArm = .degrees(2)
            pose.rightArm = .degrees(2)
            pose.glow = 0.45
            pose.gaze = CGVector(dx: 0, dy: 0.6)

        case .excited:
            pose.expression = .excited
            pose.blink = 0
            pose.glow = 1.2
            applyJump(to: &pose, since: sinceReaction ?? .infinity, height: 12)
            pose.leftArm = .degrees(60 + sin(t * 12) * 10)
            pose.rightArm = .degrees(60 - sin(t * 12) * 10)

        case .loved:
            pose.expression = .love
            pose.blink = 0
            pose.blush = 1
            pose.headTilt = .degrees(sin(t * 8) * 6)
            applyJump(to: &pose, since: sinceReaction ?? .infinity, height: 7)
            pose.leftArm = .degrees(-15)
            pose.rightArm = .degrees(-15)
        }
        return pose
    }

    private static func apply(_ activity: CompanionActivity, to pose: inout RobotPose, time t: TimeInterval) {
        switch activity {
        case .listening:
            pose = moodPose(.dancing, time: t, gaze: pose.gaze, sinceReaction: nil)

        case .waitingForMusic:
            // Nods along to a song in its head, an eye on the play button.
            pose.expression = .neutral
            pose.gaze = CGVector(dx: -0.35, dy: 0.55)
            pose.headTilt = .degrees(sin(t * 1.6) * 4)
            pose.bob = sin(t * 3.2) * 1.2
            pose.antennaAngle = .degrees(sin(t * 1.6) * 8)

        case .reading:
            // Eyes sweep along a line, head following a little.
            pose.expression = .reading
            pose.gaze = CGVector(dx: sin(t * 2.2) * 0.75, dy: 0.45)
            pose.headTilt = .degrees(sin(t * 2.2) * 3)

        case .puzzled:
            pose.expression = .puzzled
            pose.blink = 0
            pose.gaze = CGVector(dx: 0.35, dy: -0.35)
            pose.headTilt = .degrees(12 + sin(t * 1.4) * 2)
            pose.antennaAngle = .degrees(-14 + sin(t * 1.4) * 4)

        case .wiring:
            // Leans back to pull the cables, the effort showing on its face, then looks the plug over.
            let tug = CompanionCables.tug(at: t)
            pose.expression = tug > 0.35 ? .hot : .neutral
            pose.gaze = CGVector(dx: sin(t * 0.9) * 0.25, dy: 0.4)
            pose.headTilt = .degrees(-2 + 9 * tug)
            pose.bob = -2 * tug

        case .terminal:
            pose.expression = .terminal
            pose.visorTick = Int(t / 0.55)
            pose.headTilt = .degrees(sin(t * 0.8) * 2)

        case .thinking:
            pose.expression = .thinking
            pose.visorTick = Int(t / ClaudeCodeSpinner.frameDuration)
            pose.headTilt = .degrees(-4 + sin(t * 0.7) * 2)

        case .focusing:
            // Still and steady, eyes on the work.
            pose.expression = .reading
            pose.gaze = CGVector(dx: sin(t * 0.6) * 0.15, dy: 0.35)
            pose.headTilt = .degrees(sin(t * 0.5) * 1.5)
            pose.bob = sin(t * 1.2) * 1
            pose.antennaAngle = .degrees(sin(t * 0.5) * 2)

        case .resting:
            pose.expression = .happy
            pose.blink = 0
            pose.sway = sin(t * 1.1) * 1.5
            pose.headTilt = .degrees(sin(t * 1.1) * 4)
            pose.glow = 0.9

        case .alert:
            // Startled every second and a half: a quick shake, then still.
            pose.expression = .excited
            pose.blink = 0
            let phase = t.truncatingRemainder(dividingBy: 1.5)
            let shake = phase < 0.3 ? sin(phase * 60) : 0
            pose.sway = shake * 1.6
            pose.antennaAngle = .degrees(shake * 12)
        }
    }

    /// A blink every few seconds, at a slightly irregular rhythm so it doesn't feel mechanical.
    static func blink(at t: TimeInterval) -> CGFloat {
        let period = 3.6
        let duration = 0.16
        let cycle = (t / period).rounded(.down)
        let start = pseudoRandom(cycle) * 1.4
        let local = t - cycle * period - start
        guard local >= 0, local < duration else { return 0 }
        return 1 - abs(local / (duration / 2) - 1)
    }

    /// Hop, then squash on landing and spring back.
    private static func applyJump(to pose: inout RobotPose, since elapsed: TimeInterval, height: CGFloat) {
        let airTime = 0.45
        if elapsed < airTime {
            pose.bob = -height * sin(elapsed / airTime * .pi)
            pose.squash = 1.06
        } else if elapsed < airTime + 0.3 {
            let landing = (elapsed - airTime) / 0.3
            pose.squash = 1 - 0.1 * sin(landing * .pi)
        }
    }

    /// Deterministic value in 0..<1 for a given number.
    private static func pseudoRandom(_ seed: Double) -> Double {
        let value = sin(seed * 12.9898) * 43758.5453
        return value - value.rounded(.down)
    }
}
