//
//  ScreenRingLightManager.swift
//  boringNotch
//
//  Created for Dino Architecture Evolution.
//

import AppKit
import Defaults
import SwiftUI

@MainActor
public final class ScreenRingLightManager: ObservableObject {
    public static let shared = ScreenRingLightManager()

    private var ringLightWindows: [String: NSWindow] = [:] // screenUUID -> NSWindow
    private var isShowing: Bool = false

    private init() {}

    /// Evaluates whether the full screen ring light should be displayed
    public func update() {
        hide()
    }

    /// Displays the animated neon edge light across all active monitors
    public func show() {
        // Disabled per user preference to keep performance ultra-fast
    }

    /// Dismisses the full screen ring light immediately
    public func hide() {
        isShowing = false
        for (_, window) in ringLightWindows {
            window.orderOut(nil)
            window.close()
        }
        ringLightWindows.removeAll()
    }
}

// MARK: - Animated Neon Edge Light Overlay

public struct ScreenRingLightOverlayView: View {
    @State private var rotationAngle: Double = 0
    @State private var pulseOpacity: Double = 0.85

    // Neon violet, cyan, magenta, and electric pink palette
    private let neonPalette: [Color] = [
        Color(red: 0.68, green: 0.15, blue: 0.98), // Neon Purple/Violet
        Color(red: 0.08, green: 0.76, blue: 1.00), // Electric Cyan
        Color(red: 1.00, green: 0.20, blue: 0.70), // Radiant Pink
        Color(red: 0.35, green: 0.30, blue: 1.00), // Royal Indigo
        Color(red: 0.00, green: 0.88, blue: 0.82), // Bright Turquoise
        Color(red: 0.68, green: 0.15, blue: 0.98)  // Smooth loop back to Violet
    ]

    public init() {}

    public var body: some View {
        GeometryReader { _ in
            let cornerRadius: CGFloat = 18

            ZStack {
                // 1. Outer Deep Diffuse Bloom (diffuses inward from screen edges)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        AngularGradient(
                            colors: neonPalette,
                            center: .center,
                            startAngle: .degrees(rotationAngle),
                            endAngle: .degrees(rotationAngle + 360)
                        ),
                        lineWidth: 16
                    )
                    .blur(radius: 18)
                    .opacity(pulseOpacity * 0.85)

                // 2. Medium Neon Glow (adds vibrant density to the light beam)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        AngularGradient(
                            colors: neonPalette,
                            center: .center,
                            startAngle: .degrees(rotationAngle),
                            endAngle: .degrees(rotationAngle + 360)
                        ),
                        lineWidth: 8
                    )
                    .blur(radius: 8)
                    .opacity(0.95)

                // 3. Crisp Neon Core Border (defines clean border edge)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        AngularGradient(
                            colors: neonPalette,
                            center: .center,
                            startAngle: .degrees(rotationAngle),
                            endAngle: .degrees(rotationAngle + 360)
                        ),
                        lineWidth: 6
                    )
                    .opacity(1.0)
            }
            .padding(1)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                    rotationAngle = 360
                }
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    pulseOpacity = 1.0
                }
            }
        }
    }
}
