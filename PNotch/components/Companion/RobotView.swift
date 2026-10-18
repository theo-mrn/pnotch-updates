//
//  RobotView.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Defaults
import SwiftUI

/// What a page changes in how the robot looks and moves.
struct RobotVariant: Equatable {
    var activity: CompanionActivity?
    /// Music notes take the cover's color.
    var noteColor: Color?
    /// The antenna bulb shows something: the processor's load, Claude at work…
    var bulbColor: Color?
    /// The metrics it's wired to on the System page.
    var cables: [RobotCable] = []
}

/// The robot companion, alive: animated every frame, its eyes and the light on its head following the pointer.
struct RobotView: View {
    var framing: RobotRenderer.Framing = .full
    var followsPointer = true
    /// Overrides the mood the companion is in, e.g. wide awake to deliver news.
    var mood: CompanionMood?
    var variant = RobotVariant()

    @Environment(CompanionManager.self) private var companion
    @Environment(PNotchViewModel.self) private var vm
    @Default(.companionAppearance) private var appearance

    var body: some View {
        GeometryReader { proxy in
            let frameInWindow = proxy.frame(in: .global)

            TimelineView(.animation(minimumInterval: frameInterval)) { timeline in
                let date = timeline.date
                let time = date.timeIntervalSinceReferenceDate
                let mood = self.mood ?? companion.mood(at: date)
                let reaction = companion.reactionElapsed(at: date)
                let gaze = followsPointer ? pointerGaze(from: frameInWindow) : .zero
                let pose = RobotAnimator.pose(mood: mood, activity: variant.activity, time: time, gaze: gaze, sinceReaction: reaction)
                let scene = RobotRenderer.Scene(
                    appearance: dressed(appearance),
                    pose: pose,
                    mood: mood,
                    time: time,
                    sinceReaction: reaction,
                    // The pointer is the light source: the highlight slides towards it.
                    light: UnitPoint(x: 0.32 + pose.gaze.dx * 0.28, y: 0.22 + pose.gaze.dy * 0.18),
                    activity: variant.activity,
                    noteColor: variant.noteColor,
                    bulbColor: variant.bulbColor,
                    cables: variant.cables
                )

                Canvas { context, size in
                    RobotRenderer.draw(scene, framing: framing, in: context, size: size)
                }
                .padding(framing == .full ? RobotRenderer.overscanPadding(fitting: proxy.size) : EdgeInsets())
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(Defaults[.companionName]))
    }

    /// Slips on headphones on the music page, unless it already wears something.
    private func dressed(_ appearance: RobotAppearance) -> RobotAppearance {
        let isAboutMusic = variant.activity == .listening || variant.activity == .waitingForMusic
        guard isAboutMusic, appearance.accessory == .none else { return appearance }
        var appearance = appearance
        appearance.accessory = .headphones
        return appearance
    }

    /// The small robots in the headers, the tab bar and around the closed notch don't need the display's full refresh rate.
    private var frameInterval: TimeInterval {
        switch framing {
        case .full: 1.0 / 60
        case .bust, .face: 1.0 / 30
        }
    }

    /// Direction of the pointer seen from the robot, each axis in -1...1, full strength past 150 points.
    private func pointerGaze(from frameInWindow: CGRect) -> CGVector {
        let window = vm.geometry.windowFrame
        let center = CGPoint(x: window.minX + frameInWindow.midX, y: window.maxY - frameInWindow.midY)
        let pointer = NSEvent.mouseLocation
        let dx = pointer.x - center.x
        // Screen coordinates go up, the drawing goes down.
        let dy = center.y - pointer.y
        let distance = max(hypot(dx, dy), 1)
        let strength = min(distance / 150, 1)
        return CGVector(dx: dx / distance * strength, dy: dy / distance * strength)
    }
}
