//
//  IslandContainerLayout.swift
//  boringNotch
//

import SwiftUI
import Defaults

struct IslandContainerLayout<Content: View>: View {
    @EnvironmentObject var vm: BoringViewModel

    let isCurrentDisplayIsland: Bool
    let isCurrentScreenBuiltin: Bool
    let islandStyle: IslandStyle
    let isShowingMusicSneakPeek: Bool
    let isDualActivityActive: Bool
    let isHovering: Bool
    let isScaleHovered: Bool
    let emptyClickBounce: Bool
    let islandCornerRadius: CGFloat
    let topCornerRadius: CGFloat
    let currentNotchShape: NotchShape
    let islandYOffset: CGFloat
    let islandOpacity: Double
    let gestureProgress: CGFloat
    let pomodoroEnabled: Bool
    let pomodoroClosedNotchDisplayMode: PomodoroClosedNotchDisplayMode
    let shouldShowPomodoroInlineClosedVisual: Bool
    let animationSpring: Animation

    let onMainPillHover: (Bool) -> Void
    let onHover: (Bool) -> Void
    let onMainPillTap: () -> Void
    let onCompanionCircleTap: () -> Void

    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: (vm.notchState == .closed && isDualActivityActive) ? 8 : 0) {
            mainPill
                .contentShape(RoundedRectangle(cornerRadius: islandCornerRadius, style: .continuous))
                .onHover { hovering in
                    if isDualActivityActive && vm.notchState == .closed {
                        onMainPillHover(hovering)
                    } else {
                        onHover(hovering)
                    }
                }
                .onTapGesture {
                    onMainPillTap()
                }

            if isCurrentDisplayIsland && isDualActivityActive && vm.notchState == .closed {
                PomodoroCompanionCircleView(
                    isCurrentScreenBuiltin: isCurrentScreenBuiltin,
                    islandStyle: islandStyle,
                    isHovering: isHovering,
                    onOpenPomodoro: onCompanionCircleTap
                )
                .opacity(isShowingMusicSneakPeek ? 0 : 1)
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                        removal: .scale(scale: 0.3).combined(with: .opacity)
                    )
                )
            }
        }
    }

    // MARK: - Main Pill Shell

    @ViewBuilder
    private var mainPill: some View {
        content()
            .frame(alignment: .top)
            .padding(
                .horizontal,
                vm.notchState == .open
                    ? (isCurrentDisplayIsland ? 22 : (topCornerRadius + 14))
                    : (isCurrentDisplayIsland ? (isShowingMusicSneakPeek ? 10 : 8) : (topCornerRadius + 6))
            )
            .padding(.top, vm.notchState == .open ? 18 : (isShowingMusicSneakPeek ? 4 : 0))
            .padding(.bottom, vm.notchState == .open ? 18 : (isShowingMusicSneakPeek ? 6 : 0))
            .background(surfaceBackground)
            .conditionalModifier(isCurrentDisplayIsland) { view in
                view.clipShape(RoundedRectangle(cornerRadius: islandCornerRadius, style: .continuous))
            }
            .conditionalModifier(!isCurrentDisplayIsland) { view in
                view.clipShape(currentNotchShape)
            }
            .overlay(alignment: .top) {
                surfaceOverlay
            }
            .shadow(
                color: ((vm.notchState == .open || isHovering) && Defaults[.enableShadow])
                    ? (isCurrentDisplayIsland ? Color.black.opacity(0.65) : Color.black.opacity(0.7))
                    : (isCurrentDisplayIsland && Defaults[.enableShadow] ? Color.black.opacity(0.25) : .clear),
                radius: isCurrentDisplayIsland ? ((isHovering || vm.notchState == .open) ? 14 : 5) : (Defaults[.cornerRadiusScaling] ? 8 : 5),
                x: 0,
                y: isCurrentDisplayIsland ? ((isHovering || vm.notchState == .open) ? 6 : 2) : 0
            )
            .padding(
                .bottom,
                vm.effectiveClosedNotchHeight == 0 ? 10 : 0
            )
    }

    // MARK: - Surface Shaders

    @ViewBuilder
    private var surfaceBackground: some View {
        if isCurrentDisplayIsland {
            if islandStyle == .glass {
                ZStack {
                    VisualEffectBackground(material: .hudWindow, blendingMode: .withinWindow)
                    Color.black.opacity(0.32)
                }
            } else {
                Color.black
            }
        } else {
            Color.black
        }
    }

    @ViewBuilder
    private var surfaceOverlay: some View {
        if isCurrentDisplayIsland {
            if islandStyle == .glass {
                RoundedRectangle(cornerRadius: islandCornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.38), Color.white.opacity(0.14)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            } else {
                RoundedRectangle(cornerRadius: islandCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.9)
            }
        } else {
            Rectangle()
                .fill(.black)
                .frame(height: 1)
                .padding(.horizontal, topCornerRadius)
        }
    }
}
