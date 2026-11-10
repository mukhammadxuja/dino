import Defaults
import SwiftUI

struct MediaControlsSettingsCard: View {
    @Default(.enableLyrics) private var enableLyrics

    // MARK: - 4. Media Controls Card
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Media Controls")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                // Drag & Drop Configuration
                VStack(alignment: .leading, spacing: 10) {
                    MusicSlotConfigurationView()
                }
                .padding(16)

                MediaSettingsDivider()

                // Lyrics Toggle Row
                MediaSettingsRow(
                    icon: "quote.bubble.fill",
                    iconColor: .purple,
                    title: "Lyrics",
                    subtitle: "Show an L badge beside the song title to open lyrics",
                    badge: "Beta"
                ) {
                    Toggle("", isOn: $enableLyrics)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(.effectiveAccent)
                }
            }
            .background(Color.settingsCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.settingsCardBorder, lineWidth: 1)
            )

            Text("Customize which controls appear in the music player. Volume expands when active.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.top, 2)
        }
    }
}
