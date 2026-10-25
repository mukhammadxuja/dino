//
//  VolumeManager.swift
//  boringNotch
//
//  Created by JeanLouis on 22/08/2025.
//

import AppKit
import Combine
import CoreAudio
import CoreMediaIO
import Foundation

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

    private override init() {
        super.init()
        setupAudioListener()
        fetchCurrentVolume()
    }

    var shouldShowOverlay: Bool { Date().timeIntervalSince(lastChangeAt) < visibleDuration }

    // MARK: - Public Control API
    @MainActor func increase(stepDivisor: Float = 1.0) {
        let divisor = max(stepDivisor, 0.25)
        let delta = step / Float32(divisor)
        let current = readVolumeInternal() ?? rawVolume
        let target = max(0, min(1, current + delta))
        setAbsolute(target)
        BoringViewCoordinator.shared.toggleSneakPeek(status: true, type: .volume, value: CGFloat(target))
    }

    @MainActor func decrease(stepDivisor: Float = 1.0) {
        let divisor = max(stepDivisor, 0.25)
        let delta = step / Float32(divisor)
        let current = readVolumeInternal() ?? rawVolume
        let target = max(0, min(1, current - delta))
        setAbsolute(target)
        BoringViewCoordinator.shared.toggleSneakPeek(status: true, type: .volume, value: CGFloat(target))
    }

    @MainActor func toggleMuteAction() {
        // Determine expected resulting state immediately and show HUD with that value
        let deviceID = systemOutputDeviceID()
        var willBeMuted = false
        var resultingVolume: Float32 = rawVolume

        if deviceID == kAudioObjectUnknown {
            willBeMuted = !softwareMuted
            resultingVolume = willBeMuted ? 0 : previousVolumeBeforeMute
        } else {
            let currentMuted = isMutedInternal()
            willBeMuted = !currentMuted
            resultingVolume = willBeMuted ? 0 : (readVolumeInternal() ?? rawVolume)
        }

        toggleMuteInternal()
        BoringViewCoordinator.shared.toggleSneakPeek(status: true, type: .volume, value: CGFloat(willBeMuted ? 0 : resultingVolume))
    }
    
    func refresh() { fetchCurrentVolume() }

    func adjustRelative(delta: Float32) {
        if isMutedInternal() { toggleMuteInternal() }
        guard let current = readVolumeInternal() else {
            fetchCurrentVolume()
            return
        }
        let target = max(0, min(1, current + delta))
        writeVolumeInternal(target)  
        publish(volume: target, muted: isMutedInternal(), touchDate: true)
    }

    @MainActor func setAbsolute(_ value: Float32) {
        let clamped = max(0, min(1, value))
        let currentlyMuted = isMutedInternal()
        if currentlyMuted && clamped > 0 {
            toggleMuteInternal()
        }

        writeVolumeInternal(clamped)

        if clamped == 0 && !currentlyMuted {
            toggleMuteInternal()
        }

        publish(volume: clamped, muted: isMutedInternal(), touchDate: true)
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
        ) { _, _ in
            self.fetchCurrentVolume()
        }

        var masterAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(deviceID, &masterAddr) {
            AudioObjectAddPropertyListenerBlock(deviceID, &masterAddr, nil) { _, _ in
                self.fetchCurrentVolume()
            }
        } else {
            for ch in [UInt32(1), UInt32(2)] {
                var chAddr = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyVolumeScalar,
                    mScope: kAudioDevicePropertyScopeOutput,
                    mElement: ch
                )
                if AudioObjectHasProperty(deviceID, &chAddr) {
                    AudioObjectAddPropertyListenerBlock(deviceID, &chAddr, nil) { _, _ in
                        self.fetchCurrentVolume()
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
            AudioObjectAddPropertyListenerBlock(deviceID, &muteAddr, nil) { _, _ in
                self.fetchCurrentVolume()
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

    private var didInitialCameraFetch = false
    private var didInitialMicFetch = false
    private var didInitialRecordingFetch = false
    private var screenRecordPollTimer: Timer?

    override init() {
        super.init()
        setupCameraListener()
        setupMicInUseListener()
        setupScreenRecordListener()
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
}



