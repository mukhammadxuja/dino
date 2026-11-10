import AppKit
import Defaults
import Sparkle
import SwiftUI

struct About: View {
    @State private var showBuildNumber = false
    let updaterController: SPUStandardUpdaterController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                settingsSection("Version Info") {
                    MediaSettingsRow(
                        icon: "tag.fill", iconColor: .purple,
                        title: "Release name", subtitle: "Current Dino release"
                    ) {
                        Text(Defaults[.releaseName])
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    MediaSettingsDivider()
                    MediaSettingsRow(
                        icon: "info.circle.fill", iconColor: .blue,
                        title: "Version", subtitle: versionDetail
                    ) {
                        Text(Bundle.main.releaseVersionNumber ?? "Unknown")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation { showBuildNumber.toggle() } }
                }

                settingsSection("Software Updates") {
                    UpdaterSettingsView(updater: updaterController.updater)
                }

                settingsSection("Welcome") {
                    MediaSettingsRow(
                        icon: "hand.wave.fill", iconColor: .orange,
                        title: "Show Welcome", subtitle: "Revisit Dino’s introduction and setup"
                    ) {
                        Button("Show Welcome") {
                            NotificationCenter.default.post(name: .showWelcomeWindow, object: nil)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                settingsSection("Community") {
                    MediaSettingsRow(
                        icon: "chevron.left.forwardslash.chevron.right", iconColor: .primary,
                        title: "GitHub", subtitle: "View the Dino project and source code"
                    ) {
                        Button("Open GitHub") {
                            guard let url = URL(string: "https://github.com/mukhammadxuja/dino") else { return }
                            NSWorkspace.shared.open(url)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Text("Enjoy!")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
            }
            .padding(20)
        }
        .toolbar {
            CheckForUpdatesView(updater: updaterController.updater)
        }
        .navigationTitle("About")
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
                .hudSettingsCard()
        }
    }

    private var versionDetail: String {
        showBuildNumber
            ? "Build " + (Bundle.main.buildVersionNumber ?? "")
            : "Click to show the build number"
    }
}
