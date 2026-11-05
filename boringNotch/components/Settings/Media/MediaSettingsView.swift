import SwiftUI

struct MediaSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MediaLiveActivitySettingsCard()
                MediaSourceSettingsSection()
                MediaPlaybackSettingsCard()
                MediaControlsSettingsCard()
            }
            .padding(20)
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Media")
    }
}
