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

struct SettingsView: View {
    @State private var selectedTab = "General"
    @State private var isBatteryExpanded = true
    @State private var accentColorUpdateTrigger = UUID()

    let updaterController: SPUStandardUpdaterController?

    init(updaterController: SPUStandardUpdaterController? = nil) {
        self.updaterController = updaterController
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Group {
                    NavigationLink(value: "General") {
                        Label("General", systemImage: "gear")
                    }
                    NavigationLink(value: "Appearance") {
                        Label("Appearance", systemImage: "eye")
                    }
                    NavigationLink(value: "Media") {
                        Label("Media", systemImage: "play.laptopcomputer")
                    }
                    NavigationLink(value: "Calendar") {
                        Label("Calendar", systemImage: "calendar")
                    }
                    NavigationLink(value: "HUD") {
                        Label("HUDs", systemImage: "dial.medium.fill")
                    }
                }

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isBatteryExpanded.toggle()
                    }
                }) {
                    HStack {
                        Label("Battery", systemImage: "battery.100.bolt")
                        Spacer()
                        Image(systemName: isBatteryExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isBatteryExpanded {
                    NavigationLink(value: "Battery_General") {
                        Label("General", systemImage: "slider.horizontal.3")
                    }
                    .padding(.leading, 12)
                    NavigationLink(value: "Battery_Alerts") {
                        Label("Alerts", systemImage: "bell.badge")
                    }
                    .padding(.leading, 12)
                    NavigationLink(value: "Battery_Charging") {
                        Label("Charging", systemImage: "bolt.fill")
                    }
                    .padding(.leading, 12)
                    NavigationLink(value: "Battery_AppUsage") {
                        Label("App Usage", systemImage: "chart.bar.xaxis")
                    }
                    .padding(.leading, 12)
                }

                Group {
                    NavigationLink(value: "Shelf") {
                        Label("Shelf", systemImage: "books.vertical")
                    }
                    NavigationLink(value: "Pomodoro") {
                        Label("Pomodoro", systemImage: "timer")
                    }
                    NavigationLink(value: "Shortcuts") {
                        Label("Shortcuts", systemImage: "keyboard")
                    }
                    NavigationLink(value: "Advanced") {
                        Label("Advanced", systemImage: "gearshape.2")
                    }
                    NavigationLink(value: "About") {
                        Label("About", systemImage: "info.circle")
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .scrollContentBackground(.hidden)
            .background(Color(red: 245/255, green: 245/255, blue: 245/255))
            .tint(.effectiveAccent)
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(min: 190, ideal: 200, max: 210)
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

                appearanceCard
                lowBatterySection
                chargedAlertCard
                customSoundsCard
                resetCard
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color.white)
        .accentColor(.effectiveAccent)
        .navigationTitle("Alerts")
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
                                .controlSize(.small)
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
                                .controlSize(.small)
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

// MARK: - General Battery Settings
struct BatteryGeneralSettingsView: View {
    @Default(.batteryAlertsEnabled) private var batteryAlertsEnabled
    @Default(.showBatteryIndicator) private var showBatteryIndicator
    @Default(.showPowerStatusNotifications) private var showPowerStatusNotifications
    @Default(.showBatteryPercentage) private var showBatteryPercentage
    @Default(.showPowerStatusIcons) private var showPowerStatusIcons

    @ObservedObject private var batteryModel = BatteryStatusViewModel.shared

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Manage battery health notifications, power status, and notch display indicators.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.48))
                    .padding(.bottom, 4)

                // Card 1: Master Switch
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.green.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Battery Notifications & Glow")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Enable real-time alerts and dynamic screen edge glow when thresholds are hit.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: $batteryAlertsEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
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

                // Card 2: Live Battery Status
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.blue.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Image(systemName: "battery.100.bolt")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(red: 0.0, green: 0.55, blue: 0.95))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Battery Status")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Current hardware power metrics and power saving state.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Rectangle()
                        .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                        .frame(height: 1)

                    // Battery Level Row
                    HStack(spacing: 10) {
                        Image(systemName: batteryModel.levelBattery <= 20 ? "battery.25" : (batteryModel.levelBattery <= 50 ? "battery.50" : "battery.100"))
                            .font(.system(size: 14))
                            .foregroundStyle(batteryModel.levelBattery <= 20 ? Color.red : Color(red: 0.18, green: 0.80, blue: 0.44))
                            .frame(width: 20)

                        Text("Battery Level")
                            .font(.system(size: 13))

                        Spacer()

                        Text("\(Int(batteryModel.levelBattery))%")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(batteryModel.levelBattery <= 20 ? Color.red : Color(red: 0.12, green: 0.65, blue: 0.32))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(
                                (batteryModel.levelBattery <= 20 ? Color.red : Color.green).opacity(0.12)
                            )
                            .clipShape(Capsule())
                    }

                    Rectangle()
                        .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                        .frame(height: 1)

                    // Power Status Row
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.orange)
                            .frame(width: 20)

                        Text("Power Source")
                            .font(.system(size: 13))

                        Spacer()

                        Text(batteryModel.isCharging ? "Charging" : (batteryModel.isPluggedIn ? "Power Adapter (Not Charging)" : "Battery Power"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Rectangle()
                        .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                        .frame(height: 1)

                    // Low Power Mode Row
                    HStack(spacing: 10) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))
                            .frame(width: 20)

                        Text("Low Power Mode")
                            .font(.system(size: 13))

                        Spacer()

                        Text(batteryModel.isInLowPowerMode ? "Enabled" : "Disabled")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
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

                // Card 3: Notch Display Indicators
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.purple.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Image(systemName: "rectangle.inset.topleading.filled")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(red: 0.48, green: 0.38, blue: 0.9))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notch Display Indicators")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Choose which battery elements appear directly inside the notch wing area.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Rectangle()
                        .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                        .frame(height: 1)

                    // Row 1
                    HStack {
                        Text("Show battery indicator in notch")
                            .font(.system(size: 13))
                        Spacer()
                        Toggle("", isOn: $showBatteryIndicator)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }

                    Rectangle()
                        .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                        .frame(height: 1)

                    // Row 2
                    HStack {
                        Text("Show power status notifications")
                            .font(.system(size: 13))
                        Spacer()
                        Toggle("", isOn: $showPowerStatusNotifications)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }

                    Rectangle()
                        .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                        .frame(height: 1)

                    // Row 3
                    HStack {
                        Text("Show battery percentage")
                            .font(.system(size: 13))
                        Spacer()
                        Toggle("", isOn: $showBatteryPercentage)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }

                    Rectangle()
                        .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                        .frame(height: 1)

                    // Row 4
                    HStack {
                        Text("Show power status icons")
                            .font(.system(size: 13))
                        Spacer()
                        Toggle("", isOn: $showPowerStatusIcons)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color.white)
        .accentColor(.effectiveAccent)
        .navigationTitle("General")
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
                            .controlSize(.small)
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
                                .controlSize(.small)
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
                            .controlSize(.small)
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

// MARK: - App Usage Settings
struct BatteryAppUsageSettingsView: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Monitor applications and background tasks using significant energy.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.48))
                    .padding(.bottom, 4)

                // Card 1: Apps Using Significant Energy
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.orange.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Image(systemName: "bolt.badge.clock.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.orange)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apps Using Significant Energy")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Applications that are currently having a noticeable impact on battery life.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Rectangle()
                        .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                        .frame(height: 1)

                    // Xcode
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.blue.opacity(0.12))
                                .frame(width: 26, height: 26)
                            Image(systemName: "hammer.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.blue)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Xcode")
                                .font(.system(size: 13, weight: .medium))
                            Text("Active indexing & Swift compiler")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("High Energy")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(Color(red: 0.9, green: 0.5, blue: 0.1))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Color(red: 1.0, green: 0.94, blue: 0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }

                    Rectangle()
                        .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                        .frame(height: 1)

                    // Safari
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.blue.opacity(0.12))
                                .frame(width: 26, height: 26)
                            Image(systemName: "safari.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.blue)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Safari")
                                .font(.system(size: 13, weight: .medium))
                            Text("Active web pages and media tabs")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("Normal")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Color(red: 0.12, green: 0.65, blue: 0.32))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Color(red: 0.88, green: 0.96, blue: 0.90))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }

                    Rectangle()
                        .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                        .frame(height: 1)

                    // Music
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.red.opacity(0.12))
                                .frame(width: 26, height: 26)
                            Image(systemName: "music.note")
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Music")
                                .font(.system(size: 13, weight: .medium))
                            Text("Audio output playback")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("Low")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Color(red: 0.92, green: 0.92, blue: 0.94))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }

                    Rectangle()
                        .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                        .frame(height: 1)

                    // Terminal
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.gray.opacity(0.12))
                                .frame(width: 26, height: 26)
                            Image(systemName: "terminal.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.primary)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Terminal")
                                .font(.system(size: 13, weight: .medium))
                            Text("Shell sessions & background utilities")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("Low")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Color(red: 0.92, green: 0.92, blue: 0.94))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
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

                // Card 2: Energy Recommendations
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.green.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Energy Recommendations")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Quick adjustments to maximize battery longevity during daily usage.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Rectangle()
                        .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                        .frame(height: 1)

                    HStack(spacing: 10) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.orange)
                            .frame(width: 18)
                        Text("Reduce display brightness by 10–20% when working on battery")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Rectangle()
                        .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                        .frame(height: 1)

                    HStack(spacing: 10) {
                        Image(systemName: "macwindow.badge.plus")
                            .font(.system(size: 13))
                            .foregroundStyle(.blue)
                            .frame(width: 18)
                        Text("Close unused browser tabs running continuous animations or video")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Rectangle()
                        .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                        .frame(height: 1)

                    HStack(spacing: 10) {
                        Image(systemName: "powersleep")
                            .font(.system(size: 13))
                            .foregroundStyle(.purple)
                            .frame(width: 18)
                        Text("Disconnect high-draw external USB devices when not actively transferring data")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color.white)
        .accentColor(.effectiveAccent)
        .navigationTitle("App Usage")
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
