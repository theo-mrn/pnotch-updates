//
//  CompanionMessengerFace.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Defaults
import SwiftUI

/// The robot's face around the closed notch: wide awake to deliver news, or busy with something
/// like a focus session. `fallback` is shown instead when its announcements are turned off in Settings.
struct CompanionMessengerFace<Fallback: View>: View {
    var mood: CompanionMood = .excited
    var activity: CompanionActivity?
    @ViewBuilder let fallback: () -> Fallback

    @Default(.companionAnnouncesCopies) private var announces

    var body: some View {
        if announces {
            RobotView(framing: .face, followsPointer: false, mood: mood, variant: RobotVariant(activity: activity))
                .frame(width: 26, height: 17)
        } else {
            fallback()
        }
    }
}
