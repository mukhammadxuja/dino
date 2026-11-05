import SwiftUI

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
                if ReleaseFeatures.calendar {
                    DinoShortcutRow("Calendar:", name: .selectCalendarModule)
                }
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

