//
//  PomodoroClosedViews.swift
//  Dino
//

import Defaults
import SwiftUI

// MARK: - Pomodoro Closed Notch View
public struct PomodoroClosedNotchView: View {
    @EnvironmentObject private var vm: BoringViewModel
    @ObservedObject private var pomodoroManager = PomodoroManager.shared

    var isCurrentDisplayIsland: Bool
    var isCurrentScreenBuiltin: Bool

    public init(
        isCurrentDisplayIsland: Bool,
        isCurrentScreenBuiltin: Bool
    ) {
        self.isCurrentDisplayIsland = isCurrentDisplayIsland
        self.isCurrentScreenBuiltin = isCurrentScreenBuiltin
    }

    public var body: some View {
        let isIsland = isCurrentDisplayIsland
        let isBuiltin = isCurrentScreenBuiltin

        let buttonDiameter: CGFloat = isIsland ? (isBuiltin ? 20 : 15.5) : 20
        let iconSize: CGFloat = isIsland ? (isBuiltin ? 9 : 7) : 9
        let textSize: CGFloat = isIsland ? (isBuiltin ? 14 : 11.5) : 15
        let buttonGap: CGFloat = isIsland ? 4 : 5
        let centerSpacer: CGFloat = isIsland
            ? (isBuiltin ? 48 : 36)
            : (isBuiltin ? (vm.closedNotchSize.width + 16) : (vm.closedNotchSize.width - 47))

        HStack(spacing: 0) {
            Text(pomodoroManager.formattedRemainingTime)
                .font(.system(size: textSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Rectangle()
                .fill(Color.clear)
                .frame(width: centerSpacer)

            HStack(spacing: buttonGap) {
                Button {
                    pomodoroManager.togglePlayPause()
                } label: {
                    ZStack {
                        Circle().fill(Color.yellow)
                        Image(systemName: pomodoroManager.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: iconSize, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.85))
                    }
                    .frame(width: buttonDiameter, height: buttonDiameter)
                }
                .buttonStyle(.plain)

                Button {
                    pomodoroManager.reset()
                } label: {
                    ZStack {
                        Circle().fill(Color.red)
                        Image(systemName: "xmark")
                            .font(.system(size: iconSize, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: buttonDiameter, height: buttonDiameter)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(
            height: vm.effectiveClosedNotchHeight,
            alignment: .center
        )
        .padding(.horizontal, isIsland ? 0 : 4)
    }
}

// MARK: - Pomodoro Companion Circle View
public struct PomodoroCompanionCircleView: View {
    @EnvironmentObject private var vm: BoringViewModel
    @ObservedObject private var pomodoroManager = PomodoroManager.shared

    var isCurrentScreenBuiltin: Bool
    var islandStyle: IslandStyle
    var isHovering: Bool
    var onOpenPomodoro: () -> Void

    public init(
        isCurrentScreenBuiltin: Bool,
        islandStyle: IslandStyle,
        isHovering: Bool,
        onOpenPomodoro: @escaping () -> Void
    ) {
        self.isCurrentScreenBuiltin = isCurrentScreenBuiltin
        self.islandStyle = islandStyle
        self.isHovering = isHovering
        self.onOpenPomodoro = onOpenPomodoro
    }

    private var surfaceBackground: some View {
        Group {
            if islandStyle == .glass {
                VisualEffectBackground()
            } else {
                Color.black
            }
        }
    }

    private var companionCircleOverlay: some View {
        Group {
            if islandStyle == .glass {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.38), Color.white.opacity(0.14)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            } else {
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.9)
            }
        }
    }

    public var body: some View {
        let diameter: CGFloat = vm.effectiveClosedNotchHeight
        let ringColor: Color = pomodoroManager.isBreakPhase
            ? Color(red: 0.2, green: 0.85, blue: 0.4)
            : Color(red: 243/255.0, green: 164/255.0, blue: 28/255.0)
        // Match exact Pomodoro closed button sizing (20pt Built-in, 15.5pt External)
        let ringSize: CGFloat = isCurrentScreenBuiltin ? 20.0 : 15.5
        let ringLineWidth: CGFloat = isCurrentScreenBuiltin ? 2.0 : 1.6

        ZStack {
            PomodoroDetachedTickRingView(
                progress: Double(pomodoroManager.progress),
                ringColor: ringColor,
                size: ringSize,
                lineWidth: ringLineWidth
            )
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.82), value: pomodoroManager.progress)
        }
        .frame(width: diameter, height: diameter)
        .background(surfaceBackground)
        .clipShape(Circle())
        .overlay(companionCircleOverlay)
        .shadow(
            color: ((vm.notchState == .open || isHovering) && Defaults[.enableShadow])
                ? Color.black.opacity(0.65)
                : (Defaults[.enableShadow] ? Color.black.opacity(0.25) : .clear),
            radius: (isHovering || vm.notchState == .open) ? 14 : 5,
            x: 0,
            y: (isHovering || vm.notchState == .open) ? 6 : 2
        )
        .contentShape(Circle())
        .onTapGesture {
            onOpenPomodoro()
        }
    }
}

// MARK: - Pomodoro Detached Tick Ring View
public struct PomodoroDetachedTickRingView: View {
    var progress: Double
    var ringColor: Color
    var size: CGFloat
    var lineWidth: CGFloat

    public init(
        progress: Double,
        ringColor: Color,
        size: CGFloat,
        lineWidth: CGFloat
    ) {
        self.progress = progress
        self.ringColor = ringColor
        self.size = size
        self.lineWidth = lineWidth
    }

    public var body: some View {
        let radius = size / 2.0
        let clampedProgress = max(0.01, min(1.0, progress))
        let endAngleDegrees = -90.0 + (clampedProgress * 360.0)
        let angleRad = (endAngleDegrees * .pi) / 180.0

        // Clean gap between outer circular arc and inner tick line
        let outerGap: CGFloat = lineWidth * 0.85 + 1.2
        let tickOuterR = max(2.0, radius - outerGap)
        let tickInnerR = max(1.0, radius * 0.28)
        let cosA = CGFloat(cos(angleRad))
        let sinA = CGFloat(sin(angleRad))
        let center = CGPoint(x: radius, y: radius)
        let tickStart = CGPoint(x: center.x + tickInnerR * cosA, y: center.y + tickInnerR * sinA)
        let tickEnd = CGPoint(x: center.x + tickOuterR * cosA, y: center.y + tickOuterR * sinA)

        ZStack {
            // Subtle background track ring
            Circle()
                .stroke(ringColor.opacity(0.18), lineWidth: lineWidth)
                .frame(width: size, height: size)

            // Outer progress arc (fully rounded ends)
            Circle()
                .trim(from: 0.0, to: CGFloat(clampedProgress))
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)

            // Detached radial inward tick line (clean gap from perimeter arc, fully rounded ends)
            Path { path in
                path.move(to: tickStart)
                path.addLine(to: tickEnd)
            }
            .stroke(
                ringColor,
                style: StrokeStyle(lineWidth: lineWidth * 0.95, lineCap: .round)
            )
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }
}
