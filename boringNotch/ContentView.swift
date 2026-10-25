//
//  ContentView.swift
//  boringNotchApp
//
//  Created by Harsh Vardhan Goswami  on 02/08/24
//  Modified by Richard Kunkli on 24/08/2024.
//

import AVFoundation
import Combine
import Defaults
import KeyboardShortcuts
import SwiftUI
import SwiftUIIntrospect

@MainActor
struct ContentView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var coordinator = BoringViewCoordinator.shared

    private var musicManager: MusicManager { MusicManager.shared }
    private var pomodoroManager: PomodoroManager { PomodoroManager.shared }
    private var antigravityManager: AntigravityManager { AntigravityManager.shared }
    @State private var hoverTask: Task<Void, Never>?
    @State private var isHovering: Bool = false
    @State private var anyDropDebounceTask: Task<Void, Never>?
    @State private var openNotchHoverWatchdogTask: Task<Void, Never>?
    @State private var lastOpenedAt: Date = .distantPast

    @State private var gestureProgress: CGFloat = .zero

    @State private var haptics: Bool = false

    // Horizontal gesture states for media control
    @State private var mediaGestureDirection: MediaGestureDirection = .none
    @State private var mediaGestureIconVisible: Bool = false
    @State private var mediaGestureTask: Task<Void, Never>?
    @State private var hasTriggeredMediaGestureInCurrentSwipe: Bool = false
    @State private var lastPreviousGestureAt: Date = .distantPast
    
    // Hover states for closed notch music areas
    @State private var showCoverHoverMusicDetails: Bool = false
    @State private var coverHoverDismissTask: Task<Void, Never>?
    @State private var isIslandTransientlyVisible: Bool = false
    @State private var transientVisibilityTask: Task<Void, Never>?
    @State private var coverRotationY: Double = 0

    @Namespace var albumArtNamespace

    @Default(.useMusicVisualizer) var useMusicVisualizer
    @Default(.pomodoroEnabled) var pomodoroEnabled
    @Default(.pomodoroClosedNotchDisplayMode) var pomodoroClosedNotchDisplayMode
    @Default(.showMirror) var showMirror
    @Default(.showNotHumanFace) var showNotHumanFace
    @Default(.showCalendar) var showCalendar
    @Default(.activeModule) var activeModule
    
    @State private var emptyClickBounce: Bool = false
    @State private var isScaleHovered: Bool = false
    @State private var scaleHoverTask: Task<Void, Never>?
    @State private var idleBounceTask: Task<Void, Never>?
    @State private var idleBounceWorkItem: DispatchWorkItem?
    @State private var isIslandClickedDown: Bool = false
    @State private var isSubtlePillHovered: Bool = false
    
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

    private var isIslandShowing: Bool {
        if effectiveIslandVisibility == .alwaysVisible {
            return true
        }
        if effectiveIslandVisibility == .onClick {
            return isIslandClickedDown || isIslandTransientlyVisible
        }
        return isHovering || isShowingMusicSneakPeek || isIslandTransientlyVisible
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

        if effectiveIslandVisibility == .alwaysVisible {
            return centeredMenuBarOffset
        } else {
            return isIslandShowing ? dropDownOffset : -40
        }
    }

    private var islandOpacity: Double {
        guard isCurrentDisplayIsland else { return 1.0 }
        if vm.notchState == .open { return 1.0 }
        if effectiveIslandVisibility == .alwaysVisible { return 1.0 }
        return isIslandShowing ? 1.0 : 0.0
    }

    private var topCornerRadius: CGFloat {
        ((vm.notchState == .open) && Defaults[.cornerRadiusScaling])
            ? cornerRadiusInsets.opened.top
            : cornerRadiusInsets.closed.top
    }

    private var currentNotchShape: NotchShape {
        let bottomRadius: CGFloat = {
            if DinoCoordinator.shared.activeSlot == .webcam && vm.notchState == .open {
                return 24
            }
            return ((vm.notchState == .open) && Defaults[.cornerRadiusScaling])
                ? cornerRadiusInsets.opened.bottom
                : cornerRadiusInsets.closed.bottom
        }()
        return NotchShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomRadius
        )
    }



    private var isShowingMusicSneakPeek: Bool {
        (showCoverHoverMusicDetails || (coordinator.sneakPeek.show && coordinator.sneakPeek.type == .music))
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
            if isShowingSystemToastHUD {
                let type = coordinator.sneakPeek.type
                switch type {
                case .airPods:
                    return isCurrentScreenBuiltin ? 112 : 106
                case .volume, .brightness, .backlight:
                    return isCurrentScreenBuiltin ? 236 : 228
                case .camera, .mic, .micActivity, .screenRecord, .capsLock, .location:
                    return isCurrentScreenBuiltin ? 180 : 175
                default:
                    return isCurrentScreenBuiltin ? 180 : 175
                }
            } else if isShowingMusicSneakPeek {
                return isCurrentScreenBuiltin ? 190 : 165
            } else if coordinator.expandingView.type == .battery && coordinator.expandingView.show && vm.notchState == .closed {
                return isCurrentScreenBuiltin ? 170 : 145
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
                return isCurrentScreenBuiltin ? 170 : 145
            case .idle, .shelf, .download, .webcam, .coding, .hud:
                return isCurrentScreenBuiltin ? 88 : 70
            }
        }

        var chinWidth: CGFloat = vm.closedNotchSize.width + (2 * topCornerRadius) + 8

        if coordinator.expandingView.type == .battery && coordinator.expandingView.show
            && vm.notchState == .closed
        {
            if Defaults[.batteryToastType] == .dynamicNotch {
                chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 24)
            } else {
                chinWidth = 640
            }
        } else if isShowingSystemToastHUD {
            let type = coordinator.sneakPeek.type
            if isCurrentScreenBuiltin {
                switch type {
                case .airPods:
                    chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 50)
                case .volume, .brightness, .backlight:
                    chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 110)
                case .camera, .mic, .micActivity, .screenRecord, .capsLock, .location:
                    chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 75)
                default:
                    chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 65)
                }
            } else {
                switch type {
                case .airPods:
                    chinWidth = 106
                case .volume, .brightness, .backlight:
                    chinWidth = 228
                case .camera, .mic, .micActivity, .screenRecord, .capsLock, .location:
                    chinWidth = 175
                default:
                    chinWidth = 175
                }
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
        Defaults[.codeActivityEnabled]
            && Defaults[.codeShowInClosedNotch]
            && ((coordinator.expandingView.type == .antigravity && coordinator.expandingView.show) || antigravityManager.isVisible)
            && antigravityManager.currentPhase != .idle
            && vm.notchState == .closed
    }

    private var mirrorCardSize: CGSize {
        vm.mirrorSlotCardSize(isIsland: isCurrentDisplayIsland)
    }

    private var desiredOpenNotchWidth: CGFloat {
        if DinoCoordinator.shared.activeSlot == .webcam {
            return mirrorCardSize.width
        }
        switch coordinator.currentView {
        case .home, .shelf:
            return isCurrentDisplayIsland ? 385 : 435
        case .calendar:
            return 560
        }
    }

    private var desiredOpenNotchHeight: CGFloat {
        if DinoCoordinator.shared.activeSlot == .webcam {
            return mirrorCardSize.height
        }
        switch coordinator.currentView {
        case .home, .shelf:
            return 188
        case .calendar:
            return 190
        }
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
            && (activeModule != .calendar || isShowingMusicSneakPeek)
            && (activeModule != .pomodoro || isShowingMusicSneakPeek || !pomodoroManager.hasActiveSession)
    }

    private var shouldShowCalendarClosedVisual: Bool {
        showCalendar
            && activeModule == .calendar
            && vm.notchState == .closed
            && !vm.hideOnClosed
            && !isShowingMusicSneakPeek
            && !isAntigravityActive
            && !coordinator.expandingView.show
    }

    private var shouldShowNonMusicClosedVisual: Bool {
        !coordinator.expandingView.show
            && vm.notchState == .closed
            && !vm.hideOnClosed
            && (!musicManager.isPlaying && musicManager.isPlayerIdle)
            && (showCalendar || showNotHumanFace || showMirror)
    }

    private var hasActiveFeature: Bool {
        if coordinator.expandingView.show { return true }
        if coordinator.sneakPeek.show { return true }
        if isDualActivityActive || DinoCoordinator.shared.isDualActivityActive { return true }
        if DinoCoordinator.shared.activeSlot != .idle { return true }
        return false
    }

    private var isShowingInlineMusicPlaybackPeek: Bool {
        coordinator.expandingView.show
            && coordinator.expandingView.type == .music
            && Defaults[.sneakPeekStyles] == .inline
    }

    private var shouldShowPomodoroInlineClosedVisual: Bool {
        guard shouldShowPomodoroClosedContent else { return false }
        guard !isDualActivityActive else { return false }
        guard !isShowingInlineMusicPlaybackPeek else { return false }
        guard !(coordinator.sneakPeek.show && coordinator.sneakPeek.type == .music) else { return false }
        return true
    }

    private func updateOpenNotchWidth(animated: Bool = true) {
        guard vm.notchState == .open else { return }
        let targetWidth = desiredOpenNotchWidth
        let targetHeight = desiredOpenNotchHeight
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

    var body: some View {
        // Calculate scale based on gesture progress only
        let gestureScale: CGFloat = {
            guard gestureProgress != 0 else { return 1.0 }
            let scaleFactor = 1.0 + gestureProgress * 0.01
            return max(0.6, scaleFactor)
        }()
        
        ZStack(alignment: .top) {
            if isCurrentDisplayIsland && vm.notchState == .closed && !isIslandShowing {
                // Feedback placeholder for Island ("huddi island kabi sizega ega, shaffof, ortasida horizontal line")
                ZStack {
                    RoundedRectangle(cornerRadius: islandCornerRadius, style: .continuous)
                        .fill(
                            islandStyle == .glass
                                ? Color.white.opacity(0.12)
                                : Color.black.opacity(0.35)
                        )
                    RoundedRectangle(cornerRadius: islandCornerRadius, style: .continuous)
                        .stroke(
                            Color.white.opacity(0.16),
                            lineWidth: 0.8
                        )
                    // Horizontal line in the middle
                    Capsule()
                        .fill(Color.white.opacity(0.40))
                        .frame(width: 26, height: 3)
                }
                .frame(
                    width: max(112, vm.closedNotchSize.width),
                    height: max(24, vm.effectiveClosedNotchHeight)
                )
                .contentShape(RoundedRectangle(cornerRadius: islandCornerRadius, style: .continuous))
                .offset(y: centeredMenuBarOffset)
                .opacity(isSubtlePillHovered ? 1.0 : 0.001)
                .animation(.easeInOut(duration: 0.22), value: isSubtlePillHovered)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isSubtlePillHovered = hovering
                    }
                    if effectiveIslandVisibility == .onHover {
                        handleHover(hovering)
                    }
                }
                .onTapGesture {
                    withAnimation(animationSpring) {
                        isIslandClickedDown = true
                        isHovering = true
                    }
                }
                .transition(.opacity)
                .zIndex(10)
                .allowsHitTesting(!isIslandShowing && vm.notchState == .closed)
            }

            if isCurrentDisplayIsland && isIslandShowing && vm.notchState == .closed && effectiveIslandVisibility != .alwaysVisible {
                // Continuous vertical hover bridge from menubar down to dropped island
                Color.clear
                    .frame(
                        width: max(220, max(vm.closedNotchSize.width, computedChinWidth) + 40),
                        height: dropDownOffset + vm.effectiveClosedNotchHeight + 10
                    )
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        handleHover(hovering)
                    }
                    .onTapGesture {
                        handleTap()
                    }
                    .zIndex(1)
            }

            VStack(spacing: 0) {
                islandContainerView
                    .frame(
                        width: vm.notchState == .open ? vm.notchSize.width : nil,
                        height: vm.notchState == .open ? vm.notchSize.height : nil,
                        alignment: .top
                    )
                    .scaleEffect(
                        x: emptyClickBounce ? 0.94 : ((isScaleHovered && vm.notchState == .closed && !isShowingMusicSneakPeek) ? 1.02 : 1.0),
                        y: emptyClickBounce ? 0.94 : 1.0,
                        anchor: .top
                    )
                    .offset(y: islandYOffset)
                    .opacity(islandOpacity)
                    .allowsHitTesting(isIslandShowing || vm.notchState == .open || !isCurrentDisplayIsland)
                    .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.82), value: isScaleHovered)
                    .animation(.interactiveSpring(response: 0.42, dampingFraction: 0.80), value: isHovering)
                    .animation(.interactiveSpring(response: 0.44, dampingFraction: 0.82), value: islandYOffset)
                    .animation(.easeInOut(duration: 0.28), value: islandOpacity)
                    .conditionalModifier(true) { view in
                        let openAnimation = Animation.interactiveSpring(response: 0.36, dampingFraction: 0.68, blendDuration: 0)
                        let closeAnimation = Animation.interactiveSpring(response: 0.38, dampingFraction: 0.74, blendDuration: 0)
                        
                        return view
                            .animation(vm.notchState == .open ? openAnimation : closeAnimation, value: vm.notchState)
                            .animation(vm.notchState == .open ? openAnimation : closeAnimation, value: vm.notchSize)
                            .animation(.smooth, value: gestureProgress)
                            .animation(animationSpring, value: computedChinWidth)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: islandCornerRadius, style: .continuous))
                    .onHover { hovering in
                        if !(isDualActivityActive && isCurrentDisplayIsland && vm.notchState == .closed) {
                            handleHover(hovering)
                        }
                    }
                    .conditionalModifier(Defaults[.enableGestures]) { view in
                        view
                            .panGesture(direction: .down) { translation, phase in
                                handleDownGesture(translation: translation, phase: phase)
                            }
                            .panGesture(direction: .up) { translation, phase in
                                handleUpGesture(translation: translation, phase: phase)
                            }
                            .horizontalSwipeGesture { translation, direction, phase in
                                handleHorizontalGesture(translation: translation, phase: phase, direction: direction)
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
                            openNotchHoverWatchdogTask?.cancel()
                            openNotchHoverWatchdogTask = nil
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
                    .onReceive(DinoCoordinator.shared.$activeSlot) { _ in
                        updateOpenNotchWidth()
                    }
                    .onChange(of: builtinFormFactor) { _, _ in
                        handleFormFactorAnimation()
                    }
                    .onChange(of: externalFormFactor) { _, _ in
                        handleFormFactorAnimation()
                    }
                    .onReceive(MusicManager.shared.$songTitle) { newTitle in
                        guard !newTitle.isEmpty,
                              musicManager.isPlaying,
                              !musicManager.isPlayerIdle,
                              Defaults[.enableSneakPeek] else { return }
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                            coverRotationY -= 180
                        }
                        if vm.notchState == .closed && !vm.hideOnClosed {
                            coordinator.toggleSneakPeek(status: true, type: .music, duration: 4.5)
                        }
                    }
                    .onReceive(MusicManager.shared.$isPlaying) { _ in }
                    .onReceive(MusicManager.shared.$isPlayerIdle) { _ in }
                    .onReceive(PomodoroManager.shared.$state) { _ in }
                    .onReceive(AntigravityManager.shared.$isVisible) { _ in }
                    .onReceive(AntigravityManager.shared.$currentPhase) { _ in }
                    .onChange(of: coordinator.sneakPeek.show) { _, isShowing in
                        if isShowing && coordinator.sneakPeek.type == .music && vm.notchState == .closed {
                            transientVisibilityTask?.cancel()
                            withAnimation(animationSpring) {
                                isIslandTransientlyVisible = true
                            }
                        } else if !isShowing && isIslandTransientlyVisible {
                            transientVisibilityTask?.cancel()
                            transientVisibilityTask = Task { @MainActor in
                                let delay = max(0.25, Defaults[.collapseDelay])
                                try? await Task.sleep(for: .seconds(delay))
                                guard !Task.isCancelled else { return }
                                if !self.isHovering && !self.isShowingMusicSneakPeek {
                                    withAnimation(self.animationSpring) {
                                        self.isIslandTransientlyVisible = false
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: vm.isBatteryPopoverActive) {
                        if !vm.isBatteryPopoverActive && !isHovering && vm.notchState == .open && !SharingStateManager.shared.preventNotchClose {
                            hoverTask?.cancel()
                            hoverTask = Task {
                                try? await Task.sleep(for: .milliseconds(100))
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    if !self.vm.isBatteryPopoverActive && !self.isHovering && self.vm.notchState == .open && !SharingStateManager.shared.preventNotchClose {
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
                if vm.chinHeight > 0 {
                    Rectangle()
                        .fill(Color.black.opacity(0.01))
                        .frame(width: computedChinWidth, height: vm.chinHeight)
                }
            }
            .zIndex(2)

            CustomBatteryToastOverlay()
        }
        .padding(.bottom, 8)
        .frame(maxWidth: windowSize.width, maxHeight: windowSize.height, alignment: .top)
        .compositingGroup()
        .scaleEffect(
            x: gestureScale,
            y: gestureScale,
            anchor: .top
        )
        .animation(.smooth, value: gestureProgress)
        .background(dragDetector)
        .preferredColorScheme(.dark)
        .environmentObject(vm)
        .onChange(of: vm.anyDropZoneTargeting) { _, isTargeted in
            anyDropDebounceTask?.cancel()

            if isTargeted {
                if vm.notchState == .closed {
                    coordinator.currentView = .shelf
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
            isDualActivityActive: isDualActivityActive,
            isHovering: isHovering,
            isScaleHovered: isScaleHovered,
            emptyClickBounce: emptyClickBounce,
            islandCornerRadius: islandCornerRadius,
            topCornerRadius: topCornerRadius,
            currentNotchShape: currentNotchShape,
            islandYOffset: islandYOffset,
            islandOpacity: islandOpacity,
            gestureProgress: gestureProgress,
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
                showMirror: showMirror,
                isHovering: $isHovering,
                gestureProgress: $gestureProgress,
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
        if Defaults[.boringShelf] && vm.notchState == .closed {
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
        if Defaults[.enableHaptics] {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            haptics.toggle()
        }
        lastOpenedAt = Date()
        showCoverHoverMusicDetails = false
        coordinator.toggleSneakPeek(status: false, type: .music, duration: 0)
        let targetSize = CGSize(width: desiredOpenNotchWidth, height: desiredOpenNotchHeight)
        withAnimation(animationSpring) {
            DinoCoordinator.shared.activateSlotDirectly(.music)
            coordinator.currentView = .home
            vm.open(targetSize: targetSize)
        }
    }

    private func openPomodoroWithSpring() {
        if Defaults[.enableHaptics] {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            haptics.toggle()
        }
        lastOpenedAt = Date()
        showCoverHoverMusicDetails = false
        coordinator.toggleSneakPeek(status: false, type: .music, duration: 0)
        let targetSize = CGSize(width: desiredOpenNotchWidth, height: desiredOpenNotchHeight)
        withAnimation(animationSpring) {
            DinoCoordinator.shared.activateSlotDirectly(.pomodoro)
            Defaults[.pomodoroEnabled] = true
            coordinator.currentView = .home
            vm.open(targetSize: targetSize)
        }
    }

    private func handleMainPillHover(_ hovering: Bool) {
        if coordinator.firstLaunch { return }
        coverHoverDismissTask?.cancel()

        if hovering {
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
            if !MusicManager.shared.isPlayerIdle && !isDualActivityActive {
                withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.78)) {
                    showCoverHoverMusicDetails = true
                }
            }

            guard vm.notchState == .closed,
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
            withAnimation(animationSpring) {
                isHovering = false
                isIslandClickedDown = false
                showCoverHoverMusicDetails = false
            }

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
                switch DinoCoordinator.shared.activeSlot {
                case .pomodoro:
                    openPomodoroWithSpring()
                    return
                case .music:
                    openMusicWithSpring()
                    return
                case .calendar:
                    DinoCoordinator.shared.activateSlotDirectly(.calendar)
                    coordinator.currentView = .calendar
                case .weather:
                    DinoCoordinator.shared.activateSlotDirectly(.weather)
                    coordinator.currentView = .home
                default:
                    coordinator.currentView = .home
                }
            }
            doOpen()
        } else {
            switch Defaults[.idleClickAction] {
            case .none:
                coordinator.currentView = .home
                doOpen()
            case .music:
                openMusicWithSpring()
            case .pomodoro:
                openPomodoroWithSpring()
            case .shelf:
                DinoCoordinator.shared.activateSlotDirectly(.shelf)
                coordinator.currentView = .shelf
                doOpen()
            case .weather:
                DinoCoordinator.shared.activateSlotDirectly(.weather)
                coordinator.currentView = .home
                doOpen()
            case .calendar:
                DinoCoordinator.shared.activateSlotDirectly(.calendar)
                coordinator.currentView = .home
                doOpen()
            }
        }
    }

    private func doOpen() {
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
            isHovering = false
            isIslandClickedDown = false
            showCoverHoverMusicDetails = false
            coordinator.toggleSneakPeek(status: false, type: .music, duration: 0)
            vm.close()
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

            if DinoCoordinator.shared.currentPriority == .p2OnDemand {
                DinoCoordinator.shared.pauseOnDemandDismiss()
            }
            
            guard vm.notchState == .closed,
                  effectiveIslandVisibility != .onClick,
                  !coordinator.sneakPeek.show,
                  hasActiveFeature,
                  Defaults[.openNotchOnHover] else { return }
            
            hoverTask = Task {
                try? await Task.sleep(for: .seconds(Defaults[.minimumHoverDuration]))
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    guard self.vm.notchState == .closed,
                          self.isHovering,
                          self.hasActiveFeature,
                          !self.coordinator.sneakPeek.show else { return }
                    
                    self.doOpen()
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
                        // 1. Morph open notch back to closed island pill with spring
                        self.closeWithSpring()
                        
                        // 2. Allow collapse animation to complete and stay visible briefly, then retract up and disappear
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(750))
                            guard !Task.isCancelled else { return }
                            if self.vm.notchState == .closed {
                                withAnimation(self.animationSpring) {
                                    self.isHovering = false
                                    self.isIslandClickedDown = false
                                    self.showCoverHoverMusicDetails = false
                                }
                            }
                        }
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

    private func handleDownGesture(translation: CGFloat, phase: NSEvent.Phase) {
        guard vm.notchState == .closed else { return }

        if phase == .ended {
            withAnimation(animationSpring) { gestureProgress = .zero }
            return
        }

        withAnimation(animationSpring) {
            gestureProgress = (translation / effectiveGestureThreshold) * 20
        }

        if translation > effectiveGestureThreshold {
            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
            withAnimation(animationSpring) {
                gestureProgress = .zero
            }
            doOpen()
        }
    }

    private func handleUpGesture(translation: CGFloat, phase: NSEvent.Phase) {
        guard vm.notchState == .open && !vm.isHoveringCalendar else { return }

        withAnimation(animationSpring) {
            gestureProgress = (translation / effectiveGestureThreshold) * -20
        }

        if phase == .ended {
            withAnimation(animationSpring) {
                gestureProgress = .zero
            }
        }

        if translation > effectiveGestureThreshold {
            if !SharingStateManager.shared.preventNotchClose { 
                gestureProgress = .zero
                closeWithSpring()
            }

            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
        }
    }

    // MARK: - Horizontal Gesture Dispatcher

    private func handleHorizontalGesture(translation: CGFloat, phase: NSEvent.Phase, direction: PanDirection) {
        if vm.notchState == .open {
            handleOpenNotchTabSwipe(translation: translation, phase: phase, direction: direction)
        } else {
            handleHorizontalMediaGesture(translation: translation, phase: phase, direction: direction)
        }
    }

    private func handleOpenNotchTabSwipe(translation: CGFloat, phase: NSEvent.Phase, direction: PanDirection) {
        if phase == .began {
            hasTriggeredMediaGestureInCurrentSwipe = false
        }

        let threshold = effectiveGestureThreshold * 0.7
        guard !hasTriggeredMediaGestureInCurrentSwipe && translation >= threshold else { return }

        hasTriggeredMediaGestureInCurrentSwipe = true
        withAnimation(.smooth) {
            let isShelf = (coordinator.currentView == .shelf || DinoCoordinator.shared.activeSlot == .shelf)
            let isPomodoro = (!isShelf && DinoCoordinator.shared.activeSlot == .pomodoro)

            if direction == .left {
                // Swipe Left (forward): Music -> Pomodoro -> Shelf -> Music
                if isPomodoro {
                    coordinator.currentView = .shelf
                    DinoCoordinator.shared.activateSlotDirectly(.shelf)
                } else if isShelf {
                    coordinator.currentView = .home
                    DinoCoordinator.shared.activateSlotDirectly(.music)
                } else {
                    coordinator.currentView = .home
                    DinoCoordinator.shared.activateSlotDirectly(.pomodoro)
                }
            } else if direction == .right {
                // Swipe Right (backward): Music -> Shelf -> Pomodoro -> Music
                if isShelf {
                    coordinator.currentView = .home
                    DinoCoordinator.shared.activateSlotDirectly(.pomodoro)
                } else if isPomodoro {
                    coordinator.currentView = .home
                    DinoCoordinator.shared.activateSlotDirectly(.music)
                } else {
                    coordinator.currentView = .shelf
                    DinoCoordinator.shared.activateSlotDirectly(.shelf)
                }
            }
        }

        if Defaults[.enableHaptics] {
            haptics.toggle()
        }
    }

    // MARK: - Horizontal Media Gesture

    @State private var lastMediaSwipeTriggeredAt: Date = .distantPast

    private var effectiveGestureThreshold: CGFloat {
        Defaults[.gestureSensitivityMode].threshold
    }

    private func handleHorizontalMediaGesture(translation: CGFloat, phase: NSEvent.Phase, direction: PanDirection) {
        // Only works when music is playing and notch is closed
        guard vm.notchState == .closed,
              musicManager.isPlaying,
              !musicManager.isPlayerIdle else { return }

        let gestureDirection: MediaGestureDirection = direction == .right ? .right : .left

        if phase == .began {
            hasTriggeredMediaGestureInCurrentSwipe = false
        }

        let now = Date()
        let timeSinceLastTrigger = now.timeIntervalSince(lastMediaSwipeTriggeredAt)

        // Strict single-action lock per swipe + 0.45s cooldown to prevent multiple skips on hard swipes
        if !hasTriggeredMediaGestureInCurrentSwipe && timeSinceLastTrigger > 0.45 && translation >= effectiveGestureThreshold * 0.75 {
            hasTriggeredMediaGestureInCurrentSwipe = true
            lastMediaSwipeTriggeredAt = now

            if gestureDirection == .left {
                // Swipe left = Next track (matches next icon on the right)
                MusicManager.shared.nextTrack()
            } else {
                // Swipe right = Apple-style Previous / Restart (matches prev icon on the left/cover)
                let wasRecentlyTriggered = now.timeIntervalSince(lastPreviousGestureAt) < 2.0
                lastPreviousGestureAt = now

                // Calculate real playback position (elapsedTime + real time since last update)
                let actualElapsed = musicManager.elapsedTime + (musicManager.isPlaying ? max(0, now.timeIntervalSince(musicManager.timestampDate)) : 0)

                if actualElapsed > 3.0 && !wasRecentlyTriggered {
                    // Song played > 3 seconds: restart current song
                    MusicManager.shared.seek(to: 0)
                } else {
                    // Song just started or double-swiped within 2 seconds: previous track
                    MusicManager.shared.previousTrack()
                }
            }

            // Flash confirmation animation: force icon to be visible for at least 0.45s upon action
            mediaGestureDirection = gestureDirection
            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                mediaGestureIconVisible = true
            }

            mediaGestureTask?.cancel()
            mediaGestureTask = Task {
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.25)) {
                        mediaGestureIconVisible = false
                    }
                }
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    mediaGestureDirection = .none
                }
            }

            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
        }

        if phase == .ended || phase == .cancelled {
            hasTriggeredMediaGestureInCurrentSwipe = false

            // If action wasn't triggered (partial swipe), dismiss immediately
            if !hasTriggeredMediaGestureInCurrentSwipe && translation < effectiveGestureThreshold * 0.5 {
                mediaGestureTask?.cancel()
                withAnimation(.easeOut(duration: 0.2)) {
                    mediaGestureIconVisible = false
                }
                mediaGestureTask = Task {
                    try? await Task.sleep(for: .milliseconds(200))
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        mediaGestureDirection = .none
                    }
                }
            }
            return
        }

        // Show the direction icon smoothly while dragging (preview hint)
        if mediaGestureDirection != gestureDirection && !hasTriggeredMediaGestureInCurrentSwipe {
            mediaGestureDirection = gestureDirection
            mediaGestureTask?.cancel()
            withAnimation(.easeOut(duration: 0.12)) {
                mediaGestureIconVisible = false
            }
            mediaGestureTask = Task {
                try? await Task.sleep(for: .milliseconds(80))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                        mediaGestureIconVisible = true
                    }
                }
            }
        }
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
        if batteryToastType == .dynamicNotch {
            let itemSize = max(0, vm.effectiveClosedNotchHeight - 12)
            let tintColor: Color = batteryModel.activeGlowColor ?? (batteryModel.levelBattery <= 20 ? .red : .green)
            let displayPercentage = batteryModel.alertPercentage > 0 ? batteryModel.alertPercentage : Int(batteryModel.levelBattery)

            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tintColor)
                    .frame(width: itemSize, height: itemSize)

                Rectangle()
                    .fill(Color.clear)
                    .frame(width: isCurrentDisplayIsland ? 64 : (vm.closedNotchSize.width - cornerRadiusInsets.closed.top), height: vm.effectiveClosedNotchHeight)

                Text("\(displayPercentage)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(tintColor)
                    .frame(width: itemSize, height: itemSize)
            }
            .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
        } else {
            HStack(spacing: 0) {
                HStack {
                    Text(batteryModel.alertBannerText ?? batteryModel.statusText)
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
                        isInLowPowerMode: batteryModel.isInLowPowerMode,
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

    @Binding var showCoverHoverMusicDetails: Bool
    @Binding var coverHoverDismissTask: Task<Void, Never>?
    var onOpenPomodoro: (() -> Void)? = nil

    @State private var isVisualizerHovering: Bool = false
    @State private var isCoverHovering: Bool = false
    @State private var isSongDetailsHovered: Bool = false
    @State private var isPomodoroHovered: Bool = false
    @State private var showCopiedFeedback: Bool = false

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
        let islandSneakPeekWidth: CGFloat = isCurrentScreenBuiltin ? 190 : 165
        let defaultCenterSpacerWidth: CGFloat = isCurrentDisplayIsland
            ? (isShowingMusicSneakPeek ? max(10, islandSneakPeekWidth - (coverSize * 2) - 20) : (isCurrentScreenBuiltin ? 68 : 50))
            : (isCurrentScreenBuiltin ? (vm.closedNotchSize.width + 14) : (vm.closedNotchSize.width - 10))

        VStack(spacing: isShowingMusicSneakPeek ? 4 : 0) {
            HStack(spacing: 0) {
                // MARK: Left side - Album art with gesture prev icon & hover sneak peek
                ZStack {
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

                    // Gesture: swipe right → prev icon replaces cover
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
                    if hovering && vm.notchState == .closed && !musicManager.isPlayerIdle {
                        coverHoverDismissTask?.cancel()
                        withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.78)) {
                            showCoverHoverMusicDetails = true
                        }
                    }
                }

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
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .overlay(
                            HStack(alignment: .top) {
                                if coordinator.expandingView.show
                                    && coordinator.expandingView.type == .music
                                {
                                    MarqueeText(
                                        .constant(musicManager.songTitle),
                                        textColor: Defaults[.coloredSpectrogram]
                                            ? Color(nsColor: musicManager.avgColor) : Color.gray,
                                        minDuration: 0.4,
                                        frameWidth: 100
                                    )
                                    .opacity(
                                        (coordinator.expandingView.show
                                            && Defaults[.sneakPeekStyles] == .inline)
                                            ? 1 : 0
                                     )
                                    Spacer(minLength: isCurrentDisplayIsland ? 64 : vm.closedNotchSize.width)
                                    // Song Artist
                                    Text(musicManager.artistName)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .foregroundStyle(
                                            Defaults[.coloredSpectrogram]
                                                ? Color(nsColor: musicManager.avgColor)
                                                : Color.gray
                                        )
                                        .opacity(
                                            (coordinator.expandingView.show
                                                && coordinator.expandingView.type == .music
                                                && Defaults[.sneakPeekStyles] == .inline)
                                                ? 1 : 0
                                        )
                                }
                            }
                        )
                        .frame(
                            width: (coordinator.expandingView.show
                                && coordinator.expandingView.type == .music
                                && Defaults[.sneakPeekStyles] == .inline)
                                ? 380
                                : defaultCenterSpacerWidth
                        )
                }

                // MARK: Right side - Visualizer with gesture next icon & hover play/pause
                ZStack {
                    // Normal visualizer content
                    HStack {
                        if useMusicVisualizer {
                            let spectrumFillColor: Color = Defaults[.playerColorTinting]
                                ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.65)
                                : Color.white.opacity(0.85)
                            Rectangle()
                                .fill(
                                    musicManager.isPlaying
                                        ? spectrumFillColor.gradient
                                        : Color.gray.gradient
                                )
                                .frame(width: coverSize, height: coverSize, alignment: .center)
                                .matchedGeometryEffect(id: "spectrum", in: albumArtNamespace)
                                .mask {
                                    AudioSpectrumView(
                                        isPlaying: $musicManager.isPlaying,
                                        color: Defaults[.playerColorTinting] ? NSColor(Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.65)) : .white
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

                    // Gesture: swipe left → next icon replaces visualizer
                    if showGestureNext {
                        Image(systemName: "forward.fill")
                            .font(.system(size: coverSize * 0.45, weight: .bold))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }

                    // Hover: play/pause icon replaces visualizer
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
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.12))
                                        .blur(radius: 0.5)
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    }
                }
                .frame(
                    width: coverSize,
                    height: coverSize,
                    alignment: .center
                )
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isVisualizerHovering = hovering && !musicManager.isPlayerIdle && vm.notchState == .closed
                    }
                }
            }
            .contentShape(Rectangle())
            .frame(
                height: vm.effectiveClosedNotchHeight,
                alignment: .center
            )

            // Centered Sneak Peek details row below cover & visualizer
            if isShowingMusicSneakPeek {
                let songTitleAndArtist = musicManager.artistName.isEmpty
                    ? musicManager.songTitle
                    : "\(musicManager.songTitle) - \(musicManager.artistName)"
                let songText = musicManager.artistName.isEmpty
                    ? "♪ \(musicManager.songTitle)"
                    : "♪ \(musicManager.songTitle) • \(musicManager.artistName)"
                let textAvailableWidth = isCurrentDisplayIsland ? (islandSneakPeekWidth - 28) : (vm.closedNotchSize.width - 20)
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
                            frameWidth: textAvailableWidth - 12,
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
}

#Preview {
    let vm = BoringViewModel()
    vm.open()
    return ContentView()
        .environmentObject(vm)
        .frame(width: vm.notchSize.width, height: vm.notchSize.height)
}
