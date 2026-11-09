import SwiftUI

/// The compact player keeps the current line visible alongside the full lyrics page.
struct InlineMusicLyricsView: View {
    @ObservedObject private var musicManager = MusicManager.shared
    let width: CGFloat

    var body: some View {
        let lyrics = LyricsTimeline(synced: musicManager.syncedLyrics, plain: musicManager.currentLyrics)
        TimelineView(.animation(minimumInterval: 0.25, paused: !musicManager.isPlaying || musicManager.isPlayerIdle)) { context in
            let line = musicManager.isFetchingLyrics ? "Loading lyrics…"
                : lyrics.inlineText(at: musicManager.estimatedPlaybackPosition(at: context.date))
            ZStack(alignment: .leading) {
                if !line.isEmpty {
                    let isPersian = line.unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) }
                    MarqueeText(
                        .constant(line),
                        font: isPersian ? .custom("Vazirmatn-Regular", size: 11.5) : .system(size: 11.5),
                        nsFont: .caption1,
                        textColor: .white.opacity(0.5),
                        frameWidth: width
                    )
                    .lineLimit(1)
                }
            }
            .frame(width: width, height: 14, alignment: .leading)
        }
    }
}

struct LyricsBadge: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text("L")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundStyle(.black)
                .frame(width: 14, height: 14)
                .background(.white, in: RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                .opacity(isHovered ? 1 : 0.9)
                .scaleEffect(isHovered ? 1.08 : 1)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isHovered)
        .help("Show lyrics")
        .accessibilityLabel("Show lyrics")
    }
}

struct MusicLyricsView: View {
    @ObservedObject private var musicManager = MusicManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrollFollow = LyricsScrollFollowState()
    var showsHeader = true
    var showsPreviousLine = false
    let onClose: () -> Void

    private func scrollTarget(for active: Int?) -> Int {
        guard let active else { return -1 }
        guard showsPreviousLine else { return active }
        return active == 0 ? -2 : active - 1
    }

    private var lyrics: LyricsTimeline {
        LyricsTimeline(synced: musicManager.syncedLyrics, plain: musicManager.currentLyrics)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: showsHeader ? 8 : 0) {
            if showsHeader { header }
            pageContent
        }
        .onChange(of: trackIdentity) { _, _ in scrollFollow.resume() }
        .onExitCommand(perform: onClose)
    }

    private var trackIdentity: [String] {
        [musicManager.bundleIdentifier ?? "", musicManager.songTitle, musicManager.artistName, musicManager.album]
    }

    @ViewBuilder
    private var pageContent: some View {
        switch lyrics.contentState(isFetching: musicManager.isFetchingLyrics) {
        case .loading:
            LyricsSkeletonView()
        case .unavailable:
            VStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                Text("Lyrics not found")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Text("Lyrics aren’t available for this song.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .available:
            lyricsContent.id(trackIdentity)
        }
    }

    private var header: some View {
        Button(action: onClose) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 16, height: 22)

                Image(nsImage: musicManager.albumArt)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))

                GeometryReader { geo in
                    MarqueeText(
                        $musicManager.songTitle,
                        font: .system(size: 11, weight: .medium),
                        measurementFont: .systemFont(ofSize: 11, weight: .medium),
                        textColor: .white.opacity(0.8),
                        frameWidth: max(0, geo.size.width),
                        fadeMaskWhenScrolling: true
                    )
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(height: geo.size.height)
                }
            }
            .frame(height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Back to player")
        .accessibilityLabel("Back to player")
    }

    private var lyricsContent: some View {
        let lyrics = lyrics
        // Animation timelines can stop when the lock screen's non-key panel is inactive.
        return TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let position = musicManager.estimatedPlaybackPosition(at: context.date)
            let active = lyrics.activeLine(at: position)
            ScrollViewReader { proxy in
                GeometryReader { geometry in
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 8) {
                            if lyrics.isSynced, let start = lyrics.lines.first?.start, start > 0 {
                                LyricsInstrumentalNotes(isActive: active == nil && musicManager.isPlaying)
                                    .foregroundStyle(.white)
                                    .opacity(active == nil ? 1 : (scrollFollow.isFollowingPlayback ? 0 : 0.45))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 4)
                                    .id(-1)
                            }
                            if showsPreviousLine && lyrics.isSynced {
                                Color.clear
                                    .frame(height: 28)
                                    .background {
                                        if active == 0 {
                                            GeometryReader { geometry in
                                                Color.clear.preference(key: LyricsActiveLineFrameKey.self, value: geometry.frame(in: .named("lyricsViewport")))
                                            }
                                        }
                                    }
                                    .id(-2)
                            }
                            ForEach(lyrics.lines) { line in
                                lyricRow(line, active: active, isSynced: lyrics.isSynced) {
                                    guard let start = line.start else { return }
                                    // Selecting a line is a new playback anchor, not continued browsing.
                                    withAnimation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.92)) {
                                        scrollFollow.resume()
                                        musicManager.seek(to: start)
                                        proxy.scrollTo(scrollTarget(for: lyrics.activeLine(at: start) ?? line.id), anchor: .top)
                                    }
                                }
                                    .padding(.top, 4)
                                    .id(line.id)
                            }
                        }
                        .padding(.horizontal, 2)
                        // Keep even the final line near the header when it becomes active.
                        .padding(.bottom, lyrics.isSynced ? geometry.size.height : 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollIndicators(.hidden)
                    .background {
                        LyricsScrollMonitor {
                            if lyrics.isSynced { scrollFollow.beginBrowsing() }
                        }
                        .allowsHitTesting(false)
                    }
                    .coordinateSpace(name: "lyricsViewport")
                    .onPreferenceChange(LyricsActiveLineFrameKey.self) { frame in
                        if let frame {
                            scrollFollow.updateActiveLine(distanceFromAnchor: frame.minY - 4)
                        } else if active != nil && !scrollFollow.isFollowingPlayback {
                            scrollFollow.updateActiveLine(distanceFromAnchor: .infinity)
                        }
                    }
                    .mask {
                        LinearGradient(stops: [
                            .init(color: showsPreviousLine ? .clear : .black, location: 0),
                            .init(color: .black, location: showsPreviousLine ? 0.08 : 0),
                            .init(color: .black, location: 0.82),
                            .init(color: .clear, location: 1)
                        ], startPoint: .top, endPoint: .bottom)
                    }
                    .onAppear { proxy.scrollTo(scrollTarget(for: active), anchor: .top) }
                    .onChange(of: active) { _, next in
                        guard scrollFollow.isFollowingPlayback else { return }
                        withAnimation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.92)) {
                            proxy.scrollTo(scrollTarget(for: next), anchor: .top)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if lyrics.isSynced, let active, scrollFollow.showsSync {
                            Button {
                                withAnimation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.92)) {
                                    scrollFollow.resume()
                                    proxy.scrollTo(scrollTarget(for: active), anchor: .top)
                                }
                            } label: {
                                Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .frame(height: 28)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                            .help("Sync to current lyric")
                            .accessibilityLabel("Sync to current lyric")
                            .padding(.bottom, 2)
                            .transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.9)))
                        }
                    }
                    .animation(.easeOut(duration: 0.2), value: scrollFollow.showsSync)
                }
            }
        }
    }

    private func lyricRow(_ line: LyricsTimeline.Line, active: Int?, isSynced: Bool, onSelect: @escaping () -> Void) -> some View {
        let isCurrent = active == line.id
        let isPast = isSynced && line.id < (active ?? 0)
        let hidePast = isPast && scrollFollow.isFollowingPlayback && !showsPreviousLine
        return Button(action: onSelect) {
            Group {
                if line.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    LyricsInstrumentalNotes(isActive: isCurrent && musicManager.isPlaying)
                } else {
                    Text(line.text)
                }
            }
            .font(.system(size: 19, weight: .bold, design: .rounded))
            .multilineTextAlignment(.leading)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(hidePast ? 0 : (!isSynced || isCurrent ? 1 : (isPast && !showsPreviousLine ? 0.45 : 0.28)))
            .blur(radius: isSynced && !isCurrent && !reduceMotion ? 0.8 : 0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.55), value: active)
            .background {
                if active != nil && line.id == scrollTarget(for: active) {
                    GeometryReader { geometry in
                        Color.clear.preference(key: LyricsActiveLineFrameKey.self, value: geometry.frame(in: .named("lyricsViewport")))
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(line.start == nil)
        .accessibilityHidden(hidePast)
        .accessibilityLabel(line.text.isEmpty ? "Instrumental" : line.text)
        .help(line.start == nil ? "Lyrics" : "Play from this line")
    }
}

/// Fade the complete page as one layer, including the clickable breadcrumb.
struct MusicLyricsTransition: AnimatableModifier {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let visible = min(1, max(0, progress))
        return content
            .opacity(visible)
            .blur(radius: 8 * (1 - visible))
    }
}

private struct LyricsInstrumentalNotes: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isActive: Bool

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<3) { _ in
                Image(systemName: "music.note")
                    .font(.system(size: 14, weight: .medium))
                    .symbolEffect(.pulse, options: .repeating, isActive: isActive && !reduceMotion)
            }
        }
        .frame(height: 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Instrumental")
    }
}

private struct LyricsSkeletonView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array([0.88, 0.65, 0.78].enumerated()), id: \.offset) { _, fraction in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(.white.opacity(isPulsing ? 0.16 : 0.08))
                        .frame(width: max(0, geometry.size.width * fraction), height: 13)
                }
            }
            .padding(.top, 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading lyrics")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

private struct LyricsActiveLineFrameKey: PreferenceKey {
    static var defaultValue: CGRect? = nil

    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = nextValue() ?? value
    }
}

/// Observe user wheel/trackpad input while allowing NSScrollView to handle it normally.
private struct LyricsScrollMonitor: NSViewRepresentable {
    let onUserScroll: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.install(on: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onUserScroll = onUserScroll
    }

    func makeCoordinator() -> Coordinator { Coordinator(onUserScroll: onUserScroll) }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    @MainActor final class Coordinator {
        var onUserScroll: () -> Void
        private var monitor: Any?

        init(onUserScroll: @escaping () -> Void) { self.onUserScroll = onUserScroll }

        func install(on view: NSView) {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self, weak view] event in
                guard let self, let view, let window = view.window,
                      event.window === window,
                      event.momentumPhase.isEmpty,
                      view.bounds.contains(view.convert(event.locationInWindow, from: nil)),
                      abs(event.scrollingDeltaY) > 0.1 else { return event }
                self.onUserScroll()
                return event
            }
        }

        func removeMonitor() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }
}

/// Carries presentation to the outer shell so artwork fills the padded notch/island.
struct MusicLyricsPresentationKey: PreferenceKey {
    static var defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

struct MusicLyricsBackground: View {
    @ObservedObject private var musicManager = MusicManager.shared

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                Image(nsImage: musicManager.albumArt)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .blur(radius: 45, opaque: true)
                    .scaleEffect(1.25)
                    .saturation(0.6)
                    .opacity(0.2)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
