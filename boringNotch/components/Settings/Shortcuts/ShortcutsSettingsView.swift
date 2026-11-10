import KeyboardShortcuts
import SwiftUI

struct Shortcuts: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                settingsSection(
                    "Media",
                    detail: "Sneak Peek temporarily shows the media title and artist under the notch."
                ) {
                    shortcutRow("Toggle Sneak Peek", subtitle: "Show or hide media details", icon: "eye.fill", color: .pink, name: .toggleSneakPeek)
                }

                settingsSection(
                    "Switch Active Module",
                    detail: "Quickly switch what appears in your notch or Dynamic Island."
                ) {
                    shortcutRow("Now Playing", subtitle: "Open the music controls", icon: "music.note", color: .pink, name: .selectMusicModule)
                    MediaSettingsDivider()
                    shortcutRow("Pomodoro Timer", subtitle: "Open the focus timer", icon: "timer", color: .orange, name: .selectPomodoroModule)
                    if ReleaseFeatures.calendar {
                        MediaSettingsDivider()
                        shortcutRow("Calendar", subtitle: "Open upcoming events", icon: "calendar", color: .red, name: .selectCalendarModule)
                    }
                    MediaSettingsDivider()
                    shortcutRow("Battery Status", subtitle: "Open battery information", icon: "battery.100", color: .green, name: .selectBatteryModule)
                    MediaSettingsDivider()
                    shortcutRow("Shelf Upload", subtitle: "Open the shelf for file sharing", icon: "books.vertical.fill", color: .purple, name: .selectShelfModule)
                }

                settingsSection("Floating HUDs & Overlays") {
                    shortcutRow("Clipboard History", subtitle: "Open the clipboard history panel", icon: "doc.on.clipboard.fill", color: .orange, name: .clipboardHistoryPanel)
                    MediaSettingsDivider()
                    shortcutRow("Toggle Notch Open", subtitle: "Open or close the notch", icon: "rectangle.topthird.inset.filled", color: .blue, name: .toggleNotchOpen)
                }

                settingsSection("Pomodoro", detail: "Use this shortcut to skip the current break.") {
                    shortcutRow("Skip Break", subtitle: "End the active break early", icon: "forward.end.fill", color: .orange, name: .pomodoroEmergencyExit)
                }
            }
            .padding(20)
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Shortcuts")
    }

    private func settingsSection<Content: View>(
        _ title: String,
        detail: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
            VStack(spacing: 0, content: content)
                .hudSettingsCard()
            if let detail {
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func shortcutRow(
        _ title: String,
        subtitle: String,
        icon: String,
        color: Color,
        name: KeyboardShortcuts.Name
    ) -> some View {
        MediaSettingsRow(icon: icon, iconColor: color, title: title, subtitle: subtitle) {
            DinoShortcutRecorder(name: name)
        }
    }
}
