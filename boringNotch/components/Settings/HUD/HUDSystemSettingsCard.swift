import AppKit
import Defaults
import SwiftUI

struct HUDSystemSettingsCard: View {
    @Default(.hudReplacement) private var isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("System HUD")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: "dial.medium.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Replace system HUD")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Replaces standard macOS volume, display brightness, and keyboard brightness HUDs with a custom design.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 20)
                if isEnabled {
                    HUDSystemStatusView()
                }
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .hudSettingsCard()
        }
    }
}

// This observer and permission query exist only while replacement is enabled.
private struct HUDSystemStatusView: View {
    @ObservedObject private var interceptor = MediaKeyInterceptor.shared
    @State private var authorized = false
    @State private var showingPermission = false
    @State private var showingRetry = false
    @State private var refreshID = 0

    var body: some View {
        Group {
            if !authorized {
                HUDPermissionButton { showingPermission = true }
                    .popover(isPresented: $showingPermission, arrowEdge: .bottom) {
                        HUDPermissionPrompt(
                            title: "Dino needs permission to replace system HUDs.",
                            detail: "Allow device control in System Settings to show custom volume and brightness controls.",
                            buttonTitle: "Ask Permission..."
                        ) {
                            showingPermission = false
                            XPCHelperClient.shared.requestAccessibilityAuthorization()
                        }
                    }
            } else {
                switch interceptor.activationState {
                case .active:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .help("System HUD is active")
                case .failed:
                    HUDPermissionButton(icon: "exclamationmark.triangle.fill", help: "System HUD could not start") {
                        showingRetry = true
                    }
                    .popover(isPresented: $showingRetry, arrowEdge: .bottom) {
                        HUDPermissionPrompt(
                            title: "Dino could not start the system HUD.",
                            detail: "Try starting it again. If this continues, quit other copies of Dino and reopen the app.",
                            buttonTitle: "Try Again"
                        ) {
                            showingRetry = false
                            Task { await interceptor.start() }
                        }
                    }
                case .starting, .disabled, .needsPermission:
                    ProgressView()
                        .controlSize(.small)
                        .help("Starting system HUD")
                }
            }
        }
        .task(id: refreshID) {
            let result = await XPCHelperClient.shared.isAccessibilityAuthorized()
            guard !Task.isCancelled else { return }
            authorized = result
        }
        .onReceive(NotificationCenter.default.publisher(for: .accessibilityAuthorizationChanged)) { notification in
            if let granted = notification.userInfo?["granted"] as? Bool {
                authorized = granted
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshID &+= 1
        }
    }
}
