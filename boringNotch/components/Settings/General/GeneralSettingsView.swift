import AppKit
import Defaults
import LaunchAtLogin
import SwiftUI

struct GeneralSettings: View {
    @Default(.idleClickAction) private var idleClickAction
    @Default(.notchWidthAdjustment) private var notchWidthAdjustment
    @Default(.notchHeightAdjustment) private var notchHeightAdjustment

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GeneralSystemSettingsCard()
                GeneralIdleActivitySection(idleClickAction: $idleClickAction)
                GeneralClipboardSettingsCard()
                GeneralMirrorSection()
                GeneralGesturesSettingsCard()
                GeneralTuningSettingsCard(notchWidthAdjustment: $notchWidthAdjustment, notchHeightAdjustment: $notchHeightAdjustment)
                GeneralQuitSection()
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
}

private struct GeneralSystemSettingsCard: View {
    @ObservedObject private var coordinator = BoringViewCoordinator.shared
    @Default(.menubarIcon) private var menubarIcon
    @Default(.hideNotchOption) private var hideNotchOption
    @Default(.hideFromScreenRecording) private var hideFromScreenRecording

    var body: some View {
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
    }
}

private struct GeneralIdleActivitySection: View {
    @Binding var idleClickAction: IdleClickAction

    var body: some View {
                // MARK: - 2. Idle Activity
                VStack(alignment: .leading, spacing: 8) {
                    Text("Idle activity")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)

                    Text("Choose what opens when you click an idle notch or Dynamic Island")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach([IdleClickAction.none, .music, .pomodoro, .weather] + (ReleaseFeatures.calendar ? [.calendar] : [])) { action in
                            IdleActivityCard(action: action, selection: $idleClickAction)
                        }
                    }
                }
    }
}

private struct GeneralClipboardSettingsCard: View {
    @Default(.clipboardHistoryEnabled) private var clipboardHistoryEnabled
    @Default(.clipboardHistoryAutoPaste) private var clipboardHistoryAutoPaste
    @Default(.clipboardHistoryMaxItems) private var clipboardHistoryMaxItems

    var body: some View {
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
    }
}

private struct GeneralMirrorSection: View {
    var body: some View {
                // MARK: - 4. Mirror HUD Card
                if ReleaseFeatures.mirror {
                    MirrorSettingsCard()
                }
    }
}

private struct GeneralGesturesSettingsCard: View {
    @Default(.enableGestures) private var enableGestures

    var body: some View {
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
    }
}

private struct GeneralTuningSettingsCard: View {
    @Binding var notchWidthAdjustment: Int
    @Binding var notchHeightAdjustment: Int

    var body: some View {
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
    }
}

private struct GeneralQuitSection: View {
    var body: some View {
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
