import AppKit
import Defaults
import SwiftUI
import UniformTypeIdentifiers

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

