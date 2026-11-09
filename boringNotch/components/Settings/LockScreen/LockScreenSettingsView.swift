import Defaults
import SwiftUI

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

                    Text("The player appears above the passcode field while media is playing. Click its album artwork for a larger cover and a matching backdrop.")
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

