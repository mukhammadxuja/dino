//
//  LockScreenPasscodePlayerView.swift
//  boringNotch
//

import SwiftUI
import Defaults

struct LockScreenPasscodePlayerView: View {
    @ObservedObject private var musicManager = MusicManager.shared
    @Default(.coloredSpectrogram) private var coloredSpectrogram
    @Default(.lockScreenPlayerBackgroundStyle) private var lockScreenPlayerBackgroundStyle
    @Default(.enableLyrics) private var enableLyrics
    @Default(.musicControlSlots) private var slotConfig
    @State private var sliderValue: Double = 0
    @State private var dragging = false
    @State private var lastDragged: Date = .distantPast

    private var shouldShowPlayer: Bool {
        musicManager.isPlaying || !musicManager.isPlayerIdle
    }

    private var duration: Double {
        max(0, musicManager.songDuration)
    }

    private let playerCornerRadius: CGFloat = 32

    var body: some View {
        ZStack {
            if shouldShowPlayer {
                VStack(alignment: .leading, spacing: 10) {
                    topRow
                    sliderBlock
                    controlsRow
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(width: 355, height: 176)
                .background {
                    playerBackground
                }
                .clipShape(RoundedRectangle(cornerRadius: playerCornerRadius, style: .continuous))
                .animation(.easeInOut(duration: 0.35), value: lockScreenPlayerBackgroundStyle)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.smooth(duration: 0.28), value: shouldShowPlayer)
    }

    // MARK: - Surface Background

    @ViewBuilder
    private var playerBackground: some View {
        let shape = RoundedRectangle(cornerRadius: playerCornerRadius, style: .continuous)

        switch lockScreenPlayerBackgroundStyle {
        case .glass:
            ZStack {
                VisualEffectBackground(material: .hudWindow, blendingMode: .withinWindow)
                Color.black.opacity(0.32)
            }
            .clipShape(shape)
            .overlay {
                shape.stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.38), Color.white.opacity(0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }

        case .solid:
            ZStack {
                Color.black
            }
            .clipShape(shape)
            .overlay {
                shape.stroke(Color.white.opacity(0.18), lineWidth: 0.9)
            }
        }
    }

    // MARK: - Top Info Row

    private var topRow: some View {
        HStack(alignment: .bottom, spacing: 14) {
            albumArtView
                .frame(width: 62, height: 62)

            GeometryReader { geo in
                VStack(alignment: .leading, spacing: 2) {
                    Spacer(minLength: 0)
                    songInfo(width: geo.size.width)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .frame(height: 62)
    }

    // MARK: - Album Art

    private var albumArtView: some View {
        ZStack {
            Button {
                musicManager.openMusicApp()
            } label: {
                Image(nsImage: musicManager.albumArt)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 62, height: 62)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(musicManager.isPlaying ? 1.0 : 0.88)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: musicManager.isPlaying)

            // Subtle dark overlay when paused
            Rectangle()
                .aspectRatio(1, contentMode: .fit)
                .foregroundColor(Color.black)
                .opacity(musicManager.isPlaying ? 0 : 0.35)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }

    // MARK: - Track Info

    private func songInfo(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 6) {
                MarqueeText(
                    $musicManager.songTitle,
                    font: .system(size: 15.5, weight: .bold, design: .default),
                    nsFont: .headline,
                    textColor: .white,
                    frameWidth: max(0, width - 30)
                )

                Spacer(minLength: 2)

                visualizerView
            }
            .frame(maxWidth: .infinity)

            MarqueeText(
                $musicManager.artistName,
                font: .system(size: 13, weight: .medium, design: .default),
                nsFont: .subheadline,
                textColor: Color.white.opacity(0.65),
                frameWidth: width
            )

            if Defaults[.enableLyrics] {
                TimelineView(.animation(minimumInterval: 0.25, paused: !musicManager.isPlaying || musicManager.isPlayerIdle)) { timeline in
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
                        return trimmed.isEmpty ? "" : trimmed.replacingOccurrences(of: "\n", with: " ")
                    }()
                    if !line.isEmpty {
                        MarqueeText(
                            .constant(line),
                            font: .system(size: 11.5, weight: .regular),
                            nsFont: .caption1,
                            textColor: Color.white.opacity(0.5),
                            frameWidth: width
                        )
                        .lineLimit(1)
                        .opacity(musicManager.isPlaying ? 1 : 0)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    // MARK: - Visualizer

    private var visualizerView: some View {
        Group {
            if Defaults[.useMusicVisualizer] {
                let isSolid = lockScreenPlayerBackgroundStyle == .solid
                let tintColor: Color = isSolid
                    ? .white
                    : (Defaults[.playerColorTinting]
                        ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.65)
                        : Color.white.opacity(0.85))
                Rectangle()
                    .fill(tintColor.gradient)
                    .mask {
                        AudioSpectrumView(
                            isPlaying: $musicManager.isPlaying,
                            color: isSolid
                                ? .white
                                : (Defaults[.playerColorTinting]
                                    ? NSColor(Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.65))
                                    : .white)
                        )
                        .frame(width: 22, height: 16)
                    }
                    .frame(width: 22, height: 16)
                    .opacity(musicManager.isPlaying ? 0.95 : 0.45)
            }
        }
    }

    // MARK: - Progress Row

    private var sliderBlock: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: !musicManager.isPlaying || musicManager.isPlayerIdle)) { timeline in
            let pos: Double = {
                if dragging || Date().timeIntervalSince(lastDragged) < 1.5 {
                    return sliderValue
                }
                return musicManager.estimatedPlaybackPosition(at: timeline.date)
            }()
            let current = min(max(0, pos), duration)
            let remaining = max(0, duration - current)
            let sliderBinding = Binding<Double>(
                get: { current },
                set: { sliderValue = $0 }
            )

            HStack(alignment: .center, spacing: 8) {
                Text(timeString(from: current))
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 32, alignment: .leading)

                CustomSlider(
                    value: sliderBinding,
                    range: 0...max(duration, 0.01),
                    color: .white,
                    dragging: $dragging,
                    lastDragged: $lastDragged,
                    onValueChange: { newValue in
                        sliderValue = newValue
                        lastDragged = Date()
                        MusicManager.shared.seek(to: newValue)
                    }
                )
                .frame(maxWidth: .infinity)
                .frame(height: 12)

                Text("-" + timeString(from: remaining))
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 38, alignment: .trailing)
            }
            .frame(height: 14)
            .padding(.top, 2)
        }
    }

    // MARK: - Controls Toolbar

    private var controlsRow: some View {
        let slots = activeSlots
        return HStack(spacing: 16) {
            ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                slotView(for: slot)
                    .frame(alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 2)
    }

    private var activeSlots: [MusicControlButton] {
        let limit = MusicControlButton.maxSlotCount
        let trimmed = Array(slotConfig.prefix(limit))
        if trimmed.count >= limit {
            return trimmed
        }
        return trimmed + Array(repeating: .none, count: limit - trimmed.count)
    }

    @ViewBuilder
    private func slotView(for slot: MusicControlButton) -> some View {
        let hoverRadius: CGFloat = 11

        switch slot {
        case .shuffle:
            HoverButton(
                icon: "shuffle",
                iconColor: musicManager.isShuffled ? .white : .white.opacity(0.6),
                scale: .medium,
                cornerRadius: hoverRadius,
                customFont: .system(size: 14, weight: .semibold),
                customSize: 32
            ) {
                MusicManager.shared.toggleShuffle()
            }
        case .previous:
            HoverButton(
                icon: "backward.fill",
                iconColor: .white,
                scale: .medium,
                cornerRadius: hoverRadius,
                customFont: .system(size: 19, weight: .bold),
                customSize: 36
            ) {
                MusicManager.shared.previousTrack()
            }
        case .playPause:
            HoverButton(
                icon: musicManager.isPlaying ? "pause.fill" : "play.fill",
                iconColor: .white,
                scale: .large,
                cornerRadius: 14,
                customFont: .system(size: 25, weight: .bold),
                customSize: 44
            ) {
                MusicManager.shared.togglePlay()
            }
        case .next:
            HoverButton(
                icon: "forward.fill",
                iconColor: .white,
                scale: .medium,
                cornerRadius: hoverRadius,
                customFont: .system(size: 19, weight: .bold),
                customSize: 36
            ) {
                MusicManager.shared.nextTrack()
            }
        case .repeatMode:
            HoverButton(
                icon: repeatIcon,
                iconColor: repeatIconColor,
                scale: .medium,
                cornerRadius: hoverRadius,
                customFont: .system(size: 14, weight: .semibold),
                customSize: 32
            ) {
                MusicManager.shared.toggleRepeat()
            }
        case .favorite:
            FavoriteControlButton(cornerRadius: hoverRadius)
        case .goBackward:
            HoverButton(
                icon: "gobackward.15",
                iconColor: .white,
                scale: .medium,
                cornerRadius: hoverRadius,
                customFont: .system(size: 16, weight: .bold),
                customSize: 32
            ) {
                MusicManager.shared.skip(seconds: -15)
            }
        case .goForward:
            HoverButton(
                icon: "goforward.15",
                iconColor: .white,
                scale: .medium,
                cornerRadius: hoverRadius,
                customFont: .system(size: 16, weight: .bold),
                customSize: 32
            ) {
                MusicManager.shared.skip(seconds: 15)
            }
        case .volume:
            Color.clear.frame(width: 32, height: 32)
        case .none:
            Color.clear.frame(width: 32, height: 32)
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
            return .white.opacity(0.6)
        case .all, .one:
            return .white
        }
    }

    private func timeString(from seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
