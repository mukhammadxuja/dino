//
//  DinoWindowManager.swift
//  boringNotch
//

import Cocoa
import SwiftUI
import Defaults

@MainActor
final class DinoWindowManager {
    static let shared = DinoWindowManager()

    let lockScreenPlayerSize = NSSize(width: 355, height: 176)

    private init() {}

    // MARK: - Main Notch Window Creation

    func createBoringNotchWindow(
        for screen: NSScreen,
        with viewModel: BoringViewModel,
        isScreenLocked: Bool,
        onScreenChange: @escaping () -> Void
    ) -> (window: NSWindow, observer: Any?) {
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
                .environmentObject(BoringViewCoordinator.shared)
        )

        window.orderFrontRegardless()
        NotchSpaceManager.shared.notchSpace.windows.insert(window)

        let observer = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeScreenNotification,
            object: window,
            queue: .main
        ) { _ in
            onScreenChange()
        }

        return (window, observer)
    }

    // MARK: - Window Positioning

    func positionWindow(_ window: NSWindow, on screen: NSScreen, changeAlpha: Bool = false) {
        if changeAlpha {
            window.alphaValue = 0
        }

        let screenFrame = screen.frame
        window.setFrameOrigin(
            NSPoint(
                x: screenFrame.origin.x + (screenFrame.width / 2) - window.frame.width / 2,
                y: screenFrame.origin.y + screenFrame.height - window.frame.height
            )
        )
        window.alphaValue = 1
    }

    // MARK: - Lock Screen Player Window

    func createLockScreenPlayerWindow(for screen: NSScreen, isScreenLocked: Bool) -> NSWindow {
        let rect = NSRect(origin: .zero, size: lockScreenPlayerSize)
        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel, .utilityWindow]
        let window = BoringNotchSkyLightWindow(contentRect: rect, styleMask: styleMask, backing: .buffered, defer: false)

        let hostingView = NSHostingView(rootView: LockScreenPasscodePlayerView())
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = CGColor.clear
        window.contentView = hostingView
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

    func positionLockScreenPlayerWindow(_ window: NSWindow, on screen: NSScreen) {
        let screenFrame = screen.frame
        let x = screenFrame.origin.x + (screenFrame.width - lockScreenPlayerSize.width) / 2
        let y = screenFrame.origin.y + lockScreenPlayerBottomOffset
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    var lockScreenPlayerBottomOffset: CGFloat {
        let domain = "com.apple.loginwindow" as CFString
        let key = "HideUserAvatarAndName" as CFString

        let value = CFPreferencesCopyValue(
            key,
            domain,
            kCFPreferencesAnyUser,
            kCFPreferencesAnyHost
        )

        let hideUserAvatarAndName = (value as? Bool) ?? false
        return hideUserAvatarAndName ? 130 : 185
    }

    // MARK: - Screen Glow Window

    func createScreenGlowWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.contentView = NSHostingView(rootView: ScreenEdgeGlowView())
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false

        return window
    }

    // MARK: - Strict Mode Overlay Window

    func createStrictModeWindow(for screen: NSScreen) -> NSWindow {
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

    // MARK: - SkyLight Helpers

    func enableSkyLight(on windows: [NSWindow]) {
        windows.forEach { window in
            if let skyWindow = window as? BoringNotchSkyLightWindow {
                skyWindow.enableSkyLight()
            }
        }
    }

    func disableSkyLight(on windows: [NSWindow]) {
        windows.forEach { window in
            if let skyWindow = window as? BoringNotchSkyLightWindow {
                skyWindow.disableSkyLight()
            }
        }
    }
}
