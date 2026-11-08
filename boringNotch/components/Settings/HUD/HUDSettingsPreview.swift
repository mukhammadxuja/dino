import SwiftUI

// Pure settings previews: no hardware managers, permissions or audio.
struct HUDSettingsPreview: View {
    let indicator: HUDIndicator
    var isActive = true

    @ViewBuilder var body: some View {
        Group {
            switch indicator {
            case .volume: previewVolumeHUD
            case .brightness: previewBrightnessHUD
            case .backlight: previewBacklightHUD
            case .airpods: previewAirPodsHUD
            case .capslock: previewCapsLockHUD
            case .location: previewLocationHUD
            case .camera: previewCameraHUD
            case .mic: previewMicHUD
            case .screenrecord: previewScreenRecordHUD
            case .charging: previewChargingHUD
            case .unplugged: previewUnpluggedHUD
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 42)
        .background(Capsule().fill(Color.black))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.75))
        .shadow(color: .black.opacity(0.55), radius: 9, x: 0, y: 4)
    }

    private var previewVolumeHUD: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.25)).frame(width: 70, height: 6)
                Capsule().fill(Color.white).frame(width: 52, height: 6)
            }
            Text("75%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
    }

    private var previewBrightnessHUD: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.25)).frame(width: 70, height: 6)
                Capsule().fill(Color.white).frame(width: 45, height: 6)
            }
            Text("65%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
    }

    private var previewBacklightHUD: some View {
        HStack(spacing: 8) {
            Image(systemName: "keyboard.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.25)).frame(width: 70, height: 6)
                Capsule().fill(Color.white).frame(width: 35, height: 6)
            }
            Text("50%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
    }

    private var previewAirPodsHUD: some View {
        HStack(spacing: 24) {
            AirPodsVideoView(isActive: isActive)
                .frame(width: 24, height: 24)
            AirPodsBatteryRingView(battery: 94)
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
    }

    private var previewCapsLockHUD: some View {
        HStack(spacing: 8) {
            ZStack {
                Capsule().fill(Color.effectiveAccent).frame(width: 22, height: 15)
                Image(systemName: "capslock.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            }
            Text("Caps On")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
    }

    private var previewLocationHUD: some View {
        HStack(spacing: 8) {
            ZStack {
                Capsule().fill(Color.blue).frame(width: 22, height: 15)
                Image(systemName: "location.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            }
            Text("Location In Use")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
    }

    private var previewCameraHUD: some View {
        HStack(spacing: 8) {
            ZStack {
                Capsule().fill(Color.green).frame(width: 22, height: 15)
                Image(systemName: "video.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            }
            Text("Camera On")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(.green)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
    }

    private var previewMicHUD: some View {
        HStack(spacing: 8) {
            ZStack {
                Capsule().fill(Color.orange).frame(width: 22, height: 15)
                Image(systemName: "mic.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            }
            Text("Mic On")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
    }

    private var previewScreenRecordHUD: some View {
        HStack(spacing: 8) {
            ZStack {
                Capsule().fill(Color.red).frame(width: 22, height: 15)
                Image(systemName: "record.circle.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            }
            Text("Recording")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(.red)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
    }

    private var previewChargingHUD: some View {
        BatteryInlineAlertContent(
            isLow: false,
            percentage: 99,
            color: .green,
            title: "Charging"
        )
        .frame(width: 220, height: 27)
    }

    private var previewUnpluggedHUD: some View {
        BatteryInlineAlertContent(
            isLow: false,
            percentage: 99,
            color: .white,
            title: "Unplugged"
        )
        .frame(width: 220, height: 27)
    }
}
