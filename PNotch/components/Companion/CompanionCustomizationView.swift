//
//  CompanionCustomizationView.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Defaults
import SwiftUI

/// The robot's wardrobe: name, body and eye colors, accessory. Changes show on the robot right away.
/// What it does lives in Settings › Companion.
struct CompanionCustomizationView: View {
    let onDone: () -> Void

    @Default(.companionName) private var name
    @Default(.companionAppearance) private var appearance

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TextField("Name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .frame(width: 160, height: 24)
                    .background(.white.opacity(0.1), in: Capsule())

                Spacer()

                Button("Done", action: onDone)
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 24)
                    .background(.white.opacity(0.16), in: Capsule())
            }

            OptionRow(title: "Body") {
                ForEach(RobotBodyColor.allCases, id: \.self) { color in
                    let (light, dark) = color.shades
                    Swatch(isSelected: appearance.bodyColor == color) {
                        LinearGradient(colors: [Color(hex: light), Color(hex: dark)], startPoint: .top, endPoint: .bottom)
                    } action: {
                        appearance.bodyColor = color
                    }
                }
            }

            OptionRow(title: "Eyes") {
                ForEach(RobotEyeColor.allCases, id: \.self) { color in
                    Swatch(isSelected: appearance.eyeColor == color) {
                        Color(hex: color.hex)
                    } action: {
                        appearance.eyeColor = color
                    }
                }
            }

            OptionRow(title: "Wear") {
                ForEach(RobotAccessory.allCases, id: \.self) { accessory in
                    AccessoryButton(accessory: accessory, isSelected: appearance.accessory == accessory) {
                        appearance.accessory = accessory
                    }
                }
            }
        }
        .padding(.vertical, 14)
    }
}

private struct OptionRow<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 46, alignment: .leading)
            content()
        }
    }
}

private struct Swatch<Fill: View>: View {
    let isSelected: Bool
    @ViewBuilder let fill: () -> Fill
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            fill()
                .frame(width: 18, height: 18)
                .clipShape(Circle())
                .padding(2)
                .overlay(Circle().strokeBorder(.white.opacity(isSelected ? 0.9 : 0), lineWidth: 1.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct AccessoryButton: View {
    let accessory: RobotAccessory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: accessory.symbolName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(isSelected ? 1 : 0.6))
                .frame(width: 24, height: 22)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.white.opacity(isSelected ? 0.2 : 0.07)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(accessory.title)
    }
}

extension RobotAccessory {
    var symbolName: String {
        switch self {
        case .none: "circle.slash"
        case .headphones: "headphones"
        case .crown: "crown.fill"
        case .glasses: "eyeglasses"
        case .flower: "camera.macro"
        }
    }

    var title: String {
        switch self {
        case .none: String(localized: "Nothing")
        case .headphones: String(localized: "Headphones")
        case .crown: String(localized: "Crown")
        case .glasses: String(localized: "Glasses")
        case .flower: String(localized: "Flower")
        }
    }
}
