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
    @Default(.pomodoroStrictModeEnabled) private var pomodoroStrictModeEnabled
    @Default(.pomodoroStrictModeWallpaperPath) private var pomodoroStrictModeWallpaperPath
    @Default(.pomodoroStrictModeEyeExercisesEnabled) private var pomodoroStrictModeEyeExercisesEnabled

    private let pomodoroColor = Color(red: 0.95, green: 0.35, blue: 0.25)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                settingsSection("Pomodoro") {
                    PomodoroSettingsRow(
                        icon: "timer", iconColor: pomodoroColor,
                        title: "Enable Pomodoro",
                        subtitle: "Show focus sessions and controls in the notch"
                    ) {
                        Toggle("Enable Pomodoro", isOn: $pomodoroEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .tint(.effectiveAccent)
                    }
                }

                settingsSection("Session") {
                    PomodoroSettingsRow(
                        icon: "brain.head.profile", iconColor: .blue,
                        title: "Focus duration",
                        subtitle: "Length of each focused work session"
                    ) {
                        durationStepper($pomodoroFocusMinutes, range: 5...120)
                    }
                    PomodoroSettingsDivider()
                    PomodoroSettingsRow(
                        icon: "cup.and.saucer.fill", iconColor: .green,
                        title: "Short break",
                        subtitle: "Recovery time between focus sessions"
                    ) {
                        durationStepper($pomodoroShortBreakMinutes, range: 1...30)
                    }
                    PomodoroSettingsDivider()
                    PomodoroSettingsRow(
                        icon: "moon.fill", iconColor: .indigo,
                        title: "Long break",
                        subtitle: "A longer break after completing a cycle"
                    ) {
                        durationStepper($pomodoroLongBreakMinutes, range: 5...60)
                    }
                    PomodoroSettingsDivider()
                    PomodoroSettingsRow(
                        icon: "arrow.triangle.2.circlepath", iconColor: .orange,
                        title: "Cycles before long break",
                        subtitle: "Number of focus sessions in each cycle"
                    ) {
                        cycleStepper
                    }
                }

                settingsSection("Automation") {
                    PomodoroSettingsRow(
                        icon: "play.circle.fill", iconColor: .green,
                        title: "Auto-start breaks",
                        subtitle: "Begin each break when a focus session ends"
                    ) {
                        Toggle("Auto-start breaks", isOn: $pomodoroAutoStartBreaks)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .tint(.effectiveAccent)
                    }
                    PomodoroSettingsDivider()
                    PomodoroSettingsRow(
                        icon: "forward.end.fill", iconColor: .blue,
                        title: "Auto-start next focus",
                        subtitle: "Start the next focus session after a break"
                    ) {
                        Toggle("Auto-start next focus", isOn: $pomodoroAutoStartFocus)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .tint(.effectiveAccent)
                    }
                    PomodoroSettingsDivider()
                    PomodoroSettingsRow(
                        icon: "bell.badge.fill", iconColor: .orange,
                        title: "Notifications",
                        subtitle: "Get a one-minute warning before a session ends"
                    ) {
                        Toggle("Notifications", isOn: $pomodoroNotificationsEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .tint(.effectiveAccent)
                    }
                }

                settingsSection("Strict Mode") {
                    PomodoroSettingsRow(
                        icon: "lock.fill", iconColor: .red,
                        title: "Enable strict mode",
                        subtitle: "Show a full-screen break overlay on every monitor"
                    ) {
                        Toggle("Enable strict mode", isOn: $pomodoroStrictModeEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .tint(.effectiveAccent)
                    }
                    PomodoroSettingsDivider()
                    PomodoroSettingsRow(
                        icon: "eye.fill", iconColor: .teal,
                        title: "Eye exercise mode",
                        subtitle: "Include eye exercises during strict-mode breaks"
                    ) {
                        Toggle("Enable eye exercise mode", isOn: $pomodoroStrictModeEyeExercisesEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .tint(.effectiveAccent)
                    }
                    .disabled(!pomodoroStrictModeEnabled)
                    .opacity(pomodoroStrictModeEnabled ? 1 : 0.5)
                    PomodoroSettingsDivider()
                    PomodoroSettingsRow(
                        icon: "photo.fill", iconColor: .purple,
                        title: "Break wallpaper",
                        subtitle: strictModeWallpaperLabel
                    ) {
                        HStack(spacing: 8) {
                            Button("Choose") { pickStrictModeWallpaper() }
                                .buttonStyle(.bordered)
                            if pomodoroStrictModeWallpaperPath != nil {
                                Button("Reset") { pomodoroStrictModeWallpaperPath = nil }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                    .disabled(!pomodoroStrictModeEnabled)
                    .opacity(pomodoroStrictModeEnabled ? 1 : 0.5)
                }

                settingsSection("Closed Notch") {
                    PomodoroSettingsRow(
                        icon: "rectangle.topthird.inset.filled", iconColor: pomodoroColor,
                        title: "Closed notch behavior",
                        subtitle: "Choose whether the countdown appears while the notch is closed"
                    ) {
                        Picker("Closed notch behavior", selection: $pomodoroClosedNotchDisplayMode) {
                            ForEach(PomodoroClosedNotchDisplayMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 118)
                    }
                }

                settingsSection("Sounds") {
                    PomodoroSettingsRow(
                        icon: "metronome.fill", iconColor: .orange,
                        title: "Ticking",
                        subtitle: "Plays during the last five seconds of each session"
                    ) {
                        HStack(spacing: 8) {
                            Picker("Ticking", selection: $pomodoroTickSound) {
                                ForEach(PomodoroTickSound.allCases) { sound in
                                    Text(sound.title).tag(sound)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 112)
                            Button("Play") { playTickSound() }
                                .buttonStyle(.bordered)
                                .disabled(pomodoroTickSound == .off)
                        }
                    }
                    PomodoroSettingsDivider()
                    PomodoroSettingsRow(
                        icon: "speaker.wave.2.fill", iconColor: .red,
                        title: "Session end",
                        subtitle: "Plays when a focus session or break finishes"
                    ) {
                        HStack(spacing: 8) {
                            Picker("Session end", selection: $pomodoroEndSound) {
                                ForEach(PomodoroEndSound.allCases) { sound in
                                    Text(sound.title).tag(sound)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 112)
                            Button("Play") { playEndSound() }
                                .buttonStyle(.bordered)
                                .disabled(pomodoroEndSound == .off)
                        }
                    }
                }
            }
            .padding(20)
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Pomodoro")
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0, content: content)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
                }
        }
    }

    private func durationStepper(_ value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        Stepper(value: clampedBinding(for: value, in: range), in: range) {
            Text("\(value.wrappedValue) min")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(minWidth: 45, alignment: .trailing)
        }
        .labelsHidden()
    }

    private var cycleStepper: some View {
        Stepper(value: clampedBinding(for: $pomodoroCycleBeforeLongBreak, in: 2...10), in: 2...10) {
            Text("\(pomodoroCycleBeforeLongBreak)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(minWidth: 24, alignment: .trailing)
        }
        .labelsHidden()
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

    private func playTickSound() {
        guard let fileName = pomodoroTickSound.fileName else { return }
        AudioPlayer().play(fileName: fileName, fileExtension: "mp3", subdirectory: "sounds")
    }

    private func playEndSound() {
        guard let fileName = pomodoroEndSound.fileName else { return }
        AudioPlayer().play(fileName: fileName, fileExtension: "mp3", subdirectory: "sounds")
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

private struct PomodoroSettingsDivider: View {
    var body: some View {
        Divider().padding(.leading, 56)
    }
}

private struct PomodoroSettingsRow<TrailingContent: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: () -> TrailingContent

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
