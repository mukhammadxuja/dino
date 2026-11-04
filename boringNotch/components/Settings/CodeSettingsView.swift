import SwiftUI
import Defaults

struct CodeSettingsView: View {
    @Default(.codeActivityEnabled) private var codeActivityEnabled
    @Default(.codeSoundNotifications) private var codeSoundNotifications
    @Default(.codeShowInClosedNotch) private var codeShowInClosedNotch
    @ObservedObject private var antigravityManager = AntigravityManager.shared

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .codeActivityEnabled) {
                    HStack(spacing: 8) {
                        Image(systemName: "curlybraces")
                            .foregroundStyle(Color(red: 0.20, green: 0.78, blue: 0.55))
                        Text("Enable Code Activity in Notch")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .onChange(of: codeActivityEnabled) { _, isEnabled in
                    if !isEnabled {
                        antigravityManager.setPhase(.idle)
                    }
                }
            } header: {
                Text("Code & AI Assistant")
            } footer: {
                Text("Displays real-time Antigravity AI Agent activity (Analyzing, Thinking, Reading, Editing files, Running commands) in the notch and Dynamic Island.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if codeActivityEnabled {
                Section {
                    Defaults.Toggle(key: .codeShowInClosedNotch) {
                        Text("Show in closed notch / island")
                    }
                    Defaults.Toggle(key: .codeSoundNotifications) {
                        Text("Sound notifications on completion & permissions")
                    }
                } header: {
                    Text("Behavior")
                } footer: {
                    Text("When closed notch is enabled, the notch smoothly expands to show live coding phases and status indicators.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    AntigravityDemoView()
                        .padding(.vertical, 4)
                } header: {
                    Text("Interactive Preview & Testing")
                } footer: {
                    Text("Click any state to preview how the notch reacts in real time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Code")
    }
}
