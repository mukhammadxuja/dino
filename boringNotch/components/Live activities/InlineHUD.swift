//
//  InlineHUDs.swift
//  boringNotch
//
//  Created by Richard Kunkli on 14/09/2024.
//

import AppKit
import SwiftUI
import Defaults
import AVKit
import AVFoundation
import CoreImage

struct InlineHUD: View {
    @EnvironmentObject var vm: BoringViewModel
    var isIsland: Bool = true
    var isScreenBuiltin: Bool = true
    @Binding var type: SneakContentType
    @Binding var value: CGFloat
    @Binding var icon: String
    @Binding var hoverAnimation: Bool
    @Binding var gestureProgress: CGFloat

    @ViewBuilder
    private var leftIconView: some View {
        HStack(spacing: 5) {
            Group {
                switch (type) {
                    case .volume:
                        if icon.isEmpty {
                            Image(systemName: SpeakerSymbol(value))
                                .contentTransition(.interpolate)
                                .symbolVariant(value > 0 ? .none : .slash)
                                .frame(width: 20, height: 15, alignment: .leading)
                        } else {
                            Image(systemName: icon)
                                .contentTransition(.interpolate)
                                .opacity(value.isZero ? 0.6 : 1)
                                .scaleEffect(value.isZero ? 0.85 : 1)
                                .frame(width: 20, height: 15, alignment: .leading)
                        }
                    case .brightness:
                        Image(systemName: BrightnessSymbol(value))
                            .contentTransition(.interpolate)
                            .frame(width: 20, height: 15, alignment: .center)
                    case .backlight:
                        Image(systemName: value > 0.5 ? "light.max" : "light.min")
                            .contentTransition(.interpolate)
                            .frame(width: 20, height: 15, alignment: .center)
                    case .mic:
                        ZStack {
                            Capsule()
                                .fill(value.isZero ? Color.red : Color.green)
                                .frame(width: 24, height: 16)
                            Image(systemName: value.isZero ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(Color.white)
                        }
                        .contentTransition(.interpolate)
                        .frame(width: 24, height: 16, alignment: .center)
                    case .micActivity:
                        ZStack {
                            if value > 0 {
                                Capsule()
                                    .fill(Color.orange)
                                    .frame(width: 24, height: 16)
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(Color.white)
                            } else {
                                Image(systemName: "mic.slash.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(Color.gray)
                            }
                        }
                        .contentTransition(.interpolate)
                        .frame(width: 24, height: 16, alignment: .center)
                    case .camera:
                        ZStack {
                            if value > 0 {
                                Capsule()
                                    .fill(Color.green)
                                    .frame(width: 24, height: 16)
                                Image(systemName: "video.fill")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(Color.white)
                            } else {
                                Image(systemName: "video.slash.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(Color.gray)
                            }
                        }
                        .contentTransition(.interpolate)
                        .frame(width: 24, height: 16, alignment: .center)
                    case .screenRecord:
                        ZStack {
                            if value > 0 {
                                Capsule()
                                    .fill(Color.red)
                                    .frame(width: 24, height: 16)
                                Image(systemName: "record.circle.fill")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(Color.white)
                            } else {
                                Image(systemName: "record.circle")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(Color.gray)
                            }
                        }
                        .contentTransition(.interpolate)
                        .frame(width: 24, height: 16, alignment: .center)
                    case .capsLock:
                        ZStack {
                            if value > 0 {
                                Capsule()
                                    .fill(Color.accentColor)
                                    .frame(width: 24, height: 16)
                                Image(systemName: "capslock.fill")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(Color.white)
                            } else {
                                Image(systemName: "capslock")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(Color.gray)
                            }
                        }
                        .contentTransition(.interpolate)
                        .frame(width: 24, height: 16, alignment: .center)
                    case .location:
                        ZStack {
                            if value > 0 {
                                Capsule()
                                    .fill(Color.blue)
                                    .frame(width: 24, height: 16)
                                Image(systemName: "location.fill")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(Color.white)
                            } else {
                                Image(systemName: "location.slash.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(Color.gray)
                            }
                        }
                        .contentTransition(.interpolate)
                        .frame(width: 24, height: 16, alignment: .center)
                    case .airPods:
                        AirPodsVideoView(animationAsset: .forDeviceName(icon))
                            .frame(width: 24, height: 24)
                    case .updateAvailable:
                        ZStack {
                            Capsule()
                                .fill(Color.updateHUD)
                                .frame(width: 24, height: 16)
                            Image(systemName: "arrow.down.app.fill")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 24, height: 16, alignment: .center)
                    case .charging:
                        ZStack(alignment: .bottomTrailing) {
                            Image(systemName: "battery.100percent")
                                .font(.system(size: 15, weight: .semibold))
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 7, weight: .black))
                                .offset(x: 2, y: 2)
                        }
                        .foregroundStyle(.green)
                        .frame(width: 24, height: 18)
                    case .unplugged:
                        Image(systemName: "battery.0percent")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.orange)
                            .frame(width: 24, height: 18)
                    default:
                        EmptyView()
                }
            }
            .foregroundStyle(.white)
            .symbolVariant(.fill)
            
            if type != .mic && type != .micActivity && type != .camera && type != .screenRecord && type != .capsLock && type != .location && type != .airPods && type != .updateAvailable && type != .charging && type != .unplugged {
                Text(Type2Name(type))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .allowsTightening(true)
                    .contentTransition(.numericText())
            }
        }
    }

    @ViewBuilder
    private var rightStatusView: some View {
        HStack {
            if (type == .mic) {
                Text(value.isZero ? "muted" : "unmuted")
                    .foregroundStyle(value.isZero ? Color.red.opacity(0.85) : Color.white)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                    .allowsTightening(true)
                    .multilineTextAlignment(.trailing)
                    .frame(alignment: .trailing)
                    .contentTransition(.interpolate)
            } else if (type == .micActivity) {
                Text(value > 0 ? "Mic On" : "Mic Off")
                    .foregroundStyle(value > 0 ? Color.orange : Color.gray)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                    .allowsTightening(true)
                    .multilineTextAlignment(.trailing)
                    .frame(alignment: .trailing)
                    .contentTransition(.interpolate)
            } else if (type == .camera) {
                Text(value > 0 ? "Camera On" : "Camera Off")
                    .foregroundStyle(value > 0 ? Color.green : Color.gray)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                    .allowsTightening(true)
                    .multilineTextAlignment(.trailing)
                    .frame(alignment: .trailing)
                    .contentTransition(.interpolate)
            } else if (type == .screenRecord) {
                Text(value > 0 ? "Recording" : "Stopped")
                    .foregroundStyle(value > 0 ? Color.red : Color.gray)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                    .allowsTightening(true)
                    .multilineTextAlignment(.trailing)
                    .frame(alignment: .trailing)
                    .contentTransition(.interpolate)
            } else if (type == .capsLock) {
                Text(value > 0 ? "Caps On" : "Caps Off")
                    .foregroundStyle(value > 0 ? Color.white : Color.gray)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                    .allowsTightening(true)
                    .multilineTextAlignment(.trailing)
                    .frame(alignment: .trailing)
                    .contentTransition(.interpolate)
            } else if (type == .location) {
                Text(value > 0 ? "Location In Use" : "Location Off")
                    .foregroundStyle(value > 0 ? Color.blue : Color.gray)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                    .allowsTightening(true)
                    .multilineTextAlignment(.trailing)
                    .frame(alignment: .trailing)
                    .contentTransition(.interpolate)
            } else if (type == .airPods) {
                let batteryVal = Int(value > 1 ? value : value * 100)
                AirPodsBatteryRingView(battery: batteryVal)
                    .frame(alignment: .trailing)
            } else if type == .updateAvailable {
                Text("Update ready")
                    .foregroundStyle(Color.updateHUD)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize()
            } else if type == .charging {
                Text("Charging")
                    .foregroundStyle(.green)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize()
            } else if type == .unplugged {
                Text("Unplugged")
                    .foregroundStyle(.orange)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize()
            } else {
                HStack(spacing: 6) {
                    DraggableProgressBar(value: $value, animateValueChanges: true, onChange: { v in
                        if type == .volume {
                            VolumeManager.shared.setAbsolute(Float32(v))
                        } else if type == .brightness {
                            BrightnessManager.shared.setAbsolute(value: Float32(v))
                        }
                    })
                    .frame(width: 58)
                    if (type == .volume && value.isZero) {
                        Text("muted")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(minWidth: 32, alignment: .trailing)
                    } else {
                        Text("\(Int(value * 100))%")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(Int(value * 100))))
                            .animation(.snappy(duration: 0.2), value: Int(value * 100))
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(minWidth: 32, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var isSliderHUD: Bool {
        type == .volume || type == .brightness || type == .backlight
    }

    private static let builtInNotchCameraClearance: CGFloat = 12
    private static let builtInNotchSidePadding: CGFloat = 4

    /// The exact width required for a built-in notch HUD. Matching wing widths
    /// keep the physical camera area centered even when one side has longer text.
    static func requiredBuiltInNotchWidth(cameraWidth: CGFloat, type: SneakContentType) -> CGFloat {
        let wingWidth = builtInWingWidth(for: type)
        return (wingWidth * 2)
            + cameraWidth
            + builtInNotchCameraClearance
            + (builtInNotchSidePadding * 2)
    }

    /// External notch styling has no physical camera, but it retains the center
    /// capsule. Its wings still grow to the actual content width so labels never
    /// need to be truncated just to fit a legacy fixed wing.
    static func requiredExternalNotchWidth(cameraWidth: CGFloat, type: SneakContentType) -> CGFloat {
        let wingWidth = builtInWingWidth(for: type)
        let centerWidth = max(0, cameraWidth - 20)
        return (wingWidth * 2) + centerWidth + (builtInNotchSidePadding * 2)
    }

    private static func builtInWingWidth(for type: SneakContentType) -> CGFloat {
        max(builtInLeftContentWidth(for: type), builtInRightContentWidth(for: type))
    }

    private static func builtInLeftContentWidth(for type: SneakContentType) -> CGFloat {
        switch type {
        case .volume, .brightness, .backlight:
            return 20 + 5 + textWidth(Type2Name(for: type), size: 12, weight: .medium)
        case .airPods:
            return 24
        case .mic, .micActivity, .camera, .screenRecord, .capsLock, .location, .updateAvailable, .charging, .unplugged:
            return 24
        default:
            return 24
        }
    }

    private static func builtInRightContentWidth(for type: SneakContentType) -> CGFloat {
        switch type {
        case .volume, .brightness, .backlight:
            return 58 + 6 + 32
        case .mic:
            return textWidth("unmuted", size: 11.5, weight: .medium)
        case .micActivity:
            return textWidth("Mic Off", size: 11.5, weight: .medium)
        case .camera:
            return textWidth("Camera Off", size: 11.5, weight: .medium)
        case .screenRecord:
            return textWidth("Recording", size: 11.5, weight: .medium)
        case .capsLock:
            return textWidth("Caps Off", size: 11.5, weight: .medium)
        case .location:
            return textWidth("Location In Use", size: 11.5, weight: .medium)
        case .airPods:
            return 15
        case .updateAvailable:
            return textWidth("Update ready", size: 11.5, weight: .semibold)
        case .charging:
            return textWidth("Charging", size: 11.5, weight: .semibold)
        case .unplugged:
            return textWidth("Unplugged", size: 11.5, weight: .semibold)
        default:
            return 0
        }
    }

    private static func textWidth(_ text: String, size: CGFloat, weight: NSFont.Weight) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).width)
    }

    private static func Type2Name(for type: SneakContentType) -> String {
        switch type {
        case .volume: return "Volume"
        case .brightness: return "Brightness"
        case .backlight: return "Backlight"
        case .mic: return "Mic"
        default: return ""
        }
    }

    private var islandHUDWidth: CGFloat {
        switch type {
        case .airPods:
            return isScreenBuiltin ? 112 : 106
        case .volume, .brightness, .backlight:
            return isScreenBuiltin ? 236 : 228
        case .camera, .mic, .micActivity, .screenRecord, .capsLock, .location, .charging, .unplugged:
            return isScreenBuiltin ? 180 : 175
        case .updateAvailable:
            return isScreenBuiltin ? 190 : 185
        default:
            return isScreenBuiltin ? 180 : 175
        }
    }

    private var leftWingWidth: CGFloat {
        switch type {
        case .airPods:
            return 52
        case .volume, .brightness, .backlight:
            return 82
        case .camera, .mic, .micActivity, .screenRecord, .capsLock, .location, .updateAvailable, .charging, .unplugged:
            return 52
        default:
            return 60
        }
    }

    private var rightWingWidth: CGFloat {
        switch type {
        case .airPods:
            return 52
        case .volume, .brightness, .backlight:
            return 98
        case .camera, .mic, .micActivity, .screenRecord, .capsLock, .location, .updateAvailable, .charging, .unplugged:
            return 88
        default:
            return 80
        }
    }

    private var islandLayout: some View {
        HStack(spacing: 0) {
            leftIconView
            Spacer(minLength: isSliderHUD ? 25 : 12)
            rightStatusView
        }
        .padding(.leading, 1)
        .padding(.trailing, 4)
        .frame(width: islandHUDWidth, height: vm.closedNotchSize.height + (hoverAnimation ? 8 : 0), alignment: .center)
    }

    private var builtInNotchLayout: some View {
        let wingWidth = Self.builtInWingWidth(for: type)

        return HStack(spacing: 0) {
            leftIconView
                .frame(width: wingWidth, alignment: .leading)

            Rectangle()
                .fill(Color.black)
                .frame(width: vm.closedNotchSize.width + Self.builtInNotchCameraClearance)

            rightStatusView
                .frame(width: wingWidth, alignment: .trailing)
        }
        .padding(.horizontal, Self.builtInNotchSidePadding)
        .frame(
            width: Self.requiredBuiltInNotchWidth(cameraWidth: vm.closedNotchSize.width, type: type),
            height: vm.closedNotchSize.height + (hoverAnimation ? 8 : 0),
            alignment: .center
        )
    }

    private var externalNotchLayout: some View {
        let wingWidth = Self.builtInWingWidth(for: type)
        let centerWidth = max(0, vm.closedNotchSize.width - 20)

        return HStack(spacing: 0) {
            leftIconView
                .frame(width: wingWidth, alignment: .leading)

            Rectangle()
                .fill(.black)
                .frame(width: centerWidth)

            rightStatusView
                .frame(width: wingWidth, alignment: .trailing)
        }
        .padding(.horizontal, Self.builtInNotchSidePadding)
        .frame(
            width: Self.requiredExternalNotchWidth(cameraWidth: vm.closedNotchSize.width, type: type),
            height: vm.closedNotchSize.height + (hoverAnimation ? 8 : 0),
            alignment: .center
        )
    }

    private var notchLayout: some View {
        Group {
            if isScreenBuiltin {
                builtInNotchLayout
            } else {
                externalNotchLayout
            }
        }
    }

    var body: some View {
        if isIsland {
            islandLayout
        } else {
            notchLayout
        }
    }
    
    func SpeakerSymbol(_ value: CGFloat) -> String {
        switch(value) {
            case 0:
                return "speaker"
            case 0...0.3:
                return "speaker.wave.1"
            case 0.3...0.8:
                return "speaker.wave.2"
            case 0.8...1:
                return "speaker.wave.3"
            default:
                return "speaker.wave.2"
        }
    }
    
    func BrightnessSymbol(_ value: CGFloat) -> String {
        switch(value) {
            case 0...0.6:
                return "sun.min"
            case 0.6...1:
                return "sun.max"
            default:
                return "sun.min"
        }
    }
    
    func Type2Name(_ type: SneakContentType) -> String {
        Self.Type2Name(for: type)
    }
}

#Preview {
    InlineHUD(type: .constant(.brightness), value: .constant(0.4), icon: .constant(""), hoverAnimation: .constant(false), gestureProgress: .constant(0))
        .padding(.horizontal, 8)
        .background(Color.black)
        .padding()
        .environmentObject(BoringViewModel())
}

// MARK: - Bluetooth device video assets
enum BluetoothAnimationAsset: String, CaseIterable {
    case airpodsPro
    case airpodsPro3
    case airpodsGen4
    case airpodsGen3
    case airpods
    case airpodsMax
    case beatsSolo = "beatssolo"
    case beatsStudio = "beatsstudio"

    static let defaultAsset: Self = .airpodsPro

    /// A representative device name used by the HUD settings preview cycle.
    var testDeviceName: String {
        switch self {
        case .airpodsPro: return "AirPods Pro"
        case .airpodsPro3: return "AirPods Pro 3"
        case .airpodsGen4: return "AirPods 4"
        case .airpodsGen3: return "AirPods 3"
        case .airpods: return "AirPods"
        case .airpodsMax: return "AirPods Max"
        case .beatsSolo: return "Beats Solo"
        case .beatsStudio: return "Beats Studio"
        }
    }

    static func forDeviceName(_ name: String) -> Self {
        let normalized = name.lowercased()

        if normalized.contains("beats studio") { return .beatsStudio }
        if normalized.contains("beats solo") { return .beatsSolo }
        if normalized.contains("airpods max") { return .airpodsMax }
        if normalized.contains("airpods pro") {
            return normalized.contains("pro 3") || normalized.contains("3rd") || normalized.contains("gen 3")
                ? .airpodsPro3 : .airpodsPro
        }
        if normalized.contains("airpods gen 4") || normalized.contains("airpods 4") || normalized.contains("4th") {
            return .airpodsGen4
        }
        if normalized.contains("airpods gen 3") || normalized.contains("airpods 3") || normalized.contains("3rd") {
            return .airpodsGen3
        }
        if normalized.contains("airpods") { return .airpods }
        return defaultAsset
    }
}

// MARK: - Bluetooth video asset cache
final class AirPodsVideoCache {
    static let shared = AirPodsVideoCache()
    private var cachedURLs: [BluetoothAnimationAsset: URL] = [:]
    private let queue = DispatchQueue(label: "com.boringnotch.airpodsVideoCache", qos: .userInitiated)

    private init() {}

    func prewarm(_ asset: BluetoothAnimationAsset = .defaultAsset) {
        resolveVideoURL(for: asset) { _ in }
    }

    func resolveVideoURL(for asset: BluetoothAnimationAsset, completion: @escaping (URL?) -> Void) {
        queue.async {
            let resolved = self.resolveVideoURLSync(for: asset)
            self.cachedURLs[asset] = resolved
            DispatchQueue.main.async {
                completion(resolved)
            }
        }
    }

    private func resolveVideoURLSync(for asset: BluetoothAnimationAsset) -> URL? {
        if let cached = cachedURLs[asset], FileManager.default.fileExists(atPath: cached.path) {
            return cached
        }

        guard let bundledURL = Bundle.main.url(
            forResource: asset.rawValue,
            withExtension: "mov",
            subdirectory: "devices-animation"
        ) ?? Bundle.main.url(forResource: asset.rawValue, withExtension: "mov") else {
            return nil
        }
        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dino-bluetooth-\(asset.rawValue).mov")
        do {
            let bundledData = try Data(contentsOf: bundledURL)
            if (try? Data(contentsOf: fileURL)) != bundledData {
                try bundledData.write(to: fileURL, options: .atomic)
            }
            return fileURL
        } catch {
            print("⚠️ [AirPodsVideoCache] Failed to write temp video: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - AirPods Video Animation Player
struct AirPodsVideoView: View {
    var animationAsset: BluetoothAnimationAsset = .defaultAsset
    var isActive = true
    @State private var players: [AVPlayer] = []
    @State private var timeObservers: [Any] = []
    @State private var activePlayerIndex = 0
    @State private var isCrossfading = false
    @State private var crossfadeTask: Task<Void, Never>?
    @State private var isVisible = false
    @State private var playbackGeneration = 0
    private let crossfadeDuration: TimeInterval = 0.35

    var body: some View {
        Group {
            if !players.isEmpty {
                ZStack {
                    ForEach(players.indices, id: \.self) { index in
                        AirPodsVideoPlayerRepresentable(player: players[index])
                            .opacity(index == activePlayerIndex ? 1 : 0)
                    }
                }
            } else {
                Image(systemName: "airpodspro")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .onAppear { isVisible = true; updatePlayback() }
        .onChange(of: isActive) { _, _ in updatePlayback() }
        .onChange(of: animationAsset) { _, _ in
            stopPlayback()
            updatePlayback()
        }
        .onDisappear { isVisible = false; stopPlayback() }
    }

    private func updatePlayback() {
        guard isVisible && isActive else { stopPlayback(); return }
        guard players.isEmpty else { return }
        playbackGeneration += 1
        let generation = playbackGeneration
        AirPodsVideoCache.shared.resolveVideoURL(for: animationAsset) { url in
            guard let url, self.isVisible, self.isActive,
                  self.playbackGeneration == generation, self.players.isEmpty else { return }
            let asset = AVURLAsset(url: url)
            let videoPlayers = (0..<2).map { _ in
                let item = AVPlayerItem(asset: asset)
                let player = AVPlayer(playerItem: item)
                player.isMuted = true
                return player
            }
            self.activePlayerIndex = 0
            self.players = videoPlayers
            self.timeObservers = videoPlayers.enumerated().map { index, player in
                player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
                                               queue: .main) { time in
                    self.beginCrossfadeIfNeeded(index: index, time: time, generation: generation)
                }
            }
            videoPlayers[0].play()
        }
    }

    private func beginCrossfadeIfNeeded(index: Int, time: CMTime, generation: Int) {
        guard isVisible, isActive, playbackGeneration == generation,
              !isCrossfading, players.count == 2, index == activePlayerIndex,
              let duration = players[index].currentItem?.duration.seconds,
              duration.isFinite, duration > crossfadeDuration,
              time.seconds >= duration - crossfadeDuration else { return }

        isCrossfading = true
        let nextIndex = 1 - index
        let previousPlayer = players[index]
        let nextPlayer = players[nextIndex]
        nextPlayer.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
            DispatchQueue.main.async {
                guard self.isVisible, self.isActive, self.playbackGeneration == generation else { return }
                guard finished else { self.isCrossfading = false; return }
                nextPlayer.play()
                withAnimation(.easeInOut(duration: self.crossfadeDuration)) {
                    self.activePlayerIndex = nextIndex
                }
                self.crossfadeTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(self.crossfadeDuration))
                    guard !Task.isCancelled, self.playbackGeneration == generation else { return }
                    previousPlayer.pause()
                    self.isCrossfading = false
                }
            }
        }
    }

    private func stopPlayback() {
        playbackGeneration += 1
        crossfadeTask?.cancel()
        crossfadeTask = nil
        for (player, observer) in zip(players, timeObservers) {
            player.removeTimeObserver(observer)
        }
        timeObservers = []
        players.forEach { $0.pause(); $0.replaceCurrentItem(with: nil) }
        players = []
        isCrossfading = false
    }
}

struct AirPodsVideoPlayerRepresentable: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> TransparentAirPodsPlayerView {
        let view = TransparentAirPodsPlayerView()
        view.player = player
        return view
    }

    func updateNSView(_ nsView: TransparentAirPodsPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }

    static func dismantleNSView(_ nsView: TransparentAirPodsPlayerView, coordinator: ()) {
        nsView.player = nil
    }
}

final class TransparentAirPodsPlayerView: NSView {
    override var isOpaque: Bool { false }
    override func makeBackingLayer() -> CALayer { AVPlayerLayer() }

    var player: AVPlayer? {
        get { (layer as? AVPlayerLayer)?.player }
        set { (layer as? AVPlayerLayer)?.player = newValue }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor
        (layer as? AVPlayerLayer)?.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }
}

// MARK: - AirPods Battery Circular Progress Ring
struct AirPodsBatteryRingView: View {
    let battery: Int

    private var batteryFraction: CGFloat {
        CGFloat(max(0, min(100, battery))) / 100.0
    }

    private var ringColor: Color {
        battery <= 20 ? Color.red : Color(red: 0.20, green: 0.88, blue: 0.45)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.25), lineWidth: 2.3)
            Circle()
                .trim(from: 0, to: batteryFraction)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 2.3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 15, height: 15)
    }
}
