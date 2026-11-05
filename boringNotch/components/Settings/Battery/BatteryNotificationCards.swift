import AppKit
import Defaults
import SwiftUI

// MARK: - Low Battery Alert Card View
struct LowBatteryAlertCardView: View {
    @Binding var alert: BatteryAlertItem
    let isExpanded: Bool
    let showDelete: Bool
    let onToggleExpand: () -> Void
    let onDelete: () -> Void
    let onTest: () -> Void

    @ObservedObject private var soundManager = CustomSoundManager.shared

    private func soundDisplayName(for rawName: String) -> String {
        if let choice = BatterySoundChoice(rawValue: rawName) {
            return choice.title
        }
        return rawName
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Row
            HStack(spacing: 12) {
                Image(systemName: "battery.25")
                    .foregroundStyle(Color.fromHex(alert.colorHex))
                    .font(.system(size: 16, weight: .bold))

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(alert.percentage)%")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.fromHex(alert.colorHex).opacity(0.18))
                        .foregroundStyle(Color.fromHex(alert.colorHex))
                        .clipShape(Capsule())

                    Text("\(alert.position == "Center" ? "Center of Screen" : "Top of Screen") • \(alert.borderGlow ? "Border Glow" : "No Glow") • \(soundDisplayName(for: alert.soundName))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "gearshape.fill" : "gearshape")
                        .font(.system(size: 13))
                        .foregroundStyle(isExpanded ? Color.effectiveAccent : .secondary)
                }
                .buttonStyle(.plain)

                if showDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .contentShape(Rectangle())

            // Expanded Details
            if isExpanded {
                Divider()
                    .padding(.vertical, 12)

                VStack(alignment: .leading, spacing: 16) {
                    // 1. Battery Percentage and Slider (flex items center between on one line)
                    HStack(alignment: .center, spacing: 16) {
                        Text("Battery Percentage")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize()

                        Slider(value: Binding(
                            get: { Double(alert.percentage) },
                            set: { alert.percentage = Int($0) }
                        ), in: 1...50, step: 1)
                        .tint(Color.fromHex(alert.colorHex))
                    }

                    // 2. 4 Columns: Color | Position | Sound | Border Glow
                    HStack(alignment: .top, spacing: 16) {
                        // Color Column
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Color")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                ForEach(["#FF453A", "#FF9F0A", "#FFD60A"], id: \.self) { hex in
                                    Circle()
                                        .fill(Color.fromHex(hex))
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: alert.colorHex == hex ? 2 : 0)
                                                .padding(-2)
                                        )
                                        .onTapGesture {
                                            alert.colorHex = hex
                                        }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Position Column
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Position")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Button(action: { alert.position = "Top" }) {
                                    Image(systemName: "menubar.dock.rectangle")
                                        .font(.system(size: 13))
                                        .frame(width: 28, height: 24)
                                        .background(alert.position == "Top" ? Color.effectiveAccent : Color(NSColor.controlBackgroundColor))
                                        .foregroundStyle(alert.position == "Top" ? .white : .secondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .help("Top of Screen")

                                Button(action: { alert.position = "Center" }) {
                                    Image(systemName: "rectangle.inset.filled")
                                        .font(.system(size: 13))
                                        .frame(width: 28, height: 24)
                                        .background(alert.position == "Center" ? Color.effectiveAccent : Color(NSColor.controlBackgroundColor))
                                        .foregroundStyle(alert.position == "Center" ? .white : .secondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .help("Center of Screen")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Sound Column (flex-col: Sound label on top, select + icon below)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sound")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 4) {
                                Picker("", selection: $alert.soundName) {
                                    ForEach(BatterySoundChoice.allCases) { s in
                                        Text(s.title).tag(s.rawValue)
                                    }
                                    ForEach(Defaults[.customBatterySounds], id: \.self) { cs in
                                        Text(cs).tag(cs)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)

                                Button(action: {
                                    soundManager.playAny(soundName: alert.soundName)
                                }) {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Preview Sound")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Border Glow Column
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Border Glow")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Toggle("", isOn: $alert.borderGlow)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .tint(.effectiveAccent)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // 3. Alert Preview + Test Button (flex items center between)
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "eye")
                                .font(.system(size: 13))
                            Text("Alert Preview")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.secondary)

                        Spacer()

                        Button(action: onTest) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 9))
                                Text("Test")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .foregroundStyle(.white)
                            .background(Color.fromHex(alert.colorHex))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)

                    // 4. Preview Canvas (wide display box with screen glow & centered/top notification)
                    ZStack(alignment: alert.position == "Center" ? .center : .top) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(red: 0.08, green: 0.09, blue: 0.12))

                        if alert.borderGlow {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.fromHex(alert.colorHex).opacity(0.85), lineWidth: 2)
                                .shadow(color: Color.fromHex(alert.colorHex).opacity(0.5), radius: 6)
                        } else {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        }

                        // Notch indicator
                        VStack {
                            HStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.black)
                                    .frame(width: 44, height: 6)
                                Spacer()
                            }
                            Spacer()
                        }
                        .padding(.top, 2)

                        if Defaults[.batteryToastType] == .dynamicNotch && alert.position != "Center" {
                            HStack(spacing: 8) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Color.fromHex(alert.colorHex))

                                Rectangle()
                                    .fill(Color.black)
                                    .frame(width: 34, height: 7)

                                Text("\(alert.percentage)")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.fromHex(alert.colorHex))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.black))
                            .padding(.top, 2)
                        } else {
                            // Custom Battery Toast Mini Preview
                            CustomBatteryToastMiniPreview(
                                percentage: alert.percentage,
                                colorHex: alert.colorHex,
                                isCharged: false
                            )
                            .padding(.top, alert.position == "Center" ? 0 : 12)
                        }
                    }
                    .frame(height: 105)
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
        )
    }
}

// MARK: - Charged Alert Card View
struct ChargedAlertCardView: View {
    @Binding var threshold: Int
    @Binding var glowEnabled: Bool
    @Binding var soundEnabled: Bool
    @Binding var soundName: BatterySoundChoice
    @Binding var position: String
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onTest: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header Row
            HStack(spacing: 12) {
                Image(systemName: "battery.100.bolt")
                    .foregroundStyle(.green)
                    .font(.system(size: 16, weight: .bold))

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(threshold)%")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.18))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())

                    Text("\(position == "Center" ? "Center of Screen" : "Top of Screen") • \(glowEnabled ? "Border Glow" : "No Glow") • \(soundName.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "gearshape.fill" : "gearshape")
                        .font(.system(size: 13))
                        .foregroundStyle(isExpanded ? Color.effectiveAccent : .secondary)
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())

            // Expanded Details
            if isExpanded {
                Divider()
                    .padding(.vertical, 12)

                VStack(alignment: .leading, spacing: 16) {
                    // 1. Battery Percentage and Slider (flex items center between on one line)
                    HStack(alignment: .center, spacing: 16) {
                        Text("Battery Percentage")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize()

                        Slider(value: Binding(
                            get: { Double(threshold) },
                            set: { threshold = Int($0) }
                        ), in: 60...100, step: 5)
                        .tint(.green)
                    }

                    // 2. Columns: Position | Sound | Border Glow
                    HStack(alignment: .top, spacing: 16) {
                        // Position Column
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Position")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Button(action: { position = "Top" }) {
                                    Image(systemName: "menubar.dock.rectangle")
                                        .font(.system(size: 13))
                                        .frame(width: 28, height: 24)
                                        .background(position == "Top" ? Color.effectiveAccent : Color(NSColor.controlBackgroundColor))
                                        .foregroundStyle(position == "Top" ? .white : .secondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .help("Top of Screen")

                                Button(action: { position = "Center" }) {
                                    Image(systemName: "rectangle.inset.filled")
                                        .font(.system(size: 13))
                                        .frame(width: 28, height: 24)
                                        .background(position == "Center" ? Color.effectiveAccent : Color(NSColor.controlBackgroundColor))
                                        .foregroundStyle(position == "Center" ? .white : .secondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .help("Center of Screen")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Sound Column (flex-col: Sound label on top, select + icon below)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sound")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 4) {
                                Picker("", selection: $soundName) {
                                    ForEach(BatterySoundChoice.allCases) { sound in
                                        Text(sound.title).tag(sound)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)

                                Button(action: {
                                    soundName.play()
                                }) {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Preview Sound")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Border Glow Column
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Border Glow")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Toggle("", isOn: $glowEnabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .tint(.effectiveAccent)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // 3. Alert Preview + Test Button
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "eye")
                                .font(.system(size: 13))
                            Text("Alert Preview")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.secondary)

                        Spacer()

                        Button(action: onTest) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 9))
                                Text("Test")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .foregroundStyle(.white)
                            .background(Color.green)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)

                    // 4. Preview Canvas
                    ZStack(alignment: position == "Center" ? .center : .top) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(red: 0.08, green: 0.09, blue: 0.12))

                        if glowEnabled {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.green.opacity(0.85), lineWidth: 2)
                                .shadow(color: Color.green.opacity(0.5), radius: 6)
                        } else {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        }

                        // Notch indicator
                        VStack {
                            HStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.black)
                                    .frame(width: 44, height: 6)
                                Spacer()
                            }
                            Spacer()
                        }
                        .padding(.top, 2)

                        if Defaults[.batteryToastType] == .dynamicNotch && position != "Center" {
                            HStack(spacing: 8) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.green)

                                Rectangle()
                                    .fill(Color.black)
                                    .frame(width: 34, height: 7)

                                Text("\(threshold)")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(.green)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.black))
                            .padding(.top, 2)
                        } else {
                            // Custom Battery Toast Mini Preview
                            CustomBatteryToastMiniPreview(
                                percentage: threshold,
                                colorHex: "#34C759",
                                isCharged: true
                            )
                            .padding(.top, position == "Center" ? 0 : 12)
                        }
                    }
                    .frame(height: 105)
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
        )
    }
}
