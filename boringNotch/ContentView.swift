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

    @Namespace var albumArtNamespace

    @Default(.useMusicVisualizer) var useMusicVisualizer
    @Default(.pomodoroEnabled) var pomodoroEnabled
    @Default(.pomodoroClosedNotchDisplayMode) var pomodoroClosedNotchDisplayMode
    @Default(.showMirror) var showMirror

    @Default(.showNotHumanFace) var showNotHumanFace

    // Shared interactive spring for movement/resizing to avoid conflicting animations
    private let animationSpring = Animation.interactiveSpring(response: 0.38, dampingFraction: 0.8, blendDuration: 0)

    private let extendedHoverPadding: CGFloat = 30
    private let zeroHeightHoverPadding: CGFloat = 10
    private let homeBaseOpenWidth: CGFloat = 560
    private let pomodoroReplaceWidthExpansion: CGFloat = 104

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

    private var computedChinWidth: CGFloat {
        var chinWidth: CGFloat = vm.closedNotchSize.width

        if coordinator.expandingView.type == .battery && coordinator.expandingView.show
            && vm.notchState == .closed && Defaults[.showPowerStatusNotifications]
        {
            chinWidth = 640
        } else if shouldShowPomodoroInlineClosedVisual {
            chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 20 + pomodoroReplaceWidthExpansion)
        } else if shouldShowMusicClosedVisual {
            chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 20)
        } else if !coordinator.expandingView.show && vm.notchState == .closed
            && (!musicManager.isPlaying && musicManager.isPlayerIdle) && Defaults[.showNotHumanFace]
            && !vm.hideOnClosed
        {
            chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 20)
        }

        return chinWidth
    }

    private var desiredOpenNotchWidth: CGFloat {
        switch coordinator.currentView {
        case .home:
            return homeBaseOpenWidth
        case .shelf:
            return 560
        case .calendar:
            return 560
        }
    }

    private var calendarTabContentWidth: CGFloat {
        max(420, desiredOpenNotchWidth - 70)
    }

    private var shouldShowPomodoroClosedContent: Bool {
        vm.notchState == .closed
            && pomodoroEnabled
            && pomodoroManager.hasActiveSession
            && !vm.hideOnClosed
    }

    private var shouldShowMusicClosedVisual: Bool {
        (!coordinator.expandingView.show || coordinator.expandingView.type == .music)
            && vm.notchState == .closed
            && (musicManager.isPlaying || !musicManager.isPlayerIdle)
            && coordinator.musicLiveActivityEnabled
            && !vm.hideOnClosed
    }

    private var isShowingInlineMusicPlaybackPeek: Bool {
        coordinator.expandingView.show
            && coordinator.expandingView.type == .music
            && Defaults[.sneakPeekStyles] == .inline
    }

    private var shouldShowPomodoroInlineClosedVisual: Bool {
        guard shouldShowPomodoroClosedContent else { return false }
        guard !isShowingInlineMusicPlaybackPeek else { return false }
        guard !(coordinator.sneakPeek.show && coordinator.sneakPeek.type == .music) else { return false }
        switch pomodoroClosedNotchDisplayMode {
        case .off:
            return false
        case .replaceMusicVisual, .countOnly, .controlsAndCount, .showInSneakPeek:
            return true
        }
    }

    private func updateOpenNotchWidth(animated: Bool = true) {
        guard vm.notchState == .open else { return }
        let targetWidth = desiredOpenNotchWidth
        guard abs(vm.notchSize.width - targetWidth) > 0.5 else { return }

        let applyChange = {
            vm.notchSize = .init(width: targetWidth, height: openNotchSize.height)
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
            VStack(spacing: 0) {
                let mainLayout = NotchLayout()
                    .frame(alignment: .top)
                    .padding(
                        .horizontal,
                        vm.notchState == .open
                        ? Defaults[.cornerRadiusScaling]
                        ? (cornerRadiusInsets.opened.top) : (cornerRadiusInsets.opened.bottom)
                        : cornerRadiusInsets.closed.bottom
                    )
                    .padding(.horizontal, vm.notchState == .open ? 12 : 0)
                    .padding(.bottom, vm.notchState == .open ? 12 : 0)
                    .background(.black)
                    .clipShape(currentNotchShape)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(.black)
                            .frame(height: 1)
                            .padding(.horizontal, topCornerRadius)
                    }
                    .shadow(
                        color: ((vm.notchState == .open || isHovering) && Defaults[.enableShadow])
                            ? .black.opacity(0.7) : .clear, radius: Defaults[.cornerRadiusScaling] ? 6 : 4
                    )
                    .padding(
                        .bottom,
                        vm.effectiveClosedNotchHeight == 0 ? 10 : 0
                    )
                
                mainLayout
                    .frame(
                        width: vm.notchState == .open ? vm.notchSize.width : nil,
                        height: vm.notchState == .open ? vm.notchSize.height : nil,
                        alignment: .top
                    )
                    .conditionalModifier(true) { view in
                        let openAnimation = Animation.interactiveSpring(response: 0.4, dampingFraction: 0.82, blendDuration: 0)
                        let closeAnimation = Animation.interactiveSpring(response: 0.42, dampingFraction: 0.84, blendDuration: 0)
                        
                        return view
                            .animation(vm.notchState == .open ? openAnimation : closeAnimation, value: vm.notchState)
                            .animation(.smooth, value: gestureProgress)
                            .animation(animationSpring, value: pomodoroEnabled)
                            .animation(animationSpring, value: pomodoroClosedNotchDisplayMode)
                            .animation(animationSpring, value: shouldShowPomodoroInlineClosedVisual)
                            .animation(animationSpring, value: isShowingInlineMusicPlaybackPeek)
                    }
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        handleHover(hovering)
                    }
                    .onTapGesture {
                        doOpen()
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
                        if newState == .open {
                            updateOpenNotchWidth()
                        }

                        if newState == .closed && isHovering {
                            withAnimation {
                                isHovering = false
                            }
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
                    vm.close()
                }
            }
        }
    }

    @ViewBuilder
    func NotchLayout() -> some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
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
                        && vm.notchState == .closed && Defaults[.showPowerStatusNotifications]
                    {
                        HStack(spacing: 0) {
                            HStack {
                                Text(batteryModel.statusText)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                            }

                            Rectangle()
                                .fill(.black)
                                .frame(width: vm.closedNotchSize.width + 10)

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
                      } else if coordinator.sneakPeek.show && Defaults[.inlineHUD] && (coordinator.sneakPeek.type != .music) && (coordinator.sneakPeek.type != .battery) && vm.notchState == .closed {
                          InlineHUD(type: $coordinator.sneakPeek.type, value: $coordinator.sneakPeek.value, icon: $coordinator.sneakPeek.icon, hoverAnimation: $isHovering, gestureProgress: $gestureProgress)
                              .transition(.opacity)
                      } else if shouldShowPomodoroInlineClosedVisual {
                          PomodoroClosedNotchView()
                              .transition(.opacity)
                      } else if shouldShowMusicClosedVisual {
                          MusicLiveActivity()
                              .frame(alignment: .center)
                      } else if !coordinator.expandingView.show && vm.notchState == .closed && (!musicManager.isPlaying && musicManager.isPlayerIdle) && Defaults[.showNotHumanFace] && !vm.hideOnClosed  {
                          BoringFaceAnimation()
                       } else if vm.notchState == .open {
                           BoringHeader()
                               .frame(height: max(24, vm.effectiveClosedNotchHeight))
                               .opacity(gestureProgress != 0 ? 1.0 - min(abs(gestureProgress) * 0.1, 0.3) : 1.0)
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
                          // Old sneak peek music
                          else if coordinator.sneakPeek.type == .music {
                              if vm.notchState == .closed && !vm.hideOnClosed && Defaults[.sneakPeekStyles] == .standard {
                                  HStack(alignment: .center) {
                                      Image(systemName: "music.note")
                                      GeometryReader { geo in
                                          MarqueeText(.constant(musicManager.songTitle + " - " + musicManager.artistName),  textColor: Defaults[.playerColorTinting] ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.6) : .gray, minDuration: 1, frameWidth: geo.size.width)
                                      }
                                  }
                                  .foregroundStyle(.gray)
                                  .padding(.bottom, 10)
                              }
                          }
                      }

                  }
              }
              .conditionalModifier((coordinator.sneakPeek.show && (coordinator.sneakPeek.type == .music) && vm.notchState == .closed && !vm.hideOnClosed && Defaults[.sneakPeekStyles] == .standard) || (coordinator.sneakPeek.show && (coordinator.sneakPeek.type != .music) && (vm.notchState == .closed))) { view in
                  view
                      .fixedSize()
              }
              .zIndex(2)
            if vm.notchState == .open {
                VStack {
                    switch coordinator.currentView {
                    case .home:
                        NotchHomeView(albumArtNamespace: albumArtNamespace)
                    case .shelf:
                        ShelfView()
                    case .calendar:
                        VStack(alignment: .leading, spacing: 0) {
                            CalendarView()
                                .frame(width: calendarTabContentWidth, alignment: .topLeading)
                        }
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
                    .fill(.black)
                    .frame(width: vm.closedNotchSize.width - 20)
                MinimalFaceFeatures()
            }
        }.frame(
            height: vm.effectiveClosedNotchHeight,
            alignment: .center
        )
    }

    @ViewBuilder
    func MusicLiveActivity() -> some View {
        let coverSize = max(0, vm.effectiveClosedNotchHeight - 12)
        let showGesturePrev = mediaGestureDirection == .right && mediaGestureIconVisible && musicManager.isPlaying
        let showGestureNext = mediaGestureDirection == .left && mediaGestureIconVisible && musicManager.isPlaying

        HStack {
            // MARK: Left side - Album art with gesture prev icon & hover sneak peek
            ZStack {
                Image(nsImage: musicManager.albumArt)
                    .resizable()
                    .clipped()
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: MusicPlayerImageSizes.cornerRadiusInset.closed)
                    )
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
            .onHover { hovering in
                isCoverHovering = hovering
                if hovering && vm.notchState == .closed && !musicManager.isPlayerIdle {
                    // Show sneak peek from bottom (standard style)
                    coordinator.toggleSneakPeek(
                        status: true,
                        type: .music,
                        duration: 0
                    )
                } else if !hovering {
                    // Dismiss sneak peek after a short delay
                    Task {
                        try? await Task.sleep(for: .milliseconds(600))
                        await MainActor.run {
                            if !isCoverHovering {
                                coordinator.toggleSneakPeek(status: false, type: .music, duration: 0)
                            }
                        }
                    }
                }
            }

            Rectangle()
                .fill(.black)
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
                            Spacer(minLength: vm.closedNotchSize.width)
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
                        : vm.closedNotchSize.width
                            + -cornerRadiusInsets.closed.top
                )

            // MARK: Right side - Visualizer with gesture next icon & hover play/pause
            ZStack {
                // Normal visualizer content
                HStack {
                    if useMusicVisualizer {
                        Rectangle()
                            .fill(
                                Defaults[.coloredSpectrogram]
                                    ? Color(nsColor: musicManager.avgColor).gradient
                                    : Color.gray.gradient
                            )
                            .frame(width: 50, alignment: .center)
                            .matchedGeometryEffect(id: "spectrum", in: albumArtNamespace)
                            .mask {
                                AudioSpectrumView(isPlaying: $musicManager.isPlaying)
                                    .frame(width: 16, height: 12)
                            }
                    } else {
                        LottieAnimationContainer()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
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
                if isVisualizerHovering && !showGestureNext && musicManager.isPlaying {
                    Button {
                        MusicManager.shared.togglePlay()
                    } label: {
                        Image(systemName: musicManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: coverSize * 0.45, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                }
            }
            .frame(
                width: max(
                    0,
                    vm.effectiveClosedNotchHeight - 12
                        + gestureProgress / 2
                ),
                height: max(
                    0,
                    vm.effectiveClosedNotchHeight - 12
                ),
                alignment: .center
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isVisualizerHovering = hovering && musicManager.isPlaying && vm.notchState == .closed
                }
            }
        }
        .frame(
            height: vm.effectiveClosedNotchHeight,
            alignment: .center
        )
    }

    @ViewBuilder
    func PomodoroClosedNotchView() -> some View {
        HStack(spacing: 12) {
            Text(pomodoroManager.formattedRemainingTime)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 6)

            HStack(spacing: 6) {
                Button {
                    pomodoroManager.togglePlayPause()
                } label: {
                    ZStack {
                        Circle().fill(Color.yellow)
                        Image(systemName: pomodoroManager.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.85))
                    }
                    .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)

                Button {
                    pomodoroManager.reset()
                } label: {
                    ZStack {
                        Circle().fill(Color.red)
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(
            width: vm.closedNotchSize.width + pomodoroReplaceWidthExpansion,
            height: vm.effectiveClosedNotchHeight,
            alignment: .center
        )
        .padding(.horizontal, 4)
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

    private func doOpen() {
        withAnimation(animationSpring) {
            vm.open()
            vm.notchSize = .init(width: desiredOpenNotchWidth, height: openNotchSize.height)
        }
    }

    // MARK: - Hover Management

    private func handleHover(_ hovering: Bool) {
        if coordinator.firstLaunch { return }
        hoverTask?.cancel()
        
        if hovering {
            withAnimation(animationSpring) {
                isHovering = true
            }
            
            if vm.notchState == .closed && Defaults[.enableHaptics] {
                haptics.toggle()
            }
            
            guard vm.notchState == .closed,
                  !coordinator.sneakPeek.show,
                  Defaults[.openNotchOnHover] else { return }
            
            hoverTask = Task {
                try? await Task.sleep(for: .seconds(Defaults[.minimumHoverDuration]))
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    guard self.vm.notchState == .closed,
                          self.isHovering,
                          !self.coordinator.sneakPeek.show else { return }
                    
                    self.doOpen()
                }
            }
        } else {
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    withAnimation(animationSpring) {
                        self.isHovering = false
                    }
                    
                    if self.vm.notchState == .open && !self.vm.isBatteryPopoverActive && !SharingStateManager.shared.preventNotchClose {
                        self.vm.close()
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
