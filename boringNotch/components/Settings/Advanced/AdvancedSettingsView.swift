import AppKit
import Defaults
import SwiftUI

struct Advanced: View {
    @Default(.useCustomAccentColor) private var useCustomAccentColor
    @Default(.customAccentColorData) private var customAccentColorData
    @Default(.enableShadow) private var enableShadow
    @Default(.cornerRadiusScaling) private var cornerRadiusScaling
    @Default(.extendHoverArea) private var extendHoverArea
    @Default(.hideTitleBar) private var hideTitleBar
    @Default(.hideFromScreenRecording) private var hideFromScreenRecording

    @State private var customAccentColor: Color = .accentColor
    @State private var selectedPresetColor: PresetAccentColor?
    @State private var selectedIcon = "DinoLogo"
    private let icons = ["DinoLogo"]

    enum PresetAccentColor: String, CaseIterable, Identifiable {
        case blue = "Blue", purple = "Purple", pink = "Pink", red = "Red"
        case orange = "Orange", yellow = "Yellow", green = "Green", graphite = "Graphite"

        var id: String { rawValue }

        var color: Color {
            switch self {
            case .blue: return Color(red: 0, green: 0.478, blue: 1)
            case .purple: return Color(red: 0.686, green: 0.322, blue: 0.871)
            case .pink: return Color(red: 1, green: 0.176, blue: 0.333)
            case .red: return Color(red: 1, green: 0.271, blue: 0.227)
            case .orange: return Color(red: 1, green: 0.584, blue: 0)
            case .yellow: return Color(red: 1, green: 0.8, blue: 0)
            case .green: return Color(red: 0.4, green: 0.824, blue: 0.176)
            case .graphite: return Color(red: 0.557, green: 0.557, blue: 0.576)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                settingsSection(
                    "Accent Color",
                    detail: "Choose between the system accent color or a custom color for Dino."
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Accent color", selection: $useCustomAccentColor) {
                            Text("System").tag(false)
                            Text("Custom").tag(true)
                        }
                        .pickerStyle(.segmented)

                        if !useCustomAccentColor {
                            HStack(spacing: 12) {
                                AccentCircleButton(isSelected: true, color: .accentColor, isSystemDefault: true) {}
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Using System Accent")
                                        .font(.system(size: 13.5, weight: .medium))
                                    Text("Your macOS system accent color")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Color Presets")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 12) {
                                    ForEach(PresetAccentColor.allCases) { preset in
                                        AccentCircleButton(
                                            isSelected: selectedPresetColor == preset,
                                            color: preset.color
                                        ) {
                                            selectedPresetColor = preset
                                            customAccentColor = preset.color
                                            saveCustomColor(preset.color)
                                            forceUiUpdate()
                                        }
                                    }
                                    Spacer()
                                }
                                Divider()
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Pick a Color")
                                            .font(.system(size: 13.5, weight: .medium))
                                        Text("Choose any color")
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    ColorPicker(selection: Binding(
                                        get: { customAccentColor },
                                        set: { newColor in
                                            customAccentColor = newColor
                                            selectedPresetColor = nil
                                            saveCustomColor(newColor)
                                            forceUiUpdate()
                                        }
                                    ), supportsOpacity: false) {
                                        Circle().fill(customAccentColor).frame(width: 32, height: 32)
                                    }
                                    .labelsHidden()
                                }
                            }
                        }
                    }
                    .padding(16)
                }
                .onAppear { initializeAccentColorState() }

                settingsSection("Window Appearance") {
                    MediaSettingsRow(
                        icon: "shadow", iconColor: .gray,
                        title: "Enable window shadow", subtitle: "Add a shadow beneath the notch window"
                    ) { toggle($enableShadow, label: "Enable window shadow") }
                    MediaSettingsDivider()
                    MediaSettingsRow(
                        icon: "rectangle.inset.filled", iconColor: .blue,
                        title: "Corner radius scaling", subtitle: "Scale corner rounding with the notch size"
                    ) { toggle($cornerRadiusScaling, label: "Corner radius scaling") }
                }

                settingsSection("App Icon", badge: "Coming soon") {
                    HStack {
                        ForEach(icons, id: \.self) { icon in
                            Spacer()
                            VStack(spacing: 8) {
                                Image(icon)
                                    .resizable()
                                    .frame(width: 80, height: 80)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(icon == selectedIcon ? Color.effectiveAccent : .clear, lineWidth: 2.5)
                                    }
                                Text("Default")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(icon == selectedIcon ? .white : .secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(icon == selectedIcon ? Color.effectiveAccent : .clear))
                            }
                            .onTapGesture {
                                withAnimation { selectedIcon = icon }
                                NSApp.applicationIconImage = NSImage(named: icon)
                            }
                            Spacer()
                        }
                    }
                    .padding(16)
                    .disabled(true)
                }

                settingsSection("Window Behavior") {
                    MediaSettingsRow(
                        icon: "arrow.up.left.and.arrow.down.right", iconColor: .orange,
                        title: "Extend hover area", subtitle: "Use a larger area to reveal the notch"
                    ) { toggle($extendHoverArea, label: "Extend hover area") }
                    MediaSettingsDivider()
                    MediaSettingsRow(
                        icon: "rectangle.topthird.inset.filled", iconColor: .purple,
                        title: "Hide title bar", subtitle: "Hide the title bar on the Settings window"
                    ) { toggle($hideTitleBar, label: "Hide title bar") }
                    MediaSettingsDivider()
                    MediaSettingsRow(
                        icon: "camera.viewfinder", iconColor: .green,
                        title: "Hide from screen recording", subtitle: "Exclude Dino from recordings and screenshots"
                    ) { toggle($hideFromScreenRecording, label: "Hide from screen recording") }
                }
            }
            .padding(20)
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Advanced")
        .onAppear { loadCustomColor() }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        badge: String? = nil,
        detail: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                if let badge { customBadge(text: badge) }
            }
            VStack(spacing: 0, content: content)
                .hudSettingsCard()
            if let detail {
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func toggle(_ binding: Binding<Bool>, label: String) -> some View {
        Toggle(label, isOn: binding)
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(.effectiveAccent)
    }

    private func forceUiUpdate() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .init("AccentColorChanged"), object: nil)
        }
    }

    private func saveCustomColor(_ color: Color) {
        let nsColor = NSColor(color)
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: nsColor, requiringSecureCoding: false) {
            customAccentColorData = data
            forceUiUpdate()
        }
    }

    private func loadCustomColor() {
        guard let data = customAccentColorData,
              let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) else { return }
        customAccentColor = Color(nsColor: nsColor)
        selectedPresetColor = PresetAccentColor.allCases.first { colorsAreEqual(customAccentColor, $0.color) }
    }

    private func colorsAreEqual(_ color1: Color, _ color2: Color) -> Bool {
        let lhs = NSColor(color1).usingColorSpace(.sRGB) ?? NSColor(color1)
        let rhs = NSColor(color2).usingColorSpace(.sRGB) ?? NSColor(color2)
        return abs(lhs.redComponent - rhs.redComponent) < 0.01
            && abs(lhs.greenComponent - rhs.greenComponent) < 0.01
            && abs(lhs.blueComponent - rhs.blueComponent) < 0.01
    }

    private func initializeAccentColorState() {
        if !useCustomAccentColor { selectedPresetColor = nil }
        else { loadCustomColor() }
    }
}

struct AccentCircleButton: View {
    let isSelected: Bool
    let color: Color
    var isSystemDefault = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(color).frame(width: 32, height: 32)
                Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1).frame(width: 32, height: 32)
                if isSelected {
                    Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 2).frame(width: 28, height: 28)
                }
            }
        }
        .buttonStyle(.plain)
        .help(isSystemDefault ? "Use your macOS system accent color" : "")
    }
}
