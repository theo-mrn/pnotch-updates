//
//  RobotRenderer.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// Draws the robot for one frame in a `Canvas`.
///
/// The depth comes from shading rather than 3D: a metallic gradient, a specular highlight that follows
/// a light source (the user's pointer), rim light, a glass visor and glowing eyes.
/// Coordinates are in a 120 × 140 design space, scaled to fit.
enum RobotRenderer {
    static let designSize = CGSize(width: 120, height: 140)

    /// Room around the design box that jumps, dance moves, headphones and particles reach.
    /// A full robot's canvas covers it, so they aren't cut off at the edge of the robot's slot.
    static let overscan = EdgeInsets(top: 22, leading: 14, bottom: 4, trailing: 14)

    /// Canvas padding (negative) that adds the overscan around a full robot laid out in `size`.
    static func overscanPadding(fitting size: CGSize) -> EdgeInsets {
        let scale = min(size.width / designSize.width, size.height / designSize.height)
        return EdgeInsets(
            top: -overscan.top * scale,
            leading: -overscan.leading * scale,
            bottom: -overscan.bottom * scale,
            trailing: -overscan.trailing * scale
        )
    }

    enum Framing {
        /// Head, body, floor shadow and particles.
        case full
        /// Head, antenna, accessories and particles: the robot in the header of every page.
        case bust
        /// Only the visor and eyes, for tiny places like the closed notch.
        case face
    }

    /// What the bust shows in design space: from the antenna's tip to the chin, with room on the sides
    /// for headphones swinging to the music and a chin tilting with it.
    static let bustBounds = CGRect(x: -8, y: -8, width: 136, height: 108)

    struct Scene {
        var appearance: RobotAppearance
        var pose: RobotPose
        var mood: CompanionMood
        var time: TimeInterval
        var sinceReaction: TimeInterval?
        /// Light position on the head, 0...1 on each axis.
        var light: UnitPoint
        /// What the page it's on gives it to do: its own particles replace the mood's.
        var activity: CompanionActivity?
        /// Music notes take the cover's color.
        var noteColor: Color?
        /// The antenna bulb shows something: the processor's load, Claude at work…
        var bulbColor: Color?
        /// The metrics it's wired to on the System page.
        var cables: [RobotCable] = []
    }

    static func draw(_ scene: Scene, framing: Framing, in context: GraphicsContext, size: CGSize) {
        var context = context
        switch framing {
        case .full:
            // The canvas spans the design box plus the overscan around it.
            let bounds = CGSize(
                width: overscan.leading + designSize.width + overscan.trailing,
                height: overscan.top + designSize.height + overscan.bottom
            )
            let scale = min(size.width / bounds.width, size.height / bounds.height)
            context.translateBy(x: (size.width - bounds.width * scale) / 2, y: (size.height - bounds.height * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: overscan.leading, y: overscan.top)
            drawFull(scene, in: context)
        case .bust:
            let scale = min(size.width / bustBounds.width, size.height / bustBounds.height)
            context.translateBy(x: (size.width - bustBounds.width * scale) / 2, y: (size.height - bustBounds.height * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -bustBounds.minX, y: -bustBounds.minY)
            drawBust(scene, in: context)
        case .face:
            // Frames the visor (x 20...100, y 33...83 in design space).
            let scale = min(size.width / 84, size.height / 54)
            context.translateBy(x: size.width / 2 - 60 * scale, y: size.height / 2 - 58 * scale)
            context.scaleBy(x: scale, y: scale)
            drawVisor(scene, in: context)
        }
    }

    // MARK: Body

    /// The head alone, moving half as much as the full robot so it stays in its slot.
    private static func drawBust(_ scene: Scene, in context: GraphicsContext) {
        let pose = scene.pose
        var head = context
        head.translateBy(x: pose.sway / 2, y: pose.bob / 2)
        head.translateBy(x: 60, y: 93)
        head.rotate(by: pose.headTilt)
        head.translateBy(x: -60, y: -93)
        drawHead(scene, palette: scene.palette, in: head)

        // What it holds moves with its body, not with its head.
        var hands = context
        hands.translateBy(x: pose.sway / 2, y: pose.bob / 2)
        if !scene.mood.isReaction, scene.activity == .reading || scene.activity == .puzzled {
            drawClipboard(in: hands)
        }
        if !scene.mood.isReaction, scene.activity == .wiring {
            drawCables(scene.cables, time: scene.time, in: hands)
        }
        drawParticles(scene, palette: scene.palette, in: context)
    }

    private static func drawFull(_ scene: Scene, in context: GraphicsContext) {
        let pose = scene.pose
        let palette = scene.palette

        drawFloorShadow(pose: pose, in: context)

        var robot = context
        robot.translateBy(x: pose.sway, y: pose.bob)
        // Squash and stretch around the floor contact point.
        robot.translateBy(x: 60, y: 128)
        robot.scaleBy(x: 1 / max(pose.squash, 0.5), y: pose.squash)
        robot.translateBy(x: -60, y: -128)

        drawThruster(palette: palette, pose: pose, in: robot)
        drawArm(shoulder: CGPoint(x: 37, y: 101), angle: -pose.leftArm, palette: palette, in: robot)
        drawArm(shoulder: CGPoint(x: 83, y: 101), angle: pose.rightArm, palette: palette, in: robot)
        drawTorso(palette: palette, pose: pose, accessory: scene.appearance.accessory, in: robot)

        var head = robot
        head.translateBy(x: 60, y: 93)
        head.rotate(by: pose.headTilt)
        head.translateBy(x: -60, y: -93)
        drawHead(scene, palette: palette, in: head)

        drawParticles(scene, palette: palette, in: context)
    }

    private static func drawFloorShadow(pose: RobotPose, in context: GraphicsContext) {
        // Smaller and lighter while the robot is up in the air.
        let lift = max(-pose.bob, 0)
        let width = 56 - lift * 1.6
        var layer = context
        layer.addFilter(.blur(radius: 4))
        layer.opacity = 0.45 - Double(lift) * 0.015
        layer.fill(
            Path(ellipseIn: CGRect(x: 60 + pose.sway - width / 2, y: 131, width: width, height: 7)),
            with: .color(.black)
        )
    }

    private static func drawThruster(palette: RobotPalette, pose: RobotPose, in context: GraphicsContext) {
        var layer = context
        layer.addFilter(.blur(radius: 3))
        layer.opacity = 0.55 * Double(pose.glow)
        layer.fill(Path(ellipseIn: CGRect(x: 51, y: 124, width: 18, height: 7)), with: .color(palette.eye))
    }

    private static func drawArm(shoulder: CGPoint, angle: Angle, palette: RobotPalette, in context: GraphicsContext) {
        var arm = context
        arm.translateBy(x: shoulder.x, y: shoulder.y)
        arm.rotate(by: angle)
        let rect = CGRect(x: -4.5, y: -2, width: 9, height: 22)
        arm.fill(Path(roundedRect: rect, cornerRadius: 4.5), with: .linearGradient(
            Gradient(colors: [palette.light, palette.dark]), startPoint: CGPoint(x: -4.5, y: 0), endPoint: CGPoint(x: 4.5, y: 0)
        ))
    }

    private static func drawTorso(palette: RobotPalette, pose: RobotPose, accessory: RobotAccessory, in context: GraphicsContext) {
        let rect = CGRect(x: 36, y: 96, width: 48, height: 29)
        let torso = Path(roundedRect: rect, cornerRadius: 13)
        context.fill(torso, with: .linearGradient(
            Gradient(colors: [palette.light, palette.dark]), startPoint: CGPoint(x: 60, y: 96), endPoint: CGPoint(x: 60, y: 125)
        ))
        context.stroke(torso, with: .color(.white.opacity(0.25)), lineWidth: 1)

        // Chest light, breathing with the eyes.
        var light = context
        light.addFilter(.shadow(color: palette.eye.opacity(0.9), radius: 4))
        light.opacity = Double(0.6 + 0.4 * pose.glow)
        light.fill(Path(ellipseIn: CGRect(x: 55.5, y: 106, width: 9, height: 9)), with: .color(palette.eye))
    }

    // MARK: Head

    private static func headPath() -> Path {
        Path(roundedRect: CGRect(x: 10, y: 23, width: 100, height: 70), cornerRadius: 28, style: .continuous)
    }

    private static func drawHead(_ scene: Scene, palette: RobotPalette, in context: GraphicsContext) {
        let pose = scene.pose
        let accessory = scene.appearance.accessory

        drawAntenna(scene, palette: palette, in: context)

        // Ears, or headphone cups.
        if accessory == .headphones {
            for x in [0.0, 106.0] {
                context.fill(Path(roundedRect: CGRect(x: x, y: 40, width: 14, height: 34), cornerRadius: 7), with: .color(Color(hex: 0x2B2F36)))
            }
        } else {
            for x in [4.0, 108.0] {
                context.fill(Path(roundedRect: CGRect(x: x, y: 47, width: 8, height: 22), cornerRadius: 4), with: .color(palette.dark))
            }
        }

        let head = headPath()
        context.fill(head, with: .linearGradient(
            Gradient(colors: [palette.light, palette.mid, palette.dark]),
            startPoint: CGPoint(x: 60, y: 23), endPoint: CGPoint(x: 60, y: 93)
        ))

        // Specular highlight from the light source, added on top of the metal.
        var shine = context
        shine.clip(to: head)
        shine.blendMode = .plusLighter
        let center = CGPoint(x: 10 + 100 * scene.light.x, y: 23 + 70 * scene.light.y)
        shine.fill(head, with: .radialGradient(
            Gradient(colors: [.white.opacity(0.55), .white.opacity(0)]), center: center, startRadius: 0, endRadius: 52
        ))

        // Rim light along the top edge.
        context.stroke(head, with: .linearGradient(
            Gradient(colors: [.white.opacity(0.6), .white.opacity(0)]), startPoint: CGPoint(x: 60, y: 23), endPoint: CGPoint(x: 60, y: 60)
        ), lineWidth: 1.5)

        if scene.activity == .focusing, !scene.mood.isReaction {
            drawHeadband(time: scene.time, clippedTo: head, in: context)
        }

        drawVisor(scene, in: context)

        switch accessory {
        case .headphones:
            context.stroke(
                Path { $0.move(to: CGPoint(x: 7, y: 42)); $0.addQuadCurve(to: CGPoint(x: 113, y: 42), control: CGPoint(x: 60, y: -14)) },
                with: .color(Color(hex: 0x2B2F36)), style: StrokeStyle(lineWidth: 6, lineCap: .round)
            )
        case .crown:
            drawCrown(in: context)
        case .glasses:
            drawGlasses(gaze: pose.gaze, in: context)
        case .none, .flower:
            break
        }
    }

    private static func drawAntenna(_ scene: Scene, palette: RobotPalette, in context: GraphicsContext) {
        var antenna = context
        antenna.translateBy(x: 60, y: 24)
        antenna.rotate(by: scene.pose.antennaAngle)
        antenna.stroke(Path { $0.move(to: .zero); $0.addLine(to: CGPoint(x: 0, y: -15)) }, with: .color(palette.dark), lineWidth: 3)

        if scene.appearance.accessory == .flower {
            for index in 0 ..< 5 {
                var petal = antenna
                petal.translateBy(x: 0, y: -19)
                petal.rotate(by: .degrees(Double(index) * 72))
                petal.fill(Path(ellipseIn: CGRect(x: -3, y: -9, width: 6, height: 8)), with: .color(Color(hex: 0xFF8CC6)))
            }
            antenna.fill(Path(ellipseIn: CGRect(x: -3, y: -22, width: 6, height: 6)), with: .color(Color(hex: 0xFFD54A)))
            return
        }

        let bulbColor = scene.bulbColor ?? palette.bulb
        var bulb = antenna
        bulb.addFilter(.shadow(color: bulbColor.opacity(0.9), radius: 5))
        bulb.opacity = Double(min(scene.pose.glow, 1))
        bulb.fill(Path(ellipseIn: CGRect(x: -5.5, y: -24, width: 11, height: 11)), with: .color(bulbColor))
    }

    private static func drawVisor(_ scene: Scene, in context: GraphicsContext) {
        let palette = scene.palette
        let pose = scene.pose
        let visor = Path(roundedRect: CGRect(x: 20, y: 33, width: 80, height: 50), cornerRadius: 18, style: .continuous)
        context.fill(visor, with: .linearGradient(
            Gradient(colors: [Color(hex: 0x1C2230), Color(hex: 0x0A0D13)]), startPoint: CGPoint(x: 60, y: 33), endPoint: CGPoint(x: 60, y: 83)
        ))
        // Glass reflection.
        var glass = context
        glass.clip(to: visor)
        glass.fill(Path { path in
            path.move(to: CGPoint(x: 20, y: 33))
            path.addLine(to: CGPoint(x: 58, y: 33))
            path.addLine(to: CGPoint(x: 34, y: 83))
            path.addLine(to: CGPoint(x: 20, y: 83))
            path.closeSubpath()
        }, with: .color(.white.opacity(0.06)))

        if pose.blush > 0 {
            var blush = context
            blush.addFilter(.blur(radius: 2))
            blush.opacity = Double(pose.blush) * 0.7
            for x in [27.0, 83.0] {
                blush.fill(Path(ellipseIn: CGRect(x: x, y: 68, width: 10, height: 5)), with: .color(Color(hex: 0xFF6FAE)))
            }
        }

        var face = context
        face.addFilter(.shadow(color: palette.eye.opacity(0.85), radius: 4))
        face.opacity = Double(min(max(pose.glow, 0.3), 1))
        if pose.expression == .terminal {
            drawPrompt(cursorVisible: pose.visorTick.isMultiple(of: 2), color: palette.eye, in: face)
            return
        }

        let offset = CGVector(dx: pose.gaze.dx * 5, dy: pose.gaze.dy * 4)
        for (index, x) in [44.0, 76.0].enumerated() {
            drawEye(at: CGPoint(x: x + offset.dx, y: 56 + offset.dy), isLeft: index == 0, pose: pose, color: palette.eye, in: face)
        }
        drawMouth(at: CGPoint(x: 60 + offset.dx * 0.6, y: 72 + offset.dy * 0.5), expression: pose.expression, color: palette.eye, in: face)
    }

    /// `>_` with a blinking cursor, waiting for a command.
    private static func drawPrompt(cursorVisible: Bool, color: Color, in context: GraphicsContext) {
        context.stroke(Path { path in
            path.move(to: CGPoint(x: 36, y: 49))
            path.addLine(to: CGPoint(x: 45, y: 57))
            path.addLine(to: CGPoint(x: 36, y: 65))
        }, with: .color(color), style: StrokeStyle(lineWidth: 3.6, lineCap: .round, lineJoin: .round))
        if cursorVisible {
            context.fill(Path(roundedRect: CGRect(x: 51, y: 62, width: 15, height: 4), cornerRadius: 1.5), with: .color(color))
        }
    }

    private static func drawEye(at center: CGPoint, isLeft: Bool, pose: RobotPose, color: Color, in context: GraphicsContext) {
        let line = StrokeStyle(lineWidth: 3.4, lineCap: .round, lineJoin: .round)
        switch pose.expression {
        case .thinking:
            let frame = ClaudeCodeSpinner.frames[pose.visorTick % ClaudeCodeSpinner.frames.count]
            context.draw(Text(verbatim: frame).font(.system(size: 19, weight: .bold)).foregroundStyle(ClaudeCodeSpinner.tint), at: center)
        case .terminal:
            break
        case .neutral:
            let height = max(15 * (1 - pose.blink), 2.5)
            context.fill(Path(roundedRect: CGRect(x: center.x - 5.5, y: center.y - height / 2, width: 11, height: height), cornerRadius: 5.5), with: .color(color))
        case .reading:
            let height = max(7 * (1 - pose.blink), 2.5)
            context.fill(Path(roundedRect: CGRect(x: center.x - 6, y: center.y - height / 2, width: 12, height: height), cornerRadius: 3.5), with: .color(color))
        case .puzzled:
            if isLeft {
                context.fill(Path(ellipseIn: CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14)), with: .color(color))
            } else {
                context.fill(Path(roundedRect: CGRect(x: center.x - 6, y: center.y - 1.5, width: 12, height: 4), cornerRadius: 2), with: .color(color))
            }
        case .happy:
            context.stroke(Path { path in
                path.move(to: CGPoint(x: center.x - 6.5, y: center.y + 3))
                path.addQuadCurve(to: CGPoint(x: center.x + 6.5, y: center.y + 3), control: CGPoint(x: center.x, y: center.y - 8))
            }, with: .color(color), style: line)
        case .sleepy:
            context.stroke(Path { path in
                path.move(to: CGPoint(x: center.x - 6, y: center.y + 3))
                path.addQuadCurve(to: CGPoint(x: center.x + 6, y: center.y + 3), control: CGPoint(x: center.x, y: center.y + 7))
            }, with: .color(color), style: line)
        case .hot:
            let direction: CGFloat = isLeft ? 1 : -1
            context.stroke(Path { path in
                path.move(to: CGPoint(x: center.x - 4 * direction, y: center.y - 6))
                path.addLine(to: CGPoint(x: center.x + 4 * direction, y: center.y))
                path.addLine(to: CGPoint(x: center.x - 4 * direction, y: center.y + 6))
            }, with: .color(color), style: line)
        case .excited:
            context.fill(Path(ellipseIn: CGRect(x: center.x - 7.5, y: center.y - 7.5, width: 15, height: 15)), with: .color(color))
            context.fill(Path(ellipseIn: CGRect(x: center.x + 1, y: center.y - 5, width: 4, height: 4)), with: .color(.white))
        case .love:
            context.fill(heartPath(center: center, size: 15), with: .color(Color(hex: 0xFF6FAE)))
        }
    }

    private static func drawMouth(at center: CGPoint, expression: RobotExpression, color: Color, in context: GraphicsContext) {
        switch expression {
        case .neutral:
            context.stroke(Path { path in
                path.move(to: CGPoint(x: center.x - 5, y: center.y))
                path.addQuadCurve(to: CGPoint(x: center.x + 5, y: center.y), control: CGPoint(x: center.x, y: center.y + 4))
            }, with: .color(color.opacity(0.9)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        case .happy, .love:
            context.fill(Path { path in
                path.move(to: CGPoint(x: center.x - 6, y: center.y - 1))
                path.addQuadCurve(to: CGPoint(x: center.x + 6, y: center.y - 1), control: CGPoint(x: center.x, y: center.y + 9))
                path.closeSubpath()
            }, with: .color(color))
        case .excited:
            context.fill(Path(ellipseIn: CGRect(x: center.x - 3.5, y: center.y - 2.5, width: 7, height: 7)), with: .color(color))
        case .sleepy:
            context.stroke(Path(ellipseIn: CGRect(x: center.x - 2, y: center.y - 1, width: 4, height: 4)), with: .color(color.opacity(0.8)), lineWidth: 1.6)
        case .reading:
            context.stroke(Path { path in
                path.move(to: CGPoint(x: center.x - 4, y: center.y + 1))
                path.addLine(to: CGPoint(x: center.x + 4, y: center.y + 1))
            }, with: .color(color.opacity(0.9)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        case .puzzled:
            context.stroke(Path { path in
                path.move(to: CGPoint(x: center.x - 5, y: center.y + 2))
                path.addQuadCurve(to: CGPoint(x: center.x + 5, y: center.y - 1), control: CGPoint(x: center.x, y: center.y - 2))
            }, with: .color(color.opacity(0.9)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        case .terminal:
            break
        case .thinking:
            // Pursed to the side.
            context.stroke(Path { path in
                path.move(to: CGPoint(x: center.x, y: center.y + 1))
                path.addLine(to: CGPoint(x: center.x + 6, y: center.y))
            }, with: .color(color.opacity(0.9)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        case .hot:
            context.stroke(Path { path in
                path.move(to: CGPoint(x: center.x - 7, y: center.y))
                for step in 1 ... 4 {
                    path.addQuadCurve(
                        to: CGPoint(x: center.x - 7 + CGFloat(step) * 3.5, y: center.y),
                        control: CGPoint(x: center.x - 7 + CGFloat(step) * 3.5 - 1.75, y: center.y + (step.isMultiple(of: 2) ? 2.5 : -2.5))
                    )
                }
            }, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    // MARK: Accessories

    /// A red headband for concentrating, its knot's tails fluttering on the side.
    private static func drawHeadband(time t: TimeInterval, clippedTo head: Path, in context: GraphicsContext) {
        let red = Color(hex: 0xE5484D)
        var band = context
        band.clip(to: head)
        band.fill(Path(CGRect(x: 0, y: 24, width: 120, height: 8)), with: .linearGradient(
            Gradient(colors: [Color(hex: 0xFF6B6F), red]), startPoint: CGPoint(x: 60, y: 24), endPoint: CGPoint(x: 60, y: 32)
        ))
        let flutter = sin(t * 3) * 2
        for (index, length) in [14.0, 11.0].enumerated() {
            context.stroke(Path { path in
                path.move(to: CGPoint(x: 107, y: 29))
                path.addQuadCurve(
                    to: CGPoint(x: 107 + length, y: 34 + Double(index) * 6 + flutter),
                    control: CGPoint(x: 112 + length / 3, y: 26 + Double(index) * 4 - flutter)
                )
            }, with: .color(red), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
        }
        context.fill(Path(ellipseIn: CGRect(x: 104, y: 26, width: 7, height: 7)), with: .color(red))
    }

    /// The plug it holds, one cable per metric coming up to it from below the frame, data climbing to the robot.
    private static func drawCables(_ cables: [RobotCable], time t: TimeInterval, in context: GraphicsContext) {
        let tug = CompanionCables.tug(at: t)
        for (index, cable) in cables.enumerated() {
            let curve = CompanionCables.cable(index, of: cables.count, tug: tug)
            let path = Path { path in
                path.move(to: curve.start)
                path.addCurve(to: curve.end, control1: curve.control1, control2: curve.control2)
            }
            // Fades out where it leaves the frame.
            context.stroke(path, with: .linearGradient(
                Gradient(colors: [cable.tint, cable.tint.opacity(0)]), startPoint: curve.start, endPoint: CGPoint(x: curve.end.x, y: 100)
            ), style: StrokeStyle(lineWidth: 4.6, lineCap: .round))

            var packet = context
            packet.addFilter(.shadow(color: cable.tint, radius: 3))
            let lap = (t * CompanionCables.packetSpeed(flow: cable.flow) + Double(index) * 0.23).truncatingRemainder(dividingBy: 1)
            let point = curve.point(at: 1 - lap)
            packet.opacity = min(lap * 3, 1)
            packet.fill(Path(ellipseIn: CGRect(x: point.x - 2.8, y: point.y - 2.8, width: 5.6, height: 5.6)), with: .color(.white))
        }

        let plug = CompanionCables.plug(tug: tug)
        context.fill(Path(roundedRect: plug, cornerRadius: 4), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x4A505B), Color(hex: 0x23272E)]),
            startPoint: CGPoint(x: plug.midX, y: plug.minY), endPoint: CGPoint(x: plug.midX, y: plug.maxY)
        ))
        // One light per cable, brighter as its metric gets busy.
        for (index, cable) in cables.enumerated() {
            let spread = cables.count > 1 ? CGFloat(index) / CGFloat(cables.count - 1) - 0.5 : 0
            var light = context
            light.addFilter(.shadow(color: cable.tint, radius: 2))
            light.opacity = 0.45 + 0.55 * min(max(cable.flow, 0), 1)
            light.fill(Path(ellipseIn: CGRect(x: plug.midX + spread * (plug.width - 12) - 2.8, y: plug.midY - 2.8, width: 5.6, height: 5.6)), with: .color(cable.tint))
        }
    }

    /// A clipboard held up to read, its sheet lined with text.
    private static func drawClipboard(in context: GraphicsContext) {
        var board = context
        board.translateBy(x: 62, y: 82)
        board.rotate(by: .degrees(-7))
        board.fill(Path(roundedRect: CGRect(x: -26, y: -16, width: 52, height: 34), cornerRadius: 4), with: .linearGradient(
            Gradient(colors: [Color(hex: 0xC99A6B), Color(hex: 0x9C6B42)]), startPoint: CGPoint(x: 0, y: -16), endPoint: CGPoint(x: 0, y: 18)
        ))
        board.fill(Path(roundedRect: CGRect(x: -22, y: -12, width: 44, height: 27), cornerRadius: 2), with: .color(Color(hex: 0xF6F3EC)))
        for (index, width) in [30.0, 36, 22, 32].enumerated() {
            board.fill(
                Path(roundedRect: CGRect(x: -17, y: -6 + Double(index) * 5.5, width: width, height: 2.2), cornerRadius: 1.1),
                with: .color(Color(hex: 0x9AA3AF))
            )
        }
        board.fill(Path(roundedRect: CGRect(x: -9, y: -20, width: 18, height: 8), cornerRadius: 2.5), with: .linearGradient(
            Gradient(colors: [Color(hex: 0xE3E7ED), Color(hex: 0x8E97A6)]), startPoint: CGPoint(x: 0, y: -20), endPoint: CGPoint(x: 0, y: -12)
        ))
    }

    private static func drawCrown(in context: GraphicsContext) {
        var crown = context
        crown.translateBy(x: 84, y: 24)
        crown.rotate(by: .degrees(12))
        let shape = Path { path in
            path.move(to: CGPoint(x: -14, y: 0))
            path.addLine(to: CGPoint(x: -14, y: -12))
            path.addLine(to: CGPoint(x: -7, y: -5))
            path.addLine(to: CGPoint(x: 0, y: -15))
            path.addLine(to: CGPoint(x: 7, y: -5))
            path.addLine(to: CGPoint(x: 14, y: -12))
            path.addLine(to: CGPoint(x: 14, y: 0))
            path.closeSubpath()
        }
        crown.fill(shape, with: .linearGradient(
            Gradient(colors: [Color(hex: 0xFFE27A), Color(hex: 0xE0A21B)]), startPoint: CGPoint(x: 0, y: -15), endPoint: CGPoint(x: 0, y: 0)
        ))
        crown.fill(Path(ellipseIn: CGRect(x: -2.5, y: -6, width: 5, height: 5)), with: .color(Color(hex: 0xFF5F57)))
    }

    private static func drawGlasses(gaze: CGVector, in context: GraphicsContext) {
        let style = StrokeStyle(lineWidth: 2.4)
        let frame = Color.white.opacity(0.9)
        let dx = gaze.dx * 2
        for x in [44.0, 76.0] {
            context.stroke(Path(ellipseIn: CGRect(x: x - 12 + dx, y: 44, width: 24, height: 24)), with: .color(frame), style: style)
        }
        context.stroke(Path { $0.move(to: CGPoint(x: 56 + dx, y: 55)); $0.addLine(to: CGPoint(x: 64 + dx, y: 55)) }, with: .color(frame), style: style)
    }

    // MARK: Particles

    private static func drawParticles(_ scene: Scene, palette: RobotPalette, in context: GraphicsContext) {
        let t = scene.time
        if let activity = scene.activity, !scene.mood.isReaction {
            drawParticles(for: activity, scene: scene, palette: palette, in: context)
            return
        }
        switch scene.mood {
        case .dancing:
            drawNotes(time: t, color: palette.eye, in: context)
        case .hot:
            for (index, start) in [CGPoint(x: 16, y: 34), CGPoint(x: 104, y: 38)].enumerated() {
                let progress = ((t + Double(index) * 0.7).truncatingRemainder(dividingBy: 1.4)) / 1.4
                var drop = context
                drop.opacity = 1 - progress
                drop.fill(dropPath(at: CGPoint(x: start.x, y: start.y + progress * 18)), with: .color(Color(hex: 0x8FD3FF)))
            }
        case .sleepy:
            for index in 0 ..< 3 {
                let progress = ((t * 0.5 + Double(index) / 3).truncatingRemainder(dividingBy: 1))
                var letter = context
                letter.opacity = sin(progress * .pi) * 0.8
                let point = CGPoint(x: 96 + progress * 14, y: 30 - progress * 26)
                letter.draw(Text(verbatim: "z").font(.system(size: 8 + progress * 6, weight: .bold, design: .rounded)).foregroundStyle(.white), at: point)
            }
        case .loved:
            let elapsed = scene.sinceReaction ?? 0
            for index in 0 ..< 3 {
                let progress = (elapsed - Double(index) * 0.25) / 1.6
                guard progress > 0, progress < 1 else { continue }
                var heart = context
                heart.opacity = sin(progress * .pi)
                let center = CGPoint(x: 60 + Double(index - 1) * 24 + sin(progress * 6) * 4, y: 16 - progress * 22)
                heart.fill(heartPath(center: center, size: 12), with: .color(Color(hex: 0xFF6FAE)))
            }
        case .excited:
            let elapsed = scene.sinceReaction ?? 0
            for (index, point) in [CGPoint(x: 12, y: 26), CGPoint(x: 108, y: 22), CGPoint(x: 100, y: 92)].enumerated() {
                let progress = (elapsed - Double(index) * 0.15) / 0.9
                guard progress > 0, progress < 1 else { continue }
                var sparkle = context
                sparkle.opacity = sin(progress * .pi)
                sparkle.draw(Text(verbatim: "✦").font(.system(size: 10 + progress * 4)).foregroundStyle(palette.eye), at: point)
            }
        case .content:
            break
        }
    }

    private static func drawNotes(time t: TimeInterval, color: Color, in context: GraphicsContext) {
        for index in 0 ..< 3 {
            let progress = ((t + Double(index) * 0.8).truncatingRemainder(dividingBy: 2.4)) / 2.4
            var note = context
            note.opacity = sin(progress * .pi)
            let point = CGPoint(x: 100 + sin(progress * .pi * 2 + Double(index)) * 6, y: 34 - progress * 30)
            note.draw(Text(verbatim: index.isMultiple(of: 2) ? "♪" : "♫").font(.system(size: 13, weight: .bold)).foregroundStyle(color), at: point)
        }
    }

    private static func drawParticles(for activity: CompanionActivity, scene: Scene, palette: RobotPalette, in context: GraphicsContext) {
        let t = scene.time
        switch activity {
        case .listening:
            drawNotes(time: t, color: scene.noteColor ?? palette.eye, in: context)

        case .waitingForMusic:
            // A single faded note drifting up: the music is on hold.
            let progress = t.truncatingRemainder(dividingBy: 3) / 3
            var note = context
            note.opacity = sin(progress * .pi) * 0.5
            note.draw(
                Text(verbatim: "♪").font(.system(size: 15, weight: .bold)).foregroundStyle(scene.noteColor ?? palette.eye),
                at: CGPoint(x: 104 + sin(progress * .pi * 2) * 3, y: 30 - progress * 22)
            )

        case .reading, .wiring, .terminal, .thinking, .focusing:
            break

        case .resting:
            // A warm drink, steaming.
            context.draw(Text(verbatim: "☕").font(.system(size: 16)), at: CGPoint(x: 107, y: 24))
            for index in 0 ..< 2 {
                let progress = ((t * 0.6 + Double(index) * 0.5).truncatingRemainder(dividingBy: 1))
                var steam = context
                steam.opacity = sin(progress * .pi) * 0.6
                let x = 104 + Double(index) * 6
                let y = 14 - progress * 10
                steam.stroke(Path { path in
                    path.move(to: CGPoint(x: x, y: y + 5))
                    path.addQuadCurve(to: CGPoint(x: x, y: y - 3), control: CGPoint(x: x + 3, y: y + 1))
                }, with: .color(.white), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }

        case .puzzled:
            // Big enough to read on the small robot of the header.
            let point = CGPoint(x: 109, y: 16 + sin(t * 2) * 2)
            context.draw(Text(verbatim: "?").font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(.white.opacity(0.9)), at: point)

        case .alert:
            let bounce = abs(sin(t * 5)) * 3
            context.draw(
                Text(verbatim: "!").font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(ClaudeCodeSpinner.tint),
                at: CGPoint(x: 112, y: 17 - bounce)
            )
        }
    }

    // MARK: Shapes

    private static func heartPath(center: CGPoint, size: CGFloat) -> Path {
        let half = size / 2
        return Path { path in
            path.move(to: CGPoint(x: center.x, y: center.y + half * 0.85))
            path.addCurve(
                to: CGPoint(x: center.x - half, y: center.y - half * 0.25),
                control1: CGPoint(x: center.x - half * 0.55, y: center.y + half * 0.45),
                control2: CGPoint(x: center.x - half, y: center.y + half * 0.15)
            )
            path.addArc(center: CGPoint(x: center.x - half / 2, y: center.y - half * 0.25), radius: half / 2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            path.addArc(center: CGPoint(x: center.x + half / 2, y: center.y - half * 0.25), radius: half / 2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            path.addCurve(
                to: CGPoint(x: center.x, y: center.y + half * 0.85),
                control1: CGPoint(x: center.x + half, y: center.y + half * 0.15),
                control2: CGPoint(x: center.x + half * 0.55, y: center.y + half * 0.45)
            )
        }
    }

    private static func dropPath(at point: CGPoint) -> Path {
        Path { path in
            path.move(to: CGPoint(x: point.x, y: point.y - 5))
            path.addQuadCurve(to: CGPoint(x: point.x, y: point.y + 3), control: CGPoint(x: point.x + 5, y: point.y + 2))
            path.addQuadCurve(to: CGPoint(x: point.x, y: point.y - 5), control: CGPoint(x: point.x - 5, y: point.y + 2))
        }
    }
}

// MARK: - RobotPalette

/// Colors derived from the chosen appearance.
/// A metric the robot is wired to.
struct RobotCable: Equatable {
    let tint: Color
    /// How busy the metric is, 0...1: the data climbs faster.
    let flow: Double
}

struct RobotPalette {
    let light: Color
    let mid: Color
    let dark: Color
    let eye: Color
    let bulb: Color

    init(_ appearance: RobotAppearance, mood: CompanionMood = .content) {
        let (light, dark) = appearance.bodyColor.shades
        self.light = Color(hex: light)
        self.dark = Color(hex: dark)
        mid = Color(hex: Self.blend(light, dark, by: 0.45))
        eye = Color(hex: appearance.eyeColor.hex)
        bulb = mood == .hot ? Color(hex: 0xFF5F57) : Color(hex: appearance.eyeColor.hex)
    }

    /// Linear mix of two `0xRRGGBB` colors (`Color.mix` needs macOS 15).
    private static func blend(_ first: UInt32, _ second: UInt32, by fraction: Double) -> UInt32 {
        [16, 8, 0].reduce(0) { result, shift in
            let a = Double((first >> UInt32(shift)) & 0xFF)
            let b = Double((second >> UInt32(shift)) & 0xFF)
            return result | (UInt32((a + (b - a) * fraction).rounded()) << UInt32(shift))
        }
    }
}

extension RobotRenderer.Scene {
    var palette: RobotPalette {
        RobotPalette(appearance, mood: mood)
    }
}

extension RobotBodyColor {
    /// Light and dark ends of the metal gradient.
    var shades: (UInt32, UInt32) {
        switch self {
        case .silver: (0xEEF1F5, 0x8E97A6)
        case .mint: (0xC4F5E4, 0x3FAE8C)
        case .coral: (0xFFCBBE, 0xE0664C)
        case .sky: (0xC9E4FF, 0x4F8EE0)
        case .lemon: (0xFFF3B0, 0xD9AE2C)
        case .lavender: (0xE0D6FF, 0x8670DA)
        case .graphite: (0x7A818E, 0x2A2E35)
        }
    }
}

extension RobotEyeColor {
    var hex: UInt32 {
        switch self {
        case .cyan: 0x5CE1FF
        case .green: 0x6CFF9E
        case .amber: 0xFFC145
        case .pink: 0xFF7AC8
        case .white: 0xF2F5FF
        }
    }
}
