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

    private var currentValue: Double {
        min(max(0, sliderValue), duration)
    }

    private var remainingValue: Double {
        max(0, duration - currentValue)
    }

    private var lyricLineText: String {
        if musicManager.isFetchingLyrics {
            return "Loading lyrics…"
        }

        if !musicManager.syncedLyrics.isEmpty {
            return musicManager.lyricLine(at: currentValue)
        }

        let trimmed = musicManager.currentLyrics.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No lyrics found" : trimmed.replacingOccurrences(of: "\n", with: " ")
    }

    var body: some View {
        ZStack {
            if shouldShowPlayer {
                VStack(alignment: .leading, spacing: 7) {
                    topRow
                    sliderBlock
                    controlsRow
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 13)
                .background {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(backgroundFill)
                        .overlay { backgroundOverlayA }
                        .overlay { backgroundOverlayB }
                        .overlay { backgroundOverlayC }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.4), radius: 22, y: 10)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.smooth, value: shouldShowPlayer)
    }

    private var backgroundFill: AnyShapeStyle {
        switch lockScreenPlayerBackgroundStyle {
        case .glassBlur:
            return AnyShapeStyle(.ultraThinMaterial)
        case .liquidGlass:
            return AnyShapeStyle(.thinMaterial)
        case .solid:
            return AnyShapeStyle(Color.black.opacity(0.32))
        }
    }

    @ViewBuilder
    private var backgroundOverlayA: some View {
        switch lockScreenPlayerBackgroundStyle {
        case .glassBlur:
            Color.white.opacity(0.025)
        case .liquidGlass:
            LinearGradient(
                colors: [Color.white.opacity(0.10), Color.white.opacity(0.02), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .solid:
            Color.white.opacity(0.04)
        }
    }

    @ViewBuilder
    private var backgroundOverlayB: some View {
        switch lockScreenPlayerBackgroundStyle {
        case .glassBlur:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
        case .liquidGlass:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 0.9)
        case .solid:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 0.9)
        }
    }

    @ViewBuilder
    private var backgroundOverlayC: some View {
        switch lockScreenPlayerBackgroundStyle {
        case .glassBlur:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.10), lineWidth: 0.5)
                .blur(radius: 0.2)
        case .liquidGlass:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.12), lineWidth: 0.5)
                .blur(radius: 0.25)
        case .solid:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.18), lineWidth: 0.6)
                .blur(radius: 0.2)
        }
    }

    private var topRow: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let textWidth = max(0, width - 58 - 12 - 8 - 28)

            HStack(spacing: 12) {
                Image(nsImage: musicManager.albumArt)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 0) {
                    MarqueeText(
                        $musicManager.songTitle,
                        font: .headline,
                        nsFont: .headline,
                        textColor: .white,
                        frameWidth: textWidth
                    )
                    MarqueeText(
                        $musicManager.artistName,
                        font: .headline,
                        nsFont: .headline,
                        textColor: Defaults[.playerColorTinting]
                            ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.6)
                            : .gray,
                        frameWidth: textWidth
                    )
                    .fontWeight(.medium)
                    if enableLyrics {
                        MarqueeText(
                            .constant(lyricLineText),
                            font: .subheadline,
                            nsFont: .subheadline,
                            textColor: musicManager.isFetchingLyrics ? .gray.opacity(0.7) : .gray,
                            frameWidth: textWidth
                        )
                        .lineLimit(1)
                        .opacity(musicManager.isPlaying ? 1 : 0)
                    }
                }

                Spacer(minLength: 8)

                Rectangle()
                    .fill(
                        coloredSpectrogram
                            ? Color(nsColor: musicManager.avgColor).gradient
                            : Color.white.opacity(0.75).gradient
                    )
                    .frame(width: 28, height: 20)
                    .mask {
                        AudioSpectrumView(isPlaying: $musicManager.isPlaying)
                            .frame(width: 16, height: 12)
                    }
                    .opacity(musicManager.isPlaying ? 0.95 : 0.45)
            }
        }
        .frame(height: 58)
    }

    private var sliderBlock: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: !musicManager.isPlaying || musicManager.isPlayerIdle)) { timeline in
            let pos: Double = {
                if dragging { return sliderValue }
                return musicManager.estimatedPlaybackPosition(at: timeline.date)
            }()
            let current = min(max(0, pos), duration)
            let remaining = max(0, duration - current)
            let sliderBinding = Binding<Double>(
                get: { current },
                set: { sliderValue = $0 }
            )

            HStack(alignment: .center, spacing: 10) {
                Text(formatTime(current))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.76))
                    .monospacedDigit()

                CustomSlider(
                    value: sliderBinding,
                    range: 0...max(duration, 0.01),
                    color: .white,
                    dragging: $dragging,
                    lastDragged: $lastDragged,
                    onValueChange: { newValue in
                        MusicManager.shared.seek(to: newValue)
                    }
                )
                .frame(maxWidth: .infinity)
                .frame(height: 10)

                Text("-\(formatTime(remaining))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.76))
                    .monospacedDigit()
            }
            .padding(.top, 6)
        }
    }

    private var controlsRow: some View {
        let slots = activeSlots
        return HStack(spacing: 12) {
            ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                slotView(for: slot)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
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
        switch slot {
        case .shuffle:
            playerButton(icon: "shuffle", active: musicManager.isShuffled) { MusicManager.shared.toggleShuffle() }
        case .previous:
            playerButton(icon: "backward.fill") { MusicManager.shared.previousTrack() }
        case .playPause:
            playerButton(icon: musicManager.isPlaying ? "pause.fill" : "play.fill", size: 50, iconSize: 26) {
                MusicManager.shared.togglePlay()
            }
        case .next:
            playerButton(icon: "forward.fill") { MusicManager.shared.nextTrack() }
        case .repeatMode:
            playerButton(icon: repeatIcon, active: musicManager.repeatMode != .off) { MusicManager.shared.toggleRepeat() }
        case .favorite:
            playerButton(icon: musicManager.isFavoriteTrack ? "heart.fill" : "heart", active: musicManager.isFavoriteTrack) {
                MusicManager.shared.toggleFavoriteTrack()
            }
            .disabled(!musicManager.canFavoriteTrack)
            .opacity(musicManager.canFavoriteTrack ? 1 : 0.45)
        case .goBackward:
            playerButton(icon: "gobackward.15") { MusicManager.shared.skip(seconds: -15) }
        case .goForward:
            playerButton(icon: "goforward.15") { MusicManager.shared.skip(seconds: 15) }
        case .volume:
            Color.clear.frame(width: 34, height: 34)
        case .none:
            Color.clear.frame(width: 34, height: 34)
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

    private func playerButton(
        icon: String,
        active: Bool = false,
        size: CGFloat = 34,
        iconSize: CGFloat = 16,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(active ? .red : .white)
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
