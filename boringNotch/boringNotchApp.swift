//
//  boringNotchApp.swift
//  boringNotchApp
//
//  Created by Harsh Vardhan  Goswami  on 02/08/24.
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
    var timer: Timer?
    var closeNotchTask: Task<Void, Never>?
    private var previousScreens: [NSScreen]?
    private var onboardingWindowController: NSWindowController?
    private var screenLockedObserver: Any?
    private var screenUnlockedObserver: Any?
    private var isScreenLocked: Bool = false
    private var windowScreenDidChangeObserver: Any?
    private var dragDetectors: [String: DragDetector] = [:] // UUID -> DragDetector
    private var lockScreenPlayerWindows: [String: NSWindow] = [:] // UUID -> NSWindow
    private var strictModeWindows: [String: NSWindow] = [:] // UUID -> NSWindow
    private var strictModeObservers: Set<AnyCancellable> = []
    private var pomodoroNotificationObservers: Set<AnyCancellable> = []
    private var strictModeEscGlobalMonitor: Any?
    private var strictModeEscLocalMonitor: Any?
    private var lastStrictModeEscPressAt: Date?
    private var lastPomodoroShortcutEscPressAt: Date?
    private var didNotifyAlmostBreakForCurrentFocus = false
    private let lockScreenPlayerSize = NSSize(width: 355, height: 176)
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

    @MainActor
    func onScreenLocked(_ notification: Notification) {
        isScreenLocked = true
        playLockScreenSoundIfNeeded(soundName: "lockscreen-sound")
        if !Defaults[.showOnLockScreen] {
            cleanupWindows()
        } else {
            enableSkyLightOnAllWindows()
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
            disableSkyLightOnAllWindows()
        }
        cleanupLockScreenPlayerWindows()
    }
    
    @MainActor
    private func enableSkyLightOnAllWindows() {
        if Defaults[.showOnAllDisplays] {
            windows.values.forEach { window in
                if let skyWindow = window as? BoringNotchSkyLightWindow {
                    skyWindow.enableSkyLight()
                }
            }
        } else {
            if let skyWindow = window as? BoringNotchSkyLightWindow {
                skyWindow.enableSkyLight()
            }
        }
    }
    
    @MainActor
    private func disableSkyLightOnAllWindows() {
        // Delay disabling SkyLight to avoid flicker during unlock transition
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            await MainActor.run {
                if Defaults[.showOnAllDisplays] {
                    self.windows.values.forEach { window in
                        if let skyWindow = window as? BoringNotchSkyLightWindow {
                            skyWindow.disableSkyLight()
                        }
                    }
                } else {
                    if let skyWindow = self.window as? BoringNotchSkyLightWindow {
                        skyWindow.disableSkyLight()
                    }
                }
            }
        }
    }

    @MainActor
    private func targetLockScreenScreens() -> [NSScreen] {
        if Defaults[.showOnAllDisplays] {
            return NSScreen.screens
        }

        if let preferredScreen = NSScreen.screen(withUUID: coordinator.preferredScreenUUID ?? "") {
            return [preferredScreen]
        }

        if let main = NSScreen.main {
            return [main]
        }

        return NSScreen.screens.prefix(1).map { $0 }
    }

    @MainActor
    private func createLockScreenPlayerWindow(for screen: NSScreen) -> NSWindow {
        let rect = NSRect(origin: .zero, size: lockScreenPlayerSize)
        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow]
        let window = BoringNotchSkyLightWindow(contentRect: rect, styleMask: styleMask, backing: .buffered, defer: false)

        window.contentView = NSHostingView(rootView: LockScreenPasscodePlayerView())
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false

        if isScreenLocked {
            window.enableSkyLight()
        } else {
            window.disableSkyLight()
        }

        positionLockScreenPlayerWindow(window, on: screen)
        return window
    }

    @MainActor
    private func positionLockScreenPlayerWindow(_ window: NSWindow, on screen: NSScreen) {
        let screenFrame = screen.frame
        let x = screenFrame.origin.x + (screenFrame.width - lockScreenPlayerSize.width) / 2
        let y = screenFrame.origin.y + 130
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @MainActor
    private func presentLockScreenPlayerWindows() {
        guard Defaults[.lockScreenPlayerEnabled], isScreenLocked else {
            cleanupLockScreenPlayerWindows()
            return
        }

        let screens = targetLockScreenScreens()
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
                lockScreenPlayerWindows[uuid] = createLockScreenPlayerWindow(for: screen)
            }

            if let window = lockScreenPlayerWindows[uuid] {
                positionLockScreenPlayerWindow(window, on: screen)
                window.orderFrontRegardless()

                if let skyWindow = window as? BoringNotchSkyLightWindow {
                    skyWindow.enableSkyLight()
                }
            }
        }
    }

    @MainActor
    private func cleanupLockScreenPlayerWindows() {
        lockScreenPlayerWindows.values.forEach { window in
            if let skyWindow = window as? BoringNotchSkyLightWindow {
                skyWindow.disableSkyLight()
            }
            window.close()
        }
        lockScreenPlayerWindows.removeAll()
    }

    @MainActor
    private func createStrictModeWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.contentView = NSHostingView(rootView: StrictModeOverlayView())
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false

        return window
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
                strictModeWindows[uuid] = createStrictModeWindow(for: screen)
            }

            if let window = strictModeWindows[uuid] {
                window.setFrame(screen.frame, display: true)
                window.orderFrontRegardless()
            }
        }
    }

    @MainActor
    private func cleanupStrictModeWindows() {
        strictModeWindows.values.forEach { window in
            window.close()
        }
        strictModeWindows.removeAll()
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

    private func setupPomodoroNotificationActions() {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self

        let startBreakAction = UNNotificationAction(
            identifier: pomodoroActionStartNextBreakNow,
            title: "Start next break now"
        )
        let plusOneAction = UNNotificationAction(
            identifier: pomodoroActionAddOneMinute,
            title: "+1 min"
        )
        let plusFiveAction = UNNotificationAction(
            identifier: pomodoroActionAddFiveMinutes,
            title: "+5 min"
        )
        let skipBreakAction = UNNotificationAction(
            identifier: pomodoroActionSkipBreak,
            title: "Skip break"
        )

        let category = UNNotificationCategory(
            identifier: pomodoroAlmostTimeCategoryID,
            actions: [startBreakAction, plusOneAction, plusFiveAction, skipBreakAction],
            intentIdentifiers: []
        )

        notificationCenter.setNotificationCategories([category])
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func setupPomodoroAlmostTimeObservers() {
        let manager = PomodoroManager.shared

        pomodoroNotificationObservers.removeAll()

        manager.$phase
            .combineLatest(manager.$state)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase, state in
                guard let self else { return }

                guard Defaults[.pomodoroNotificationsEnabled] else {
                    didNotifyAlmostBreakForCurrentFocus = false
                    removePendingPomodoroAlmostTimeNotification()
                    return
                }

                if phase != .focus || state != .running {
                    didNotifyAlmostBreakForCurrentFocus = false
                    removePendingPomodoroAlmostTimeNotification()
                }
            }
            .store(in: &pomodoroNotificationObservers)

        manager.$remainingTime
            .combineLatest(manager.$phase, manager.$state)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] remaining, phase, state in
                guard let self else { return }
                guard Defaults[.pomodoroNotificationsEnabled] else { return }
                guard phase == .focus, state == .running else { return }

                let secondsLeft = Int(ceil(max(0, remaining)))
                if secondsLeft > 60 {
                    didNotifyAlmostBreakForCurrentFocus = false
                    return
                }

                guard secondsLeft > 0, !didNotifyAlmostBreakForCurrentFocus else { return }
                didNotifyAlmostBreakForCurrentFocus = true
                postPomodoroAlmostTimeNotification(countdown: manager.formattedRemainingTime)
            }
            .store(in: &pomodoroNotificationObservers)

        Defaults.publisher(.pomodoroNotificationsEnabled)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                guard let self else { return }
                if !change.newValue {
                    didNotifyAlmostBreakForCurrentFocus = false
                    removePendingPomodoroAlmostTimeNotification()
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
        let request = UNNotificationRequest(
            identifier: pomodoroAlmostTimeNotificationID,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func removePendingPomodoroAlmostTimeNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [pomodoroAlmostTimeNotificationID])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
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
        
        // Create notch region at the top-center of the screen where an open notch would occupy
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

    private func createBoringNotchWindow(for screen: NSScreen, with viewModel: BoringViewModel) -> NSWindow {
        let rect = NSRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height)
        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow]
        
        let window = BoringNotchSkyLightWindow(contentRect: rect, styleMask: styleMask, backing: .buffered, defer: false)
        
        // Enable SkyLight only when screen is locked
        if isScreenLocked {
            window.enableSkyLight()
        } else {
            window.disableSkyLight()
        }

        window.contentView = NSHostingView(
            rootView: ContentView()
                .environmentObject(viewModel)
        )

        window.orderFrontRegardless()
        NotchSpaceManager.shared.notchSpace.windows.insert(window)

        // Observe when the window's screen changes so we can update drag detectors
        windowScreenDidChangeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeScreenNotification,
            object: window,
            queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.setupDragDetectors()
                }
        }
        return window
    }

    @MainActor
    private func positionWindow(_ window: NSWindow, on screen: NSScreen, changeAlpha: Bool = false) {
        if changeAlpha {
            window.alphaValue = 0
        }

        let screenFrame = screen.frame
        window.setFrameOrigin(
            NSPoint(
                x: screenFrame.origin.x + (screenFrame.width / 2) - window.frame.width / 2,
                y: screenFrame.origin.y + screenFrame.height - window.frame.height
            ))
        window.alphaValue = 1
    }

    func applicationDidFinishLaunching(_ notification: Notification) {

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            forName: Notification.Name.selectedScreenChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.adjustWindowPosition(changeAlpha: true)
                self?.setupDragDetectors()
            }
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name.notchHeightChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.adjustWindowPosition()
                self?.setupDragDetectors()
            }
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name.automaticallySwitchDisplayChanged, object: nil, queue: nil
        ) { [weak self] _ in
            guard let self = self, let window = self.window else { return }
            Task { @MainActor in
                window.alphaValue = self.coordinator.selectedScreenUUID == self.coordinator.preferredScreenUUID ? 1 : 0
            }
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name.showOnAllDisplaysChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.cleanupWindows(shouldInvert: true)
                self.adjustWindowPosition(changeAlpha: true)
                self.setupDragDetectors()
            }
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name.expandedDragDetectionChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setupDragDetectors()
            }
        }

        // Use closure-based observers for DistributedNotificationCenter and keep tokens for removal
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
                self.coordinator.toggleSneakPeek(
                    status: !self.coordinator.sneakPeek.show,
                    type: .music,
                    duration: 3.0
                )
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
                    await MainActor.run {
                        viewModel.open()
                    }

                    let task = Task { [weak viewModel] in
                        do {
                            try await Task.sleep(for: .seconds(3))
                            await MainActor.run {
                                viewModel?.close()
                            }
                        } catch { }
                    }
                    self.closeNotchTask = task
                case .open:
                    await MainActor.run {
                        viewModel.close()
                    }
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

        setupStrictModeObservers()
        setupStrictModeEscMonitors()
        setupPomodoroNotificationActions()
        if Defaults[.pomodoroNotificationsEnabled] {
            setupPomodoroAlmostTimeObservers()
        }

        if !Defaults[.showOnAllDisplays] {
            let viewModel = self.vm
            let window = createBoringNotchWindow(
                for: NSScreen.main ?? NSScreen.screens.first!, with: viewModel)
            self.window = window
            adjustWindowPosition(changeAlpha: true)
        } else {
            adjustWindowPosition(changeAlpha: true)
        }

        setupDragDetectors()

        if coordinator.firstLaunch {
            DispatchQueue.main.async {
                self.showOnboardingWindow()
            }
            playWelcomeSound()
        } else if MusicManager.shared.isNowPlayingDeprecated
            && Defaults[.mediaController] == .nowPlaying
        {
            DispatchQueue.main.async {
                self.showOnboardingWindow(step: .musicPermission)
            }
        }

        previousScreens = NSScreen.screens

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
        if #available(macOS 12.0, *) {
            for screen in NSScreen.screens {
                if screen.safeAreaInsets.top > 0 {
                    return true
                }
            }
        }
        return false
    }

    @objc func screenConfigurationDidChange() {
        let currentScreens = NSScreen.screens

        let screensChanged =
            currentScreens.count != previousScreens?.count
            || Set(currentScreens.compactMap { $0.displayUUID })
                != Set(previousScreens?.compactMap { $0.displayUUID } ?? [])
            || Set(currentScreens.map { $0.frame }) != Set(previousScreens?.map { $0.frame } ?? [])

        previousScreens = currentScreens

        if screensChanged {
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
        if Defaults[.showOnAllDisplays] {
            let currentScreenUUIDs = Set(NSScreen.screens.compactMap { $0.displayUUID })

            // Remove windows for screens that no longer exist
            for uuid in windows.keys where !currentScreenUUIDs.contains(uuid) {
                if let window = windows[uuid] {
                    window.close()
                    NotchSpaceManager.shared.notchSpace.windows.remove(window)
                    windows.removeValue(forKey: uuid)
                    viewModels.removeValue(forKey: uuid)
                }
            }

            // Create or update windows for all screens
            for screen in NSScreen.screens {
                guard let uuid = screen.displayUUID else { continue }
                
                if windows[uuid] == nil {
                    let viewModel = BoringViewModel(screenUUID: uuid)
                    let window = createBoringNotchWindow(for: screen, with: viewModel)

                    windows[uuid] = window
                    viewModels[uuid] = viewModel
                }

                if let window = windows[uuid], let viewModel = viewModels[uuid] {
                    positionWindow(window, on: screen, changeAlpha: changeAlpha)

                    if viewModel.notchState == .closed {
                        viewModel.close()
                    }
                }
            }
        } else {
            let selectedScreen: NSScreen

            if let preferredScreen = NSScreen.screen(withUUID: coordinator.preferredScreenUUID ?? "") {
                coordinator.selectedScreenUUID = coordinator.preferredScreenUUID ?? ""
                selectedScreen = preferredScreen
            } else if Defaults[.automaticallySwitchDisplay], let mainScreen = NSScreen.main,
                      let mainUUID = mainScreen.displayUUID {
                coordinator.selectedScreenUUID = mainUUID
                selectedScreen = mainScreen
            } else {
                if let window = window {
                    window.alphaValue = 0
                }
                return
            }

            vm.screenUUID = selectedScreen.displayUUID
            vm.notchSize = getClosedNotchSize(screenUUID: selectedScreen.displayUUID)

            if window == nil {
                window = createBoringNotchWindow(for: selectedScreen, with: vm)
            }

            if let window = window {
                positionWindow(window, on: selectedScreen, changeAlpha: changeAlpha)

                if vm.notchState == .closed {
                    vm.close()
                }
            }
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
//                        NSApp.setActivationPolicy(.accessory)
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

//        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        onboardingWindowController?.window?.orderFrontRegardless()
    }
}

private struct LockScreenPasscodePlayerView: View {
    @ObservedObject private var musicManager = MusicManager.shared
    @Default(.coloredSpectrogram) private var coloredSpectrogram
    @Default(.lockScreenPlayerBackgroundStyle) private var lockScreenPlayerBackgroundStyle
    @Default(.enableLyrics) private var enableLyrics
    @Default(.musicControlSlots) private var slotConfig
    @State private var sliderValue: Double = 0
    @State private var dragging = false
    @State private var lastDragged: Date = .distantPast

    private var duration: Double {
        max(0, musicManager.songDuration)
    }

    private var currentValue: Double {
        min(max(0, sliderValue), duration)
    }

    private var remainingValue: Double {
        max(0, duration - currentValue)
    }

    private var lyricLineText: String {
        if musicManager.isFetchingLyrics {
            return "Loading lyrics…"
        }

        if !musicManager.syncedLyrics.isEmpty {
            return musicManager.lyricLine(at: currentValue)
        }

        let trimmed = musicManager.currentLyrics.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No lyrics found" : trimmed.replacingOccurrences(of: "\n", with: " ")
    }

    var body: some View {
        ZStack {
            Color.clear

            VStack(alignment: .leading, spacing: 7) {
                topRow
                sliderBlock
                controlsRow
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(backgroundFill)
                    .overlay { backgroundOverlayA }
                    .overlay { backgroundOverlayB }
                    .overlay { backgroundOverlayC }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 22, y: 10)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var backgroundFill: AnyShapeStyle {
        switch lockScreenPlayerBackgroundStyle {
        case .glassBlur:
            return AnyShapeStyle(.ultraThinMaterial)
        case .liquidGlass:
            return AnyShapeStyle(.thinMaterial)
        case .solid:
            return AnyShapeStyle(Color.black.opacity(0.32))
        }
    }

    @ViewBuilder
    private var backgroundOverlayA: some View {
        switch lockScreenPlayerBackgroundStyle {
        case .glassBlur:
            Color.white.opacity(0.025)
        case .liquidGlass:
            LinearGradient(
                colors: [Color.white.opacity(0.10), Color.white.opacity(0.02), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .solid:
            Color.white.opacity(0.04)
        }
    }

    @ViewBuilder
    private var backgroundOverlayB: some View {
        switch lockScreenPlayerBackgroundStyle {
        case .glassBlur:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
        case .liquidGlass:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 0.9)
        case .solid:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 0.9)
        }
    }

    @ViewBuilder
    private var backgroundOverlayC: some View {
        switch lockScreenPlayerBackgroundStyle {
        case .glassBlur:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.10), lineWidth: 0.5)
                .blur(radius: 0.2)
        case .liquidGlass:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.12), lineWidth: 0.5)
                .blur(radius: 0.25)
        case .solid:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.18), lineWidth: 0.6)
                .blur(radius: 0.2)
        }
    }

    private var topRow: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let textWidth = max(0, width - 58 - 12 - 8 - 28)

            HStack(spacing: 12) {
                Image(nsImage: musicManager.albumArt)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 0) {
                    MarqueeText(
                        $musicManager.songTitle,
                        font: .headline,
                        nsFont: .headline,
                        textColor: .white,
                        frameWidth: textWidth
                    )
                    MarqueeText(
                        $musicManager.artistName,
                        font: .headline,
                        nsFont: .headline,
                        textColor: Defaults[.playerColorTinting]
                            ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.6)
                            : .gray,
                        frameWidth: textWidth
                    )
                    .fontWeight(.medium)
                    if enableLyrics {
                        MarqueeText(
                            .constant(lyricLineText),
                            font: .subheadline,
                            nsFont: .subheadline,
                            textColor: musicManager.isFetchingLyrics ? .gray.opacity(0.7) : .gray,
                            frameWidth: textWidth
                        )
                        .lineLimit(1)
                        .opacity(musicManager.isPlaying ? 1 : 0)
                    }
                }

                Spacer(minLength: 8)

                Rectangle()
                    .fill(
                        coloredSpectrogram
                            ? Color(nsColor: musicManager.avgColor).gradient
                            : Color.white.opacity(0.75).gradient
                    )
                    .frame(width: 28, height: 20)
                    .mask {
                        AudioSpectrumView(isPlaying: $musicManager.isPlaying)
                            .frame(width: 16, height: 12)
                    }
                    .opacity(musicManager.isPlaying ? 0.95 : 0.45)
            }
        }
        .frame(height: 58)
    }

    private var sliderBlock: some View {
        TimelineView(.animation(minimumInterval: musicManager.playbackRate > 0 ? 0.1 : nil)) { timeline in
            VStack(spacing: 3) {
                CustomSlider(
                    value: $sliderValue,
                    range: 0...max(duration, 0.01),
                    color: .white,
                    dragging: $dragging,
                    lastDragged: $lastDragged,
                    onValueChange: { newValue in
                        MusicManager.shared.seek(to: newValue)
                    }
                )
                .frame(height: 10)

                HStack {
                    Text(formatTime(currentValue))
                    Spacer()
                    Text("-\(formatTime(remainingValue))")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.76))
                .monospacedDigit()
            }
            .onChange(of: timeline.date) {
                guard !dragging, musicManager.timestampDate.timeIntervalSince(lastDragged) > -1 else { return }
                sliderValue = musicManager.estimatedPlaybackPosition(at: timeline.date)
            }
        }
    }

    private var controlsRow: some View {
        let slots = activeSlots
        return HStack(spacing: 12) {
            ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                slotView(for: slot)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var activeSlots: [MusicControlButton] {
        let limit = MusicControlButton.maxSlotCount
        let trimmed = Array(slotConfig.prefix(limit))
        if trimmed.count >= limit {
            return trimmed
        }
        return trimmed + Array(repeating: .none, count: limit - trimmed.count)
    }

    @ViewBuilder
    private func slotView(for slot: MusicControlButton) -> some View {
        switch slot {
        case .shuffle:
            playerButton(icon: "shuffle", active: musicManager.isShuffled) { MusicManager.shared.toggleShuffle() }
        case .previous:
            playerButton(icon: "backward.fill") { MusicManager.shared.previousTrack() }
        case .playPause:
            playerButton(icon: musicManager.isPlaying ? "pause.fill" : "play.fill", size: 50, iconSize: 26) {
                MusicManager.shared.togglePlay()
            }
        case .next:
            playerButton(icon: "forward.fill") { MusicManager.shared.nextTrack() }
        case .repeatMode:
            playerButton(icon: repeatIcon, active: musicManager.repeatMode != .off) { MusicManager.shared.toggleRepeat() }
        case .favorite:
            playerButton(icon: musicManager.isFavoriteTrack ? "heart.fill" : "heart", active: musicManager.isFavoriteTrack) {
                MusicManager.shared.toggleFavoriteTrack()
            }
            .disabled(!musicManager.canFavoriteTrack)
            .opacity(musicManager.canFavoriteTrack ? 1 : 0.45)
        case .goBackward:
            playerButton(icon: "gobackward.15") { MusicManager.shared.skip(seconds: -15) }
        case .goForward:
            playerButton(icon: "goforward.15") { MusicManager.shared.skip(seconds: 15) }
        case .volume:
            Color.clear.frame(width: 34, height: 34)
        case .none:
            Color.clear.frame(width: 34, height: 34)
        }
    }

    private var repeatIcon: String {
        switch musicManager.repeatMode {
        case .off:
            return "repeat"
        case .all:
            return "repeat"
        case .one:
            return "repeat.1"
        }
    }

    private func playerButton(
        icon: String,
        active: Bool = false,
        size: CGFloat = 34,
        iconSize: CGFloat = 16,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(active ? .red : .white)
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
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
