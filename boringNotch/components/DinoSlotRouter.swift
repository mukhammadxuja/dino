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
        ZStack(alignment: .top) {
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
                .transition(.opacity)
                .zIndex(2)
            }

            if vm.notchState == .open {
                openNotchContent
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], delegate: GeneralDropTargetDelegate(isTargeted: $vm.generalDropTargeting))
    }

    @ObservedObject private var dinoCoordinator = DinoCoordinator.shared

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
                isIsland: isCurrentDisplayIsland,
                isScreenBuiltin: isCurrentScreenBuiltin,
                type: $coordinator.sneakPeek.type,
                value: $coordinator.sneakPeek.value,
                icon: $coordinator.sneakPeek.icon,
                hoverAnimation: $isHovering,
                gestureProgress: $gestureProgress
            )
            .transition(.opacity)
        } else if isDualActivityActive || dinoCoordinator.isDualActivityActive {
            MusicLiveActivityView(
                isCurrentDisplayIsland: isCurrentDisplayIsland,
                isCurrentScreenBuiltin: isCurrentScreenBuiltin,
                isShowingMusicSneakPeek: isShowingMusicSneakPeek,
                mediaGestureDirection: mediaGestureDirection,
                mediaGestureIconVisible: mediaGestureIconVisible,
                coverRotationY: coverRotationY,
                albumArtNamespace: albumArtNamespace,
                isDualActivityActive: true,
                useMusicVisualizer: useMusicVisualizer,
                islandStyle: islandStyle,
                showCoverHoverMusicDetails: $showCoverHoverMusicDetails,
                coverHoverDismissTask: $coverHoverDismissTask,
                onOpenPomodoro: onOpenPomodoro
            )
            .frame(alignment: .center)
            .transition(.opacity)
        } else {
            switch dinoCoordinator.activeSlot {
            case .music:
                MusicLiveActivityView(
                    isCurrentDisplayIsland: isCurrentDisplayIsland,
                    isCurrentScreenBuiltin: isCurrentScreenBuiltin,
                    isShowingMusicSneakPeek: isShowingMusicSneakPeek,
                    mediaGestureDirection: mediaGestureDirection,
                    mediaGestureIconVisible: mediaGestureIconVisible,
                    coverRotationY: coverRotationY,
                    albumArtNamespace: albumArtNamespace,
                    isDualActivityActive: false,
                    useMusicVisualizer: useMusicVisualizer,
                    islandStyle: islandStyle,
                    showCoverHoverMusicDetails: $showCoverHoverMusicDetails,
                    coverHoverDismissTask: $coverHoverDismissTask,
                    onOpenPomodoro: onOpenPomodoro
                )
                .frame(alignment: .center)
                .transition(.opacity)

            case .pomodoro:
                PomodoroClosedNotchView(
                    isCurrentDisplayIsland: isCurrentDisplayIsland,
                    isCurrentScreenBuiltin: isCurrentScreenBuiltin
                )
                .transition(.opacity)

            case .calendar:
                CalendarClosedNotchView(
                    isCurrentDisplayIsland: isCurrentDisplayIsland,
                    isCurrentScreenBuiltin: isCurrentScreenBuiltin
                )
                .transition(.opacity)

            case .weather:
                WeatherClosedPillView()
                    .frame(
                        width: isCurrentDisplayIsland ? (isCurrentScreenBuiltin ? 120 : 105) : (vm.closedNotchSize.width + 10),
                        height: vm.effectiveClosedNotchHeight
                    )
                    .transition(.opacity)

            case .battery:
                BatteryClosedNotchLayoutView(isCurrentDisplayIsland: isCurrentDisplayIsland)
                    .transition(.opacity)

            case .idle, .shelf, .download, .webcam, .coding, .hud:
                if vm.notchState == .open {
                    EmptyView()
                } else {
                    Rectangle().fill(.clear).frame(width: vm.closedNotchSize.width - 20, height: vm.effectiveClosedNotchHeight)
                }
            }
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
            if dinoCoordinator.activeSlot == .webcam {
                mirrorView
            } else {
                switch coordinator.currentView {
                case .home, .calendar:
                    NotchHomeView(albumArtNamespace: albumArtNamespace)
                case .shelf:
                    shelfView
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .transition(.opacity)
        .zIndex(1)
        .allowsHitTesting(vm.notchState == .open)
        .opacity(gestureProgress != 0 ? 1.0 - min(abs(gestureProgress) * 0.1, 0.3) : 1.0)
    }

    private var mirrorView: some View {
        MirrorSlotView(isCurrentDisplayIsland: isCurrentDisplayIsland)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var shelfView: some View {
        ShelfView()
            .padding(.horizontal, 2)
            .padding(.top, 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
