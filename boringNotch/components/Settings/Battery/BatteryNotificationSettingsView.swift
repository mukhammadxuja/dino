import AppKit
import Defaults
import SwiftUI

// MARK: - Battery Alerts Settings View
struct BatteryNotificationSettingsView: View {
    @Default(.batteryToastType) private var batteryToastType
    @Default(.batteryToastSize) private var batteryToastSize
    @Default(.batteryGlowIntensity) private var batteryGlowIntensity
    @Default(.batteryShowGlowInPreview) private var batteryShowGlowInPreview
    @Default(.lowBatteryAlerts) private var lowBatteryAlerts
    @Default(.chargedAlertThreshold) private var chargedAlertThreshold
    @Default(.chargedAlertGlowEnabled) private var chargedAlertGlowEnabled
    @Default(.chargedAlertSoundEnabled) private var chargedAlertSoundEnabled
    @Default(.chargedAlertSoundName) private var chargedAlertSoundName
    @Default(.chargedAlertPosition) private var chargedAlertPosition
    @Default(.customBatterySounds) private var customBatterySounds

    @Default(.batteryAlertsEnabled) private var batteryAlertsEnabled

    @ObservedObject private var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject private var soundManager = CustomSoundManager.shared

    @State private var expandedAlertId: UUID? = nil
    @State private var isChargedExpanded: Bool = false

    var body: some View {
        alertSections
    }

    private var alertSections: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Configure low battery thresholds, charge alerts, screen glows, and custom sounds.")
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.48))
                .padding(.bottom, 4)

            masterNotificationCard

            if batteryAlertsEnabled {
                appearanceCard
                lowBatterySection
                chargedAlertCard
                customSoundsCard
                resetCard
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.2), value: batteryAlertsEnabled)
    }

    private var masterNotificationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.12, green: 0.48, blue: 0.98))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Battery notifications")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Receive notifications and screen edge glow alerts for battery milestones.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $batteryAlertsEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(.effectiveAccent)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
        )
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.indigo.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: "eye.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.indigo)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Notification Appearance")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Choose between Dynamic Notch pill and custom floating toast alerts.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
            }

            Rectangle()
                .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                .frame(height: 1)

            HStack {
                Text("Alert Style")
                    .font(.system(size: 13))
                Spacer()
                Picker("", selection: $batteryToastType) {
                    ForEach(BatteryToastType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .labelsHidden()
                .frame(width: 150, alignment: .trailing)
            }

            if batteryToastType == .customToast {
                Rectangle()
                    .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                    .frame(height: 1)

                HStack {
                    Text("Alert Bubble Size")
                        .font(.system(size: 13))
                    Spacer()
                    Picker("", selection: $batteryToastSize) {
                        ForEach(BatteryToastSize.allCases) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150, alignment: .trailing)
                }
            }

            Rectangle()
                .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                .frame(height: 1)

            HStack {
                Text("Screen Edge Glow")
                    .font(.system(size: 13))
                Spacer()
                Picker("", selection: $batteryGlowIntensity) {
                    ForEach(BatteryGlowIntensity.allCases) { intensity in
                        Text(intensity.title).tag(intensity)
                    }
                }
                .labelsHidden()
                .frame(width: 150, alignment: .trailing)
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

    private var lowBatterySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("LOW BATTERY ALERTS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            }
            .padding(.leading, 2)
            .padding(.top, 4)

            ForEach(Array(lowBatteryAlerts.enumerated()), id: \.element.id) { index, alert in
                LowBatteryAlertCardView(
                    alert: binding(for: index),
                    isExpanded: expandedAlertId == alert.id,
                    showDelete: lowBatteryAlerts.count > 1,
                    onToggleExpand: {
                        toggleExpand(for: alert.id)
                    },
                    onDelete: {
                        deleteAlert(at: index)
                    },
                    onTest: {
                        batteryModel.triggerAlert(
                            type: .lowBattery,
                            percentage: alert.percentage,
                            colorHex: alert.colorHex,
                            position: alert.position,
                            soundName: alert.soundName,
                            borderGlow: alert.borderGlow,
                            isSimulation: true
                        )
                    }
                )
            }

            HStack {
                Spacer()
                Button(action: addNewAlert) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Add Low Battery Alert")
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                Spacer()
            }
            .padding(.top, 4)
        }
    }

    private var chargedAlertCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CHARGED ALERT")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
                .padding(.leading, 2)
                .padding(.top, 4)

            ChargedAlertCardView(
                threshold: $chargedAlertThreshold,
                glowEnabled: $chargedAlertGlowEnabled,
                soundEnabled: $chargedAlertSoundEnabled,
                soundName: $chargedAlertSoundName,
                position: $chargedAlertPosition,
                isExpanded: isChargedExpanded,
                onToggleExpand: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isChargedExpanded.toggle()
                    }
                },
                onTest: {
                    batteryModel.triggerAlert(
                        type: .highBattery,
                        percentage: chargedAlertThreshold,
                        colorHex: "#34C759",
                        position: chargedAlertPosition,
                        soundName: chargedAlertSoundEnabled ? chargedAlertSoundName.rawValue : nil,
                        borderGlow: chargedAlertGlowEnabled,
                        isSimulation: true
                    )
                }
            )
        }
    }

    private var customSoundsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: "music.note")
                        .foregroundStyle(.purple)
                        .font(.system(size: 13))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom Audio Sounds")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Import MP3, WAV, M4A, or AIFF sounds for battery alerts.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: {
                    soundManager.importSound()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import")
                    }
                }
                .controlSize(.small)
            }

            if !customBatterySounds.isEmpty {
                Rectangle()
                    .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                    .frame(height: 1)

                ForEach(customBatterySounds, id: \.self) { sound in
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundStyle(.secondary)
                        Text(sound)
                            .font(.system(size: 12.5))
                            .lineLimit(1)
                        Spacer()
                        Button(action: {
                            soundManager.playCustom(soundName: sound)
                        }) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 15))
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            soundManager.deleteSound(name: sound)
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
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

    private var resetCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Restore Defaults")
                    .font(.system(size: 13, weight: .semibold))
                Text("Reset all battery alert thresholds, sounds, and preferences.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive, action: resetAlerts) {
                Text("Reset")
            }
            .controlSize(.small)
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

    private func toggleExpand(for id: UUID) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            if expandedAlertId == id {
                expandedAlertId = nil
            } else {
                expandedAlertId = id
            }
        }
    }

    private func deleteAlert(at index: Int) {
        if lowBatteryAlerts.count > 1 && index < lowBatteryAlerts.count {
            lowBatteryAlerts.remove(at: index)
        }
    }

    private func addNewAlert() {
        let currentMins = lowBatteryAlerts.map(\.percentage).min() ?? 20
        let nextPct = max(5, currentMins - 5)
        let newAlert = BatteryAlertItem(
            percentage: nextPct,
            isEnabled: true,
            soundName: Defaults.Keys.lowBatteryAlerts.defaultValue.first?.soundName ?? "Basso",
            borderGlow: true,
            colorHex: nextPct <= 10 ? "#FF453A" : "#FF9F0A",
            isPersistent: false,
            position: "Top"
        )
        lowBatteryAlerts.append(newAlert)
        withAnimation {
            expandedAlertId = newAlert.id
        }
    }

    private func resetAlerts() {
        lowBatteryAlerts = Defaults.Keys.lowBatteryAlerts.defaultValue
        chargedAlertThreshold = Defaults.Keys.chargedAlertThreshold.defaultValue
        chargedAlertGlowEnabled = Defaults.Keys.chargedAlertGlowEnabled.defaultValue
        chargedAlertSoundEnabled = Defaults.Keys.chargedAlertSoundEnabled.defaultValue
        chargedAlertSoundName = Defaults.Keys.chargedAlertSoundName.defaultValue
        chargedAlertPosition = Defaults.Keys.chargedAlertPosition.defaultValue
        batteryGlowIntensity = Defaults.Keys.batteryGlowIntensity.defaultValue
        batteryToastSize = Defaults.Keys.batteryToastSize.defaultValue
        batteryToastType = Defaults.Keys.batteryToastType.defaultValue
    }

    private func binding(for index: Int) -> Binding<BatteryAlertItem> {
        Binding(
            get: {
                if index < lowBatteryAlerts.count {
                    return lowBatteryAlerts[index]
                }
                return BatteryAlertItem(percentage: 20)
            },
            set: { newValue in
                if index < lowBatteryAlerts.count {
                    lowBatteryAlerts[index] = newValue
                }
            }
        )
    }
}
