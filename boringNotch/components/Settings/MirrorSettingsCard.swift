import SwiftUI
import Defaults

struct MirrorSettingsCard: View {
    @Default(.mirrorHUDEnabled) private var mirrorHUDEnabled
    @Default(.mirrorRingLight) private var mirrorRingLight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Mirror (HUD)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                customBadge(text: "⌥M")
            }

            VStack(spacing: 0) {
                // Master Toggle: Enable Mirror HUD
                settingRow(
                    icon: "video.fill",
                    iconColor: Color.blue,
                    title: "Enable mirror HUD",
                    subtitle: "Quickly check your appearance from the notch with zero background battery usage",
                    isOn: $mirrorHUDEnabled
                )

                if mirrorHUDEnabled {
                    cardDivider

                    // Shortcut recorder row
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.blue.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Image(systemName: "keyboard.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.blue)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Global shortcut")
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundColor(.primary)
                            Text("Press shortcut from anywhere to open mirror HUD")
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        DinoShortcutRecorder(name: .mirrorHUDPanel)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    cardDivider

                    // Default Ring Light toggle
                    settingRow(
                        icon: "lightbulb.fill",
                        iconColor: Color.yellow,
                        title: "Soft Ring Light default",
                        subtitle: "Automatically illuminate the viewport perimeter for low-light environments",
                        isOn: $mirrorRingLight
                    )
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
}
