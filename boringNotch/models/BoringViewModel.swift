//
//  BoringViewModel.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import Combine
import Defaults
import SwiftUI

class BoringViewModel: NSObject, ObservableObject {
    public static var activeInstance: BoringViewModel?
    public static var shared: BoringViewModel {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            let mouseLocation = NSEvent.mouseLocation
            for screen in NSScreen.screens {
                if NSMouseInRect(mouseLocation, screen.frame, false),
                   let uuid = screen.displayUUID,
                   let vm = appDelegate.viewModels[uuid] {
                    return vm
                }
            }
            if let mainUUID = NSScreen.main?.displayUUID,
               let vm = appDelegate.viewModels[mainUUID] {
                return vm
            }
            if let firstVM = appDelegate.viewModels.values.first {
                return firstVM
            }
        }
        if let active = activeInstance { return active }
        let fallback = BoringViewModel()
        activeInstance = fallback
        return fallback
    }

    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject var detector = FullscreenMediaDetector.shared

    let animationLibrary: BoringAnimations = .init()
    let animation: Animation?

    @Published var contentType: ContentType = .normal
    @Published private(set) var notchState: NotchState = .closed

    @Published var dragDetectorTargeting: Bool = false
    @Published var generalDropTargeting: Bool = false
    @Published var dropZoneTargeting: Bool = false
    @Published var dropEvent: Bool = false
    @Published var anyDropZoneTargeting: Bool = false
    var cancellables: Set<AnyCancellable> = []
    
    @Published var hideOnClosed: Bool = true

    @Published var edgeAutoOpenActive: Bool = false
    @Published var isHoveringCalendar: Bool = false
    @Published var isBatteryPopoverActive: Bool = false

    @Published var screenUUID: String?

    @Published var notchSize: CGSize = getClosedNotchSize()
    @Published var closedNotchSize: CGSize = getClosedNotchSize()
    
    let webcamManager = WebcamManager.shared
    @Published var isCameraExpanded: Bool = false
    @Published var isRequestingAuthorization: Bool = false
    
    deinit {
        destroy()
    }

    private var openNotchTask: Task<Void, Never>?
    private var notchOpenDiagnosticsTask: Task<Void, Never>?

    func destroy() {
        openNotchTask?.cancel()
        openNotchTask = nil
        notchOpenDiagnosticsTask?.cancel()
        notchOpenDiagnosticsTask = nil
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    init(screenUUID: String? = nil) {
        animation = animationLibrary.animation

        super.init()
        Self.activeInstance = self
        
        self.screenUUID = screenUUID
        notchSize = getClosedNotchSize(screenUUID: screenUUID)
        closedNotchSize = notchSize

        Publishers.CombineLatest3($dropZoneTargeting, $dragDetectorTargeting, $generalDropTargeting)
            .map { shelf, drag, general in
                shelf || drag || general
            }
            .assign(to: \.anyDropZoneTargeting, on: self)
            .store(in: &cancellables)
        
        setupDetectorObserver()
    }
    
    private func setupDetectorObserver() {
        // Publisher for the user’s fullscreen detection setting
        let enabledPublisher = Defaults
            .publisher(.hideNotchOption)
            .map(\.newValue)
            .map { $0 != .never }
            .removeDuplicates()

        // Publisher for the current screen UUID (non-nil, distinct)
        let screenPublisher = $screenUUID
            .compactMap { $0 }
            .removeDuplicates()

        // Publisher for fullscreen status dictionary
        let fullscreenStatusPublisher = detector.$fullscreenStatus
            .removeDuplicates()

        // Combine all three: screen UUID, fullscreen status, and enabled setting
        Publishers.CombineLatest3(screenPublisher, fullscreenStatusPublisher, enabledPublisher)
            .map { screenUUID, fullscreenStatus, enabled in
                let isFullscreen = fullscreenStatus[screenUUID] ?? false
                return enabled && isFullscreen
            }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] shouldHide in
                withAnimation(.smooth) {
                    self?.hideOnClosed = shouldHide
                }
            }
            .store(in: &cancellables)
    }

    // Computed property for effective notch height
    var effectiveClosedNotchHeight: CGFloat {
        let currentScreen = screenUUID.flatMap { NSScreen.screen(withUUID: $0) }
        let noNotchAndFullscreen = hideOnClosed && (currentScreen?.safeAreaInsets.top ?? 0 <= 0 || currentScreen == nil)
        return noNotchAndFullscreen ? 0 : closedNotchSize.height
    }

    var chinHeight: CGFloat {
        if !Defaults[.hideTitleBar] {
            return 0
        }

        guard let currentScreen = screenUUID.flatMap({ NSScreen.screen(withUUID: $0) }) else {
            return 0
        }

        if notchState == .open { return 0 }

        let menuBarHeight = currentScreen.frame.maxY - currentScreen.visibleFrame.maxY
        let currentHeight = effectiveClosedNotchHeight

        if currentHeight == 0 { return 0 }

        return max(0, menuBarHeight - currentHeight)
    }

    func toggleCameraPreview() {
        if isRequestingAuthorization {
            return
        }

        switch webcamManager.authorizationStatus {
        case .authorized:
            if webcamManager.isSessionRunning {
                webcamManager.stopSession()
                isCameraExpanded = false
            } else if webcamManager.cameraAvailable {
                webcamManager.startSession()
                isCameraExpanded = true
            }

        case .denied, .restricted:
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)

                let alert = NSAlert()
                alert.messageText = "Camera Access Required"
                alert.informativeText = "Please allow camera access in System Settings."
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")

                if alert.runModal() == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                        NSWorkspace.shared.open(url)
                    }
                }

                NSApp.setActivationPolicy(.accessory)
                NSApp.deactivate()
            }

        case .notDetermined:
            isRequestingAuthorization = true
            webcamManager.checkAndRequestVideoAuthorization()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.isRequestingAuthorization = false
            }

        default:
            break
        }
    }
    
    func isMouseHovering(position: NSPoint = NSEvent.mouseLocation) -> Bool {
        let screenFrame = getScreenFrame(screenUUID)
        if let frame = screenFrame {
            
            let baseY = frame.maxY - notchSize.height
            let baseX = frame.midX - notchSize.width / 2
            
            return position.y >= baseY && position.x >= baseX && position.x <= baseX + notchSize.width
        }
        
        return false
    }

    func mirrorSlotCardSize(isIsland: Bool) -> CGSize {
        let isBuiltin = (screenUUID.flatMap { NSScreen.screen(withUUID: $0) } ?? NSScreen.main)?.isBuiltin ?? true
        
        let width: CGFloat
        let hPadding: CGFloat
        let topPadding: CGFloat
        let bottomPadding: CGFloat
        
        if isIsland {
            width = isBuiltin ? 150 : 130
            hPadding = 12
            topPadding = 12
            bottomPadding = 12
        } else {
            let topCornerRadius: CGFloat = 10
            let musicExpansion = (2 * max(0, effectiveClosedNotchHeight - 12) + (isBuiltin ? 38 : 24))
            width = closedNotchSize.width + (2 * topCornerRadius) + 8 + musicExpansion
            hPadding = topCornerRadius + 14
            topPadding = effectiveClosedNotchHeight + 8
            bottomPadding = 14
        }
        
        let cameraSide = width - (2 * hPadding)
        let height = topPadding + cameraSide + bottomPadding
        return CGSize(width: width, height: height)
    }

    func expandedNotchSize(for slot: DinoSlot, isIsland: Bool) -> CGSize {
        if slot == .webcam {
            return mirrorSlotCardSize(isIsland: isIsland)
        }
        switch slot.asNotchView {
        case .calendar:
            return CGSize(width: 560, height: 190)
        case .home, .shelf:
            return CGSize(width: isIsland ? 385 : 435, height: 188)
        }
    }

    func open(targetSize: CGSize? = nil) {
        let openRequestStartedAt = ProcessInfo.processInfo.systemUptime
        let wasAlreadyOpen = notchState == .open
        let isIsland: Bool = {
            let screen = screenUUID.flatMap { NSScreen.screen(withUUID: $0) } ?? NSScreen.main
            let isBuiltin = screen?.isBuiltin ?? true
            switch Defaults[.displaySelection] {
            case .builtin:
                return Defaults[.builtinFormFactor] == .island
            case .external:
                return Defaults[.externalFormFactor] == .island
            case .both:
                return isBuiltin ? (Defaults[.builtinFormFactor] == .island) : (Defaults[.externalFormFactor] == .island)
            }
        }()
        let openSize = targetSize ?? expandedNotchSize(for: DinoCoordinator.shared.activeSlot, isIsland: isIsland)

        NSLog(
            "%@",
            "[DINO-PERF] NOTCH_OPEN_BEGIN alreadyOpen=\(wasAlreadyOpen) formFactor=\(isIsland ? "island" : "notch") size=\(Int(openSize.width))x\(Int(openSize.height)) slot=\(DinoCoordinator.shared.activeSlot) view=\(coordinator.currentView) prepMs=\(Int((ProcessInfo.processInfo.systemUptime - openRequestStartedAt) * 1_000))"
        )
        startNotchOpenDiagnostics()
        
        self.notchSize = openSize
        self.notchState = .open
        DinoCoordinator.shared.isExpanded = true
        NSLog(
            "%@",
            "[DINO-PERF] NOTCH_OPEN_STATE_SET elapsedMs=\(Int((ProcessInfo.processInfo.systemUptime - openRequestStartedAt) * 1_000))"
        )
        
        // Defer music information update until after the spring animation settles
        // so background queries and @Published property updates do not cause frame drops during expansion
        openNotchTask?.cancel()
        openNotchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(380))
            guard self?.notchState == .open else { return }
            NSLog("[DINO-PERF] NOTCH_OPEN_SETTLED_DELAY elapsedMs=380; requesting music refresh")
            MusicManager.shared.forceUpdate()
        }
    }

    private func startNotchOpenDiagnostics() {
        notchOpenDiagnosticsTask?.cancel()
        notchOpenDiagnosticsTask = Task { @MainActor [weak self] in
            var previousTick = ProcessInfo.processInfo.systemUptime

            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled, let self, self.notchState == .open else { break }

                let now = ProcessInfo.processInfo.systemUptime
                let gapMs = (now - previousTick) * 1_000
                if gapMs >= 250 {
                    NSLog(
                        "[DINO-PERF] NOTCH_OPEN_MAIN_THREAD_DELAY gapMs=%.0f slot=%@ view=%@",
                        gapMs,
                        String(describing: DinoCoordinator.shared.activeSlot),
                        String(describing: self.coordinator.currentView)
                    )
                }
                previousTick = now
            }

            self?.notchOpenDiagnosticsTask = nil
        }
    }

    func close(resetSelection: Bool = true) {
        openNotchTask?.cancel()
        openNotchTask = nil
        notchOpenDiagnosticsTask?.cancel()
        notchOpenDiagnosticsTask = nil
        coordinator.cancelAllTasks()

        // Do not close while a share picker or sharing service is active
        if SharingStateManager.shared.preventNotchClose {
            return
        }
        self.notchSize = getClosedNotchSize(screenUUID: self.screenUUID)
        self.closedNotchSize = self.notchSize
        self.notchState = .closed
        DinoCoordinator.shared.isExpanded = false
        self.isBatteryPopoverActive = false
        self.coordinator.sneakPeek.show = false
        self.edgeAutoOpenActive = false

        // Shortcut dismissal restores its own interrupted slot instead of applying this preference.
        guard resetSelection else { return }
        if !ShelfStateViewModel.shared.isEmpty && Defaults[.openShelfByDefault] {
            DinoCoordinator.shared.selectView(.shelf)
        } else if !coordinator.openLastTabByDefault {
            DinoCoordinator.shared.selectView(.home)
        }
    }

    func closeHello() {
        Task { @MainActor in
            withAnimation(animationLibrary.animation) {
                coordinator.helloAnimationRunning = false
                close()
            }
        }
    }
}
