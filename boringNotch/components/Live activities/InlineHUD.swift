//
//  InlineHUDs.swift
//  boringNotch
//
//  Created by Richard Kunkli on 14/09/2024.
//

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
                        AirPodsVideoView()
                            .frame(width: 24, height: 24)
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
            
            if type != .mic && type != .micActivity && type != .camera && type != .screenRecord && type != .capsLock && type != .location && type != .airPods && type != .charging && type != .unplugged {
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
                    .frame(maxWidth: isIsland ? nil : .infinity, alignment: .trailing)
                    .contentTransition(.interpolate)
            } else if (type == .micActivity) {
                Text(value > 0 ? "Mic On" : "Mic Off")
                    .foregroundStyle(value > 0 ? Color.orange : Color.gray)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                    .allowsTightening(true)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: isIsland ? nil : .infinity, alignment: .trailing)
                    .contentTransition(.interpolate)
            } else if (type == .camera) {
                Text(value > 0 ? "Camera On" : "Camera Off")
                    .foregroundStyle(value > 0 ? Color.green : Color.gray)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                    .allowsTightening(true)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: isIsland ? nil : .infinity, alignment: .trailing)
                    .contentTransition(.interpolate)
            } else if (type == .screenRecord) {
                Text(value > 0 ? "Recording" : "Stopped")
                    .foregroundStyle(value > 0 ? Color.red : Color.gray)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                    .allowsTightening(true)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: isIsland ? nil : .infinity, alignment: .trailing)
                    .contentTransition(.interpolate)
            } else if (type == .capsLock) {
                Text(value > 0 ? "Caps On" : "Caps Off")
                    .foregroundStyle(value > 0 ? Color.white : Color.gray)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                    .allowsTightening(true)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: isIsland ? nil : .infinity, alignment: .trailing)
                    .contentTransition(.interpolate)
            } else if (type == .location) {
                Text(value > 0 ? "Location In Use" : "Location Off")
                    .foregroundStyle(value > 0 ? Color.blue : Color.gray)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                    .allowsTightening(true)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: isIsland ? nil : .infinity, alignment: .trailing)
                    .contentTransition(.interpolate)
            } else if (type == .airPods) {
                let batteryVal = Int(value > 1 ? value : value * 100)
                AirPodsBatteryRingView(battery: batteryVal)
                    .frame(maxWidth: isIsland ? nil : .infinity, alignment: .trailing)
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

    private var islandHUDWidth: CGFloat {
        switch type {
        case .airPods:
            return isScreenBuiltin ? 112 : 106
        case .volume, .brightness, .backlight:
            return isScreenBuiltin ? 236 : 228
        case .camera, .mic, .micActivity, .screenRecord, .capsLock, .location, .charging, .unplugged:
            return isScreenBuiltin ? 180 : 175
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
        case .camera, .mic, .micActivity, .screenRecord, .capsLock, .location, .charging, .unplugged:
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
        case .camera, .mic, .micActivity, .screenRecord, .capsLock, .location, .charging, .unplugged:
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
        .padding(.trailing, type == .airPods ? 10 : 4)
        .frame(width: islandHUDWidth, height: vm.closedNotchSize.height + (hoverAnimation ? 8 : 0), alignment: .center)
    }

    private var notchLayout: some View {
        HStack {
            leftIconView
                .frame(width: leftWingWidth - (hoverAnimation ? 0 : 12) + gestureProgress / 2, height: vm.notchSize.height - (hoverAnimation ? 0 : 12), alignment: .leading)
            
            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width - 20)
            
            rightStatusView
                .padding(.trailing, 4)
                .frame(width: rightWingWidth - (hoverAnimation ? 0 : 12) + gestureProgress / 2, height: vm.closedNotchSize.height - (hoverAnimation ? 0 : 12), alignment: .trailing)
        }
        .frame(height: vm.closedNotchSize.height + (hoverAnimation ? 8 : 0), alignment: .center)
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
        switch(type) {
            case .volume:
                return "Volume"
            case .brightness:
                return "Brightness"
            case .backlight:
                return "Backlight"
            case .mic:
                return "Mic"
            default:
                return ""
        }
    }
}

#Preview {
    InlineHUD(type: .constant(.brightness), value: .constant(0.4), icon: .constant(""), hoverAnimation: .constant(false), gestureProgress: .constant(0))
        .padding(.horizontal, 8)
        .background(Color.black)
        .padding()
        .environmentObject(BoringViewModel())
}

// MARK: - AirPods Video Asset Cache & Background Resolver
final class AirPodsVideoCache {
    static let shared = AirPodsVideoCache()
    private var cachedURL: URL?
    private let queue = DispatchQueue(label: "com.boringnotch.airpodsVideoCache", qos: .userInitiated)

    private init() {}

    func prewarm() {
        resolveVideoURL { _ in }
    }

    func resolveVideoURL(completion: @escaping (URL?) -> Void) {
        queue.async {
            let resolved = self.resolveVideoURLSync()
            self.cachedURL = resolved
            DispatchQueue.main.async {
                completion(resolved)
            }
        }
    }

    private func resolveVideoURLSync() -> URL? {
        if let cached = cachedURL, FileManager.default.fileExists(atPath: cached.path) {
            return cached
        }

        guard let asset = NSDataAsset(name: "airpods-pro-transparent") else { return nil }
        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("boringnotch-airpods-pro-alpha.mov")
        do {
            // Do not reuse an old extracted video after the bundled asset changes.
            if (try? Data(contentsOf: fileURL)) != asset.data {
                try asset.data.write(to: fileURL, options: .atomic)
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
    var isActive = true
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?
    @State private var isVisible = false
    @State private var playbackGeneration = 0

    // The supplied movie advertises an alpha channel but its background is opaque.
    // Key out near-black pixels so the HUD surface remains visible behind it.
    private static let blackBackgroundCube: Data = {
        let dimension = 32
        var values: [Float] = []
        values.reserveCapacity(dimension * dimension * dimension * 4)
        for blue in 0..<dimension {
            for green in 0..<dimension {
                for red in 0..<dimension {
                    let r = Float(red) / Float(dimension - 1)
                    let g = Float(green) / Float(dimension - 1)
                    let b = Float(blue) / Float(dimension - 1)
                    let t = min(1, max(0, (max(r, g, b) - 0.025) / 0.12))
                    let alpha = t * t * (3 - 2 * t)
                    values.append(contentsOf: [r * alpha, g * alpha, b * alpha, alpha])
                }
            }
        }
        return values.withUnsafeBufferPointer { Data(buffer: $0) }
    }()

    var body: some View {
        Group {
            if let p = player {
                AirPodsVideoPlayerRepresentable(player: p)
            } else {
                Image(systemName: "airpodspro")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .onAppear { isVisible = true; updatePlayback() }
        .onChange(of: isActive) { _, _ in updatePlayback() }
        .onDisappear { isVisible = false; stopPlayback() }
    }

    private func updatePlayback() {
        guard isVisible && isActive else { stopPlayback(); return }
        guard player == nil else { return }
        playbackGeneration += 1
        let generation = playbackGeneration
        AirPodsVideoCache.shared.resolveVideoURL { url in
            guard let url, self.isVisible, self.isActive,
                  self.playbackGeneration == generation, self.player == nil else { return }
            let asset = AVURLAsset(url: url)
            let item = AVPlayerItem(asset: asset)
            item.videoComposition = AVVideoComposition(asset: asset) { request in
                guard let filter = CIFilter(name: "CIColorCube") else {
                    request.finish(with: request.sourceImage, context: nil)
                    return
                }
                filter.setValue(request.sourceImage.clampedToExtent(), forKey: kCIInputImageKey)
                filter.setValue(32, forKey: "inputCubeDimension")
                filter.setValue(Self.blackBackgroundCube, forKey: "inputCubeData")
                let image = (filter.outputImage ?? request.sourceImage).cropped(to: request.sourceImage.extent)
                request.finish(with: image, context: nil)
            }
            let videoPlayer = AVQueuePlayer()
            videoPlayer.isMuted = true
            let videoLooper = AVPlayerLooper(player: videoPlayer, templateItem: item)
            self.player = videoPlayer
            self.looper = videoLooper
            videoPlayer.play()
        }
    }

    private func stopPlayback() {
        playbackGeneration += 1
        player?.pause()
        looper?.disableLooping()
        player?.removeAllItems()
        looper = nil
        player = nil
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
