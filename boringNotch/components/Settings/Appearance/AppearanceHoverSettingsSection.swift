import Defaults
import SwiftUI

struct AppearanceHoverSettingsSection: View {
    @Default(.openNotchOnHover) private var openNotchOnHover
    @Default(.minimumHoverDuration) private var minimumHoverDuration
    @Default(.collapseDelay) private var collapseDelay
    @Default(.enableHaptics) private var enableHaptics

    var body: some View {
                // MARK: - 1. Hover Section (Redesigned UI)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hover")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)

                    VStack(spacing: 0) {
                        // Row 1: Expand on hover
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Expand on hover")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("Open the expanded view without clicking")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $openNotchOnHover)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .tint(Color.effectiveAccent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        Divider()
                            .padding(.horizontal, 16)

                        // Row 2: Expand delay
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Expand delay")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("Hover time\nbefore expanding")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            HoverDelaySlider(value: $minimumHoverDuration, range: 0.1...1.0, step: 0.05)
                                .opacity(openNotchOnHover ? 1.0 : 0.45)
                                .disabled(!openNotchOnHover)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        Divider()
                            .padding(.horizontal, 16)

                        // Row 3: Collapse delay
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Collapse delay")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("After the pointer leaves")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            HoverDelaySlider(value: $collapseDelay, range: 0.1...1.0, step: 0.05)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        Divider()
                            .padding(.horizontal, 16)

                        // Row 4: Haptic feedback on hover
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Haptic feedback on hover")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("Vibrate trackpad when pointer touches notch or island")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $enableHaptics)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .tint(Color.effectiveAccent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.75))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
    }
}
