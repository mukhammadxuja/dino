import AppKit
import SwiftUI

struct WelcomeView: View {
    var onGetStarted: (() -> Void)? = nil
    var onSkip: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)

            Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("Welcome to Dino")
                    .font(.system(size: 30, weight: .bold))
                Text("Your everyday Mac companion.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Music, focus, files, and useful updates — together on your Mac.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 28) {
                feature("Music", icon: "music.note")
                feature("Focus", icon: "timer")
                feature("Files", icon: "tray.fill")
                feature("HUDs", icon: "slider.horizontal.3")
            }
            .padding(.vertical, 12)

            Spacer(minLength: 8)

            VStack(spacing: 10) {
                Button("Get Started") { onGetStarted?() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)

                if let onSkip {
                    Button("Set up later", action: onSkip)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func feature(_ title: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 21))
                .foregroundStyle(Color.effectiveAccent)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    WelcomeView()
        .frame(width: 520, height: 580)
}
