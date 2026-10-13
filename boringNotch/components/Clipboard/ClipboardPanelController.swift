//
//  ClipboardPanelController.swift
//  boringNotch
//
//  Created for Dino Architecture Evolution.
//

import AppKit
import SwiftUI

// Subclass NSPanel to allow borderless floating panel to accept key and main focus for text input
final class ClipboardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
public final class ClipboardPanelController: NSObject, NSWindowDelegate {
    public static let shared = ClipboardPanelController()

    private var panel: ClipboardPanel?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?

    // Clean, compact panel size directly matching the notch width
    private let panelSize = NSSize(width: 370, height: 360)

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
        ClipboardManager.shared.rememberPreviousApp()
        ClipboardManager.shared.searchText = ""
        ClipboardManager.shared.selectedIndex = 0

        let targetScreen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        let screenFrame = targetScreen.frame

        let windowX = screenFrame.origin.x + (screenFrame.width - panelSize.width) / 2.0
        // Position tucked ~38pt below the top (just below the notch)
        let windowY = screenFrame.origin.y + screenFrame.height - panelSize.height - 38.0
        let windowRect = NSRect(origin: NSPoint(x: windowX, y: windowY), size: panelSize)

        if panel == nil {
            let p = ClipboardPanel(
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

            let hostingView = NSHostingView(rootView: ClipboardPanelView())
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

        // Dismiss on clicking outside the panel
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
            }
        }

        // Dismiss on Escape key
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                Task { @MainActor in
                    self?.hide()
                }
                return nil
            }
            return event
        }
    }

    private func removeDismissMonitors() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }

    public func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
