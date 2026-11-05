import Combine
import Defaults
import SwiftUI

struct MediaSourceSettingsSection: View {
    @Default(.mediaController) private var mediaController
    @State private var isNowPlayingDeprecated = false

    var body: some View {
        sourceOptions
            .onReceive(MusicManager.shared.$isNowPlayingDeprecated.removeDuplicates()) {
                isNowPlayingDeprecated = $0
            }
    }

    // MARK: - 2. Music Source Section
    private var sourceOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Music Source")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                ForEach(availableMediaControllers) { controller in
                    MediaSourceCard(source: controller, selection: $mediaController)
                }
            }

            if isNowPlayingDeprecated {
                HStack(spacing: 4) {
                    Text("YouTube Music requires this third-party app to be installed: ")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11))
                    Link(
                        "pear-desktop",
                        destination: URL(string: "https://github.com/pear-devs/pear-desktop")!
                    )
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.effectiveAccent)
                }
                .padding(.horizontal, 4)
                .padding(.top, 2)
            } else {
                Text("'Now Playing' automatically connects to Apple Music, Spotify, browsers, and all macOS media players.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
            }
        }
    }
    private var availableMediaControllers: [MediaControllerType] {
        MediaControllerType.allCases.filter { !isNowPlayingDeprecated || $0 != .nowPlaying }
    }
}
