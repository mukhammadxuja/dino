//
//  PanGesture.swift
//  boringNotch
//

import AppKit
import SwiftUI

enum PanDirection {
    case left, right, up, down
}

enum NotchGestureActivation {
    static let distance: CGFloat = 34
}

extension View {
    func verticalSwipeGesture(
        isEnabled: Bool = true,
        threshold: CGFloat = 4,
        action: @escaping (CGFloat, PanDirection, NSEvent.Phase, Bool) -> Void
    ) -> some View {
        background(AxisScrollMonitor(isHorizontal: false, isEnabled: isEnabled, threshold: threshold, action: action))
    }

    func horizontalSwipeGesture(
        threshold: CGFloat = 4,
        action: @escaping (CGFloat, PanDirection, NSEvent.Phase, Bool) -> Void
    ) -> some View {
        background(AxisScrollMonitor(isHorizontal: true, isEnabled: true, threshold: threshold, action: action))
    }
}

private struct AxisScrollMonitor: NSViewRepresentable {
    let isHorizontal: Bool
    let isEnabled: Bool
    let threshold: CGFloat
    let action: (CGFloat, PanDirection, NSEvent.Phase, Bool) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.installMonitor(on: view)
        context.coordinator.setEnabled(isEnabled)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.action = action
        context.coordinator.setEnabled(isEnabled)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isHorizontal: isHorizontal, threshold: threshold, action: action)
    }

    @MainActor final class Coordinator: NSObject {
        private let isHorizontal: Bool
        private let threshold: CGFloat
        var action: (CGFloat, PanDirection, NSEvent.Phase, Bool) -> Void
        private var isEnabled = true
        private var monitor: Any?
        private var accumulated: CGFloat = 0
        private var active = false
        private var lastWasPrecise = false
        private var lastDirection: PanDirection
        private var endTask: Task<Void, Never>?

        init(
            isHorizontal: Bool,
            threshold: CGFloat,
            action: @escaping (CGFloat, PanDirection, NSEvent.Phase, Bool) -> Void
        ) {
            self.isHorizontal = isHorizontal
            self.threshold = threshold
            self.action = action
            self.lastDirection = isHorizontal ? .left : .down
        }

        func installMonitor(on view: NSView) {
            removeMonitor()
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self, weak view] event in
                guard let self, let view, event.window === view.window else { return event }
                self.handleScroll(event)
                return event
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            endTask?.cancel()
            endTask = nil
            active = false
            accumulated = 0
            lastWasPrecise = false
        }

        func setEnabled(_ enabled: Bool) {
            guard isEnabled != enabled else { return }
            isEnabled = enabled
            if !enabled { finish(.cancelled) }
        }

        private func finish(_ phase: NSEvent.Phase) {
            endTask?.cancel()
            endTask = nil
            if active {
                action(abs(accumulated), lastDirection, phase, lastWasPrecise)
            }
            active = false
            accumulated = 0
            lastWasPrecise = false
        }

        private func scheduleEndForPhaseLessDevice() {
            endTask?.cancel()
            endTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(240))
                guard !Task.isCancelled else { return }
                finish(.ended)
            }
        }

        private func handleScroll(_ event: NSEvent) {
            guard isEnabled else { return }
            if event.phase == .ended || event.phase == .cancelled {
                finish(event.phase == .cancelled ? .cancelled : .ended)
                return
            }

            guard event.momentumPhase.isEmpty else { return }
            guard !event.modifierFlags.contains(.option) else { return }

            let axisDelta = isHorizontal ? event.scrollingDeltaX : event.scrollingDeltaY
            let otherDelta = isHorizontal ? event.scrollingDeltaY : event.scrollingDeltaX
            guard abs(axisDelta) >= 1.5 * abs(otherDelta) else { return }

            let scale: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 8
            let delta = axisDelta * scale
            guard abs(delta) > 0.2 else { return }

            // Net movement makes a swipe that returns to its starting point cancel itself.
            accumulated += delta
            if accumulated != 0 {
                if isHorizontal {
                    lastDirection = accumulated > 0 ? .right : .left
                } else {
                    lastDirection = accumulated > 0 ? .down : .up
                }
            }

            let magnitude = abs(accumulated)
            if !active && magnitude >= threshold {
                active = true
                lastWasPrecise = event.hasPreciseScrollingDeltas
                action(magnitude, lastDirection, .began, lastWasPrecise)
            } else if active {
                lastWasPrecise = lastWasPrecise || event.hasPreciseScrollingDeltas
                action(magnitude, lastDirection, .changed, lastWasPrecise)
            }

            // Trackpads report .ended when fingers lift. Never finish their
            // gesture just because movement pauses while fingers are held.
            if event.phase.isEmpty && !event.hasPreciseScrollingDeltas {
                scheduleEndForPhaseLessDevice()
            }
        }
    }
}
