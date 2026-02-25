//
//  NotchHomeView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-18.
//  Modified by Harsh Vardhan Goswami & Richard Kunkli & Mustafa Ramadan
//

import Combine
import Defaults
import SwiftUI

// MARK: - Music Player Components

struct MusicPlayerView: View {
    @EnvironmentObject var vm: BoringViewModel
    let albumArtNamespace: Namespace.ID

    var body: some View {
        MusicControlsView(albumArtNamespace: albumArtNamespace)
    }
}

struct AlbumArtView: View {
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var vm: BoringViewModel
    let albumArtNamespace: Namespace.ID

    var body: some View {
        albumArtButton
    }

    private var albumArtButton: some View {
        ZStack {
            Button {
                musicManager.openMusicApp()
            } label: {
                albumArtImage
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(musicManager.isPlaying ? 1 : 0.85)
            
            albumArtDarkOverlay
        }
    }

    private var albumArtDarkOverlay: some View {
        Rectangle()
            .aspectRatio(1, contentMode: .fit)
            .foregroundColor(Color.black)
            .opacity(musicManager.isPlaying ? 0 : 0.8)
            .blur(radius: 50)
    }
                

    private var albumArtImage: some View {
        Image(nsImage: musicManager.albumArt)
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
            .clipped()
            .clipShape(
                RoundedRectangle(
                    cornerRadius: Defaults[.cornerRadiusScaling]
                        ? MusicPlayerImageSizes.cornerRadiusInset.opened
                        : MusicPlayerImageSizes.cornerRadiusInset.closed)
            )
    }
}

struct MusicControlsView: View {
    @ObservedObject var musicManager = MusicManager.shared
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var webcamManager = WebcamManager.shared
    let albumArtNamespace: Namespace.ID
    @State private var sliderValue: Double = 0
    @State private var dragging: Bool = false
    @State private var lastDragged: Date = .distantPast
    @Default(.musicControlSlots) private var slotConfig
    @Default(.musicControlSlotLimit) private var slotLimit

    var body: some View {
        VStack(spacing: 12) {
            topInfoRow
            progressRow
            slotToolbar
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(PlainButtonStyle())
    }

    private var topInfoRow: some View {
        HStack(alignment: .center) {
            HStack(alignment: .center, spacing: 12) {
                AlbumArtView(vm: vm, albumArtNamespace: albumArtNamespace)
                    .frame(width: 66, height: 66)

                GeometryReader { geo in
                    VStack(alignment: .leading, spacing: 2) {
                        Spacer(minLength: 0)
                        songInfo(width: geo.size.width)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
            .frame(height: 66)

            Spacer(minLength: 10)

            visualizerView
                .frame(width: 28, height: 28, alignment: .trailing)
        }
    }

    private var visualizerView: some View {
        Group {
            if Defaults[.useMusicVisualizer] {
                Rectangle()
                    .fill(
                        Defaults[.coloredSpectrogram]
                            ? Color(nsColor: musicManager.avgColor).gradient
                            : Color.gray.gradient
                    )
                    .mask {
                        AudioSpectrumView(isPlaying: $musicManager.isPlaying)
                            .frame(width: 18, height: 14)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            } else {
                LottieAnimationContainer()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
        }
    }

    private var progressRow: some View {
        TimelineView(.animation(minimumInterval: musicManager.playbackRate > 0 ? 0.1 : nil)) { timeline in
            HStack(alignment: .center, spacing: 0.5) {
                Text(timeString(from: sliderValue))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(width: 38, alignment: .leading)

                CustomSlider(
                    value: $sliderValue,
                    range: 0...musicManager.songDuration,
                    color: Defaults[.sliderColor] == SliderColorEnum.albumArt
                        ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.8)
                        : Defaults[.sliderColor] == SliderColorEnum.accent ? .effectiveAccent : .white,
                    dragging: $dragging,
                    lastDragged: $lastDragged,
                    onValueChange: { newValue in
                        MusicManager.shared.seek(to: newValue)
                    },
                    onDragChange: { newValue in
                        MusicManager.shared.seek(to: newValue)
                    }
                )
                .frame(maxWidth: .infinity)
                .frame(height: 10)

                Text(timeString(from: musicManager.songDuration))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(width: 38, alignment: .trailing)
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(
                Defaults[.playerColorTinting]
                    ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.6)
                    : .gray
            )
            .onChange(of: timeline.date) {
                guard !dragging, musicManager.timestampDate.timeIntervalSince(lastDragged) > -1 else { return }
                sliderValue = MusicManager.shared.estimatedPlaybackPosition(at: timeline.date)
            }
        }
    }

    private func songInfo(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MarqueeText(
                $musicManager.songTitle, font: .headline, nsFont: .headline, textColor: .white,
                frameWidth: width)
            MarqueeText(
                $musicManager.artistName,
                font: .headline,
                nsFont: .headline,
                textColor: Defaults[.playerColorTinting]
                    ? Color(nsColor: musicManager.avgColor)
                        .ensureMinimumBrightness(factor: 0.6) : .gray,
                frameWidth: width
            )
            .fontWeight(.medium)
            if Defaults[.enableLyrics] {
                TimelineView(.animation(minimumInterval: 0.25)) { timeline in
                    let currentElapsed: Double = {
                        guard musicManager.isPlaying else { return musicManager.elapsedTime }
                        let delta = timeline.date.timeIntervalSince(musicManager.timestampDate)
                        let progressed = musicManager.elapsedTime + (delta * musicManager.playbackRate)
                        return min(max(progressed, 0), musicManager.songDuration)
                    }()
                    let line: String = {
                        if musicManager.isFetchingLyrics { return "Loading lyrics…" }
                        if !musicManager.syncedLyrics.isEmpty {
                            return musicManager.lyricLine(at: currentElapsed)
                        }
                        let trimmed = musicManager.currentLyrics.trimmingCharacters(in: .whitespacesAndNewlines)
                        return trimmed.isEmpty ? "No lyrics found" : trimmed.replacingOccurrences(of: "\n", with: " ")
                    }()
                    let isPersian = line.unicodeScalars.contains { scalar in
                        let v = scalar.value
                        return v >= 0x0600 && v <= 0x06FF
                    }
                    MarqueeText(
                        .constant(line),
                        font: .subheadline,
                        nsFont: .subheadline,
                        textColor: musicManager.isFetchingLyrics ? .gray.opacity(0.7) : .gray,
                        frameWidth: width
                    )
                    .font(isPersian ? .custom("Vazirmatn-Regular", size: NSFont.preferredFont(forTextStyle: .subheadline).pointSize) : .subheadline)
                    .lineLimit(1)
                    .opacity(musicManager.isPlaying ? 1 : 0)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var musicSlider: some View {
        TimelineView(.animation(minimumInterval: musicManager.playbackRate > 0 ? 0.1 : nil)) { timeline in
            MusicSliderView(
                sliderValue: $sliderValue,
                duration: $musicManager.songDuration,
                lastDragged: $lastDragged,
                color: musicManager.avgColor,
                dragging: $dragging,
                currentDate: timeline.date,
                timestampDate: musicManager.timestampDate,
                elapsedTime: musicManager.elapsedTime,
                playbackRate: musicManager.playbackRate,
                isPlaying: musicManager.isPlaying
            ) { newValue in
                MusicManager.shared.seek(to: newValue)
            }
            .padding(.top, 5)
            .frame(height: 36)
        }
    }

    private var slotToolbar: some View {
        let slots = activeSlots
        return HStack(spacing: 6) {
            ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                slotView(for: slot)
                    .frame(alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func timeString(from seconds: Double) -> String {
        let totalMinutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }

    private var activeSlots: [MusicControlButton] {
        let sanitizedLimit = min(
            max(slotLimit, MusicControlButton.minSlotCount),
            MusicControlButton.maxSlotCount
        )
        let padded = slotConfig.padded(to: sanitizedLimit, filler: .none)
        let result = Array(padded.prefix(sanitizedLimit))
        // If calendar and camera are both visible alongside music, hide the edge slots
        let shouldHideEdges = Defaults[.showCalendar] && Defaults[.showMirror] && webcamManager.cameraAvailable && vm.isCameraExpanded
        if shouldHideEdges && result.count >= 5 {
            return Array(result.dropFirst().dropLast())
        }

        return result
    }

    @ViewBuilder
    private func slotView(for slot: MusicControlButton) -> some View {
        let hoverCornerRadius: CGFloat = Defaults[.cornerRadiusScaling]
            ? MusicPlayerImageSizes.cornerRadiusInset.opened
            : MusicPlayerImageSizes.cornerRadiusInset.closed

        switch slot {
        case .shuffle:
            HoverButton(
                icon: "shuffle",
                iconColor: musicManager.isShuffled ? .red : .primary,
                scale: .medium,
                cornerRadius: hoverCornerRadius
            ) {
                MusicManager.shared.toggleShuffle()
            }
        case .previous:
            HoverButton(icon: "backward.fill", scale: .medium, cornerRadius: hoverCornerRadius) {
                MusicManager.shared.previousTrack()
            }
        case .playPause:
            HoverButton(
                icon: musicManager.isPlaying ? "pause.fill" : "play.fill",
                scale: .large,
                cornerRadius: hoverCornerRadius
            ) {
                MusicManager.shared.togglePlay()
            }
        case .next:
            HoverButton(icon: "forward.fill", scale: .medium, cornerRadius: hoverCornerRadius) {
                MusicManager.shared.nextTrack()
            }
        case .repeatMode:
            HoverButton(
                icon: repeatIcon,
                iconColor: repeatIconColor,
                scale: .medium,
                cornerRadius: hoverCornerRadius
            ) {
                MusicManager.shared.toggleRepeat()
            }
        case .volume:
            VolumeControlView()
        case .favorite:
            FavoriteControlButton(cornerRadius: hoverCornerRadius)
        case .goBackward:
            HoverButton(icon: "gobackward.15", scale: .medium, cornerRadius: hoverCornerRadius) {
                MusicManager.shared.skip(seconds: -15)
            }
        case .goForward:
            HoverButton(icon: "goforward.15", scale: .medium, cornerRadius: hoverCornerRadius) {
                MusicManager.shared.skip(seconds: 15)
            }
        case .none:
            Color.clear.frame(height: 1)
        }
    }

    private var repeatIcon: String {
        switch musicManager.repeatMode {
        case .off:
            return "repeat"
        case .all:
            return "repeat"
        case .one:
            return "repeat.1"
        }
    }

    private var repeatIconColor: Color {
        switch musicManager.repeatMode {
        case .off:
            return .primary
        case .all, .one:
            return .red
        }
    }
}

struct FavoriteControlButton: View {
    @ObservedObject var musicManager = MusicManager.shared
    var cornerRadius: CGFloat? = nil

    var body: some View {
        HoverButton(icon: iconName, iconColor: iconColor, scale: .medium, cornerRadius: cornerRadius) {
            MusicManager.shared.toggleFavoriteTrack()
        }
        .disabled(!musicManager.canFavoriteTrack)
        .opacity(musicManager.canFavoriteTrack ? 1 : 0.35)
    }

    private var iconName: String {
        musicManager.isFavoriteTrack ? "heart.fill" : "heart"
    }

    private var iconColor: Color {
        musicManager.isFavoriteTrack ? .red : .primary
    }
}

private extension Array where Element == MusicControlButton {
    func padded(to length: Int, filler: MusicControlButton) -> [MusicControlButton] {
        if count >= length { return self }
        return self + Array(repeating: filler, count: length - count)
    }
}

// MARK: - Volume Control View

struct VolumeControlView: View {
    @ObservedObject var musicManager = MusicManager.shared
    @State private var volumeSliderValue: Double = 0.5
    @State private var dragging: Bool = false
    @State private var showVolumeSlider: Bool = false
    @State private var lastVolumeUpdateTime: Date = Date.distantPast
    private let volumeUpdateThrottle: TimeInterval = 0.1
    
    var body: some View {
        HStack(spacing: 4) {
            Button(action: {
                if musicManager.volumeControlSupported {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        showVolumeSlider.toggle()
                    }
                }
            }) {
                Image(systemName: volumeIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(musicManager.volumeControlSupported ? .white : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!musicManager.volumeControlSupported)
            .frame(width: 24)

            if showVolumeSlider && musicManager.volumeControlSupported {
                CustomSlider(
                    value: $volumeSliderValue,
                    range: 0.0...1.0,
                    color: .white,
                    dragging: $dragging,
                    lastDragged: .constant(Date.distantPast),
                    onValueChange: { newValue in
                        MusicManager.shared.setVolume(to: newValue)
                    },
                    onDragChange: { newValue in
                        let now = Date()
                        if now.timeIntervalSince(lastVolumeUpdateTime) > volumeUpdateThrottle {
                            MusicManager.shared.setVolume(to: newValue)
                            lastVolumeUpdateTime = now
                        }
                    }
                )
                .frame(width: 48, height: 8)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .clipped()
        .onReceive(musicManager.$volume) { volume in
            if !dragging {
                volumeSliderValue = volume
            }
        }
        .onReceive(musicManager.$volumeControlSupported) { supported in
            if !supported {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showVolumeSlider = false
                }
            }
        }
        .onChange(of: showVolumeSlider) { _, isShowing in
            if isShowing {
                // Sync volume from app when slider appears
                Task {
                    await MusicManager.shared.syncVolumeFromActiveApp()
                }
            }
        }
        .onDisappear {
            // volumeUpdateTask?.cancel() // No longer needed
        }
    }
    
    
    private var volumeIcon: String {
        if !musicManager.volumeControlSupported {
            return "speaker.slash"
        } else if volumeSliderValue == 0 {
            return "speaker.slash.fill"
        } else if volumeSliderValue < 0.33 {
            return "speaker.1.fill"
        } else if volumeSliderValue < 0.66 {
            return "speaker.2.fill"
        } else {
            return "speaker.3.fill"
        }
    }
}

// MARK: - Main View

struct NotchHomeView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var webcamManager = WebcamManager.shared
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject var pomodoroManager = PomodoroManager.shared
    let albumArtNamespace: Namespace.ID

    @State private var homeCarouselPosition: Int? = 0
    @State private var isPomodoroMirrorEnabled: Bool = false

    var body: some View {
        Group {
            if !coordinator.firstLaunch {
                mainContent
            }
        }
        // simplified: use a straightforward opacity transition
        .transition(.opacity)
    }

    private var shouldShowCamera: Bool {
        Defaults[.showMirror] && webcamManager.cameraAvailable && vm.isCameraExpanded
    }

    private var shouldShowPomodoro: Bool {
        Defaults[.pomodoroEnabled] && vm.notchState == .open
    }

    private var shouldShowCalendar: Bool {
        Defaults[.showCalendar] && vm.notchState == .open
    }

    private let headerReplacementTopPadding: CGFloat = 10
    private let otherPagesTopPadding: CGFloat = 40
    private let playerTopPadding: CGFloat = 20

    private var enabledPages: [Int] {
        var pages = [0]
        if shouldShowPomodoro { pages.append(1) }
        if shouldShowCalendar { pages.append(2) }
        return pages
    }

    private var mainContent: some View {
        GeometryReader { geo in
            let indicatorHeight: CGFloat = enabledPages.count > 1 ? 8 : 0
            VStack(spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(enabledPages, id: \.self) { pageIndex in
                            Group {
                                switch pageIndex {
                                case 0:
                                    playerPage
                                case 1:
                                    pomodoroPage
                                case 2:
                                    calendarPage
                                default:
                                    EmptyView()
                                }
                            }
                            .frame(width: geo.size.width, height: max(0, geo.size.height - indicatorHeight - 10), alignment: .top)
                            .id(pageIndex)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.never)
                .scrollPosition(id: $homeCarouselPosition)
                .scrollTargetBehavior(.paging)

                if enabledPages.count > 1 {
                    pageIndicator
                        .frame(height: 8)
                }

            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
        .blur(radius: vm.notchState == .closed ? 30 : 0)
        .onChange(of: shouldShowPomodoro) { _, _ in
            normalizeCarouselPosition()
        }
        .onChange(of: shouldShowCalendar) { _, _ in
            normalizeCarouselPosition()
        }
    }

    private func normalizeCarouselPosition() {
        let current = homeCarouselPosition ?? 0
        guard !enabledPages.contains(current) else { return }
        homeCarouselPosition = enabledPages.first
    }

    private var playerPage: some View {
        GeometryReader { pageGeo in
            let hasSecondaryPanel = shouldShowCamera
            let spacing: CGFloat = hasSecondaryPanel ? 12 : 0
            let sidePanelWidth: CGFloat = hasSecondaryPanel ? 160 : 0
            let musicWidth = max(0, pageGeo.size.width - sidePanelWidth - spacing)

            HStack(alignment: .top, spacing: 0) {
                MusicPlayerView(albumArtNamespace: albumArtNamespace)
                    .frame(width: musicWidth, alignment: .leading)

                if hasSecondaryPanel {
                    Spacer(minLength: spacing)
                }

                if shouldShowCamera {
                    CameraPreviewView(webcamManager: webcamManager)
                        .scaledToFit()
                        .frame(width: sidePanelWidth, alignment: .trailing)
                        .opacity(vm.notchState == .closed ? 0 : 1)
                        .blur(radius: vm.notchState == .closed ? 20 : 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.8, blendDuration: 0), value: shouldShowCamera)
        }
        .padding(.horizontal, 8)
        .padding(.top, playerTopPadding)
    }

    private var pomodoroPage: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("Pomodoro")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Spacer(minLength: 0)

                Button {
                    guard Defaults[.showMirror] && webcamManager.cameraAvailable else { return }
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isPomodoroMirrorEnabled.toggle()
                    }
                } label: {
                    Image(systemName: "video")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity((Defaults[.showMirror] && webcamManager.cameraAvailable) ? 0.9 : 0.35))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!(Defaults[.showMirror] && webcamManager.cameraAvailable))
            }
            .padding(.top, 4)
            .padding(.horizontal, 8)

            PomodoroHomeSection(
                pomodoroManager: pomodoroManager,
                webcamManager: webcamManager,
                showMirror: isPomodoroMirrorEnabled
            )
            .padding(.top, 4)
            .opacity(shouldShowPomodoro ? 1 : 0.45)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var calendarPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            CalendarView()
        }
        .padding(.horizontal, 8)
        .padding(.top, otherPagesTopPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var pageIndicator: some View {
        let selected = homeCarouselPosition ?? 0
        let selectedIndex = enabledPages.firstIndex(of: selected) ?? 0
        return HStack(spacing: 6) {
            ForEach(0..<enabledPages.count, id: \.self) { idx in
                Capsule()
                    .fill(idx == selectedIndex ? Color.white.opacity(0.85) : Color.white.opacity(0.25))
                    .frame(width: idx == selectedIndex ? 14 : 6, height: 6)
                    .animation(.easeInOut(duration: 0.18), value: selectedIndex)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PomodoroHomeSection: View {
    @ObservedObject var pomodoroManager: PomodoroManager
    @ObservedObject var webcamManager: WebcamManager
    let showMirror: Bool

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let progressSize = min(geo.size.height - 32, 132)
            let clampedProgress = min(max(pomodoroManager.progress, 0), 1)
            let cycleLimit = max(1, Defaults[.pomodoroCycleBeforeLongBreak])
            let currentCycle = (pomodoroManager.completedFocusSessions % cycleLimit) + 1

            let primaryLabel: String = {
                switch pomodoroManager.state {
                case .idle:
                    return "Start"
                case .paused:
                    return "Resume"
                case .running:
                    return "Stop"
                }
            }()

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(pomodoroManager.phaseTitle) \(currentCycle)/\(cycleLimit)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)

                    Text(pomodoroManager.formattedRemainingTime)
                        .font(.system(size: size * 0.34, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Button {
                            pomodoroManager.reset()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(height: 30)
                                .padding(.horizontal, 8)
                                .background(Color.white.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            switch pomodoroManager.state {
                            case .idle:
                                pomodoroManager.start()
                            case .paused:
                                pomodoroManager.resume()
                            case .running:
                                pomodoroManager.pause()
                            }
                        } label: {
                            Text(primaryLabel)
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(height: 30)
                                .padding(.horizontal, 8)
                                .background(Color.white.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            pomodoroManager.skip()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(height: 30)
                                .padding(.horizontal, 8)
                                .background(Color.white.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.effectiveAccent.opacity(0.18))

                    Group {
                        if showMirror {
                            CameraPreviewView(webcamManager: webcamManager)
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        } else {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.12), lineWidth: 10)

                                Circle()
                                    .trim(from: 0, to: clampedProgress)
                                    .stroke(Color.effectiveAccent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                    .rotationEffect(.degrees(-90))

                                Button {
                                    pomodoroManager.togglePlayPause()
                                } label: {
                                    Circle()
                                        .fill(Color.black.opacity(0.55))
                                        .overlay {
                                            Image(systemName: pomodoroManager.isRunning ? "pause.fill" : "play.fill")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(16)
                        }
                    }
                }
                .frame(width: progressSize, height: progressSize)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
        }
    }
}

struct MusicSliderView: View {
    @Binding var sliderValue: Double
    @Binding var duration: Double
    @Binding var lastDragged: Date
    var color: NSColor
    @Binding var dragging: Bool
    let currentDate: Date
    let timestampDate: Date
    let elapsedTime: Double
    let playbackRate: Double
    let isPlaying: Bool
    var onValueChange: (Double) -> Void


    var body: some View {
        VStack {
            CustomSlider(
                value: $sliderValue,
                range: 0...duration,
                color: Defaults[.sliderColor] == SliderColorEnum.albumArt
                    ? Color(nsColor: color).ensureMinimumBrightness(factor: 0.8)
                    : Defaults[.sliderColor] == SliderColorEnum.accent ? .effectiveAccent : .white,
                dragging: $dragging,
                lastDragged: $lastDragged,
                onValueChange: onValueChange
            )
            .frame(height: 10, alignment: .center)

            HStack {
                Text(timeString(from: sliderValue))
                Spacer()
                Text(timeString(from: duration))
            }
            .fontWeight(.medium)
            .foregroundColor(
                Defaults[.playerColorTinting]
                    ? Color(nsColor: color).ensureMinimumBrightness(factor: 0.6) : .gray
            )
            .font(.caption)
        }
        .onChange(of: currentDate) {
           guard !dragging, timestampDate.timeIntervalSince(lastDragged) > -1 else { return }
            sliderValue = MusicManager.shared.estimatedPlaybackPosition(at: currentDate)
        }
    }

    func timeString(from seconds: Double) -> String {
        let totalMinutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }
}

struct CustomSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var color: Color = .white
    @Binding var dragging: Bool
    @Binding var lastDragged: Date
    var onValueChange: ((Double) -> Void)?
    var onDragChange: ((Double) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = CGFloat(dragging ? 9 : 5)
            let rangeSpan = range.upperBound - range.lowerBound

            let progress = rangeSpan == .zero ? 0 : (value - range.lowerBound) / rangeSpan
            let filledTrackWidth = min(max(progress, 0), 1) * width

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.gray.opacity(0.3))
                    .frame(height: height)

                Rectangle()
                    .fill(color)
                    .frame(width: filledTrackWidth, height: height)
            }
            .cornerRadius(height / 2)
            .frame(height: 10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        withAnimation {
                            dragging = true
                        }
                        let newValue = range.lowerBound + Double(gesture.location.x / width) * rangeSpan
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                        onDragChange?(value)
                    }
                    .onEnded { _ in
                        onValueChange?(value)
                        dragging = false
                        lastDragged = Date()
                    }
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: dragging)
        }
    }
}
