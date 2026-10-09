//
//  DualActivityClosedView.swift
//  Dino
//

import Defaults
import SwiftUI

public struct DualActivityClosedView: View {
    @EnvironmentObject private var vm: BoringViewModel
    @ObservedObject private var coordinator = BoringViewCoordinator.shared
    @ObservedObject private var musicManager = MusicManager.shared
    @ObservedObject private var pomodoroManager = PomodoroManager.shared

    var albumArtNamespace: Namespace.ID
    var isCurrentScreenBuiltin: Bool
    var isCurrentDisplayIsland: Bool
    var useMusicVisualizer: Bool
    var isShowingMusicSneakPeek: Bool
    @Binding var showCoverHoverMusicDetails: Bool

    @State private var isCoverHovering = false
    @State private var coverHoverDismissTask: Task<Void, Never>?
    @State private var isSongDetailsHovered = false
    @State private var showCopiedFeedback = false

    public init(
        albumArtNamespace: Namespace.ID,
        isCurrentScreenBuiltin: Bool,
        isCurrentDisplayIsland: Bool,
        useMusicVisualizer: Bool,
        isShowingMusicSneakPeek: Bool,
        showCoverHoverMusicDetails: Binding<Bool>
    ) {
        self.albumArtNamespace = albumArtNamespace
        self.isCurrentScreenBuiltin = isCurrentScreenBuiltin
        self.isCurrentDisplayIsland = isCurrentDisplayIsland
        self.useMusicVisualizer = useMusicVisualizer
        self.isShowingMusicSneakPeek = isShowingMusicSneakPeek
        self._showCoverHoverMusicDetails = showCoverHoverMusicDetails
    }

    public var body: some View {
        let isBuiltin = isCurrentScreenBuiltin
        let artSize: CGFloat = max(0, vm.effectiveClosedNotchHeight - 12)
        let centerWidth: CGFloat = isBuiltin
            ? (vm.closedNotchSize.width + 14)
            : max(40, vm.closedNotchSize.width - 10)

        VStack(spacing: isShowingMusicSneakPeek ? 4 : 0) {
            HStack(spacing: 0) {
                // MARK: Left - Music artwork with hover detection for sneak peek
                ZStack {
                    Image(nsImage: musicManager.albumArt)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: artSize, height: artSize)
                        .clipShape(RoundedRectangle(cornerRadius: MusicPlayerImageSizes.cornerRadiusInset.closed, style: .continuous))
                        .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                }
                .frame(width: artSize, height: artSize)
                .contentShape(Rectangle())
                .onHover { hovering in
                    isCoverHovering = hovering
                    if hovering && vm.notchState == .closed && !musicManager.isPlayerIdle {
                        coverHoverDismissTask?.cancel()
                        withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.78)) {
                            showCoverHoverMusicDetails = true
                        }
                    } else if !hovering {
                        coverHoverDismissTask?.cancel()
                        coverHoverDismissTask = Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(400))
                            guard !Task.isCancelled else { return }
                            withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.78)) {
                                self.showCoverHoverMusicDetails = false
                            }
                        }
                    }
                }

                // MARK: Center - Single Pomodoro countdown counter (centered in notch chin)
                HStack {
                    Spacer(minLength: 0)
                    Text(pomodoroManager.formattedRemainingTime)
                        .font(.system(size: isBuiltin ? 12.5 : 11.0, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(pomodoroManager.isBreakPhase ? Color.green : Color.white)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .frame(width: centerWidth, height: vm.effectiveClosedNotchHeight)

                // MARK: Right - Audio visualizer / playing animation
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
                            .frame(width: artSize, height: artSize, alignment: .center)
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
                .frame(width: artSize, height: artSize, alignment: .center)
            }
            .contentShape(Rectangle())
            .frame(
                height: vm.effectiveClosedNotchHeight,
                alignment: .center
            )

            // MARK: Sneak Peek details row below cover & visualizer
            if isShowingMusicSneakPeek {
                let songTitleAndArtist = musicManager.artistName.isEmpty
                    ? musicManager.songTitle
                    : "\(musicManager.songTitle) - \(musicManager.artistName)"
                let songText = musicManager.artistName.isEmpty
                    ? "♪ \(musicManager.songTitle)"
                    : "♪ \(musicManager.songTitle) • \(musicManager.artistName)"
                let textAvailableWidth = vm.closedNotchSize.width - 20
                let textColor = Defaults[.playerColorTinting]
                    ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.6)
                    : .white.opacity(0.9)

                Group {
                    if showCopiedFeedback {
                        let feedbackColor: Color = Defaults[.playerColorTinting]
                            ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.7)
                            : .white.opacity(0.85)

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
        .padding(.horizontal, 4)
    }
}
