import AppKit
import Defaults
import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case displayStyle
    case musicSource
    case finished

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .displayStyle: return "Your look"
        case .musicSource: return "Music"
        case .finished: return "Ready"
        }
    }
}

struct OnboardingView: View {
    static let windowSize = CGSize(width: 520, height: 640)

    @State var step: OnboardingStep = .welcome
    let onFinish: () -> Void
    let onOpenSettings: () -> Void

    @State private var displaySelection = Self.initialDisplaySelection
    @State private var builtinFormFactor = Defaults[.builtinFormFactor]
    @State private var externalFormFactor = Defaults[.externalFormFactor]
    @State private var selectedMediaController = Defaults[.mediaController]
    @State private var musicSetupSkipped = false
    @ObservedObject private var musicManager = MusicManager.shared

    private static var initialDisplaySelection: DisplaySelection {
        // Detect the first setup's screens while preserving preferences on repeat visits.
        guard BoringViewCoordinator.shared.firstLaunch,
              let bundleID = Bundle.main.bundleIdentifier,
              UserDefaults.standard.persistentDomain(forName: bundleID)?["displaySelection"] == nil else {
            return Defaults[.displaySelection]
        }
        let hasBuiltin = NSScreen.screens.contains { $0.isBuiltin }
        let hasExternal = NSScreen.screens.contains { !$0.isBuiltin }
        if hasBuiltin && hasExternal { return .both }
        return hasBuiltin ? .builtin : .external
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { item in
                    VStack(spacing: 7) {
                        Capsule()
                            .fill(item.rawValue <= step.rawValue ? Color.effectiveAccent : Color.secondary.opacity(0.15))
                            .frame(height: 3)
                        Text(item.title)
                            .font(.system(size: 11, weight: item == step ? .semibold : .regular))
                            .foregroundStyle(item == step ? .primary : .secondary)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
            .padding(.bottom, 12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(step.rawValue + 1) of 4: \(step.title)")

            Group {
                switch step {
                case .welcome:
                    WelcomeView { go(to: .displayStyle) }
                case .displayStyle:
                    OnboardingDisplayStyleView(
                        displaySelection: $displaySelection,
                        builtinFormFactor: $builtinFormFactor,
                        externalFormFactor: $externalFormFactor,
                        onBack: { go(to: .welcome) },
                        onContinue: { go(to: .musicSource) }
                    )
                case .musicSource:
                    MusicControllerSelectionView(
                        selection: $selectedMediaController,
                        isNowPlayingDeprecated: musicManager.isNowPlayingDeprecated,
                        onBack: { go(to: .displayStyle) },
                        onContinue: {
                            musicSetupSkipped = false
                            go(to: .finished)
                        },
                        onSkip: {
                            musicSetupSkipped = true
                            go(to: .finished)
                        }
                    )
                case .finished:
                    OnboardingFinishView(
                        displaySelection: displaySelection,
                        builtinFormFactor: builtinFormFactor,
                        externalFormFactor: externalFormFactor,
                        musicSource: musicSetupSkipped ? nil : selectedMediaController,
                        onBack: { go(to: .musicSource) },
                        onFinish: { complete(onFinish) },
                        onOpenSettings: { complete(onOpenSettings) }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
        }
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        .background {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
        }
        .onAppear(perform: validateMusicSource)
        .onChange(of: musicManager.isNowPlayingDeprecated) { validateMusicSource() }
    }

    private func go(to nextStep: OnboardingStep) {
        withAnimation(.easeInOut(duration: 0.2)) { step = nextStep }
    }

    private func validateMusicSource() {
        if musicManager.isNowPlayingDeprecated && selectedMediaController == .nowPlaying {
            selectedMediaController = .appleMusic
        }
    }

    private func complete(_ action: () -> Void) {
        let displayChanged = Defaults[.displaySelection] != displaySelection
            || Defaults[.builtinFormFactor] != builtinFormFactor
            || Defaults[.externalFormFactor] != externalFormFactor

        Defaults[.displaySelection] = displaySelection
        Defaults[.builtinFormFactor] = builtinFormFactor
        Defaults[.externalFormFactor] = externalFormFactor
        if displayChanged {
            NotificationCenter.default.post(name: .displaySettingsChanged, object: nil)
        }

        validateMusicSource()
        if !musicSetupSkipped && Defaults[.mediaController] != selectedMediaController {
            Defaults[.mediaController] = selectedMediaController
            NotificationCenter.default.post(name: .mediaControllerChanged, object: nil)
        }
        BoringViewCoordinator.shared.firstLaunch = false
        action()
    }
}

private struct OnboardingDisplayStyleView: View {
    @Binding var displaySelection: DisplaySelection
    @Binding var builtinFormFactor: DisplayFormFactor
    @Binding var externalFormFactor: DisplayFormFactor
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var screens = NSScreen.screens

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text("Choose your look")
                    .font(.system(size: 26, weight: .bold))
                Text("Make Dino feel at home on every display.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Show Dino on", selection: $displaySelection) {
                        ForEach(DisplaySelection.allCases) { display in
                            Text(display.rawValue).tag(display)
                        }
                    }
                    .pickerStyle(.segmented)

                    displayCard(
                        title: "Built-in display", icon: "laptopcomputer",
                        isConnected: screens.contains { $0.isBuiltin },
                        selection: $builtinFormFactor
                    )
                    displayCard(
                        title: "External display", icon: "display",
                        isConnected: screens.contains { !$0.isBuiltin },
                        selection: $externalFormFactor
                    )

                    Text("You can change these choices later in Settings → Appearance.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 32)
            }

            HStack {
                Button("Back", action: onBack)
                Spacer()
                Button("Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .padding(.top, 10)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screens = NSScreen.screens
        }
    }

    private func displayCard(
        title: String, icon: String, isConnected: Bool,
        selection: Binding<DisplayFormFactor>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(isConnected ? "Connected" : "Save for later")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            OnboardingDisplayPreview(factor: selection.wrappedValue)

            HStack(spacing: 12) {
                FormFactorCard(factor: .notch, selection: selection)
                FormFactorCard(factor: .island, selection: selection)
            }
        }
    }
}

private struct OnboardingDisplayPreview: View {
    let factor: DisplayFormFactor

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(
                    colors: [Color.effectiveAccent.opacity(0.25), Color.effectiveAccent.opacity(0.06)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            Rectangle()
                .fill(Color.primary.opacity(0.04))
                .frame(height: 16)
            if factor == .notch {
                NotchCutoutShape()
                    .fill(.black)
                    .frame(width: 100, height: 24)
            } else {
                Capsule()
                    .fill(.black)
                    .frame(width: 86, height: 24)
                    .padding(.top, 9)
            }
            Label("Dino", systemImage: "sparkles")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 12)
        }
        .frame(height: 86)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.2), value: factor)
        .accessibilityLabel("\(factor.rawValue) preview")
    }
}

#Preview {
    OnboardingView(onFinish: {}, onOpenSettings: {})
}
