//
//  boringNotchApp.swift
//  boringNotchApp
//
//  Created by Harsh Vardhan Goswami on 02/08/24.
//

import AVFoundation
import Combine
import Carbon
import Defaults
import KeyboardShortcuts
import Sparkle
import SwiftUI
import UserNotifications

@main
struct DynamicNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Default(.menubarIcon) var showMenuBarIcon
    @Environment(\.openWindow) var openWindow

    let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

        // Initialize the settings window controller with the updater controller
        SettingsWindowController.shared.setUpdaterController(updaterController)
    }

    var body: some Scene {
        MenuBarExtra(
            "dino",
            systemImage: "sparkle",
            isInserted: .constant(showMenuBarIcon)
        ) {
            Button("Settings") {
                SettingsWindowController.shared.showWindow()
            }
            .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
            CheckForUpdatesView(updater: updaterController.updater)
            Divider()
            Button("Restart Dino") {
                ApplicationRelauncher.restart()
            }
            Button("Quit", role: .destructive) {
                NSApplication.shared.terminate(self)
            }
            .keyboardShortcut(KeyEquivalent("Q"), modifiers: .command)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem?
    var windows: [String: NSWindow] = [:] // UUID -> NSWindow
    var viewModels: [String: BoringViewModel] = [:] // UUID -> BoringViewModel
    var window: NSWindow?
    let vm: BoringViewModel = .init()
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    var quickShareService = QuickShareService.shared
    var whatsNewWindow: NSWindow?
    var closeNotchTask: Task<Void, Never>?

    private var onboardingWindowController: NSWindowController?
    private var screenLockedObserver: Any?
    private var screenUnlockedObserver: Any?
    private var isScreenLocked: Bool = false
    private var windowScreenDidChangeObserver: Any?
    private var dragDetectors: [String: DragDetector] = [:] // UUID -> DragDetector
    private var lockScreenPlayerWindows: [String: NSWindow] = [:] // UUID -> NSWindow
    private var strictModeWindows: [String: NSWindow] = [:] // UUID -> NSWindow
    private var strictModeObservers: Set<AnyCancellable> = []
    private var screenGlowWindows: [String: NSWindow] = [:]
    private var screenGlowObservers: Set<AnyCancellable> = []
    private var glowWindowDismissTask: Task<Void, Never>?
    private var pomodoroNotificationObservers: Set<AnyCancellable> = []
    private var strictModeEscGlobalMonitor: Any?
    private var strictModeEscLocalMonitor: Any?
    private var lastStrictModeEscPressAt: Date?
    private var lastPomodoroShortcutEscPressAt: Date?
    private var didNotifyAlmostBreakForCurrentFocus = false
    private let lockScreenSoundPlayer = AudioPlayer()
    private var lastLockScreenSoundPlayedAt: Date = .distantPast
    private let strictModeEscDoublePressInterval: TimeInterval = 0.65
    private let pomodoroAlmostTimeNotificationID = "pomodoro.almostTime"
    private let pomodoroAlmostTimeCategoryID = "pomodoro.almostTime.category"
    private let pomodoroActionStartNextBreakNow = "pomodoro.action.startNextBreakNow"
    private let pomodoroActionAddOneMinute = "pomodoro.action.addOneMinute"
    private let pomodoroActionAddFiveMinutes = "pomodoro.action.addFiveMinutes"
    private let pomodoroActionSkipBreak = "pomodoro.action.skipBreak"

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        DinoScreenObserver.shared.stopPointerTracking()
        if let observer = screenLockedObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            screenLockedObserver = nil
        }
        if let observer = screenUnlockedObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            screenUnlockedObserver = nil
        }
        MusicManager.shared.destroy()
        cleanupDragDetectors()
        cleanupLockScreenPlayerWindows()
        cleanupStrictModeWindows()
        strictModeObservers.removeAll()
        pomodoroNotificationObservers.removeAll()
        cleanupStrictModeEscMonitors()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [pomodoroAlmostTimeNotificationID])
        cleanupWindows()
        XPCHelperClient.shared.stopMonitoringAccessibilityAuthorization()
    }

    // MARK: - Lock Screen Handling

    @MainActor
    func onScreenLocked(_ notification: Notification) {
        isScreenLocked = true
        playLockScreenSoundIfNeeded(soundName: "lockscreen-sound")
        if !Defaults[.showOnLockScreen] {
            cleanupWindows()
        } else {
            DinoWindowManager.shared.enableSkyLight(on: Array(windows.values))
        }
        presentLockScreenPlayerWindows()
    }

    @MainActor
    func onScreenUnlocked(_ notification: Notification) {
        isScreenLocked = false
        playLockScreenSoundIfNeeded(soundName: "unlockscreen-sound")
        if !Defaults[.showOnLockScreen] {
            adjustWindowPosition(changeAlpha: true)
        } else {
            Task {
                try? await Task.sleep(for: .milliseconds(150))
                await MainActor.run {
                    DinoWindowManager.shared.disableSkyLight(on: Array(self.windows.values))
                }
            }
        }
        cleanupLockScreenPlayerWindows()
    }

    @MainActor
    private func presentLockScreenPlayerWindows() {
        guard Defaults[.lockScreenPlayerEnabled], isScreenLocked else {
            cleanupLockScreenPlayerWindows()
            return
        }

        let screens = DinoScreenObserver.shared.targetLockScreenScreens(preferredScreenUUID: coordinator.preferredScreenUUID)
        let targetUUIDs = Set(screens.compactMap { $0.displayUUID })

        for uuid in lockScreenPlayerWindows.keys where !targetUUIDs.contains(uuid) {
            if let staleWindow = lockScreenPlayerWindows[uuid] {
                staleWindow.close()
                lockScreenPlayerWindows.removeValue(forKey: uuid)
            }
        }

        for screen in screens {
            guard let uuid = screen.displayUUID else { continue }

            if lockScreenPlayerWindows[uuid] == nil {
                lockScreenPlayerWindows[uuid] = DinoWindowManager.shared.createLockScreenPlayerWindow(for: screen, isScreenLocked: isScreenLocked)
            }

            if let window = lockScreenPlayerWindows[uuid] {
                DinoWindowManager.shared.positionLockScreenPlayerWindow(window, on: screen)
                window.orderFrontRegardless()
            }
        }
    }

    @MainActor
    private func cleanupLockScreenPlayerWindows() {
        lockScreenPlayerWindows.values.forEach { window in
            window.close()
        }
        lockScreenPlayerWindows.removeAll()
    }

    // MARK: - Strict Mode & Screen Glow

    @MainActor
    private func cleanupStrictModeWindows() {
        strictModeWindows.values.forEach { window in
            window.close()
        }
        strictModeWindows.removeAll()
    }

    @MainActor
    private func presentStrictModeWindowsIfNeeded() {
        guard PomodoroManager.shared.shouldEnforceStrictMode else {
            cleanupStrictModeWindows()
            return
        }

        let screens = NSScreen.screens
        let targetUUIDs = Set(screens.compactMap { $0.displayUUID })

        for uuid in strictModeWindows.keys where !targetUUIDs.contains(uuid) {
            if let staleWindow = strictModeWindows[uuid] {
                staleWindow.close()
                strictModeWindows.removeValue(forKey: uuid)
            }
        }

        for screen in screens {
            guard let uuid = screen.displayUUID else { continue }

            if strictModeWindows[uuid] == nil {
                strictModeWindows[uuid] = DinoWindowManager.shared.createStrictModeWindow(for: screen)
            }

            if let window = strictModeWindows[uuid] {
                window.setFrame(screen.frame, display: true)
                window.orderFrontRegardless()
            }
        }
    }

    @MainActor
    private func updateScreenGlowWindows() {
        let shouldShow = (BatteryStatusViewModel.shared.isGlowActive && Defaults[.batteryGlowEnabled]) ||
                         (BatteryStatusViewModel.shared.isCustomToastPresented && BatteryStatusViewModel.shared.alertPosition == "Center")
        if shouldShow {
            glowWindowDismissTask?.cancel()
            let screens = NSScreen.screens
            for screen in screens {
                guard let uuid = screen.displayUUID else { continue }
                if screenGlowWindows[uuid] == nil {
                    screenGlowWindows[uuid] = DinoWindowManager.shared.createScreenGlowWindow(for: screen)
                }
                if let window = screenGlowWindows[uuid] {
                    window.setFrame(screen.frame, display: true)
                    window.orderFrontRegardless()
                }
            }
        } else {
            glowWindowDismissTask?.cancel()
            glowWindowDismissTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { return }
                guard !BatteryStatusViewModel.shared.isGlowActive && !(BatteryStatusViewModel.shared.isCustomToastPresented && BatteryStatusViewModel.shared.alertPosition == "Center") else { return }
                for (_, window) in self.screenGlowWindows {
                    window.orderOut(nil)
                }
            }
        }
    }

    // MARK: - Observers Setup

    private func setupScreenGlowObservers() {
        BatteryStatusViewModel.shared.$isGlowActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateScreenGlowWindows()
                }
            }
            .store(in: &screenGlowObservers)

        BatteryStatusViewModel.shared.$isCustomToastPresented
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateScreenGlowWindows()
                }
            }
            .store(in: &screenGlowObservers)

        Defaults.publisher(.batteryGlowEnabled)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                if !change.newValue {
                    Task { @MainActor in
                        self?.updateScreenGlowWindows()
                    }
                }
            }
            .store(in: &screenGlowObservers)
    }

    private func setupStrictModeObservers() {
        let manager = PomodoroManager.shared

        manager.$phase
            .combineLatest(manager.$state, manager.$strictModeBypassedForCurrentBreak)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                Task { @MainActor in
                    self?.presentStrictModeWindowsIfNeeded()
                }
            }
            .store(in: &strictModeObservers)

        Defaults.publisher(.pomodoroEnabled)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.presentStrictModeWindowsIfNeeded()
                }
            }
            .store(in: &strictModeObservers)

        Defaults.publisher(.pomodoroStrictModeEnabled)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.presentStrictModeWindowsIfNeeded()
                }
            }
            .store(in: &strictModeObservers)
    }

    private func setupStrictModeEscMonitors() {
        cleanupStrictModeEscMonitors()

        strictModeEscGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleStrictModeEscape(event)
        }

        strictModeEscLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleStrictModeEscape(event)
            return event
        }
    }

    private func cleanupStrictModeEscMonitors() {
        if let strictModeEscGlobalMonitor {
            NSEvent.removeMonitor(strictModeEscGlobalMonitor)
            self.strictModeEscGlobalMonitor = nil
        }

        if let strictModeEscLocalMonitor {
            NSEvent.removeMonitor(strictModeEscLocalMonitor)
            self.strictModeEscLocalMonitor = nil
        }

        lastStrictModeEscPressAt = nil
    }

    private func handleStrictModeEscape(_ event: NSEvent) {
        guard event.keyCode == 53 else {
            DispatchQueue.main.async { [weak self] in
                self?.lastStrictModeEscPressAt = nil
            }
            return
        }

        Task { @MainActor in
            guard PomodoroManager.shared.shouldEnforceStrictMode else {
                lastStrictModeEscPressAt = nil
                return
            }

            let now = Date()
            if let lastStrictModeEscPressAt,
               now.timeIntervalSince(lastStrictModeEscPressAt) <= strictModeEscDoublePressInterval {
                PomodoroManager.shared.skip()
                self.lastStrictModeEscPressAt = nil
                presentStrictModeWindowsIfNeeded()
                return
            }

            lastStrictModeEscPressAt = now
        }
    }

    // MARK: - Pomodoro Notifications

    private func setupPomodoroNotificationActions() {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self

        let startBreakAction = UNNotificationAction(identifier: pomodoroActionStartNextBreakNow, title: "Start next break now")
        let plusOneAction = UNNotificationAction(identifier: pomodoroActionAddOneMinute, title: "+1 min")
        let plusFiveAction = UNNotificationAction(identifier: pomodoroActionAddFiveMinutes, title: "+5 min")
        let skipBreakAction = UNNotificationAction(identifier: pomodoroActionSkipBreak, title: "Skip break")

        let category = UNNotificationCategory(
            identifier: pomodoroAlmostTimeCategoryID,
            actions: [startBreakAction, plusOneAction, plusFiveAction, skipBreakAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([category])
    }

    private func setupPomodoroAlmostTimeObservers() {
        let manager = PomodoroManager.shared

        manager.$phase
            .combineLatest(manager.$state)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase, state in
                guard let self else { return }

                if phase != .focus || state != .running {
                    self.didNotifyAlmostBreakForCurrentFocus = false
                    self.removePendingPomodoroAlmostTimeNotification()
                }
            }
            .store(in: &pomodoroNotificationObservers)

        manager.$remainingTime
            .combineLatest(manager.$phase, manager.$state)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] remaining, phase, state in
                guard let self else { return }
                guard phase == .focus, state == .running else { return }

                let secondsLeft = Int(ceil(max(0, remaining)))
                if secondsLeft > 60 {
                    self.didNotifyAlmostBreakForCurrentFocus = false
                    return
                }

                guard secondsLeft > 0, !self.didNotifyAlmostBreakForCurrentFocus else { return }
                self.didNotifyAlmostBreakForCurrentFocus = true
                self.postPomodoroAlmostTimeNotification(countdown: manager.formattedRemainingTime)
            }
            .store(in: &pomodoroNotificationObservers)

        Defaults.publisher(.pomodoroNotificationsEnabled)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                guard let self else { return }
                if !change.newValue {
                    self.didNotifyAlmostBreakForCurrentFocus = false
                    self.removePendingPomodoroAlmostTimeNotification()
                }
            }
            .store(in: &pomodoroNotificationObservers)
    }

    private func postPomodoroAlmostTimeNotification(countdown: String) {
        let content = UNMutableNotificationContent()
        content.title = "Almost time - \(countdown)"
        content.body = "Take a break and rest your eyes"
        content.sound = .default
        content.categoryIdentifier = pomodoroAlmostTimeCategoryID

        removePendingPomodoroAlmostTimeNotification()

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.25, repeats: false)
        let request = UNNotificationRequest(identifier: pomodoroAlmostTimeNotificationID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func removePendingPomodoroAlmostTimeNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [pomodoroAlmostTimeNotificationID])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            defer { completionHandler() }

            switch response.actionIdentifier {
            case pomodoroActionStartNextBreakNow:
                PomodoroManager.shared.startNextBreakNow()
            case pomodoroActionAddOneMinute:
                PomodoroManager.shared.extendCurrentFocus(byMinutes: 1)
                didNotifyAlmostBreakForCurrentFocus = false
            case pomodoroActionAddFiveMinutes:
                PomodoroManager.shared.extendCurrentFocus(byMinutes: 5)
                didNotifyAlmostBreakForCurrentFocus = false
            case pomodoroActionSkipBreak:
                PomodoroManager.shared.skip()
            default:
                break
            }

            removePendingPomodoroAlmostTimeNotification()
            presentStrictModeWindowsIfNeeded()
        }
    }

    // MARK: - Window Management

    private func cleanupWindows(shouldInvert: Bool = false) {
        let shouldCleanupMulti = shouldInvert ? !Defaults[.showOnAllDisplays] : Defaults[.showOnAllDisplays]

        if shouldCleanupMulti {
            windows.values.forEach { window in
                window.close()
                NotchSpaceManager.shared.notchSpace.windows.remove(window)
            }
            windows.removeAll()
            viewModels.removeAll()
        } else if let window = window {
            window.close()
            NotchSpaceManager.shared.notchSpace.windows.remove(window)
            if let obs = windowScreenDidChangeObserver {
                NotificationCenter.default.removeObserver(obs)
                windowScreenDidChangeObserver = nil
            }
            self.window = nil
        }
    }

    // MARK: - Drag Detectors

    private func cleanupDragDetectors() {
        dragDetectors.values.forEach { detector in
            detector.stopMonitoring()
        }
        dragDetectors.removeAll()
    }

    private func setupDragDetectors() {
        cleanupDragDetectors()

        guard Defaults[.expandedDragDetection] else { return }

        if Defaults[.showOnAllDisplays] {
            for screen in NSScreen.screens {
                setupDragDetectorForScreen(screen)
            }
        } else {
            let preferredScreen: NSScreen? = window?.screen
                ?? NSScreen.screen(withUUID: coordinator.selectedScreenUUID)
                ?? NSScreen.main

            if let screen = preferredScreen {
                setupDragDetectorForScreen(screen)
            }
        }
    }

    private func setupDragDetectorForScreen(_ screen: NSScreen) {
        guard let uuid = screen.displayUUID else { return }

        let screenFrame = screen.frame
        let notchHeight = openNotchSize.height
        let notchWidth = openNotchSize.width

        let notchRegion = CGRect(
            x: screenFrame.midX - notchWidth / 2,
            y: screenFrame.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight
        )

        let detector = DragDetector(notchRegion: notchRegion)
        detector.onDragEntersNotchRegion = { [weak self] in
            Task { @MainActor in
                self?.handleDragEntersNotchRegion(onScreen: screen)
            }
        }

        dragDetectors[uuid] = detector
        detector.startMonitoring()
    }

    private func handleDragEntersNotchRegion(onScreen screen: NSScreen) {
        guard let uuid = screen.displayUUID else { return }

        if Defaults[.showOnAllDisplays], let viewModel = viewModels[uuid] {
            viewModel.open()
            coordinator.currentView = .shelf
        } else if !Defaults[.showOnAllDisplays], let windowScreen = window?.screen, screen == windowScreen {
            vm.open()
            coordinator.currentView = .shelf
        }
    }

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(forName: Notification.Name.selectedScreenChanged, object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor in
                self?.adjustWindowPosition(changeAlpha: true)
                self?.setupDragDetectors()
            }
        }

        NotificationCenter.default.addObserver(forName: Notification.Name.notchHeightChanged, object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor in
                self?.adjustWindowPosition()
                self?.setupDragDetectors()
            }
        }

        NotificationCenter.default.addObserver(forName: Notification.Name.automaticallySwitchDisplayChanged, object: nil, queue: nil) { [weak self] _ in
            guard let self = self, let window = self.window else { return }
            Task { @MainActor in
                window.alphaValue = self.coordinator.selectedScreenUUID == self.coordinator.preferredScreenUUID ? 1 : 0
            }
        }

        NotificationCenter.default.addObserver(forName: Notification.Name.showOnAllDisplaysChanged, object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.cleanupWindows(shouldInvert: true)
                self.adjustWindowPosition(changeAlpha: true)
                self.setupDragDetectors()
            }
        }

        NotificationCenter.default.addObserver(forName: Notification.Name.displaySettingsChanged, object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.cleanupWindows(shouldInvert: true)
                self.adjustWindowPosition(changeAlpha: true)
                self.setupDragDetectors()
                self.setupPointerTracking()
            }
        }

        NotificationCenter.default.addObserver(forName: Notification.Name.expandedDragDetectionChanged, object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor in
                self?.setupDragDetectors()
            }
        }

        screenLockedObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(rawValue: "com.apple.screenIsLocked"),
            object: nil, queue: .main) { [weak self] notification in
                Task { @MainActor in
                    self?.onScreenLocked(notification)
                }
        }

        screenUnlockedObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(rawValue: "com.apple.screenIsUnlocked"),
            object: nil, queue: .main) { [weak self] notification in
                Task { @MainActor in
                    self?.onScreenUnlocked(notification)
                }
        }

        KeyboardShortcuts.onKeyDown(for: .toggleSneakPeek) { [weak self] in
            guard let self = self else { return }
            if Defaults[.sneakPeekStyles] == .inline {
                let newStatus = !self.coordinator.expandingView.show
                self.coordinator.toggleExpandingView(status: newStatus, type: .music)
            } else {
                self.coordinator.toggleSneakPeek(status: !self.coordinator.sneakPeek.show, type: .music, duration: 3.0)
            }
        }

        KeyboardShortcuts.onKeyDown(for: .toggleNotchOpen) { [weak self] in
            Task { [weak self] in
                guard let self = self else { return }
                let mouseLocation = NSEvent.mouseLocation
                var viewModel = self.vm

                if Defaults[.showOnAllDisplays] {
                    for screen in NSScreen.screens {
                        if screen.frame.contains(mouseLocation) {
                            if let uuid = screen.displayUUID, let screenViewModel = self.viewModels[uuid] {
                                viewModel = screenViewModel
                                break
                            }
                        }
                    }
                }

                self.closeNotchTask?.cancel()
                self.closeNotchTask = nil

                switch viewModel.notchState {
                case .closed:
                    await MainActor.run { viewModel.open() }
                    let task = Task { [weak viewModel] in
                        do {
                            try await Task.sleep(for: .seconds(3))
                            await MainActor.run { viewModel?.close() }
                        } catch { }
                    }
                    self.closeNotchTask = task
                case .open:
                    await MainActor.run { viewModel.close() }
                }
            }
        }

        KeyboardShortcuts.onKeyDown(for: .pomodoroEmergencyExit) { [weak self] in
            Task { @MainActor in
                guard PomodoroManager.shared.shouldEnforceStrictMode else { return }

                if let shortcut = KeyboardShortcuts.Name.pomodoroEmergencyExit.shortcut,
                   shortcut.carbonKeyCode == kVK_Escape,
                   shortcut.modifiers.isEmpty {
                    let now = Date()
                    if let last = self?.lastPomodoroShortcutEscPressAt,
                       now.timeIntervalSince(last) <= self?.strictModeEscDoublePressInterval ?? 0.65 {
                        PomodoroManager.shared.skip()
                        self?.lastPomodoroShortcutEscPressAt = nil
                        self?.presentStrictModeWindowsIfNeeded()
                    } else {
                        self?.lastPomodoroShortcutEscPressAt = now
                    }
                    return
                }

                PomodoroManager.shared.skip()
                self?.presentStrictModeWindowsIfNeeded()
            }
        }

        DinoHotKeyManager.shared.registerAllShortcuts()

        setupStrictModeObservers()
        setupScreenGlowObservers()
        setupStrictModeEscMonitors()
        setupPomodoroNotificationActions()
        if Defaults[.pomodoroNotificationsEnabled] {
            setupPomodoroAlmostTimeObservers()
        }

        adjustWindowPosition(changeAlpha: true)
        setupDragDetectors()

        if coordinator.firstLaunch {
            DispatchQueue.main.async { self.showOnboardingWindow() }
            playWelcomeSound()
        } else if MusicManager.shared.isNowPlayingDeprecated && Defaults[.mediaController] == .nowPlaying {
            DispatchQueue.main.async { self.showOnboardingWindow(step: .musicPermission) }
        }

        Task { @MainActor in
            self.presentStrictModeWindowsIfNeeded()
        }
    }

    func playWelcomeSound() {
        let audioPlayer = AudioPlayer()
        audioPlayer.play(fileName: "boring", fileExtension: "m4a")
    }

    private func playLockScreenSoundIfNeeded(soundName: String) {
        guard Defaults[.lockScreenSoundEnabled] else { return }
        let now = Date()
        guard now.timeIntervalSince(lastLockScreenSoundPlayedAt) > 0.8 else { return }
        lastLockScreenSoundPlayedAt = now

        let vol = Defaults[.lockScreenSoundVolume]
        let extensions = ["m4a", "mp3", "wav", "aiff"]
        for ext in extensions {
            if lockScreenSoundPlayer.playIfAvailable(fileName: soundName, fileExtension: ext, volume: vol) {
                break
            }
        }
    }

    func deviceHasNotch() -> Bool {
        DinoScreenObserver.shared.deviceHasNotch()
    }

    @objc func screenConfigurationDidChange() {
        if DinoScreenObserver.shared.hasScreenConfigurationChanged() {
            DispatchQueue.main.async { [weak self] in
                self?.cleanupWindows()
                self?.adjustWindowPosition()
                self?.setupDragDetectors()
                if self?.isScreenLocked == true {
                    self?.presentLockScreenPlayerWindows()
                }
                Task { @MainActor in
                    self?.presentStrictModeWindowsIfNeeded()
                }
            }
        }
    }

    @objc func adjustWindowPosition(changeAlpha: Bool = false) {
        let targetScreens = DinoScreenObserver.shared.targetScreens()
        let targetUUIDs = Set(targetScreens.compactMap { $0.displayUUID })

        // Remove windows for screens that are no longer targeted
        for uuid in windows.keys where !targetUUIDs.contains(uuid) {
            if let window = windows[uuid] {
                window.close()
                NotchSpaceManager.shared.notchSpace.windows.remove(window)
                windows.removeValue(forKey: uuid)
                viewModels.removeValue(forKey: uuid)
            }
        }

        // Create or update windows for targeted screens
        for screen in targetScreens {
            guard let uuid = screen.displayUUID else { continue }

            if windows[uuid] == nil {
                let viewModel = BoringViewModel(screenUUID: uuid)
                let res = DinoWindowManager.shared.createBoringNotchWindow(
                    for: screen,
                    with: viewModel,
                    isScreenLocked: isScreenLocked,
                    onScreenChange: { [weak self] in
                        Task { @MainActor in
                            self?.setupDragDetectors()
                        }
                    }
                )
                self.windowScreenDidChangeObserver = res.observer
                windows[uuid] = res.window
                viewModels[uuid] = viewModel
            }

            if let window = windows[uuid], let viewModel = viewModels[uuid] {
                viewModel.screenUUID = uuid
                viewModel.notchSize = getClosedNotchSize(screenUUID: uuid)
                DinoWindowManager.shared.positionWindow(window, on: screen, changeAlpha: changeAlpha)

                if viewModel.notchState == .closed {
                    viewModel.close()
                }
            }
        }
    }

    func setupPointerTracking() {
        DinoScreenObserver.shared.setupPointerTracking { [weak self] in
            self?.adjustWindowPosition()
        }
    }

    @objc func togglePopover(_ sender: Any?) {
        if window?.isVisible == true {
            window?.orderOut(nil)
        } else {
            window?.orderFrontRegardless()
        }
    }

    @objc func showMenu() {
        statusItem?.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc func quitAction() {
        NSApplication.shared.terminate(self)
    }

    private func showOnboardingWindow(step: OnboardingStep = .welcome) {
        if onboardingWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
                styleMask: [.titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Onboarding"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.contentView = NSHostingView(
                rootView: OnboardingView(
                    step: step,
                    onFinish: {
                        window.orderOut(nil)
                        window.close()
                        NSApp.deactivate()
                    },
                    onOpenSettings: {
                        window.close()
                        SettingsWindowController.shared.showWindow()
                    }
                ))
            window.isRestorable = false
            window.identifier = NSUserInterfaceItemIdentifier("OnboardingWindow")
            onboardingWindowController = NSWindowController(window: window)
        }

        NSApp.activate(ignoringOtherApps: true)
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        onboardingWindowController?.window?.orderFrontRegardless()
    }
}

extension Notification.Name {
    static let selectedScreenChanged = Notification.Name("SelectedScreenChanged")
    static let notchHeightChanged = Notification.Name("NotchHeightChanged")
    static let showOnAllDisplaysChanged = Notification.Name("showOnAllDisplaysChanged")
    static let automaticallySwitchDisplayChanged = Notification.Name("automaticallySwitchDisplayChanged")
    static let expandedDragDetectionChanged = Notification.Name("expandedDragDetectionChanged")
}

extension CGRect: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(origin.x)
        hasher.combine(origin.y)
        hasher.combine(size.width)
        hasher.combine(size.height)
    }

    public static func == (lhs: CGRect, rhs: CGRect) -> Bool {
        return lhs.origin == rhs.origin && lhs.size == rhs.size
    }
}
