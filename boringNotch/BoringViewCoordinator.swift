//
//  BoringViewCoordinator.swift
//  boringNotch
//
//  Created by Alexander on 2024-11-20.
//

import AppKit
import Combine
import Defaults
import SwiftUI

enum HUDAnimations {
    static let presentation = Animation.interactiveSpring(response: 0.34, dampingFraction: 0.62)
}

enum SneakContentType {
    case brightness
    case volume
    case backlight
    case music
    case mic
    case micActivity
    case battery
    case charging
    case unplugged
    case download
    case antigravity
    case camera
    case screenRecord
    case capsLock
    case location
    case airPods

    var isInteractiveHUD: Bool {
        switch self {
        case .volume, .brightness, .backlight, .mic, .capsLock:
            return true
        default:
            return false
        }
    }
}

struct sneakPeek {
    var show: Bool = false
    var type: SneakContentType = .music
    var value: CGFloat = 0
    var icon: String = ""
}

struct SharedSneakPeek: Codable {
    var show: Bool
    var type: String
    var value: String
    var icon: String
}

enum BrowserType {
    case chromium
    case safari
}

struct ExpandedItem {
    var show: Bool = false
    var type: SneakContentType = .battery
    var value: CGFloat = 0
    var browser: BrowserType = .chromium
}

@MainActor
class BoringViewCoordinator: ObservableObject {
    static let shared = BoringViewCoordinator()

    @Published private(set) var currentView: NotchViews = .home
    @Published var helloAnimationRunning: Bool = false
    private var sneakPeekDispatch: DispatchWorkItem?
    private var expandingViewDispatch: DispatchWorkItem?
    private var hudEnableTask: Task<Void, Never>?

    @AppStorage("firstLaunch") var firstLaunch: Bool = true
    @AppStorage("showWhatsNew") var showWhatsNew: Bool = true
    @AppStorage("musicLiveActivityEnabled") var musicLiveActivityEnabled: Bool = true
    @AppStorage("currentMicStatus") var currentMicStatus: Bool = true

    @AppStorage("alwaysShowTabs") var alwaysShowTabs: Bool = true {
        didSet {
            if !alwaysShowTabs {
                if ShelfStateViewModel.shared.isEmpty || !Defaults[.openShelfByDefault] {
                    DinoCoordinator.shared.selectView(.home)
                }
            }
        }
    }

    @AppStorage("openLastTabByDefault") var openLastTabByDefault: Bool = true

    @AppStorage("lastExpandedFeature") private var lastExpandedFeature = ""

    var lastExpandedSlot: DinoSlot? {
        switch lastExpandedFeature {
        case "music": return .music
        case "pomodoro": return .pomodoro
        case "shelf": return .shelf
        case "weather": return .weather
        case "calendar": return ReleaseFeatures.calendar ? .calendar : nil
        default: return nil
        }
    }

    func rememberExpandedSlot(_ slot: DinoSlot) {
        let value: String
        switch slot {
        case .music: value = "music"
        case .pomodoro: value = "pomodoro"
        case .shelf: value = "shelf"
        case .weather: value = "weather"
        case .calendar: value = "calendar"
        default: return
        }
        if lastExpandedFeature != value {
            lastExpandedFeature = value
        }
    }
    
    @Default(.hudReplacement) var hudReplacement: Bool
    
    // Legacy storage for migration
    @AppStorage("preferred_screen_name") private var legacyPreferredScreenName: String?
    
    // New UUID-based storage
    @AppStorage("preferred_screen_uuid") var preferredScreenUUID: String? {
        didSet {
            if let uuid = preferredScreenUUID {
                selectedScreenUUID = uuid
            }
            NotificationCenter.default.post(name: Notification.Name.selectedScreenChanged, object: nil)
        }
    }

    @Published var selectedScreenUUID: String = NSScreen.main?.displayUUID ?? ""

    @Published var optionKeyPressed: Bool = true
    private var accessibilityObserver: Any?
    private var appDidBecomeActiveObserver: Any?
    private var hudReplacementCancellable: AnyCancellable?

    private init() {
        // Perform migration from name-based to UUID-based storage
        if preferredScreenUUID == nil, let legacyName = legacyPreferredScreenName {
            // Try to find screen by name and migrate to UUID
            if let screen = NSScreen.screens.first(where: { $0.localizedName == legacyName }),
               let uuid = screen.displayUUID {
                preferredScreenUUID = uuid
                NSLog("✅ Migrated display preference from name '\(legacyName)' to UUID '\(uuid)'")
            } else {
                // Fallback to main screen if legacy screen not found
                preferredScreenUUID = NSScreen.main?.displayUUID
                NSLog("⚠️ Could not find display named '\(legacyName)', falling back to main screen")
            }
            // Clear legacy value after migration
            legacyPreferredScreenName = nil
        } else if preferredScreenUUID == nil {
            // No legacy value, use main screen
            preferredScreenUUID = NSScreen.main?.displayUUID
        }
        
        selectedScreenUUID = preferredScreenUUID ?? NSScreen.main?.displayUUID ?? ""
        // Observe changes to accessibility authorization and react accordingly
        accessibilityObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.accessibilityAuthorizationChanged,
            object: nil,
            queue: .main
        ) { notification in
            guard let granted = notification.userInfo?["granted"] as? Bool else { return }
            Task { @MainActor in
                guard Defaults[.hudReplacement] else { return }
                if granted {
                    await MediaKeyInterceptor.shared.start()
                } else {
                    MediaKeyInterceptor.shared.stopForMissingPermission()
                }
            }
        }

        appDidBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                guard Defaults[.hudReplacement] else { return }
                await MediaKeyInterceptor.shared.start()
            }
        }

        // Observe changes to hudReplacement
        hudReplacementCancellable = Defaults.publisher(.hudReplacement)
            .sink { [weak self] change in
                Task { @MainActor in
                    guard let self = self else { return }

                    self.hudEnableTask?.cancel()
                    self.hudEnableTask = nil

                    if change.newValue {
                        XPCHelperClient.shared.startMonitoringAccessibilityAuthorization()
                        self.hudEnableTask = Task { @MainActor in
                            await MediaKeyInterceptor.shared.start()
                        }
                    } else {
                        XPCHelperClient.shared.stopMonitoringAccessibilityAuthorization()
                        MediaKeyInterceptor.shared.stop()
                    }
                }
            }

        Task { @MainActor in
            helloAnimationRunning = firstLaunch
            if Defaults[.hudReplacement] {
                XPCHelperClient.shared.startMonitoringAccessibilityAuthorization()
                await MediaKeyInterceptor.shared.start()
            }
        }
    }
    
    @objc func sneakPeekEvent(_ notification: Notification) {
        let decoder = JSONDecoder()
        if let decodedData = try? decoder.decode(
            SharedSneakPeek.self, from: notification.userInfo?.first?.value as! Data)
        {
            let contentType =
                decodedData.type == "brightness"
                ? SneakContentType.brightness
                : decodedData.type == "volume"
                    ? SneakContentType.volume
                    : decodedData.type == "backlight"
                        ? SneakContentType.backlight
                        : decodedData.type == "mic"
                            ? SneakContentType.mic : SneakContentType.brightness

            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.numberStyle = .decimal
            let value = CGFloat((formatter.number(from: decodedData.value) ?? 0.0).floatValue)
            let icon = decodedData.icon

            print("Decoded: \(decodedData), Parsed value: \(value)")

            toggleSneakPeek(status: decodedData.show, type: contentType, value: value, icon: icon)

        } else {
            print("Failed to decode JSON data")
        }
    }

    // MARK: - SneakPeek presentation and notification queue
    struct SneakPeekQueueItem: Equatable {
        let type: SneakContentType
        let duration: TimeInterval
        let value: CGFloat
        let icon: String
    }

    private var sneakPeekQueue: [SneakPeekQueueItem] = []
    private var activeSneakPeekType: SneakContentType?
    private var activeSneakPeekStartTime: Date = .distantPast

    func toggleSneakPeek(
        status: Bool, type: SneakContentType, duration: TimeInterval = 1.5, value: CGFloat = 0,
        icon: String = "", force: Bool = false
    ) {
        if !status {
            sneakPeekQueue.removeAll { $0.type == type }
            if activeSneakPeekType == type {
                if !sneakPeekQueue.isEmpty {
                    let nextItem = sneakPeekQueue.removeFirst()
                    presentSneakPeek(
                        type: nextItem.type,
                        duration: nextItem.duration,
                        value: nextItem.value,
                        icon: nextItem.icon
                    )
                } else {
                    activeSneakPeekType = nil
                    dismissSneakPeek()
                }
            }
            return
        }

        if type != .music && type != .mic && type != .micActivity && type != .camera && type != .screenRecord && type != .capsLock && type != .location && type != .airPods {
            if !Defaults[.hudReplacement] && !force {
                return
            }
        }

        guard !force else {
            presentSneakPeek(type: type, duration: duration, value: value, icon: icon)
            return
        }

        switch type {
        case .volume:
            guard Defaults[.hudVolumeEnabled] else { return }
        case .brightness:
            guard Defaults[.hudBrightnessEnabled] else { return }
        case .backlight:
            guard Defaults[.hudBacklightEnabled] else { return }
        case .airPods:
            guard Defaults[.hudAirPodsEnabled] else { return }
        case .capsLock:
            guard Defaults[.hudCapsLockEnabled] else { return }
        case .location:
            guard Defaults[.hudLocationEnabled] else { return }
        case .camera:
            guard Defaults[.hudCameraEnabled] else { return }
        case .mic, .micActivity:
            guard Defaults[.hudMicEnabled] else { return }
        case .screenRecord:
            guard Defaults[.hudScreenRecordEnabled] else { return }
        case .charging:
            guard Defaults[.hudChargingEnabled] else { return }
        case .unplugged:
            guard Defaults[.hudUnpluggedEnabled] else { return }
        default:
            break
        }

        let isCurrentlyShowing = sneakPeek.show
        let isDifferentType = (activeSneakPeekType != nil && activeSneakPeekType != type)
        let elapsedSinceStart = Date().timeIntervalSince(activeSneakPeekStartTime)

        if type == .music && isCurrentlyShowing && activeSneakPeekType == .music {
            activeSneakPeekStartTime = Date()
            sneakPeekDuration = duration
            scheduleSneakPeekHide(after: duration)
            return
        }

        if type.isInteractiveHUD {
            // A keypress takes effect now; never replay an older control value later.
            sneakPeekQueue.removeAll { $0.type.isInteractiveHUD }
        } else if isCurrentlyShowing && isDifferentType && elapsedSinceStart < 1.2 {
            let item = SneakPeekQueueItem(type: type, duration: duration, value: value, icon: icon)
            sneakPeekQueue.removeAll { $0.type == type }
            sneakPeekQueue.append(item)
            return
        }

        presentSneakPeek(type: type, duration: duration, value: value, icon: icon)

        if type == .mic {
            currentMicStatus = !value.isZero
        }
    }

    @MainActor
    private func presentSneakPeek(type: SneakContentType, duration: TimeInterval, value: CGFloat, icon: String) {
        let isUpdatingVisibleHUD = sneakPeek.show && activeSneakPeekType == type
        activeSneakPeekType = type
        activeSneakPeekStartTime = Date()
        sneakPeekDuration = duration

        let hudSlot: DinoSlot? = {
            guard type != .music else { return nil }
            switch type {
            case .volume: return .hud(.volume(value: Double(value)))
            case .brightness: return .hud(.brightness(value: Double(value)))
            case .backlight: return .hud(.backlight(value: Double(value)))
            case .mic: return .hud(.micMute(isMuted: value.isZero))
            case .micActivity: return .hud(.micActivity(isActive: value > 0))
            case .camera: return .hud(.camera(isActive: value > 0))
            case .screenRecord: return .hud(.screenRecord(isRecording: value > 0))
            case .capsLock: return .hud(.capsLock(isOn: value > 0))
            case .location: return .hud(.location(isInUse: value > 0))
            case .airPods: return .hud(.airPods(name: icon.isEmpty ? "AirPods Pro" : icon, battery: Int(value)))
            case .charging: return .hud(.charging)
            case .unplugged: return .hud(.unplugged)
            default: return .hud(.volume(value: Double(value)))
            }
        }()

        // Repeated keys update the visible value without restarting the opening spring.
        let animation: Animation? = isUpdatingVisibleHUD ? nil
            : (type == .music ? .interactiveSpring(response: 0.42, dampingFraction: 0.88) : HUDAnimations.presentation)
        withAnimation(animation) {
            var presentation = self.sneakPeek
            presentation.show = true
            presentation.type = type
            presentation.value = value
            presentation.icon = icon
            self.sneakPeek = presentation

            if let slot = hudSlot {
                DinoCoordinator.shared.triggerToast(slot, duration: duration, animated: false)
            }
        }

        scheduleSneakPeekHide(after: duration)
    }

    @MainActor
    private func dismissSneakPeek() {
        withAnimation(sneakPeek.type == .music
                      ? .interactiveSpring(response: 0.42, dampingFraction: 0.88)
                      : HUDAnimations.presentation) {
            self.sneakPeek.show = false
            if DinoCoordinator.shared.currentPriority == .p1Toast {
                DinoCoordinator.shared.dismissToast(animated: false)
            }
        }
    }

    private var sneakPeekDuration: TimeInterval = 1.5
    private var sneakPeekTask: Task<Void, Never>?

    // Helper function to manage sneakPeek timer using Swift Concurrency
    private func scheduleSneakPeekHide(after duration: TimeInterval) {
        sneakPeekTask?.cancel()

        sneakPeekTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self = self, !Task.isCancelled else { return }
            await MainActor.run {
                if !self.sneakPeekQueue.isEmpty {
                    let nextItem = self.sneakPeekQueue.removeFirst()
                    self.presentSneakPeek(
                        type: nextItem.type,
                        duration: nextItem.duration,
                        value: nextItem.value,
                        icon: nextItem.icon
                    )
                } else {
                    self.activeSneakPeekType = nil
                    self.dismissSneakPeek()
                    self.sneakPeekDuration = 1.5
                }
            }
        }
    }

    @Published var sneakPeek: sneakPeek = .init() {
        didSet {
            if !sneakPeek.show {
                sneakPeekTask?.cancel()
            }
        }
    }

    func toggleExpandingView(
        status: Bool,
        type: SneakContentType,
        value: CGFloat = 0,
        browser: BrowserType = .chromium
    ) {
        // Commit once on the main actor; a queued show must not outlive close/cleanup.
        guard status || expandingView.type == type else { return }
        let isPowerHUD = type == .charging || type == .unplugged || type == .battery
        withAnimation(isPowerHUD ? HUDAnimations.presentation
                      : .interactiveSpring(response: 0.42, dampingFraction: 0.88, blendDuration: 0)) {
            expandingView = ExpandedItem(show: status, type: type, value: value, browser: browser)
        }
    }

    private var expandingViewTask: Task<Void, Never>?

    @Published var expandingView: ExpandedItem = .init() {
        didSet {
            if expandingView.show {
                expandingViewTask?.cancel()
                let duration: TimeInterval = (expandingView.type == .download ? 2 : 3)
                let currentType = expandingView.type
                expandingViewTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(duration))
                    guard let self = self, !Task.isCancelled else { return }
                    self.toggleExpandingView(status: false, type: currentType)
                }
            } else {
                expandingViewTask?.cancel()
                expandingViewTask = nil
            }
        }
    }
    
    /// Projection of the selected slot; callers select through DinoCoordinator.
    func syncCurrentView(for slot: DinoSlot) {
        let view = slot.asNotchView
        guard currentView != view else { return }
        currentView = view
    }

    func showEmpty() {
        DinoCoordinator.shared.selectView(.home)
    }

    func cancelAllTasks() {
        sneakPeekTask?.cancel()
        sneakPeekTask = nil
        expandingViewTask?.cancel()
        expandingViewTask = nil
        // Clearing only the timer leaves a visible inline peek with no way to expire.
        if expandingView.show { expandingView.show = false }
        hudEnableTask?.cancel()
        hudEnableTask = nil
    }
}
