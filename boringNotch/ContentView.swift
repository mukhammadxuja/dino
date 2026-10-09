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
    @ObservedObject var webcamManager = WebcamManager.shared

    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var pomodoroManager = PomodoroManager.shared
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var brightnessManager = BrightnessManager.shared
    @ObservedObject var volumeManager = VolumeManager.shared
    @ObservedObject var antigravityManager = AntigravityManager.shared
    @State private var hoverTask: Task<Void, Never>?
    @State private var isHovering: Bool = false
    @State private var anyDropDebounceTask: Task<Void, Never>?

    @State private var gestureProgress: CGFloat = .zero

    @State private var haptics: Bool = false

    // Horizontal gesture states for media control
    @State private var mediaGestureDirection: MediaGestureDirection = .none
    @State private var mediaGestureIconVisible: Bool = false
    @State private var mediaGestureTask: Task<Void, Never>?
    
    // Hover states for closed notch music areas
    @State private var isCoverHovering: Bool = false
    @State private var isVisualizerHovering: Bool = false
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
    @State private var isSongDetailsHovered: Bool = false
    @State private var isScaleHovered: Bool = false
    @State private var scaleHoverTask: Task<Void, Never>?
    @State private var showCopiedFeedback: Bool = false
    
    // Displays & Island Mode
    @Default(.displaySelection) var displaySelection
    @Default(.builtinFormFactor) var builtinFormFactor
    @Default(.externalFormFactor) var externalFormFactor
    @Default(.islandStyle) var islandStyle
    @Default(.islandVisibility) var islandVisibility
    @Default(.displayShowOn) var displayShowOn

    // Shared interactive spring for movement/resizing to avoid conflicting animations
    private let animationSpring = Animation.interactiveSpring(response: 0.36, dampingFraction: 0.68, blendDuration: 0)

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
            return .onHover
        } else {
            return islandVisibility
        }
    }

    private var islandYOffset: CGFloat {
        guard isCurrentDisplayIsland else { return 0 }
        let currentScreen = currentTargetScreen
        let physicalHeight = max(32, currentScreen?.safeAreaInsets.top ?? 38)
        let menuBarHeight = max(24, (currentScreen?.frame.maxY ?? 0) - (currentScreen?.visibleFrame.maxY ?? 0))
        let centeredMenuBarOffset = max(2, (menuBarHeight - (isCurrentScreenBuiltin ? 33 : 24)) / 2)
        
        // Exact drop down offset below camera / menu bar with clean breathing space (38pt + 8pt = 46pt)
        let dropDownOffset = max(physicalHeight, menuBarHeight) + 8

        if vm.notchState == .open {
            return isCurrentScreenBuiltin ? dropDownOffset : 8
        }

        if effectiveIslandVisibility == .onHover {
            if isHovering || isShowingMusicSneakPeek || isIslandTransientlyVisible {
                return dropDownOffset
            } else {
                return -40 // Retracted and hidden up top
            }
        } else {
            return centeredMenuBarOffset
        }
    }

    private var islandOpacity: Double {
        guard isCurrentDisplayIsland else { return 1.0 }
        if vm.notchState == .open { return 1.0 }
        if effectiveIslandVisibility == .onHover {
            return (isHovering || isShowingMusicSneakPeek || isIslandTransientlyVisible) ? 1.0 : 0.0
        }
        return 1.0
    }

    private var topCornerRadius: CGFloat {
       ((vm.notchState == .open) && Defaults[.cornerRadiusScaling])
                ? cornerRadiusInsets.opened.top
                : cornerRadiusInsets.closed.top
    }

    private var currentNotchShape: NotchShape {
        NotchShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: ((vm.notchState == .open) && Defaults[.cornerRadiusScaling])
                ? cornerRadiusInsets.opened.bottom
                : cornerRadiusInsets.closed.bottom
        )
    }

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

    private var isShowingMusicSneakPeek: Bool {
        (showCoverHoverMusicDetails || (coordinator.sneakPeek.show && coordinator.sneakPeek.type == .music))
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

    private var computedChinWidth: CGFloat {
        if isCurrentDisplayIsland {
            if isShowingMusicSneakPeek {
                return isCurrentScreenBuiltin ? 190 : 165
            } else if coordinator.expandingView.type == .battery && coordinator.expandingView.show && vm.notchState == .closed {
                return isCurrentScreenBuiltin ? 170 : 145
            } else if isAntigravityActive {
                return isCurrentScreenBuiltin ? 190 : 160
            } else if isDualActivityActive {
                return isCurrentScreenBuiltin ? 150 : 130
            } else if shouldShowPomodoroInlineClosedVisual {
                return isCurrentScreenBuiltin ? 172 : 144
            } else if shouldShowMusicClosedVisual {
                return isCurrentScreenBuiltin ? 150 : 130
            } else if shouldShowCalendarClosedVisual {
                return isCurrentScreenBuiltin ? 140 : 115
            } else {
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
        } else if isDualActivityActive {
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
        } else if shouldShowPomodoroInlineClosedVisual {
            if isCurrentDisplayIsland {
                chinWidth = isCurrentScreenBuiltin ? 172 : 144
            } else if isCurrentScreenBuiltin {
                chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 40)
            } else {
                chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 24)
            }
        } else if shouldShowMusicClosedVisual {
            if isCurrentDisplayIsland {
                chinWidth = isCurrentScreenBuiltin ? 150 : 130
            } else if isCurrentScreenBuiltin {
                chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 38)
            } else {
                chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 24)
            }
        } else if shouldShowCalendarClosedVisual {
            chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 24)
        } else if !coordinator.expandingView.show && vm.notchState == .closed
            && (!musicManager.isPlaying && musicManager.isPlayerIdle) && Defaults[.showNotHumanFace]
            && !vm.hideOnClosed
        {
            chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 24)
        }

        return chinWidth
    }

    private var isAntigravityActive: Bool {
        ((coordinator.expandingView.type == .antigravity && coordinator.expandingView.show) || antigravityManager.isVisible)
            && antigravityManager.currentPhase != .idle
            && vm.notchState == .closed
    }

    private var desiredOpenNotchWidth: CGFloat {
        switch coordinator.currentView {
        case .home:
            return isCurrentDisplayIsland ? 385 : 435
        case .shelf:
            return 560
        case .calendar:
            return 560
        }
    }

    private var desiredOpenNotchHeight: CGFloat {
        switch coordinator.currentView {
        case .home:
            return 188
        case .shelf:
            return 190
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

    private var hasActiveFeature: Bool {
        if coordinator.expandingView.show { return true }
        if coordinator.sneakPeek.show { return true }
        if isDualActivityActive { return true }
        if shouldShowMusicClosedVisual { return true }
        if shouldShowPomodoroInlineClosedVisual { return true }
        if shouldShowCalendarClosedVisual { return true }
        if DinoCoordinator.shared.activeSlot != .idle { return true }
        if activeModule != .none && activeModule != .music && activeModule != .coding { return true }
        if activeModule == .calendar && showCalendar { return true }
        if !musicManager.isPlayerIdle || musicManager.isPlaying { return true }
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
            withAnimation(.smooth) {
                applyChange()
            }
        } else {
            applyChange()
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
            if isCurrentDisplayIsland && effectiveIslandVisibility == .onHover {
                // Continuous vertical hover bridge from menubar down to dropped island
                Color.clear
                    .frame(width: max(220, vm.closedNotchSize.width + 60), height: 110)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        handleHover(hovering)
                    }
                    .onTapGesture {
                        handleTap()
                    }
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
                            .animation(animationSpring, value: pomodoroEnabled)
                            .animation(animationSpring, value: pomodoroClosedNotchDisplayMode)
                            .animation(animationSpring, value: shouldShowPomodoroInlineClosedVisual)
                            .animation(animationSpring, value: activeModule)
                            .animation(animationSpring, value: computedChinWidth)
                            .animation(animationSpring, value: DinoCoordinator.shared.activeSlot)
                            .animation(animationSpring, value: isShowingInlineMusicPlaybackPeek)
                            .animation(animationSpring, value: isAntigravityActive)
                            .animation(animationSpring, value: isShowingMusicSneakPeek)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: islandCornerRadius, style: .continuous))
                    .onHover { hovering in
                        handleHover(hovering)
                    }
                    .onTapGesture {
                        handleTap()
                    }
                    .conditionalModifier(Defaults[.enableGestures]) { view in
                        view
                            .panGesture(direction: .down) { translation, phase in
                                handleDownGesture(translation: translation, phase: phase)
                            }
                    }
                    .conditionalModifier(Defaults[.closeGestureEnabled] && Defaults[.enableGestures]) { view in
                        view
                            .panGesture(direction: .up) { translation, phase in
                                handleUpGesture(translation: translation, phase: phase)
                            }
                    }
                    .conditionalModifier(Defaults[.changeMediaWithGesture] && Defaults[.enableGestures]) { view in
                        view
                            .panGesture(direction: .right) { translation, phase in
                                handleHorizontalMediaGesture(translation: translation, phase: phase, direction: .right)
                            }
                            .panGesture(direction: .left) { translation, phase in
                                handleHorizontalMediaGesture(translation: translation, phase: phase, direction: .left)
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
                                        self.vm.close()
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: vm.notchState) { _, newState in
                        showCoverHoverMusicDetails = false
                        coordinator.toggleSneakPeek(status: false, type: .music, duration: 0)
                        if newState == .open {
                            updateOpenNotchWidth()
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
                    .onChange(of: webcamManager.cameraAvailable) { _, _ in
                        updateOpenNotchWidth()
                    }
                    .onChange(of: musicManager.songTitle) { _, newTitle in
                        guard !newTitle.isEmpty else { return }
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                            coverRotationY -= 180
                        }
                        if vm.notchState == .closed && !vm.hideOnClosed {
                            coordinator.toggleSneakPeek(status: true, type: .music, duration: 4.5)
                        }
                    }
                    .onChange(of: coordinator.sneakPeek.show) { _, isShowing in
                        if isShowing && coordinator.sneakPeek.type == .music && vm.notchState == .closed {
                            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                                coverRotationY -= 180
                            }
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
                                        self.vm.close()
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

            if batteryModel.isCustomToastPresented && Defaults[.batteryToastEnabled] && Defaults[.batteryToastType] == .customToast && vm.notchState == .closed && batteryModel.alertPosition != "Center" {
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
                    vm.close()
                }
            }
        }
    }

    @ViewBuilder
    private var mainPillView: some View {
        NotchLayout()
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

    @ViewBuilder
    private var islandContainerView: some View {
        HStack(alignment: .top, spacing: 8) {
            mainPillView
                .contentShape(RoundedRectangle(cornerRadius: islandCornerRadius, style: .continuous))
                .onTapGesture {
                    if vm.notchState == .closed {
                        openMusicWithSpring()
                    }
                }

            if isCurrentDisplayIsland && isDualActivityActive && vm.notchState == .closed {
                PomodoroCompanionCircleView(
                    isCurrentScreenBuiltin: isCurrentScreenBuiltin,
                    islandStyle: islandStyle,
                    isHovering: isHovering,
                    onOpenPomodoro: {
                        openPomodoroWithSpring()
                    }
                )
                .opacity(isShowingMusicSneakPeek ? 0 : 1)
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                        removal: .scale(scale: 0.5).combined(with: .opacity)
                    )
                )
            }
        }
    }

    @ViewBuilder
    func NotchLayout() -> some View {
        VStack(spacing: 0) {
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
                    if coordinator.expandingView.type == .battery && coordinator.expandingView.show
                        && vm.notchState == .closed
                    {
                        if Defaults[.batteryToastType] == .dynamicNotch {
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
                    } else if isAntigravityActive {
                        AntigravityLiveActivity()
                            .frame(width: computedChinWidth, height: vm.effectiveClosedNotchHeight, alignment: .center)
                            .clipped()
                            .transition(.opacity)
                    } else if coordinator.sneakPeek.show && Defaults[.inlineHUD] && (coordinator.sneakPeek.type != .music) && (coordinator.sneakPeek.type != .battery) && vm.notchState == .closed {
                          InlineHUD(type: $coordinator.sneakPeek.type, value: $coordinator.sneakPeek.value, icon: $coordinator.sneakPeek.icon, hoverAnimation: $isHovering, gestureProgress: $gestureProgress)
                              .transition(.opacity)
                      } else if DinoCoordinator.shared.activeSlot == .weather && vm.notchState == .closed {
                          WeatherClosedPillView()
                              .frame(width: isCurrentDisplayIsland ? 110 : (vm.closedNotchSize.width + 10), height: vm.effectiveClosedNotchHeight)
                              .transition(.opacity)
                      } else if isDualActivityActive {
                          MusicLiveActivity()
                              .frame(alignment: .center)
                              .transition(.opacity)
                      } else if shouldShowPomodoroInlineClosedVisual {
                          PomodoroClosedNotchView(
                              isCurrentDisplayIsland: isCurrentDisplayIsland,
                              isCurrentScreenBuiltin: isCurrentScreenBuiltin
                          )
                          .transition(.opacity)
                      } else if shouldShowMusicClosedVisual {
                          MusicLiveActivity()
                              .frame(alignment: .center)
                      } else if shouldShowCalendarClosedVisual {
                          CalendarClosedNotchView(
                              isCurrentDisplayIsland: isCurrentDisplayIsland,
                              isCurrentScreenBuiltin: isCurrentScreenBuiltin
                          )
                          .transition(.opacity)
                      } else if !coordinator.expandingView.show && vm.notchState == .closed && (!musicManager.isPlaying && musicManager.isPlayerIdle) && Defaults[.showNotHumanFace] && !vm.hideOnClosed  {
                          BoringFaceAnimation()
                       } else if vm.notchState == .open {
                           EmptyView()
                       } else {
                           Rectangle().fill(.clear).frame(width: vm.closedNotchSize.width - 20, height: vm.effectiveClosedNotchHeight)
                       }

                      if coordinator.sneakPeek.show {
                          if (coordinator.sneakPeek.type != .music) && (coordinator.sneakPeek.type != .battery) && !Defaults[.inlineHUD] && vm.notchState == .closed {
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
              }
              .conditionalModifier(
                  coordinator.sneakPeek.show && (coordinator.sneakPeek.type != .music) && (coordinator.sneakPeek.type != .battery) && (vm.notchState == .closed)
              ) { view in
                  view
                      .fixedSize()
              }
              .zIndex(2)
            if vm.notchState == .open {
                VStack {
                    switch coordinator.currentView {
                    case .home, .calendar:
                        NotchHomeView(albumArtNamespace: albumArtNamespace)
                    case .shelf:
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(
                    .scale(scale: 0.8, anchor: .top)
                    .combined(with: .opacity)
                    .animation(.smooth(duration: 0.35))
                )
                .zIndex(1)
                .allowsHitTesting(vm.notchState == .open)
                .opacity(gestureProgress != 0 ? 1.0 - min(abs(gestureProgress) * 0.1, 0.3) : 1.0)
            }
        }
        .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], delegate: GeneralDropTargetDelegate(isTargeted: $vm.generalDropTargeting))
    }

    @ViewBuilder
    func BoringFaceAnimation() -> some View {
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
        }.frame(
            height: vm.effectiveClosedNotchHeight,
            alignment: .center
        )
    }

    @ViewBuilder
    func MusicLiveActivity() -> some View {
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
                        Text(pomodoroManager.formattedRemainingTime)
                            .font(.system(size: isCurrentScreenBuiltin ? 12.5 : 11.0, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(pomodoroManager.isBreakPhase ? Color.green : Color.white)
                            .lineLimit(1)
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
        Defaults[.activeModule] = .music
        coordinator.currentView = .home
        doOpen()
    }

    private func openPomodoroWithSpring() {
        if Defaults[.enableHaptics] {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            haptics.toggle()
        }
        Defaults[.activeModule] = .pomodoro
        Defaults[.pomodoroEnabled] = true
        coordinator.currentView = .home
        doOpen()
    }

    private func handleTap() {
        if vm.notchState == .open {
            return
        }
        if hasActiveFeature {
            if isDualActivityActive {
                if activeModule == .pomodoro || DinoCoordinator.shared.activeSlot == .pomodoro {
                    openPomodoroWithSpring()
                } else {
                    openMusicWithSpring()
                }
                return
            } else if shouldShowPomodoroInlineClosedVisual || DinoCoordinator.shared.activeSlot == .pomodoro {
                Defaults[.activeModule] = .pomodoro
                Defaults[.pomodoroEnabled] = true
                coordinator.currentView = .home
            } else if shouldShowMusicClosedVisual || DinoCoordinator.shared.activeSlot == .music {
                Defaults[.activeModule] = .music
                coordinator.currentView = .home
            } else if shouldShowCalendarClosedVisual || DinoCoordinator.shared.activeSlot == .calendar {
                Defaults[.activeModule] = .calendar
                coordinator.currentView = .home
            } else if DinoCoordinator.shared.activeSlot == .weather {
                coordinator.currentView = .home
            }
            doOpen()
        } else {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.52, blendDuration: 0)) {
                emptyClickBounce = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.65, blendDuration: 0)) {
                    emptyClickBounce = false
                }
            }
        }
    }

    private func doOpen() {
        showCoverHoverMusicDetails = false
        coordinator.toggleSneakPeek(status: false, type: .music, duration: 0)
        withAnimation(animationSpring) {
            vm.open()
            vm.notchSize = .init(width: desiredOpenNotchWidth, height: desiredOpenNotchHeight)
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
            
            guard vm.notchState == .closed,
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
            scaleHoverTask?.cancel()
            scaleHoverTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.82)) {
                    self.isScaleHovered = false
                }
            }
            
            hoverTask = Task {
                let delay = max(0.20, Defaults[.collapseDelay])
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    if self.vm.notchState == .open && !self.vm.isBatteryPopoverActive && !SharingStateManager.shared.preventNotchClose {
                        self.showCoverHoverMusicDetails = false
                        self.coordinator.toggleSneakPeek(status: false, type: .music, duration: 0)
                        // 1. Morph open notch back to closed island pill
                        self.vm.close()
                        
                        // 2. Allow collapse animation to complete and stay visible briefly, then retract up and disappear
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(750))
                            guard !Task.isCancelled else { return }
                            if self.vm.notchState == .closed {
                                withAnimation(self.animationSpring) {
                                    self.isHovering = false
                                }
                            }
                        }
                    } else {
                        withAnimation(self.animationSpring) {
                            self.isHovering = false
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
            gestureProgress = (translation / Defaults[.gestureSensitivity]) * 20
        }

        if translation > Defaults[.gestureSensitivity] {
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
            gestureProgress = (translation / Defaults[.gestureSensitivity]) * -20
        }

        if phase == .ended {
            withAnimation(animationSpring) {
                gestureProgress = .zero
            }
        }

        if translation > Defaults[.gestureSensitivity] {
            withAnimation(animationSpring) {
                isHovering = false
            }
            if !SharingStateManager.shared.preventNotchClose { 
                gestureProgress = .zero
                vm.close()
            }

            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
        }
    }

    // MARK: - Horizontal Media Gesture

    private func handleHorizontalMediaGesture(translation: CGFloat, phase: NSEvent.Phase, direction: PanDirection) {
        // Only works when music is playing and notch is closed
        guard vm.notchState == .closed,
              musicManager.isPlaying,
              !musicManager.isPlayerIdle else { return }

        let gestureDirection: MediaGestureDirection = direction == .right ? .right : .left

        if phase == .ended {
            // Trigger the track change if threshold met
            if translation > Defaults[.gestureSensitivity] * 0.5 {
                if gestureDirection == .right {
                    MusicManager.shared.previousTrack()
                } else {
                    MusicManager.shared.nextTrack()
                }
                if Defaults[.enableHaptics] {
                    haptics.toggle()
                }
            }

            // Reset gesture state after a delay for smooth icon disappearance
            mediaGestureTask?.cancel()
            mediaGestureTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.3)) {
                        mediaGestureIconVisible = false
                    }
                }
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    mediaGestureDirection = .none
                }
            }
            return
        }

        // Show the direction icon
        if mediaGestureDirection != gestureDirection {
            mediaGestureDirection = gestureDirection
            // Brief delay before showing icon for smooth appearance
            mediaGestureTask?.cancel()
            withAnimation(.easeOut(duration: 0.15)) {
                mediaGestureIconVisible = false
            }
            mediaGestureTask = Task {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
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

#Preview {
    let vm = BoringViewModel()
    vm.open()
    return ContentView()
        .environmentObject(vm)
        .frame(width: vm.notchSize.width, height: vm.notchSize.height)
}
