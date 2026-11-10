import Defaults
import SwiftUI

struct MediaPlaybackSettingsCard: View {
    @Default(.enableSneakPeek) private var enableSneakPeek
    @Default(.sneakPeekStyles) private var sneakPeekStyles
    @Default(.playerColorTinting) private var playerColorTinting
    @Default(.waitInterval) private var waitInterval
    @Default(.hideNotchOption) private var hideNotchOption

    // MARK: - 3. Playback Live Activity Card
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Playback Live Activity")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                // Sneak Peek Toggle Row
                MediaSettingsRow(
                    icon: "sparkles.rectangle.stack.fill",
                    iconColor: .indigo,
                    title: "Show sneak peek on playback changes",
                    subtitle: "Briefly pop open track info and album art when a new song starts"
                ) {
                    Toggle("", isOn: $enableSneakPeek)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(.effectiveAccent)
                }

                if enableSneakPeek {
                    MediaSettingsDivider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sneak Peek Style")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            ForEach(SneakPeekStyle.allCases) { style in
                                SneakPeekStyleCard(style: style, selection: $sneakPeekStyles)
                            }
                        }

                        Text(sneakPeekStyles == .standard ? "Rich card popup with album art." : "Compact inline banner in the notch.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                MediaSettingsDivider()

                // Artwork Color Tinting Row
                MediaSettingsRow(
                    icon: "paintpalette.fill",
                    iconColor: .pink,
                    title: "Match player colors to album artwork",
                    subtitle: "Tint the song title, artist text, and playing visualizer to artwork color"
                ) {
                    Toggle("", isOn: $playerColorTinting)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(.effectiveAccent)
                }

                MediaSettingsDivider()

                // Inactivity Timeout Row
                MediaSettingsRow(
                    icon: "timer",
                    iconColor: .orange,
                    title: "Media inactivity timeout",
                    subtitle: "Automatically hide player after media has remained paused"
                ) {
                    HStack(spacing: 8) {
                        Text("\(Int(waitInterval))s")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 28, alignment: .trailing)

                        Stepper("", value: $waitInterval, in: 0...10, step: 1)
                            .labelsHidden()
                            .controlSize(.small)
                    }
                }

                MediaSettingsDivider()

                // Full Screen Behavior Row
                MediaSettingsRow(
                    icon: "arrow.up.left.and.arrow.down.right.rectangle",
                    iconColor: .teal,
                    title: "Full screen behavior",
                    subtitle: "Control media notch visibility in full screen apps",
                    badge: "Beta"
                ) {
                    Picker("", selection: $hideNotchOption) {
                        Text("Hide for all apps").tag(HideNotchOption.always)
                        Text("Hide for media app only").tag(HideNotchOption.nowPlayingOnly)
                        Text("Never hide").tag(HideNotchOption.never)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 170)
                }
            }
            .background(Color.settingsCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.settingsCardBorder, lineWidth: 1)
            )
        }
    }
}
