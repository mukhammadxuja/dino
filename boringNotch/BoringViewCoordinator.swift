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

enum SneakContentType {
    case brightness
    case volume
    case backlight
    case music
    case mic
    case micActivity
    case battery
    case download
    case antigravity
    case camera
    case screenRecord
    case capsLock
    case location
    case airPods
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

    @Published var currentView: NotchViews = .home
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
                openLastTabByDefault = false
                if ShelfStateViewModel.shared.isEmpty || !Defaults[.openShelfByDefault] {
                    currentView = .home
                }
            }
        }
    }

    @AppStorage("openLastTabByDefault") var openLastTabByDefault: Bool = false {
        didSet {
            if openLastTabByDefault {
                alwaysShowTabs = true
            }
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
        ) { _ in
            Task { @MainActor in
                if Defaults[.hudReplacement] {
                    await MediaKeyInterceptor.shared.start(promptIfNeeded: false)
                }
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
                        self.hudEnableTask = Task { @MainActor in
                            let granted = await XPCHelperClient.shared.ensureAccessibilityAuthorization(promptIfNeeded: true)
                            if Task.isCancelled { return }

                            if granted {
                                await MediaKeyInterceptor.shared.start()
                            } else {
                                Defaults[.hudReplacement] = false
                            }
                        }
                    } else {
                        MediaKeyInterceptor.shared.stop()
                    }
                }
            }

        Task { @MainActor in
            helloAnimationRunning = firstLaunch

            if Defaults[.hudReplacement] {
                let authorized = await XPCHelperClient.shared.isAccessibilityAuthorized()
                if !authorized {
                    Defaults[.hudReplacement] = false
                } else {
                    await MediaKeyInterceptor.shared.start(promptIfNeeded: false)
                }
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

    // MARK: - SneakPeek Sequential Queue (Variant B)
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
        icon: String = ""
    ) {
        if !status {
            Task { @MainActor in
                self.sneakPeekQueue.removeAll { $0.type == type }
                if self.activeSneakPeekType == type {
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
                    }
                }
            }
            return
        }

        if type != .music && type != .mic && type != .micActivity && type != .camera && type != .screenRecord && type != .capsLock && type != .location && type != .airPods {
            if !Defaults[.hudReplacement] {
                return
            }
        }

        Task { @MainActor in
            let isCurrentlyShowing = self.sneakPeek.show
            let isDifferentType = (self.activeSneakPeekType != nil && self.activeSneakPeekType != type)
            let elapsedSinceStart = Date().timeIntervalSince(self.activeSneakPeekStartTime)

            if isCurrentlyShowing && isDifferentType && elapsedSinceStart < 1.2 {
                // Queue the incoming HUD item sequentially so both get full visibility
                let item = SneakPeekQueueItem(type: type, duration: duration, value: value, icon: icon)
                self.sneakPeekQueue.removeAll { $0.type == type }
                self.sneakPeekQueue.append(item)
                return
            }

            self.presentSneakPeek(type: type, duration: duration, value: value, icon: icon)
        }

        if type == .mic {
            currentMicStatus = !value.isZero
        }
    }

    @MainActor
    private func presentSneakPeek(type: SneakContentType, duration: TimeInterval, value: CGFloat, icon: String) {
        activeSneakPeekType = type
        activeSneakPeekStartTime = Date()
        sneakPeekDuration = duration

        withAnimation(.smooth) {
            self.sneakPeek.show = true
            self.sneakPeek.type = type
            self.sneakPeek.value = value
            self.sneakPeek.icon = icon
        }

        // Sync with DinoCoordinator SSOT Priority Stack (P1 Toast)
        if type != .music {
            let hudSlot: DinoSlot = {
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
                default: return .hud(.volume(value: Double(value)))
                }
            }()
            DinoCoordinator.shared.triggerToast(hudSlot, duration: duration)
        }

        scheduleSneakPeekHide(after: duration)
    }

    @MainActor
    private func dismissSneakPeek() {
        withAnimation(.smooth) {
            self.sneakPeek.show = false
        }
        if DinoCoordinator.shared.currentPriority == .p1Toast {
            DinoCoordinator.shared.dismissToast()
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
        Task { @MainActor in
            withAnimation(.smooth) {
                self.expandingView.show = status
                self.expandingView.type = type
                self.expandingView.value = value
                self.expandingView.browser = browser
            }
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
            }
        }
    }
    
    func showEmpty() {
        currentView = .home
    }

    func cancelAllTasks() {
        sneakPeekTask?.cancel()
        sneakPeekTask = nil
        expandingViewTask?.cancel()
        expandingViewTask = nil
        hudEnableTask?.cancel()
        hudEnableTask = nil
    }
}
