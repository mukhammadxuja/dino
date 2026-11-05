import AppKit
import CoreBluetooth
import SwiftUI

extension View {
    func hudSettingsCard() -> some View {
        background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
            }
    }
}

struct HUDPermissionButton: View {
    var icon = "lock.shield.fill"
    var help = "Permission needed"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.orange)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

struct HUDPermissionPrompt: View {
    let title: String
    let detail: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 30))
                .foregroundStyle(.orange)
                .padding(.top, 4)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .frame(maxWidth: .infinity)
        }
        .frame(width: 280)
        .padding(18)
    }
}

// Constructed only for the enabled AirPods row, never for a collapsed preview.
struct HUDBluetoothPermissionView: View {
    @ObservedObject private var manager = BluetoothHUDManager.shared
    @State private var showingPermission = false

    var body: some View {
        Group {
            if manager.authorizationStatus != .allowedAlways {
                HUDPermissionButton { showingPermission = true }
                    .popover(isPresented: $showingPermission, arrowEdge: .bottom) {
                        HUDPermissionPrompt(
                            title: "Dino needs Bluetooth access for AirPods alerts.",
                            detail: "Allow Bluetooth to show when your headphones connect.",
                            buttonTitle: manager.authorizationStatus == .notDetermined
                                ? "Ask Permission..." : "Open System Settings"
                        ) {
                            showingPermission = false
                            if manager.authorizationStatus == .notDetermined {
                                manager.requestAuthorization()
                            } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
            }
        }
        .task { manager.refreshAuthorizationStatus() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            manager.refreshAuthorizationStatus()
        }
    }
}
