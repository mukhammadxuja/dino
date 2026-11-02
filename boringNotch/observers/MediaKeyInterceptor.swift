//
//  MediaKeyInterceptor.swift
//  boringNotch
//
//  Created by Alexander on 2025-11-23.

import Foundation
import AppKit
import ApplicationServices
import Combine
import Defaults
import AVFoundation

private let kSystemDefinedEventType = CGEventType(rawValue: 14)!

@MainActor
final class MediaKeyInterceptor: ObservableObject {
    static let shared = MediaKeyInterceptor()

    enum ActivationState: Equatable {
        case disabled
        case needsPermission
        case starting
        case active
        case failed
    }

    @Published private(set) var activationState: ActivationState = .disabled
    
    private enum NXKeyType: Int {
        case soundUp = 0
        case soundDown = 1
        case brightnessUp = 2
        case brightnessDown = 3
        case mute = 7
        case keyboardBrightnessUp = 21
        case keyboardBrightnessDown = 22
    }
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lifecycleGeneration = 0
    private var isStarting = false
    private let step: Float = 1.0 / 16.0
    private var audioPlayer: AVAudioPlayer?
    private var isFeedbackSoundEnabled: Bool = false
    private var lastFeedbackCheck: Date = .distantPast
    
    private init() {
        prewarmAudio()
    }
    
    // MARK: - Event Tap
    
    func start() async {
        guard Defaults[.hudReplacement] else {
            stop()
            return
        }

        guard !isStarting else { return }
        isStarting = true
        let generation = lifecycleGeneration
        defer {
            if generation == lifecycleGeneration { isStarting = false }
        }

        let authorized = await XPCHelperClient.shared.isAccessibilityAuthorized()
        guard !Task.isCancelled,
              Defaults[.hudReplacement],
              generation == lifecycleGeneration else { return }
        guard authorized else {
            stopForMissingPermission()
            return
        }

        if let eventTap {
            if CFMachPortIsValid(eventTap) && CGEvent.tapIsEnabled(tap: eventTap) {
                activationState = .active
                return
            }
            stop()
        }

        activationState = .starting
        let mask = CGEventMask(1 << kSystemDefinedEventType.rawValue)
        // The HID entry point requires root; the session tap runs in the user's app.
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, cgEvent, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(cgEvent) }
                let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
                return MainActor.assumeIsolated {
                    interceptor.handleEvent(cgEvent)
                }
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            activationState = .failed
            NSLog("Dino HUD: unable to create session event tap (Accessibility authorized: \(AXIsProcessTrusted()))")
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            activationState = .failed
            NSLog("Dino HUD: unable to create event tap run-loop source")
            return
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        guard CGEvent.tapIsEnabled(tap: tap) else {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            CFMachPortInvalidate(tap)
            activationState = .failed
            NSLog("Dino HUD: event tap could not be enabled")
            return
        }

        eventTap = tap
        runLoopSource = source
        activationState = .active
        if audioPlayer == nil { prewarmAudio() }
    }
    
    func stop() {
        lifecycleGeneration &+= 1
        isStarting = false
        if let eventTap, CFMachPortIsValid(eventTap) {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
        activationState = .disabled
    }

    func stopForMissingPermission() {
        guard activationState != .needsPermission || eventTap != nil || isStarting else { return }
        stop()
        activationState = .needsPermission
    }
    
    // MARK: - Event Handling
    
    private func handleEvent(_ cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
        if cgEvent.type == .tapDisabledByTimeout || cgEvent.type == .tapDisabledByUserInput {
            if AXIsProcessTrusted(), Defaults[.hudReplacement], let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
                if CGEvent.tapIsEnabled(tap: eventTap) {
                    activationState = .active
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.stop()
                        self?.activationState = .failed
                        NSLog("Dino HUD: event tap was disabled and could not be restarted")
                    }
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.stopForMissingPermission()
                }
            }
            return Unmanaged.passUnretained(cgEvent)
        }

        // Ensure the CGEvent has a valid type before converting to NSEvent
        guard cgEvent.type != .null else {
            return Unmanaged.passUnretained(cgEvent)
        }
        guard let nsEvent = NSEvent(cgEvent: cgEvent),
              nsEvent.type == .systemDefined,
              nsEvent.subtype.rawValue == 8 else {
            return Unmanaged.passUnretained(cgEvent)
        }
        
        let data1 = nsEvent.data1
        let keyCode = (data1 & 0xFFFF_0000) >> 16
        let stateByte = ((data1 & 0xFF00) >> 8)
        
        // 0xA = key down, 0xB = key up. Only handle key down.
        guard stateByte == 0xA,
              let keyType = NXKeyType(rawValue: keyCode) else {
            return Unmanaged.passUnretained(cgEvent)
        }
        
        let flags = nsEvent.modifierFlags
        let option = flags.contains(.option)
        let shift = flags.contains(.shift)
        let command = flags.contains(.command)
        
        // Handle option key action (without shift)
        if option && !shift {
            if handleOptionAction(for: keyType, command: command) {
                return nil
            }
        }
        
        // Handle normal key press
        handleKeyPress(keyType: keyType, option: option, shift: shift, command: command)
        return nil
    }
    
    private func handleOptionAction(for keyType: NXKeyType, command: Bool) -> Bool {
        openSystemSettings(for: keyType, command: command)
        return true
    }
    
    private func prewarmAudio() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // 1. Pre-read and cache feedback sound setting from NSGlobalDomain
            let feedback = UserDefaults.standard.persistentDomain(forName: "NSGlobalDomain")?["com.apple.sound.beep.feedback"] as? Int
            let enabled = (feedback == 1)

            // 2. Pre-load audio player and pre-warm audio hardware buffer
            let defaultPath = "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff"
            var player: AVAudioPlayer? = nil
            if FileManager.default.fileExists(atPath: defaultPath) {
                do {
                    player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: defaultPath))
                    player?.volume = 1.0
                    player?.numberOfLoops = 0
                    player?.prepareToPlay()
                } catch {
                    print("⚠️ [MediaKeyInterceptor] Failed to pre-warm AVAudioPlayer: \(error.localizedDescription)")
                }
            } else {
                print("⚠️ [MediaKeyInterceptor] Default bezel audio not found at: \(defaultPath)")
            }

            DispatchQueue.main.async {
                self?.isFeedbackSoundEnabled = enabled
                self?.lastFeedbackCheck = Date()
                if let player = player {
                    self?.audioPlayer = player
                    print("🔊 [MediaKeyInterceptor] Pre-warmed Bezel audio player (feedback enabled: \(enabled))")
                }
            }
        }
    }

    private func prepareAudioPlayerIfNeeded() {
        guard audioPlayer == nil else { return }

        let defaultPath = "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff"
        if FileManager.default.fileExists(atPath: defaultPath) {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: defaultPath))
                print("🔊 [MediaKeyInterceptor] Loaded default Bezel audio from: \(defaultPath)")
            } catch {
                print("⚠️ [MediaKeyInterceptor] Failed to init AVAudioPlayer with default path \(defaultPath): \(error.localizedDescription)")
            }
        } else {
            print("⚠️ [MediaKeyInterceptor] Default bezel audio not found at: \(defaultPath)")
        }

        if let player = audioPlayer {
            player.volume = 1.0
            player.numberOfLoops = 0
            player.prepareToPlay()
        }
    }

    private func playFeedbackSound() {
        // Refresh feedback sound setting in the background at most once every 5 seconds (zero disk I/O on keypress)
        if Date().timeIntervalSince(lastFeedbackCheck) > 5.0 {
            lastFeedbackCheck = Date()
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let feedback = UserDefaults.standard.persistentDomain(forName: "NSGlobalDomain")?["com.apple.sound.beep.feedback"] as? Int
                let enabled = (feedback == 1)
                DispatchQueue.main.async {
                    self?.isFeedbackSoundEnabled = enabled
                }
            }
        }

        guard isFeedbackSoundEnabled else { return }

        guard let player = audioPlayer else {
            prepareAudioPlayerIfNeeded()
            return
        }

        if player.isPlaying {
            player.stop()
            player.currentTime = 0
        }
        player.play()
    }

    private func handleKeyPress(keyType: NXKeyType, option: Bool, shift: Bool, command: Bool) {
        let stepDivisor: Float = (option && shift) ? 4.0 : 1.0
        
        switch keyType {
        case .soundUp:
            DispatchQueue.main.async { [weak self] in
                self?.playFeedbackSound()
                VolumeManager.shared.increase(stepDivisor: stepDivisor)
            }
        case .soundDown:
            DispatchQueue.main.async { [weak self] in
                self?.playFeedbackSound()
                VolumeManager.shared.decrease(stepDivisor: stepDivisor)
            }
        case .mute:
            DispatchQueue.main.async {
                VolumeManager.shared.toggleMuteAction()
            }
        case .brightnessUp, .keyboardBrightnessUp:
            let delta = step / stepDivisor
            adjustBrightness(delta: delta, keyboard: keyType == .keyboardBrightnessUp || command)
        case .brightnessDown, .keyboardBrightnessDown:
            let delta = -(step / stepDivisor)
            adjustBrightness(delta: delta, keyboard: keyType == .keyboardBrightnessDown || command)
        }
    }
    
    private func adjustBrightness(delta: Float, keyboard: Bool) {
        DispatchQueue.main.async {
            if keyboard {
                KeyboardBacklightManager.shared.setRelative(delta: delta)
            } else {
                BrightnessManager.shared.setRelative(delta: delta)
            }
        }
    }
    

    
    private func openSystemSettings(for keyType: NXKeyType, command: Bool) {
        let urlString: String
        
        switch keyType {
        case .soundUp, .soundDown, .mute:
            urlString = "x-apple.systempreferences:com.apple.preference.sound"
        case .brightnessUp, .brightnessDown:
            if command {
                urlString = "x-apple.systempreferences:com.apple.preference.keyboard"
            } else {
                urlString = "x-apple.systempreferences:com.apple.preference.displays"
            }
        case .keyboardBrightnessUp, .keyboardBrightnessDown:
            urlString = "x-apple.systempreferences:com.apple.preference.keyboard"
        }
        
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
