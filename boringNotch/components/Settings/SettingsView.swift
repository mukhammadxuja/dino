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
    @Default(.appTheme) private var appTheme

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
                    if ReleaseFeatures.calendar {
                        SettingsSidebarItemRow(title: "Calendar", icon: "calendar", iconBg: Color(red: 0.98, green: 0.35, blue: 0.35), isSelected: selectedTab == "Calendar") {
                            selectedTab = "Calendar"
                        }
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
            .background(Color.settingsSidebarBackground)
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(min: 200, ideal: 215, max: 235)
        } detail: {
            Group {
                switch selectedTab {
                case "General":
                    GeneralSettings()
                case "Appearance":
                    AppearanceSettingsView()
                case "LockScreen":
                    LockScreenSettingsView()
                case "Media":
                    MediaSettingsView()
                case "Calendar":
                    if ReleaseFeatures.calendar { CalendarSettings() } else { GeneralSettings() }
                case "HUD":
                    HUDSettingsView()
                case "Battery":
                    BatterySettingsView()
                case "Shelf":
                    ShelfSettingsView()
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
            .background(Color.settingsWindowBackground)
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
        .background(Color.settingsWindowBackground)
        .preferredColorScheme(appTheme.colorScheme)
        .tint(.effectiveAccent)
        .id(accentColorUpdateTrigger)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AccentColorChanged"))) { _ in
            accentColorUpdateTrigger = UUID()
        }
        .onAppear {
            appTheme.applyToApplication()
        }
        .onChange(of: appTheme) { _, theme in
            theme.applyToApplication()
        }
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
