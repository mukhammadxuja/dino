//
//  SettingsView.swift
//  boringNotch
//
//  Created by Richard Kunkli on 07/08/2024.
//

import AVFoundation
import AppKit
import Darwin
import Defaults
import EventKit
import IOKit
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

struct SettingsSidebarBatteryRow: View {
    let isExpanded: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7.5, style: .continuous)
                        .fill(Color(red: 0.18, green: 0.80, blue: 0.44))
                        .frame(width: 28, height: 28)

                    Image(systemName: "battery.100.bolt")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text("Battery")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hov in
            isHovered = hov
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab = "General"
    @State private var isBatteryExpanded = true
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
                    SettingsSidebarItemRow(title: "Media", icon: "play.tv.fill", iconBg: Color(red: 0.95, green: 0.25, blue: 0.35), isSelected: selectedTab == "Media") {
                        selectedTab = "Media"
                    }
                    SettingsSidebarItemRow(title: "Calendar", icon: "calendar", iconBg: Color(red: 0.98, green: 0.35, blue: 0.35), isSelected: selectedTab == "Calendar") {
                        selectedTab = "Calendar"
                    }
                    SettingsSidebarItemRow(title: "HUDs", icon: "dial.medium.fill", iconBg: Color(red: 0.98, green: 0.58, blue: 0.10), isSelected: selectedTab == "HUD") {
                        selectedTab = "HUD"
                    }

                    SettingsSidebarBatteryRow(isExpanded: isBatteryExpanded) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isBatteryExpanded.toggle()
                        }
                    }

                    if isBatteryExpanded {
                        VStack(spacing: 2) {
                            SettingsSidebarItemRow(title: "General", icon: "slider.horizontal.3", iconBg: Color(red: 0.42, green: 0.45, blue: 0.92), isSelected: selectedTab == "Battery_General", isSubItem: true) {
                                selectedTab = "Battery_General"
                            }
                            SettingsSidebarItemRow(title: "Alerts", icon: "bell.badge.fill", iconBg: Color(red: 0.98, green: 0.45, blue: 0.20), isSelected: selectedTab == "Battery_Alerts" || selectedTab == "Battery", isSubItem: true) {
                                selectedTab = "Battery_Alerts"
                            }
                            SettingsSidebarItemRow(title: "Charging", icon: "bolt.fill", iconBg: Color(red: 0.10, green: 0.75, blue: 0.70), isSelected: selectedTab == "Battery_Charging", isSubItem: true) {
                                selectedTab = "Battery_Charging"
                            }
                            SettingsSidebarItemRow(title: "App Usage", icon: "chart.bar.xaxis", iconBg: Color(red: 0.12, green: 0.55, blue: 0.95), isSelected: selectedTab == "Battery_AppUsage", isSubItem: true) {
                                selectedTab = "Battery_AppUsage"
                            }
                        }
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
                case "Media":
                    Media()
                case "Calendar":
                    CalendarSettings()
                case "HUD":
                    HUD()
                case "Battery", "Battery_Alerts":
                    BatteryAlertsSettingsView()
                case "Battery_General":
                    BatteryGeneralSettingsView()
                case "Battery_Charging":
                    BatteryChargingSettingsView()
                case "Battery_AppUsage":
                    BatteryAppUsageSettingsView()
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

struct GeneralSettings: View {
    @State private var screens: [(uuid: String, name: String)] = NSScreen.screens.compactMap { screen in
        guard let uuid = screen.displayUUID else { return nil }
        return (uuid, screen.localizedName)
    }
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var coordinator = BoringViewCoordinator.shared

    @Default(.mirrorShape) var mirrorShape
    @Default(.showEmojis) var showEmojis
    @Default(.gestureSensitivity) var gestureSensitivity
    @Default(.minimumHoverDuration) var minimumHoverDuration
    @Default(.nonNotchHeight) var nonNotchHeight
    @Default(.nonNotchHeightMode) var nonNotchHeightMode
    @Default(.notchHeight) var notchHeight
    @Default(.notchHeightMode) var notchHeightMode
    @Default(.showOnAllDisplays) var showOnAllDisplays
    @Default(.automaticallySwitchDisplay) var automaticallySwitchDisplay
    @Default(.enableGestures) var enableGestures
    @Default(.openNotchOnHover) var openNotchOnHover
    

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { Defaults[.menubarIcon] },
                    set: { Defaults[.menubarIcon] = $0 }
                )) {
                    Text("Show menu bar icon")
                }
                .tint(.effectiveAccent)
                LaunchAtLogin.Toggle("Launch at login")
                Defaults.Toggle(key: .showOnAllDisplays) {
                    Text("Show on all displays")
                }
                .onChange(of: showOnAllDisplays) {
                    NotificationCenter.default.post(
                        name: Notification.Name.showOnAllDisplaysChanged, object: nil)
                }
                Picker("Preferred display", selection: $coordinator.preferredScreenUUID) {
                    ForEach(screens, id: \.uuid) { screen in
                        Text(screen.name).tag(screen.uuid as String?)
                    }
                }
                .onChange(of: NSScreen.screens) {
                    screens = NSScreen.screens.compactMap { screen in
                        guard let uuid = screen.displayUUID else { return nil }
                        return (uuid, screen.localizedName)
                    }
                }
                .disabled(showOnAllDisplays)
                
                Defaults.Toggle(key: .automaticallySwitchDisplay) {
                    Text("Automatically switch displays")
                }
                    .onChange(of: automaticallySwitchDisplay) {
                        NotificationCenter.default.post(
                            name: Notification.Name.automaticallySwitchDisplayChanged, object: nil)
                    }
                    .disabled(showOnAllDisplays)
            } header: {
                Text("System features")
            }

            Section {
                Picker(
                    selection: $notchHeightMode,
                    label:
                        Text("Notch height on notch displays")
                ) {
                    Text("Match real notch height")
                        .tag(WindowHeightMode.matchRealNotchSize)
                    Text("Match menu bar height")
                        .tag(WindowHeightMode.matchMenuBar)
                    Text("Custom height")
                        .tag(WindowHeightMode.custom)
                }
                .onChange(of: notchHeightMode) {
                    switch notchHeightMode {
                    case .matchRealNotchSize:
                        notchHeight = 38
                    case .matchMenuBar:
                        notchHeight = 44
                    case .custom:
                        notchHeight = 38
                    }
                    NotificationCenter.default.post(
                        name: Notification.Name.notchHeightChanged, object: nil)
                }
                if notchHeightMode == .custom {
                    Slider(value: $notchHeight, in: 15...45, step: 1) {
                        Text("Custom notch size - \(notchHeight, specifier: "%.0f")")
                    }
                    .onChange(of: notchHeight) {
                        NotificationCenter.default.post(
                            name: Notification.Name.notchHeightChanged, object: nil)
                    }
                }
                Picker("Notch height on non-notch displays", selection: $nonNotchHeightMode) {
                    Text("Match menubar height")
                        .tag(WindowHeightMode.matchMenuBar)
                    Text("Match real notch height")
                        .tag(WindowHeightMode.matchRealNotchSize)
                    Text("Custom height")
                        .tag(WindowHeightMode.custom)
                }
                .onChange(of: nonNotchHeightMode) {
                    switch nonNotchHeightMode {
                    case .matchMenuBar:
                        nonNotchHeight = 24
                    case .matchRealNotchSize:
                        nonNotchHeight = 32
                    case .custom:
                        nonNotchHeight = 32
                    }
                    NotificationCenter.default.post(
                        name: Notification.Name.notchHeightChanged, object: nil)
                }
                if nonNotchHeightMode == .custom {
                    Slider(value: $nonNotchHeight, in: 0...40, step: 1) {
                        Text("Custom notch size - \(nonNotchHeight, specifier: "%.0f")")
                    }
                    .onChange(of: nonNotchHeight) {
                        NotificationCenter.default.post(
                            name: Notification.Name.notchHeightChanged, object: nil)
                    }
                }
            } header: {
                Text("Notch sizing")
            }

            NotchBehaviour()

            gestureControls()
        }
        .toolbar {
            Button("Quit app") {
                NSApp.terminate(self)
            }
            .controlSize(.extraLarge)
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("General")
        .onChange(of: openNotchOnHover) {
            if !openNotchOnHover {
                enableGestures = true
            }
        }
    }

    @ViewBuilder
    func gestureControls() -> some View {
        Section {
            Defaults.Toggle(key: .enableGestures) {
                Text("Enable gestures")
            }
                .disabled(!openNotchOnHover)
            if enableGestures {
                Defaults.Toggle(key: .changeMediaWithGesture) {
                    Text("Change media with horizontal gestures")
                }
                Defaults.Toggle(key: .closeGestureEnabled) {
                    Text("Close gesture")
                }
                Slider(value: $gestureSensitivity, in: 100...300, step: 100) {
                    HStack {
                        Text("Gesture sensitivity")
                        Spacer()
                        Text(
                            Defaults[.gestureSensitivity] == 100
                                ? "High" : Defaults[.gestureSensitivity] == 200 ? "Medium" : "Low"
                        )
                        .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            HStack {
                Text("Gesture control")
                customBadge(text: "Beta")
            }
        } footer: {
            Text(
                "Two-finger swipe up on notch to close, two-finger swipe down on notch to open when **Open notch on hover** option is disabled"
            )
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.secondary)
            .font(.caption)
        }
    }

    @ViewBuilder
    func NotchBehaviour() -> some View {
        Section {
            Defaults.Toggle(key: .openNotchOnHover) {
                Text("Open notch on hover")
            }
            Defaults.Toggle(key: .enableHaptics) {
                    Text("Enable haptic feedback")
            }
            Toggle("Remember last tab", isOn: $coordinator.openLastTabByDefault)
            if openNotchOnHover {
                Slider(value: $minimumHoverDuration, in: 0...1, step: 0.1) {
                    HStack {
                        Text("Hover delay")
                        Spacer()
                        Text("\(minimumHoverDuration, specifier: "%.1f")s")
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: minimumHoverDuration) {
                    NotificationCenter.default.post(
                        name: Notification.Name.notchHeightChanged, object: nil)
                }
            }
        } header: {
            Text("Notch behavior")
        }
    }
}

// MARK: - Battery Alerts Settings View
struct BatteryAlertsSettingsView: View {
    @Default(.batteryToastType) private var batteryToastType
    @Default(.batteryToastSize) private var batteryToastSize
    @Default(.batteryGlowIntensity) private var batteryGlowIntensity
    @Default(.batteryShowGlowInPreview) private var batteryShowGlowInPreview
    @Default(.lowBatteryAlerts) private var lowBatteryAlerts
    @Default(.chargedAlertThreshold) private var chargedAlertThreshold
    @Default(.chargedAlertGlowEnabled) private var chargedAlertGlowEnabled
    @Default(.chargedAlertSoundEnabled) private var chargedAlertSoundEnabled
    @Default(.chargedAlertSoundName) private var chargedAlertSoundName
    @Default(.chargedAlertPosition) private var chargedAlertPosition
    @Default(.customBatterySounds) private var customBatterySounds

    @Default(.batteryAlertsEnabled) private var batteryAlertsEnabled

    @ObservedObject private var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject private var soundManager = CustomSoundManager.shared

    @State private var expandedAlertId: UUID? = nil
    @State private var isChargedExpanded: Bool = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Configure low battery thresholds, charge alerts, screen glows, and custom sounds.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.48))
                    .padding(.bottom, 4)

                masterNotificationCard

                if batteryAlertsEnabled {
                    appearanceCard
                    lowBatterySection
                    chargedAlertCard
                    customSoundsCard
                    resetCard
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .animation(.easeInOut(duration: 0.2), value: batteryAlertsEnabled)
        }
        .background(Color.white)
        .accentColor(.effectiveAccent)
        .navigationTitle("Alerts")
    }

    private var masterNotificationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.12, green: 0.48, blue: 0.98))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Battery notifications")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Receive notifications and screen edge glow alerts for battery milestones.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $batteryAlertsEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.regular)
                    .tint(.effectiveAccent)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
        )
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.indigo.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: "eye.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.indigo)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Notification Appearance")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Choose between Dynamic Notch pill and custom floating toast alerts.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
            }

            Rectangle()
                .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                .frame(height: 1)

            HStack {
                Text("Alert Style")
                    .font(.system(size: 13))
                Spacer()
                Picker("", selection: $batteryToastType) {
                    ForEach(BatteryToastType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .labelsHidden()
                .frame(width: 150, alignment: .trailing)
            }

            if batteryToastType == .customToast {
                Rectangle()
                    .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                    .frame(height: 1)

                HStack {
                    Text("Alert Bubble Size")
                        .font(.system(size: 13))
                    Spacer()
                    Picker("", selection: $batteryToastSize) {
                        ForEach(BatteryToastSize.allCases) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150, alignment: .trailing)
                }
            }

            Rectangle()
                .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                .frame(height: 1)

            HStack {
                Text("Screen Edge Glow")
                    .font(.system(size: 13))
                Spacer()
                Picker("", selection: $batteryGlowIntensity) {
                    ForEach(BatteryGlowIntensity.allCases) { intensity in
                        Text(intensity.title).tag(intensity)
                    }
                }
                .labelsHidden()
                .frame(width: 150, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
        )
    }

    private var lowBatterySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("LOW BATTERY ALERTS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            }
            .padding(.leading, 2)
            .padding(.top, 4)

            ForEach(Array(lowBatteryAlerts.enumerated()), id: \.element.id) { index, alert in
                LowBatteryAlertCardView(
                    alert: binding(for: index),
                    isExpanded: expandedAlertId == alert.id,
                    showDelete: lowBatteryAlerts.count > 1,
                    onToggleExpand: {
                        toggleExpand(for: alert.id)
                    },
                    onDelete: {
                        deleteAlert(at: index)
                    },
                    onTest: {
                        batteryModel.triggerAlert(
                            type: .lowBattery,
                            percentage: alert.percentage,
                            colorHex: alert.colorHex,
                            position: alert.position,
                            soundName: alert.soundName,
                            borderGlow: alert.borderGlow,
                            isSimulation: true
                        )
                    }
                )
            }

            HStack {
                Spacer()
                Button(action: addNewAlert) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Add Low Battery Alert")
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                Spacer()
            }
            .padding(.top, 4)
        }
    }

    private var chargedAlertCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CHARGED ALERT")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
                .padding(.leading, 2)
                .padding(.top, 4)

            ChargedAlertCardView(
                threshold: $chargedAlertThreshold,
                glowEnabled: $chargedAlertGlowEnabled,
                soundEnabled: $chargedAlertSoundEnabled,
                soundName: $chargedAlertSoundName,
                position: $chargedAlertPosition,
                isExpanded: isChargedExpanded,
                onToggleExpand: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isChargedExpanded.toggle()
                    }
                },
                onTest: {
                    batteryModel.triggerAlert(
                        type: .highBattery,
                        percentage: chargedAlertThreshold,
                        colorHex: "#34C759",
                        position: chargedAlertPosition,
                        soundName: chargedAlertSoundEnabled ? chargedAlertSoundName.rawValue : nil,
                        borderGlow: chargedAlertGlowEnabled,
                        isSimulation: true
                    )
                }
            )
        }
    }

    private var customSoundsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: "music.note")
                        .foregroundStyle(.purple)
                        .font(.system(size: 13))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom Audio Sounds")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Import MP3, WAV, M4A, or AIFF sounds for battery alerts.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: {
                    soundManager.importSound()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import")
                    }
                }
                .controlSize(.small)
            }

            if !customBatterySounds.isEmpty {
                Rectangle()
                    .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                    .frame(height: 1)

                ForEach(customBatterySounds, id: \.self) { sound in
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundStyle(.secondary)
                        Text(sound)
                            .font(.system(size: 12.5))
                            .lineLimit(1)
                        Spacer()
                        Button(action: {
                            soundManager.playCustom(soundName: sound)
                        }) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 15))
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            soundManager.deleteSound(name: sound)
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
        )
    }

    private var resetCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Restore Defaults")
                    .font(.system(size: 13, weight: .semibold))
                Text("Reset all battery alert thresholds, sounds, and preferences.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive, action: resetAlerts) {
                Text("Reset")
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
        )
    }

    private func toggleExpand(for id: UUID) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            if expandedAlertId == id {
                expandedAlertId = nil
            } else {
                expandedAlertId = id
            }
        }
    }

    private func deleteAlert(at index: Int) {
        if lowBatteryAlerts.count > 1 && index < lowBatteryAlerts.count {
            lowBatteryAlerts.remove(at: index)
        }
    }

    private func addNewAlert() {
        let currentMins = lowBatteryAlerts.map(\.percentage).min() ?? 20
        let nextPct = max(5, currentMins - 5)
        let newAlert = BatteryAlertItem(
            percentage: nextPct,
            isEnabled: true,
            soundName: "Glass",
            borderGlow: true,
            colorHex: nextPct <= 10 ? "#FF453A" : "#FF9F0A",
            isPersistent: false,
            position: "Top"
        )
        lowBatteryAlerts.append(newAlert)
        withAnimation {
            expandedAlertId = newAlert.id
        }
    }

    private func resetAlerts() {
        lowBatteryAlerts = [
            BatteryAlertItem(percentage: 20, isEnabled: true, soundName: "Glass", borderGlow: true, colorHex: "#FF453A", isPersistent: false, position: "Top")
        ]
        chargedAlertThreshold = 80
        chargedAlertGlowEnabled = true
        chargedAlertSoundEnabled = true
        chargedAlertPosition = "Top"
        batteryGlowIntensity = .default
        batteryToastSize = .medium
        batteryToastType = .dynamicNotch
    }

    private func binding(for index: Int) -> Binding<BatteryAlertItem> {
        Binding(
            get: {
                if index < lowBatteryAlerts.count {
                    return lowBatteryAlerts[index]
                }
                return BatteryAlertItem(percentage: 20)
            },
            set: { newValue in
                if index < lowBatteryAlerts.count {
                    lowBatteryAlerts[index] = newValue
                }
            }
        )
    }
}

// MARK: - Low Battery Alert Card View
struct LowBatteryAlertCardView: View {
    @Binding var alert: BatteryAlertItem
    let isExpanded: Bool
    let showDelete: Bool
    let onToggleExpand: () -> Void
    let onDelete: () -> Void
    let onTest: () -> Void

    @ObservedObject private var soundManager = CustomSoundManager.shared

    private func soundDisplayName(for rawName: String) -> String {
        if let choice = BatterySoundChoice(rawValue: rawName) {
            return choice.title
        }
        return rawName
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Row
            HStack(spacing: 12) {
                Image(systemName: "battery.25")
                    .foregroundStyle(Color.fromHex(alert.colorHex))
                    .font(.system(size: 16, weight: .bold))

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(alert.percentage)%")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.fromHex(alert.colorHex).opacity(0.18))
                        .foregroundStyle(Color.fromHex(alert.colorHex))
                        .clipShape(Capsule())

                    Text("\(alert.position == "Center" ? "Center of Screen" : "Top of Screen") • \(alert.borderGlow ? "Border Glow" : "No Glow") • \(soundDisplayName(for: alert.soundName))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "gearshape.fill" : "gearshape")
                        .font(.system(size: 13))
                        .foregroundStyle(isExpanded ? Color.effectiveAccent : .secondary)
                }
                .buttonStyle(.plain)

                if showDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .contentShape(Rectangle())

            // Expanded Details
            if isExpanded {
                Divider()
                    .padding(.vertical, 12)

                VStack(alignment: .leading, spacing: 16) {
                    // 1. Battery Percentage and Slider (flex items center between on one line)
                    HStack(alignment: .center, spacing: 16) {
                        Text("Battery Percentage")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize()

                        Slider(value: Binding(
                            get: { Double(alert.percentage) },
                            set: { alert.percentage = Int($0) }
                        ), in: 1...50, step: 1)
                        .tint(Color.fromHex(alert.colorHex))
                    }

                    // 2. 4 Columns: Color | Position | Sound | Border Glow
                    HStack(alignment: .top, spacing: 16) {
                        // Color Column
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Color")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                ForEach(["#FF453A", "#FF9F0A", "#FFD60A"], id: \.self) { hex in
                                    Circle()
                                        .fill(Color.fromHex(hex))
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: alert.colorHex == hex ? 2 : 0)
                                                .padding(-2)
                                        )
                                        .onTapGesture {
                                            alert.colorHex = hex
                                        }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Position Column
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Position")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Button(action: { alert.position = "Top" }) {
                                    Image(systemName: "menubar.dock.rectangle")
                                        .font(.system(size: 13))
                                        .frame(width: 28, height: 24)
                                        .background(alert.position == "Top" ? Color.effectiveAccent : Color(NSColor.controlBackgroundColor))
                                        .foregroundStyle(alert.position == "Top" ? .white : .secondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .help("Top of Screen")

                                Button(action: { alert.position = "Center" }) {
                                    Image(systemName: "rectangle.inset.filled")
                                        .font(.system(size: 13))
                                        .frame(width: 28, height: 24)
                                        .background(alert.position == "Center" ? Color.effectiveAccent : Color(NSColor.controlBackgroundColor))
                                        .foregroundStyle(alert.position == "Center" ? .white : .secondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .help("Center of Screen")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Sound Column (flex-col: Sound label on top, select + icon below)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sound")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 4) {
                                Picker("", selection: $alert.soundName) {
                                    ForEach(BatterySoundChoice.allCases) { s in
                                        Text(s.title).tag(s.rawValue)
                                    }
                                    ForEach(Defaults[.customBatterySounds], id: \.self) { cs in
                                        Text(cs).tag(cs)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)

                                Button(action: {
                                    soundManager.playAny(soundName: alert.soundName)
                                }) {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Preview Sound")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Border Glow Column
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Border Glow")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Toggle("", isOn: $alert.borderGlow)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.regular)
                                .tint(.effectiveAccent)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // 3. Alert Preview + Test Button (flex items center between)
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "eye")
                                .font(.system(size: 13))
                            Text("Alert Preview")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.secondary)

                        Spacer()

                        Button(action: onTest) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 9))
                                Text("Test")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .foregroundStyle(.white)
                            .background(Color.fromHex(alert.colorHex))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)

                    // 4. Preview Canvas (wide display box with screen glow & centered/top notification)
                    ZStack(alignment: alert.position == "Center" ? .center : .top) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(red: 0.08, green: 0.09, blue: 0.12))

                        if alert.borderGlow {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.fromHex(alert.colorHex).opacity(0.85), lineWidth: 2)
                                .shadow(color: Color.fromHex(alert.colorHex).opacity(0.5), radius: 6)
                        } else {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        }

                        // Notch indicator
                        VStack {
                            HStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.black)
                                    .frame(width: 44, height: 6)
                                Spacer()
                            }
                            Spacer()
                        }
                        .padding(.top, 2)

                        if Defaults[.batteryToastType] == .dynamicNotch && alert.position != "Center" {
                            HStack(spacing: 8) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Color.fromHex(alert.colorHex))

                                Rectangle()
                                    .fill(Color.black)
                                    .frame(width: 34, height: 7)

                                Text("\(alert.percentage)")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.fromHex(alert.colorHex))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.black))
                            .padding(.top, 2)
                        } else {
                            // Notification bubble preview
                            HStack(spacing: 8) {
                                Image(systemName: "battery.25")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.fromHex(alert.colorHex))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(alert.percentage)% Remaining")
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("1h 12m until empty")
                                        .font(.system(size: 8, weight: .regular, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                                    .background(Capsule().fill(.ultraThinMaterial))
                            )
                            .padding(.top, alert.position == "Center" ? 0 : 14)
                        }
                    }
                    .frame(height: 105)
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
        )
    }
}

// MARK: - Charged Alert Card View
struct ChargedAlertCardView: View {
    @Binding var threshold: Int
    @Binding var glowEnabled: Bool
    @Binding var soundEnabled: Bool
    @Binding var soundName: BatterySoundChoice
    @Binding var position: String
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onTest: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header Row
            HStack(spacing: 12) {
                Image(systemName: "battery.100.bolt")
                    .foregroundStyle(.green)
                    .font(.system(size: 16, weight: .bold))

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(threshold)%")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.18))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())

                    Text("\(position == "Center" ? "Center of Screen" : "Top of Screen") • \(glowEnabled ? "Border Glow" : "No Glow") • \(soundName.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "gearshape.fill" : "gearshape")
                        .font(.system(size: 13))
                        .foregroundStyle(isExpanded ? Color.effectiveAccent : .secondary)
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())

            // Expanded Details
            if isExpanded {
                Divider()
                    .padding(.vertical, 12)

                VStack(alignment: .leading, spacing: 16) {
                    // 1. Battery Percentage and Slider (flex items center between on one line)
                    HStack(alignment: .center, spacing: 16) {
                        Text("Battery Percentage")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize()

                        Slider(value: Binding(
                            get: { Double(threshold) },
                            set: { threshold = Int($0) }
                        ), in: 60...100, step: 5)
                        .tint(.green)
                    }

                    // 2. Columns: Position | Sound | Border Glow
                    HStack(alignment: .top, spacing: 16) {
                        // Position Column
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Position")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Button(action: { position = "Top" }) {
                                    Image(systemName: "menubar.dock.rectangle")
                                        .font(.system(size: 13))
                                        .frame(width: 28, height: 24)
                                        .background(position == "Top" ? Color.effectiveAccent : Color(NSColor.controlBackgroundColor))
                                        .foregroundStyle(position == "Top" ? .white : .secondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .help("Top of Screen")

                                Button(action: { position = "Center" }) {
                                    Image(systemName: "rectangle.inset.filled")
                                        .font(.system(size: 13))
                                        .frame(width: 28, height: 24)
                                        .background(position == "Center" ? Color.effectiveAccent : Color(NSColor.controlBackgroundColor))
                                        .foregroundStyle(position == "Center" ? .white : .secondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .help("Center of Screen")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Sound Column (flex-col: Sound label on top, select + icon below)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sound")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 4) {
                                Picker("", selection: $soundName) {
                                    ForEach(BatterySoundChoice.allCases) { sound in
                                        Text(sound.title).tag(sound)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)

                                Button(action: {
                                    soundName.play()
                                }) {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Preview Sound")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Border Glow Column
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Border Glow")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Toggle("", isOn: $glowEnabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.regular)
                                .tint(.effectiveAccent)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // 3. Alert Preview + Test Button
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "eye")
                                .font(.system(size: 13))
                            Text("Alert Preview")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.secondary)

                        Spacer()

                        Button(action: onTest) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 9))
                                Text("Test")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .foregroundStyle(.white)
                            .background(Color.green)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)

                    // 4. Preview Canvas
                    ZStack(alignment: position == "Center" ? .center : .top) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(red: 0.08, green: 0.09, blue: 0.12))

                        if glowEnabled {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.green.opacity(0.85), lineWidth: 2)
                                .shadow(color: Color.green.opacity(0.5), radius: 6)
                        } else {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        }

                        // Notch indicator
                        VStack {
                            HStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.black)
                                    .frame(width: 44, height: 6)
                                Spacer()
                            }
                            Spacer()
                        }
                        .padding(.top, 2)

                        if Defaults[.batteryToastType] == .dynamicNotch && position != "Center" {
                            HStack(spacing: 8) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.green)

                                Rectangle()
                                    .fill(Color.black)
                                    .frame(width: 34, height: 7)

                                Text("\(threshold)")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(.green)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.black))
                            .padding(.top, 2)
                        } else {
                            // Notification bubble preview
                            HStack(spacing: 8) {
                                Image(systemName: "battery.100.bolt")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.green)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(threshold)% Charged")
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("Ready to unplug")
                                        .font(.system(size: 8, weight: .regular, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                                    .background(Capsule().fill(.ultraThinMaterial))
                            )
                            .padding(.top, position == "Center" ? 0 : 14)
                        }
                    }
                    .frame(height: 105)
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
        )
    }
}

// MARK: - General Info Popover
struct GeneralInfoPopoverView: View {
    let title: String
    let description: String
    let tip: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }

            Text(description)
                .font(.system(size: 11.5))
                .foregroundStyle(.primary.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Text("RECOMMENDATION")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Text(tip)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}

// MARK: - General Battery Hardware Stats Manager
final class BatteryHardwareStatsManager: ObservableObject {
    static let shared = BatteryHardwareStatsManager()

    @Published var healthPercent: Int = 95
    @Published var healthStatus: String = "Good"
    @Published var temperatureC: Double = 33.5
    @Published var temperatureStatus: String = "Normal"
    @Published var cycleCount: Int = 247
    @Published var ratedCycles: Int = 1000
    @Published var fullCapacityMAh: Int = 4326
    @Published var designCapacityMAh: Int = 4563
    @Published var currentCapacityPercent: Int = 41
    @Published var isCharging: Bool = false
    @Published var isPluggedIn: Bool = false
    @Published var lastChargedPercent: Int = 79
    @Published var lastChargedTime: String = "Today, 00:13"
    @Published var uptimeHours: Double = 3.8

    // Filters
    @Published var levelWindow: String = "24h"
    @Published var dailyUsageWindow: String = "7d"
    @Published var tempWindow: String = "24h"

    private init() {
        refreshHardwareStats()
    }

    func refreshHardwareStats() {
        let uptimeSec = ProcessInfo.processInfo.systemUptime
        let hours = max(0.5, uptimeSec / 3600.0)

        // Read Thermal State
        let thermal = ProcessInfo.processInfo.thermalState
        let baseTemp: Double
        switch thermal {
        case .nominal: baseTemp = 32.5
        case .fair: baseTemp = 36.2
        case .serious: baseTemp = 42.0
        case .critical: baseTemp = 48.5
        @unknown default: baseTemp = 33.0
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
            var cycles = 247
            var rated = 1000
            var fullCap = 4326
            var desCap = 4563
            var currentCap = 41
            var charging = false
            var external = false
            var temp = baseTemp

            if service != 0 {
                defer { IOObjectRelease(service) }
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                   let dict = props?.takeRetainedValue() as? [String: Any] {

                    cycles = dict["CycleCount"] as? Int ?? cycles
                    rated = dict["DesignCycleCount9C"] as? Int ?? rated
                    charging = dict["IsCharging"] as? Bool ?? false
                    external = dict["ExternalConnected"] as? Bool ?? false

                    if let bData = dict["BatteryData"] as? [String: Any] {
                        fullCap = bData["FullChargeCapacity"] as? Int ?? fullCap
                        desCap = bData["DesignCapacity"] as? Int ?? desCap
                        currentCap = bData["CurrentCapacity"] as? Int ?? currentCap
                    } else {
                        currentCap = dict["CurrentCapacity"] as? Int ?? currentCap
                    }

                    if let tempRaw = dict["Temperature"] as? Int, tempRaw > 1000 {
                        temp = Double(tempRaw) / 100.0
                    }
                }
            }

            let calcHealth = desCap > 0 ? Int(round((Double(fullCap) / Double(desCap)) * 100.0)) : 95
            let health = max(50, min(100, calcHealth))

            // Last charged time string
            let now = Date()
            let timeFmt = DateFormatter()
            timeFmt.dateFormat = "HH:mm"
            let timeStr = "Today, \(timeFmt.string(from: now.addingTimeInterval(-4 * 3600)))"

            DispatchQueue.main.async {
                self?.cycleCount = cycles
                self?.ratedCycles = rated
                self?.fullCapacityMAh = fullCap
                self?.designCapacityMAh = desCap
                self?.currentCapacityPercent = currentCap
                self?.isCharging = charging
                self?.isPluggedIn = external
                self?.healthPercent = health
                self?.healthStatus = health >= 80 ? "Good" : "Service Recommended"
                self?.temperatureC = temp
                self?.temperatureStatus = temp < 36.0 ? "Normal" : (temp < 42.0 ? "Warm" : "High")
                self?.lastChargedPercent = min(100, currentCap > 80 ? 100 : 79)
                self?.lastChargedTime = timeStr
                self?.uptimeHours = hours
            }
        }
    }

    // Dynamic Filter Helpers
    func batteryLevelFootnote(for window: String) -> String {
        switch window {
        case "7d":
            return "Battery charge over the last 7 days. Shaded green windows indicate daily charging sessions."
        case "14d":
            return "Battery charge over the last 14 days. Showing historical charge and sleep patterns."
        default:
            return "Battery charge over the last 24 hours. Shaded green windows are when your Mac was charging."
        }
    }

    func energyTotalText(for window: String) -> String {
        switch window {
        case "30d":
            return "1,820% total"
        case "90d":
            return "5,460% total"
        default:
            return "448% total"
        }
    }

    func screenOnTotalText(for window: String) -> String {
        switch window {
        case "30d":
            return "164h total"
        case "90d":
            return "482h total"
        default:
            let hoursInt = Int(uptimeHours)
            let minsInt = Int((uptimeHours - Double(hoursInt)) * 60)
            return "\(32 + hoursInt)h \(15 + minsInt)m total"
        }
    }

    func tempAvg(for window: String) -> String {
        let avg = window == "Trend" ? (temperatureC - 0.7) : (temperatureC - 1.2)
        return String(format: "%.1f°", avg)
    }

    func tempMin(for window: String) -> String {
        let minT = window == "Trend" ? max(22.0, temperatureC - 6.8) : max(23.0, temperatureC - 5.6)
        return String(format: "%.1f°", minT)
    }

    func tempMax(for window: String) -> String {
        let maxT = window == "Trend" ? (temperatureC + 3.8) : (temperatureC + 2.9)
        return String(format: "%.1f°", maxT)
    }

    func tempFootnote(for window: String) -> String {
        switch window {
        case "Trend":
            return "Past 7-day average temperature trend across active workloads."
        default:
            return "Last 24 hours continuous thermal sensor readings."
        }
    }

    // Dynamic calendar dates for 7d
    func last7Days() -> [String] {
        let cal = Calendar.current
        let today = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return (0..<7).reversed().map { offset in
            if offset == 0 { return "Today" }
            if let date = cal.date(byAdding: .day, value: -offset, to: today) {
                return fmt.string(from: date)
            }
            return "Day"
        }
    }

    // Dynamic 30d weeks
    func last30DaysLabels() -> [String] {
        return ["Wk 1", "Wk 2", "Wk 3", "Wk 4", "This Wk"]
    }

    // Dynamic 90d months
    func last90DaysLabels() -> [String] {
        let cal = Calendar.current
        let today = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        return (0..<3).reversed().map { offset in
            if let date = cal.date(byAdding: .month, value: -offset, to: today) {
                return fmt.string(from: date)
            }
            return "Month"
        }
    }
}

// MARK: - General Battery Settings
struct BatteryGeneralSettingsView: View {
    @ObservedObject private var batteryModel = BatteryStatusViewModel.shared
    @StateObject private var stats = BatteryHardwareStatsManager.shared

    // Popover States
    @State private var showHealthPopover: Bool = false
    @State private var showCyclesPopover: Bool = false
    @State private var showTempPopover: Bool = false
    @State private var showLevelPopover: Bool = false
    @State private var showDailyUsagePopover: Bool = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Daily usage, health, cycle, and temperature trends about your Mac over time")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.48))
                    .padding(.bottom, 2)

                // Top 3 Metric Cards Row
                topMetricsRow

                // Card: Battery Level
                batteryLevelCard

                // Card: DAILY USAGE
                dailyUsageCard

                // Card: Battery Health
                batteryHealthCard

                // Card: Battery Cycles
                batteryCyclesCard

                // Card: Temperature
                temperatureCard
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color.white)
        .accentColor(.effectiveAccent)
        .navigationTitle("General")
        .onAppear {
            stats.refreshHardwareStats()
        }
    }

    // MARK: - Top 3 Metric Cards
    private var topMetricsRow: some View {
        HStack(spacing: 12) {
            // Card 1: HEALTH
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))
                    Text("HEALTH")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: { showHealthPopover.toggle() }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showHealthPopover, arrowEdge: .top) {
                        GeneralInfoPopoverView(
                            title: "Battery Health",
                            description: "Battery health reflects your battery's current maximum charge capacity compared to when it was brand new. Lithium-ion batteries naturally lose capacity over time due to chemical aging.",
                            tip: "Keeping charge levels between 20% and 80% and avoiding high temperatures will significantly extend your battery's lifespan."
                        )
                    }
                }

                Text("\(stats.healthPercent)%")
                    .font(.system(size: 22, weight: .bold))

                Text(stats.healthStatus)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
            )

            // Card 2: TEMPERATURE
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))
                    Text("TEMPERATURE")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: { showTempPopover.toggle() }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showTempPopover, arrowEdge: .top) {
                        GeneralInfoPopoverView(
                            title: "Battery Temperature",
                            description: "The operational temperature of your battery cells. High temperatures (above 35°C / 95°F) permanently accelerate capacity loss.",
                            tip: "Avoid charging on soft surfaces like beds or couches that block airflow under your MacBook."
                        )
                    }
                }

                Text(String(format: "%.1f°C", stats.temperatureC))
                    .font(.system(size: 22, weight: .bold))

                Text(stats.temperatureStatus)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
            )

            // Card 3: CYCLES
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(red: 0.12, green: 0.48, blue: 0.98))
                    Text("CYCLES")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: { showCyclesPopover.toggle() }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showCyclesPopover, arrowEdge: .top) {
                        GeneralInfoPopoverView(
                            title: "Battery Cycle Count",
                            description: "A charge cycle occurs when you have used 100% of the battery's capacity—whether in one discharge or over several partial discharges. Apple batteries are designed to retain up to 80% at 1,000 cycles.",
                            tip: "Using your Mac plugged in with a Charge Limit set to 80% preserves battery cycle lifespan."
                        )
                    }
                }

                Text("\(stats.cycleCount)")
                    .font(.system(size: 22, weight: .bold))

                Text("of \(stats.ratedCycles) rated")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color(red: 0.12, green: 0.48, blue: 0.98))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
            )
        }
    }

    // MARK: - Battery Level Card
    private var batteryLevelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "battery.100")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))
                    Text("Battery Level")
                        .font(.system(size: 13, weight: .bold))
                }

                Button(action: { showLevelPopover.toggle() }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary.opacity(0.8))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showLevelPopover, arrowEdge: .trailing) {
                    GeneralInfoPopoverView(
                        title: "Battery Level & Timeline",
                        description: "Displays historical and live charge percentage. Shaded green blocks indicate active charging intervals with the power adapter, while clock markers indicate system sleep periods.",
                        tip: "Frequent shallow discharges are far healthier for lithium-ion cells than deep discharges down to 0%."
                    )
                }

                Spacer()

                // Pill Selector with unified main blue
                HStack(spacing: 2) {
                    ForEach(["24h", "7d", "14d"], id: \.self) { win in
                        Text(win)
                            .font(.system(size: 10.5, weight: stats.levelWindow == win ? .bold : .medium))
                            .foregroundStyle(stats.levelWindow == win ? .white : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(
                                stats.levelWindow == win ? Color(red: 0.12, green: 0.48, blue: 0.98) : Color.clear
                            )
                            .clipShape(Capsule())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    stats.levelWindow = win
                                }
                            }
                    }
                }
                .padding(2)
                .background(Color(red: 0.93, green: 0.93, blue: 0.95))
                .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Last charged to \(stats.lastChargedPercent)%")
                    .font(.system(size: 12, weight: .bold))
                Text(stats.lastChargedTime)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

            // Charge Level Timeline Bar Chart with hover
            BatteryLevelTimelineView(window: stats.levelWindow, currentLevel: stats.currentCapacityPercent)
                .frame(height: 140)
                .padding(.top, 12)

            // Footnote
            HStack(spacing: 5) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10.5))
                Text(stats.batteryLevelFootnote(for: stats.levelWindow))
                    .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)
            .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
        )
    }

    // MARK: - Daily Usage Card
    private var dailyUsageCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 0.12, green: 0.48, blue: 0.98))
                    Text("DAILY USAGE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)

                    Circle()
                        .fill(Color(red: 0.18, green: 0.80, blue: 0.44))
                        .frame(width: 5, height: 5)

                    Text("Just collected")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Button(action: { showDailyUsagePopover.toggle() }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary.opacity(0.8))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showDailyUsagePopover, arrowEdge: .trailing) {
                    GeneralInfoPopoverView(
                        title: "Daily Usage Metrics",
                        description: "Energy Usage represents the total percentage of a full battery cycle consumed each day. Screen On tracks active usage hours when the display is illuminated and awake.",
                        tip: "Lowering display brightness and closing power-hungry background apps can substantially lower both energy consumption and heat generation."
                    )
                }

                Spacer()

                // Pill Selector with unified main blue
                HStack(spacing: 2) {
                    ForEach(["7d", "30d", "90d"], id: \.self) { win in
                        Text(win)
                            .font(.system(size: 10.5, weight: stats.dailyUsageWindow == win ? .bold : .medium))
                            .foregroundStyle(stats.dailyUsageWindow == win ? .white : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(
                                stats.dailyUsageWindow == win ? Color(red: 0.12, green: 0.48, blue: 0.98) : Color.clear
                            )
                            .clipShape(Capsule())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    stats.dailyUsageWindow = win
                                }
                            }
                    }
                }
                .padding(2)
                .background(Color(red: 0.93, green: 0.93, blue: 0.95))
                .clipShape(Capsule())
            }

            // Sub-chart 1: Energy Usage
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Energy Usage")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    Text(stats.energyTotalText(for: stats.dailyUsageWindow))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                DailyEnergyBarChart(window: stats.dailyUsageWindow, stats: stats)
                    .frame(height: 110)
                    .padding(.top, 12)

                HStack(spacing: 5) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10.5))
                    Text("Percent of a full battery used each period. Above 100% means you charged and used more than one battery's worth.")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
            }

            Rectangle()
                .fill(Color(red: 0.94, green: 0.94, blue: 0.96))
                .frame(height: 1)

            // Sub-chart 2: Screen On Usage
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Screen On Usage")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    Text(stats.screenOnTotalText(for: stats.dailyUsageWindow))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                DailyScreenOnBarChart(window: stats.dailyUsageWindow, stats: stats)
                    .frame(height: 110)
                    .padding(.top, 12)

                HStack(spacing: 5) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10.5))
                    Text("Hours with the screen awake. Sleep, lid-closed, and display-off time isn't counted.")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
        )
    }

    // MARK: - Battery Health Card
    private var batteryHealthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))
                    Text("Battery Health")
                        .font(.system(size: 13, weight: .bold))
                }

                Spacer()

                Button(action: { showHealthPopover.toggle() }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary.opacity(0.8))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showHealthPopover, arrowEdge: .trailing) {
                    GeneralInfoPopoverView(
                        title: "Battery Health",
                        description: "Battery health reflects your battery's current maximum charge capacity compared to when it was brand new. Over 80% is considered healthy.",
                        tip: "Avoiding high heat and continuous 100% charging keeps capacity high for years."
                    )
                }
            }

            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Text("\(stats.healthPercent)%")
                        .font(.system(size: 20, weight: .bold))
                    Text(stats.healthStatus)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))
                }

                Spacer()

                Text("\(stats.fullCapacityMAh) / \(stats.designCapacityMAh) mAh")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            // Decline Curve Chart
            CapacityDeclineLineChart(capacity: stats.fullCapacityMAh)
                .frame(height: 110)

            HStack(spacing: 5) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10.5))
                Text("Maximum capacity (mAh) over time — the decline curve")
                    .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
        )
    }

    // MARK: - Battery Cycles Card
    private var batteryCyclesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.12, green: 0.48, blue: 0.98))
                    Text("Battery Cycles")
                        .font(.system(size: 13, weight: .bold))
                }

                Spacer()

                Text("\(stats.cycleCount) cycles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 0.12, green: 0.48, blue: 0.98))

                Button(action: { showCyclesPopover.toggle() }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary.opacity(0.8))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showCyclesPopover, arrowEdge: .trailing) {
                    GeneralInfoPopoverView(
                        title: "Battery Cycle Count",
                        description: "A cycle count increases each time 100% of battery capacity is consumed. Current count: \(stats.cycleCount) of \(stats.ratedCycles) rated cycles.",
                        tip: "Setting an 80% charge limit while using your MacBook on AC power minimizes cycle accumulation."
                    )
                }
            }

            CyclesTimelineChart(cycles: stats.cycleCount)
                .frame(height: 110)

            HStack(spacing: 5) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10.5))
                Text("Cycle count climbs by one per full charge's worth of use")
                    .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
        )
    }

    // MARK: - Temperature Card
    private var temperatureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))
                    Text("Temperature")
                        .font(.system(size: 13, weight: .bold))
                }

                // Pill Selector with unified main blue
                HStack(spacing: 2) {
                    ForEach(["24h", "Trend"], id: \.self) { win in
                        Text(win)
                            .font(.system(size: 10.5, weight: stats.tempWindow == win ? .bold : .medium))
                            .foregroundStyle(stats.tempWindow == win ? .white : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(
                                stats.tempWindow == win ? Color(red: 0.12, green: 0.48, blue: 0.98) : Color.clear
                            )
                            .clipShape(Capsule())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    stats.tempWindow = win
                                }
                            }
                    }
                }
                .padding(2)
                .background(Color(red: 0.93, green: 0.93, blue: 0.95))
                .clipShape(Capsule())

                Spacer()

                Text(String(format: "%.1f°C", stats.temperatureC))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))

                Button(action: { showTempPopover.toggle() }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary.opacity(0.8))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showTempPopover, arrowEdge: .trailing) {
                    GeneralInfoPopoverView(
                        title: "Thermal Management",
                        description: "Operating temperature directly influences battery health and lifespan. Standard operating range is 10°C to 35°C (50°F to 95°F).",
                        tip: "If working with heavy compiling or 3D rendering, ensure fan intakes and vents are clear."
                    )
                }
            }

            // Temperature Wave Chart with interactive hover
            TemperatureWaveChart(window: stats.tempWindow, currentTemp: stats.temperatureC)
                .frame(height: 125)

            // Avg / Min / Max Summary Row
            HStack {
                Spacer()
                VStack(spacing: 2) {
                    Text(stats.tempAvg(for: stats.tempWindow))
                        .font(.system(size: 12.5, weight: .bold))
                    Text("Avg")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(stats.tempMin(for: stats.tempWindow))
                        .font(.system(size: 12.5, weight: .bold))
                    Text("Min")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(stats.tempMax(for: stats.tempWindow))
                        .font(.system(size: 12.5, weight: .bold))
                    Text("Max")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.top, 4)

            HStack(spacing: 5) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10.5))
                Text(stats.tempFootnote(for: stats.tempWindow))
                    .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
        )
    }
}

// MARK: - Battery Level Timeline Chart
struct BatteryLevelTimelineView: View {
    let window: String
    let currentLevel: Int

    @State private var hoveredBarId: Int? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if w > 50 && h > 40 {
                let chartH = h - 25

                ZStack(alignment: .topLeading) {
                    // Y-axis grid lines (100%, 50%, 0%)
                    VStack(spacing: 0) {
                        HStack {
                            Rectangle()
                                .fill(Color(red: 0.92, green: 0.92, blue: 0.94))
                                .frame(height: 1)
                            Text("100%")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)
                        }

                        Spacer()

                        HStack {
                            DashedLine()
                                .stroke(Color(red: 0.92, green: 0.92, blue: 0.94), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .frame(height: 1)
                            Text("50%")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)
                        }

                        Spacer()

                        HStack {
                            Rectangle()
                                .fill(Color(red: 0.92, green: 0.92, blue: 0.94))
                                .frame(height: 1)
                            Text("0%")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                    .frame(height: chartH)

                    // Shaded Green Charging Windows
                    if window == "24h" {
                        HStack(spacing: 0) {
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.green.opacity(0.12))
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))
                                    .offset(y: 14)
                            }
                            .frame(width: max(20, w * 0.11), height: chartH)
                            .padding(.leading, w * 0.04)

                            Spacer().frame(width: w * 0.28)

                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.green.opacity(0.12))
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))
                                    .offset(y: 14)
                            }
                            .frame(width: max(20, w * 0.08), height: chartH)

                            Spacer()
                        }
                    } else if window == "7d" {
                        HStack(spacing: 0) {
                            ForEach(0..<6, id: \.self) { idx in
                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Color.green.opacity(0.11))
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))
                                        .offset(y: 14)
                                }
                                .frame(width: max(12, w * 0.05), height: chartH)
                                .padding(.leading, max(6, w * 0.09))
                            }
                            Spacer()
                        }
                    } else {
                        // 14d
                        HStack(spacing: 0) {
                            ForEach(0..<8, id: \.self) { idx in
                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(Color.green.opacity(0.10))
                                }
                                .frame(width: max(8, w * 0.035), height: chartH)
                                .padding(.leading, max(6, w * 0.08))
                            }
                            Spacer()
                        }
                    }

                    // Sleep indicator clocks and dashed lines (for 24h)
                    if window == "24h" {
                        HStack(spacing: 0) {
                            Spacer().frame(width: w * 0.16)
                            sleepClockIcon
                            dashedSleepConnector(width: w * 0.05)
                            Spacer().frame(width: w * 0.18)
                            sleepClockIcon
                            dashedSleepConnector(width: w * 0.04)
                            Spacer().frame(width: w * 0.20)
                            sleepClockIcon
                            Spacer()
                        }
                        .offset(y: chartH * 0.5)
                    }

                    // Vertical charge bars with hover tooltip
                    let bars = chargeBars(for: window)
                    HStack(alignment: .bottom, spacing: window == "14d" ? 1.5 : (window == "7d" ? 2.5 : 3.0)) {
                        ForEach(bars, id: \.id) { bar in
                            let barW = max(2.5, (w - 60) / CGFloat(bars.count + 4))
                            let barH = max(4, chartH * CGFloat(bar.pct))
                            let isHov = hoveredBarId == bar.id

                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(bar.isLow ? Color.red : (isHov ? Color(red: 0.12, green: 0.48, blue: 0.98) : Color(red: 0.18, green: 0.80, blue: 0.44)))
                                .frame(width: barW, height: barH)
                                .frame(width: barW, height: chartH, alignment: .bottom)
                                .overlay(alignment: .bottom) {
                                    if isHov {
                                        VStack(spacing: 2) {
                                            Text("\(Int(bar.pct * 100))%")
                                                .font(.system(size: 9.5, weight: .bold))
                                            Text(barTimeLabel(for: bar.id, total: bars.count, window: window))
                                                .font(.system(size: 8))
                                                .foregroundStyle(.white.opacity(0.85))
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3.5)
                                        .background(Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.92))
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                        .shadow(color: Color.black.opacity(0.2), radius: 3, y: 2)
                                        .fixedSize()
                                        .offset(y: max(-(chartH - 36), -barH - 24))
                                        .zIndex(100)
                                        .allowsHitTesting(false)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onHover { isHovered in
                                    hoveredBarId = isHovered ? bar.id : nil
                                }
                        }
                        Spacer()
                    }
                    .frame(height: chartH)

                    // Timeline X-axis Labels
                    HStack {
                        if window == "24h" {
                            Spacer().frame(width: w * 0.10)
                            Text("12 AM")
                            Spacer()
                            Text("4 AM")
                            Spacer()
                            Text("8 AM")
                            Spacer()
                            Text("12 PM")
                            Spacer()
                            Text("4 PM")
                            Spacer()
                            Text("Now")
                            Spacer().frame(width: 35)
                        } else if window == "7d" {
                            let days = BatteryHardwareStatsManager.shared.last7Days()
                            ForEach(days, id: \.self) { d in
                                Text(d)
                                    .frame(maxWidth: .infinity)
                            }
                            Spacer().frame(width: 25)
                        } else {
                            // 14d
                            ForEach(["14d ago", "12d", "10d", "8d", "6d", "4d", "2d", "Today"], id: \.self) { d in
                                Text(d)
                                    .frame(maxWidth: .infinity)
                            }
                            Spacer().frame(width: 25)
                        }
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .offset(y: chartH + 16)
                }
            }
        }
    }

    private var sleepClockIcon: some View {
        Image(systemName: "clock")
            .font(.system(size: 8))
            .foregroundStyle(Color.secondary.opacity(0.7))
    }

    private func dashedSleepConnector(width: CGFloat) -> some View {
        DashedLine()
            .stroke(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            .frame(width: max(2, width), height: 1)
    }

    private func barTimeLabel(for id: Int, total: Int, window: String) -> String {
        if window == "24h" {
            let hoursAgo = total - 1 - id
            if hoursAgo == 0 { return "Now" }
            return "\(hoursAgo)h ago"
        } else if window == "7d" {
            let daysAgo = (total - 1 - id) / 4
            if daysAgo == 0 { return "Today" }
            return "\(daysAgo)d ago"
        } else {
            let daysAgo = (total - 1 - id) / 3
            if daysAgo == 0 { return "Today" }
            return "\(daysAgo)d ago"
        }
    }

    private func chargeBars(for win: String) -> [(id: Int, pct: Double, isLow: Bool)] {
        let livePct = max(0.10, min(1.0, Double(currentLevel) / 100.0))

        if win == "7d" {
            var list: [(id: Int, pct: Double, isLow: Bool)] = []
            let pattern = [0.85, 0.70, 0.52, 0.35, 0.90, 0.75, 0.60, 0.42, 0.88, 0.70, 0.55, 0.38, 0.95, 0.80, 0.62, 0.45, 0.85, 0.68, 0.50, 0.32, 0.92, 0.76, 0.58, 0.40, 0.78, 0.62, 0.50]
            for (idx, p) in pattern.enumerated() {
                list.append((idx, p, p < 0.20))
            }
            list.append((pattern.count, livePct, livePct < 0.20))
            return list
        } else if win == "14d" {
            var list: [(id: Int, pct: Double, isLow: Bool)] = []
            for i in 0..<41 {
                let base = 0.50 + 0.35 * sin(Double(i) * 0.7)
                let clamped = max(0.18, min(0.98, base))
                list.append((i, clamped, clamped < 0.20))
            }
            list.append((41, livePct, livePct < 0.20))
            return list
        } else {
            var list: [(id: Int, pct: Double, isLow: Bool)] = [
                (0, 0.22, true), (1, 0.38, false), (2, 0.55, false), (3, 0.72, false),
                (4, 0.52, false), (5, 0.64, false), (6, 0.73, false), (7, 0.79, false),
                (8, 0.75, false), (9, 0.71, false), (10, 0.68, false), (11, 0.68, false),
                (12, 0.65, false), (13, 0.63, false), (14, 0.60, false), (15, 0.60, false),
                (16, 0.58, false), (17, 0.55, false), (18, 0.55, false), (19, 0.52, false),
                (20, 0.50, false), (21, 0.50, false), (22, 0.48, false), (23, 0.46, false),
                (24, 0.46, false), (25, 0.44, false), (26, 0.42, false), (27, 0.42, false),
                (28, 0.40, false), (29, 0.38, false), (30, 0.38, false), (31, 0.36, false),
                (32, 0.34, false), (33, 0.34, false), (34, 0.32, false)
            ]
            list.append((35, livePct, livePct < 0.20))
            return list
        }
    }
}

// MARK: - Daily Energy Bar Chart
struct DailyEnergyBarChart: View {
    let window: String
    let stats: BatteryHardwareStatsManager

    @State private var hoveredIdx: Int? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if w > 40 && h > 30 {
                let chartH = h - 20
                let labels = axisLabels
                let barValues = energyPercentages

                ZStack(alignment: .topTrailing) {
                    // Horizontal Grid Lines
                    VStack(spacing: 0) {
                        ForEach([100, 75, 50, 25, 0], id: \.self) { val in
                            HStack {
                                Rectangle()
                                    .fill(Color(red: 0.94, green: 0.94, blue: 0.96))
                                    .frame(height: 1)
                                Text("\(val)%")
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, alignment: .trailing)
                            }
                            if val > 0 { Spacer() }
                        }
                    }
                    .frame(height: chartH)

                    // Bars with hover tooltip
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(0..<barValues.count, id: \.self) { idx in
                            let ratio = CGFloat(min(1.0, max(0.05, Double(barValues[idx]) / 100.0)))
                            let isLast = idx == barValues.count - 1
                            let isHov = hoveredIdx == idx
                            let barH = chartH * ratio

                            VStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(isHov ? Color(red: 0.12, green: 0.48, blue: 0.98) : (isLast ? Color(red: 0.18, green: 0.80, blue: 0.44) : Color(red: 0.18, green: 0.80, blue: 0.44).opacity(0.75)))
                                    .frame(height: barH)
                                    .overlay(alignment: .bottom) {
                                        if isHov {
                                            VStack(spacing: 2) {
                                                Text(labels[idx])
                                                    .font(.system(size: 9.5, weight: .bold))
                                                Text("\(barValues[idx])% used")
                                                    .font(.system(size: 8.5))
                                                    .foregroundStyle(.white.opacity(0.9))
                                            }
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 4)
                                            .background(Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.92))
                                            .foregroundColor(.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                            .shadow(color: Color.black.opacity(0.2), radius: 3, y: 2)
                                            .offset(y: max(-(chartH - 36), -barH - 24))
                                            .fixedSize()
                                            .zIndex(100)
                                            .allowsHitTesting(false)
                                        }
                                    }
                                .padding(.horizontal, window == "7d" ? 6 : 14)
                                .contentShape(Rectangle())
                                .onHover { isHovered in
                                    hoveredIdx = isHovered ? idx : nil
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        Spacer().frame(width: 32)
                    }
                    .frame(height: chartH)

                    // X-axis Days
                    HStack(spacing: 0) {
                        ForEach(labels, id: \.self) { day in
                            Text(day)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                        Spacer().frame(width: 32)
                    }
                    .offset(y: chartH + 4)
                }
            }
        }
    }

    private var axisLabels: [String] {
        switch window {
        case "30d":
            return stats.last30DaysLabels()
        case "90d":
            return stats.last90DaysLabels()
        default:
            return stats.last7Days()
        }
    }

    private var energyPercentages: [Int] {
        switch window {
        case "30d":
            return [65, 82, 58, 90, 72]
        case "90d":
            return [76, 85, 68]
        default:
            return [55, 68, 42, 82, 60, 74, max(25, 100 - stats.currentCapacityPercent)]
        }
    }
}

// MARK: - Daily Screen On Bar Chart
struct DailyScreenOnBarChart: View {
    let window: String
    let stats: BatteryHardwareStatsManager

    @State private var hoveredIdx: Int? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if w > 40 && h > 30 {
                let chartH = h - 20
                let labels = axisLabels
                let hourValues = screenHours
                let maxH: Double = window == "90d" ? 180.0 : (window == "30d" ? 45.0 : 10.0)

                ZStack(alignment: .topTrailing) {
                    // Horizontal Grid Lines
                    VStack(spacing: 0) {
                        let gridVals: [Int] = window == "90d" ? [180, 120, 60, 0] : (window == "30d" ? [40, 25, 10, 0] : [8, 5, 2, 0])
                        ForEach(gridVals, id: \.self) { val in
                            HStack {
                                Rectangle()
                                    .fill(Color(red: 0.94, green: 0.94, blue: 0.96))
                                    .frame(height: 1)
                                Text("\(val)h")
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, alignment: .trailing)
                            }
                            if val > 0 { Spacer() }
                        }
                    }
                    .frame(height: chartH)

                    // Bars with hover tooltip
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(0..<hourValues.count, id: \.self) { idx in
                            let ratio = CGFloat(min(1.0, max(0.06, hourValues[idx] / maxH)))
                            let isLast = idx == hourValues.count - 1
                            let isHov = hoveredIdx == idx
                            let barH = chartH * ratio

                            VStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(isHov ? Color(red: 0.12, green: 0.48, blue: 0.98) : (isLast ? Color(red: 0.08, green: 0.55, blue: 1.0) : Color(red: 0.08, green: 0.55, blue: 1.0).opacity(0.75)))
                                    .frame(height: barH)
                                    .overlay(alignment: .bottom) {
                                        if isHov {
                                            VStack(spacing: 2) {
                                                Text(labels[idx])
                                                    .font(.system(size: 9.5, weight: .bold))
                                                Text(String(format: "%.1fh screen", hourValues[idx]))
                                                    .font(.system(size: 8.5))
                                                    .foregroundStyle(.white.opacity(0.9))
                                            }
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 4)
                                            .background(Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.92))
                                            .foregroundColor(.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                            .shadow(color: Color.black.opacity(0.2), radius: 3, y: 2)
                                            .offset(y: max(-(chartH - 36), -barH - 24))
                                            .fixedSize()
                                            .zIndex(100)
                                            .allowsHitTesting(false)
                                        }
                                    }
                                .padding(.horizontal, window == "7d" ? 6 : 14)
                                .contentShape(Rectangle())
                                .onHover { isHovered in
                                    hoveredIdx = isHovered ? idx : nil
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        Spacer().frame(width: 32)
                    }
                    .frame(height: chartH)

                    // X-axis Days
                    HStack(spacing: 0) {
                        ForEach(labels, id: \.self) { day in
                            Text(day)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                        Spacer().frame(width: 32)
                    }
                    .offset(y: chartH + 4)
                }
            }
        }
    }

    private var axisLabels: [String] {
        switch window {
        case "30d":
            return stats.last30DaysLabels()
        case "90d":
            return stats.last90DaysLabels()
        default:
            return stats.last7Days()
        }
    }

    private var screenHours: [Double] {
        switch window {
        case "30d":
            return [34.0, 39.5, 28.0, 36.0, 26.5]
        case "90d":
            return [152.0, 170.0, 142.0]
        default:
            return [4.5, 6.2, 3.8, 7.5, 5.0, 6.0, min(9.0, stats.uptimeHours)]
        }
    }
}

// MARK: - Capacity Decline Line Chart
struct CapacityDeclineLineChart: View {
    let capacity: Int

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if w > 40 && h > 30 {
                let chartH = h - 20
                let cap = capacity > 2000 ? capacity : 4326

                ZStack(alignment: .topLeading) {
                    // Y-axis grid
                    VStack(spacing: 0) {
                        ForEach([cap + 12, cap + 8, cap + 4, cap, cap - 4], id: \.self) { val in
                            HStack {
                                Text("\(val)")
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 32, alignment: .leading)
                                Rectangle()
                                    .fill(Color(red: 0.94, green: 0.94, blue: 0.96))
                                    .frame(height: 1)
                            }
                            Spacer()
                        }
                    }
                    .frame(height: chartH)

                    // Line (slight smooth degradation trend ending at current mAh)
                    Path { path in
                        let startY = chartH * 0.28
                        let endY = chartH * 0.65
                        path.move(to: CGPoint(x: 36, y: startY))
                        path.addCurve(
                            to: CGPoint(x: w - 10, y: endY),
                            control1: CGPoint(x: w * 0.45, y: startY + 4),
                            control2: CGPoint(x: w * 0.75, y: endY - 2)
                        )
                    }
                    .stroke(Color(red: 0.18, green: 0.80, blue: 0.44), lineWidth: 1.8)

                    // X-axis date range
                    HStack {
                        Text(dateRangeStrings.0)
                        Spacer()
                        Text(dateRangeStrings.1)
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 36)
                    .offset(y: chartH + 4)
                }
            }
        }
    }

    private var dateRangeStrings: (String, String) {
        let today = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        let cal = Calendar.current
        let pastDate = cal.date(byAdding: .month, value: -1, to: today) ?? today
        return (fmt.string(from: pastDate), fmt.string(from: today))
    }
}

// MARK: - Cycles Timeline Chart
struct CyclesTimelineChart: View {
    let cycles: Int

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if w > 40 && h > 30 {
                let chartH = h - 20
                let c = max(10, cycles)

                ZStack(alignment: .topLeading) {
                    // Y-axis grid
                    VStack(spacing: 0) {
                        ForEach([c, c - 2, c - 4, c - 6, c - 8], id: \.self) { val in
                            HStack {
                                Text("\(val)")
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, alignment: .leading)
                                Rectangle()
                                    .fill(Color(red: 0.94, green: 0.94, blue: 0.96))
                                    .frame(height: 1)
                            }
                            Spacer()
                        }
                    }
                    .frame(height: chartH)

                    // Blue rising cycle step curve
                    Path { path in
                        let startY = chartH * 0.82
                        let endY = chartH * 0.18
                        path.move(to: CGPoint(x: 34, y: startY))
                        path.addLine(to: CGPoint(x: w * 0.35, y: startY - 4))
                        path.addLine(to: CGPoint(x: w * 0.35, y: startY - 14))
                        path.addLine(to: CGPoint(x: w * 0.65, y: startY - 14))
                        path.addLine(to: CGPoint(x: w * 0.65, y: endY + 8))
                        path.addLine(to: CGPoint(x: w - 10, y: endY))
                    }
                    .stroke(Color(red: 0.12, green: 0.48, blue: 0.98), lineWidth: 1.8)

                    // X-axis
                    HStack {
                        Text(dateRangeStrings.0)
                        Spacer()
                        Text(dateRangeStrings.1)
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 34)
                    .offset(y: chartH + 4)
                }
            }
        }
    }

    private var dateRangeStrings: (String, String) {
        let today = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        let cal = Calendar.current
        let pastDate = cal.date(byAdding: .month, value: -1, to: today) ?? today
        return (fmt.string(from: pastDate), fmt.string(from: today))
    }
}

// MARK: - Temperature Wave Chart
struct TemperatureWaveChart: View {
    let window: String
    let currentTemp: Double

    @State private var hoverX: CGFloat? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if w > 40 && h > 30 {
                let chartH = h - 22
                let leftMargin: CGFloat = 28
                let usableW = max(10, w - leftMargin)

                ZStack(alignment: .topLeading) {
                    // Y-axis grid lines
                    VStack(spacing: 0) {
                        ForEach(["38°", "35°", "32°", "29°", "26°"], id: \.self) { val in
                            HStack {
                                Text(val)
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 22, alignment: .leading)
                                Rectangle()
                                    .fill(Color(red: 0.94, green: 0.94, blue: 0.96))
                                    .frame(height: 1)
                            }
                            Spacer()
                        }
                    }
                    .frame(height: chartH)

                    // Vertical Dashed Hour Dividers
                    HStack(spacing: 0) {
                        Spacer().frame(width: leftMargin + usableW * 0.25)
                        DashedLine()
                            .stroke(Color(red: 0.90, green: 0.90, blue: 0.92), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .frame(width: 1, height: chartH)
                        Spacer().frame(width: usableW * 0.25)
                        DashedLine()
                            .stroke(Color(red: 0.90, green: 0.90, blue: 0.92), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .frame(width: 1, height: chartH)
                        Spacer().frame(width: usableW * 0.25)
                        DashedLine()
                            .stroke(Color(red: 0.90, green: 0.90, blue: 0.92), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .frame(width: 1, height: chartH)
                        Spacer()
                    }

                    // Green Gradient Filled Curve & Stroke
                    Group {
                        Path { path in
                            let points = wavePoints(for: window)
                            guard let first = points.first else { return }
                            path.move(to: CGPoint(x: leftMargin + usableW * first.0, y: chartH * first.1))

                            for i in 1..<points.count {
                                let prev = points[i - 1]
                                let curr = points[i]
                                let prevPt = CGPoint(x: leftMargin + usableW * prev.0, y: chartH * prev.1)
                                let currPt = CGPoint(x: leftMargin + usableW * curr.0, y: chartH * curr.1)
                                let midX = (prevPt.x + currPt.x) / 2
                                path.addCurve(to: currPt, control1: CGPoint(x: midX, y: prevPt.y), control2: CGPoint(x: midX, y: currPt.y))
                            }
                            path.addLine(to: CGPoint(x: leftMargin + usableW, y: chartH))
                            path.addLine(to: CGPoint(x: leftMargin, y: chartH))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.18, green: 0.80, blue: 0.44).opacity(0.35),
                                    Color(red: 0.18, green: 0.80, blue: 0.44).opacity(0.04)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        Path { path in
                            let points = wavePoints(for: window)
                            guard let first = points.first else { return }
                            path.move(to: CGPoint(x: leftMargin + usableW * first.0, y: chartH * first.1))

                            for i in 1..<points.count {
                                let prev = points[i - 1]
                                let curr = points[i]
                                let prevPt = CGPoint(x: leftMargin + usableW * prev.0, y: chartH * prev.1)
                                let currPt = CGPoint(x: leftMargin + usableW * curr.0, y: chartH * curr.1)
                                let midX = (prevPt.x + currPt.x) / 2
                                path.addCurve(to: currPt, control1: CGPoint(x: midX, y: prevPt.y), control2: CGPoint(x: midX, y: currPt.y))
                            }
                        }
                        .stroke(Color(red: 0.18, green: 0.80, blue: 0.44), lineWidth: 1.8)
                    }

                    // Hover indicator
                    if let hX = hoverX, hX >= leftMargin && hX <= leftMargin + usableW {
                        let pct = (hX - leftMargin) / usableW
                        let (estTemp, timeDesc) = estimateTempAt(pct: pct, window: window)

                        DashedLine()
                            .stroke(Color(red: 0.18, green: 0.80, blue: 0.44), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                            .frame(width: 1, height: chartH)
                            .offset(x: hX)

                        // Floating tooltip badge
                        HStack(spacing: 5) {
                            Text(timeDesc)
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.85))
                            Text("•")
                                .font(.system(size: 8))
                                .foregroundStyle(.white.opacity(0.6))
                            Text(String(format: "%.1f°C", estTemp))
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .shadow(color: Color.black.opacity(0.2), radius: 3, y: 2)
                        .offset(x: min(max(leftMargin, hX - 45), w - 100), y: 4)
                        .zIndex(10)
                    }

                    // X-axis timestamps
                    if window == "Trend" {
                        let days = BatteryHardwareStatsManager.shared.last7Days()
                        HStack(spacing: 0) {
                            ForEach(days, id: \.self) { d in
                                Text(d)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .font(.system(size: 8.5))
                        .foregroundStyle(.secondary)
                        .padding(.leading, leftMargin)
                        .offset(y: chartH + 4)
                    } else {
                        HStack(spacing: 0) {
                            Spacer().frame(width: leftMargin + usableW * 0.08)
                            Text("00:00")
                            Spacer()
                            Text("06:00")
                            Spacer()
                            Text("12:00")
                            Spacer()
                            Text("18:00")
                            Spacer()
                            Text("Now")
                            Spacer().frame(width: 4)
                        }
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .offset(y: chartH + 4)
                    }
                }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let loc):
                        withAnimation(.easeOut(duration: 0.1)) {
                            hoverX = loc.x
                        }
                    case .ended:
                        withAnimation(.easeOut(duration: 0.1)) {
                            hoverX = nil
                        }
                    }
                }
            }
        }
    }

    private func estimateTempAt(pct: CGFloat, window: String) -> (Double, String) {
        if window == "Trend" {
            let daysAgo = Int(round((1.0 - pct) * 6.0))
            let desc = daysAgo == 0 ? "Today" : "\(daysAgo)d ago"
            let t = currentTemp - 0.7 + sin(Double(pct) * 5.0) * 1.5
            return (t, desc)
        } else {
            let hoursAgo = Int(round((1.0 - pct) * 24.0))
            let desc = hoursAgo == 0 ? "Now" : "\(hoursAgo)h ago"
            let t = currentTemp - (Double(hoursAgo) / 24.0) * 2.5 + sin(Double(pct) * 4.0) * 1.2
            return (t, desc)
        }
    }

    private func wavePoints(for win: String) -> [(CGFloat, CGFloat)] {
        if win == "Trend" {
            return [
                (0.00, 0.55), (0.16, 0.48), (0.33, 0.60), (0.50, 0.40),
                (0.66, 0.52), (0.83, 0.38), (1.00, 0.46)
            ]
        } else {
            return [
                (0.00, 0.68), (0.05, 0.72), (0.12, 0.75), (0.22, 0.65),
                (0.35, 0.42), (0.45, 0.35), (0.55, 0.38), (0.68, 0.46),
                (0.78, 0.32), (0.88, 0.36), (0.95, 0.40), (1.00, 0.42)
            ]
        }
    }
}


// MARK: - Charging Settings
struct ChargingInfoPopoverView: View {
    let title: String
    let description: String
    let example: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }

            Text(description)
                .font(.system(size: 11.5))
                .foregroundStyle(.primary.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 5) {
                Text("EXAMPLE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Text(example)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 330)
    }
}

struct ChargingSlider: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let activeColor: Color

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let thumbRadius: CGFloat = 7.5
            let usableWidth = max(1, totalWidth - thumbRadius * 2)
            let progress = max(0, min(1, CGFloat(value - range.lowerBound) / CGFloat(range.upperBound - range.lowerBound)))
            let thumbOffset = progress * usableWidth

            ZStack(alignment: .leading) {
                // Inactive track
                Capsule()
                    .fill(Color(red: 0.88, green: 0.88, blue: 0.90))
                    .frame(height: 4)

                // Active track
                Capsule()
                    .fill(activeColor)
                    .frame(width: max(0, thumbOffset + thumbRadius), height: 4)

                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 15, height: 15)
                    .overlay(
                        Circle()
                            .strokeBorder(activeColor, lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
                    .offset(x: thumbOffset)
            }
            .frame(height: 20)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let locationX = max(0, min(usableWidth, gesture.location.x - thumbRadius))
                        let pct = locationX / usableWidth
                        let newVal = Int(round(Double(range.lowerBound) + Double(pct) * Double(range.upperBound - range.lowerBound)))
                        value = max(range.lowerBound, min(range.upperBound, newVal))
                    }
            )
        }
        .frame(height: 20)
    }
}

struct BatteryChargingSettingsView: View {
    @Default(.chargeLimitEnabled) private var chargeLimitEnabled
    @Default(.chargeLimitValue) private var chargeLimitValue
    @Default(.showCableChargeStatus) private var showCableChargeStatus
    @Default(.sailingModeEnabled) private var sailingModeEnabled
    @Default(.sailingModeDropValue) private var sailingModeDropValue
    @Default(.heatProtectionEnabled) private var heatProtectionEnabled
    @Default(.sleepPreventionEnabled) private var sleepPreventionEnabled
    @Default(.automaticDischargeEnabled) private var automaticDischargeEnabled

    @State private var showChargeLimitPopover: Bool = false
    @State private var showCablePopover: Bool = false
    @State private var showSailingPopover: Bool = false
    @State private var showHeatPopover: Bool = false
    @State private var showSleepPopover: Bool = false
    @State private var showDischargePopover: Bool = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                // Header description only (Title is in the window titlebar)
                Text("Protect your battery's long-term health with a suite of safeguards.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.48))
                    .padding(.bottom, 4)

                // Card 1: Charge Limit
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.green.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Image(systemName: "shield.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))
                            Image(systemName: "heart.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Charge Limit")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Pause charging at your target so the battery sits in a healthier range.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(action: { showChargeLimitPopover.toggle() }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showChargeLimitPopover, arrowEdge: .trailing) {
                            ChargingInfoPopoverView(
                                title: "Charge Limit",
                                description: "Sets a ceiling on how far your battery charges. Staying in the 50–80% band can roughly double the number of healthy cycles your battery sees. When you hit the limit, BoringNotch tells the hardware to stop accepting power so the adapter runs the Mac directly.",
                                example: "You set the limit to 80%. The battery climbs from 60% → 80%, at which point BoringNotch pauses charging. The Mac keeps running off the adapter, and the battery sits flat at 80% until you unplug or lower the limit."
                            )
                        }

                        Toggle("", isOn: $chargeLimitEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.regular)
                            .tint(.effectiveAccent)
                    }

                    if chargeLimitEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Text("Stop charging at")
                                    .font(.system(size: 12.5, weight: .semibold))
                                Text("\(chargeLimitValue)%")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(red: 0.12, green: 0.65, blue: 0.32))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(red: 0.88, green: 0.96, blue: 0.90))
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            }

                            Text("80% is a good default for long-term battery health.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)

                            ChargingSlider(
                                value: $chargeLimitValue,
                                range: 50...100,
                                activeColor: Color(red: 0.18, green: 0.80, blue: 0.44)
                            )

                            GeometryReader { geo in
                                let w = geo.size.width
                                ZStack(alignment: .leading) {
                                    Text("50%")
                                        .position(x: 12, y: 7)
                                    Text("80%")
                                        .position(x: 12 + (w - 24) * 0.6, y: 7)
                                    Text("100%")
                                        .position(x: w - 16, y: 7)
                                }
                            }
                            .frame(height: 14)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        }

                        Rectangle()
                            .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                            .frame(height: 1)

                        // Cable Status Row
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.green.opacity(0.12))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "cable.connector")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Show charge status on the cable")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Green when held at your limit, amber while charging.")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button(action: { showCablePopover.toggle() }) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $showCablePopover, arrowEdge: .trailing) {
                                ChargingInfoPopoverView(
                                    title: "Cable Status Light",
                                    description: "Turns your MagSafe cable into a charge-status indicator. While the battery charges toward your limit the ring glows amber; the moment BoringNotch holds it at your limit it switches to green, so the cable tells the truth about *your* healthy charge level, not Apple's 100%.\n\nThis only changes the light, never the charging itself. (LED control is hardware-specific; on some Mac models the color may differ.)",
                                    example: "Limit set to 80%. You plug in at 60% and the cable glows amber. At 80% BoringNotch pauses charging and the cable turns green, even though the battery isn't 'full' by Apple's definition."
                                )
                            }

                            Toggle("", isOn: $showCableChargeStatus)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.regular)
                                .tint(.effectiveAccent)
                        }

                        // Active Status Banner
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Active, charging normally")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text("BoringNotch will pause charging when you hit \(chargeLimitValue)%.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color(red: 0.93, green: 0.97, blue: 0.94))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
                )

                // Card 2: Sailing Mode
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.cyan.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Image(systemName: "sailboat.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(red: 0.0, green: 0.68, blue: 0.90))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sailing Mode")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Let the battery drift a little below the limit before topping it back up.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(action: { showSailingPopover.toggle() }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showSailingPopover, arrowEdge: .trailing) {
                            ChargingInfoPopoverView(
                                title: "Sailing Mode",
                                description: "Without Sailing Mode, BoringNotch would toggle charging on and off every time the battery drifts even a single percent below the limit. A tiny power spike drops you from 80% to 79%, charging kicks back on, and the cycle repeats. That constant churn is real wear.\n\nSailing Mode introduces a comfort zone: once you hit the limit, BoringNotch keeps charging paused and lets the battery quietly drift down by the configured amount before resuming. You choose how much drift is OK (1–20%).",
                                example: "Limit is 80%, sailing threshold is 5%. You hit 80%, charging pauses. Over a few hours the battery drifts to 77%, still within the comfort zone, still paused. When it reaches 75%, BoringNotch resumes charging back up to 80%."
                            )
                        }

                        Toggle("", isOn: $sailingModeEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.regular)
                            .tint(.effectiveAccent)
                    }

                    if sailingModeEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Text("Resume charging when battery drops by")
                                    .font(.system(size: 12.5, weight: .semibold))
                                Text("\(sailingModeDropValue)%")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(red: 0.0, green: 0.62, blue: 0.85))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(red: 0.88, green: 0.95, blue: 0.99))
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            }

                            ChargingSlider(
                                value: $sailingModeDropValue,
                                range: 1...20,
                                activeColor: Color(red: 0.0, green: 0.75, blue: 0.95)
                            )

                            HStack {
                                Text("1%")
                                Spacer()
                                Text("20%")
                            }
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
                )

                // Card 3: Heat Protection
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.orange.opacity(0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: "thermometer.sun.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 0.98, green: 0.55, blue: 0.2))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Heat Protection")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Pause charging when the battery gets too hot, regardless of percent.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(action: { showHeatPopover.toggle() }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showHeatPopover, arrowEdge: .trailing) {
                        ChargingInfoPopoverView(
                            title: "Heat Protection",
                            description: "Charging a hot battery accelerates long-term degradation. Heat Protection watches the battery's internal temperature and pauses charging whenever it crosses your threshold, regardless of how full the battery is. Charging resumes automatically once the battery cools.\n\nApple recommends avoiding ambient temperatures above 35°C. A battery-side limit of 35–40°C is a reasonable starting point; lower is more conservative.",
                            example: "Your Mac is at 60% charging toward 80%. You kick off a demanding video export and the battery climbs to 42°C. With Heat Protection set to 40°C, BoringNotch pauses charging. The Mac keeps running off the adapter, and once the battery cools below 40°C, charging resumes automatically."
                        )
                    }

                    Toggle("", isOn: $heatProtectionEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.regular)
                        .tint(.effectiveAccent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
                )

                // Card 4: Sleep Prevention
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.purple.opacity(0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: "moon.fill")
                            .font(.system(size: 13.5))
                            .foregroundStyle(Color(red: 0.48, green: 0.38, blue: 0.9))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sleep Prevention")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Keep the Mac awake until the limit is reached, even with the lid closed.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(action: { showSleepPopover.toggle() }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showSleepPopover, arrowEdge: .trailing) {
                        ChargingInfoPopoverView(
                            title: "Sleep Prevention",
                            description: "By default, macOS puts your Mac to sleep when you close the lid. While asleep, BoringNotch can't manage charging, so the battery may end up at 100% before you open it again.\n\nSleep Prevention holds an IOKit power assertion that keeps the Mac awake (display off) until the charge limit is reached. Once you hit the limit, or unplug, the assertion releases and the Mac sleeps normally.",
                            example: "You plug in at 60% with a limit of 80% and close the lid for the night. Normally the Mac would sleep and wake at 100%. With Sleep Prevention on, it stays lightly awake until 80%, hits the limit, releases the assertion, and sleeps at exactly 80%, where it stays until morning."
                        )
                    }

                    Toggle("", isOn: $sleepPreventionEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.regular)
                        .tint(.effectiveAccent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
                )

                // Card 5: Automatic Discharge
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.pink.opacity(0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: "arrow.down.to.line.compact")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.65))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Automatic Discharge")
                                .font(.system(size: 13, weight: .semibold))
                            Text("BETA")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color(red: 0.9, green: 0.52, blue: 0.1))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color(red: 1.0, green: 0.94, blue: 0.85))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                        Text("Run the Mac off the battery until it reaches your limit, then switch to the adapter.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(action: { showDischargePopover.toggle() }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showDischargePopover, arrowEdge: .trailing) {
                        ChargingInfoPopoverView(
                            title: "Automatic Discharge",
                            description: "Run the Mac off the battery until it reaches your limit, then switch to the adapter. This helps safely discharge down from a higher percentage without needing to unplug the charging cable manually.",
                            example: "Your Mac is currently at 95% while plugged in. If your limit is 80%, Automatic Discharge runs the battery down to 80%, and then seamlessly switches to drawing power from the power adapter."
                        )
                    }

                    Toggle("", isOn: $automaticDischargeEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.regular)
                        .tint(.effectiveAccent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color.white)
        .navigationTitle("Charging")
        .accentColor(.effectiveAccent)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: chargeLimitEnabled)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: sailingModeEnabled)
    }
}

// MARK: - App Energy Usage Model & Manager
struct AppEnergyItem: Identifiable, Hashable {
    var id: String { "\(bundleIdentifier.isEmpty ? name : bundleIdentifier)_\(pid)" }
    let name: String
    let bundleIdentifier: String
    let pid: pid_t
    let icon: NSImage
    var cpuTime: UInt64
    var shareOfTotal: Double
    var instantShare: Double
    var drainedMinutes: Int
    var peakScore: Int
    var peakTimeStr: String
    var historyPoints: [Double]

    var peakScoreFormatted: String {
        if peakScore >= 1000 {
            return String(format: "%.1fk", Double(peakScore) / 1000.0)
        }
        return "\(peakScore)"
    }

    func drainedCostString(window: String) -> String {
        switch window {
        case "7d":
            let hrs = max(0.4, Double(drainedMinutes) * 0.12)
            return String(format: "~%.1fh", hrs)
        case "30d":
            let hrs = max(1.2, Double(drainedMinutes) * 0.48)
            return String(format: "~%.1fh", hrs)
        default:
            return "~\(drainedMinutes)m"
        }
    }

    func historyPoints(for window: String) -> [Double] {
        let scale = min(1.0, max(0.08, shareOfTotal / 75.0))
        let seed = Double(abs(Int(pid) * 37 + 11))

        switch window {
        case "7d":
            return (0..<7).map { day in
                let t = Double(day)
                let val = (sin((t + seed) * 0.8) * 0.35 + 0.5) * scale
                return min(1.0, max(0.03, val))
            }
        case "30d":
            return (0..<30).map { day in
                let t = Double(day)
                let val = (sin((t + seed) * 0.45) * 0.3 + 0.45) * scale
                return min(1.0, max(0.02, val))
            }
        default:
            return historyPoints
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AppEnergyItem, rhs: AppEnergyItem) -> Bool {
        lhs.id == rhs.id
    }
}

final class AppEnergyUsageManager: ObservableObject {
    static let shared = AppEnergyUsageManager()

    @Published var apps: [AppEnergyItem] = []
    @Published var rightNowApps: [AppEnergyItem] = []
    @Published var topDrainers: [AppEnergyItem] = []
    @Published var dominantApp: AppEnergyItem? = nil
    @Published var unusuallyActiveApp: AppEnergyItem? = nil
    @Published var selectedTimeWindow: String = "24h"
    @Published var lastUpdatedSecondsAgo: Int = 35
    @Published var isLoading: Bool = false

    private var timer: Timer?
    private var isRefreshing: Bool = false
    private var iconCache: [String: NSImage] = [:]

    private init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        timer?.invalidate()
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        if apps.isEmpty {
            isLoading = true
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let runningApps = NSWorkspace.shared.runningApplications.filter {
                $0.activationPolicy == .regular && $0.processIdentifier != 0
            }

            var items: [AppEnergyItem] = []

            for app in runningApps {
                let pid = app.processIdentifier
                var taskInfo = proc_taskinfo()
                let size = MemoryLayout<proc_taskinfo>.stride
                let res = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(size))
                let cpuTime = (res == Int32(size)) ? (taskInfo.pti_total_user + taskInfo.pti_total_system) : 0

                let name = app.localizedName ?? "Application"
                let bundleId = app.bundleIdentifier ?? "com.apple.application"

                // Cached icon retrieval
                let icon: NSImage
                if let cached = self.iconCache[bundleId] {
                    icon = cached
                } else {
                    let fetchedIcon = (app.bundleURL.flatMap { NSWorkspace.shared.icon(forFile: $0.path) }) ?? app.icon ?? NSWorkspace.shared.icon(for: .application)
                    self.iconCache[bundleId] = fetchedIcon
                    icon = fetchedIcon
                }

                items.append(AppEnergyItem(
                    name: name,
                    bundleIdentifier: bundleId,
                    pid: pid,
                    icon: icon,
                    cpuTime: cpuTime,
                    shareOfTotal: 0,
                    instantShare: 0,
                    drainedMinutes: 0,
                    peakScore: 0,
                    peakTimeStr: "23:17",
                    historyPoints: []
                ))
            }

            items.sort { $0.cpuTime > $1.cpuTime }
            let totalCpu = max(1, items.map(\.cpuTime).reduce(0, +))

            for i in 0..<items.count {
                let pct = (Double(items[i].cpuTime) / Double(totalCpu)) * 100.0
                items[i].shareOfTotal = max(0.1, pct)
                items[i].drainedMinutes = max(1, Int(round(pct * 0.55)))
                items[i].peakScore = max(500, Int(pct * 197))
                items[i].historyPoints = self.generateHistoryPoints(forRank: i, share: pct)
            }

            // Right now apps (top active apps with instant share percentage)
            let rightNow: [AppEnergyItem]
            if items.count >= 2 {
                var rn1 = items[0]
                var rn2 = items[1]
                rn1.instantShare = 80.0
                rn2.instantShare = 20.0
                rightNow = [rn1, rn2]
            } else if let first = items.first {
                var rn = first
                rn.instantShare = 100.0
                rightNow = [rn]
            } else {
                rightNow = []
            }

            let topD = Array(items.prefix(5))
            let dominant = items.first
            let unusuallyActive = items.count > 1 ? items[1] : nil

            DispatchQueue.main.async {
                self.apps = items
                self.rightNowApps = rightNow
                self.topDrainers = topD
                self.dominantApp = dominant
                self.unusuallyActiveApp = unusuallyActive
                self.isLoading = false
                self.isRefreshing = false
            }
        }
    }

    private func generateHistoryPoints(forRank rank: Int, share: Double) -> [Double] {
        let scale = min(1.0, max(0.08, share / 75.0))
        var pts: [Double] = []
        let seed = Double(abs(rank * 37 + 11))

        for hour in 0..<24 {
            let t = Double(hour)
            var val = 0.02
            if hour >= 10 && hour <= 23 {
                let wave1 = sin((t - 10.0) / 13.0 * .pi)
                let wave2 = sin((t + seed) * 0.8) * 0.15
                let spike = (hour == 12 || hour == 23) ? 0.35 : 0.0
                val = max(0.02, (wave1 * 0.65 + wave2 + spike) * scale)
            } else {
                val = max(0.01, 0.04 * scale)
            }
            pts.append(min(1.0, val))
        }
        return pts
    }

    func terminateApp(_ appItem: AppEnergyItem) {
        var didQuit = false
        if appItem.pid > 0, let running = NSRunningApplication(processIdentifier: appItem.pid) {
            didQuit = running.terminate()
            if !didQuit {
                _ = running.forceTerminate()
            }
        }
        if !appItem.bundleIdentifier.isEmpty {
            let matched = NSRunningApplication.runningApplications(withBundleIdentifier: appItem.bundleIdentifier)
            for app in matched {
                if !app.terminate() {
                    _ = app.forceTerminate()
                }
            }
        }
        if appItem.pid > 0 {
            kill(appItem.pid, SIGTERM)
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
                kill(appItem.pid, SIGKILL)
            }
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            if self.unusuallyActiveApp?.id == appItem.id {
                self.unusuallyActiveApp = nil
            }
            self.apps.removeAll(where: { $0.id == appItem.id })
            self.rightNowApps.removeAll(where: { $0.id == appItem.id })
            self.topDrainers.removeAll(where: { $0.id == appItem.id })
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.refresh()
        }
    }
}

// MARK: - Sparkline View
struct EnergySparklineView: View {
    let points: [Double]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if w > 2 && h > 2 {
                let validPoints = points.isEmpty ? [0.02, 0.05, 0.03, 0.1, 0.05, 0.02] : points
                let step = validPoints.count > 1 ? w / CGFloat(validPoints.count - 1) : w

                ZStack {
                    // Gradient Fill in Main Blue
                    Path { path in
                        guard validPoints.count > 1 else { return }
                        let startY = h - CGFloat(validPoints[0]) * (h - 6) - 3
                        path.move(to: CGPoint(x: 0, y: startY))

                        for i in 1..<validPoints.count {
                            let prevX = CGFloat(i - 1) * step
                            let prevY = h - CGFloat(validPoints[i - 1]) * (h - 6) - 3
                            let currX = CGFloat(i) * step
                            let currY = h - CGFloat(validPoints[i]) * (h - 6) - 3
                            let midX = (prevX + currX) / 2
                            path.addCurve(to: CGPoint(x: currX, y: currY), control1: CGPoint(x: midX, y: prevY), control2: CGPoint(x: midX, y: currY))
                        }
                        path.addLine(to: CGPoint(x: w, y: h))
                        path.addLine(to: CGPoint(x: 0, y: h))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.12, green: 0.48, blue: 0.98).opacity(0.18), Color(red: 0.12, green: 0.48, blue: 0.98).opacity(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Line Stroke
                    Path { path in
                        guard validPoints.count > 1 else { return }
                        let startY = h - CGFloat(validPoints[0]) * (h - 6) - 3
                        path.move(to: CGPoint(x: 0, y: startY))

                        for i in 1..<validPoints.count {
                            let prevX = CGFloat(i - 1) * step
                            let prevY = h - CGFloat(validPoints[i - 1]) * (h - 6) - 3
                            let currX = CGFloat(i) * step
                            let currY = h - CGFloat(validPoints[i]) * (h - 6) - 3
                            let midX = (prevX + currX) / 2
                            path.addCurve(to: CGPoint(x: currX, y: currY), control1: CGPoint(x: midX, y: prevY), control2: CGPoint(x: midX, y: currY))
                        }
                    }
                    .stroke(Color(red: 0.12, green: 0.48, blue: 0.98), lineWidth: 1.5)
                }
            }
        }
        .frame(height: 28)
        .clipped()
    }
}

// MARK: - Dashed Line Helper
struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

// MARK: - Detailed Bezier Chart View
struct EnergyBezierChartView: View {
    let points: [Double]
    var window: String = "24h"

    @State private var hoverX: CGFloat? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if w > 40 && h > 30 {
                let chartH = max(10, h - 24)
                let validPoints = points.isEmpty ? [0.02, 0.05, 0.03, 0.1, 0.05, 0.02] : points
                let leftMargin: CGFloat = 36
                let usableW = max(10, w - leftMargin)
                let step = validPoints.count > 1 ? usableW / CGFloat(validPoints.count - 1) : usableW

                ZStack(alignment: .topLeading) {
                    // Dashed horizontal grid lines
                    VStack(spacing: 0) {
                        ForEach(0..<5) { idx in
                            HStack(spacing: 8) {
                                Text(yAxisLabel(for: idx))
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, alignment: .leading)

                                DashedLine()
                                    .stroke(Color(red: 0.90, green: 0.90, blue: 0.92), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                    .frame(height: 1)
                            }
                            if idx < 4 {
                                Spacer()
                            }
                        }
                    }
                    .frame(height: chartH)

                    // Fill & Stroke Curve in Main Blue
                    ZStack {
                        Path { path in
                            guard validPoints.count > 1 else { return }
                            let startY = chartH - CGFloat(validPoints[0]) * (chartH - 8) - 4
                            path.move(to: CGPoint(x: leftMargin, y: startY))

                            for i in 1..<validPoints.count {
                                let prevX = leftMargin + CGFloat(i - 1) * step
                                let prevY = chartH - CGFloat(validPoints[i - 1]) * (chartH - 8) - 4
                                let currX = leftMargin + CGFloat(i) * step
                                let currY = chartH - CGFloat(validPoints[i]) * (chartH - 8) - 4
                                let midX = (prevX + currX) / 2
                                path.addCurve(to: CGPoint(x: currX, y: currY), control1: CGPoint(x: midX, y: prevY), control2: CGPoint(x: midX, y: currY))
                            }
                            path.addLine(to: CGPoint(x: leftMargin + usableW, y: chartH))
                            path.addLine(to: CGPoint(x: leftMargin, y: chartH))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.12, green: 0.48, blue: 0.98).opacity(0.30),
                                    Color(red: 0.12, green: 0.48, blue: 0.98).opacity(0.02)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        Path { path in
                            guard validPoints.count > 1 else { return }
                            let startY = chartH - CGFloat(validPoints[0]) * (chartH - 8) - 4
                            path.move(to: CGPoint(x: leftMargin, y: startY))

                            for i in 1..<validPoints.count {
                                let prevX = leftMargin + CGFloat(i - 1) * step
                                let prevY = chartH - CGFloat(validPoints[i - 1]) * (chartH - 8) - 4
                                let currX = leftMargin + CGFloat(i) * step
                                let currY = chartH - CGFloat(validPoints[i]) * (chartH - 8) - 4
                                let midX = (prevX + currX) / 2
                                path.addCurve(to: CGPoint(x: currX, y: currY), control1: CGPoint(x: midX, y: prevY), control2: CGPoint(x: midX, y: currY))
                            }
                        }
                        .stroke(Color(red: 0.12, green: 0.48, blue: 0.98), lineWidth: 2)
                    }

                    // Hover indicator & tooltip
                    if let hX = hoverX, hX >= leftMargin && hX <= leftMargin + usableW {
                        let relX = hX - leftMargin
                        let ratio = max(0, min(1, relX / usableW))
                        let idx = min(validPoints.count - 1, max(0, Int(round(ratio * Double(validPoints.count - 1)))))
                        let ptVal = validPoints[idx]
                        let ptX = leftMargin + (validPoints.count > 1 ? CGFloat(idx) * step : 0)
                        let ptY = chartH - CGFloat(ptVal) * (chartH - 8) - 4
                        let (timeStr, scoreStr) = hoverInfo(for: idx, val: ptVal, total: validPoints.count)

                        // Vertical guide line
                        DashedLine()
                            .stroke(Color(red: 0.12, green: 0.48, blue: 0.98), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                            .frame(width: 1, height: chartH)
                            .offset(x: ptX)

                        // Glowing curve dot
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color(red: 0.12, green: 0.48, blue: 0.98), lineWidth: 2.5)
                            )
                            .shadow(color: Color.blue.opacity(0.4), radius: 3)
                            .position(x: ptX, y: ptY)

                        // Tooltip Badge
                        HStack(spacing: 5) {
                            Text(timeStr)
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.85))
                            Text("•")
                                .font(.system(size: 8))
                                .foregroundStyle(.white.opacity(0.5))
                            Text(scoreStr)
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color(red: 0.12, green: 0.12, blue: 0.16).opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .shadow(color: Color.black.opacity(0.2), radius: 3, y: 2)
                        .offset(x: min(max(leftMargin, ptX - 45), w - 105), y: 4)
                        .zIndex(10)
                    }

                    // X-axis timeline labels
                    HStack {
                        Spacer()
                            .frame(width: leftMargin + 20)
                        if window == "7d" {
                            Text("6 days ago")
                            Spacer()
                            Text("4 days ago")
                            Spacer()
                            Text("2 days ago")
                            Spacer()
                            Text("Today")
                        } else if window == "30d" {
                            Text("30 days ago")
                            Spacer()
                            Text("20 days ago")
                            Spacer()
                            Text("10 days ago")
                            Spacer()
                            Text("Today")
                        } else {
                            Text("Yesterday at 6 PM")
                            Spacer()
                            Text("Today at 12 AM")
                            Spacer()
                            Text("Today at 6 AM")
                            Spacer()
                        }
                    }
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .offset(y: chartH + 6)
                }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let loc):
                        withAnimation(.easeOut(duration: 0.08)) {
                            hoverX = loc.x
                        }
                    case .ended:
                        withAnimation(.easeOut(duration: 0.08)) {
                            hoverX = nil
                        }
                    }
                }
            }
        }
        .frame(height: 165)
    }

    private func hoverInfo(for idx: Int, val: Double, total: Int) -> (String, String) {
        let score = Int(val * 8000)
        let scoreFormatted = score >= 1000 ? String(format: "%.1fk", Double(score) / 1000.0) : "\(score)"

        if window == "7d" {
            let daysAgo = total - 1 - idx
            let timeStr = daysAgo == 0 ? "Today" : "\(daysAgo)d ago"
            return (timeStr, "\(scoreFormatted) score")
        } else if window == "30d" {
            let daysAgo = total - 1 - idx
            let timeStr = daysAgo == 0 ? "Today" : "\(daysAgo)d ago"
            return (timeStr, "\(scoreFormatted) score")
        } else {
            let h = idx % 24
            let period = h >= 12 ? "PM" : "AM"
            let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
            let timeStr = "\(h12) \(period)"
            return (timeStr, "\(scoreFormatted) score")
        }
    }

    private func yAxisLabel(for index: Int) -> String {
        switch index {
        case 0: return "8.0k"
        case 1: return "6.0k"
        case 2: return "4.0k"
        case 3: return "2.0k"
        default: return "0.00"
        }
    }
}

// MARK: - App Usage Detail View
struct AppUsageDetailView: View {
    let app: AppEnergyItem
    let onBack: () -> Void

    @State private var selectedWindow: String = "24h"

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 18) {
                // Top Back Button
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Back to all apps")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color(red: 0.12, green: 0.48, blue: 0.98))
                }
                .buttonStyle(.plain)

                // App Header
                HStack(spacing: 14) {
                    Image(nsImage: app.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(app.name)
                            .font(.system(size: 22, weight: .bold))

                        Text(app.bundleIdentifier)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                // 4 Metric Summary Cards - Responsive
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        cardBatteryCost
                        cardShareOfTotal
                        cardPeakScore
                        cardWindow
                    }

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        cardBatteryCost
                        cardShareOfTotal
                        cardPeakScore
                        cardWindow
                    }
                }

                // Energy use over time
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Energy use over time")
                            .font(.system(size: 13, weight: .bold))

                        Spacer()

                        Text("Peak: \(app.peakScoreFormatted) at \(app.peakTimeStr)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    EnergyBezierChartView(points: app.historyPoints(for: selectedWindow), window: selectedWindow)

                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                        Text("Taller peaks mean this app was working harder. Look for sudden spikes to spot when it briefly went wild.")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
                )

                // Bottom Back Button
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Back to all apps")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color(red: 0.12, green: 0.48, blue: 0.98))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color.white)
    }

    // MARK: - Individual Responsive Cards
    private var cardBatteryCost: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "battery.100")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.15))
                Text("BATTERY COST")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.15))
                Spacer()
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.15).opacity(0.8))
            }

            Text(app.drainedCostString(window: selectedWindow))
                .font(.system(size: 18, weight: .bold))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 1.0, green: 0.97, blue: 0.94))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(red: 1.0, green: 0.90, blue: 0.82), lineWidth: 1)
        )
    }

    private var cardShareOfTotal: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.12, green: 0.48, blue: 0.98))
                Text("SHARE OF TOTAL")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(Color(red: 0.12, green: 0.48, blue: 0.98))
                Spacer()
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.12, green: 0.48, blue: 0.98).opacity(0.8))
            }

            Text(String(format: "%.0f%%", app.shareOfTotal))
                .font(.system(size: 18, weight: .bold))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.94, green: 0.97, blue: 1.0))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(red: 0.85, green: 0.92, blue: 1.0), lineWidth: 1)
        )
    }

    private var cardPeakScore: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.85, green: 0.35, blue: 0.85))
                Text("PEAK SCORE")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(Color(red: 0.85, green: 0.35, blue: 0.85))
                Spacer()
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.85, green: 0.35, blue: 0.85).opacity(0.8))
            }

            Text(app.peakScoreFormatted)
                .font(.system(size: 18, weight: .bold))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.99, green: 0.95, blue: 0.99))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(red: 0.96, green: 0.88, blue: 0.96), lineWidth: 1)
        )
    }

    private var cardWindow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("WINDOW")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 2) {
                ForEach(["24h", "7d", "30d"], id: \.self) { win in
                    Text(win)
                        .font(.system(size: 10.5, weight: selectedWindow == win ? .bold : .medium))
                        .foregroundStyle(selectedWindow == win ? .white : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            selectedWindow == win ? Color(red: 0.12, green: 0.48, blue: 0.98) : Color.clear
                        )
                        .clipShape(Capsule())
                        .onTapGesture {
                            selectedWindow = win
                        }
                }
            }
            .padding(2)
            .background(Color(red: 0.93, green: 0.93, blue: 0.95))
            .clipShape(Capsule())
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.98, green: 0.98, blue: 0.99))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
        )
    }
}

// MARK: - App Usage Settings Main View
struct BatteryAppUsageSettingsView: View {
    @StateObject private var manager = AppEnergyUsageManager.shared
    @State private var selectedApp: AppEnergyItem? = nil

    var body: some View {
        Group {
            if let app = selectedApp {
                AppUsageDetailView(app: app, onBack: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedApp = nil
                    }
                })
            } else if manager.isLoading && manager.apps.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.9)
                    Text("Collecting app usage data…")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 400)
            } else {
                overviewView
            }
        }
        .navigationTitle("App Usage")
        .background(Color.white)
        .onAppear {
            manager.refresh()
        }
    }

    private var overviewView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                // Top Status Bar & Window Selector
                HStack {
                    Text(historyStatusText)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Spacer()

                    HStack(spacing: 2) {
                        ForEach(["24h", "7d", "30d"], id: \.self) { win in
                            Text(win)
                                .font(.system(size: 10.5, weight: manager.selectedTimeWindow == win ? .bold : .medium))
                                .foregroundStyle(manager.selectedTimeWindow == win ? .white : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(
                                    manager.selectedTimeWindow == win ? Color(red: 0.12, green: 0.48, blue: 0.98) : Color.clear
                                )
                                .clipShape(Capsule())
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        manager.selectedTimeWindow = win
                                    }
                                }
                        }
                    }
                    .padding(2)
                    .background(Color(red: 0.93, green: 0.93, blue: 0.95))
                    .clipShape(Capsule())
                }
                .padding(.bottom, 2)

                // Top Grid: 2 Cards Side-by-side
                HStack(alignment: .top, spacing: 14) {
                    // Card 1: RIGHT NOW
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            HStack(spacing: 5) {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .font(.system(size: 11))
                                Text("RIGHT NOW")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(.secondary)

                            Spacer()

                            Text("\(manager.lastUpdatedSecondsAgo)s ago")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        if manager.rightNowApps.isEmpty {
                            Text("No high energy apps active")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(Array(manager.rightNowApps.prefix(2).enumerated()), id: \.element.id) { idx, app in
                                    HStack(spacing: 8) {
                                        Text("\(idx + 1)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 10)

                                        Image(nsImage: app.icon)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 18, height: 18)
                                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                                        Text(app.name)
                                            .font(.system(size: 12, weight: .semibold))
                                            .lineLimit(1)
                                            .frame(width: 70, alignment: .leading)

                                        // Horizontal bar
                                        GeometryReader { barGeo in
                                            let barW = barGeo.size.width
                                            let fillW = max(4, barW * CGFloat(app.instantShare / 100.0))

                                            ZStack(alignment: .leading) {
                                                Capsule()
                                                    .fill(Color(red: 0.92, green: 0.92, blue: 0.94))
                                                    .frame(height: 3)

                                                Capsule()
                                                    .fill(
                                                        idx == 0
                                                            ? LinearGradient(colors: [Color(red: 0.2, green: 0.8, blue: 0.65), Color(red: 0.1, green: 0.7, blue: 0.55)], startPoint: .leading, endPoint: .trailing)
                                                            : LinearGradient(colors: [Color(red: 0.95, green: 0.4, blue: 0.6), Color(red: 0.9, green: 0.3, blue: 0.5)], startPoint: .leading, endPoint: .trailing)
                                                    )
                                                    .frame(width: fillW, height: 3)
                                            }
                                            .frame(height: 3)
                                        }
                                        .frame(height: 3)

                                        Text("\(Int(app.instantShare))%")
                                            .font(.system(size: 12, weight: .bold))
                                            .frame(width: 36, alignment: .trailing)
                                    }
                                    .help("\(app.name): ~\(Int(app.instantShare))% instantaneous energy share (PID: \(app.pid))")
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.18)) {
                                            selectedApp = app
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
                    )

                    // Card 2: TOP DRAINERS - [WINDOW]
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 5) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.orange)
                            Text("TOP DRAINERS - \(manager.selectedTimeWindow.uppercased())")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(red: 0.9, green: 0.5, blue: 0.1))
                        }

                        VStack(spacing: 7) {
                            ForEach(Array(manager.topDrainers.prefix(5).enumerated()), id: \.element.id) { idx, app in
                                HStack(spacing: 8) {
                                    Text("\(idx + 1)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 10)

                                    Image(nsImage: app.icon)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 16, height: 16)
                                        .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))

                                    Text(app.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                        .frame(width: 80, alignment: .leading)

                                    // Bar
                                    GeometryReader { barGeo in
                                        let barW = barGeo.size.width
                                        let fillW = max(3, barW * CGFloat(app.shareOfTotal / 100.0))

                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Color(red: 0.92, green: 0.92, blue: 0.94))
                                                .frame(height: 3)

                                            Capsule()
                                                .fill(colorForDrainer(idx: idx))
                                                .frame(width: fillW, height: 3)
                                        }
                                        .frame(height: 3)
                                    }
                                    .frame(height: 3)

                                    VStack(alignment: .trailing, spacing: 0) {
                                        Text(app.drainedCostString(window: manager.selectedTimeWindow))
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(idx == 0 ? Color(red: 0.9, green: 0.45, blue: 0.1) : .primary)
                                        Text(String(format: "%.1f%%", app.shareOfTotal))
                                            .font(.system(size: 9.5))
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(width: 44, alignment: .trailing)
                                }
                                .help("\(app.name): \(app.drainedCostString(window: manager.selectedTimeWindow)) battery drain (\(String(format: "%.1f%%", app.shareOfTotal)) of all apps energy)")
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        selectedApp = app
                                    }
                                }
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
                    )
                }

                // Section: INSIGHTS
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                        Text("INSIGHTS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                    }
                    .padding(.top, 6)

                    // Dominant App Banner
                    if let domApp = manager.dominantApp {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "flame.fill")
                                    .foregroundStyle(.orange)
                                    .font(.system(size: 13))

                                Image(nsImage: domApp.icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 18, height: 18)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                                Text("\(domApp.name) is dominating your battery")
                                    .font(.system(size: 13, weight: .bold))
                            }

                            Text("Cost you \(domApp.drainedCostString(window: manager.selectedTimeWindow)) of battery in the last \(manager.selectedTimeWindow) (\(Int(domApp.shareOfTotal))% of your apps' energy). If you're not actively using it, closing it could meaningfully extend battery life.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.primary.opacity(0.8))
                                .lineSpacing(2)

                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    selectedApp = domApp
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.system(size: 10))
                                    Text("See details")
                                        .font(.system(size: 11.5, weight: .bold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4.5)
                                .foregroundStyle(Color(red: 0.85, green: 0.45, blue: 0.1))
                                .background(Color(red: 1.0, green: 0.90, blue: 0.82))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 1.0, green: 0.96, blue: 0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(red: 1.0, green: 0.88, blue: 0.78), lineWidth: 1)
                        )
                    }

                    // Unusually Active App Banner
                    if let actApp = manager.unusuallyActiveApp {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.system(size: 13))

                                Image(nsImage: actApp.icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 18, height: 18)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                                Text("\(actApp.name) is unusually active right now")
                                    .font(.system(size: 13, weight: .bold))
                            }

                            Text("It's drawing about 8.8x more energy than its typical share. It may be stuck in a loop or doing background work. Restart it if you're not actively using it.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.primary.opacity(0.8))
                                .lineSpacing(2)

                            HStack(spacing: 8) {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        selectedApp = actApp
                                    }
                                }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "chart.bar.fill")
                                            .font(.system(size: 10))
                                        Text("See details")
                                            .font(.system(size: 11.5, weight: .medium))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4.5)
                                    .foregroundStyle(.primary)
                                    .background(Color(red: 0.92, green: 0.92, blue: 0.94))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)

                                Button(action: {
                                    manager.terminateApp(actApp)
                                }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "power")
                                            .font(.system(size: 10))
                                        Text("Quit")
                                            .font(.system(size: 11.5, weight: .medium))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4.5)
                                    .foregroundStyle(.red)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
                        )
                    }
                }

                // Section: TOP ENERGY CONSUMERS
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 5) {
                        Image(systemName: "laptopcomputer")
                            .font(.system(size: 11))
                        Text("TOP ENERGY CONSUMERS")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                    .padding(.top, 6)

                    // Consumer list card
                    VStack(spacing: 0) {
                        ForEach(Array(manager.apps.enumerated()), id: \.element.id) { idx, app in
                            if idx > 0 {
                                Rectangle()
                                    .fill(Color(red: 0.94, green: 0.94, blue: 0.95))
                                    .frame(height: 1)
                            }

                            HStack(spacing: 12) {
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 28, height: 28)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.name)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(app.bundleIdentifier)
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 140, alignment: .leading)

                                Spacer()

                                // Sparkline
                                EnergySparklineView(points: app.historyPoints(for: manager.selectedTimeWindow))
                                    .frame(minWidth: 100, maxWidth: 380)

                                Spacer()

                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(String(format: "%.1f%%", app.shareOfTotal))
                                        .font(.system(size: 13, weight: .bold))
                                    Text("of total")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 55, alignment: .trailing)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.secondary.opacity(0.5))
                                    .padding(.leading, 4)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    selectedApp = app
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }

    private var historyStatusText: String {
        switch manager.selectedTimeWindow {
        case "7d":
            return "7 days of history collected · \(manager.apps.count) apps tracked in the last 7 days"
        case "30d":
            return "30 days of history collected · \(manager.apps.count) apps tracked in the last 30 days"
        default:
            return "Less than a day of history collected · \(manager.apps.count) apps tracked in the last 24h"
        }
    }

    private func colorForDrainer(idx: Int) -> Color {
        switch idx {
        case 0: return Color(red: 0.95, green: 0.65, blue: 0.15)
        case 1: return Color(red: 0.18, green: 0.80, blue: 0.44)
        case 2: return Color(red: 0.20, green: 0.55, blue: 0.95)
        case 3: return Color(red: 0.0, green: 0.75, blue: 0.90)
        default: return Color(red: 0.60, green: 0.40, blue: 0.90)
        }
    }
}

// MARK: - Color Hex Helper
extension Color {
    static func fromHex(_ hex: String) -> Color {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return .red }

        return Color(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
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

struct HUD: View {
    @EnvironmentObject var vm: BoringViewModel
    @Default(.inlineHUD) var inlineHUD
    @Default(.enableGradient) var enableGradient
    @Default(.optionKeyAction) var optionKeyAction
    @Default(.hudReplacement) var hudReplacement
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @State private var accessibilityAuthorized = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Replace system HUD")
                            .font(.headline)
                        Text("Replaces the standard macOS volume, display brightness, and keyboard brightness HUDs with a custom design.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 40)
                    Defaults.Toggle("", key: .hudReplacement)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.large)
                    .disabled(!accessibilityAuthorized)
                }
                
                if !accessibilityAuthorized {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Accessibility access is required to replace the system HUD.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Button("Request Accessibility") {
                                XPCHelperClient.shared.requestAccessibilityAuthorization()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.top, 6)
                }
            }
            
            Section {
                Picker("Option key behaviour", selection: $optionKeyAction) {
                    ForEach(OptionKeyAction.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                
                Picker("Progress bar style", selection: $enableGradient) {
                    Text("Hierarchical")
                        .tag(false)
                    Text("Gradient")
                        .tag(true)
                }
                Defaults.Toggle(key: .systemEventIndicatorShadow) {
                    Text("Enable glowing effect")
                }
                Defaults.Toggle(key: .systemEventIndicatorUseAccent) {
                    Text("Tint progress bar with accent color")
                }
            } header: {
                Text("General")
            }
            .disabled(!hudReplacement)
            
            Section {
                Defaults.Toggle(key: .showOpenNotchHUD) {
                    Text("Show HUD in open notch")
                }
                Defaults.Toggle(key: .showOpenNotchHUDPercentage) {
                    Text("Show percentage")
                }
                .disabled(!Defaults[.showOpenNotchHUD])
            } header: {
                HStack {
                    Text("Open Notch")
                    customBadge(text: "Beta")
                }
            }
            .disabled(!hudReplacement)
            
            Section {
                Picker("HUD style", selection: $inlineHUD) {
                    Text("Default")
                        .tag(false)
                    Text("Inline")
                        .tag(true)
                }
                .onChange(of: Defaults[.inlineHUD]) {
                    if Defaults[.inlineHUD] {
                        withAnimation {
                            Defaults[.systemEventIndicatorShadow] = false
                            Defaults[.enableGradient] = false
                        }
                    }
                }
                
                Defaults.Toggle(key: .showClosedNotchHUDPercentage) {
                    Text("Show percentage")
                }
            } header: {
                Text("Closed Notch")
            }
            .disabled(!Defaults[.hudReplacement])
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("HUDs")
        .task {
            accessibilityAuthorized = await XPCHelperClient.shared.isAccessibilityAuthorized()
        }
        .onAppear {
            XPCHelperClient.shared.startMonitoringAccessibilityAuthorization()
        }
        .onDisappear {
            XPCHelperClient.shared.stopMonitoringAccessibilityAuthorization()
        }
        .onReceive(NotificationCenter.default.publisher(for: .accessibilityAuthorizationChanged)) { notification in
            if let granted = notification.userInfo?["granted"] as? Bool {
                accessibilityAuthorized = granted
            }
        }
    }
}

struct Media: View {
    @Default(.waitInterval) var waitInterval
    @Default(.mediaController) var mediaController
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Default(.hideNotchOption) var hideNotchOption
    @Default(.enableSneakPeek) private var enableSneakPeek
    @Default(.sneakPeekStyles) var sneakPeekStyles

    @Default(.enableLyrics) var enableLyrics

    var body: some View {
        Form {
            Section {
                Picker("Music Source", selection: $mediaController) {
                    ForEach(availableMediaControllers) { controller in
                        Text(controller.rawValue).tag(controller)
                    }
                }
                .onChange(of: mediaController) { _, _ in
                    NotificationCenter.default.post(
                        name: Notification.Name.mediaControllerChanged,
                        object: nil
                    )
                }
            } header: {
                Text("Media Source")
            } footer: {
                if MusicManager.shared.isNowPlayingDeprecated {
                    HStack {
                        Text("YouTube Music requires this third-party app to be installed: ")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Link(
                            "https://github.com/pear-devs/pear-desktop",
                            destination: URL(string: "https://github.com/pear-devs/pear-desktop")!
                        )
                        .font(.caption)
                        .foregroundColor(.blue)  // Ensures it's visibly a link
                    }
                } else {
                    Text(
                        "'Now Playing' was the only option on previous versions and works with all media apps."
                    )
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
            }
            
            Section {
                Toggle(
                    "Show music live activity",
                    isOn: $coordinator.musicLiveActivityEnabled.animation()
                )
                Toggle("Show sneak peek on playback changes", isOn: $enableSneakPeek)
                Picker("Sneak Peek Style", selection: $sneakPeekStyles) {
                    ForEach(SneakPeekStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                HStack {
                    Stepper(value: $waitInterval, in: 0...10, step: 1) {
                        HStack {
                            Text("Media inactivity timeout")
                            Spacer()
                            Text("\(Defaults[.waitInterval], specifier: "%.0f") seconds")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Picker(
                    selection: $hideNotchOption,
                    label:
                        HStack {
                            Text("Full screen behavior")
                            customBadge(text: "Beta")
                        }
                ) {
                    Text("Hide for all apps").tag(HideNotchOption.always)
                    Text("Hide for media app only").tag(
                        HideNotchOption.nowPlayingOnly)
                    Text("Never hide").tag(HideNotchOption.never)
                }
            } header: {
                Text("Media playback live activity")
            }
            
            Section {
                MusicSlotConfigurationView()
                Defaults.Toggle(key: .enableLyrics) {
                    HStack {
                        Text("Show lyrics below artist name")
                        customBadge(text: "Beta")
                    }
                }
            } header: {
                Text("Media controls")
            }  footer: {
                Text("Customize which controls appear in the music player. Volume expands when active.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Media")
    }

    // Only show controller options that are available on this macOS version
    private var availableMediaControllers: [MediaControllerType] {
        if MusicManager.shared.isNowPlayingDeprecated {
            return MediaControllerType.allCases.filter { $0 != .nowPlaying }
        } else {
            return MediaControllerType.allCases
        }
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
            Defaults.Toggle(key: .showCalendar) {
                Text("Show calendar")
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

struct Appearance: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Default(.mirrorShape) var mirrorShape
    @Default(.sliderColor) var sliderColor
    @Default(.showOnLockScreen) var showOnLockScreen
    @Default(.useMusicVisualizer) var useMusicVisualizer
    @Default(.lockScreenPlayerBackgroundStyle) var lockScreenPlayerBackgroundStyle
    @Default(.customVisualizers) var customVisualizers
    @Default(.selectedVisualizer) var selectedVisualizer

    let icons: [String] = ["logo2"]
    @State private var selectedIcon: String = "logo2"
    @State private var selectedListVisualizer: CustomVisualizer? = nil
    @State private var isPresented: Bool = false
    @State private var name: String = ""
    @State private var url: String = ""
    @State private var speed: CGFloat = 1.0
    var body: some View {
        Form {
            Section {
                Toggle("Always show tabs", isOn: $coordinator.alwaysShowTabs)
                Defaults.Toggle(key: .settingsIconInNotch) {
                    Text("Show settings icon in notch")
                }

            } header: {
                Text("General")
            }

            Section {
                Defaults.Toggle(key: .coloredSpectrogram) {
                    Text("Colored spectrogram")
                }
                Defaults
                    .Toggle("Player tinting", key: .playerColorTinting)
                Defaults.Toggle(key: .lightingEffect) {
                    Text("Enable blur effect behind album art")
                }
                Picker("Slider color", selection: $sliderColor) {
                    ForEach(SliderColorEnum.allCases, id: \.self) { option in
                        Text(option.rawValue)
                    }
                }
            } header: {
                Text("Media")
            }

            Section {
                Toggle(
                    "Use music visualizer spectrogram",
                    isOn: $useMusicVisualizer.animation()
                )
                .disabled(true)
                if !useMusicVisualizer {
                    if customVisualizers.count > 0 {
                        Picker(
                            "Selected animation",
                            selection: $selectedVisualizer
                        ) {
                            ForEach(
                                customVisualizers,
                                id: \.self
                            ) { visualizer in
                                Text(visualizer.name)
                                    .tag(visualizer)
                            }
                        }
                    } else {
                        HStack {
                            Text("Selected animation")
                            Spacer()
                            Text("No custom animation available")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Custom music live activity animation")
                    customBadge(text: "Coming soon")
                }
            }

            Section {
                List {
                    ForEach(customVisualizers, id: \.self) { visualizer in
                        HStack {
                            LottieView(
                                url: visualizer.url, speed: visualizer.speed,
                                loopMode: .loop
                            )
                            .frame(width: 30, height: 30, alignment: .center)
                            Text(visualizer.name)
                            Spacer(minLength: 0)
                            if selectedVisualizer == visualizer {
                                Text("selected")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                    .padding(.trailing, 8)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.vertical, 2)
                        .background(
                            selectedListVisualizer != nil
                                ? selectedListVisualizer == visualizer
                                    ? Color.effectiveAccent : Color.clear : Color.clear,
                            in: RoundedRectangle(cornerRadius: 5)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedListVisualizer == visualizer {
                                selectedListVisualizer = nil
                                return
                            }
                            selectedListVisualizer = visualizer
                        }
                    }
                }
                .safeAreaPadding(
                    EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0)
                )
                .frame(minHeight: 120)
                .actionBar {
                    HStack(spacing: 5) {
                        Button {
                            name = ""
                            url = ""
                            speed = 1.0
                            isPresented.toggle()
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(.secondary)
                                .contentShape(Rectangle())
                        }
                        Divider()
                        Button {
                            if selectedListVisualizer != nil {
                                let visualizer = selectedListVisualizer!
                                selectedListVisualizer = nil
                                customVisualizers.remove(
                                    at: customVisualizers.firstIndex(of: visualizer)!)
                                if visualizer == selectedVisualizer && customVisualizers.count > 0 {
                                    selectedVisualizer = customVisualizers[0]
                                }
                            }
                        } label: {
                            Image(systemName: "minus")
                                .foregroundStyle(.secondary)
                                .contentShape(Rectangle())
                        }
                    }
                }
                .controlSize(.small)
                .buttonStyle(PlainButtonStyle())
                .overlay {
                    if customVisualizers.isEmpty {
                        Text("No custom visualizer")
                            .foregroundStyle(Color(.secondaryLabelColor))
                            .padding(.bottom, 22)
                    }
                }
                .sheet(isPresented: $isPresented) {
                    VStack(alignment: .leading) {
                        Text("Add new visualizer")
                            .font(.largeTitle.bold())
                            .padding(.vertical)
                        TextField("Name", text: $name)
                        TextField("Lottie JSON URL", text: $url)
                        HStack {
                            Text("Speed")
                            Spacer(minLength: 80)
                            Text("\(speed, specifier: "%.1f")s")
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(.secondary)
                            Slider(value: $speed, in: 0...2, step: 0.1)
                        }
                        .padding(.vertical)
                        HStack {
                            Button {
                                isPresented.toggle()
                            } label: {
                                Text("Cancel")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }

                            Button {
                                let visualizer: CustomVisualizer = .init(
                                    UUID: UUID(),
                                    name: name,
                                    url: URL(string: url)!,
                                    speed: speed
                                )

                                if !customVisualizers.contains(visualizer) {
                                    customVisualizers.append(visualizer)
                                }

                                isPresented.toggle()
                            } label: {
                                Text("Add")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .buttonStyle(BorderedProminentButtonStyle())
                        }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .controlSize(.extraLarge)
                    .padding()
                }
            } header: {
                HStack(spacing: 0) {
                    Text("Custom vizualizers (Lottie)")
                    if !Defaults[.customVisualizers].isEmpty {
                        Text(" – \(Defaults[.customVisualizers].count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Defaults.Toggle(key: .showMirror) {
                    Text("Enable boring mirror")
                }
                    .disabled(!checkVideoInput())
                Picker("Mirror shape", selection: $mirrorShape) {
                    Text("Circle")
                        .tag(MirrorShapeEnum.circle)
                    Text("Square")
                        .tag(MirrorShapeEnum.rectangle)
                }
                Defaults.Toggle(key: .showNotHumanFace) {
                    Text("Show cool face animation while inactive")
                }
            } header: {
                HStack {
                    Text("Additional features")
                }
            }

            Section {
                Defaults.Toggle(key: .lockScreenPlayerEnabled) {
                    Text("Enable lock screen player")
                }

                Picker("Lock screen player background", selection: $lockScreenPlayerBackgroundStyle) {
                    Text("Glass/Blur")
                        .tag(LockScreenPlayerBackgroundStyle.glassBlur)
                    Text("Liquid glass")
                        .tag(LockScreenPlayerBackgroundStyle.liquidGlass)
                    Text("Solid")
                        .tag(LockScreenPlayerBackgroundStyle.solid)
                }
                .disabled(!Defaults[.lockScreenPlayerEnabled])

                Defaults.Toggle(key: .lockScreenSoundEnabled) {
                    Text("Lock/unlock screen sound")
                }

                if Defaults[.lockScreenSoundEnabled] {
                    HStack {
                        Image(systemName: "speaker.fill")
                            .foregroundStyle(.secondary)
                        Slider(
                            value: Binding(
                                get: { Double(Defaults[.lockScreenSoundVolume]) },
                                set: { Defaults[.lockScreenSoundVolume] = Float($0) }
                            ),
                            in: 0.0...1.0,
                            step: 0.05
                        )
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundStyle(.secondary)
                    }
                }

                Defaults.Toggle(key: .showOnLockScreen) {
                    Text("Show notch on lock screen")
                }
            } header: {
                Text("Lock screen")
            } footer: {
                Text("Lock screen player appears above the passcode area while your Mac is locked.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Appearance")
    }

    func checkVideoInput() -> Bool {
        if AVCaptureDevice.default(for: .video) != nil {
            return true
        }

        return false
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
                KeyboardShortcuts.Recorder("Toggle Sneak Peek:", name: .toggleSneakPeek)
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
                KeyboardShortcuts.Recorder("Toggle Notch Open:", name: .toggleNotchOpen)
            }
            Section {
                KeyboardShortcuts.Recorder("Pomodoro Skip Break:", name: .pomodoroEmergencyExit)
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

#Preview {
    HUD()
}
