import SwiftUI
import Defaults
import AppKit

struct StrictModeOverlayView: View {
    @ObservedObject private var pomodoroManager = PomodoroManager.shared
    @Default(.pomodoroStrictModeWallpaperPath) private var wallpaperPath
    @Default(.pomodoroStrictModeEyeExercisesEnabled) private var eyeExercisesEnabled
    @Default(.pomodoroAutoStartBreaks) private var autoStartBreaks
    @State private var showSkipConfirmation = false

    private let eyeExercises: [String] = [
        "Look up and down slowly for 20 seconds",
        "Look left and right, then blink 10 times",
        "Focus on a far object for 20 seconds",
        "Draw gentle circles with your eyes"
    ]

    private var currentExercise: String {
        let seconds = max(0, Int(pomodoroManager.remainingTime.rounded(.down)))
        let index = (seconds / 20) % eyeExercises.count
        return eyeExercises[index]
    }

    private var shouldShowStartBreakButton: Bool {
        pomodoroManager.isWaitingToStartBreak && !autoStartBreaks
    }

    private var wallpaperImage: NSImage? {
        guard let wallpaperPath, !wallpaperPath.isEmpty else { return nil }
        return NSImage(contentsOfFile: wallpaperPath)
    }

    var body: some View {
        ZStack {
            if let wallpaperImage {
                Image(nsImage: wallpaperImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(eyeExercisesEnabled ? 0.5 : 0.58))
            } else {
                Rectangle()
                    .fill(Color.black.opacity(0.62))
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
            }

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 68, height: 68)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.12))
                        )

                    Text("Strict Mode")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("\(pomodoroManager.phaseTitle) is active. Take your break away from distractions.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 460)

                    if eyeExercisesEnabled {
                        Label(currentExercise, systemImage: "eye")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.16))
                            )
                    }
                }

                StrictModeProgressView(
                    progress: pomodoroManager.progress,
                    remaining: pomodoroManager.formattedRemainingTime
                )
                .frame(width: 190, height: 190)

                HStack(spacing: 12) {
                    if shouldShowStartBreakButton {
                        Button {
                            pomodoroManager.startCurrentBreakIfNeeded()
                        } label: {
                            Label("Start break", systemImage: "play.fill")
                        }
                        .buttonStyle(StrictModeCapsuleButtonStyle(prominent: true))
                    }

                    Button {
                        showSkipConfirmation = true
                    } label: {
                        Label("Skip break", systemImage: "forward.fill")
                    }
                    .buttonStyle(StrictModeCapsuleButtonStyle(prominent: true))

                    Button {
                    } label: {
                        Label("Lock screen", systemImage: "lock.fill")
                    }
                    .buttonStyle(StrictModeCapsuleButtonStyle(prominent: false))
                    .disabled(true)
                }

                Text("Press Esc twice to skip")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 30)
        }
        .confirmationDialog("Skip this break?", isPresented: $showSkipConfirmation, titleVisibility: .visible) {
            Button("Skip break", role: .destructive) {
                pomodoroManager.skip()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure? This confirmation is always required in strict mode.")
        }
    }
}

private struct StrictModeCapsuleButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(prominent ? Color.black : Color.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(prominent ? Color.white : Color.white.opacity(0.16))
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct StrictModeProgressView: View {
    let progress: Double
    let remaining: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: 11)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: 11, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.35), value: progress)

            VStack(spacing: 8) {
                Text("Remaining")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Text(remaining)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
        }
    }
}
