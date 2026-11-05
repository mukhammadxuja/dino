import AppKit
import Defaults
import SwiftUI

struct SettingsSidebarBatteryRow: View {
    let isExpanded: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7.5, style: .continuous)
                        .fill(Color(red: 0.18, green: 0.80, blue: 0.44))
                        .frame(width: 28, height: 28)

                    Image(systemName: "battery.100.bolt")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text("Battery")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hov in
            isHovered = hov
        }
    }
}
