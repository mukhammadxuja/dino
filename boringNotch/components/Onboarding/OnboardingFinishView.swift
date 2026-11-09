import SwiftUI

struct OnboardingFinishView: View {
    let displaySelection: DisplaySelection
    let builtinFormFactor: DisplayFormFactor
    let externalFormFactor: DisplayFormFactor
    let musicSource: MediaControllerType?
    let onBack: () -> Void
    let onFinish: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 8)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.effectiveAccent)

            VStack(spacing: 10) {
                Text("You're All Set!")
                    .font(.system(size: 30, weight: .bold))
                Text("Dino is ready for your Mac. Fine-tune anything in Settings whenever you like.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 12) {
                summaryRow("Show on", value: displaySelection.rawValue, icon: "display.2")
                summaryRow("Built-in display", value: builtinFormFactor.rawValue, icon: "laptopcomputer")
                summaryRow("External display", value: externalFormFactor.rawValue, icon: "display")
                summaryRow("Music source", value: musicSource?.rawValue ?? "Set up later", icon: "music.note")
            }
            .padding(18)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))

            Spacer(minLength: 8)

            Button(action: onOpenSettings) {
                Label("Open Settings", systemImage: "gearshape")
            }
            .controlSize(.large)

            HStack {
                Button("Back", action: onBack)
                Spacer()
                Button("Finish", action: onFinish)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func summaryRow(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.system(size: 13))
    }
}

#Preview {
    OnboardingFinishView(
        displaySelection: .both, builtinFormFactor: .notch, externalFormFactor: .island,
        musicSource: .nowPlaying, onBack: {}, onFinish: {}, onOpenSettings: {}
    )
    .frame(width: 520, height: 580)
}
