import AppKit
import Defaults
import SwiftUI

enum HUDIndicator: String, CaseIterable, Identifiable {
    case volume, brightness, backlight, airpods, capslock, location, camera, mic, screenrecord, charging, unplugged, lowPowerMode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .volume: return "Volume"
        case .brightness: return "Display Brightness"
        case .backlight: return "Keyboard Backlight"
        case .airpods: return "AirPods & Bluetooth Audio"
        case .capslock: return "Caps Lock Indicator"
        case .location: return "Location In-Use"
        case .camera: return "Camera In-Use"
        case .mic: return "Microphone In-Use"
        case .screenrecord: return "Screen Recording"
        case .charging: return "Charging"
        case .unplugged: return "Unplugged"
        case .lowPowerMode: return "Low Power Mode"
        }
    }

    var subtitle: String {
        switch self {
        case .volume: return "Audio volume slider and mute notification toast"
        case .brightness: return "Screen brightness slider with level percentage"
        case .backlight: return "Keyboard illumination level slider indicator"
        case .airpods: return "iOS Dynamic Island connection animation and circular battery ring"
        case .capslock: return "Instant notch feedback when Caps Lock is engaged or released"
        case .location: return "Privacy indicator when Location Services are requested or active"
        case .camera: return "Privacy indicator when the webcam or Continuity Camera is active"
        case .mic: return "Privacy indicator when the system microphone is recording audio"
        case .screenrecord: return "Privacy alert when screen capture or screen recording is active"
        case .charging: return "Inline HUD when the power adapter is connected"
        case .unplugged: return "Inline HUD when the power adapter is disconnected"
        case .lowPowerMode: return "Inline HUD when Low Power Mode is turned on or off"
        }
    }

    var icon: String {
        switch self {
        case .volume: return "speaker.wave.2.fill"
        case .brightness: return "sun.max.fill"
        case .backlight: return "keyboard.fill"
        case .airpods: return "airpodspro"
        case .capslock: return "capslock.fill"
        case .location: return "location.fill"
        case .camera: return "video.fill"
        case .mic: return "mic.fill"
        case .screenrecord: return "record.circle.fill"
        case .charging: return "battery.100percent"
        case .unplugged: return "battery.0percent"
        case .lowPowerMode: return "bolt.batteryblock.fill"
        }
    }

    var tint: Color {
        switch self {
        case .volume: return .blue
        case .brightness: return .orange
        case .backlight: return .purple
        case .airpods: return .green
        case .capslock: return .indigo
        case .location: return .cyan
        case .camera: return .green
        case .mic: return .orange
        case .screenrecord: return .red
        case .charging: return .green
        case .unplugged: return .orange
        case .lowPowerMode: return .yellow
        }
    }

    var key: Defaults.Key<Bool> {
        switch self {
        case .volume: return .hudVolumeEnabled
        case .brightness: return .hudBrightnessEnabled
        case .backlight: return .hudBacklightEnabled
        case .airpods: return .hudAirPodsEnabled
        case .capslock: return .hudCapsLockEnabled
        case .location: return .hudLocationEnabled
        case .camera: return .hudCameraEnabled
        case .mic: return .hudMicEnabled
        case .screenrecord: return .hudScreenRecordEnabled
        case .charging: return .hudChargingEnabled
        case .unplugged: return .hudUnpluggedEnabled
        case .lowPowerMode: return .hudLowPowerModeEnabled
        }
    }

    var detail: String {
        switch self {
        case .volume: return "Fires when adjusting system volume with keyboard keys or menu bar. Shows speaker symbol, animated volume slider, and percentage."
        case .brightness: return "Fires when adjusting screen brightness using function keys. Shows sun icon with smooth slider and real-time percentage."
        case .backlight: return "Fires when adjusting keyboard illumination level. Shows keyboard glyph, progress bar, and lighting status."
        case .airpods: return "Fires automatically when AirPods or wireless headphones connect. Displays an animated 3D AirPods model on the left and a circular battery progress ring on the right."
        case .capslock: return "Fires instantly whenever Caps Lock is pressed. Shows a highlighted badge and 'Caps On' or 'Caps Off' indicator."
        case .location: return "Fires when any application or system service accesses your location. Displays a blue location capsule with 'Location In Use' status."
        case .camera: return "Fires when any app starts using the webcam. Shows a green privacy capsule and 'Camera On' alert."
        case .mic: return "Fires when an app accesses the microphone. Displays an orange audio capsule and 'Mic On' indicator."
        case .screenrecord: return "Fires when macOS screencapture, QuickTime, or meeting software records the screen. Displays a red recording capsule."
        case .charging: return "Shows a separate inline charging HUD when the power adapter connects."
        case .unplugged: return "Shows a separate inline unplugged HUD when the power adapter disconnects."
        case .lowPowerMode: return "Shows a yellow battery HUD when macOS Low Power Mode is turned on or off."
        }
    }

    var testOptions: [HUDTestOption] {
        switch self {
        case .volume:
            return [.init(title: "Test 75%", value: 0.75), .init(title: "Test Mute", value: 0)]
        case .brightness:
            return [.init(title: "Test Bright", value: 0.65), .init(title: "Test Dim", value: 0)]
        case .backlight:
            return [.init(title: "Test On", value: 0.5), .init(title: "Test Off", value: 0)]
        case .airpods:
            return [.init(title: "Test 94%", value: 94), .init(title: "Test 15%", value: 15)]
        case .capslock:
            return [.init(title: "Test On", value: 1), .init(title: "Test Off", value: 0)]
        case .location:
            return [.init(title: "Test On", value: 1), .init(title: "Test Off", value: 0)]
        case .camera:
            return [.init(title: "Test On", value: 1), .init(title: "Test Off", value: 0)]
        case .mic:
            return [.init(title: "Test On", value: 1), .init(title: "Test Off", value: 0)]
        case .screenrecord:
            return [.init(title: "Test Start", value: 1), .init(title: "Test Stop", value: 0)]
        case .charging, .unplugged, .lowPowerMode:
            return []
        }
    }
}

struct HUDTestOption: Identifiable {
    let title: String
    let value: CGFloat
    var id: String { title }
}

struct HUDIndicatorSettingsSection: View {
    @State private var expandedIndicator: HUDIndicator?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Active HUDs & Indicators")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                customBadge(text: "Inline")
            }
            VStack(spacing: 0) {
                ForEach(HUDIndicator.allCases) { indicator in
                    HUDIndicatorSettingsRow(indicator: indicator, expandedIndicator: $expandedIndicator)
                    if indicator != HUDIndicator.allCases.last {
                        Divider().padding(.horizontal, 16)
                    }
                }
            }
            .hudSettingsCard()
        }
    }
}

private struct HUDIndicatorSettingsRow: View {
    let indicator: HUDIndicator
    @Binding var expandedIndicator: HUDIndicator?
    @Default private var isEnabled: Bool
    @State private var lowPowerModePreviewIsOn = true

    init(indicator: HUDIndicator, expandedIndicator: Binding<HUDIndicator?>) {
        self.indicator = indicator
        self._expandedIndicator = expandedIndicator
        self._isEnabled = Default(indicator.key)
    }

    private var isExpanded: Bool { expandedIndicator == indicator }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(indicator.tint.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: indicator.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(indicator.tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(indicator.title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(indicator.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 12)
                if indicator == .airpods && isEnabled {
                    HUDBluetoothPermissionView()
                }
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        expandedIndicator = isExpanded ? nil : indicator
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Preview \(indicator.title)")
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("LIVE PREVIEW")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary.opacity(0.8))
                        Spacer()
                        if indicator == .lowPowerMode {
                            Button("Test On") { testLowPowerModeHUD(isOn: true) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            Button("Test Off") { testLowPowerModeHUD(isOn: false) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        } else if !indicator.testOptions.isEmpty {
                            ForEach(indicator.testOptions) { option in
                                Button(option.title) { testHUD(indicator, value: option.value) }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                        } else {
                            Button("Test") { testHUD(indicator) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                    HStack {
                        Spacer()
                        HUDSettingsPreview(
                            indicator: indicator,
                            isActive: isExpanded,
                            lowPowerModeIsOn: lowPowerModePreviewIsOn
                        )
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.92), in: RoundedRectangle(cornerRadius: 14))
                    Text(indicator.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.primary.opacity(0.02))
            }
        }
        .onChange(of: isEnabled) { _, enabled in
            switch indicator {
            case .airpods:
                if enabled { BluetoothHUDManager.shared.start() }
                else { BluetoothHUDManager.shared.stop() }
            case .location where enabled:
                PrivacyHUDManager.shared.enableLocationTrackingIfNeeded()
            default:
                break
            }
        }
    }

    private func testHUD(_ indicator: HUDIndicator, value: CGFloat? = nil) {
        let coordinator = BoringViewCoordinator.shared
        switch indicator {
        case .volume:
            coordinator.toggleSneakPeek(status: true, type: .volume, value: value ?? 0.75, force: true)
        case .brightness:
            coordinator.toggleSneakPeek(status: true, type: .brightness, value: value ?? 0.65, force: true)
        case .backlight:
            coordinator.toggleSneakPeek(status: true, type: .backlight, value: value ?? 0.5, force: true)
        case .airpods:
            coordinator.toggleSneakPeek(status: true, type: .airPods, duration: 5.2, value: value ?? 94, icon: "AirPods Pro", force: true)
        case .capslock:
            coordinator.toggleSneakPeek(status: true, type: .capsLock, value: value ?? 1, force: true)
        case .location:
            coordinator.toggleSneakPeek(status: true, type: .location, value: value ?? 1, force: true)
        case .camera:
            coordinator.toggleSneakPeek(status: true, type: .camera, value: value ?? 1, force: true)
        case .mic:
            coordinator.toggleSneakPeek(status: true, type: .micActivity, value: value ?? 1, force: true)
        case .screenrecord:
            coordinator.toggleSneakPeek(status: true, type: .screenRecord, value: value ?? 1, force: true)
        case .charging:
            coordinator.toggleExpandingView(status: true, type: .charging)
        case .unplugged:
            coordinator.toggleExpandingView(status: true, type: .unplugged)
        case .lowPowerMode:
            testLowPowerModeHUD(isOn: true)
        }
    }

    private func testLowPowerModeHUD(isOn: Bool) {
        lowPowerModePreviewIsOn = isOn
        BatteryStatusViewModel.shared.testLowPowerModeHUD(isEnabled: isOn)
    }
}

