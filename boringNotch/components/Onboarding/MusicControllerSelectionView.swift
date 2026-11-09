import SwiftUI

struct MusicControllerSelectionView: View {
    @Binding var selection: MediaControllerType
    let isNowPlayingDeprecated: Bool
    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

    private var availableMediaControllers: [MediaControllerType] {
        [.nowPlaying, .spotify, .appleMusic, .youtubeMusic]
            .filter { !isNowPlayingDeprecated || $0 != .nowPlaying }
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Choose your music source")
                    .font(.system(size: 26, weight: .bold))
                Text("Pick what you listen with. You can change this later.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(availableMediaControllers) { controller in
                        Button {
                            selection = controller
                        } label: {
                            ControllerOptionView(controller: controller, isSelected: selection == controller)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selection == controller ? [.isSelected] : [])
                    }

                    if selection == .youtubeMusic {
                        Link("Set up Pear Desktop for YouTube Music",
                             destination: URL(string: "https://github.com/pear-devs/pear-desktop")!)
                            .font(.caption)
                    }
                    if isNowPlayingDeprecated {
                        Text("Now Playing is unavailable on this version of macOS. Choose a direct music source instead.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 2)
            }

            HStack {
                Button("Back", action: onBack)
                Spacer()
                Button("Set up later", action: onSkip)
                Button("Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!availableMediaControllers.contains(selection))
            }
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ControllerOptionView: View {
    let controller: MediaControllerType
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: 22))
                .foregroundStyle(Color.effectiveAccent)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(controller.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(controller.description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Color.effectiveAccent : Color.secondary.opacity(0.4))
        }
        .multilineTextAlignment(.leading)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.effectiveAccent.opacity(0.1) : Color.primary.opacity(0.025))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.effectiveAccent : Color.primary.opacity(0.1), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    private var iconName: String {
        switch controller {
        case .nowPlaying: return "waveform"
        case .spotify: return "dot.radiowaves.left.and.right"
        case .appleMusic: return "music.note"
        case .youtubeMusic: return "play.rectangle.fill"
        }
    }
}

extension MediaControllerType {
    var description: String {
        switch self {
        case .nowPlaying: return "Automatically follows supported music apps and browsers."
        case .spotify: return "Connect directly to the Spotify app on your Mac."
        case .appleMusic: return "Connect directly to the Apple Music app on your Mac."
        case .youtubeMusic: return "Use Pear Desktop with its API server enabled."
        }
    }
}

#Preview {
    MusicControllerSelectionView(
        selection: .constant(.nowPlaying), isNowPlayingDeprecated: false,
        onBack: {}, onContinue: {}, onSkip: {}
    )
    .frame(width: 520, height: 580)
}
