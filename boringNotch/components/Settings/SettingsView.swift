//
//  SettingsView.swift
//  boringNotch
//
//  Created by Richard Kunkli on 07/08/2024.
//

import AVFoundation
import AppKit
import Defaults
import EventKit
import KeyboardShortcuts
import LaunchAtLogin
import Sparkle
import SwiftUI
import SwiftUIIntrospect

// MARK: - Sidebar Custom Items (Modern Squircle UI)
struct SettingsSidebarItemRow: View {
    let title: String
    let icon: String
    let iconBg: Color
    let isSelected: Bool
    var isSubItem: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: isSubItem ? 6 : 7.5, style: .continuous)
                        .fill(iconBg)
                        .frame(width: isSubItem ? 22 : 28, height: isSubItem ? 22 : 28)

                    Image(systemName: icon)
                        .font(.system(size: isSubItem ? 11 : 13.5, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text(title)
                    .font(.system(size: isSubItem ? 12.5 : 13.5, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .primary.opacity(0.88))

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, isSubItem ? 4.5 : 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.09) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? Color.primary.opacity(0.07) : Color.clear, lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, isSubItem ? 16 : 0)
        .onHover { hov in
            isHovered = hov
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab = "General"
    @State private var accentColorUpdateTrigger = UUID()
    @Default(.useCustomAccentColor) private var useCustomAccentColor
    @Default(.customAccentColorData) private var customAccentColorData

    let updaterController: SPUStandardUpdaterController?

    init(updaterController: SPUStandardUpdaterController? = nil) {
        self.updaterController = updaterController
    }

    var body: some View {
        NavigationSplitView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 3) {
                    SettingsSidebarItemRow(title: "General", icon: "gearshape.fill", iconBg: Color.effectiveAccent, isSelected: selectedTab == "General") {
                        selectedTab = "General"
                    }
                    SettingsSidebarItemRow(title: "Appearance", icon: "eye.fill", iconBg: Color(red: 0.15, green: 0.55, blue: 0.98), isSelected: selectedTab == "Appearance") {
                        selectedTab = "Appearance"
                    }
                    SettingsSidebarItemRow(title: "Lock Screen", icon: "lock.fill", iconBg: Color(red: 0.35, green: 0.38, blue: 0.92), isSelected: selectedTab == "LockScreen") {
                        selectedTab = "LockScreen"
                    }
                    SettingsSidebarItemRow(title: "Media", icon: "play.tv.fill", iconBg: Color(red: 0.95, green: 0.25, blue: 0.35), isSelected: selectedTab == "Media") {
                        selectedTab = "Media"
                    }
                    SettingsSidebarItemRow(title: "Calendar", icon: "calendar", iconBg: Color(red: 0.98, green: 0.35, blue: 0.35), isSelected: selectedTab == "Calendar") {
                        selectedTab = "Calendar"
                    }
                    SettingsSidebarItemRow(title: "HUDs", icon: "dial.medium.fill", iconBg: Color(red: 0.98, green: 0.58, blue: 0.10), isSelected: selectedTab == "HUD") {
                        selectedTab = "HUD"
                    }

                    SettingsSidebarItemRow(title: "Battery", icon: "battery.100", iconBg: Color(red: 0.18, green: 0.80, blue: 0.44), isSelected: selectedTab == "Battery") {
                        selectedTab = "Battery"
                    }

                    SettingsSidebarItemRow(title: "Shelf", icon: "books.vertical.fill", iconBg: Color(red: 0.55, green: 0.35, blue: 0.95), isSelected: selectedTab == "Shelf") {
                        selectedTab = "Shelf"
                    }
                    SettingsSidebarItemRow(title: "Pomodoro", icon: "timer", iconBg: Color(red: 0.95, green: 0.35, blue: 0.25), isSelected: selectedTab == "Pomodoro") {
                        selectedTab = "Pomodoro"
                    }
                    SettingsSidebarItemRow(title: "Shortcuts", icon: "command", iconBg: Color(red: 0.10, green: 0.65, blue: 0.95), isSelected: selectedTab == "Shortcuts") {
                        selectedTab = "Shortcuts"
                    }
                    SettingsSidebarItemRow(title: "Advanced", icon: "gearshape.2.fill", iconBg: Color(red: 0.50, green: 0.52, blue: 0.58), isSelected: selectedTab == "Advanced") {
                        selectedTab = "Advanced"
                    }
                    SettingsSidebarItemRow(title: "About", icon: "info", iconBg: Color(red: 0.35, green: 0.45, blue: 0.95), isSelected: selectedTab == "About") {
                        selectedTab = "About"
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
            }
            .background(Color(red: 245/255, green: 245/255, blue: 247/255))
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(min: 200, ideal: 215, max: 235)
        } detail: {
            Group {
                switch selectedTab {
                case "General":
                    GeneralSettings()
                case "Appearance":
                    Appearance()
                case "LockScreen":
                    LockScreenSettingsView()
                case "Media":
                    MediaSettingsView()
                case "Calendar":
                    CalendarSettings()
                case "HUD":
                    HUDSettingsView()
                case "Battery":
                    BatterySettingsView()
                case "Shelf":
                    Shelf()
                case "Pomodoro":
                    PomodoroSettings()
                case "Shortcuts":
                    Shortcuts()
                case "Extensions":
                    GeneralSettings()
                case "Advanced":
                    Advanced()
                case "About":
                    if let controller = updaterController {
                        About(updaterController: controller)
                    } else {
                        // Fallback with a default controller
                        About(
                            updaterController: SPUStandardUpdaterController(
                                startingUpdater: false, updaterDelegate: nil,
                                userDriverDelegate: nil))
                    }
                default:
                    GeneralSettings()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("")
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 840, idealWidth: 860, minHeight: 620, idealHeight: 640)
        .background(Color.white)
        .preferredColorScheme(.light)
        .tint(.effectiveAccent)
        .id(accentColorUpdateTrigger)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AccentColorChanged"))) { _ in
            accentColorUpdateTrigger = UUID()
        }
    }
}

private struct NotchTuningSliderRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let axis: NotchTuningAxis
    let range: ClosedRange<Int>
    @Binding var value: Int
    @State private var draftValue: Int
    @State private var isDragging = false

    private let thumbSize: CGFloat = 22
    init(title: String, subtitle: String, icon: String, axis: NotchTuningAxis, range: ClosedRange<Int>, value: Binding<Int>) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.axis = axis
        self.range = range
        self._value = value
        self._draftValue = State(initialValue: min(range.upperBound, max(range.lowerBound, value.wrappedValue)))
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.effectiveAccent.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.effectiveAccent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(valueLabel)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.effectiveAccent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.effectiveAccent.opacity(0.08), in: Capsule())
                    .overlay(Capsule().stroke(Color.effectiveAccent.opacity(0.18), lineWidth: 1))
            }

            GeometryReader { geometry in
                let usableWidth = max(1, geometry.size.width - thumbSize)
                let fraction = CGFloat(draftValue - range.lowerBound) / CGFloat(range.upperBound - range.lowerBound)
                let thumbX = usableWidth * fraction

                ZStack(alignment: .topLeading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.13))
                        .frame(width: usableWidth, height: 6)
                        .offset(x: thumbSize / 2, y: 11)

                    Capsule()
                        .fill(Color.effectiveAccent)
                        .frame(width: thumbX, height: 6)
                        .offset(x: thumbSize / 2, y: 11)

                    ForEach(0..<(range.upperBound - range.lowerBound + 1), id: \.self) { index in
                        Circle()
                            .fill(Color.primary.opacity(0.25))
                            .frame(width: 3, height: 3)
                            .offset(x: thumbSize / 2 + usableWidth * CGFloat(index) / CGFloat(range.upperBound - range.lowerBound) - 1.5, y: 32)
                    }

                    Circle()
                        .fill(Color.white)
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(color: .black.opacity(0.17), radius: 4, y: 2)
                        .offset(x: thumbX, y: 3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            if !isDragging {
                                isDragging = true
                                NotchTuningPreviewState.shared.begin(axis, value: draftValue)
                            }
                            let progress = min(1, max(0, (gesture.location.x - thumbSize / 2) / usableWidth))
                            let raw = CGFloat(range.lowerBound) + progress * CGFloat(range.upperBound - range.lowerBound)
                            let newValue = Int(raw.rounded())
                            if draftValue != newValue {
                                draftValue = newValue
                                NotchTuningPreviewState.shared.update(newValue)
                                performSelectionHaptic()
                            }
                        }
                        .onEnded { _ in
                            finishDragging()
                        }
                )
            }
            .frame(height: 40)
            .accessibilityLabel(title)
            .accessibilityValue(valueLabel)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onChange(of: value) { _, newValue in
            if !isDragging { draftValue = newValue }
        }
        .onDisappear {
            finishDragging()
        }
    }

    private func finishDragging() {
        guard isDragging else { return }
        isDragging = false
        let selectedValue = draftValue
        NotchTuningPreviewState.shared.end {
            value = selectedValue
        }
    }

    private var valueLabel: String {
        draftValue > 0 ? "+\(draftValue)" : "\(draftValue)"
    }

    private func performSelectionHaptic() {
        if Defaults[.enableHaptics] {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }
}

struct GeneralSettings: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var coordinator = BoringViewCoordinator.shared

    @Default(.menubarIcon) var menubarIcon
    @Default(.hideNotchOption) var hideNotchOption
    @Default(.hideFromScreenRecording) var hideFromScreenRecording
    @Default(.enableGestures) var enableGestures
    @Default(.openNotchOnHover) var openNotchOnHover
    @Default(.idleClickAction) var idleClickAction
    @Default(.clipboardHistoryEnabled) var clipboardHistoryEnabled
    @Default(.clipboardHistoryAutoPaste) var clipboardHistoryAutoPaste
    @Default(.clipboardHistoryMaxItems) var clipboardHistoryMaxItems
    @Default(.notchWidthAdjustment) private var notchWidthAdjustment
    @Default(.notchHeightAdjustment) private var notchHeightAdjustment

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - 1. System Settings Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("System")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)

                    VStack(spacing: 0) {
                        // Row 1: Launch at login
                        settingRow(
                            icon: "power.circle.fill",
                            iconColor: Color.blue,
                            title: "Launch at login",
                            subtitle: "Open BoringNotch automatically when you log in to your Mac",
                            isOn: Binding(
                                get: { LaunchAtLogin.isEnabled },
                                set: { LaunchAtLogin.isEnabled = $0 }
                            )
                        )

                        cardDivider

                        // Row 2: Show menu bar icon
                        settingRow(
                            icon: "menubar.rectangle",
                            iconColor: Color.purple,
                            title: "Show menu bar icon",
                            subtitle: "Display BoringNotch icon in the macOS menu bar for quick access",
                            isOn: $menubarIcon
                        )

                        cardDivider

                        // Row 3: Show in full screen
                        settingRow(
                            icon: "arrow.up.left.and.arrow.down.right.rectangle",
                            iconColor: Color.teal,
                            title: "Show in full screen",
                            subtitle: "Keep the notch and island visible over full screen applications",
                            isOn: Binding(
                                get: { hideNotchOption == .never },
                                set: { hideNotchOption = $0 ? .never : .always }
                            )
                        )

                        cardDivider

                        // Row 4: Remember last active tab
                        settingRow(
                            icon: "clock.arrow.circlepath",
                            iconColor: Color.orange,
                            title: "Remember last active feature",
                            subtitle: "Reopen Music, Timer, Shelf, Weather, or Calendar where you left off",
                            isOn: $coordinator.openLastTabByDefault
                        )

                        cardDivider

                        // Row 5: Display in screen capture
                        settingRow(
                            icon: "camera.viewfinder",
                            iconColor: Color.green,
                            title: "Display in screen capture",
                            subtitle: "Include BoringNotch in screen recordings and screenshots",
                            isOn: Binding(
                                get: { !hideFromScreenRecording },
                                set: { hideFromScreenRecording = !$0 }
                            )
                        )

                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
                    )
                }

                // MARK: - 2. Idle Activity
                VStack(alignment: .leading, spacing: 8) {
                    Text("Idle activity")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)

                    Text("Choose what opens when you click an idle notch or Dynamic Island")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach([IdleClickAction.none, .music, .pomodoro, .weather, .calendar]) { action in
                            IdleActivityCard(action: action, selection: $idleClickAction)
                        }
                    }
                }

                // MARK: - 3. Clipboard History Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Clipboard history")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)
                        customBadge(text: "⌥V")
                    }

                    VStack(spacing: 0) {
                        // Master Toggle: Enable Clipboard History
                        settingRow(
                            icon: "doc.on.clipboard.fill",
                            iconColor: Color.orange,
                            title: "Enable clipboard history",
                            subtitle: "Track recent copied texts, links, images, and colors in a floating HUD",
                            isOn: $clipboardHistoryEnabled
                        )

                        if clipboardHistoryEnabled {
                            cardDivider

                            // Shortcut recorder row
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(Color.orange.opacity(0.12))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: "keyboard.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.orange)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Global shortcut")
                                        .font(.system(size: 13.5, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text("Press shortcut from anywhere to open clipboard panel")
                                        .font(.system(size: 11.5))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                DinoShortcutRecorder(name: .clipboardHistoryPanel)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)

                            cardDivider

                            // Auto-paste toggle
                            settingRow(
                                icon: "arrow.right.doc.on.clipboard",
                                iconColor: Color.blue,
                                title: "Auto-paste on selection",
                                subtitle: "Instantly paste the selected item into the previous active application",
                                isOn: $clipboardHistoryAutoPaste
                            )

                            cardDivider

                            // Max items picker
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(Color.purple.opacity(0.12))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: "tray.full.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.purple)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("History limit")
                                        .font(.system(size: 13.5, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text("Maximum number of clipboard items to keep in history")
                                        .font(.system(size: 11.5))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Picker("", selection: $clipboardHistoryMaxItems) {
                                    Text("25 items").tag(25)
                                    Text("50 items").tag(50)
                                    Text("100 items").tag(100)
                                }
                                .frame(width: 120)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
                    )
                }

                // MARK: - 4. Mirror HUD Card
                if ReleaseFeatures.mirror {
                    MirrorSettingsCard()
                }

                // MARK: - 5. Gestures
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gestures")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)

                    VStack(spacing: 0) {
                        settingRow(
                            icon: "hand.draw.fill",
                            iconColor: Color.indigo,
                            title: "Enable gestures",
                            subtitle: "Multi-touch trackpad gestures on the notch & Dynamic Island",
                            isOn: $enableGestures
                        )

                        if enableGestures {
                            cardDivider

                            // Gestures Cheatsheet / Guide
                            VStack(alignment: .leading, spacing: 10) {
                                Text("HOW TO USE GESTURES")
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundStyle(.secondary.opacity(0.8))
                                    .padding(.top, 2)

                                gestureGuideRow(
                                    icon: "arrow.up.and.down",
                                    action: "Swipe Down / Up",
                                    description: "Swipe down to open, or up to close; release your fingers to confirm"
                                )

                                gestureGuideRow(
                                    icon: "arrow.left.and.right",
                                    action: "Swipe Left / Right",
                                    description: "With music playing: next track (left) or restart / previous (right)"
                                )

                                gestureGuideRow(
                                    icon: "arrow.down",
                                    action: "Swipe Down while Open",
                                    description: "Release to advance Music → Timer → Shelf → Music"
                                )
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.primary.opacity(0.02))
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
                    )
                }

                // MARK: - 6. Tuning
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tuning")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                    VStack(spacing: 0) {
                        NotchTuningSliderRow(
                            title: "Notch width",
                            subtitle: "Make the notch wider or narrower",
                            icon: "arrow.left.and.right",
                            axis: .width,
                            range: -3...5,
                            value: $notchWidthAdjustment
                        )
                        cardDivider
                        NotchTuningSliderRow(
                            title: "Notch height",
                            subtitle: "Make the notch taller or shorter",
                            icon: "arrow.up.and.down",
                            axis: .height,
                            range: -3...3,
                            value: $notchHeightAdjustment
                        )
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1))
                }

                // MARK: - 7. App Quit Section
                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        NSApp.terminate(nil)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "power")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Quit Dino")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                    Spacer()
                }
                .padding(.top, 6)
            }
            .padding(20)
        }
        .navigationTitle("General")
        .onAppear {
            if idleClickAction == .shelf {
                idleClickAction = .none
            }
            notchWidthAdjustment = min(5, max(-3, notchWidthAdjustment))
            notchHeightAdjustment = min(3, max(-3, notchHeightAdjustment))
        }
    }

    private var cardDivider: some View {
        Divider()
            .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func settingRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.effectiveAccent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func gestureGuideRow(
        icon: String,
        action: String,
        description: String
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 24, height: 24)
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.75))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(action)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Lock Screen Settings View
private struct LockScreenBackgroundStyleCard: View {
    let style: LockScreenPlayerBackgroundStyle
    @Binding var selection: LockScreenPlayerBackgroundStyle

    var body: some View {
        CompactSelectionCard(value: style, selection: $selection) {
            HStack(spacing: 8) {
                Image(systemName: style == .glass ? "square.on.square" : "square.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(selection == style ? Color.effectiveAccent : .secondary)

                Text(style.title)
                    .font(.system(size: 12, weight: selection == style ? .semibold : .medium))
                    .foregroundColor(selection == style ? .primary : .secondary)
            }
        }
    }
}

struct LockScreenSettingsView: View {
    @Default(.showOnLockScreen) private var showOnLockScreen
    @Default(.lockScreenPlayerEnabled) private var lockScreenPlayerEnabled
    @Default(.lockScreenPlayerBackgroundStyle) private var lockScreenPlayerBackgroundStyle
    @Default(.lockScreenSoundEnabled) private var lockScreenSoundEnabled
    @Default(.lockScreenSoundVolume) private var lockScreenSoundVolume

    private let audioPlayer = AudioPlayer()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - 1. Display Card (Notch / Island)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)

                    VStack(spacing: 0) {
                        settingRow(
                            icon: "display",
                            iconColor: Color.blue,
                            title: "Show notch on lock screen",
                            subtitle: "Keep the notch or island visible while your Mac is locked",
                            isOn: $showOnLockScreen
                        )
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
                    )
                }

                // MARK: - 2. Lock Screen Player Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Media player")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)

                    VStack(spacing: 0) {
                        settingRow(
                            icon: "play.circle.fill",
                            iconColor: Color(red: 0.95, green: 0.25, blue: 0.35),
                            title: "Lock screen player",
                            subtitle: "Display media playback and controls above the passcode area",
                            isOn: $lockScreenPlayerEnabled
                        )

                        if lockScreenPlayerEnabled {
                            cardDivider

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Background style")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)

                                HStack(spacing: 8) {
                                    ForEach(LockScreenPlayerBackgroundStyle.allCases) { style in
                                        LockScreenBackgroundStyleCard(style: style, selection: $lockScreenPlayerBackgroundStyle)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
                    )

                    Text("The player appears automatically above the passcode field whenever media is playing.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }

                // MARK: - 3. Sound Effects Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sound effects")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)

                    VStack(spacing: 0) {
                        settingRow(
                            icon: "lock.circle.fill",
                            iconColor: Color(red: 0.98, green: 0.58, blue: 0.10),
                            title: "Lock & unlock sound",
                            subtitle: "Play audio feedback when locking and unlocking your Mac",
                            isOn: $lockScreenSoundEnabled
                        )

                        if lockScreenSoundEnabled {
                            cardDivider

                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(Color.orange.opacity(0.12))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.orange)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sound volume")
                                        .font(.system(size: 13.5, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text("Volume level for the lock and unlock sounds")
                                        .font(.system(size: 11.5))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                HStack(spacing: 8) {
                                    Slider(
                                        value: Binding(
                                            get: { Double(lockScreenSoundVolume) },
                                            set: { lockScreenSoundVolume = Float($0) }
                                        ),
                                        in: 0.0...1.0,
                                        step: 0.05
                                    )
                                    .tint(.effectiveAccent)
                                    .frame(width: 100)

                                    Text("\(Int(lockScreenSoundVolume * 100))%")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .frame(width: 36, alignment: .trailing)

                                    Button {
                                        playPreviewSound()
                                    } label: {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 10))
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Test sound")
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
                    )
                }
            }
            .padding(20)
        }
        .navigationTitle("Lock Screen")
    }

    private var cardDivider: some View {
        Divider()
            .padding(.horizontal, 16)
    }

    private func playPreviewSound() {
        let extensions = ["mp3", "m4a", "wav", "caf", "aiff"]
        for ext in extensions {
            if audioPlayer.playIfAvailable(fileName: "lockscreen-sound", fileExtension: ext, volume: lockScreenSoundVolume) {
                break
            }
        }
    }

    @ViewBuilder
    private func settingRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.effectiveAccent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

//struct Downloads: View {
//    @Default(.selectedDownloadIndicatorStyle) var selectedDownloadIndicatorStyle
//    @Default(.selectedDownloadIconStyle) var selectedDownloadIconStyle
//    var body: some View {
//        Form {
//            warningBadge("We don't support downloads yet", "It will be supported later on.")
//            Section {
//                Defaults.Toggle(key: .enableDownloadListener) {
//                    Text("Show download progress")
//                }
//                    .disabled(true)
//                Defaults.Toggle(key: .enableSafariDownloads) {
//                    Text("Enable Safari Downloads")
//                }
//                    .disabled(!Defaults[.enableDownloadListener])
//                Picker("Download indicator style", selection: $selectedDownloadIndicatorStyle) {
//                    Text("Progress bar")
//                        .tag(DownloadIndicatorStyle.progress)
//                    Text("Percentage")
//                        .tag(DownloadIndicatorStyle.percentage)
//                }
//                Picker("Download icon style", selection: $selectedDownloadIconStyle) {
//                    Text("Only app icon")
//                        .tag(DownloadIconStyle.onlyAppIcon)
//                    Text("Only download icon")
//                        .tag(DownloadIconStyle.onlyIcon)
//                    Text("Both")
//                        .tag(DownloadIconStyle.iconAndAppIcon)
//                }
//
//            } header: {
//                HStack {
//                    Text("Download indicators")
//                    comingSoonTag()
//                }
//            }
//            Section {
//                List {
//                    ForEach([].indices, id: \.self) { index in
//                        Text("\(index)")
//                    }
//                }
//                .frame(minHeight: 96)
//                .overlay {
//                    if true {
//                        Text("No excluded apps")
//                            .foregroundStyle(Color(.secondaryLabelColor))
//                    }
//                }
//                .actionBar(padding: 0) {
//                    Group {
//                        Button {
//                        } label: {
//                            Image(systemName: "plus")
//                                .frame(width: 25, height: 16, alignment: .center)
//                                .contentShape(Rectangle())
//                                .foregroundStyle(.secondary)
//                        }
//
//                        Divider()
//                        Button {
//                        } label: {
//                            Image(systemName: "minus")
//                                .frame(width: 20, height: 16, alignment: .center)
//                                .contentShape(Rectangle())
//                                .foregroundStyle(.secondary)
//                        }
//                    }
//                }
//            } header: {
//                HStack(spacing: 4) {
//                    Text("Exclude apps")
//                    comingSoonTag()
//                }
//            }
//        }
//        .navigationTitle("Downloads")
//    }
//}

// MARK: - Idle Activity Radio Selection Card
private struct IdleActivityCard: View {
    let action: IdleClickAction
    @Binding var selection: IdleClickAction
    @State private var isHovered = false

    private var label: String {
        switch action {
        case .none: return "None"
        case .music: return "Playing"
        case .pomodoro: return "Timer"
        case .weather: return "Weather"
        case .calendar: return "Calendar"
        case .shelf: return "Shelf"
        }
    }

    private var icon: String {
        switch action {
        case .none: return "circle.slash"
        case .music: return "waveform"
        case .pomodoro: return "timer"
        case .weather: return "cloud.sun.fill"
        case .calendar: return "calendar"
        case .shelf: return "tray.full.fill"
        }
    }

    var body: some View {
        let isSelected = selection == action
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selection = action
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSelected ? .effectiveAccent : (isHovered ? .primary : .secondary))
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.effectiveAccent.opacity(0.12) :
                          (isHovered ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.effectiveAccent : Color.primary.opacity(0.08),
                            lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .onHover { isHovered = $0 }
    }
}

struct CalendarSettings: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    @Default(.showCalendar) var showCalendar: Bool
    @Default(.hideCompletedReminders) var hideCompletedReminders
    @Default(.hideAllDayEvents) var hideAllDayEvents
    @Default(.autoScrollToNextEvent) var autoScrollToNextEvent

    var body: some View {
        Form {
            calendarTogglesSection
            calendarsSection
            remindersSection
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Calendar")
        .onAppear {
            Task {
                await calendarManager.checkCalendarAuthorization()
                await calendarManager.checkReminderAuthorization()
            }
        }
    }

    @ViewBuilder
    private var calendarTogglesSection: some View {
        HStack(alignment: .center) {
            Text("Show calendar")
            Spacer()
            KbdShortcutBadge(keys: ["⌘", "⇧", "A"])
            Toggle("", isOn: $showCalendar)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.effectiveAccent)
                .onChange(of: showCalendar) { _, enabled in
                    if !enabled {
                        if Defaults[.activeModule] == .calendar {
                            Defaults[.activeModule] = .none
                        }
                        if DinoCoordinator.shared.activeSlot == .calendar {
                            DinoCoordinator.shared.activateSlotDirectly(DinoCoordinator.shared.backgroundSlot)
                        }
                    }
                }
        }
        Defaults.Toggle(key: .hideCompletedReminders) {
            Text("Hide completed reminders")
        }
        Defaults.Toggle(key: .hideAllDayEvents) {
            Text("Hide all-day events")
        }
        Defaults.Toggle(key: .autoScrollToNextEvent) {
            Text("Auto-scroll to next event")
        }
        Defaults.Toggle(key: .showFullEventTitles) {
            Text("Always show full event titles")
        }
    }

    @ViewBuilder
    private var calendarsSection: some View {
        Section(header: Text("Calendars")) {
            if calendarManager.calendarAuthorizationStatus != .fullAccess {
                Text("Calendar access is denied. Please enable it in System Settings.")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                Button("Open Calendar Settings") {
                    if let settingsURL = URL(
                        string:
                            "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
                    ) {
                        NSWorkspace.shared.open(settingsURL)
                    }
                }
            } else {
                List {
                    ForEach(calendarManager.eventCalendars, id: \.id) { calendar in
                        Toggle(
                            isOn: Binding(
                                get: { calendarManager.getCalendarSelected(calendar) },
                                set: { isSelected in
                                    Task {
                                        await calendarManager.setCalendarSelected(
                                            calendar, isSelected: isSelected)
                                    }
                                }
                            )
                        ) {
                            Text(calendar.title)
                        }
                        .accentColor(lighterColor(from: calendar.color))
                        .disabled(!showCalendar)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var remindersSection: some View {
        Section(header: Text("Reminders")) {
            if calendarManager.reminderAuthorizationStatus != .fullAccess {
                Text("Reminder access is denied. Please enable it in System Settings.")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                Button("Open Reminder Settings") {
                    if let settingsURL = URL(
                        string:
                            "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders"
                    ) {
                        NSWorkspace.shared.open(settingsURL)
                    }
                }
            } else {
                List {
                    ForEach(calendarManager.reminderLists, id: \.id) { calendar in
                        Toggle(
                            isOn: Binding(
                                get: { calendarManager.getCalendarSelected(calendar) },
                                set: { isSelected in
                                    Task {
                                        await calendarManager.setCalendarSelected(
                                            calendar, isSelected: isSelected)
                                    }
                                }
                            )
                        ) {
                            Text(calendar.title)
                        }
                        .accentColor(lighterColor(from: calendar.color))
                        .disabled(!showCalendar)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await calendarManager.checkCalendarAuthorization()
                await calendarManager.checkReminderAuthorization()
            }
        }
    }
}

func lighterColor(from nsColor: NSColor, amount: CGFloat = 0.14) -> Color {
    let srgb = nsColor.usingColorSpace(.sRGB) ?? nsColor
    var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0,0,0,0)
    srgb.getRed(&r, green: &g, blue: &b, alpha: &a)

    func lighten(_ c: CGFloat) -> CGFloat {
        let increased = c + (1.0 - c) * amount
        return min(max(increased, 0), 1)
    }

    let nr = lighten(r)
    let ng = lighten(g)
    let nb = lighten(b)

    return Color(red: Double(nr), green: Double(ng), blue: Double(nb), opacity: Double(a))
}

struct About: View {
    @State private var showBuildNumber: Bool = false
    let updaterController: SPUStandardUpdaterController
    @Environment(\.openWindow) var openWindow
    var body: some View {
        VStack {
            Form {
                Section {
                    HStack {
                        Text("Release name")
                        Spacer()
                        Text(Defaults[.releaseName])
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        if showBuildNumber {
                            Text("(\(Bundle.main.buildVersionNumber ?? ""))")
                                .foregroundStyle(.secondary)
                        }
                        Text(Bundle.main.releaseVersionNumber ?? "unkown")
                            .foregroundStyle(.secondary)
                    }
                    .onTapGesture {
                        withAnimation {
                            showBuildNumber.toggle()
                        }
                    }
                } header: {
                    Text("Version info")
                }

                UpdaterSettingsView(updater: updaterController.updater)

                HStack(spacing: 30) {
                    Spacer(minLength: 0)
                    Button {
                        if let url = URL(string: "https://github.com/mukhammadxuja/dino") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Image("Github")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 18)
                            Text("GitHub")
                        }
                        .contentShape(Rectangle())
                    }
                    Spacer(minLength: 0)
                }
                .buttonStyle(PlainButtonStyle())
            }
            VStack(spacing: 0) {
                Divider()
                Text("Enjoy!")
                    .foregroundStyle(.secondary)
                    .padding(.top, 5)
                    .padding(.bottom, 7)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .toolbar {
            //            Button("Welcome window") {
            //                openWindow(id: "onboarding")
            //            }
            //            .controlSize(.extraLarge)
            CheckForUpdatesView(updater: updaterController.updater)
        }
        .navigationTitle("About")
    }
}

struct Shelf: View {
    
    @Default(.shelfTapToOpen) var shelfTapToOpen: Bool
    @Default(.quickShareProvider) var quickShareProvider
    @Default(.expandedDragDetection) var expandedDragDetection: Bool
    @StateObject private var quickShareService = QuickShareService.shared

    private var selectedProvider: QuickShareProvider? {
        quickShareService.availableProviders.first(where: { $0.id == quickShareProvider })
    }
    
    init() {
        Task { await QuickShareService.shared.discoverAvailableProviders() }
    }
    
    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .boringShelf) {
                    Text("Enable shelf")
                }
                Defaults.Toggle(key: .openShelfByDefault) {
                    Text("Open shelf by default if items are present")
                }
                Defaults.Toggle(key: .expandedDragDetection) {
                    Text("Expanded drag detection area")
                }
                .onChange(of: expandedDragDetection) {
                    NotificationCenter.default.post(
                        name: Notification.Name.expandedDragDetectionChanged,
                        object: nil
                    )
                }
                Defaults.Toggle(key: .copyOnDrag) {
                    Text("Copy items on drag")
                }
                Defaults.Toggle(key: .autoRemoveShelfItems) {
                    Text("Remove from shelf after dragging")
                }

            } header: {
                HStack {
                    Text("General")
                }
            }
            
            Section {
                Picker("Quick Share Service", selection: $quickShareProvider) {
                    ForEach(quickShareService.availableProviders, id: \.id) { provider in
                        HStack {
                            Group {
                                if let imgData = provider.imageData, let nsImg = NSImage(data: imgData) {
                                    Image(nsImage: nsImg)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                }
                            }
                            .frame(width: 16, height: 16)
                            .foregroundColor(.accentColor)
                            Text(provider.id)
                        }
                        .tag(provider.id)
                    }
                }
                .pickerStyle(.menu)
                
                if let selectedProvider = selectedProvider {
                    HStack {
                        Group {
                            if let imgData = selectedProvider.imageData, let nsImg = NSImage(data: imgData) {
                                Image(nsImage: nsImg)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .frame(width: 16, height: 16)
                        .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Currently selected: \(selectedProvider.id)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Files dropped on the shelf will be shared via this service")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                // Providers are always enabled; user can pick default service above.
                
            } header: {
                HStack {
                    Text("Quick Share")
                }
            } footer: {
                Text("Choose which service to use when sharing files from the shelf. Click the shelf button to select files, or drag files onto it to share immediately.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Shelf")
    }
}

struct PomodoroSettings: View {
    @Default(.pomodoroEnabled) private var pomodoroEnabled
    @Default(.pomodoroNotificationsEnabled) private var pomodoroNotificationsEnabled
    @Default(.pomodoroFocusMinutes) private var pomodoroFocusMinutes
    @Default(.pomodoroShortBreakMinutes) private var pomodoroShortBreakMinutes
    @Default(.pomodoroLongBreakMinutes) private var pomodoroLongBreakMinutes
    @Default(.pomodoroAutoStartBreaks) private var pomodoroAutoStartBreaks
    @Default(.pomodoroAutoStartFocus) private var pomodoroAutoStartFocus
    @Default(.pomodoroCycleBeforeLongBreak) private var pomodoroCycleBeforeLongBreak
    @Default(.pomodoroClosedNotchDisplayMode) private var pomodoroClosedNotchDisplayMode
    @Default(.pomodoroTickSound) private var pomodoroTickSound
    @Default(.pomodoroEndSound) private var pomodoroEndSound
    @Default(.pomodoroStrictModeWallpaperPath) private var pomodoroStrictModeWallpaperPath
    @Default(.pomodoroStrictModeEyeExercisesEnabled) private var pomodoroStrictModeEyeExercisesEnabled

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .pomodoroEnabled) {
                    Text("Enable Pomodoro")
                }
            } header: {
                Text("Pomodoro Features")
            } footer: {
                Text("Enable Pomodoro widgets in the notch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Stepper(value: clampedBinding(for: $pomodoroFocusMinutes, in: 5...120), step: 1) {
                    HStack {
                        Text("Focus")
                        Spacer()
                        Text("\(pomodoroFocusMinutes) min")
                            .foregroundStyle(.secondary)
                    }
                }
                Stepper(value: clampedBinding(for: $pomodoroShortBreakMinutes, in: 1...30), step: 1) {
                    HStack {
                        Text("Short break")
                        Spacer()
                        Text("\(pomodoroShortBreakMinutes) min")
                            .foregroundStyle(.secondary)
                    }
                }
                Stepper(value: clampedBinding(for: $pomodoroLongBreakMinutes, in: 5...60), step: 1) {
                    HStack {
                        Text("Long break")
                        Spacer()
                        Text("\(pomodoroLongBreakMinutes) min")
                            .foregroundStyle(.secondary)
                    }
                }
                Stepper(value: clampedBinding(for: $pomodoroCycleBeforeLongBreak, in: 2...10), step: 1) {
                    HStack {
                        Text("Cycles before long break")
                        Spacer()
                        Text("\(pomodoroCycleBeforeLongBreak)")
                            .foregroundStyle(.secondary)
                    }
                }
                Defaults.Toggle(key: .pomodoroAutoStartBreaks) {
                    Text("Auto-start breaks")
                }
                Defaults.Toggle(key: .pomodoroAutoStartFocus) {
                    Text("Auto-start next focus")
                }
                Defaults.Toggle(key: .pomodoroNotificationsEnabled) {
                    Text("Notifications")
                }
            } header: {
                Text("Session")
            } footer: {
                Text("Shows a 1-minute warning notification before focus ends.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Defaults.Toggle(key: .pomodoroStrictModeEnabled) {
                    Text("Enable strict mode")
                }

                Defaults.Toggle(key: .pomodoroStrictModeEyeExercisesEnabled) {
                    Text("Enable eye exercise mode")
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Break wallpaper")
                        Text(strictModeWallpaperLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    Button("Upload") {
                        pickStrictModeWallpaper()
                    }
                    .buttonStyle(.bordered)

                    if pomodoroStrictModeWallpaperPath != nil {
                        Button("Reset") {
                            pomodoroStrictModeWallpaperPath = nil
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } header: {
                Text("Strict Mode")
            } footer: {
                Text("When enabled, break sessions show a full-screen lock overlay on all monitors. Skip always asks for confirmation. You can keep blur as default or set a custom wallpaper.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Closed notch behavior", selection: $pomodoroClosedNotchDisplayMode) {
                    ForEach(PomodoroClosedNotchDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Closed Notch")
            } footer: {
                Text("Choose whether Pomodoro is hidden or shown inline in the closed notch by replacing the music cover/visualizer area with countdown and controls.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Picker("Ticking", selection: $pomodoroTickSound) {
                        ForEach(PomodoroTickSound.allCases) { sound in
                            Text(sound.title).tag(sound)
                        }
                    }

                    Spacer(minLength: 8)

                    Button("Play") {
                        guard let fileName = pomodoroTickSound.fileName else { return }
                        AudioPlayer().play(fileName: fileName, fileExtension: "mp3", subdirectory: "sounds")
                    }
                    .buttonStyle(.bordered)
                    .disabled(pomodoroTickSound == .off)
                }

                HStack {
                    Picker("End", selection: $pomodoroEndSound) {
                        ForEach(PomodoroEndSound.allCases) { sound in
                            Text(sound.title).tag(sound)
                        }
                    }

                    Spacer(minLength: 8)

                    Button("Play") {
                        guard let fileName = pomodoroEndSound.fileName else { return }
                        AudioPlayer().play(fileName: fileName, fileExtension: "mp3", subdirectory: "sounds")
                    }
                    .buttonStyle(.bordered)
                    .disabled(pomodoroEndSound == .off)
                }
            } header: {
                Text("Sounds")
            } footer: {
                Text("Ticking plays during the last 5 seconds of focus/break. End sound plays when the phase completes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Pomodoro")
    }

    private func clampedBinding(for value: Binding<Int>, in range: ClosedRange<Int>) -> Binding<Int> {
        Binding(
            get: { min(max(value.wrappedValue, range.lowerBound), range.upperBound) },
            set: { value.wrappedValue = min(max($0, range.lowerBound), range.upperBound) }
        )
    }

    private var strictModeWallpaperLabel: String {
        guard let path = pomodoroStrictModeWallpaperPath, !path.isEmpty else {
            return "Default blur background"
        }

        return URL(fileURLWithPath: path).lastPathComponent
    }

    private func pickStrictModeWallpaper() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]

        if panel.runModal() == .OK, let url = panel.url {
            pomodoroStrictModeWallpaperPath = url.path
        }
    }
}

//struct Extensions: View {
//    @State private var effectTrigger: Bool = false
//    var body: some View {
//        Form {
//            Section {
//                List {
//                    ForEach(extensionManager.installedExtensions.indices, id: \.self) { index in
//                        let item = extensionManager.installedExtensions[index]
//                        HStack {
//                            AppIcon(for: item.bundleIdentifier)
//                                .resizable()
//                                .frame(width: 24, height: 24)
//                            Text(item.name)
//                            ListItemPopover {
//                                Text("Description")
//                            }
//                            Spacer(minLength: 0)
//                            HStack(spacing: 6) {
//                                Circle()
//                                    .frame(width: 6, height: 6)
//                                    .foregroundColor(
//                                        isExtensionRunning(item.bundleIdentifier)
//                                            ? .green : item.status == .disabled ? .gray : .red
//                                    )
//                                    .conditionalModifier(isExtensionRunning(item.bundleIdentifier))
//                                { view in
//                                    view
//                                        .shadow(color: .green, radius: 3)
//                                }
//                                Text(
//                                    isExtensionRunning(item.bundleIdentifier)
//                                        ? "Running"
//                                        : item.status == .disabled ? "Disabled" : "Stopped"
//                                )
//                                .contentTransition(.numericText())
//                                .foregroundStyle(.secondary)
//                                .font(.footnote)
//                            }
//                            .frame(width: 60, alignment: .leading)
//
//                            Menu(
//                                content: {
//                                    Button("Restart") {
//                                        let ws = NSWorkspace.shared
//
//                                        if let ext = ws.runningApplications.first(where: {
//                                            $0.bundleIdentifier == item.bundleIdentifier
//                                        }) {
//                                            ext.terminate()
//                                        }
//
//                                        if let appURL = ws.urlForApplication(
//                                            withBundleIdentifier: item.bundleIdentifier)
//                                        {
//                                            ws.openApplication(
//                                                at: appURL, configuration: .init(),
//                                                completionHandler: nil)
//                                        }
//                                    }
//                                    .keyboardShortcut("R", modifiers: .command)
//                                    Button("Disable") {
//                                        if let ext = NSWorkspace.shared.runningApplications.first(
//                                            where: { $0.bundleIdentifier == item.bundleIdentifier })
//                                        {
//                                            ext.terminate()
//                                        }
//                                        extensionManager.installedExtensions[index].status =
//                                            .disabled
//                                    }
//                                    .keyboardShortcut("D", modifiers: .command)
//                                    Divider()
//                                    Button("Uninstall", role: .destructive) {
//                                        //
//                                    }
//                                },
//                                label: {
//                                    Image(systemName: "ellipsis.circle")
//                                        .foregroundStyle(.secondary)
//                                }
//                            )
//                            .controlSize(.regular)
//                        }
//                        .buttonStyle(PlainButtonStyle())
//                        .padding(.vertical, 5)
//                    }
//                }
//                .frame(minHeight: 120)
//                .actionBar {
//                    Button {
//                    } label: {
//                        HStack(spacing: 3) {
//                            Image(systemName: "plus")
//                            Text("Add manually")
//                        }
//                        .foregroundStyle(.secondary)
//                    }
//                    .disabled(true)
//                    Spacer()
//                    Button {
//                        withAnimation(.linear(duration: 1)) {
//                            effectTrigger.toggle()
//                        } completion: {
//                            effectTrigger.toggle()
//                        }
//                        extensionManager.checkIfExtensionsAreInstalled()
//                    } label: {
//                        HStack(spacing: 3) {
//                            Image(systemName: "arrow.triangle.2.circlepath")
//                                .rotationEffect(effectTrigger ? .degrees(360) : .zero)
//                        }
//                        .foregroundStyle(.secondary)
//                    }
//                }
//                .controlSize(.small)
//                .buttonStyle(PlainButtonStyle())
//                .overlay {
//                    if extensionManager.installedExtensions.isEmpty {
//                        Text("No extension installed")
//                            .foregroundStyle(Color(.secondaryLabelColor))
//                            .padding(.bottom, 22)
//                    }
//                }
//            } header: {
//                HStack(spacing: 0) {
//                    Text("Installed extensions")
//                    if !extensionManager.installedExtensions.isEmpty {
//                        Text(" – \(extensionManager.installedExtensions.count)")
//                            .foregroundStyle(.secondary)
//                    }
//                }
//            }
//        }
//        .accentColor(.effectiveAccent)
//        .navigationTitle("Extensions")
//        // TipsView()
//        // .padding(.horizontal, 19)
//    }
//}

// MARK: - Custom Stepped Hover Delay Slider
struct HoverDelaySlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "hare.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            GeometryReader { geo in
                let width = geo.size.width
                let clamped = min(max(value, range.lowerBound), range.upperBound)
                let pct = CGFloat((clamped - range.lowerBound) / (range.upperBound - range.lowerBound))
                let knobX = pct * max(1, width - 16)

                ZStack(alignment: .leading) {
                    // Base background track
                    Capsule()
                        .fill(Color.primary.opacity(0.12))
                        .frame(height: 4)

                    // Active filled track
                    Capsule()
                        .fill(Color.effectiveAccent)
                        .frame(width: max(0, knobX + 8), height: 4)

                    // Tick dots
                    HStack {
                        ForEach(0..<4, id: \.self) { _ in
                            Circle()
                                .fill(Color.white.opacity(0.8))
                                .frame(width: 3.5, height: 3.5)
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 6)

                    // Draggable White Knob
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: Color.black.opacity(0.2), radius: 2.5, y: 1)
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                        )
                        .offset(x: knobX)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let fraction = max(0, min(1, gesture.location.x / width))
                            let raw = range.lowerBound + Double(fraction) * (range.upperBound - range.lowerBound)
                            let stepped = (raw / step).rounded() * step
                            value = min(max(stepped, range.lowerBound), range.upperBound)
                        }
                )
            }
            .frame(width: 130, height: 20)

            Image(systemName: "tortoise.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            Text(String(format: "%.1fs", value).replacingOccurrences(of: ".", with: ","))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 36, alignment: .trailing)
        }
    }
}

struct Appearance: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    
    // Displays & Island Settings
    @Default(.displaySelection) var displaySelection
    @Default(.builtinFormFactor) var builtinFormFactor
    @Default(.externalFormFactor) var externalFormFactor
    @Default(.islandStyle) var islandStyle
    @Default(.islandVisibility) var islandVisibility
    @Default(.displayShowOn) var displayShowOn
    
    // Hover & Interaction
    @Default(.openNotchOnHover) var openNotchOnHover
    @Default(.minimumHoverDuration) var minimumHoverDuration
    @Default(.collapseDelay) var collapseDelay
    @Default(.enableHaptics) var enableHaptics
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // MARK: - 1. Hover Section (Redesigned UI)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hover")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)

                    VStack(spacing: 0) {
                        // Row 1: Expand on hover
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Expand on hover")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("Open the expanded view without clicking")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $openNotchOnHover)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .tint(Color.effectiveAccent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        Divider()
                            .padding(.horizontal, 16)

                        // Row 2: Expand delay
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Expand delay")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("Hover time\nbefore expanding")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            HoverDelaySlider(value: $minimumHoverDuration, range: 0.1...1.0, step: 0.05)
                                .opacity(openNotchOnHover ? 1.0 : 0.45)
                                .disabled(!openNotchOnHover)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        Divider()
                            .padding(.horizontal, 16)

                        // Row 3: Collapse delay
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Collapse delay")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("After the pointer leaves")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            HoverDelaySlider(value: $collapseDelay, range: 0.1...1.0, step: 0.05)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        Divider()
                            .padding(.horizontal, 16)

                        // Row 4: Haptic feedback on hover
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Haptic feedback on hover")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("Vibrate trackpad when pointer touches notch or island")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $enableHaptics)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .tint(Color.effectiveAccent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.75))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
                
                // MARK: - 2. Displays Top Selector
                VStack(alignment: .leading, spacing: 10) {
                    Text("Displays")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)

                    HStack(spacing: 12) {
                        ForEach(DisplaySelection.allCases) { type in
                            DisplaySelectionCard(type: type, selection: $displaySelection)
                        }
                    }
                }

                // MARK: - 3. Dynamic Configuration Based on Selection
                if displaySelection == .builtin {
                    // BUILT-IN DISPLAY SETTINGS
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            FormFactorCard(factor: .notch, selection: $builtinFormFactor)
                            FormFactorCard(factor: .island, selection: $builtinFormFactor)
                        }

                        if builtinFormFactor == .island {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Island")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.primary)
                                    .padding(.top, 4)

                                Text("Style")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)

                                HStack(spacing: 12) {
                                    IslandStyleCard(style: .dark, selection: $islandStyle)
                                    IslandStyleCard(style: .glass, selection: $islandStyle)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        Text("Visibility")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)

                        HStack(spacing: 8) {
                            IslandVisibilityCard(visibility: .onHover, selection: $islandVisibility)
                            IslandVisibilityCard(visibility: .onClick, selection: $islandVisibility)
                            if builtinFormFactor == .island {
                                IslandVisibilityCard(visibility: .alwaysVisible, selection: $islandVisibility)
                            }
                        }
                    }
                } else if displaySelection == .external {
                    // EXTERNAL DISPLAY SETTINGS
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            FormFactorCard(factor: .notch, selection: $externalFormFactor)
                            FormFactorCard(factor: .island, selection: $externalFormFactor)
                        }

                        if externalFormFactor == .island {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Island")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.primary)

                                Text("Style")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)

                                HStack(spacing: 12) {
                                    IslandStyleCard(style: .dark, selection: $islandStyle)
                                    IslandStyleCard(style: .glass, selection: $islandStyle)
                                }

                                if displaySelection == .external {
                                    Text("Visibility")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)

                                    HStack(spacing: 8) {
                                        IslandVisibilityCard(visibility: .onHover, selection: $islandVisibility)
                                        IslandVisibilityCard(visibility: .onClick, selection: $islandVisibility)
                                        IslandVisibilityCard(visibility: .alwaysVisible, selection: $islandVisibility)
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Show On Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Show on")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)

                            HStack(spacing: 12) {
                                ForEach(DisplayShowOn.allCases) { target in
                                    DisplayShowOnCard(target: target, selection: $displayShowOn)
                                }
                            }

                            Text(displayShowOn.subtitle)
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                    }
                } else {
                    // BOTH DISPLAYS SETTINGS
                    VStack(alignment: .leading, spacing: 16) {
                        // Built-in group
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "laptopcomputer")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Text("Built-in")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)
                            }

                            HStack(spacing: 12) {
                                FormFactorCard(factor: .notch, selection: $builtinFormFactor)
                                FormFactorCard(factor: .island, selection: $builtinFormFactor)
                            }
                        }

                        // External group
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "display")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Text("External")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)
                            }

                            HStack(spacing: 12) {
                                FormFactorCard(factor: .notch, selection: $externalFormFactor)
                                FormFactorCard(factor: .island, selection: $externalFormFactor)
                            }
                        }

                        // Island Sub-options if either uses Island
                        if builtinFormFactor == .island || externalFormFactor == .island {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Island")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.primary)

                                Text("Style")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)

                                HStack(spacing: 12) {
                                    IslandStyleCard(style: .dark, selection: $islandStyle)
                                    IslandStyleCard(style: .glass, selection: $islandStyle)
                                }

                                if externalFormFactor == .island {
                                    Text("Visibility")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)

                                    HStack(spacing: 8) {
                                        IslandVisibilityCard(visibility: .onHover, selection: $islandVisibility)
                                        IslandVisibilityCard(visibility: .onClick, selection: $islandVisibility)
                                        IslandVisibilityCard(visibility: .alwaysVisible, selection: $islandVisibility)
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Show On Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Show on")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)

                            HStack(spacing: 12) {
                                ForEach(DisplayShowOn.allCases) { target in
                                    DisplayShowOnCard(target: target, selection: $displayShowOn)
                                }
                            }

                            Text(displayShowOn.subtitle)
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                    }
                }
                
                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .navigationTitle("Appearance")
        .onChange(of: displaySelection) {
            NotificationCenter.default.post(name: .displaySettingsChanged, object: nil)
        }
        .onChange(of: builtinFormFactor) {
            NotificationCenter.default.post(name: .formFactorChanged, object: nil)
        }
        .onChange(of: externalFormFactor) {
            NotificationCenter.default.post(name: .formFactorChanged, object: nil)
        }
        .onChange(of: islandVisibility) {
            NotificationCenter.default.post(name: .displaySettingsChanged, object: nil)
        }
        .onChange(of: displayShowOn) {
            NotificationCenter.default.post(name: .displaySettingsChanged, object: nil)
        }
    }
}

struct Advanced: View {
    @Default(.useCustomAccentColor) var useCustomAccentColor
    @Default(.customAccentColorData) var customAccentColorData
    @Default(.extendHoverArea) var extendHoverArea
    @Default(.hideFromScreenRecording) var hideFromScreenRecording
    
    @State private var customAccentColor: Color = .accentColor
    @State private var selectedPresetColor: PresetAccentColor? = nil
    let icons: [String] = ["logo2"]
    @State private var selectedIcon: String = "logo2"
    
    // macOS accent colors
    enum PresetAccentColor: String, CaseIterable, Identifiable {
        case blue = "Blue"
        case purple = "Purple"
        case pink = "Pink"
        case red = "Red"
        case orange = "Orange"
        case yellow = "Yellow"
        case green = "Green"
        case graphite = "Graphite"
        
        var id: String { self.rawValue }
        
        var color: Color {
            switch self {
            case .blue: return Color(red: 0.0, green: 0.478, blue: 1.0)
            case .purple: return Color(red: 0.686, green: 0.322, blue: 0.871)
            case .pink: return Color(red: 1.0, green: 0.176, blue: 0.333)
            case .red: return Color(red: 1.0, green: 0.271, blue: 0.227)
            case .orange: return Color(red: 1.0, green: 0.584, blue: 0.0)
            case .yellow: return Color(red: 1.0, green: 0.8, blue: 0.0)
            case .green: return Color(red: 0.4, green: 0.824, blue: 0.176)
            case .graphite: return Color(red: 0.557, green: 0.557, blue: 0.576)
            }
        }
    }
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Toggle between system and custom
                    Picker("Accent color", selection: $useCustomAccentColor) {
                        Text("System").tag(false)
                        Text("Custom").tag(true)
                    }
                    .pickerStyle(.segmented)
                    
                    if !useCustomAccentColor {
                        // System accent info
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                AccentCircleButton(
                                    isSelected: true,
                                    color: .accentColor,
                                    isSystemDefault: true
                                ) {}
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Using System Accent")
                                        .font(.body)
                                    Text("Your macOS system accent color")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    } else {
                        // Custom color options
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Color Presets")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 12) {
                                ForEach(PresetAccentColor.allCases) { preset in
                                    AccentCircleButton(
                                        isSelected: selectedPresetColor == preset,
                                        color: preset.color,
                                        isMulticolor: false
                                    ) {
                                        selectedPresetColor = preset
                                        customAccentColor = preset.color
                                        saveCustomColor(preset.color)
                                        forceUiUpdate()
                                    }
                                }
                                Spacer()
                            }
                            
                            Divider()
                                .padding(.vertical, 4)
                            
                            // Custom color picker
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Pick a Color")
                                        .font(.body)
                                    Text("Choose any color")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                ColorPicker(selection: Binding(
                                    get: { customAccentColor },
                                    set: { newColor in
                                        customAccentColor = newColor
                                        selectedPresetColor = nil
                                        saveCustomColor(newColor)
                                        forceUiUpdate()
                                    }
                                ), supportsOpacity: false) {
                                    ZStack {
                                        Circle()
                                            .fill(customAccentColor)
                                            .frame(width: 32, height: 32)
                                        
                                        if selectedPresetColor == nil {
                                            Circle()
                                                .strokeBorder(.primary.opacity(0.3), lineWidth: 2)
                                                .frame(width: 32, height: 32)
                                        }
                                    }
                                }
                                .labelsHidden()
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Accent color")
            } footer: {
                Text("Choose between your system accent color or customize it with your own selection.")
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .onAppear {
                initializeAccentColorState()
            }
            
            Section {
                Defaults.Toggle(key: .enableShadow) {
                    Text("Enable window shadow")
                }
                Defaults.Toggle(key: .cornerRadiusScaling) {
                    Text("Corner radius scaling")
                }
            } header: {
                Text("Window Appearance")
            }
            
            Section {
                HStack {
                    ForEach(icons, id: \.self) { icon in
                        Spacer()
                        VStack {
                            Image(icon)
                                .resizable()
                                .frame(width: 80, height: 80)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .circular)
                                        .strokeBorder(
                                            icon == selectedIcon ? Color.effectiveAccent : .clear,
                                            lineWidth: 2.5
                                        )
                                )

                            Text("Default")
                                .fontWeight(.medium)
                                .font(.caption)
                                .foregroundStyle(icon == selectedIcon ? .white : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(icon == selectedIcon ? Color.effectiveAccent : .clear)
                                )
                        }
                        .onTapGesture {
                            withAnimation {
                                selectedIcon = icon
                            }
                            NSApp.applicationIconImage = NSImage(named: icon)
                        }
                        Spacer()
                    }
                }
                .disabled(true)
            } header: {
                HStack {
                    Text("App icon")
                    customBadge(text: "Coming soon")
                }
            }
            
            Section {
                Defaults.Toggle(key: .extendHoverArea) {
                    Text("Extend hover area")
                }
                Defaults.Toggle(key: .hideTitleBar) {
                    Text("Hide title bar")
                }
                Defaults.Toggle(key: .hideFromScreenRecording) {
                    Text("Hide from screen recording")
                }
            } header: {
                Text("Window Behavior")
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Advanced")
        .onAppear {
            loadCustomColor()
        }
    }
    
    private func forceUiUpdate() {
        // Force refresh the UI
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("AccentColorChanged"), object: nil)
        }
    }
    
    private func saveCustomColor(_ color: Color) {
        let nsColor = NSColor(color)
        if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: nsColor, requiringSecureCoding: false) {
            Defaults[.customAccentColorData] = colorData
            forceUiUpdate()
        }
    }
    
    private func loadCustomColor() {
        if let colorData = Defaults[.customAccentColorData],
           let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            customAccentColor = Color(nsColor: nsColor)
            
            // Check if loaded color matches a preset
            selectedPresetColor = nil
            for preset in PresetAccentColor.allCases {
                if colorsAreEqual(Color(nsColor: nsColor), preset.color) {
                    selectedPresetColor = preset
                    break
                }
            }
        }
    }
    
    private func colorsAreEqual(_ color1: Color, _ color2: Color) -> Bool {
        let nsColor1 = NSColor(color1).usingColorSpace(.sRGB) ?? NSColor(color1)
        let nsColor2 = NSColor(color2).usingColorSpace(.sRGB) ?? NSColor(color2)
        
        return abs(nsColor1.redComponent - nsColor2.redComponent) < 0.01 &&
               abs(nsColor1.greenComponent - nsColor2.greenComponent) < 0.01 &&
               abs(nsColor1.blueComponent - nsColor2.blueComponent) < 0.01
    }
    
    private func initializeAccentColorState() {
        if !useCustomAccentColor {
            selectedPresetColor = nil // Multicolor is selected when useCustomAccentColor is false
        } else {
            loadCustomColor()
        }
    }
}

// MARK: - Accent Circle Button Component
struct AccentCircleButton: View {
    let isSelected: Bool
    let color: Color
    var isSystemDefault: Bool = false
    var isMulticolor: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Color circle
                Circle()
                    .fill(color)
                    .frame(width: 32, height: 32)
                
                // Subtle border
                Circle()
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    .frame(width: 32, height: 32)
                
                // Apple-style highlight ring around the middle when selected
                if isSelected {
                    Circle()
                        .strokeBorder(
                            Color.white.opacity(0.5),
                            lineWidth: 2
                        )
                        .frame(width: 28, height: 28)
                }
            }
        }
        .buttonStyle(.plain)
        .help(isSystemDefault ? "Use your macOS system accent color" : "")
    }
}

struct Shortcuts: View {
    var body: some View {
        Form {
            Section {
                DinoShortcutRow("Toggle Sneak Peek:", name: .toggleSneakPeek)
            } header: {
                Text("Media")
            } footer: {
                Text(
                    "Sneak Peek shows the media title and artist under the notch for a few seconds."
                )
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .font(.caption)
            }
            Section {
                DinoShortcutRow("Now Playing (Music):", name: .selectMusicModule)
                DinoShortcutRow("Pomodoro Timer:", name: .selectPomodoroModule)
                DinoShortcutRow("Calendar:", name: .selectCalendarModule)
                DinoShortcutRow("Battery Status:", name: .selectBatteryModule)
                DinoShortcutRow("Shelf (Upload):", name: .selectShelfModule)
            } header: {
                Text("Switch Active Module")
            } footer: {
                Text("Quickly switch what is shown in your Notch / Island using keyboard shortcuts.")
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section {
                DinoShortcutRow("Clipboard History (HUD):", name: .clipboardHistoryPanel)
                DinoShortcutRow("Toggle Notch Open:", name: .toggleNotchOpen)
            } header: {
                Text("Floating HUDs & Overlays")
            }
            Section {
                DinoShortcutRow("Pomodoro Skip Break:", name: .pomodoroEmergencyExit)
            } header: {
                Text("Pomodoro")
            } footer: {
                Text("Use this shortcut to skip the current break.")
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Shortcuts")
    }
}

func proFeatureBadge() -> some View {
    Text("Upgrade to Pro")
        .foregroundStyle(Color(red: 0.545, green: 0.196, blue: 0.98))
        .font(.footnote.bold())
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 4).stroke(
                Color(red: 0.545, green: 0.196, blue: 0.98), lineWidth: 1))
}

func comingSoonTag() -> some View {
    Text("Coming soon")
        .foregroundStyle(.secondary)
        .font(.footnote.bold())
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(Color(nsColor: .secondarySystemFill))
        .clipShape(.capsule)
}

func customBadge(text: String) -> some View {
    Text(text)
        .foregroundStyle(.secondary)
        .font(.footnote.bold())
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(Color(nsColor: .secondarySystemFill))
        .clipShape(.capsule)
}

func warningBadge(_ text: String, _ description: String) -> some View {
    Section {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.yellow)
            VStack(alignment: .leading) {
                Text(text)
                    .font(.headline)
                Text(description)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
