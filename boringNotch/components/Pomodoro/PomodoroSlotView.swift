//
//  PomodoroSlotView.swift
//  Dino
//
//  Created for Dino Architecture Evolution.
//

import AppKit
import Defaults
import SwiftUI

// MARK: - Pomodoro Theme
public enum PomodoroTheme {
    public static let orange = Color(red: 252/255, green: 163/255, blue: 77/255)
    public static let orangeInactive = Color(red: 252/255, green: 163/255, blue: 77/255).opacity(0.30)
    public static let tickActive = Color(red: 252/255, green: 163/255, blue: 77/255)
    public static let tickActiveMinor = Color(red: 252/255, green: 163/255, blue: 77/255).opacity(0.85)
    public static let tickInactiveMajor = Color(red: 252/255, green: 163/255, blue: 77/255).opacity(0.24)
    public static let tickInactiveMinor = Color(red: 252/255, green: 163/255, blue: 77/255).opacity(0.12)
    public static let buttonBg = Color(red: 44/255, green: 22/255, blue: 8/255)
    public static let buttonBgPressed = Color(red: 68/255, green: 34/255, blue: 12/255)
}

// MARK: - Button Styles (No Borders)
public struct PomodoroCapsuleButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? PomodoroTheme.buttonBgPressed : PomodoroTheme.buttonBg)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

public struct PomodoroCircleButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? PomodoroTheme.buttonBgPressed : PomodoroTheme.buttonBg)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Caret Triangle Shape
private struct CaretTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Pomodoro Ruler Picker View
public struct PomodoroRulerPickerView: View {
    @ObservedObject private var pomodoro = PomodoroManager.shared
    var isInteractive: Bool

    @State private var scrollPosition: Double = 25.0
    @State private var dragStartScroll: Double = 25.0
    @State private var isDragging: Bool = false
    @State private var activeMinute: Int = 25

    // White flash state on the active tick
    @State private var whiteFlashTick: Int = -1
    @State private var whiteFlashProgress: Double = 0.0

    private let tickSpacing: CGFloat = 8.5
    private let displayMinMinute: Int = 0
    private let selectableMinMinute: Int = 1
    private let maxMinute: Int = 120

    public init(isInteractive: Bool = true) {
        self.isInteractive = isInteractive
    }

    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let centerX = width / 2.0
            let baselineY: CGFloat = 50.0

            ZStack(alignment: .top) {
                // Ticks & Numbers (Moving horizontally based on scrollPosition)
                ZStack(alignment: .top) {
                    ForEach(displayMinMinute...maxMinute, id: \.self) { minute in
                        let deltaMinute = CGFloat(Double(minute) - scrollPosition)
                        let x = centerX + (deltaMinute * tickSpacing)

                        // Render ticks within view bounds (plus margin for smooth edges)
                        if x >= -35 && x <= width + 35 {
                            let isMajor = minute % 5 == 0
                            let isPastOrEqual = Double(minute) <= scrollPosition + 0.25
                            let isFlashing = (minute == whiteFlashTick && whiteFlashProgress > 0)

                            if isMajor {
                                // Number label above the major tick (Fixed constant font weight so it NEVER wobbles)
                                Text("\(minute)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(
                                        isFlashing ? Color.white : (isPastOrEqual ? PomodoroTheme.orange : PomodoroTheme.orangeInactive)
                                    )
                                    .position(x: x, y: 11)

                                // Major tick line
                                Capsule()
                                    .fill(isPastOrEqual ? PomodoroTheme.tickActive : PomodoroTheme.tickInactiveMajor)
                                    .frame(width: 2.2, height: 26)
                                    .overlay(
                                        Capsule()
                                            .fill(Color.white)
                                            .opacity(minute == whiteFlashTick ? whiteFlashProgress : 0)
                                    )
                                    .position(x: x, y: baselineY - 13.0)
                            } else {
                                // Minor tick line
                                Capsule()
                                    .fill(isPastOrEqual ? PomodoroTheme.tickActiveMinor : PomodoroTheme.tickInactiveMinor)
                                    .frame(width: 1.4, height: 16)
                                    .overlay(
                                        Capsule()
                                            .fill(Color.white)
                                            .opacity(minute == whiteFlashTick ? whiteFlashProgress : 0)
                                    )
                                    .position(x: x, y: baselineY - 8.0)
                            }
                        }
                    }
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black, location: 0.14),
                            .init(color: .black, location: 0.86),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

                // Transparent Black Edge Overlays
                HStack {
                    LinearGradient(
                        colors: [Color.black, Color.black.opacity(0.6), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 36)

                    Spacer(minLength: 0)

                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.6), Color.black],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 36)
                }
                .allowsHitTesting(false)

                // Fixed Center Triangle Caret Indicator (Points directly up at the active tick)
                CaretTriangle()
                    .fill(PomodoroTheme.orange)
                    .frame(width: 10, height: 7.5)
                    .position(x: centerX, y: baselineY + 7.0)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        guard isInteractive else { return }

                        if !isDragging {
                            isDragging = true
                            dragStartScroll = scrollPosition
                        }

                        let delta = Double(value.translation.width / tickSpacing)
                        // Allow scrolling down towards 0 visually, but clamped selection to min 1
                        let newPos = max(Double(displayMinMinute), min(Double(maxMinute), dragStartScroll - delta))
                        scrollPosition = newPos

                        let nearest = max(selectableMinMinute, min(maxMinute, Int(round(newPos))))
                        if nearest != activeMinute {
                            activeMinute = nearest
                            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                            triggerWhiteFlash(for: nearest)
                            pomodoro.setCustomMinutes(nearest)
                        }
                    }
                    .onEnded { _ in
                        guard isInteractive else { return }

                        let target = max(Double(selectableMinMinute), min(Double(maxMinute), round(scrollPosition)))
                        let nearest = Int(target)
                        activeMinute = nearest
                        pomodoro.setCustomMinutes(nearest)

                        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                            scrollPosition = target
                        }
                        isDragging = false
                    }
            )
            .background(
                RulerScrollMonitor(onScroll: { deltaX in
                    guard isInteractive else { return }
                    let delta = Double(deltaX / tickSpacing)
                    let newPos = max(Double(displayMinMinute), min(Double(maxMinute), scrollPosition - delta))
                    scrollPosition = newPos
                    let nearest = max(selectableMinMinute, min(maxMinute, Int(round(newPos))))
                    if nearest != activeMinute {
                        activeMinute = nearest
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                        triggerWhiteFlash(for: nearest)
                        pomodoro.setCustomMinutes(nearest)
                    }
                })
            )
            .onAppear {
                syncInitialPosition()
            }
            .onChange(of: pomodoro.state) { _, newState in
                if newState == .idle {
                    let focusMin = Double(max(selectableMinMinute, min(maxMinute, Defaults[.pomodoroFocusMinutes])))
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        scrollPosition = focusMin
                        activeMinute = Int(focusMin)
                    }
                }
            }
            .onChange(of: pomodoro.remainingTime) { _, newRemaining in
                if !isInteractive && !isDragging {
                    withAnimation(.linear(duration: 0.95)) {
                        scrollPosition = max(0.0, newRemaining / 60.0)
                    }
                }
            }
        }
        .frame(height: 64)
    }

    private func syncInitialPosition() {
        if pomodoro.state == .idle {
            let focusMin = Double(max(selectableMinMinute, min(maxMinute, Defaults[.pomodoroFocusMinutes])))
            scrollPosition = focusMin
            activeMinute = Int(focusMin)
        } else {
            scrollPosition = max(0.0, pomodoro.remainingTime / 60.0)
            activeMinute = max(selectableMinMinute, min(maxMinute, Int(ceil(pomodoro.remainingTime / 60.0))))
        }
    }

    private func triggerWhiteFlash(for tick: Int) {
        whiteFlashTick = tick
        whiteFlashProgress = 1.0
        withAnimation(.easeOut(duration: 0.40)) {
            whiteFlashProgress = 0.0
        }
    }
}

// MARK: - Local Scroll Monitor for Trackpad Horizontal Scroll
private struct RulerScrollMonitor: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScroll: onScroll)
    }

    final class Coordinator: NSObject {
        private let onScroll: (CGFloat) -> Void
        private var monitor: Any?
        private var accumulatedDelta: CGFloat = 0

        init(onScroll: @escaping (CGFloat) -> Void) {
            self.onScroll = onScroll
        }

        func attach(to view: NSView) {
            detach()
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self, weak view] event in
                guard let self = self, let view = view, event.window === view.window else {
                    return event
                }
                let pointInView = view.convert(event.locationInWindow, from: nil)
                if view.bounds.contains(pointInView) {
                    self.accumulatedDelta += event.scrollingDeltaX
                    if abs(self.accumulatedDelta) > 4.0 {
                        self.onScroll(self.accumulatedDelta)
                        self.accumulatedDelta = 0
                    }
                }
                return event
            }
        }

        func detach() {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }
}

// MARK: - Pomodoro Open Notch View
public struct PomodoroOpenNotchView: View {
    @ObservedObject private var pomodoro = PomodoroManager.shared

    public init() {}

    private var sessionTitleText: String {
        let cycleLimit = max(1, Defaults[.pomodoroCycleBeforeLongBreak])
        let currentCycle = (pomodoro.completedFocusSessions % cycleLimit) + 1
        switch pomodoro.phase {
        case .focus:
            return "Focus \(currentCycle)/\(cycleLimit)"
        case .shortBreak:
            return "Short Break \(currentCycle)/\(cycleLimit)"
        case .longBreak:
            return "Long Break"
        }
    }

    public var body: some View {
        VStack(spacing: 12) {
            // MARK: - 1. Top Row: Countdown (Left) & Phase/Cycle (Right) - Justify Between
            HStack(alignment: .firstTextBaseline) {
                // Countdown Time Display (SF Pro font, monospaced digits)
                Text(pomodoro.formattedRemainingTime)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(PomodoroTheme.orange)
                    .monospacedDigit()
                    .lineLimit(1)

                Spacer(minLength: 12)

                // Session Status Display (e.g. "Focus 1/4" - medium weight)
                Text(sessionTitleText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(PomodoroTheme.orange)
                    .lineLimit(1)
            }
            .padding(.horizontal, 2)
            .padding(.top, 2)

            // MARK: - 2. Middle Section: Tape-Measure Ruler Picker
            // Interactive only when countdown has not started (state == .idle)
            PomodoroRulerPickerView(isInteractive: pomodoro.state == .idle)
                .padding(.horizontal, 0)

            // MARK: - 3. Bottom Section: Action Controls - Justify Between
            HStack(alignment: .center, spacing: 0) {
                // Leading Control: Start Timer (before start) OR Stop/Resume (after start)
                Group {
                    if pomodoro.state == .idle {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                pomodoro.start()
                            }
                        } label: {
                            Text("Start Timer")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(PomodoroTheme.orange)
                                .padding(.horizontal, 18)
                                .frame(height: 35)
                        }
                        .buttonStyle(PomodoroCapsuleButtonStyle())
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                    } else {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                if pomodoro.isRunning {
                                    pomodoro.pause()
                                } else {
                                    pomodoro.resume()
                                }
                            }
                        } label: {
                            Text(pomodoro.isRunning ? "Stop" : "Resume")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(PomodoroTheme.orange)
                                .padding(.horizontal, 16)
                                .frame(height: 35)
                        }
                        .buttonStyle(PomodoroCapsuleButtonStyle())
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.78), value: pomodoro.state)

                Spacer(minLength: 16)

                // Trailing Controls: Reset Icon Button & Next Icon Button
                HStack(spacing: 8) {
                    // Reset Button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            pomodoro.reset()
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(PomodoroTheme.orange)
                            .frame(width: 35, height: 35)
                    }
                    .buttonStyle(PomodoroCircleButtonStyle())
                    .help(pomodoro.state == .idle ? "Reset to default" : "Reset session")

                    // Next / Skip Button (forward.end.fill icon)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            pomodoro.skip()
                        }
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(PomodoroTheme.orange)
                            .frame(width: 35, height: 35)
                    }
                    .buttonStyle(PomodoroCircleButtonStyle())
                    .help("Skip to next session")
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 2)
        }
        .padding(.horizontal, 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Pomodoro Closed Pill View (for Mini Notch / Dynamic Island pill)
public struct PomodoroClosedPillView: View {
    @ObservedObject private var pomodoro = PomodoroManager.shared

    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: pomodoro.phase == .focus ? "timer" : "cup.and.saucer.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(PomodoroTheme.orange)

            Spacer(minLength: 0)

            Text(pomodoro.formattedRemainingTime)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Pomodoro Expanded Card View
public struct PomodoroExpandedCardView: View {
    public init() {}

    public var body: some View {
        PomodoroOpenNotchView()
            .frame(width: 360, height: 145)
    }
}
