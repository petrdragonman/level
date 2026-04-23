//
//  ContentView.swift
//  mimo-level
//
//  Created by Petr Valouch on 23/4/2026.
//

import SwiftUI
import CoreMotion

import SwiftUI
import CoreMotion


// MARK: - Motion Manager

final class MotionManager: ObservableObject {
    private let motion = CMMotionManager()
    private var rawX: Double = 0
    private var rawY: Double = 0

    @Published private(set) var angleX: Double = 0
    @Published private(set) var angleY: Double = 0
    @Published private(set) var magnitude: Double = 0
    @Published private(set) var isLevel: Bool = true
    @Published private(set) var isFlat: Bool = true
    @Published var zeroX: Double = 0
    @Published var zeroY: Double = 0

    var isCalibrated: Bool { zeroX != 0 || zeroY != 0 }

    init() { start() }

    func start() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) {
            [weak self] dm, _ in
            guard let self, let dm else { return }
            let g = dm.gravity
            let rm = dm.attitude.rotationMatrix

            let newFlat: Bool = self.isFlat ? (g.z < -0.7) : (g.z < -0.85)
            if newFlat != self.isFlat {
                self.zeroX = 0; self.zeroY = 0
                self.isFlat = newFlat
            }

            if self.isFlat {
                self.rawX = atan2(g.x, -g.z) * 180 / .pi
                self.rawY = atan2(g.y, -g.z) * 180 / .pi
            } else {
                self.rawX = atan2(rm.m21, rm.m23) * 180 / .pi
                self.rawY = atan2(rm.m22, rm.m23) * 180 / .pi
            }

            self.angleX = self.rawX - self.zeroX
            self.angleY = self.rawY - self.zeroY
            self.magnitude = max(abs(self.angleX), abs(self.angleY))
            self.isLevel = self.magnitude < 0.3
        }
    }

    func stop() { motion.stopDeviceMotionUpdates() }
    func calibrate() { zeroX = rawX; zeroY = rawY }
    func resetCalibration() { zeroX = 0; zeroY = 0 }
    deinit { motion.stopDeviceMotionUpdates() }
}

// MARK: - Theme

func levelColor(for tilt: Double) -> Color {
    let t = min(max(abs(tilt), 0) / 10.0, 1.0)
    return Color(hue: 0.333 * (1.0 - t), saturation: 0.9, brightness: 0.85)
}

// MARK: - Content View

struct ContentView: View {
    @StateObject private var motion = MotionManager()
    @Environment(\.scenePhase) private var phase
    @State private var wasLevel = true

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            let minDim = min(geo.size.width, geo.size.height)

            let eyeSize  = minDim * (landscape ? 0.52 : 0.80)
            let tubeLen  = landscape
                ? min(geo.size.width * 0.72, 560)
                : min(geo.size.width * 0.84, 500)
            let barH: CGFloat = landscape ? 40 : 50
            let numFont: CGFloat = landscape ? 58 : 84

            let displayAngle: Double = motion.isFlat
                ? motion.magnitude
                : (landscape ? motion.angleX : motion.angleY)
            let displayLabel = motion.isFlat
                ? "TILT"
                : (landscape ? "ROLL" : "PITCH")
            let displayColor = levelColor(for: displayAngle)
            let fmt = motion.isFlat ? "%.1f\u{00B0}" : "%+.1f\u{00B0}"

            ZStack {
                Color(red: 0.03, green: 0.03, blue: 0.045)
                    .ignoresSafeArea()
                GridPattern().opacity(0.02).ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        zeroButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, landscape ? 10 : 44)

                    Spacer(minLength: landscape ? 6 : 12)

                    Group {
                        if motion.isFlat {
                            BullseyeLevel(
                                x: motion.angleX,
                                y: motion.angleY,
                                diameter: eyeSize
                            )
                        } else {
                            TubeLevel(
                                tilt: landscape ? motion.angleX : motion.angleY,
                                width: tubeLen,
                                height: barH
                            )
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                        removal: .opacity.combined(with: .scale(scale: 1.02))
                    ))

                    Spacer(minLength: landscape ? 6 : 12)

                    VStack(spacing: landscape ? 8 : 12) {
                        Text(displayLabel)
                            .font(.system(
                                size: landscape ? 13 : 15,
                                weight: .semibold,
                                design: .monospaced
                            ))
                            .foregroundColor(.white.opacity(0.2))
                            .tracking(5)

                        Text(String(format: fmt, displayAngle))
                            .font(.system(
                                size: numFont,
                                weight: .ultraLight,
                                design: .monospaced
                            ))
                            .foregroundColor(displayColor)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }

                    Spacer(minLength: landscape ? 4 : 8)

                    StatusBadge(magnitude: motion.magnitude)
                        .padding(.bottom, landscape ? 14 : 34)
                }
            }
        }
        .statusBarHidden(true)
        .animation(.easeInOut(duration: 0.35), value: motion.isFlat)
        .onChange(of: phase) { p in
            if p == .active { motion.start() } else { motion.stop() }
        }
        .onChange(of: motion.isLevel) { now in
            if now && !wasLevel {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            wasLevel = now
        }
    }

    private var zeroButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                motion.isCalibrated
                    ? motion.resetCalibration()
                    : motion.calibrate()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "target")
                    .font(.system(size: 14, weight: .medium))
                Text("ZERO")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1)
            }
            .foregroundColor(
                motion.isCalibrated
                    ? Color(hue: 0.333, saturation: 0.9, brightness: 0.85)
                    : Color.white.opacity(0.22)
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.white.opacity(0.04)))
        }
    }
}

// MARK: - Bull's Eye Level

struct BullseyeLevel: View {
    let x: Double
    let y: Double
    let diameter: CGFloat

    private let maxAngle: Double = 10.0
    private let bubbleR: CGFloat = 22

    private var maxTravel: CGFloat { diameter / 2 - bubbleR - 2 }
    private var offX: CGFloat { CGFloat(x / maxAngle) * maxTravel }
    private var offY: CGFloat { CGFloat(-y / maxAngle) * maxTravel }
    private var maxTilt: Double { max(abs(x), abs(y)) }
    private var color: Color { levelColor(for: maxTilt) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(maxTilt < 0.5 ? 0.15 : 0), lineWidth: 3)
                .frame(width: diameter + 8, height: diameter + 8)
                .animation(.easeInOut(duration: 0.5), value: maxTilt < 0.5)

            ring(1.0, line: 2)
            ring(0.667, line: 1.5)
            ring(0.333, line: 1.5)

            Crosshair(size: diameter)

            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 6, height: 6)

            bubble
                .offset(
                    x: min(max(offX, -maxTravel), maxTravel),
                    y: min(max(offY, -maxTravel), maxTravel)
                )
                .animation(.interpolatingSpring(stiffness: 150, damping: 14), value: x)
                .animation(.interpolatingSpring(stiffness: 150, damping: 14), value: y)
        }
        .frame(width: diameter, height: diameter)
    }

    private func ring(_ f: CGFloat, line: CGFloat) -> some View {
        Circle()
            .stroke(Color.white.opacity(0.06), lineWidth: line)
            .frame(width: diameter * f, height: diameter * f)
    }

    private var bubble: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.08))
                .frame(width: bubbleR * 3.5, height: bubbleR * 3.5)

            Circle()
                .fill(RadialGradient(
                    colors: [color.opacity(0.9), color.opacity(0.5), color.opacity(0.1)],
                    center: UnitPoint(x: 0.42, y: 0.38),
                    startRadius: 0,
                    endRadius: bubbleR
                ))
                .frame(width: bubbleR * 2, height: bubbleR * 2)

            Circle()
                .fill(RadialGradient(
                    colors: [Color.white.opacity(0.3), .clear],
                    center: UnitPoint(x: 0.36, y: 0.30),
                    startRadius: 0,
                    endRadius: bubbleR * 0.35
                ))
                .frame(width: bubbleR * 2, height: bubbleR * 2)
        }
        .shadow(color: color.opacity(0.5), radius: 10)
        .shadow(color: color.opacity(0.15), radius: 25)
    }
}

// MARK: - Crosshair

struct Crosshair: View {
    let size: CGFloat

    var body: some View {
        Canvas { ctx, sz in
            let cx = sz.width / 2, cy = sz.height / 2
            let gap: CGFloat = 8
            let col = Color.white.opacity(0.06)
            var p = Path()
            p.move(to: CGPoint(x: 0, y: cy))
            p.addLine(to: CGPoint(x: cx - gap, y: cy))
            p.move(to: CGPoint(x: cx + gap, y: cy))
            p.addLine(to: CGPoint(x: sz.width, y: cy))
            p.move(to: CGPoint(x: cx, y: 0))
            p.addLine(to: CGPoint(x: cx, y: cy - gap))
            p.move(to: CGPoint(x: cx, y: cy + gap))
            p.addLine(to: CGPoint(x: cx, y: sz.height))
            ctx.stroke(p, with: .color(col), lineWidth: 0.5)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Tube Level

struct TubeLevel: View {
    let tilt: Double
    let width: CGFloat
    let height: CGFloat

    private let maxAngle: Double = 15.0
    private var maxTravel: CGFloat { width / 2 - height * 0.45 }
    private var offset: CGFloat { CGFloat(tilt / maxAngle) * maxTravel }
    private var color: Color { levelColor(for: tilt) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: height / 2)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: height / 2)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )

            Graduation(width: width, height: height)

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 2, height: height * 0.35)

            Capsule()
                .fill(LinearGradient(
                    colors: [color.opacity(0.85), color.opacity(0.4)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: height * 0.9, height: height * 0.72)
                .shadow(color: color.opacity(0.4), radius: 6)
                .offset(x: min(max(offset, -maxTravel), maxTravel))
                .animation(
                    .interpolatingSpring(stiffness: 150, damping: 14),
                    value: tilt
                )
        }
        .frame(width: width, height: height)
    }
}

struct Graduation: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Canvas { ctx, sz in
            let cx = sz.width / 2
            let usable = sz.width - sz.height
            let step = usable / 10
            for i in -5...5 where i != 0 {
                let x = cx + CGFloat(i) * step
                let major = i.isMultiple(of: 2)
                let h = sz.height * (major ? 0.22 : 0.13)
                ctx.fill(
                    Path(CGRect(
                        x: x - 0.5,
                        y: sz.height / 2 - h / 2,
                        width: 1,
                        height: h
                    )),
                    with: .color(.white.opacity(major ? 0.1 : 0.05))
                )
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let magnitude: Double

    private var isLevel: Bool { magnitude < 0.3 }
    private var color: Color { levelColor(for: magnitude) }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(0.5), radius: 4)

            Text(isLevel ? "LEVEL" : String(format: "%.1f\u{00B0} OFF", magnitude))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .tracking(2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .background(Capsule().fill(color.opacity(isLevel ? 0.08 : 0.03)))
        .animation(.easeInOut(duration: 0.3), value: isLevel)
    }
}

// MARK: - Grid Pattern

struct GridPattern: View {
    var body: some View {
        Canvas { ctx, sz in
            let sp: CGFloat = 24
            var p = Path()
            var x: CGFloat = 0
            while x <= sz.width {
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: sz.height))
                x += sp
            }
            var y: CGFloat = 0
            while y <= sz.height {
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: sz.width, y: y))
                y += sp
            }
            ctx.stroke(p, with: .color(.white), lineWidth: 0.5)
        }
    }
}
