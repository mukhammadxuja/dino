//
//  MirrorPanelController.swift
//  boringNotch
//
//  Created for Dino Architecture Evolution.
//

import AppKit
import Defaults
import SwiftUI

final class MirrorPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
public final class MirrorPanelController: NSObject, NSWindowDelegate {
    public static let shared = MirrorPanelController()

    private var panel: MirrorPanel?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?

    // Proportional, beautiful portrait mirror HUD dimensions
    private let panelSize = NSSize(width: 290, height: 320)

    private override init() {
        super.init()
    }

    public var isVisible: Bool {
        panel?.isVisible ?? false
    }

    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    public func show() {
        guard Defaults[.mirrorHUDEnabled] else { return }

        // Start camera session only when mirror is visibly opened
        MirrorManager.shared.startSession()

        let targetScreen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        let screenFrame = targetScreen.frame

        let windowX = screenFrame.origin.x + (screenFrame.width - panelSize.width) / 2.0
        // Position tucked ~38pt below the notch
        let windowY = screenFrame.origin.y + screenFrame.height - panelSize.height - 38.0
        let windowRect = NSRect(origin: NSPoint(x: windowX, y: windowY), size: panelSize)

        if panel == nil {
            let p = MirrorPanel(
                contentRect: windowRect,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true
            p.level = .floating
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.isMovableByWindowBackground = false
            p.delegate = self

            let hostingView = NSHostingView(rootView: MirrorHUDView())
            p.contentView = hostingView
            self.panel = p
        }

        guard let panel = panel else { return }
        panel.setFrame(windowRect, display: true)
        panel.invalidateShadow()
        panel.alphaValue = 1.0
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        setupDismissMonitors()
    }

    public func hide() {
        removeDismissMonitors()

        // Turn off camera immediately so LED turns off and zero energy is spent
        MirrorManager.shared.stopSession()

        guard let panel = panel, panel.isVisible else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            panel.animator().alphaValue = 0.0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    private func setupDismissMonitors() {
        removeDismissMonitors()

        // Dismiss when Esc is pressed
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                self?.hide()
                return nil
            }
            return event
        }

        // Dismiss when user clicks outside the panel
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hide()
        }
    }

    private func removeDismissMonitors() {
        if let local = localEventMonitor {
            NSEvent.removeMonitor(local)
            localEventMonitor = nil
        }
        if let global = globalEventMonitor {
            NSEvent.removeMonitor(global)
            globalEventMonitor = nil
        }
    }

    public func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
