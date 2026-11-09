import SwiftUI

struct MediaLiveActivitySettingsCard: View {
    @ObservedObject private var coordinator = BoringViewCoordinator.shared

    // MARK: - 1. Master Live Activity Card
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.pink.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: "music.note")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.pink)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Show music live activity")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Display current track info and playback controls in Dino")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }

                Spacer()

                KbdShortcutBadge(keys: ["⌘", "⇧", "P"])
                    .padding(.trailing, 4)

                Toggle("", isOn: $coordinator.musicLiveActivityEnabled.animation())
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(.effectiveAccent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
            )
        }
    }
}
