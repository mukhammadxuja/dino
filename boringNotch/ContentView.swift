//
//  ContentView.swift
//  boringNotchApp
//
//  Created by Harsh Vardhan Goswami  on 02/08/24
//  Modified by Richard Kunkli on 24/08/2024.
//

import AVFoundation
import AppKit
import Combine
import Defaults
import KeyboardShortcuts
import SwiftUI
import SwiftUIIntrospect

@MainActor
private final class OpenFeatureStretchState: ObservableObject {
    @Published var amount: CGFloat = .zero
    @Published var closedScale: CGFloat = 1
    @Published var isInteracting = false
}

private struct OpenFeatureStretchView<Content: View>: View {
    @ObservedObject var stretch: OpenFeatureStretchState
    let content: Content

    var body: some View {
        content
            .scaleEffect(x: stretch.closedScale,
                         y: stretch.closedScale * (1 + stretch.amount * 0.04),
                         anchor: .top)
            .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.78), value: stretch.amount)
            .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.78), value: stretch.closedScale)
            // A trackpad can deliver more than 100 updates per second. During a
            // gesture, render the value directly instead of continually
            // retargeting a spring animation.
            .transaction { transaction in
                if stretch.isInteracting {
                    transaction.animation = nil
                }
            }
    }
}

@MainActor
private final class IslandMusicPeekPresentation: ObservableObject {
    enum Phase: Equatable {
        case idle, descending, presenting, collapsing, retracting, finished
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var generation = 0

    private let holdDuration: Duration
    private var trackID: String?
    private var dismissTask: Task<Void, Never>?

    init(holdDuration: Duration = .seconds(4.5)) {
        self.holdDuration = holdDuration
    }

    var isManaged: Bool { phase != .idle }
    var isRunning: Bool { phase != .idle && phase != .finished }
    var showsDetails: Bool { phase == .presenting }

    var visibility: Bool? {
        switch phase {
        case .idle: return nil
        case .descending, .presenting, .collapsing: return true
        case .retracting, .finished: return false
        }
    }

    func present(trackID: String) {
        guard self.trackID != trackID || !isRunning else { return }
        dismissTask?.cancel()
        self.trackID = trackID
        generation &+= 1
        if phase == .presenting {
            scheduleDismissal()
        } else {
            phase = .descending
        }
    }

    func didDescend(generation: Int) {
        guard self.generation == generation, phase == .descending else { return }
        withAnimation(.interactiveSpring(response: 0.42, dampingFraction: 0.88)) {
            phase = .presenting
        }
        scheduleDismissal()
    }

    func didRetract(generation: Int) {
        guard self.generation == generation, phase == .retracting else { return }
        phase = .finished
    }

    func cancel() {
        dismissTask?.cancel()
        dismissTask = nil
        trackID = nil
        generation &+= 1
        phase = .idle
    }

    private func scheduleDismissal() {
        let currentGeneration = generation
        dismissTask = Task { @MainActor [weak self, holdDuration] in
            do {
                try await Task.sleep(for: holdDuration)
            } catch {
                return
            }
            guard let self, self.generation == currentGeneration,
                  self.phase == .presenting else { return }
            // Keep the pill visible until its details have finished collapsing.
            withAnimation(.interactiveSpring(response: 0.42, dampingFraction: 0.88),
                          completionCriteria: .logicallyComplete) {
                self.phase = .collapsing
            } completion: {
                guard self.generation == currentGeneration,
                      self.phase == .collapsing else { return }
                self.phase = .retracting
            }
        }
    }
}

private struct IslandMusicPeekEvents: ViewModifier {
    let request: String?
    let trackID: String
    let canPresent: Bool
    let phase: IslandMusicPeekPresentation.Phase
    let onRequest: (String) -> Void
    let onUnavailable: () -> Void
    let onCollapse: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: request, initial: true) { _, request in
                if let request { onRequest(request) }
            }
            .onChange(of: trackID) { _, trackID in
                // Metadata is committed here; @Published emits before playback state is stored.
                if canPresent { onRequest(trackID) }
            }
            .onChange(of: canPresent) { _, canPresent in
                if !canPresent { onUnavailable() }
            }
            .onChange(of: phase) { _, phase in
                if phase == .collapsing { onCollapse() }
            }
    }
}

private struct ClosedIslandPresentation: Equatable {
    let isActive: Bool
    let isVisible: Bool
    let isMusicPeekDescending: Bool
    let musicPeekGeneration: Int
}

@MainActor
private struct ClosedIslandRevealView<Content: View>: View {
    let isActive: Bool
    let isVisible: Bool
    let isShowingHUD: Bool
    let isMusicPeekDescending: Bool
    let musicPeekGeneration: Int
    let hiddenOffsetY: CGFloat
    let onRevealComplete: (Int) -> Void
    let onRetractionComplete: (Int) -> Void
    let content: Content

    @State private var revealProgress: CGFloat = 0
    @State private var retractTask: Task<Void, Never>?

    private var presentation: ClosedIslandPresentation {
        .init(isActive: isActive, isVisible: isVisible,
              isMusicPeekDescending: isMusicPeekDescending,
              musicPeekGeneration: musicPeekGeneration)
    }

    var body: some View {
        content
            .offset(y: isActive ? -hiddenOffsetY * (1 - revealProgress) : 0)
            .opacity(isActive ? Double(revealProgress) : 1)
            .onAppear {
                updatePresentation(previous: nil)
            }
            .onChange(of: presentation) { previous, _ in
                updatePresentation(previous: previous)
            }
            .onDisappear {
                retractTask?.cancel()
            }
    }

    private func updatePresentation(previous: ClosedIslandPresentation?) {
        retractTask?.cancel()
        guard isActive else {
            revealProgress = 1
            return
        }
        let generation = musicPeekGeneration
        if isVisible {
            let startsMusicPeek = isMusicPeekDescending
                && previous?.musicPeekGeneration != generation
            guard previous?.isVisible != true || previous?.isActive != true || startsMusicPeek else { return }
            withAnimation(isShowingHUD ? HUDAnimations.presentation
                          : .interactiveSpring(response: 0.34, dampingFraction: 0.82),
                          completionCriteria: .logicallyComplete) {
                revealProgress = 1
            } completion: {
                onRevealComplete(generation)
            }
        } else if previous == nil {
            revealProgress = 0
        } else {
            retractTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled else { return }
                withAnimation(.interactiveSpring(response: 0.86, dampingFraction: 0.9),
                              completionCriteria: .logicallyComplete) {
                    revealProgress = 0
                } completion: {
                    onRetractionComplete(generation)
                }
            }
        }
    }
}

private struct IslandRevealTargetView: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let yOffset: CGFloat
    let highlightsOnHover: Bool
    @Binding var isHovered: Bool
    let onHoverChanged: (Bool) -> Void
    let onTap: () -> Void

    private var feedbackOpacity: Double {
        highlightsOnHover && isHovered ? 0.18 : 0
    }

    var body: some View {
        Color.black.opacity(0.001)
            .frame(width: width, height: height)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(feedbackOpacity))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(feedbackOpacity > 0 ? 0.22 : 0), lineWidth: 0.8)
                    }
            }
            .animation(.easeOut(duration: 0.16), value: isHovered)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .offset(y: yOffset)
            .onHover { hovering in
                isHovered = highlightsOnHover && hovering
                onHoverChanged(hovering)
            }
            .onTapGesture {
                isHovered = false
                onTap()
            }
    }
}

@MainActor
private struct NotchTuningUpdates: ViewModifier {
    @Default(.notchWidthAdjustment) private var widthAdjustment
    @Default(.notchHeightAdjustment) private var heightAdjustment
    let onSizeChanged: () -> Void
    let onPreviewChanged: (NotchTuningAxis?) -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: widthAdjustment) { _, _ in onSizeChanged() }
            .onChange(of: heightAdjustment) { _, _ in onSizeChanged() }
            .onReceive(NotchTuningPreviewState.shared.$activeAxis, perform: onPreviewChanged)
    }
}

@MainActor
struct ContentView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var coordinator = BoringViewCoordinator.shared

    private var musicManager: MusicManager { MusicManager.shared }
    private var pomodoroManager: PomodoroManager { PomodoroManager.shared }
    @State private var hoverTask: Task<Void, Never>?
    @State private var isHovering: Bool = false
    @State private var anyDropDebounceTask: Task<Void, Never>?
    @State private var openNotchHoverWatchdogTask: Task<Void, Never>?
    @State private var lastOpenedAt: Date = .distantPast

    @State private var openFeatureStretch = OpenFeatureStretchState()
    @State private var verticalGestureBeganClosed: Bool?
    @State private var verticalGestureDirection: PanDirection?
    @State private var verticalGestureReady = false
    @State private var isShowingMusicLyrics = false

    @State private var haptics: Bool = false

    // Horizontal gesture states for media control
    @State private var mediaGestureDirection: MediaGestureDirection = .none
    @State private var mediaGestureIconVisible: Bool = false
    @State private var mediaGestureTask: Task<Void, Never>?
    @State private var mediaGestureReady = false
    @State private var lastPreviousGestureAt: Date = .distantPast
    
    // Hover states for closed notch music areas
    @State private var showCoverHoverMusicDetails: Bool = false
    @State private var coverHoverDismissTask: Task<Void, Never>?
    @StateObject private var islandMusicPeek = IslandMusicPeekPresentation()
    @State private var coverRotationY: Double = 0

    @Namespace var albumArtNamespace

    @Default(.useMusicVisualizer) var useMusicVisualizer
    @Default(.pomodoroEnabled) var pomodoroEnabled
    @Default(.pomodoroClosedNotchDisplayMode) var pomodoroClosedNotchDisplayMode
    @Default(.showMirror) var showMirror
    @Default(.showNotHumanFace) var showNotHumanFace
    @Default(.showCalendar) var showCalendar
    @Default(.activeModule) var activeModule
    @Default(.gestureCycleFeatures) private var gestureCycleFeatures
    
    @State private var emptyClickBounce: Bool = false
    @State private var isScaleHovered: Bool = false
    @State private var scaleHoverTask: Task<Void, Never>?
    @State private var idleBounceTask: Task<Void, Never>?
    @State private var idleBounceWorkItem: DispatchWorkItem?
    @State private var isIslandClickedDown: Bool = false
    @State private var isIslandRevealTargetHovered: Bool = false
    @State private var islandRetractTask: Task<Void, Never>?
    
    // Displays & Island Mode
    @Default(.displaySelection) var displaySelection
    @Default(.builtinFormFactor) var builtinFormFactor
    @Default(.externalFormFactor) var externalFormFactor
    @Default(.islandStyle) var islandStyle
    @Default(.islandVisibility) var islandVisibility
    @Default(.displayShowOn) var displayShowOn

    // Shared interactive spring for movement/resizing to avoid conflicting animations
    private let animationSpring = Animation.interactiveSpring(response: 0.35, dampingFraction: 0.78, blendDuration: 0)

    private let extendedHoverPadding: CGFloat = 30
    private let zeroHeightHoverPadding: CGFloat = 10
    private let homeBaseOpenWidth: CGFloat = 385
    private let pomodoroReplaceWidthExpansion: CGFloat = 104

    private var currentTargetScreen: NSScreen? {
        if let uuid = vm.screenUUID {
            return NSScreen.screen(withUUID: uuid)
        }
        return NSScreen.main
    }

    private var isCurrentScreenBuiltin: Bool {
        if displaySelection == .builtin {
            return true
        } else if displaySelection == .external {
            return false
        } else {
            return currentTargetScreen?.isBuiltin ?? true
        }
    }

    private var isCurrentDisplayIsland: Bool {
        switch displaySelection {
        case .builtin:
            return builtinFormFactor == .island
        case .external:
            return externalFormFactor == .island
        case .both:
            return isCurrentScreenBuiltin ? (builtinFormFactor == .island) : (externalFormFactor == .island)
        }
    }

    private var islandCornerRadius: CGFloat {
        if vm.notchState == .open {
            return 36
        } else if isShowingMusicSneakPeek {
            return isCurrentScreenBuiltin ? 18 : 14
        } else {
            return isCurrentScreenBuiltin ? 18 : 14
        }
    }

    private var effectiveIslandVisibility: IslandVisibility {
        if isCurrentScreenBuiltin {
            return islandVisibility == .alwaysVisible ? .onHover : islandVisibility
        } else {
            return islandVisibility
        }
    }

    private var canPresentIslandMusicPeek: Bool {
        isCurrentDisplayIsland && effectiveIslandVisibility != .alwaysVisible
            && vm.notchState == .closed && !vm.hideOnClosed
            && Defaults[.enableSneakPeek]
            && musicManager.isPlaying && !musicManager.isPlayerIdle
            && !musicManager.songTitle.isEmpty
            && !isShowingSystemToastHUD && !isBatteryInlineAlertVisible
    }

    private var islandMusicPeekRequest: String? {
        guard canPresentIslandMusicPeek else { return nil }
        let standardRequest = coordinator.sneakPeek.show && coordinator.sneakPeek.type == .music
        let inlineRequest = coordinator.expandingView.show && coordinator.expandingView.type == .music
        guard standardRequest || inlineRequest else { return nil }
        return islandMusicTrackID
    }

    private var islandMusicTrackID: String {
        [Defaults[.sneakPeekStyles].rawValue, musicManager.artistName, musicManager.album, musicManager.songTitle]
            .joined(separator: "\u{0}")
    }

    private var isIslandMusicPeekManaged: Bool {
        isCurrentDisplayIsland && islandMusicPeek.isManaged
    }

    private var isIslandShowing: Bool {
        if isBatteryInlineAlertVisible || isShowingSystemToastHUD { return true }
        if isCurrentDisplayIsland, let visibility = islandMusicPeek.visibility { return visibility }
        if effectiveIslandVisibility == .alwaysVisible {
            return true
        }
        if effectiveIslandVisibility == .onClick {
            return isIslandClickedDown
        }
        return isHovering || isShowingMusicSneakPeek
    }

    private var isBatteryInlineAlertVisible: Bool {
        guard vm.notchState == .closed && coordinator.expandingView.show,
              !isShowingSystemToastHUD else { return false }
        if coordinator.expandingView.type == .charging || coordinator.expandingView.type == .unplugged {
            return true
        }
        // Low Power Mode is a transient HUD regardless of the user's regular
        // battery toast style, so it must participate in Island reveal/drop-down.
        if coordinator.expandingView.type == .battery,
           BatteryStatusViewModel.shared.lowPowerModeHUDState != nil {
            return true
        }
        return coordinator.expandingView.type == .battery
            && Defaults[.batteryToastType] == .dynamicNotch
    }

    private var centeredMenuBarOffset: CGFloat {
        let currentScreen = currentTargetScreen
        let menuBarHeight = max(24, (currentScreen?.frame.maxY ?? 0) - (currentScreen?.visibleFrame.maxY ?? 0))
        return max(2, (menuBarHeight - (isCurrentScreenBuiltin ? 33 : 24)) / 2)
    }

    private var dropDownOffset: CGFloat {
        let currentScreen = currentTargetScreen
        let physicalHeight = max(32, currentScreen?.safeAreaInsets.top ?? 38)
        let menuBarHeight = max(24, (currentScreen?.frame.maxY ?? 0) - (currentScreen?.visibleFrame.maxY ?? 0))
        return max(physicalHeight, menuBarHeight) + 8
    }

    private var islandYOffset: CGFloat {
        guard isCurrentDisplayIsland else { return 0 }

        if vm.notchState == .open {
            return isCurrentScreenBuiltin ? dropDownOffset : 8
        }

        // Power and system HUDs must always descend below a closed Island. This
        // keeps transient alerts visible even when the Island is configured to
        // stay at the menu bar while idle.
        if isCurrentScreenBuiltin && (isShowingSystemToastHUD || isBatteryInlineAlertVisible) {
            return dropDownOffset
        }

        if effectiveIslandVisibility == .alwaysVisible {
            return centeredMenuBarOffset
        } else {
            // Keep the closed island aligned below the menu bar for its spring reveal.
            return dropDownOffset
        }
    }

    private var islandOpacity: Double {
        guard isCurrentDisplayIsland else { return 1.0 }
        if vm.notchState == .open { return 1.0 }
        if effectiveIslandVisibility == .alwaysVisible { return 1.0 }
        return isIslandShowing ? 1.0 : 0.0
    }

    private var computedChinWidthAnimation: Animation {
        if isShowingInlineMusicPlaybackPeek {
            return isCurrentDisplayIsland
                ? .interactiveSpring(response: 0.34, dampingFraction: 0.84, blendDuration: 0)
                : .interactiveSpring(response: 0.46, dampingFraction: 0.9, blendDuration: 0)
        }
        if isShowingSystemToastHUD || isBatteryInlineAlertVisible {
            return HUDAnimations.presentation
        }
        return animationSpring
    }

    private var topCornerRadius: CGFloat {
        ((vm.notchState == .open) && Defaults[.cornerRadiusScaling])
            ? cornerRadiusInsets.opened.top
            : cornerRadiusInsets.closed.top
    }

    private var currentNotchShape: NotchShape {
        let defaultBottomRadius: CGFloat = {
            if DinoCoordinator.shared.activeSlot == .webcam && vm.notchState == .open {
                return 24
            }
            return ((vm.notchState == .open) && Defaults[.cornerRadiusScaling])
                ? cornerRadiusInsets.opened.bottom
                : cornerRadiusInsets.closed.bottom
        }()
        let bottomRadius = !isCurrentDisplayIsland && isShowingInlineMusicPlaybackPeek
            ? max(defaultBottomRadius, 22)
            : defaultBottomRadius
        return NotchShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomRadius
        )
    }



    private var isShowingMusicSneakPeek: Bool {
        if isIslandMusicPeekManaged {
            return islandMusicPeek.showsDetails
        }
        return (showCoverHoverMusicDetails || (coordinator.sneakPeek.show && coordinator.sneakPeek.type == .music))
            && musicManager.isPlaying
            && !musicManager.isPlayerIdle
            && !musicManager.songTitle.isEmpty
            && Defaults[.enableSneakPeek]
            && vm.notchState == .closed
            && !vm.hideOnClosed
            && (Defaults[.sneakPeekStyles] == .standard || showCoverHoverMusicDetails)
    }

    private var isDualActivityEligible: Bool {
        (musicManager.isPlaying || !musicManager.isPlayerIdle)
            && pomodoroManager.hasActiveSession
            && !isAntigravityActive
            && !coordinator.expandingView.show
            && !vm.hideOnClosed
    }

    private var isDualActivityActive: Bool {
        vm.notchState == .closed && isDualActivityEligible
    }

    private var isShowingSystemToastHUD: Bool {
        (coordinator.sneakPeek.show || DinoCoordinator.shared.currentPriority == .p1Toast)
            && (coordinator.sneakPeek.type != .music)
            && (coordinator.sneakPeek.type != .battery)
            && vm.notchState == .closed
    }

    private var computedChinWidth: CGFloat {
        let activeSlot = DinoCoordinator.shared.activeSlot

        if isCurrentDisplayIsland {
            if isShowingInlineMusicPlaybackPeek {
                let coverWidth: CGFloat = isCurrentScreenBuiltin
                    ? (isShowingMusicSneakPeek ? 18 : 17)
                    : (isShowingMusicSneakPeek ? 18.5 : 18)
                return MusicLiveActivityView.inlineIslandWidth(
                    isBuiltIn: isCurrentScreenBuiltin,
                    songTitle: musicManager.songTitle,
                    artistName: musicManager.artistName,
                    coverWidth: coverWidth
                )
            } else if isBatteryInlineAlertVisible {
                return 236
            } else if isShowingSystemToastHUD {
                let type = coordinator.sneakPeek.type
                switch type {
                case .airPods:
                    return isCurrentScreenBuiltin ? 112 : 106
                case .volume, .brightness, .backlight:
                    return isCurrentScreenBuiltin ? 236 : 228
                case .camera, .mic, .micActivity, .screenRecord, .capsLock, .location, .charging, .unplugged:
                    return isCurrentScreenBuiltin ? 180 : 175
                case .updateAvailable:
                    return isCurrentScreenBuiltin ? 190 : 185
                default:
                    return isCurrentScreenBuiltin ? 180 : 175
                }
            } else if isShowingMusicSneakPeek {
                return isCurrentScreenBuiltin ? 176 : 152
            } else if isAntigravityActive {
                return isCurrentScreenBuiltin ? 190 : 160
            } else if isDualActivityActive || DinoCoordinator.shared.isDualActivityActive {
                return isCurrentScreenBuiltin ? 150 : 130
            }

            switch activeSlot {
            case .music:
                return isCurrentScreenBuiltin ? 150 : 130
            case .pomodoro:
                return isCurrentScreenBuiltin ? 172 : 144
            case .weather:
                return isCurrentScreenBuiltin ? 120 : 105
            case .calendar:
                return isCurrentScreenBuiltin ? 140 : 115
            case .battery:
                return 236
            case .idle, .shelf, .download, .webcam, .coding, .hud:
                return isCurrentScreenBuiltin ? 88 : 70
            }
        }

        var chinWidth: CGFloat = vm.closedNotchSize.width + (2 * topCornerRadius) + 8

        if isShowingInlineMusicPlaybackPeek {
            let coverWidth = max(0, vm.effectiveClosedNotchHeight - 12)
            return MusicLiveActivityView.inlineNotchWidth(
                cameraWidth: vm.closedNotchSize.width,
                coverWidth: coverWidth,
                songTitle: musicManager.songTitle,
                artistName: musicManager.artistName
            )
        }

        let showsBatteryStatusPill = coordinator.expandingView.show
            && !isShowingSystemToastHUD
            && vm.notchState == .closed
            && (coordinator.expandingView.type == .charging
                || coordinator.expandingView.type == .unplugged
                || (coordinator.expandingView.type == .battery && Defaults[.batteryToastType] == .dynamicNotch))

        if showsBatteryStatusPill {
            // Reserve the actual camera width between the left and right HUD wings.
            let batteryModel = BatteryStatusViewModel.shared
            let isPowerStatus = coordinator.expandingView.type == .charging || coordinator.expandingView.type == .unplugged
            let isChargingStatus = coordinator.expandingView.type == .charging
            let lowPowerModeState = batteryModel.lowPowerModeHUDState
            let percentage = isPowerStatus
                ? Int(batteryModel.levelBattery)
                : (batteryModel.lastAlertTriggered != nil ? batteryModel.alertPercentage : Int(batteryModel.levelBattery))
            let title = lowPowerModeState.map { "Low Power \($0 ? "On" : "Off")" } ?? (isPowerStatus
                ? (isChargingStatus ? "Charging" : "Unplugged")
                : (batteryModel.lastAlertTriggered.map { $0 == .lowBattery ? "Low Battery" : "Charged" }
                    ?? (batteryModel.levelBattery <= 20 ? "Low Battery" : "Charged")))
            chinWidth = BatteryAlertNotchContent.requiredWidth(
                cameraWidth: vm.closedNotchSize.width,
                title: title,
                percentage: percentage
            )
        } else if coordinator.expandingView.type == .battery && coordinator.expandingView.show
            && vm.notchState == .closed && !isShowingSystemToastHUD {
            chinWidth = 640
        } else if isShowingSystemToastHUD {
            let type = coordinator.sneakPeek.type
            if isCurrentScreenBuiltin {
                chinWidth = InlineHUD.requiredBuiltInNotchWidth(
                    cameraWidth: vm.closedNotchSize.width,
                    type: type
                )
            } else {
                chinWidth = InlineHUD.requiredExternalNotchWidth(
                    cameraWidth: vm.closedNotchSize.width,
                    type: type
                )
            }
        } else if isDualActivityActive || DinoCoordinator.shared.isDualActivityActive {
            if isCurrentDisplayIsland {
                chinWidth = isCurrentScreenBuiltin ? 150 : 130
            } else if isCurrentScreenBuiltin {
                chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 38)
            } else {
                chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 24)
            }
            if isShowingMusicSneakPeek {
                chinWidth += 32
            }
        } else {
            switch activeSlot {
            case .music:
                if isCurrentDisplayIsland {
                    chinWidth = isCurrentScreenBuiltin ? 150 : 130
                } else if isCurrentScreenBuiltin {
                    chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 38)
                } else {
                    chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 24)
                }
                if isShowingMusicSneakPeek && !isCurrentDisplayIsland {
                    chinWidth += 32
                }

            case .pomodoro:
                if isCurrentDisplayIsland {
                    chinWidth = isCurrentScreenBuiltin ? 172 : 144
                } else if isCurrentScreenBuiltin {
                    chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 40)
                } else {
                    chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 24)
                }

            case .weather:
                chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 20)

            case .calendar:
                chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 24)

            case .battery:
                chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 24)

            case .idle, .shelf, .download, .webcam, .coding, .hud:
                break
            }
        }

        return chinWidth
    }

    private var isAntigravityActive: Bool {
        ReleaseFeatures.code
            && Defaults[.codeActivityEnabled]
            && Defaults[.codeShowInClosedNotch]
            && ((coordinator.expandingView.type == .antigravity && coordinator.expandingView.show) || AntigravityManager.shared.isVisible)
            && AntigravityManager.shared.currentPhase != .idle
            && vm.notchState == .closed
    }

    private var desiredOpenNotchWidth: CGFloat {
        vm.expandedNotchSize(for: DinoCoordinator.shared.activeSlot, isIsland: isCurrentDisplayIsland).width
    }

    private var desiredOpenNotchHeight: CGFloat {
        vm.expandedNotchSize(for: DinoCoordinator.shared.activeSlot, isIsland: isCurrentDisplayIsland).height
    }

    private var calendarTabContentWidth: CGFloat {
        max(420, desiredOpenNotchWidth - 70)
    }

    private var shouldShowPomodoroClosedContent: Bool {
        vm.notchState == .closed
            && (pomodoroManager.hasActiveSession || activeModule == .pomodoro || DinoCoordinator.shared.activeSlot == .pomodoro)
            && !vm.hideOnClosed
    }

    private var shouldShowMusicClosedVisual: Bool {
        guard !isDualActivityActive else { return false }
        return (!coordinator.expandingView.show || coordinator.expandingView.type == .music)
            && vm.notchState == .closed
            && (musicManager.isPlaying || !musicManager.isPlayerIdle || isShowingMusicSneakPeek)
            && coordinator.musicLiveActivityEnabled
            && !vm.hideOnClosed
            && (activeModule != .pomodoro || isShowingMusicSneakPeek || !pomodoroManager.hasActiveSession)
    }

    private var shouldShowCalendarClosedVisual: Bool {
        ReleaseFeatures.calendar && showCalendar
            && activeModule == .calendar
            && vm.notchState == .closed
            && !vm.hideOnClosed
            && !isShowingMusicSneakPeek
            && !isAntigravityActive
            && !coordinator.expandingView.show
            && (!musicManager.isPlaying && musicManager.isPlayerIdle)
            && !pomodoroManager.hasActiveSession
    }

    private var shouldShowNonMusicClosedVisual: Bool {
        !coordinator.expandingView.show
            && vm.notchState == .closed
            && !vm.hideOnClosed
            && (!musicManager.isPlaying && musicManager.isPlayerIdle)
            && ((ReleaseFeatures.calendar && showCalendar) || showNotHumanFace || (ReleaseFeatures.mirror && showMirror))
    }

    private var hasActiveFeature: Bool {
        switch DinoCoordinator.shared.backgroundSlot {
        case .music, .pomodoro:
            return true
        default:
            return DinoCoordinator.shared.activeSlot == .shelf
                && Defaults[.openShelfByDefault]
                && !ShelfStateViewModel.shared.isEmpty
        }
    }

    private var isShowingInlineMusicPlaybackPeek: Bool {
        if isIslandMusicPeekManaged {
            return islandMusicPeek.showsDetails && Defaults[.sneakPeekStyles] == .inline
        }
        return Defaults[.sneakPeekStyles] == .inline
            && ((coordinator.expandingView.show && coordinator.expandingView.type == .music)
                || showCoverHoverMusicDetails)
    }

    private var shouldShowPomodoroInlineClosedVisual: Bool {
        guard shouldShowPomodoroClosedContent else { return false }
        guard !isDualActivityActive else { return false }
        guard !isShowingInlineMusicPlaybackPeek else { return false }
        guard !(coordinator.sneakPeek.show && coordinator.sneakPeek.type == .music) else { return false }
        return true
    }

    private func updateOpenNotchWidth(for slot: DinoSlot? = nil, animated: Bool = true) {
        guard vm.notchState == .open else { return }
        let targetSize = vm.expandedNotchSize(for: slot ?? DinoCoordinator.shared.activeSlot, isIsland: isCurrentDisplayIsland)
        let targetWidth = targetSize.width
        let targetHeight = targetSize.height
        guard abs(vm.notchSize.width - targetWidth) > 0.5 || abs(vm.notchSize.height - targetHeight) > 0.5 else { return }

        let applyChange = {
            vm.notchSize = .init(width: targetWidth, height: targetHeight)
        }

        if animated {
            withAnimation(animationSpring) {
                applyChange()
            }
        } else {
            applyChange()
        }
    }

    private func handleFormFactorAnimation() {
        withAnimation(.interactiveSpring(response: 0.44, dampingFraction: 0.80)) {
            vm.closedNotchSize = getClosedNotchSize(screenUUID: vm.screenUUID)
            if vm.notchState == .open {
                updateOpenNotchWidth()
            } else {
                vm.notchSize = vm.closedNotchSize
            }
        }
    }

    private func refreshClosedNotchTuning() {
        let size = getClosedNotchSize(screenUUID: vm.screenUUID)
        guard vm.closedNotchSize != size else { return }
        vm.closedNotchSize = size
        if vm.notchState == .closed {
            vm.notchSize = size
        }
    }

    private func handleNotchTuningPreviewChange(_ axis: NotchTuningAxis?) {
        if axis != nil && vm.notchState == .open && !isCurrentDisplayIsland {
            closeWithSpring()
        }
    }

    @ViewBuilder
    private var islandRevealTarget: some View {
        if isCurrentDisplayIsland && vm.notchState == .closed && !isIslandShowing && !vm.hideOnClosed {
            IslandRevealTargetView(
                width: max(88, computedChinWidth - 16),
                height: max(24, vm.effectiveClosedNotchHeight),
                cornerRadius: islandCornerRadius,
                yOffset: centeredMenuBarOffset,
                highlightsOnHover: effectiveIslandVisibility == .onClick,
                isHovered: $isIslandRevealTargetHovered,
                onHoverChanged: { hovering in
                    if effectiveIslandVisibility == .onHover {
                        handleHover(hovering)
                    }
                },
                onTap: {
                    islandMusicPeek.cancel()
                    withAnimation(animationSpring) {
                        isIslandClickedDown = true
                        isHovering = true
                    }
                }
            )
            .zIndex(10)
            .allowsHitTesting(!isIslandShowing && vm.notchState == .closed)
        }
    }

    private func presentIslandMusicPeek(trackID: String) {
        hoverTask?.cancel()
        islandRetractTask?.cancel()
        coverHoverDismissTask?.cancel()
        islandMusicPeek.present(trackID: trackID)
    }

    private func shouldCloseOpenNotchAfterSharing() -> Bool {
        let batteryPopoverIsInactive = !vm.isBatteryPopoverActive
        let pointerIsOutside = !isHovering
        let notchIsOpen = vm.notchState == .open
        let sharingAllowsClose = !SharingStateManager.shared.preventNotchClose
        return batteryPopoverIsInactive && pointerIsOutside && notchIsOpen && sharingAllowsClose
    }

    var body: some View {
        ZStack(alignment: .top) {
            islandRevealTarget

            if isCurrentDisplayIsland && isIslandShowing && vm.notchState == .closed
                && effectiveIslandVisibility != .alwaysVisible && !vm.hideOnClosed {
                // Continuous vertical hover bridge from menubar down to dropped island
                Color.clear
                    .frame(
                        width: max(220, max(vm.closedNotchSize.width, computedChinWidth) + 40),
                        height: dropDownOffset + 8
                    )
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        handleHover(hovering)
                    }
                    .onTapGesture {
                        handleTap()
                    }
                    .zIndex(0)
            }

            VStack(spacing: 0) {
                if isCurrentDisplayIsland {
                    Spacer()
                        .frame(height: max(0, islandYOffset))
                }

                ClosedIslandRevealView(
                    isActive: isCurrentDisplayIsland && vm.notchState == .closed,
                    isVisible: isIslandShowing,
                    isShowingHUD: isShowingSystemToastHUD || isBatteryInlineAlertVisible,
                    isMusicPeekDescending: islandMusicPeek.phase == .descending,
                    musicPeekGeneration: islandMusicPeek.generation,
                    hiddenOffsetY: max(islandYOffset, 0) + max(vm.effectiveClosedNotchHeight, 44) + 72,
                    onRevealComplete: { islandMusicPeek.didDescend(generation: $0) },
                    onRetractionComplete: { islandMusicPeek.didRetract(generation: $0) },
                    content: OpenFeatureStretchView(
                        stretch: openFeatureStretch,
                        content: islandContainerView.frame(
                            width: vm.notchState == .open ? vm.notchSize.width : nil,
                            height: vm.notchState == .open ? vm.notchSize.height : nil,
                            alignment: .top
                        )
                    )
                )
                    .scaleEffect(
                        x: emptyClickBounce ? 0.94 : ((isScaleHovered && vm.notchState == .closed) ? 1.02 : 1.0),
                        y: emptyClickBounce ? 0.94 : 1.0,
                        anchor: .top
                    )
                    .offset(y: min(0, islandYOffset))
                    .opacity(
                        vm.notchState == .closed && vm.hideOnClosed
                            ? 0
                            : (isCurrentDisplayIsland ? 1 : islandOpacity)
                    )
                    .allowsHitTesting(
                        (isIslandShowing || vm.notchState == .open || !isCurrentDisplayIsland)
                        && (!vm.hideOnClosed || vm.notchState == .open)
                    )
                    .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.82), value: isScaleHovered)
                    .animation(.interactiveSpring(response: 0.42, dampingFraction: 0.80), value: isHovering)
                    .animation(.interactiveSpring(response: 0.44, dampingFraction: 0.82), value: islandYOffset)
                    .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.84), value: islandOpacity)
                    .conditionalModifier(true) { view in
                        let openAnimation = Animation.interactiveSpring(response: 0.36, dampingFraction: 0.68, blendDuration: 0)
                        let closeAnimation = Animation.interactiveSpring(response: 0.38, dampingFraction: 0.74, blendDuration: 0)
                        
                        return view
                            .animation(vm.notchState == .open ? openAnimation : closeAnimation, value: vm.notchState)
                            .animation(vm.notchState == .open ? openAnimation : closeAnimation, value: vm.notchSize)
                            .animation(computedChinWidthAnimation, value: computedChinWidth)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: islandCornerRadius, style: .continuous))
                    .onHover { hovering in
                        handleHover(hovering)
                    }
                    .onPreferenceChange(MusicLyricsPresentationKey.self) { isShowingMusicLyrics = $0 }
                    .conditionalModifier(Defaults[.enableGestures]) { view in
                        view
                            .verticalSwipeGesture(isEnabled: !isShowingMusicLyrics && !vm.isHoveringCalendar) { translation, direction, phase, isPrecise in
                                handleVerticalGesture(
                                    translation: translation,
                                    direction: direction,
                                    phase: phase,
                                    isPrecise: isPrecise
                                )
                            }
                            .horizontalSwipeGesture { translation, direction, phase, isPrecise in
                                handleHorizontalGesture(translation: translation, phase: phase, direction: direction, isPrecise: isPrecise)
                            }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .sharingDidFinish)) { _ in
                        if vm.notchState == .open && !isHovering && !vm.isBatteryPopoverActive {
                            hoverTask?.cancel()
                            hoverTask = Task {
                                try? await Task.sleep(for: .milliseconds(100))
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    if self.vm.notchState == .open && !self.isHovering && !self.vm.isBatteryPopoverActive && !SharingStateManager.shared.preventNotchClose {
                                        self.closeWithSpring()
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: vm.notchState) { _, newState in
                        showCoverHoverMusicDetails = false
                        coordinator.toggleSneakPeek(status: false, type: .music, duration: 0)
                        if newState == .open {
                            lastOpenedAt = Date()
                            startOpenNotchWatchdog()
                        } else {
                            vm.isHoveringCalendar = false
                            openFeatureStretch.amount = .zero
                            openFeatureStretch.isInteracting = false
                            verticalGestureBeganClosed = nil
                            verticalGestureDirection = nil
                            verticalGestureReady = false
                            openNotchHoverWatchdogTask?.cancel()
                            openNotchHoverWatchdogTask = nil
                        }
                    }
                    .onChange(of: vm.hideOnClosed) { _, shouldHide in
                        if shouldHide && vm.notchState == .open {
                            closeWithSpring()
                        }
                    }
                    .onChange(of: coordinator.currentView) { _, _ in
                        updateOpenNotchWidth()
                    }
                    .onChange(of: pomodoroEnabled) { _, _ in
                        updateOpenNotchWidth()
                    }
                    .onChange(of: showMirror) { _, _ in
                        updateOpenNotchWidth()
                    }
                    .onChange(of: vm.isCameraExpanded) { _, _ in
                        updateOpenNotchWidth()
                    }
                    .onReceive(DinoCoordinator.shared.$activeSlot) { slot in
                        // @Published emits before activeSlot's stored value changes.
                        if slot != .calendar {
                            vm.isHoveringCalendar = false
                        }
                        updateOpenNotchWidth(for: slot)
                    }
                    .onChange(of: builtinFormFactor) { _, _ in
                        handleFormFactorAnimation()
                    }
                    .onChange(of: externalFormFactor) { _, _ in
                        handleFormFactorAnimation()
                    }
                    .modifier(NotchTuningUpdates(
                        onSizeChanged: refreshClosedNotchTuning,
                        onPreviewChanged: handleNotchTuningPreviewChange
                    ))
                    .onReceive(MusicManager.shared.$songTitle) { newTitle in
                        guard !newTitle.isEmpty,
                              musicManager.isPlaying,
                              !musicManager.isPlayerIdle else { return }
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                            coverRotationY -= 180
                        }
                        if Defaults[.enableSneakPeek]
                            && vm.notchState == .closed && !vm.hideOnClosed
                            && Defaults[.sneakPeekStyles] == .standard
                            && (!isCurrentDisplayIsland || effectiveIslandVisibility == .alwaysVisible) {
                            coordinator.toggleSneakPeek(status: true, type: .music, duration: 4.5)
                        }
                    }
                    .onReceive(MusicManager.shared.$isPlaying) { _ in }
                    .onReceive(MusicManager.shared.$isPlayerIdle) { _ in }
                    .onReceive(PomodoroManager.shared.$state) { _ in }
                    .modifier(IslandMusicPeekEvents(
                        request: islandMusicPeekRequest,
                        trackID: islandMusicTrackID,
                        canPresent: canPresentIslandMusicPeek,
                        phase: islandMusicPeek.phase,
                        onRequest: presentIslandMusicPeek,
                        onUnavailable: {
                            if islandMusicPeek.isManaged { islandMusicPeek.cancel() }
                        },
                        onCollapse: {
                            coverHoverDismissTask?.cancel()
                            showCoverHoverMusicDetails = false
                        }
                    ))
                    .onChange(of: vm.isBatteryPopoverActive) {
                        if shouldCloseOpenNotchAfterSharing() {
                            hoverTask?.cancel()
                            hoverTask = Task {
                                try? await Task.sleep(for: .milliseconds(100))
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    if self.shouldCloseOpenNotchAfterSharing() {
                                        self.closeWithSpring()
                                    }
                                }
                            }
                        }
                    }
                    .sensoryFeedback(.alignment, trigger: haptics)
                    .contextMenu {
                        Button("Settings") {
                            SettingsWindowController.shared.showWindow()
                        }
                        .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
                        //                    Button("Edit") { // Doesnt work....
                        //                        let dn = DynamicNotch(content: EditPanelView())
                        //                        dn.toggle()
                        //                    }
                        //                    .keyboardShortcut("E", modifiers: .command)
                    }
                if vm.chinHeight > 0 && (!vm.hideOnClosed || vm.notchState == .open) {
                    Rectangle()
                        .fill(Color.black.opacity(0.01))
                        .frame(width: computedChinWidth, height: vm.chinHeight)
                }
            }
            .zIndex(2)

            if !vm.hideOnClosed || vm.notchState == .open {
                CustomBatteryToastOverlay()
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: windowSize.width, maxHeight: windowSize.height, alignment: .top)
        .compositingGroup()
        .background(dragDetector)
        .preferredColorScheme(.dark)
        .environmentObject(vm)
        .onDisappear {
            islandMusicPeek.cancel()
        }
        .onChange(of: vm.anyDropZoneTargeting) { _, isTargeted in
            anyDropDebounceTask?.cancel()

            if isTargeted {
                if vm.notchState == .closed {
                    DinoCoordinator.shared.selectView(.shelf)
                    doOpen()
                }
                return
            }

            anyDropDebounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }

                if vm.dropEvent {
                    vm.dropEvent = false
                    return
                }

                vm.dropEvent = false
                if !SharingStateManager.shared.preventNotchClose {
                    closeWithSpring()
                }
            }
        }
    }

    @ViewBuilder
    private var islandContainerView: some View {
        IslandContainerLayout(
            isCurrentDisplayIsland: isCurrentDisplayIsland,
            isCurrentScreenBuiltin: isCurrentScreenBuiltin,
            islandStyle: islandStyle,
            isShowingMusicSneakPeek: isShowingMusicSneakPeek,
            isInlinePlaybackPeek: isShowingInlineMusicPlaybackPeek,
            isDualActivityActive: isDualActivityActive,
            isHovering: isHovering,
            isScaleHovered: isScaleHovered,
            emptyClickBounce: emptyClickBounce,
            islandCornerRadius: islandCornerRadius,
            topCornerRadius: topCornerRadius,
            currentNotchShape: currentNotchShape,
            islandYOffset: islandYOffset,
            islandOpacity: islandOpacity,
            pomodoroEnabled: pomodoroEnabled,
            pomodoroClosedNotchDisplayMode: pomodoroClosedNotchDisplayMode,
            shouldShowPomodoroInlineClosedVisual: shouldShowPomodoroInlineClosedVisual,
            animationSpring: animationSpring,
            onMainPillHover: { hovering in
                handleMainPillHover(hovering)
            },
            onHover: { hovering in
                handleHover(hovering)
            },
            onMainPillTap: {
                if isDualActivityActive && vm.notchState == .closed {
                    openMusicWithSpring()
                } else {
                    handleTap()
                }
            },
            onCompanionCircleTap: {
                openPomodoroWithSpring()
            }
        ) {
            DinoSlotRouter(
                isCurrentDisplayIsland: isCurrentDisplayIsland,
                isCurrentScreenBuiltin: isCurrentScreenBuiltin,
                computedChinWidth: computedChinWidth,
                isShowingMusicSneakPeek: isShowingMusicSneakPeek,
                isShowingSystemToastHUD: isShowingSystemToastHUD,
                inlinePlaybackPeekOverride: isIslandMusicPeekManaged ? isShowingInlineMusicPlaybackPeek : nil,
                isDualActivityActive: isDualActivityActive,
                isAntigravityActive: isAntigravityActive,
                shouldShowPomodoroInlineClosedVisual: shouldShowPomodoroInlineClosedVisual,
                shouldShowMusicClosedVisual: shouldShowMusicClosedVisual,
                shouldShowCalendarClosedVisual: shouldShowCalendarClosedVisual,
                shouldShowNonMusicClosedVisual: shouldShowNonMusicClosedVisual,
                mediaGestureDirection: mediaGestureDirection,
                mediaGestureIconVisible: mediaGestureIconVisible,
                coverRotationY: coverRotationY,
                albumArtNamespace: albumArtNamespace,
                useMusicVisualizer: useMusicVisualizer,
                islandStyle: islandStyle,
                showCalendar: showCalendar,
                showNotHumanFace: showNotHumanFace,
                showMirror: ReleaseFeatures.mirror && showMirror,
                isHovering: $isHovering,
                showCoverHoverMusicDetails: $showCoverHoverMusicDetails,
                coverHoverDismissTask: $coverHoverDismissTask,
                onOpenPomodoro: {
                    openPomodoroWithSpring()
                }
            )
            .environmentObject(vm)
        }
    }


    @ViewBuilder
    var dragDetector: some View {
        if Defaults[.boringShelf] && vm.notchState == .closed && !vm.hideOnClosed {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], isTargeted: $vm.dragDetectorTargeting) { providers in
            vm.dropEvent = true
            ShelfStateViewModel.shared.load(providers)
            return true
        }
        } else {
            EmptyView()
        }
    }

    private func openMusicWithSpring() {
        islandRetractTask?.cancel()
        islandRetractTask = nil
        hoverTask?.cancel()
        isHovering = true
        isIslandClickedDown = true
        if Defaults[.enableHaptics] {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            haptics.toggle()
        }
        lastOpenedAt = Date()
        showCoverHoverMusicDetails = false
        coordinator.toggleSneakPeek(status: false, type: .music, duration: 0)
        withAnimation(animationSpring) {
            DinoCoordinator.shared.activateSlotDirectly(.music)
            let targetSize = CGSize(width: desiredOpenNotchWidth, height: desiredOpenNotchHeight)
            vm.open(targetSize: targetSize)
        }
    }

    private func openPomodoroWithSpring() {
        islandRetractTask?.cancel()
        islandRetractTask = nil
        hoverTask?.cancel()
        isHovering = true
        isIslandClickedDown = true
        if Defaults[.enableHaptics] {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            haptics.toggle()
        }
        lastOpenedAt = Date()
        showCoverHoverMusicDetails = false
        coordinator.toggleSneakPeek(status: false, type: .music, duration: 0)
        withAnimation(animationSpring) {
            DinoCoordinator.shared.activateSlotDirectly(.pomodoro)
            Defaults[.pomodoroEnabled] = true
            let targetSize = CGSize(width: desiredOpenNotchWidth, height: desiredOpenNotchHeight)
            vm.open(targetSize: targetSize)
        }
    }

    private func handleMainPillHover(_ hovering: Bool) {
        if coordinator.firstLaunch { return }
        coverHoverDismissTask?.cancel()

        if hovering {
            islandRetractTask?.cancel()
            scaleHoverTask?.cancel()
            withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.82)) {
                isScaleHovered = true
            }
            let wasNotHovering = !isHovering
            withAnimation(animationSpring) {
                isHovering = true
            }

            if wasNotHovering && Defaults[.enableHaptics] {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                haptics.toggle()
            }

            // Show music sneak peek (song title & artist) only if not in dual activity
            if !MusicManager.shared.isPlayerIdle && !isDualActivityActive && !islandMusicPeek.isRunning {
                withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.78)) {
                    showCoverHoverMusicDetails = true
                }
            }

            guard vm.notchState == .closed,
                  !islandMusicPeek.isRunning,
                  effectiveIslandVisibility != .onClick,
                  Defaults[.openNotchOnHover] else { return }

            hoverTask?.cancel()
            hoverTask = Task {
                try? await Task.sleep(for: .seconds(Defaults[.minimumHoverDuration]))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self.vm.notchState == .closed, self.isHovering else { return }
                    self.openMusicWithSpring()
                }
            }
        } else {
            scaleHoverTask?.cancel()
            scaleHoverTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.82)) {
                    self.isScaleHovered = false
                }
            }

            hoverTask?.cancel()
            coverHoverDismissTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.78)) {
                    self.showCoverHoverMusicDetails = false
                }
            }
        }
    }

    private func triggerIdleBounce() {
        idleBounceTask?.cancel()
        idleBounceWorkItem?.cancel()
        withAnimation(.interactiveSpring(response: 0.14, dampingFraction: 0.55, blendDuration: 0)) {
            emptyClickBounce = true
        }
        let workItem = DispatchWorkItem {
            withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.50, blendDuration: 0)) {
                self.emptyClickBounce = false
            }
        }
        idleBounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
    }

    private var availableIdleClickAction: IdleClickAction {
        let action = Defaults[.idleClickAction]
        if action == .weather || (!ReleaseFeatures.calendar && action == .calendar) {
            return .none
        }
        return action
    }

    private func handleTap() {
        if vm.notchState == .open {
            return
        }
        if hasActiveFeature {
            if isDualActivityActive || DinoCoordinator.shared.isDualActivityActive {
                if DinoCoordinator.shared.activeSlot == .pomodoro {
                    openPomodoroWithSpring()
                } else {
                    openMusicWithSpring()
                }
                return
            } else {
                switch DinoCoordinator.shared.backgroundSlot {
                case .pomodoro:
                    openPomodoroWithSpring()
                    return
                case .music:
                    openMusicWithSpring()
                    return
                default:
                    if DinoCoordinator.shared.activeSlot == .shelf {
                        DinoCoordinator.shared.activateSlotDirectly(.shelf)
                    } else {
                        DinoCoordinator.shared.selectView(.home)
                    }
                }
            }
            doOpen()
        } else {
            switch availableIdleClickAction {
            case .none:
                triggerIdleBounce()
            case .music:
                openMusicWithSpring()
            case .pomodoro:
                openPomodoroWithSpring()
            case .shelf:
                DinoCoordinator.shared.activateSlotDirectly(.shelf)
                doOpen()
            case .weather:
                DinoCoordinator.shared.activateSlotDirectly(.weather)
                doOpen()
            case .calendar:
                if ReleaseFeatures.calendar {
                    DinoCoordinator.shared.activateSlotDirectly(.calendar)
                    doOpen()
                } else {
                    triggerIdleBounce()
                }
            }
        }
    }

    private func doOpen() {
        islandRetractTask?.cancel()
        islandRetractTask = nil
        hoverTask?.cancel()
        isHovering = true
        isIslandClickedDown = true
        lastOpenedAt = Date()
        showCoverHoverMusicDetails = false
        coordinator.toggleSneakPeek(status: false, type: .music, duration: 0)
        let targetSize = CGSize(width: desiredOpenNotchWidth, height: desiredOpenNotchHeight)
        withAnimation(animationSpring) {
            vm.open(targetSize: targetSize)
        }
    }

    private func closeWithSpring() {
        let closeAnimation = Animation.interactiveSpring(response: 0.38, dampingFraction: 0.74, blendDuration: 0)
        withAnimation(closeAnimation) {
            showCoverHoverMusicDetails = false
            coordinator.toggleSneakPeek(status: false, type: .music, duration: 0)
            vm.close()
        }

        if isCurrentDisplayIsland && effectiveIslandVisibility != .alwaysVisible {
            islandRetractTask?.cancel()
            islandRetractTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
                if self.vm.notchState == .closed {
                    withAnimation(self.animationSpring) {
                        self.isHovering = false
                        self.isIslandClickedDown = false
                        self.showCoverHoverMusicDetails = false
                    }
                }
            }
        }
    }

    // MARK: - Open Notch Watchdog & Hover Safety

    private func isMouseInsideOpenNotch() -> Bool {
        guard let screen = currentTargetScreen else { return false }
        let mouseLoc = NSEvent.mouseLocation
        let screenFrame = screen.frame
        let notchWidth = max(vm.notchSize.width, 385) + 30
        let notchHeight = vm.notchSize.height + (isCurrentDisplayIsland ? 70 : 30)
        let notchRect = CGRect(
            x: screenFrame.midX - notchWidth / 2,
            y: screenFrame.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight
        )
        return NSMouseInRect(mouseLoc, notchRect, false)
    }

    private func startOpenNotchWatchdog() {
        openNotchHoverWatchdogTask?.cancel()
        openNotchHoverWatchdogTask = Task { @MainActor in
            // Initial grace period: allow opening spring animation to settle before checking
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled && vm.notchState == .open else { return }

            while !Task.isCancelled && vm.notchState == .open {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled && vm.notchState == .open else { break }

                if SharingStateManager.shared.preventNotchClose || vm.isBatteryPopoverActive {
                    continue
                }

                if !isMouseInsideOpenNotch() {
                    let timeSinceOpen = Date().timeIntervalSince(self.lastOpenedAt)
                    let graceRemaining = max(0, 0.7 - timeSinceOpen)
                    let collapseDelay = max(0.35, Defaults[.collapseDelay])
                    let totalDelay = graceRemaining + collapseDelay

                    try? await Task.sleep(for: .seconds(totalDelay))
                    guard !Task.isCancelled && vm.notchState == .open else { break }

                    if !isMouseInsideOpenNotch() && !SharingStateManager.shared.preventNotchClose && !vm.isBatteryPopoverActive {
                        self.closeWithSpring()
                        break
                    }
                }
            }
        }
    }

    // MARK: - Hover Management

    private func handleHover(_ hovering: Bool) {
        if coordinator.firstLaunch { return }
        hoverTask?.cancel()
        
        if hovering {
            islandRetractTask?.cancel()
            scaleHoverTask?.cancel()
            withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.82)) {
                isScaleHovered = true
            }
            let wasNotHovering = !isHovering
            if wasNotHovering && islandMusicPeek.phase == .finished {
                islandMusicPeek.cancel()
            }
            withAnimation(animationSpring) {
                isHovering = true
            }
            
            if wasNotHovering && Defaults[.enableHaptics] {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                haptics.toggle()
            }

            if DinoCoordinator.shared.currentPriority == .p2OnDemand {
                DinoCoordinator.shared.pauseOnDemandDismiss()
            }
            
            guard vm.notchState == .closed,
                  !islandMusicPeek.isRunning,
                  effectiveIslandVisibility != .onClick,
                  !coordinator.sneakPeek.show,
                  hasActiveFeature,
                  Defaults[.openNotchOnHover] else { return }
            
            hoverTask = Task {
                try? await Task.sleep(for: .seconds(Defaults[.minimumHoverDuration]))
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    guard self.vm.notchState == .closed,
                          !self.islandMusicPeek.isRunning,
                          self.isHovering,
                          self.hasActiveFeature,
                          !self.coordinator.sneakPeek.show else { return }
                    
                    self.handleTap()
                }
            }
        } else {
            if DinoCoordinator.shared.currentPriority == .p2OnDemand {
                DinoCoordinator.shared.resumeOnDemandDismiss(timeout: 5.0)
            }
            scaleHoverTask?.cancel()
            scaleHoverTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.82)) {
                    self.isScaleHovered = false
                }
            }
            
            hoverTask = Task {
                let timeSinceOpen = Date().timeIntervalSince(self.lastOpenedAt)
                let graceRemaining = (self.vm.notchState == .open) ? max(0, 0.7 - timeSinceOpen) : 0
                let collapseDelay = max(0.35, Defaults[.collapseDelay])
                let totalDelay = graceRemaining + collapseDelay

                try? await Task.sleep(for: .seconds(totalDelay))
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    if self.vm.notchState == .open && !self.vm.isBatteryPopoverActive && !SharingStateManager.shared.preventNotchClose {
                        // 1. Morph open notch back to closed island pill with spring, then retract after delay
                        self.closeWithSpring()
                    } else {
                        withAnimation(self.animationSpring) {
                            self.isHovering = false
                            self.isIslandClickedDown = false
                            self.showCoverHoverMusicDetails = false
                        }
                    }
                    
                    if self.showCoverHoverMusicDetails {
                        self.coverHoverDismissTask?.cancel()
                        self.coverHoverDismissTask = Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(250))
                            guard !Task.isCancelled else { return }
                            if !self.isHovering {
                                withAnimation(self.animationSpring) {
                                    self.coordinator.toggleSneakPeek(status: false, type: .music, duration: 0.25)
                                    self.showCoverHoverMusicDetails = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Gesture Handling

    private func handleVerticalGesture(
        translation: CGFloat,
        direction: PanDirection,
        phase: NSEvent.Phase,
        isPrecise: Bool
    ) {
        if phase == .began {
            verticalGestureBeganClosed = vm.notchState == .closed
            verticalGestureDirection = direction
            verticalGestureReady = false
            openFeatureStretch.isInteracting = isPrecise
        }

        guard isPrecise else {
            if phase == .ended || phase == .cancelled {
                verticalGestureBeganClosed = nil
                verticalGestureDirection = nil
                verticalGestureReady = false
                openFeatureStretch.isInteracting = false
            }
            return
        }
        guard let beganClosed = verticalGestureBeganClosed else { return }
        let eligible: Bool
        if direction == .down {
            eligible = beganClosed
                ? vm.notchState == .closed
                : (vm.notchState == .open && !vm.isHoveringCalendar && canCycleOpenSlot)
        } else {
            eligible = !beganClosed && vm.notchState == .open
                && !vm.isHoveringCalendar
                && !SharingStateManager.shared.preventNotchClose
        }

        if phase == .ended || phase == .cancelled {
            let shouldCommit = phase == .ended && eligible && verticalGestureReady
                && verticalGestureDirection == direction
                && translation >= NotchGestureActivation.distance
            verticalGestureBeganClosed = nil
            verticalGestureDirection = nil
            verticalGestureReady = false
            openFeatureStretch.isInteracting = false
            withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.68)) {
                if openFeatureStretch.amount != .zero { openFeatureStretch.amount = .zero }
                if openFeatureStretch.closedScale != 1 { openFeatureStretch.closedScale = 1 }
            }
            if shouldCommit {
                if direction == .down {
                    if beganClosed {
                        handleTap()
                    } else {
                        advanceOpenFeature()
                    }
                } else {
                    closeWithSpring()
                }
            }
            return
        }

        if verticalGestureDirection != direction {
            verticalGestureDirection = direction
            verticalGestureReady = false
            if openFeatureStretch.amount != .zero { openFeatureStretch.amount = .zero }
            if openFeatureStretch.closedScale != 1 { openFeatureStretch.closedScale = 1 }
        }
        guard eligible else { return }
        let ready = translation >= NotchGestureActivation.distance
        if ready && !verticalGestureReady {
            performGestureHaptic()
        }
        if verticalGestureReady != ready { verticalGestureReady = ready }

        if direction == .down {
            if beganClosed {
                let progress = min(1, translation / NotchGestureActivation.distance)
                let isIdleNone = availableIdleClickAction == .none
                let scale = quantizedGestureValue(isIdleNone ? 1 - progress * 0.06 : 1 + progress * 0.04)
                if openFeatureStretch.closedScale != scale { openFeatureStretch.closedScale = scale }
            } else {
                let amount = quantizedGestureValue(min(1, translation / 50))
                if openFeatureStretch.amount != amount { openFeatureStretch.amount = amount }
            }
        } else {
            let scale = quantizedGestureValue(1 - min(1, translation / NotchGestureActivation.distance) * 0.04)
            if openFeatureStretch.closedScale != scale { openFeatureStretch.closedScale = scale }
        }
    }

    private func quantizedGestureValue(_ value: CGFloat) -> CGFloat {
        (value * 120).rounded() / 120
    }

    private var canCycleOpenSlot: Bool {
        let features = availableGestureFeatures
        return features.count > 1 || (features.count == 1 && features[0].slot != DinoCoordinator.shared.activeSlot)
    }

    private var availableGestureFeatures: [GestureCycleFeature] {
        var seen = Set<GestureCycleFeature>()
        return gestureCycleFeatures.filter { $0.isAvailable && seen.insert($0).inserted }
    }

    private func advanceOpenFeature() {
        let features = availableGestureFeatures
        guard !features.isEmpty else { return }
        let current = features.firstIndex { $0.slot == DinoCoordinator.shared.activeSlot }
        let next = current.map { ($0 + 1) % features.count } ?? 0
        DinoCoordinator.shared.activateSlotDirectly(features[next].slot)
    }

    private func performGestureHaptic() {
        if Defaults[.enableHaptics] {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    // MARK: - Horizontal Gesture Dispatcher

    private func handleHorizontalGesture(translation: CGFloat, phase: NSEvent.Phase, direction: PanDirection, isPrecise: Bool) {
        handleHorizontalMediaGesture(translation: translation, phase: phase, direction: direction, isPrecise: isPrecise)
    }

    // MARK: - Horizontal Media Gesture

    @State private var lastMediaSwipeTriggeredAt: Date = .distantPast

    private func handleHorizontalMediaGesture(translation: CGFloat, phase: NSEvent.Phase, direction: PanDirection, isPrecise: Bool) {
        let gestureDirection: MediaGestureDirection = direction == .right ? .right : .left
        if phase == .began {
            mediaGestureReady = false
            mediaGestureTask?.cancel()
        }
        let isMusicFeature = vm.notchState == .closed || DinoCoordinator.shared.activeSlot == .music
        guard isPrecise, isMusicFeature, musicManager.isPlaying, !musicManager.isPlayerIdle else {
            if phase == .ended || phase == .cancelled { clearMediaGesturePreview() }
            return
        }

        if phase == .ended || phase == .cancelled {
            let shouldCommit = phase == .ended && mediaGestureReady
                && translation >= NotchGestureActivation.distance
                && Date().timeIntervalSince(lastMediaSwipeTriggeredAt) > 0.45
            mediaGestureReady = false
            if shouldCommit {
                lastMediaSwipeTriggeredAt = Date()
                performMediaSwipe(gestureDirection)
                mediaGestureTask?.cancel()
                mediaGestureTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    guard !Task.isCancelled else { return }
                    clearMediaGesturePreview()
                }
            } else {
                clearMediaGesturePreview()
            }
            return
        }

        if mediaGestureDirection != gestureDirection {
            mediaGestureReady = false
        }
        let ready = translation >= NotchGestureActivation.distance
        if ready && !mediaGestureReady { performGestureHaptic() }
        if mediaGestureReady != ready { mediaGestureReady = ready }
        if mediaGestureDirection != gestureDirection || mediaGestureIconVisible != (translation > 8) {
            mediaGestureDirection = gestureDirection
            withAnimation(.easeOut(duration: 0.16)) {
                mediaGestureIconVisible = translation > 8
            }
        }
    }

    private func performMediaSwipe(_ direction: MediaGestureDirection) {
        if direction == .left {
            musicManager.nextTrack()
        } else {
            // Match the closed notch: a recent song restarts, a second swipe goes back.
            let now = Date()
            let wasRecentlyTriggered = now.timeIntervalSince(lastPreviousGestureAt) < 2.0
            lastPreviousGestureAt = now
            let actualElapsed = musicManager.elapsedTime
                + (musicManager.isPlaying ? max(0, now.timeIntervalSince(musicManager.timestampDate)) : 0)
            if actualElapsed > 3.0 && !wasRecentlyTriggered {
                musicManager.seek(to: 0)
            } else {
                musicManager.previousTrack()
            }
        }
    }

    private func clearMediaGesturePreview() {
        mediaGestureTask?.cancel()
        mediaGestureTask = nil
        withAnimation(.easeOut(duration: 0.2)) {
            mediaGestureIconVisible = false
        }
        mediaGestureDirection = .none
    }
}

struct FullScreenDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let onDrop: () -> Void

    func dropEntered(info _: DropInfo) {
        isTargeted = true
    }

    func dropExited(info _: DropInfo) {
        isTargeted = false
    }

    func performDrop(info _: DropInfo) -> Bool {
        isTargeted = false
        onDrop()
        return true
    }

}

struct GeneralDropTargetDelegate: DropDelegate {
    @Binding var isTargeted: Bool

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .cancel)
    }

    func performDrop(info: DropInfo) -> Bool {
        return false
    }
}

// MARK: - Isolated Battery Toast Overlay
@MainActor
struct CustomBatteryToastOverlay: View {
    @ObservedObject private var batteryModel = BatteryStatusViewModel.shared
    @EnvironmentObject private var vm: BoringViewModel
    @Default(.batteryToastEnabled) private var batteryToastEnabled
    @Default(.batteryToastType) private var batteryToastType

    var body: some View {
        Group {
            if batteryModel.isCustomToastPresented && batteryToastEnabled && batteryToastType == .customToast && vm.notchState == .closed && batteryModel.alertPosition != "Center" {
                CustomBatteryToastView()
                    .offset(y: vm.effectiveClosedNotchHeight + 14)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .scale(scale: 0.82, anchor: .top)).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .scale(scale: 0.88, anchor: .top)).combined(with: .opacity)
                        )
                    )
                    .zIndex(100)
            }
        }
        .animation(
            batteryModel.isCustomToastPresented
                ? .spring(response: 0.45, dampingFraction: 0.65)
                : .spring(response: 0.45, dampingFraction: 0.8),
            value: batteryModel.isCustomToastPresented
        )
    }
}

// MARK: - Isolated Battery Closed Notch View
@MainActor
struct BatteryClosedNotchLayoutView: View {
    @ObservedObject private var batteryModel = BatteryStatusViewModel.shared
    @EnvironmentObject private var vm: BoringViewModel
    @Default(.batteryToastType) private var batteryToastType

    let isCurrentDisplayIsland: Bool

    var body: some View {
        let lowPowerModeState = batteryModel.lowPowerModeHUDState

        if batteryToastType == .dynamicNotch {
            let tintColor: Color = lowPowerModeState == nil
                ? (batteryModel.activeGlowColor ?? (batteryModel.levelBattery <= 20 ? .red : .green))
                : .yellow
            let displayPercentage = batteryModel.lastAlertTriggered != nil ? batteryModel.alertPercentage : Int(batteryModel.levelBattery)
            let title = lowPowerModeState.map { "Low Power \($0 ? "On" : "Off")" }

            if isCurrentDisplayIsland {
                BatteryInlineAlertContent(
                    isLow: batteryModel.lastAlertTriggered.map { $0 == .lowBattery } ?? (batteryModel.levelBattery <= 20),
                    percentage: displayPercentage,
                    color: tintColor,
                    title: title
                )
                .frame(width: 220, height: vm.effectiveClosedNotchHeight)
            } else {
                BatteryAlertNotchContent(
                    title: title ?? (batteryModel.lastAlertTriggered.map { $0 == .lowBattery ? "Low Battery" : "Charged" }
                        ?? (batteryModel.levelBattery <= 20 ? "Low Battery" : "Charged")),
                    percentage: displayPercentage,
                    color: tintColor,
                    closedNotchWidth: vm.closedNotchSize.width,
                    height: vm.effectiveClosedNotchHeight
                )
                .frame(height: vm.effectiveClosedNotchHeight)
            }
        } else {
            HStack(spacing: 0) {
                HStack {
                    Text(lowPowerModeState.map { "Low Power \($0 ? "On" : "Off")" } ?? batteryModel.alertBannerText ?? batteryModel.statusText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                }

                Rectangle()
                    .fill(Color.clear)
                    .frame(width: isCurrentDisplayIsland ? 64 : (vm.closedNotchSize.width + 10))

                HStack {
                    BoringBatteryView(
                        batteryWidth: 30,
                        isCharging: batteryModel.isCharging,
                        isInLowPowerMode: lowPowerModeState ?? batteryModel.isInLowPowerMode,
                        isPluggedIn: batteryModel.isPluggedIn,
                        levelBattery: batteryModel.levelBattery,
                        isForNotification: true
                    )
                }
                .frame(width: 76, alignment: .trailing)
            }
            .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
        }
    }
}

struct BatteryInlineAlertContent: View {
    let isLow: Bool
    let percentage: Int
    let color: Color
    var compact = false
    var title: String? = nil

    private var level: CGFloat { CGFloat(min(100, max(0, percentage))) / 100 }

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            Text(title ?? (isLow ? "Low Battery" : "Charged"))
                .foregroundStyle(.white)
                .font(.system(size: compact ? 9 : 12, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: compact ? 7 : 16)
            Text("\(min(100, max(0, percentage)))%")
                .font(.system(size: compact ? 9 : 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(percentage)))
                .animation(.snappy(duration: 0.25), value: percentage)
                .foregroundStyle(color)
            HStack(spacing: 1) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: compact ? 3.5 : 5)
                            .fill(color.opacity(0.35))
                        Rectangle()
                            .fill(color)
                            .frame(width: level > 0 ? max(compact ? 3 : 4, geometry.size.width * level) : 0)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: compact ? 3.5 : 5))
                }
                .frame(width: compact ? 20 : 27, height: compact ? 10 : 13)
                RoundedRectangle(cornerRadius: 1)
                    .fill(color.opacity(0.65))
                    .frame(width: 2, height: compact ? 4 : 6)
                    .clipShape(RoundedRectangle(cornerRadius: compact ? 2 : 3))
            }
        }
        .padding(.horizontal, compact ? 7 : 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title ?? (isLow ? "Low Battery" : "Charged")), \(min(100, max(0, percentage))) percent")
    }
}

struct PowerStatusInlineHUD: View {
    @ObservedObject private var batteryModel = BatteryStatusViewModel.shared

    let isCharging: Bool
    let isCurrentDisplayIsland: Bool
    let height: CGFloat
    let width: CGFloat
    let closedNotchWidth: CGFloat

    private var percentage: Int { Int(batteryModel.levelBattery) }
    private var tint: Color { isCharging ? .green : .white }

    var body: some View {
        Group {
            if isCurrentDisplayIsland {
                BatteryInlineAlertContent(
                    isLow: false,
                    percentage: percentage,
                    color: tint,
                    title: isCharging ? "Charging" : "Unplugged"
                )
                .frame(width: 220, height: height)
            } else {
                BatteryAlertNotchContent(
                    title: isCharging ? "Charging" : "Unplugged",
                    percentage: percentage,
                    color: tint,
                    closedNotchWidth: closedNotchWidth,
                    height: height
                )
                .frame(width: width, height: height)
            }
        }
    }

}

struct BatteryAlertNotchContent: View {
    let title: String
    let percentage: Int
    let color: Color
    let closedNotchWidth: CGFloat
    let height: CGFloat

    private static let cameraClearance: CGFloat = 12
    private var level: CGFloat { CGFloat(min(100, max(0, percentage))) / 100 }
    private var contentWidth: CGFloat { Self.requiredWidth(cameraWidth: closedNotchWidth, title: title, percentage: percentage) }

    static func requiredWidth(cameraWidth: CGFloat, title: String, percentage: Int) -> CGFloat {
        let titleFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
        let percentageFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        let titleWidth = ceil((title as NSString).size(withAttributes: [.font: titleFont]).width)
        let percentageText = "\(min(100, max(0, percentage)))%"
        let percentageWidth = ceil((percentageText as NSString).size(withAttributes: [.font: percentageFont]).width)
        let sideContentWidth = titleWidth + percentageWidth + 5 + 30
        let sidePadding: CGFloat = 4
        return cameraWidth + cameraClearance + sideContentWidth + (sidePadding * 2)
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .contentTransition(.opacity)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.leading, 4)

            Rectangle()
                .fill(Color.clear)
                .frame(width: closedNotchWidth + Self.cameraClearance)

            HStack(spacing: 5) {
                Text("\(min(100, max(0, percentage)))%")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(color)
                    .fixedSize()

                HStack(spacing: 1) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(color.opacity(0.35))
                            Rectangle()
                                .fill(color)
                                .frame(width: max(3, geometry.size.width * level))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .frame(width: 27, height: 13)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color.opacity(0.65))
                        .frame(width: 2, height: 6)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.trailing, 4)
        }
        .frame(
            width: contentWidth,
            height: height
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(percentage) percent")
        .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.78), value: title)
        .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.78), value: percentage)
    }
}

// MARK: - Isolated Music Live Activity View
@MainActor
struct MusicLiveActivityView: View {
    @ObservedObject private var musicManager = MusicManager.shared
    @ObservedObject private var pomodoroManager = PomodoroManager.shared
    @ObservedObject private var coordinator = BoringViewCoordinator.shared
    @EnvironmentObject private var vm: BoringViewModel

    let isCurrentDisplayIsland: Bool
    let isCurrentScreenBuiltin: Bool
    let isShowingMusicSneakPeek: Bool
    let mediaGestureDirection: MediaGestureDirection
    let mediaGestureIconVisible: Bool
    let coverRotationY: Double
    var albumArtNamespace: Namespace.ID
    let isDualActivityActive: Bool
    let useMusicVisualizer: Bool
    let islandStyle: IslandStyle
    let inlinePlaybackPeekOverride: Bool?

    @Binding var showCoverHoverMusicDetails: Bool
    @Binding var coverHoverDismissTask: Task<Void, Never>?
    var onOpenPomodoro: (() -> Void)? = nil

    @State private var isVisualizerHovering: Bool = false
    @State private var isCoverHovering: Bool = false
    @State private var isSongDetailsHovered: Bool = false
    @State private var isPomodoroHovered: Bool = false
    @State private var showCopiedFeedback: Bool = false

    static func displaySongTitle(_ title: String) -> String {
        let letters = title.filter { $0.isLetter }
        guard !letters.isEmpty, letters.allSatisfy({ $0.isUppercase }) else { return title }
        return title.localizedCapitalized
    }

    static func inlineMusicMetadata(songTitle: String, artistName: String) -> String {
        let details = [artistName, displaySongTitle(songTitle)]
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
        return details.isEmpty ? "♪" : "♪ \(details)"
    }

    static func inlineNotchArtistWidth(_ artistName: String) -> CGFloat {
        guard !artistName.isEmpty else { return 0 }
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let measuredWidth = ceil((artistName as NSString).size(withAttributes: [.font: font]).width)
        return min(92, max(44, measuredWidth + 2))
    }

    static func inlineNotchSongWidth(_ songTitle: String) -> CGFloat {
        let title = displaySongTitle(songTitle)
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let measuredWidth = ceil((title as NSString).size(withAttributes: [.font: font]).width)
        return min(120, max(76, measuredWidth + 8))
    }

    static func inlineNotchWidth(
        cameraWidth: CGFloat,
        coverWidth: CGFloat,
        songTitle: String,
        artistName: String
    ) -> CGFloat {
        let artistWidth = inlineNotchArtistWidth(artistName)
        let leftWingWidth = coverWidth + (artistWidth > 0 ? 6 + artistWidth : 0)
        let rightWingWidth = inlineNotchSongWidth(songTitle) + 6 + min(20, coverWidth)
        return cameraWidth + (2 * max(leftWingWidth, rightWingWidth))
    }

    static func inlineIslandWidth(
        isBuiltIn: Bool,
        songTitle: String,
        artistName: String,
        coverWidth: CGFloat
    ) -> CGFloat {
        let maximumWidth: CGFloat = isBuiltIn ? 210 : 180
        let details = [artistName, displaySongTitle(songTitle)]
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
        let metadata = details.isEmpty ? "♪" : "♪ \(details)"
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let measuredMetadataWidth = ceil((metadata as NSString).size(withAttributes: [.font: font]).width)
        let rightContentWidth = max(56, measuredMetadataWidth + 4)
        return min(maximumWidth, coverWidth + 6 + rightContentWidth)
    }

    public init(
        isCurrentDisplayIsland: Bool,
        isCurrentScreenBuiltin: Bool,
        isShowingMusicSneakPeek: Bool,
        mediaGestureDirection: MediaGestureDirection,
        mediaGestureIconVisible: Bool,
        coverRotationY: Double,
        albumArtNamespace: Namespace.ID,
        isDualActivityActive: Bool,
        useMusicVisualizer: Bool,
        islandStyle: IslandStyle,
        inlinePlaybackPeekOverride: Bool? = nil,
        showCoverHoverMusicDetails: Binding<Bool>,
        coverHoverDismissTask: Binding<Task<Void, Never>?>,
        onOpenPomodoro: (() -> Void)? = nil
    ) {
        self.isCurrentDisplayIsland = isCurrentDisplayIsland
        self.isCurrentScreenBuiltin = isCurrentScreenBuiltin
        self.isShowingMusicSneakPeek = isShowingMusicSneakPeek
        self.mediaGestureDirection = mediaGestureDirection
        self.mediaGestureIconVisible = mediaGestureIconVisible
        self.coverRotationY = coverRotationY
        self.albumArtNamespace = albumArtNamespace
        self.isDualActivityActive = isDualActivityActive
        self.useMusicVisualizer = useMusicVisualizer
        self.islandStyle = islandStyle
        self.inlinePlaybackPeekOverride = inlinePlaybackPeekOverride
        self._showCoverHoverMusicDetails = showCoverHoverMusicDetails
        self._coverHoverDismissTask = coverHoverDismissTask
        self.onOpenPomodoro = onOpenPomodoro
    }

    var body: some View {
        let coverSize: CGFloat = {
            if isCurrentDisplayIsland {
                if isCurrentScreenBuiltin {
                    return isShowingMusicSneakPeek ? 18 : 17
                } else {
                    return isShowingMusicSneakPeek ? 18.5 : 18
                }
            } else {
                return max(0, vm.effectiveClosedNotchHeight - 12)
            }
        }()
        let showGesturePrev = mediaGestureDirection == .right && mediaGestureIconVisible && musicManager.isPlaying
        let showGestureNext = mediaGestureDirection == .left && mediaGestureIconVisible && musicManager.isPlaying
        let isInlinePlaybackPeek = inlinePlaybackPeekOverride ?? (Defaults[.sneakPeekStyles] == .inline
            && ((coordinator.expandingView.show && coordinator.expandingView.type == .music)
                || showCoverHoverMusicDetails))
        let islandSneakPeekWidth: CGFloat = isCurrentScreenBuiltin ? 176 : 152
        let inlineIslandWidth = isCurrentDisplayIsland
            ? Self.inlineIslandWidth(
                isBuiltIn: isCurrentScreenBuiltin,
                songTitle: musicManager.songTitle,
                artistName: musicManager.artistName,
                coverWidth: coverSize
            )
            : 0
        let inlineMusicMetadata = Self.inlineMusicMetadata(
            songTitle: musicManager.songTitle,
            artistName: musicManager.artistName
        )
        let inlineTextColor = Defaults[.coloredSpectrogram]
            ? Color(nsColor: musicManager.avgColor)
            : Color.gray
        let inlineTitleWidth: CGFloat = isCurrentDisplayIsland
            ? max(40, inlineIslandWidth - coverSize - 6)
            : Self.inlineNotchSongWidth(musicManager.songTitle)
        let inlineArtistWidth = Self.inlineNotchArtistWidth(musicManager.artistName)
        let inlineVisualizerWidth = min(20, coverSize)
        let inlineLeftWingWidth = coverSize + (inlineArtistWidth > 0 ? 6 + inlineArtistWidth : 0)
        let inlineRightWingWidth = inlineTitleWidth + 6 + inlineVisualizerWidth
        let inlineWingWidth = max(inlineLeftWingWidth, inlineRightWingWidth)
        let defaultCenterSpacerWidth: CGFloat = isCurrentDisplayIsland
            ? (isShowingMusicSneakPeek ? max(10, islandSneakPeekWidth - coverSize - 20) : (isCurrentScreenBuiltin ? 68 : 50))
            : (isCurrentScreenBuiltin ? (vm.closedNotchSize.width + 14) : (vm.closedNotchSize.width - 10))
        let inlineCenterSpacerWidth: CGFloat = isCurrentDisplayIsland
            ? inlineTitleWidth
            : vm.closedNotchSize.width

        let albumCoverView = ZStack {
            Image(nsImage: musicManager.albumArt)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: coverSize, height: coverSize)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: isCurrentDisplayIsland ? (isCurrentScreenBuiltin ? 4.5 : 4.8) : MusicPlayerImageSizes.cornerRadiusInset.closed,
                        style: .continuous
                    )
                )
                .rotation3DEffect(.degrees(coverRotationY), axis: (x: 0, y: 1, z: 0))
                .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                .opacity(showGesturePrev ? 0 : 1)
                .animation(.easeOut(duration: 0.2), value: showGesturePrev)

            if showGesturePrev {
                Image(systemName: "backward.fill")
                    .font(.system(size: coverSize * 0.45, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: coverSize, height: coverSize)
        .contentShape(Rectangle())
        .onHover { hovering in
            isCoverHovering = hovering
            if hovering && vm.notchState == .closed && !musicManager.isPlayerIdle
                && inlinePlaybackPeekOverride == nil {
                coverHoverDismissTask?.cancel()
                withAnimation(.interactiveSpring(
                    response: isCurrentDisplayIsland ? 0.2 : 0.38,
                    dampingFraction: isCurrentDisplayIsland ? 0.82 : 0.78
                )) {
                    showCoverHoverMusicDetails = true
                }
            }
        }

        VStack(spacing: isShowingMusicSneakPeek && !isInlinePlaybackPeek ? 4 : 0) {
            HStack(spacing: isInlinePlaybackPeek && isCurrentDisplayIsland ? 6 : 0) {
                if isInlinePlaybackPeek && !isCurrentDisplayIsland {
                    HStack(spacing: 6) {
                        albumCoverView
                        if !musicManager.artistName.isEmpty {
                            Text(musicManager.artistName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(inlineTextColor)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(width: inlineArtistWidth, alignment: .leading)
                        }
                    }
                    .frame(width: inlineWingWidth, height: vm.effectiveClosedNotchHeight, alignment: .leading)

                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: vm.closedNotchSize.width, height: vm.effectiveClosedNotchHeight)

                    HStack(spacing: 6) {
                        MarqueeText(
                            .constant(Self.displaySongTitle(musicManager.songTitle)),
                            font: .system(size: 11, weight: .medium),
                            textColor: inlineTextColor,
                            minDuration: 0.4,
                            frameWidth: inlineTitleWidth,
                            alignment: .trailing,
                            fadeMaskWhenScrolling: true
                        )
                        .frame(width: inlineTitleWidth, alignment: .trailing)

                        musicPlayingAnimation(coverSize: inlineVisualizerWidth, showGestureNext: showGestureNext)
                            .frame(width: inlineVisualizerWidth, height: coverSize)
                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    }
                    .frame(width: inlineWingWidth, height: vm.effectiveClosedNotchHeight, alignment: .trailing)
                } else {
                    albumCoverView

                    if isDualActivityActive && !isCurrentDisplayIsland {
                        HStack {
                            Spacer(minLength: 0)
                            Button(action: {
                                onOpenPomodoro?()
                            }) {
                                Text(pomodoroManager.formattedRemainingTime)
                                    .font(.system(size: isCurrentScreenBuiltin ? 12.5 : 11.0, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(pomodoroManager.isBreakPhase ? Color.green : Color.white)
                                    .lineLimit(1)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3.5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(isPomodoroHovered ? Color.white.opacity(0.18) : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                withAnimation(.easeInOut(duration: 0.16)) {
                                    isPomodoroHovered = hovering
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(
                            width: defaultCenterSpacerWidth,
                            height: vm.effectiveClosedNotchHeight
                        )
                    } else {
                        if !isCurrentDisplayIsland {
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .overlay(
                                    HStack(alignment: .center, spacing: 4) {
                                        if isInlinePlaybackPeek {
                                            Spacer(minLength: vm.closedNotchSize.width)
                                            MarqueeText(
                                                .constant(inlineMusicMetadata),
                                                font: .system(size: 11, weight: .medium),
                                                textColor: inlineTextColor,
                                                minDuration: 0.4,
                                                frameWidth: inlineTitleWidth,
                                                alignment: .leading,
                                                fadeMaskWhenScrolling: true
                                            )
                                            .frame(width: inlineTitleWidth, alignment: .trailing)
                                        }
                                    }
                                )
                                .frame(
                                    width: isInlinePlaybackPeek
                                        ? inlineCenterSpacerWidth
                                        : defaultCenterSpacerWidth
                                )
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .overlay(
                                    HStack(alignment: .center, spacing: 4) {
                                        if isInlinePlaybackPeek {
                                            MarqueeText(
                                                .constant(inlineMusicMetadata),
                                                font: .system(size: 11, weight: .medium),
                                                textColor: inlineTextColor,
                                                minDuration: 0.4,
                                                frameWidth: inlineTitleWidth,
                                                alignment: .leading,
                                                fadeMaskWhenScrolling: true
                                            )
                                            .frame(width: inlineTitleWidth, alignment: .trailing)
                                        }
                                    }
                                )
                                .frame(
                                    width: isInlinePlaybackPeek
                                        ? inlineCenterSpacerWidth
                                        : defaultCenterSpacerWidth
                                )
                        }
                    }
                }

            }
            .overlay(alignment: .trailing) {
                if isCurrentDisplayIsland || !isInlinePlaybackPeek {
                    musicPlayingAnimation(coverSize: coverSize, showGestureNext: showGestureNext)
                        .blur(radius: isInlinePlaybackPeek ? 6 : 0)
                        .opacity(isInlinePlaybackPeek ? 0 : 1)
                        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: isInlinePlaybackPeek)
                        .allowsHitTesting(!isInlinePlaybackPeek)
                }
            }
            .contentShape(Rectangle())
            .frame(
                height: vm.effectiveClosedNotchHeight,
                alignment: .center
            )
            .animation(isCurrentDisplayIsland ? .interactiveSpring(response: 0.34, dampingFraction: 0.84) : nil, value: isInlinePlaybackPeek)
            .animation(isCurrentDisplayIsland ? .spring(response: 0.68, dampingFraction: 0.88) : nil, value: musicManager.songTitle)
            .animation(isCurrentDisplayIsland ? .spring(response: 0.68, dampingFraction: 0.88) : nil, value: musicManager.artistName)

            // Centered Sneak Peek details row below cover & visualizer
            if isShowingMusicSneakPeek && !isInlinePlaybackPeek {
                let songTitleAndArtist = musicManager.artistName.isEmpty
                    ? musicManager.songTitle
                    : "\(musicManager.songTitle) - \(musicManager.artistName)"
                let songText = musicManager.artistName.isEmpty
                    ? "♪ \(musicManager.songTitle)"
                    : "♪ \(musicManager.songTitle) • \(musicManager.artistName)"
                let textAvailableWidth = isCurrentDisplayIsland
                    ? (islandSneakPeekWidth - 28)
                    : (vm.closedNotchSize.width - 20)
                let textColor = Defaults[.playerColorTinting]
                    ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.6)
                    : .white.opacity(0.9)

                Group {
                    if showCopiedFeedback {
                        let feedbackColor: Color = {
                            if Defaults[.playerColorTinting] {
                                return Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.7)
                            } else if islandStyle == .glass && isCurrentDisplayIsland {
                                return .white.opacity(0.9)
                            } else {
                                return .white.opacity(0.85)
                            }
                        }()

                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8.5, weight: .bold))
                            Text("Copied to clipboard")
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(feedbackColor)
                        .frame(height: 16)
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        MarqueeText(
                            .constant(songText),
                            font: .system(size: 11, weight: .medium, design: .rounded),
                            textColor: textColor,
                            minDuration: 1.5,
                            frameWidth: isCurrentDisplayIsland ? textAvailableWidth : (textAvailableWidth - 12),
                            alignment: .center,
                            fadeMaskWhenScrolling: true
                        )
                        .opacity(isSongDetailsHovered ? 1.0 : 0.85)
                    }
                }
                .contentShape(Rectangle())
                .onHover { hov in
                    isSongDetailsHovered = hov
                    if hov {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .onTapGesture {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(songTitleAndArtist, forType: .string)
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        showCopiedFeedback = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            showCopiedFeedback = false
                        }
                    }
                }
                .frame(width: textAvailableWidth, alignment: .center)
                .padding(.horizontal, 4)
                .padding(.bottom, isCurrentDisplayIsland ? 6 : 8)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
            }
        }
    }

    @ViewBuilder
    private func musicPlayingAnimation(coverSize: CGFloat, showGestureNext: Bool) -> some View {
        ZStack {
            HStack {
                if useMusicVisualizer {
                    let spectrumFillColor: Color = Defaults[.playerColorTinting]
                        ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.65)
                        : Color.white.opacity(0.85)
                    Rectangle()
                        .fill(musicManager.isPlaying ? spectrumFillColor.gradient : Color.gray.gradient)
                        .frame(width: coverSize, height: coverSize, alignment: .center)
                        .matchedGeometryEffect(id: "spectrum", in: albumArtNamespace)
                        .mask {
                            AudioSpectrumView(
                                isPlaying: $musicManager.isPlaying,
                                color: Defaults[.playerColorTinting]
                                    ? NSColor(Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.65))
                                    : .white
                            )
                            .frame(width: 14, height: 11)
                        }
                } else {
                    LottieAnimationContainer()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: coverSize, height: coverSize, alignment: .center)
            .opacity(showGestureNext || isVisualizerHovering ? 0 : 1)
            .animation(.easeOut(duration: 0.2), value: showGestureNext)
            .animation(.easeOut(duration: 0.2), value: isVisualizerHovering)

            if showGestureNext {
                Image(systemName: "forward.fill")
                    .font(.system(size: coverSize * 0.45, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            }

            if isVisualizerHovering && !showGestureNext {
                Button {
                    MusicManager.shared.togglePlay()
                } label: {
                    Image(systemName: musicManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: coverSize * 0.62, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.6), radius: 12)
                        .shadow(color: .white.opacity(0.35), radius: 24)
                        .padding(6)
                        .background(Circle().fill(Color.white.opacity(0.12)).blur(radius: 0.5))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
        }
        .frame(width: coverSize, height: coverSize, alignment: .center)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isVisualizerHovering = hovering && !musicManager.isPlayerIdle && vm.notchState == .closed
            }
        }
    }
}

#Preview {
    let vm = BoringViewModel()
    vm.open()
    return ContentView()
        .environmentObject(vm)
        .frame(width: vm.notchSize.width, height: vm.notchSize.height)
}
