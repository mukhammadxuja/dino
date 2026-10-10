//
//  DinoSlotRouter.swift
//  boringNotch
//

import SwiftUI
import Defaults

struct DinoSlotRouter: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var coordinator = BoringViewCoordinator.shared

    let isCurrentDisplayIsland: Bool
    let isCurrentScreenBuiltin: Bool
    let computedChinWidth: CGFloat
    let isShowingMusicSneakPeek: Bool
    let isShowingSystemToastHUD: Bool
    let isDualActivityActive: Bool
    let isAntigravityActive: Bool
    let shouldShowPomodoroInlineClosedVisual: Bool
    let shouldShowMusicClosedVisual: Bool
    let shouldShowCalendarClosedVisual: Bool
    let shouldShowNonMusicClosedVisual: Bool

    let mediaGestureDirection: MediaGestureDirection
    let mediaGestureIconVisible: Bool
    let coverRotationY: Double
    let albumArtNamespace: Namespace.ID
    let useMusicVisualizer: Bool
    let islandStyle: IslandStyle
    let showCalendar: Bool
    let showNotHumanFace: Bool
    let showMirror: Bool

    @Binding var isHovering: Bool
    @Binding var gestureProgress: CGFloat
    @Binding var showCoverHoverMusicDetails: Bool
    @Binding var coverHoverDismissTask: Task<Void, Never>?

    let onOpenPomodoro: () -> Void

    private var musicManager: MusicManager { MusicManager.shared }

    var body: some View {
        VStack(spacing: 0) {
            if vm.notchState == .closed || coordinator.helloAnimationRunning {
                VStack(spacing: 0) {
                    if coordinator.helloAnimationRunning {
                        Spacer()
                        HelloAnimation(onFinish: {
                            vm.closeHello()
                        }).frame(
                            width: getClosedNotchSize().width,
                            height: 80
                        )
                        .padding(.top, 40)
                        Spacer()
                    } else {
                        closedSlotView
                    }
                }
                .zIndex(2)
            }

            if vm.notchState == .open {
                openNotchContent
            }
        }
        .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], delegate: GeneralDropTargetDelegate(isTargeted: $vm.generalDropTargeting))
    }

    // MARK: - Closed Slot View Routing

    @ViewBuilder
    private var closedSlotView: some View {
        if coordinator.expandingView.type == .battery && coordinator.expandingView.show && vm.notchState == .closed {
            BatteryClosedNotchLayoutView(isCurrentDisplayIsland: isCurrentDisplayIsland)
        } else if isAntigravityActive {
            AntigravityLiveActivity()
                .frame(width: computedChinWidth, height: vm.effectiveClosedNotchHeight, alignment: .center)
                .clipped()
                .transition(.opacity)
        } else if isShowingSystemToastHUD {
            InlineHUD(
                type: $coordinator.sneakPeek.type,
                value: $coordinator.sneakPeek.value,
                icon: $coordinator.sneakPeek.icon,
                hoverAnimation: $isHovering,
                gestureProgress: $gestureProgress
            )
            .transition(.opacity)
        } else if DinoCoordinator.shared.activeSlot == .weather && vm.notchState == .closed {
            WeatherClosedPillView()
                .frame(
                    width: isCurrentDisplayIsland ? (isCurrentScreenBuiltin ? 120 : 105) : (vm.closedNotchSize.width + 10),
                    height: vm.effectiveClosedNotchHeight
                )
                .transition(.opacity)
        } else if isDualActivityActive {
            MusicLiveActivityView(
                isCurrentDisplayIsland: isCurrentDisplayIsland,
                isCurrentScreenBuiltin: isCurrentScreenBuiltin,
                isShowingMusicSneakPeek: isShowingMusicSneakPeek,
                mediaGestureDirection: mediaGestureDirection,
                mediaGestureIconVisible: mediaGestureIconVisible,
                coverRotationY: coverRotationY,
                albumArtNamespace: albumArtNamespace,
                isDualActivityActive: isDualActivityActive,
                useMusicVisualizer: useMusicVisualizer,
                islandStyle: islandStyle,
                showCoverHoverMusicDetails: $showCoverHoverMusicDetails,
                coverHoverDismissTask: $coverHoverDismissTask,
                onOpenPomodoro: onOpenPomodoro
            )
            .frame(alignment: .center)
            .transition(.opacity)
        } else if shouldShowPomodoroInlineClosedVisual {
            PomodoroClosedNotchView(
                isCurrentDisplayIsland: isCurrentDisplayIsland,
                isCurrentScreenBuiltin: isCurrentScreenBuiltin
            )
            .transition(.opacity)
        } else if shouldShowMusicClosedVisual {
            MusicLiveActivityView(
                isCurrentDisplayIsland: isCurrentDisplayIsland,
                isCurrentScreenBuiltin: isCurrentScreenBuiltin,
                isShowingMusicSneakPeek: isShowingMusicSneakPeek,
                mediaGestureDirection: mediaGestureDirection,
                mediaGestureIconVisible: mediaGestureIconVisible,
                coverRotationY: coverRotationY,
                albumArtNamespace: albumArtNamespace,
                isDualActivityActive: isDualActivityActive,
                useMusicVisualizer: useMusicVisualizer,
                islandStyle: islandStyle,
                showCoverHoverMusicDetails: $showCoverHoverMusicDetails,
                coverHoverDismissTask: $coverHoverDismissTask,
                onOpenPomodoro: onOpenPomodoro
            )
            .frame(alignment: .center)
        } else if shouldShowCalendarClosedVisual {
            CalendarClosedNotchView(
                isCurrentDisplayIsland: isCurrentDisplayIsland,
                isCurrentScreenBuiltin: isCurrentScreenBuiltin
            )
            .transition(.opacity)
        } else if shouldShowNonMusicClosedVisual {
            if showCalendar {
                CalendarClosedNotchView(
                    isCurrentDisplayIsland: isCurrentDisplayIsland,
                    isCurrentScreenBuiltin: isCurrentScreenBuiltin
                )
                .transition(.opacity)
            } else if showNotHumanFace {
                MinimalFaceFeatures()
                    .frame(
                        width: isCurrentDisplayIsland ? 32 : getClosedNotchSize().width,
                        height: isCurrentDisplayIsland ? (isCurrentScreenBuiltin ? 24 : 18) : vm.effectiveClosedNotchHeight,
                        alignment: .center
                    )
                    .transition(.opacity)
            } else if showMirror {
                CameraPreviewView(webcamManager: .shared)
                    .frame(
                        width: isCurrentDisplayIsland ? 32 : getClosedNotchSize().width,
                        height: isCurrentDisplayIsland ? (isCurrentScreenBuiltin ? 24 : 18) : vm.effectiveClosedNotchHeight,
                        alignment: .center
                    )
                    .transition(.opacity)
            }
        } else if !coordinator.expandingView.show && vm.notchState == .closed && (!musicManager.isPlaying && musicManager.isPlayerIdle) && Defaults[.showNotHumanFace] && !vm.hideOnClosed {
            boringFaceAnimation
        } else if vm.notchState == .open {
            EmptyView()
        } else {
            Rectangle().fill(.clear).frame(width: vm.closedNotchSize.width - 20, height: vm.effectiveClosedNotchHeight)
        }

        if coordinator.sneakPeek.show {
            if (coordinator.sneakPeek.type != .music) && (coordinator.sneakPeek.type != .battery) && !isShowingSystemToastHUD && vm.notchState == .closed {
                SystemEventIndicatorModifier(
                    eventType: $coordinator.sneakPeek.type,
                    value: $coordinator.sneakPeek.value,
                    icon: $coordinator.sneakPeek.icon,
                    sendEventBack: { newVal in
                        switch coordinator.sneakPeek.type {
                        case .volume:
                            VolumeManager.shared.setAbsolute(Float32(newVal))
                        case .brightness:
                            BrightnessManager.shared.setAbsolute(value: Float32(newVal))
                        default:
                            break
                        }
                    }
                )
                .padding(.bottom, 10)
                .padding(.leading, 4)
                .padding(.trailing, 8)
            }
        }
    }

    private var boringFaceAnimation: some View {
        HStack {
            HStack {
                Rectangle()
                    .fill(.clear)
                    .frame(
                        width: max(0, vm.effectiveClosedNotchHeight - 12),
                        height: max(0, vm.effectiveClosedNotchHeight - 12)
                    )
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: isCurrentDisplayIsland ? 64 : (vm.closedNotchSize.width - 20))
                MinimalFaceFeatures()
            }
        }
        .frame(
            height: vm.effectiveClosedNotchHeight,
            alignment: .center
        )
    }

    // MARK: - Open Notch Content Routing

    @ViewBuilder
    private var openNotchContent: some View {
        VStack {
            switch coordinator.currentView {
            case .home, .calendar:
                NotchHomeView(albumArtNamespace: albumArtNamespace)
            case .shelf:
                shelfView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .transition(.opacity)
        .zIndex(1)
        .allowsHitTesting(vm.notchState == .open)
        .opacity(gestureProgress != 0 ? 1.0 - min(abs(gestureProgress) * 0.1, 0.3) : 1.0)
    }

    private var shelfView: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("Shelf")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Spacer(minLength: 0)

                Button(action: {
                    withAnimation(.smooth) {
                        coordinator.currentView = .home
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
            .padding(.horizontal, 8)

            ShelfView()
                .padding(.top, 4)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
