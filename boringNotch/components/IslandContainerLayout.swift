//
//  IslandContainerLayout.swift
//  boringNotch
//

import SwiftUI
import Defaults

struct IslandContainerLayout<Content: View>: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var tuningPreview = NotchTuningPreviewState.shared
    @Default(.notchWidthAdjustment) private var notchWidthAdjustment
    @Default(.notchHeightAdjustment) private var notchHeightAdjustment

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
    let pomodoroEnabled: Bool
    let pomodoroClosedNotchDisplayMode: PomodoroClosedNotchDisplayMode
    let shouldShowPomodoroInlineClosedVisual: Bool
    let animationSpring: Animation

    let onMainPillHover: (Bool) -> Void
    let onHover: (Bool) -> Void
    let onMainPillTap: () -> Void
    let onCompanionCircleTap: () -> Void

    @ViewBuilder let content: () -> Content

    private var isTuningPreviewActive: Bool {
        !isCurrentDisplayIsland && vm.notchState == .closed && tuningPreview.activeAxis != nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: (vm.notchState == .closed && isDualActivityActive) ? 8 : 0) {
            mainPill
                .background {
                    GeometryReader { geometry in
                        if isTuningPreviewActive, let axis = tuningPreview.activeAxis {
                            let supporterSize = tuningSupporterSize(for: axis, notchSize: geometry.size)
                            tuningSupporter(for: axis, size: supporterSize, notchSize: geometry.size)
                                .position(
                                    x: geometry.size.width / 2,
                                    y: supporterSize.height / 2
                                )
                                .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.22, dampingFraction: 0.82), value: tuningPreview.activeAxis)
                    .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.86), value: tuningPreview.draftValue)
                    .allowsHitTesting(false)
                }
                .conditionalModifier(isCurrentDisplayIsland) { view in
                    view.contentShape(RoundedRectangle(cornerRadius: islandCornerRadius, style: .continuous))
                }
                .conditionalModifier(!isCurrentDisplayIsland) { view in
                    view.contentShape(Rectangle())
                }
                .onHover { hovering in
                    if isDualActivityActive && vm.notchState == .closed {
                        onMainPillHover(hovering)
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

    @ObservedObject private var dinoCoordinator = DinoCoordinator.shared

    private var isMirrorOpen: Bool {
        vm.notchState == .open && dinoCoordinator.activeSlot == .webcam
    }

    private var openHorizontalPadding: CGFloat {
        if isMirrorOpen {
            return isCurrentDisplayIsland ? 12 : (topCornerRadius + 14)
        }
        return isCurrentDisplayIsland ? 22 : (topCornerRadius + 14)
    }

    private var openTopPadding: CGFloat {
        if isMirrorOpen {
            return isCurrentDisplayIsland ? 12 : (vm.effectiveClosedNotchHeight + 8)
        }
        return 18
    }

    private var openBottomPadding: CGFloat {
        if isMirrorOpen {
            return isCurrentDisplayIsland ? 12 : 14
        }
        return 18
    }

    // MARK: - Main Pill Shell

    @ViewBuilder
    private var mainPill: some View {
        content()
            .frame(alignment: .top)
            .padding(
                .horizontal,
                vm.notchState == .open
                    ? openHorizontalPadding
                    : (isCurrentDisplayIsland ? (isShowingMusicSneakPeek ? 10 : 8) : (topCornerRadius + 6))
            )
            .padding(.top, vm.notchState == .open ? openTopPadding : (isShowingMusicSneakPeek ? 4 : 0))
            .padding(.bottom, vm.notchState == .open ? openBottomPadding : (isShowingMusicSneakPeek ? 6 : 0))
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

    private func tuningSupporterSize(for axis: NotchTuningAxis, notchSize: CGSize) -> CGSize {
        switch axis {
        case .width:
            let committed = min(5, max(-3, notchWidthAdjustment))
            let committedPoints = committed > 0 ? committed * 2 : committed
            let draft = tuningPreview.draftValue
            let draftPoints = draft > 0 ? draft * 2 : draft
            return CGSize(
                width: notchSize.width + CGFloat(draftPoints - committedPoints),
                height: notchSize.height + 30
            )
        case .height:
            let committed = min(3, max(-3, notchHeightAdjustment))
            return CGSize(
                width: notchSize.width + 112,
                height: notchSize.height + CGFloat(tuningPreview.draftValue - committed)
            )
        }
    }

    private func tuningSupporter(for axis: NotchTuningAxis, size: CGSize, notchSize: CGSize) -> some View {
        let value = tuningPreview.draftValue
        let label = value == 0 ? "0" : (value > 0 ? "+\(value)" : "\(value)")

        return currentNotchShape
            .fill(NotchTuningPreviewState.rose)
            .overlay(alignment: .bottom) {
                if axis == .width {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer(minLength: 4)
                        Text(label)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Spacer(minLength: 4)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 22)
                    .frame(height: size.height - notchSize.height)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.up.and.down")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer(minLength: 4)
                        Text(label)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 22)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(
                width: size.width,
                height: size.height
            )
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
