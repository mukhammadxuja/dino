import AppKit
import Combine
import SwiftUI

/// Read the user's clock appearance without changing loginwindow preferences.
struct SystemLockScreenClockStyle {
    let identifier: String
    let weight: Double

    static func current() -> Self {
        let domain = "com.apple.loginwindow" as CFString
        let storedWeight = CFPreferencesCopyAppValue("ClockFontWeight" as CFString, domain)
        return Self(
            identifier: CFPreferencesCopyAppValue("ClockFontIdentifier" as CFString, domain) as? String ?? "system",
            weight: (storedWeight as? NSNumber)?.doubleValue ?? Double(storedWeight as? String ?? "") ?? 600
        )
    }

    func font(size: CGFloat) -> NSFont {
        let name = identifier.lowercased()
        let design: NSFontDescriptor.SystemDesign = name.contains("newyork") ? .serif
            : (name.contains("round") ? .rounded : (name.contains("mono") ? .monospaced : .default))
        let base = NSFont(name: identifier, size: size) ?? NSFont.systemFont(ofSize: size, weight: .semibold)
        let descriptor = (base.fontDescriptor.withDesign(design) ?? base.fontDescriptor)
            .addingAttributes([.variation: [NSNumber(value: 0x77676874): NSNumber(value: min(900, max(100, weight)))]])
        return NSFont(descriptor: descriptor, size: size) ?? base
    }
}

@MainActor
final class LockScreenMediaSession: ObservableObject {
    @Published private(set) var mode: LockScreenMediaMode = .compact
    var onModeChange: ((LockScreenMediaMode) -> Void)?

    func setMode(_ mode: LockScreenMediaMode) {
        guard self.mode != mode else { return }
        self.mode = mode
        onModeChange?(mode)
    }
}

@MainActor
final class LockScreenArtworkPresentation: ObservableObject {
    @Published private(set) var isExpanded = false
    @Published private(set) var showingLyrics = false
    @Published private(set) var layout: LockScreenArtworkLayout
    @Published private(set) var clockStyle = SystemLockScreenClockStyle.current()
    @Published private(set) var backgroundColors: [NSColor] = [.darkGray, .black]
    var dateColor: NSColor { Self.dateAccent(from: backgroundColors) }
    let session: LockScreenMediaSession
    private weak var playerWindow: NSWindow?
    private var backdropWindow: BoringNotchSkyLightWindow?
    private var artworkWindow: BoringNotchSkyLightWindow?
    private var lyricsWindow: BoringNotchSkyLightWindow?
    private var closeObserver: Any?
    private var subscriptions = Set<AnyCancellable>()
    private var dismissalTask: Task<Void, Never>?
    private var lyricsDismissalTask: Task<Void, Never>?
    private var isDisposed = false
    private var playerBottomOffset: CGFloat

    init(screenFrame: CGRect, playerBottomOffset: CGFloat, session: LockScreenMediaSession? = nil) {
        self.session = session ?? LockScreenMediaSession()
        self.playerBottomOffset = playerBottomOffset
        layout = LockScreenArtworkLayout(screenFrame: screenFrame, playerBottomOffset: playerBottomOffset)
    }

    func attach(to player: NSWindow, onClose: @escaping () -> Void) {
        playerWindow = player
        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: player, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.dispose()
                onClose()
            }
        }
        Publishers.CombineLatest(MusicManager.shared.$isPlaying, MusicManager.shared.$isPlayerIdle)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playing, idle in
                if !playing && idle { self?.collapse() }
            }
            .store(in: &subscriptions)
        MusicManager.shared.$albumArt
            .receive(on: DispatchQueue.main)
            .sink { [weak self] image in self?.backgroundColors = Self.palette(from: image) }
            .store(in: &subscriptions)
        session.$mode
            .sink { [weak self] mode in self?.apply(mode: mode) }
            .store(in: &subscriptions)
    }

    func update(screenFrame: CGRect, playerBottomOffset: CGFloat) {
        guard layout.screenFrame != screenFrame || self.playerBottomOffset != playerBottomOffset else { return }
        self.playerBottomOffset = playerBottomOffset
        layout = LockScreenArtworkLayout(screenFrame: screenFrame, playerBottomOffset: playerBottomOffset, showingLyrics: session.mode == .lyrics)
        apply(mode: session.mode)
    }

    func toggle() {
        guard !isDisposed else { return }
        session.setMode(session.mode.isExpanded ? .compact : .artwork)
    }

    func toggleLyrics() {
        guard !isDisposed else { return }
        session.setMode(session.mode == .lyrics ? .artwork : .lyrics)
    }

    func closeLyrics() {
        guard !isDisposed, showingLyrics else { return }
        session.setMode(.artwork)
    }
    func collapse() {
        guard !isDisposed else { return }
        session.setMode(.compact)
    }

    /// Called after the player is ordered onscreen, including a newly connected display.
    func synchronizeWindows() {
        guard !isDisposed, isExpanded else { return }
        guard backdropWindow == nil || artworkWindow == nil || (showingLyrics && lyricsWindow == nil) else { return }
        prepareWindows(targetLayout: layout, includeLyrics: showingLyrics)
    }

    private func prepareWindows(targetLayout: LockScreenArtworkLayout, includeLyrics: Bool) {
        guard let playerWindow, playerWindow.isVisible else { return }
        if backdropWindow == nil {
            backdropWindow = makeWindow(frame: targetLayout.screenFrame, rootView: LockScreenArtworkBackdrop(presentation: self), interactive: false)
            artworkWindow = makeWindow(frame: targetLayout.artworkWindowFrame, rootView: LockScreenLargeArtwork(presentation: self), interactive: true)
        }
        if includeLyrics && lyricsWindow == nil {
            lyricsWindow = makeWindow(frame: targetLayout.lyricsWindowFrame, rootView: LockScreenArtworkLyricsPanel(presentation: self), interactive: true)
        }
        updateWindowFrames(to: targetLayout, animated: true)
        backdropWindow?.order(.below, relativeTo: playerWindow.windowNumber)
        backdropWindow?.ignoresMouseEvents = true
        artworkWindow?.ignoresMouseEvents = false
        // Keep the compact controls above the generous transparent shadow margins.
        artworkWindow?.order(.below, relativeTo: playerWindow.windowNumber)
        if includeLyrics {
            lyricsWindow?.ignoresMouseEvents = false
            lyricsWindow?.order(.below, relativeTo: playerWindow.windowNumber)
        }
        backdropWindow?.contentView?.layoutSubtreeIfNeeded()
        artworkWindow?.contentView?.layoutSubtreeIfNeeded()
        lyricsWindow?.contentView?.layoutSubtreeIfNeeded()
    }

    private func apply(mode: LockScreenMediaMode) {
        guard !isDisposed else { return }
        dismissalTask?.cancel()
        lyricsDismissalTask?.cancel()
        let nextLayout = LockScreenArtworkLayout(screenFrame: layout.screenFrame, playerBottomOffset: playerBottomOffset, showingLyrics: mode == .lyrics)
        let expanded = mode.isExpanded && nextLayout.canExpand
        if expanded && !isExpanded { clockStyle = .current() }
        if expanded {
            // Mount transparent content before its opening animation starts.
            prepareWindows(targetLayout: nextLayout, includeLyrics: mode == .lyrics)
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) {
            isExpanded = expanded
            showingLyrics = expanded && mode == .lyrics
            layout = nextLayout
        }
        if expanded {
            if !showingLyrics {
                lyricsWindow?.ignoresMouseEvents = true
                lyricsDismissalTask = Task { @MainActor [weak self] in
                    do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
                    guard let self, !self.showingLyrics else { return }
                    self.lyricsWindow?.orderOut(nil)
                }
            }
        } else {
            backdropWindow?.ignoresMouseEvents = true
            artworkWindow?.ignoresMouseEvents = true
            lyricsWindow?.ignoresMouseEvents = true
            dismissalTask = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .milliseconds(750)) } catch { return }
                guard let self, !self.isExpanded else { return }
                self.backdropWindow?.orderOut(nil)
                self.artworkWindow?.orderOut(nil)
                self.lyricsWindow?.orderOut(nil)
            }
        }
    }

    private func updateWindowFrames(to targetLayout: LockScreenArtworkLayout? = nil, animated: Bool) {
        let target = targetLayout ?? layout
        backdropWindow?.setFrame(target.screenFrame, display: true)
        for (window, frame) in [(artworkWindow, target.artworkWindowFrame), (lyricsWindow, target.lyricsWindowFrame)] {
            guard let window else { continue }
            if animated && window.isVisible {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.55
                    window.animator().setFrame(frame, display: true)
                }
            } else {
                window.setFrame(frame, display: true)
            }
        }
    }

    func dispose() {
        guard !isDisposed else { return }
        isDisposed = true
        dismissalTask?.cancel()
        lyricsDismissalTask?.cancel()
        subscriptions.removeAll()
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        closeObserver = nil
        for window in [backdropWindow, artworkWindow, lyricsWindow].compactMap({ $0 }) {
            window.orderOut(nil)
            window.disableSkyLight()
            window.close()
        }
        backdropWindow = nil
        artworkWindow = nil
        lyricsWindow = nil
        isExpanded = false
        showingLyrics = false
    }

    private func makeWindow<Content: View>(frame: CGRect, rootView: Content, interactive: Bool) -> BoringNotchSkyLightWindow {
        let window = BoringNotchSkyLightWindow(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: rootView.environment(\.colorScheme, .dark))
        window.ignoresMouseEvents = !interactive
        window.enableSkyLight()
        return window
    }

    /// Sample four regions once per artwork change; the backdrop needs only 144 pixels.
    static func palette(from image: NSImage) -> [NSColor] {
        guard let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [.darkGray, .black] }
        let side = 12
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let rendered = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(source, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard rendered else { return [.darkGray, .black] }
        return [(0, 0), (6, 0), (0, 6), (6, 6)].map { startX, startY in
            var red = 0.0, green = 0.0, blue = 0.0, alpha = 0.0
            for y in startY..<(startY + 6) {
                for x in startX..<(startX + 6) {
                    let offset = (y * side + x) * 4
                    red += Double(pixels[offset])
                    green += Double(pixels[offset + 1])
                    blue += Double(pixels[offset + 2])
                    alpha += Double(pixels[offset + 3])
                }
            }
            guard alpha > 0 else { return .darkGray }
            return NSColor(red: min(1, red / alpha), green: min(1, green / alpha), blue: min(1, blue / alpha), alpha: 1)
        }
    }

    static func dateAccent(from colors: [NSColor]) -> NSColor {
        var accent = NSColor.white
        var bestScore: CGFloat = 0
        for color in colors {
            guard let rgb = color.usingColorSpace(.sRGB) else { continue }
            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
            rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            let score = saturation * brightness
            guard saturation > 0.12, brightness > 0.08, score > bestScore else { continue }
            bestScore = score
            accent = NSColor(calibratedHue: hue, saturation: min(0.65, saturation), brightness: max(0.92, brightness), alpha: 1)
        }
        return accent
    }
}

struct LockScreenLargeArtwork: View {
    @ObservedObject var presentation: LockScreenArtworkPresentation
    @ObservedObject private var musicManager = MusicManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoverOffset: CGSize = .zero

    var body: some View {
        Button(action: presentation.collapse) {
            Image(nsImage: musicManager.albumArt)
                .resizable()
                .scaledToFill()
                .frame(width: presentation.layout.artworkFrame.width, height: presentation.layout.artworkFrame.height)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 0.7))
                .shadow(color: .black.opacity(0.35), radius: 22, y: 12)
        }
        .buttonStyle(.plain)
        .scaleEffect(musicManager.isPlaying ? 1 : 0.96)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: musicManager.isPlaying)
        .rotation3DEffect(.degrees(reduceMotion ? 0 : -hoverOffset.height * 5), axis: (x: 1, y: 0, z: 0), perspective: 0.7)
        .rotation3DEffect(.degrees(reduceMotion ? 0 : hoverOffset.width * 5), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hoverOffset)
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                let side = presentation.layout.artworkFrame.width
                guard side > 0, presentation.isExpanded, !reduceMotion else { return }
                hoverOffset = CGSize(width: min(1, max(-1, location.x / side * 2 - 1)),
                                     height: min(1, max(-1, location.y / side * 2 - 1)))
            case .ended:
                hoverOffset = .zero
            }
        }
        .onChange(of: presentation.isExpanded) { _, expanded in
            if !expanded { hoverOffset = .zero }
        }
        .scaleEffect(presentation.isExpanded || reduceMotion ? 1 : 0.88)
        .opacity(presentation.isExpanded ? 1 : 0)
        .padding(LockScreenArtworkLayout.shadowPadding)
        .accessibilityLabel("Collapse album artwork")
        .help("Back to compact artwork")
    }
}

struct LockScreenArtworkBackdrop: View {
    @ObservedObject var presentation: LockScreenArtworkPresentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ZStack {
                    Color.black
                    ZStack {
                        LinearGradient(colors: presentation.backgroundColors.map { Color(nsColor: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing)
                            .saturation(0.75)
                            .opacity(0.8)
                            .id(presentation.backgroundColors)
                            .transition(.asymmetric(insertion: .opacity, removal: .identity))
                    }
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.7), value: presentation.backgroundColors)
                    LinearGradient(colors: [.black.opacity(0.48), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                }
                clock(size: geometry.size)
            }
            .opacity(presentation.isExpanded ? 1 : 0)
            .clipped()
        }
    }

    private func clock(size: CGSize) -> some View {
        let minute = Calendar.current.dateInterval(of: .minute, for: .now)?.start ?? .now
        return TimelineView(.periodic(from: minute, by: 60)) { context in
            let pointSize: CGFloat = min(22, max(17, size.width / 64))
            let timeFont = presentation.clockStyle.font(size: pointSize)
            let dateFont = timeFont
            let date = LockScreenClockRowLayout.dateText(for: context.date)
            let time = context.date.formatted(date: .omitted, time: .shortened)
            let dateWidth = (date as NSString).size(withAttributes: [.font: dateFont]).width
            let timeWidth = (time as NSString).size(withAttributes: [.font: timeFont]).width
            let row = LockScreenClockRowLayout(centerX: size.width / 2, timeWidth: timeWidth, dateWidth: dateWidth)
            let top = LockScreenArtworkLayout.clockTop(for: size.height)
            let expanded = presentation.isExpanded || reduceMotion
            ZStack {
                Text(date)
                    .font(Font(dateFont))
                    .foregroundStyle(Color(nsColor: presentation.dateColor).opacity(0.75))
                    .position(x: expanded ? row.dateCenterX : size.width / 2, y: top)
                Text(time)
                    .font(Font(timeFont))
                    .foregroundStyle(.white)
                    .scaleEffect(expanded ? 1 : 96 / pointSize)
                    .position(x: expanded ? row.timeCenterX : size.width / 2, y: expanded ? top : top + 90)
            }
            .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
        }
    }
}

struct LockScreenArtworkLyricsPanel: View {
    @ObservedObject var presentation: LockScreenArtworkPresentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        MusicLyricsView(showsHeader: false, showsPreviousLine: true, onClose: presentation.closeLyrics)
            .frame(width: presentation.layout.lyricsFrame.width, height: presentation.layout.lyricsFrame.height)
            .opacity(presentation.showingLyrics ? 1 : 0)
            .offset(x: presentation.showingLyrics || reduceMotion ? 0 : 24)
            .padding(LockScreenArtworkLayout.shadowPadding)
    }
}

