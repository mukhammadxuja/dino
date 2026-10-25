//
//  VolumeManager.swift
//  boringNotch
//
//  Created by JeanLouis on 22/08/2025.
//

import AppKit
import AVFoundation
import Combine
import CoreAudio
import CoreLocation
import CoreMediaIO
import Defaults
import Foundation
import IOBluetooth

final class VolumeManager: NSObject, ObservableObject {
    static let shared = VolumeManager()

    @Published private(set) var rawVolume: Float = 0
    @Published private(set) var isMuted: Bool = false
    @Published private(set) var lastChangeAt: Date = .distantPast

    let visibleDuration: TimeInterval = 1.2

    private var didInitialFetch = false
    private let step: Float32 = 1.0 / 16.0
    // Fallback software if hardware mute is not supported
    private var previousVolumeBeforeMute: Float32 = 0.2
    private var softwareMuted: Bool = false
    private let audioHardwareQueue = DispatchQueue(label: "com.boringnotch.audioHardware", qos: .userInteractive)

    private override init() {
        super.init()
        setupAudioListener()
        audioHardwareQueue.async { [weak self] in
            self?.fetchCurrentVolume()
        }
    }

    var shouldShowOverlay: Bool { Date().timeIntervalSince(lastChangeAt) < visibleDuration }

    // MARK: - Public Control API
    @MainActor func increase(stepDivisor: Float = 1.0) {
        let divisor = max(stepDivisor, 0.25)
        let delta = step / Float32(divisor)
        let current = didInitialFetch ? rawVolume : (readVolumeInternal() ?? rawVolume)
        let target = max(0, min(1, current + delta))
        
        // 1. Immediately update UI state at 0-th millisecond
        self.rawVolume = target
        self.lastChangeAt = Date()
        if self.isMuted && target > 0 {
            self.isMuted = false
        }
        BoringViewCoordinator.shared.toggleSneakPeek(status: true, type: .volume, value: CGFloat(target))
        
        // 2. Offload CoreAudio hardware driver calls to background queue
        writeVolumeAsync(target)
    }

    @MainActor func decrease(stepDivisor: Float = 1.0) {
        let divisor = max(stepDivisor, 0.25)
        let delta = step / Float32(divisor)
        let current = didInitialFetch ? rawVolume : (readVolumeInternal() ?? rawVolume)
        let target = max(0, min(1, current - delta))
        
        // 1. Immediately update UI state at 0-th millisecond
        self.rawVolume = target
        self.lastChangeAt = Date()
        if target == 0 {
            self.isMuted = true
        }
        BoringViewCoordinator.shared.toggleSneakPeek(status: true, type: .volume, value: CGFloat(target))
        
        // 2. Offload CoreAudio hardware driver calls to background queue
        writeVolumeAsync(target)
    }

    @MainActor func toggleMuteAction() {
        let willBeMuted = !self.isMuted
        let resultingVolume: Float32 = willBeMuted ? 0 : (rawVolume > 0 ? rawVolume : 0.25)

        // 1. Immediately update UI state at 0-th millisecond
        self.isMuted = willBeMuted
        self.lastChangeAt = Date()
        BoringViewCoordinator.shared.toggleSneakPeek(status: true, type: .volume, value: CGFloat(resultingVolume))

        // 2. Offload hardware mute toggle to background queue
        audioHardwareQueue.async { [weak self] in
            self?.toggleMuteInternal()
        }
    }
    
    func refresh() {
        audioHardwareQueue.async { [weak self] in
            self?.fetchCurrentVolume()
        }
    }

    func adjustRelative(delta: Float32) {
        audioHardwareQueue.async { [weak self] in
            guard let self = self else { return }
            if self.isMutedInternal() { self.toggleMuteInternal() }
            guard let current = self.readVolumeInternal() else {
                self.fetchCurrentVolume()
                return
            }
            let target = max(0, min(1, current + delta))
            self.writeVolumeInternal(target)  
            self.publish(volume: target, muted: self.isMutedInternal(), touchDate: true)
        }
    }

    @MainActor func setAbsolute(_ value: Float32) {
        let clamped = max(0, min(1, value))
        self.rawVolume = clamped
        self.lastChangeAt = Date()
        if self.isMuted && clamped > 0 {
            self.isMuted = false
        } else if clamped == 0 && !self.isMuted {
            self.isMuted = true
        }

        writeVolumeAsync(clamped)
    }

    private func writeVolumeAsync(_ value: Float32) {
        audioHardwareQueue.async { [weak self] in
            guard let self = self else { return }
            let isMuted = self.isMutedInternal()
            if isMuted && value > 0 {
                self.setMuteInternal(false)
            } else if value == 0 && !isMuted {
                self.setMuteInternal(true)
            }
            self.writeVolumeInternal(value)
        }
    }

    private func setMuteInternal(_ muted: Bool) {
        let deviceID = systemOutputDeviceID()
        if deviceID == kAudioObjectUnknown {
            if muted != softwareMuted {
                performSoftwareMuteToggle(currentVolume: rawVolume)
            }
            return
        }
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &muteAddr) else {
            if muted != softwareMuted {
                let currentVol = readVolumeInternal() ?? rawVolume
                performSoftwareMuteToggle(currentVolume: currentVol)
            }
            return
        }
        var sizeNeeded: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &muteAddr, 0, nil, &sizeNeeded) == noErr,
            sizeNeeded == UInt32(MemoryLayout<UInt32>.size)
        else {
            if muted != softwareMuted {
                let currentVol = readVolumeInternal() ?? rawVolume
                performSoftwareMuteToggle(currentVolume: currentVol)
            }
            return
        }
        var val: UInt32 = muted ? 1 : 0
        AudioObjectSetPropertyData(deviceID, &muteAddr, 0, nil, sizeNeeded, &val)
    }

    // MARK: - CoreAudio Helpers
    private func systemOutputDeviceID() -> AudioObjectID {
        var defaultDeviceID = kAudioObjectUnknown
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &defaultDeviceID
        )
        if status != noErr { return kAudioObjectUnknown }
        return defaultDeviceID
    }

    private func fetchCurrentVolume() {
        let deviceID = systemOutputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return }
        var volumes: [Float32] = []
        let candidateElements: [UInt32] = [kAudioObjectPropertyElementMain, 1, 2, 3, 4]
        for element in candidateElements {
            if let v = readValidatedScalar(deviceID: deviceID, element: element) {
                volumes.append(v)
            }
        }
        if !volumes.isEmpty {
            let avg = max(0, min(1, volumes.reduce(0, +) / Float32(volumes.count)))
            DispatchQueue.main.async {
                if self.rawVolume != avg {  
                    if self.didInitialFetch {
                        self.lastChangeAt = Date()
                    }
                }
                self.rawVolume = avg
                self.didInitialFetch = true

            }
        }

        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(deviceID, &muteAddr) {
            var sizeNeeded: UInt32 = 0
            if AudioObjectGetPropertyDataSize(deviceID, &muteAddr, 0, nil, &sizeNeeded) == noErr,
                sizeNeeded == UInt32(MemoryLayout<UInt32>.size)
            {
                var muted: UInt32 = 0
                var mSize = sizeNeeded
                if AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &mSize, &muted) == noErr
                {
                    let newMuted = muted != 0
                    DispatchQueue.main.async {
                        if self.isMuted != newMuted { self.lastChangeAt = Date() }
                        self.isMuted = newMuted
                    }
                }
            }
        }
    }

    private func setupAudioListener() {
        let deviceID = systemOutputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return }

        var defaultDevAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &defaultDevAddr, nil
        ) { [weak self] _, _ in
            self?.audioHardwareQueue.async {
                self?.fetchCurrentVolume()
            }
        }

        var masterAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(deviceID, &masterAddr) {
            AudioObjectAddPropertyListenerBlock(deviceID, &masterAddr, nil) { [weak self] _, _ in
                self?.audioHardwareQueue.async {
                    self?.fetchCurrentVolume()
                }
            }
        } else {
            for ch in [UInt32(1), UInt32(2)] {
                var chAddr = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyVolumeScalar,
                    mScope: kAudioDevicePropertyScopeOutput,
                    mElement: ch
                )
                if AudioObjectHasProperty(deviceID, &chAddr) {
                    AudioObjectAddPropertyListenerBlock(deviceID, &chAddr, nil) { [weak self] _, _ in
                        self?.audioHardwareQueue.async {
                            self?.fetchCurrentVolume()
                        }
                    }
                }
            }
        }

        // Mute
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(deviceID, &muteAddr) {
            AudioObjectAddPropertyListenerBlock(deviceID, &muteAddr, nil) { [weak self] _, _ in
                self?.audioHardwareQueue.async {
                    self?.fetchCurrentVolume()
                }
            }
        }
    }

    private func readVolumeInternal() -> Float32? {
        let deviceID = systemOutputDeviceID()
        if deviceID == kAudioObjectUnknown { return nil }
        var collected: [Float32] = []
        for el in [kAudioObjectPropertyElementMain, 1, 2, 3, 4] {
            if let v = readValidatedScalar(deviceID: deviceID, element: el) { collected.append(v) }
        }
        guard !collected.isEmpty else { return nil }
        return collected.reduce(0, +) / Float32(collected.count)
    }

    private func writeVolumeInternal(_ value: Float32) {
        let deviceID = systemOutputDeviceID()
        if deviceID == kAudioObjectUnknown { return }
        let newVal = max(0, min(1, value))

        var written = false
        if writeValidatedScalar(
            deviceID: deviceID, element: kAudioObjectPropertyElementMain, value: newVal)
        {
            written = true
        } else {
            var any = false
            for el in [UInt32](1...4) {
                if writeValidatedScalar(deviceID: deviceID, element: el, value: newVal) {
                    any = true
                }
            }
            written = any
        }
        if !written {
            // silent fail
        }
    }

    private func isMutedInternal() -> Bool {
        let deviceID = systemOutputDeviceID()
        if deviceID == kAudioObjectUnknown { return softwareMuted }
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &muteAddr) else { return softwareMuted }
        var sizeNeeded: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &muteAddr, 0, nil, &sizeNeeded) == noErr,
            sizeNeeded == UInt32(MemoryLayout<UInt32>.size)
        else { return softwareMuted }
        var muted: UInt32 = 0
        var size = sizeNeeded
        if AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &size, &muted) == noErr {
            return muted != 0
        }
        return softwareMuted
    }

    private func toggleMuteInternal() {
        let deviceID = systemOutputDeviceID()
        if deviceID == kAudioObjectUnknown {
            performSoftwareMuteToggle(currentVolume: rawVolume)
            return
        }
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if !AudioObjectHasProperty(deviceID, &muteAddr) {
            let currentVol = readVolumeInternal() ?? rawVolume
            performSoftwareMuteToggle(currentVolume: currentVol)
            return
        }
        var sizeNeeded: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &muteAddr, 0, nil, &sizeNeeded) == noErr,
            sizeNeeded == UInt32(MemoryLayout<UInt32>.size)
        else {
            let currentVol = readVolumeInternal() ?? rawVolume
            performSoftwareMuteToggle(currentVolume: currentVol)
            return
        }
        var muted: UInt32 = 0
        var size = sizeNeeded
        if AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &size, &muted) == noErr {
            var newVal: UInt32 = muted == 0 ? 1 : 0
            AudioObjectSetPropertyData(deviceID, &muteAddr, 0, nil, size, &newVal)
            let vol = readVolumeInternal() ?? rawVolume
            publish(volume: vol, muted: newVal != 0, touchDate: true)
        } else {
            let currentVol = readVolumeInternal() ?? rawVolume
            performSoftwareMuteToggle(currentVolume: currentVol)
        }
    }

    private func performSoftwareMuteToggle(currentVolume: Float32) {
        if softwareMuted {
            let restore = max(0, min(1, previousVolumeBeforeMute))
            writeVolumeInternal(restore)
            softwareMuted = false
            publish(volume: restore, muted: false, touchDate: true)
        } else {
            if currentVolume > 0.001 { previousVolumeBeforeMute = currentVolume }
            writeVolumeInternal(0)
            softwareMuted = true
            publish(volume: 0, muted: true, touchDate: true)
        }
    }

    private func readValidatedScalar(deviceID: AudioObjectID, element: UInt32) -> Float32? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        guard AudioObjectHasProperty(deviceID, &addr) else { return nil }
        var sizeNeeded: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &addr, 0, nil, &sizeNeeded) == noErr,
            sizeNeeded == UInt32(MemoryLayout<Float32>.size)
        else { return nil }
        var vol = Float32(0)
        var size = sizeNeeded
        let status = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &vol)
        return status == noErr ? vol : nil
    }

    private func writeValidatedScalar(deviceID: AudioObjectID, element: UInt32, value: Float32)
        -> Bool
    {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        guard AudioObjectHasProperty(deviceID, &addr) else { return false }
        var sizeNeeded: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &addr, 0, nil, &sizeNeeded) == noErr,
            sizeNeeded == UInt32(MemoryLayout<Float32>.size)
        else { return false }
        var val = value
        return AudioObjectSetPropertyData(deviceID, &addr, 0, nil, sizeNeeded, &val) == noErr
    }

    private func publish(volume: Float32, muted: Bool, touchDate: Bool) {
        DispatchQueue.main.async {
            if touchDate { self.lastChangeAt = Date() }
            self.rawVolume = volume
            self.isMuted = muted
        }
    }
}

extension Array where Element == Float32 {
    fileprivate var average: Float32? { isEmpty ? nil : reduce(0, +) / Float32(count) }
}

// MARK: - Microphone Manager (Input Devices & Mute Listener)
final class MicrophoneManager: NSObject, ObservableObject {
    static let shared = MicrophoneManager()

    @Published private(set) var isMuted: Bool = false
    @Published private(set) var rawVolume: Float32 = 1.0

    private var previousVolumeBeforeMute: Float32 = 0.8
    private var didInitialFetch = false
    private var currentListeningDeviceID: AudioObjectID = kAudioObjectUnknown

    override init() {
        super.init()
        setupInputListener()
        fetchCurrentInputState(isExternalChange: false)
    }

    func start() {
        // Ensures singleton is initialized and listening
    }

    // MARK: - Public Control API
    @MainActor func toggleMute() {
        let deviceID = systemInputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return }

        let willBeMuted = !isMuted
        setMuted(willBeMuted)

        BoringViewCoordinator.shared.toggleSneakPeek(
            status: true,
            type: .mic,
            duration: 1.8,
            value: willBeMuted ? 0.0 : 1.0
        )
    }

    func setMuted(_ muted: Bool) {
        let deviceID = systemInputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return }

        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var handledHardware = false
        if AudioObjectHasProperty(deviceID, &muteAddr) {
            var sizeNeeded: UInt32 = 0
            if AudioObjectGetPropertyDataSize(deviceID, &muteAddr, 0, nil, &sizeNeeded) == noErr,
               sizeNeeded == UInt32(MemoryLayout<UInt32>.size) {
                var val: UInt32 = muted ? 1 : 0
                if AudioObjectSetPropertyData(deviceID, &muteAddr, 0, nil, sizeNeeded, &val) == noErr {
                    handledHardware = true
                }
            }
        }

        if !handledHardware {
            // Software mute fallback by setting input volume scalar
            if muted {
                let current = readInputVolume() ?? rawVolume
                if current > 0.05 {
                    previousVolumeBeforeMute = current
                }
                writeInputVolume(0.0)
            } else {
                let restore = max(0.2, min(1.0, previousVolumeBeforeMute))
                writeInputVolume(restore)
            }
        }

        DispatchQueue.main.async {
            self.isMuted = muted
            self.rawVolume = muted ? 0.0 : self.previousVolumeBeforeMute
        }
    }

    // MARK: - CoreAudio Helpers
    fileprivate func systemInputDeviceID() -> AudioObjectID {
        var defaultDeviceID = kAudioObjectUnknown
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &defaultDeviceID
        )
        if status != noErr { return kAudioObjectUnknown }
        return defaultDeviceID
    }

    private func setupInputListener() {
        // Listen to default input device changes (e.g. user plugged in mic, connected AirPods)
        var defaultDevAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &defaultDevAddr, nil
        ) { [weak self] _, _ in
            self?.rebindInputDeviceListeners()
        }

        rebindInputDeviceListeners()
    }

    private func rebindInputDeviceListeners() {
        let deviceID = systemInputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return }
        currentListeningDeviceID = deviceID

        // 1. Mute listener
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(deviceID, &muteAddr) {
            AudioObjectAddPropertyListenerBlock(deviceID, &muteAddr, nil) { [weak self] _, _ in
                self?.fetchCurrentInputState(isExternalChange: true)
            }
        }

        // 2. Volume listener
        for el in [kAudioObjectPropertyElementMain, UInt32(1), UInt32(2)] {
            var volAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: el
            )
            if AudioObjectHasProperty(deviceID, &volAddr) {
                AudioObjectAddPropertyListenerBlock(deviceID, &volAddr, nil) { [weak self] _, _ in
                    self?.fetchCurrentInputState(isExternalChange: true)
                }
            }
        }

        fetchCurrentInputState(isExternalChange: false)
    }

    private func fetchCurrentInputState(isExternalChange: Bool) {
        let deviceID = systemInputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return }

        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var hardwareMuted = false
        if AudioObjectHasProperty(deviceID, &muteAddr) {
            var sizeNeeded: UInt32 = 0
            if AudioObjectGetPropertyDataSize(deviceID, &muteAddr, 0, nil, &sizeNeeded) == noErr,
               sizeNeeded == UInt32(MemoryLayout<UInt32>.size) {
                var muted: UInt32 = 0
                var size = sizeNeeded
                if AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &size, &muted) == noErr {
                    hardwareMuted = (muted != 0)
                }
            }
        }

        let inputVol = readInputVolume() ?? (hardwareMuted ? 0.0 : 1.0)
        let effectiveMuted = hardwareMuted || inputVol.isZero

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !effectiveMuted && inputVol > 0.05 {
                self.previousVolumeBeforeMute = inputVol
            }
            let stateChanged = (self.isMuted != effectiveMuted)
            self.isMuted = effectiveMuted
            self.rawVolume = inputVol

            if self.didInitialFetch && isExternalChange && stateChanged {
                BoringViewCoordinator.shared.toggleSneakPeek(
                    status: true,
                    type: .mic,
                    duration: 1.8,
                    value: effectiveMuted ? 0.0 : 1.0
                )
            }
            self.didInitialFetch = true
        }
    }

    private func readInputVolume() -> Float32? {
        let deviceID = systemInputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return nil }

        for el in [kAudioObjectPropertyElementMain, UInt32(1), UInt32(2)] {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: el
            )
            if AudioObjectHasProperty(deviceID, &addr) {
                var sizeNeeded: UInt32 = 0
                if AudioObjectGetPropertyDataSize(deviceID, &addr, 0, nil, &sizeNeeded) == noErr,
                   sizeNeeded == UInt32(MemoryLayout<Float32>.size) {
                    var vol: Float32 = 0
                    var size = sizeNeeded
                    if AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &vol) == noErr {
                        return vol
                    }
                }
            }
        }
        return nil
    }

    private func writeInputVolume(_ value: Float32) {
        let deviceID = systemInputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return }

        for el in [kAudioObjectPropertyElementMain, UInt32(1), UInt32(2)] {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: el
            )
            if AudioObjectHasProperty(deviceID, &addr) {
                var sizeNeeded: UInt32 = 0
                if AudioObjectGetPropertyDataSize(deviceID, &addr, 0, nil, &sizeNeeded) == noErr,
                   sizeNeeded == UInt32(MemoryLayout<Float32>.size) {
                    var val = value
                    AudioObjectSetPropertyData(deviceID, &addr, 0, nil, sizeNeeded, &val)
                }
            }
        }
    }
}

// MARK: - Privacy HUD Manager (Camera, Mic In-Use & Screen Recording Monitor)
final class PrivacyHUDManager: NSObject, ObservableObject {
    static let shared = PrivacyHUDManager()

    @Published private(set) var isCameraActive: Bool = false
    @Published private(set) var isMicInUse: Bool = false
    @Published private(set) var isScreenRecording: Bool = false
    @Published private(set) var isLocationActive: Bool = false

    private var didInitialCameraFetch = false
    private var didInitialMicFetch = false
    private var didInitialRecordingFetch = false
    private var didInitialLocationFetch = false
    private var screenRecordPollTimer: Timer?
    private var locationManager: CLLocationManager?
    private var lastLocationAuthStatus: CLAuthorizationStatus?
    private var lastLocationTriggerTime: Date = .distantPast

    override init() {
        super.init()
        setupCameraListener()
        setupMicInUseListener()
        setupScreenRecordListener()
        setupLocationListener()
    }

    func start() {
        // Initializes singleton
    }

    // MARK: - Camera Detection via CoreMediaIO
    private func setupCameraListener() {
        var devicesAddr = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(0)
        )

        CMIOObjectAddPropertyListenerBlock(
            CMIOObjectID(kCMIOObjectSystemObject),
            &devicesAddr,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.bindCameraListeners()
        }

        bindCameraListeners()
    }

    private func bindCameraListeners() {
        let deviceIDs = getAllVideoDeviceIDs()
        for devID in deviceIDs {
            var isRunningAddr = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(0)
            )

            CMIOObjectAddPropertyListenerBlock(
                devID,
                &isRunningAddr,
                DispatchQueue.main
            ) { [weak self] _, _ in
                self?.evaluateCameraState()
            }
        }

        evaluateCameraState()
    }

    private func getAllVideoDeviceIDs() -> [CMIOObjectID] {
        var addr = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(0)
        )
        var dataSize: UInt32 = 0
        var dataUsed: UInt32 = 0
        let status = CMIOObjectGetPropertyDataSize(
            CMIOObjectID(kCMIOObjectSystemObject),
            &addr,
            0,
            nil,
            &dataSize
        )
        guard status == kCMIOHardwareNoError, dataSize > 0 else { return [] }

        let count = Int(dataSize) / MemoryLayout<CMIOObjectID>.size
        var devices = [CMIOObjectID](repeating: 0, count: count)
        let fetchStatus = devices.withUnsafeMutableBytes { ptr in
            CMIOObjectGetPropertyData(
                CMIOObjectID(kCMIOObjectSystemObject),
                &addr,
                0,
                nil,
                dataSize,
                &dataUsed,
                ptr.baseAddress
            )
        }
        guard fetchStatus == kCMIOHardwareNoError else { return [] }
        return devices
    }

    private var isCameraUsedByMirror: Bool = false

    private func evaluateCameraState() {
        let deviceIDs = getAllVideoDeviceIDs()
        var runningSomewhere = false

        for devID in deviceIDs {
            var isRunningAddr = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(0)
            )
            var isRunning: UInt32 = 0
            var runningSize = UInt32(MemoryLayout<UInt32>.size)
            var runningUsed: UInt32 = 0
            let s = CMIOObjectGetPropertyData(
                devID,
                &isRunningAddr,
                0,
                nil,
                runningSize,
                &runningUsed,
                &isRunning
            )
            if s == kCMIOHardwareNoError && isRunning != 0 {
                runningSomewhere = true
                break
            }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let stateChanged = (self.isCameraActive != runningSomewhere)
            self.isCameraActive = runningSomewhere

            let isMirrorActive = (DinoCoordinator.shared.activeSlot == .webcam)
            if runningSomewhere && isMirrorActive {
                self.isCameraUsedByMirror = true
            }

            if self.didInitialCameraFetch && stateChanged {
                if runningSomewhere {
                    // Suppress camera HUD if boringNotch Mirror itself opened the camera
                    if !self.isCameraUsedByMirror {
                        BoringViewCoordinator.shared.toggleSneakPeek(
                            status: true,
                            type: .camera,
                            duration: 2.5,
                            value: 1.0
                        )
                    }
                } else {
                    // Camera turned off
                    if self.isCameraUsedByMirror {
                        self.isCameraUsedByMirror = false
                    } else {
                        BoringViewCoordinator.shared.toggleSneakPeek(
                            status: true,
                            type: .camera,
                            duration: 1.8,
                            value: 0.0
                        )
                    }
                }
            }
            self.didInitialCameraFetch = true
        }
    }

    // MARK: - Microphone In-Use Detection (Privacy Indicator)
    private func setupMicInUseListener() {
        var defaultDevAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDevAddr,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.bindMicInUseListener()
        }

        bindMicInUseListener()
    }

    private func bindMicInUseListener() {
        let devID = MicrophoneManager.shared.systemInputDeviceID()
        guard devID != kAudioObjectUnknown else { return }

        var runningAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        if AudioObjectHasProperty(devID, &runningAddr) {
            AudioObjectAddPropertyListenerBlock(
                devID,
                &runningAddr,
                DispatchQueue.main
            ) { [weak self] _, _ in
                self?.evaluateMicInUseState()
            }
        }

        evaluateMicInUseState()
    }

    func evaluateMicInUseState() {
        let devID = MicrophoneManager.shared.systemInputDeviceID()
        guard devID != kAudioObjectUnknown else { return }

        var runningAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(
            devID,
            &runningAddr,
            0,
            nil,
            &size,
            &isRunning
        )

        let active = (status == noErr && isRunning != 0)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let stateChanged = (self.isMicInUse != active)
            self.isMicInUse = active

            if self.didInitialMicFetch && stateChanged {
                BoringViewCoordinator.shared.toggleSneakPeek(
                    status: true,
                    type: .micActivity,
                    duration: active ? 2.5 : 1.8,
                    value: active ? 1.0 : 0.0
                )
            }
            self.didInitialMicFetch = true
        }
    }

    // MARK: - Screen Recording Detection (Video Only)
    private func setupScreenRecordListener() {
        screenRecordPollTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            self?.evaluateScreenRecordingState()
        }
        evaluateScreenRecordingState()
    }

    private func evaluateScreenRecordingState() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let isRunning = self?.checkScreenCaptureProcess() ?? false
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.evaluateMicInUseState()
                let stateChanged = (self.isScreenRecording != isRunning)
                self.isScreenRecording = isRunning

                if self.didInitialRecordingFetch && stateChanged {
                    BoringViewCoordinator.shared.toggleSneakPeek(
                        status: true,
                        type: .screenRecord,
                        duration: isRunning ? 2.5 : 1.8,
                        value: isRunning ? 1.0 : 0.0
                    )
                }
                self.didInitialRecordingFetch = true
            }
        }
    }

    private func checkScreenCaptureProcess() -> Bool {
        // 1. Check if screencapture is actively writing to a video (.mov) file
        let lsofTask = Process()
        lsofTask.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        lsofTask.arguments = ["-c", "screencapture"]
        let pipe = Pipe()
        lsofTask.standardOutput = pipe
        lsofTask.standardError = FileHandle.nullDevice
        do {
            try lsofTask.run()
            lsofTask.waitUntilExit()
            if lsofTask.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8),
                   output.localizedCaseInsensitiveContains(".mov") {
                    return true
                }
            }
        } catch {}

        // 2. Check for active screencapture video process (CLI or Cmd+Shift+5 toolbar)
        let pgrepTask = Process()
        pgrepTask.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        pgrepTask.arguments = ["-f", "screencapture.*(-v|-V|-pdiU)"]
        do {
            try pgrepTask.run()
            pgrepTask.waitUntilExit()
            if pgrepTask.terminationStatus == 0 {
                return true
            }
        } catch {}

        return false
    }

    // MARK: - Location In-Use Detection (Privacy Indicator)
    private func setupLocationListener() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        let names = [
            "com.apple.locationd.registration",
            "com.apple.locationd/Prefs",
            "com.apple.locationd.status",
            "com.apple.locationd.active"
        ]
        for name in names {
            CFNotificationCenterAddObserver(
                center,
                observer,
                { _, observer, _, _, _ in
                    guard let observer = observer else { return }
                    let manager = Unmanaged<PrivacyHUDManager>.fromOpaque(observer).takeUnretainedValue()
                    manager.evaluateLocationState()
                },
                name as CFString,
                nil,
                .deliverImmediately
            )
        }

        if Defaults[.hudLocationEnabled] {
            enableLocationTrackingIfNeeded()
        }
    }

    func enableLocationTrackingIfNeeded() {
        guard Defaults[.hudLocationEnabled] else { return }
        if locationManager == nil {
            let loc = CLLocationManager()
            loc.delegate = self
            self.locationManager = loc
            self.lastLocationAuthStatus = loc.authorizationStatus
        }

        if let loc = locationManager, loc.authorizationStatus == .notDetermined {
            loc.requestWhenInUseAuthorization()
        }
    }

    private func evaluateLocationState() {
        guard didInitialLocationFetch else {
            didInitialLocationFetch = true
            return
        }
        triggerLocationHUD()
    }

    func updateLocationState(_ active: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let stateChanged = (self.isLocationActive != active)
            self.isLocationActive = active

            if self.didInitialLocationFetch && stateChanged {
                BoringViewCoordinator.shared.toggleSneakPeek(
                    status: true,
                    type: .location,
                    duration: active ? 2.5 : 1.8,
                    value: active ? 1.0 : 0.0
                )
            }
            self.didInitialLocationFetch = true
        }
    }
}

extension PrivacyHUDManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let old = lastLocationAuthStatus
        lastLocationAuthStatus = status

        if status == .authorizedAlways || status == .authorized {
            if old != status {
                triggerLocationHUD()
                manager.requestLocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        triggerLocationHUD()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // CoreLocation requires didFailWithError when requestLocation() is used
    }

    func triggerLocationHUD() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let now = Date()
            guard now.timeIntervalSince(self.lastLocationTriggerTime) > 2.0 else { return }
            self.lastLocationTriggerTime = now

            self.isLocationActive = true
            BoringViewCoordinator.shared.toggleSneakPeek(
                status: true,
                type: .location,
                duration: 2.5,
                value: 1.0
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.isLocationActive = false
            }
        }
    }
}

// MARK: - Caps Lock Indicator Manager
final class CapsLockManager: NSObject {
    static let shared = CapsLockManager()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastState: Bool = false
    private var isStarted = false

    override init() {
        super.init()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true

        lastState = NSEvent.modifierFlags.contains(.capsLock)

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let currentState = event.modifierFlags.contains(.capsLock)
        if currentState != lastState {
            lastState = currentState
            DispatchQueue.main.async {
                BoringViewCoordinator.shared.toggleSneakPeek(
                    status: true,
                    type: .capsLock,
                    duration: 1.5,
                    value: currentState ? 1.0 : 0.0
                )
            }
        }
    }

    deinit {
        if let g = globalMonitor { NSEvent.removeMonitor(g) }
        if let l = localMonitor { NSEvent.removeMonitor(l) }
    }
}

// MARK: - Bluetooth & AirPods Connect HUD Manager
final class BluetoothHUDManager: NSObject {
    static let shared = BluetoothHUDManager()

    private var connectNotification: IOBluetoothUserNotification?
    private var didInitialFetch = false
    private var isStarted = false
    private var lastConnectedDeviceAddress: String = ""
    private var connectAudioPlayer: AVAudioPlayer?

    override init() {
        super.init()
        prewarmConnectSound()
    }

    func start() {
        guard Defaults[.hudAirPodsEnabled] else { return }
        guard !isStarted else { return }
        isStarted = true

        prewarmConnectSound()
        setupBluetoothConnectListener()
        setupAudioOutputListener()
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        connectNotification?.unregister()
        connectNotification = nil
    }

    func prewarmConnectSound() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self, self.connectAudioPlayer == nil else { return }
            let player = self.createConnectAudioPlayer()
            player?.prepareToPlay()
            DispatchQueue.main.async {
                self.connectAudioPlayer = player
                print("🔊 [BluetoothHUDManager] Pre-warmed connect.wav audio player")
            }
        }
    }

    private func createConnectAudioPlayer() -> AVAudioPlayer? {
        // 1. Try loading from compiled NSDataAsset in Assets.car
        if let asset = NSDataAsset(name: "connect") {
            if let player = try? AVAudioPlayer(data: asset.data) {
                player.volume = 1.0
                return player
            }
        }
        // 2. Try loading from Bundle resource URL
        if let url = Bundle.main.url(forResource: "connect", withExtension: "wav") {
            if let player = try? AVAudioPlayer(contentsOf: url) {
                player.volume = 1.0
                return player
            }
        }
        // 3. Fallback direct file path in Assets directory
        let fallbackPath = "/Users/macbookair/Desktop/Projects/My Projects/Dino/boringNotch/Assets.xcassets/connect.wav"
        if FileManager.default.fileExists(atPath: fallbackPath) {
            if let player = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: fallbackPath)) {
                player.volume = 1.0
                return player
            }
        }
        return nil
    }

    func playConnectSound() {
        if let player = connectAudioPlayer {
            if player.isPlaying {
                player.stop()
                player.currentTime = 0
            }
            player.play()
            return
        }

        if let player = createConnectAudioPlayer() {
            player.prepareToPlay()
            player.play()
            connectAudioPlayer = player
        }
    }

    private func setupBluetoothConnectListener() {
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnected(_:device:))
        ) as? IOBluetoothUserNotification
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.handleDeviceConnection(device)
        }
    }

    private func handleDeviceConnection(_ device: IOBluetoothDevice) {
        guard let name = device.name, !name.isEmpty else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                if let retryName = device.name, !retryName.isEmpty {
                    self?.handleDeviceConnection(device)
                }
            }
            return
        }

        let addr = device.addressString ?? name
        if addr == lastConnectedDeviceAddress { return }
        lastConnectedDeviceAddress = addr

        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            if self?.lastConnectedDeviceAddress == addr {
                self?.lastConnectedDeviceAddress = ""
            }
        }

        let battery = readBattery(for: device)
        triggerAirPodsHUD(deviceName: name, battery: battery)
    }

    func triggerAirPodsHUD(deviceName: String, battery: Int) {
        DispatchQueue.main.async {
            BoringViewCoordinator.shared.toggleSneakPeek(
                status: true,
                type: .airPods,
                duration: 3.8,
                value: CGFloat(battery),
                icon: deviceName
            )
        }
    }

    private func readBattery(for device: IOBluetoothDevice) -> Int {
        func getBatteryValue(_ selectorName: String) -> Int? {
            let sel = Selector((selectorName))
            guard device.responds(to: sel) else { return nil }
            if let method = class_getInstanceMethod(type(of: device), sel) {
                let imp = method_getImplementation(method)
                let fn = unsafeBitCast(imp, to: (@convention(c) (AnyObject, Selector) -> UInt8).self)
                let val = fn(device, sel)
                if val > 0 && val <= 100 {
                    return Int(val)
                }
            }
            return nil
        }

        if let single = getBatteryValue("batteryPercentSingle") {
            return single
        }

        let left = getBatteryValue("batteryPercentLeft")
        let right = getBatteryValue("batteryPercentRight")
        if let l = left, let r = right {
            return (l + r) / 2
        } else if let l = left {
            return l
        } else if let r = right {
            return r
        }

        if let combined = getBatteryValue("batteryPercentCombined") {
            return combined
        }

        if let caseBat = getBatteryValue("batteryPercentCase") {
            return caseBat
        }

        return 92
    }

    private func setupAudioOutputListener() {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &addr,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.evaluateAudioOutputChange()
        }
    }

    private func evaluateAudioOutputChange() {
        guard didInitialFetch else {
            didInitialFetch = true
            return
        }

        var devID = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &devID) == noErr else { return }

        var nameAddr = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var nameCF: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(devID, &nameAddr, 0, nil, &nameSize, &nameCF) == noErr else { return }
        let devName = nameCF as String

        if devName.localizedCaseInsensitiveContains("airpods")
            || devName.localizedCaseInsensitiveContains("beats")
            || devName.localizedCaseInsensitiveContains("headphone") {
            triggerAirPodsHUD(deviceName: devName, battery: 94)
        }
    }
}




