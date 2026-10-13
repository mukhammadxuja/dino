//
//  DinoShortcutRecorder.swift
//  boringNotch
//
//  Created for Dino Architecture Evolution.
//

import AppKit
import Foundation
import KeyboardShortcuts
import SwiftUI

// MARK: - Shortcut Registry & Conflict Resolver

@MainActor
public final class ShortcutRegistry: ObservableObject {
    public static let shared = ShortcutRegistry()

    public struct ManagedShortcut: Identifiable {
        public let id: String
        public let name: KeyboardShortcuts.Name
        public let title: String
        public let category: String

        public init(name: KeyboardShortcuts.Name, title: String, category: String) {
            self.id = name.rawValue
            self.name = name
            self.title = title
            self.category = category
        }
    }

    public let allManagedShortcuts: [ManagedShortcut] = [
        .init(name: .clipboardHistoryPanel, title: "Clipboard History (HUD)", category: "Panels"),
        .init(name: .toggleNotchOpen, title: "Toggle Notch Open", category: "Panels"),
        .init(name: .toggleSneakPeek, title: "Sneak Peek", category: "Media"),
        .init(name: .selectMusicModule, title: "Now Playing (Music)", category: "Modules"),
        .init(name: .selectPomodoroModule, title: "Pomodoro Timer", category: "Modules"),
        .init(name: .selectCalendarModule, title: "Calendar", category: "Modules"),
        .init(name: .selectWeatherModule, title: "Weather", category: "Modules"),
        .init(name: .selectBatteryModule, title: "Battery Status", category: "Modules"),
        .init(name: .selectCodingModule, title: "Coding Activity", category: "Modules"),
        .init(name: .selectShelfModule, title: "Shelf (Upload)", category: "Modules"),
        .init(name: .pomodoroEmergencyExit, title: "Pomodoro Skip Break", category: "Pomodoro"),
        .init(name: .optionWeatherShortcut, title: "Quick Weather", category: "Quick Access"),
        .init(name: .optionCalendarShortcut, title: "Quick Calendar", category: "Quick Access"),
        .init(name: .optionMusicShortcut, title: "Quick Music", category: "Quick Access"),
        .init(name: .optionPomodoroShortcut, title: "Quick Pomodoro", category: "Quick Access"),
        .init(name: .toggleMicrophone, title: "Toggle Microphone", category: "System"),
        .init(name: .decreaseBacklight, title: "Decrease Backlight", category: "System"),
        .init(name: .increaseBacklight, title: "Increase Backlight", category: "System")
    ]

    private init() {}

    /// Checks if a shortcut is already assigned to another feature.
    /// Returns the conflicting feature title, or nil if free.
    public func conflictFeature(for shortcut: KeyboardShortcuts.Shortcut, excluding targetName: KeyboardShortcuts.Name) -> String? {
        for managed in allManagedShortcuts where managed.name != targetName {
            if let existing = KeyboardShortcuts.getShortcut(for: managed.name), existing == shortcut {
                return managed.title
            }
        }
        return nil
    }

    /// Shows a polished, native modal alert informing user of shortcut conflict.
    public func showConflictAlert(shortcutString: String, conflictingTitle: String) {
        NSSound.beep()

        let alert = NSAlert()
        alert.messageText = "Shortcut band qilingan"
        alert.informativeText = "Ushbu \"\(shortcutString)\" kombinatsiyasi allaqachon \"\(conflictingTitle)\" funksiyasiga biriktirilgan.\n\nIltimos, boshqa klaviatura kombinatsiyasidan foydalaning."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Tushunarli")
        alert.runModal()
    }
}

// MARK: - Dino Shortcut Recorder View

public struct DinoShortcutRecorder: View {
    public let name: KeyboardShortcuts.Name
    public var placeholder: String = "Record Shortcut"

    @State private var currentShortcut: KeyboardShortcuts.Shortcut?
    @State private var isRecording: Bool = false
    @State private var liveModifiers: NSEvent.ModifierFlags = []
    @State private var isHovered: Bool = false
    @State private var shakeOffset: CGFloat = 0
    @State private var localMonitor: Any?

    public init(name: KeyboardShortcuts.Name, placeholder: String = "Record Shortcut") {
        self.name = name
        self.placeholder = placeholder
    }

    public var body: some View {
        HStack(spacing: 6) {
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                contentBadge
            }
            .buttonStyle(.plain)
            .offset(x: shakeOffset)

            // Clear button if shortcut is present and not recording
            if currentShortcut != nil && !isRecording {
                Button {
                    clearShortcut()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Delete shortcut")
            }
        }
        .onAppear {
            currentShortcut = KeyboardShortcuts.getShortcut(for: name)
        }
        .onDisappear {
            stopRecording()
        }
    }

    // MARK: - UI Badges

    @ViewBuilder
    private var contentBadge: some View {
        if isRecording {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 6, height: 6)

                Text(recordingText)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4.5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.blue.opacity(0.20))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.blue, lineWidth: 1.2)
            )
        } else if let shortcut = currentShortcut {
            HStack(spacing: 3) {
                ForEach(formatShortcutKeys(shortcut), id: \.self) { key in
                    Text(key)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 5.5)
                        .padding(.vertical, 2.5)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.primary.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                        )
                }
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
            )
            .onHover { isHovered = $0 }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "keyboard")
                    .font(.system(size: 10.5))
                Text(placeholder)
                    .font(.system(size: 11.5, weight: .regular))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            )
            .onHover { isHovered = $0 }
        }
    }

    private var recordingText: String {
        var str = ""
        if liveModifiers.contains(.control) { str += "⌃ " }
        if liveModifiers.contains(.option) { str += "⌥ " }
        if liveModifiers.contains(.shift) { str += "⇧ " }
        if liveModifiers.contains(.command) { str += "⌘ " }

        if str.isEmpty {
            return "Type shortcut..."
        } else {
            return str + "..."
        }
    }

    private func formatShortcutKeys(_ shortcut: KeyboardShortcuts.Shortcut) -> [String] {
        var keys: [String] = []
        if shortcut.modifiers.contains(.control) { keys.append("⌃") }
        if shortcut.modifiers.contains(.option) { keys.append("⌥") }
        if shortcut.modifiers.contains(.shift) { keys.append("⇧") }
        if shortcut.modifiers.contains(.command) { keys.append("⌘") }

        // Description of key
        let desc = shortcut.description
        var keyOnly = desc
        for mod in ["⌃", "⌥", "⇧", "⌘"] {
            keyOnly = keyOnly.replacingOccurrences(of: mod, with: "")
        }
        if !keyOnly.isEmpty {
            keys.append(keyOnly.uppercased())
        }
        return keys.isEmpty ? [shortcut.description] : keys
    }

    // MARK: - Recording Engine

    private func startRecording() {
        stopRecording()
        isRecording = true
        liveModifiers = []

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            guard isRecording else { return event }

            if event.type == .flagsChanged {
                DispatchQueue.main.async {
                    self.liveModifiers = event.modifierFlags.intersection([.command, .option, .shift, .control])
                }
                // Intercept so system doesn't beep or pass through
                return nil
            }

            if event.type == .keyDown {
                // Escape without modifiers: cancel recording
                let rawMods = event.modifierFlags.intersection([.command, .option, .shift, .control])
                if event.keyCode == 53 && rawMods.isEmpty {
                    DispatchQueue.main.async {
                        self.stopRecording()
                    }
                    return nil
                }

                // Backspace/Delete without modifiers: clear shortcut
                if event.keyCode == 51 && rawMods.isEmpty {
                    DispatchQueue.main.async {
                        self.clearShortcut()
                        self.stopRecording()
                    }
                    return nil
                }

                // If user pressed a key with or without modifiers
                if let shortcut = KeyboardShortcuts.Shortcut(event: event) {
                    DispatchQueue.main.async {
                        self.handleRecordedShortcut(shortcut)
                    }
                }

                // IMPORTANT: Always return nil to swallow event, prevent √ or char typing!
                return nil
            }

            return event
        }
    }

    private func stopRecording() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        isRecording = false
        liveModifiers = []
    }

    private func clearShortcut() {
        KeyboardShortcuts.setShortcut(nil, for: name)
        currentShortcut = nil
    }

    private func handleRecordedShortcut(_ shortcut: KeyboardShortcuts.Shortcut) {
        stopRecording()

        // Conflict check
        if let conflict = ShortcutRegistry.shared.conflictFeature(for: shortcut, excluding: name) {
            triggerShake()
            ShortcutRegistry.shared.showConflictAlert(
                shortcutString: shortcut.description,
                conflictingTitle: conflict
            )
            return
        }

        // Save shortcut
        KeyboardShortcuts.setShortcut(shortcut, for: name)
        currentShortcut = shortcut
    }

    private func triggerShake() {
        withAnimation(.easeInOut(duration: 0.08).repeatCount(4, autoreverses: true)) {
            shakeOffset = 6
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            shakeOffset = 0
        }
    }
}

// MARK: - Dino Shortcut Row Helper

public struct DinoShortcutRow: View {
    public let title: String
    public let name: KeyboardShortcuts.Name

    public init(_ title: String, name: KeyboardShortcuts.Name) {
        self.title = title
        self.name = name
    }

    public var body: some View {
        HStack {
            Text(title)
            Spacer()
            DinoShortcutRecorder(name: name)
        }
    }
}
