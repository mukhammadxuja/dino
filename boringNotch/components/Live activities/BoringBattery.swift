import SwiftUI
import Defaults

/// A view that displays the battery status with an icon and charging indicator.
struct BatteryView: View {

    var levelBattery: Float
    var isPluggedIn: Bool
    var isCharging: Bool
    var isInLowPowerMode: Bool
    var batteryWidth: CGFloat = 26
    var isForNotification: Bool

    var icon: String = "battery.0"

    /// Determines the icon to display when charging.
    var iconStatus: String {
        if isCharging {
            return "bolt"
        }
        else if isPluggedIn {
            return "plug"
        }
        else {
            return ""
        }
    }

    /// Determines the color of the battery based on its status.
    var batteryColor: Color {
        if isInLowPowerMode {
            return .yellow
        } else if levelBattery <= 20 && !isCharging && !isPluggedIn {
            return .red
        } else if isCharging || isPluggedIn || levelBattery == 100 {
            return .green
        } else {
            return .white
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {

            Image(systemName: icon)
                .resizable()
                .fontWeight(.thin)
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.white.opacity(0.5))
                .frame(
                    width: batteryWidth + 1
                )

            RoundedRectangle(cornerRadius: 2.5)
                .fill(batteryColor)
                .frame(
                    width: CGFloat(((CGFloat(CFloat(levelBattery)) / 100) * (batteryWidth - 6))),
                    height: (batteryWidth - 2.75) - 18
                )
                .padding(.leading, 2)

            if iconStatus != "" && (isForNotification || Defaults[.showPowerStatusIcons]) {
                ZStack {
                    Image(iconStatus)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.white)
                        .frame(
                            width: 17,
                            height: 17
                        )
                }
                .frame(width: batteryWidth, height: batteryWidth)
            }
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

/// A view that displays detailed battery information and settings.
struct BatteryMenuView: View {
    
    var isPluggedIn: Bool
    var isCharging: Bool
    var levelBattery: Float
    var maxCapacity: Float
    var timeToFullCharge: Int
    var isInLowPowerMode: Bool
    var onDismiss: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack {
                Text("Battery Status")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(Int(levelBattery))%")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Max Capacity: \(Int(maxCapacity))%")
                    .font(.subheadline)
                    .fontWeight(.regular)
                if isInLowPowerMode {
                    Label("Low Power Mode", systemImage: "bolt.circle")
                        .font(.subheadline)
                        .fontWeight(.regular)
                }
                if isCharging {
                    Label("Charging", systemImage: "bolt.fill")
                        .font(.subheadline)
                        .fontWeight(.regular)
                }
                if isPluggedIn {
                    Label("Plugged In", systemImage: "powerplug.fill")
                        .font(.subheadline)
                        .fontWeight(.regular)
                }
                if timeToFullCharge > 0 {
                    Label("Time to Full Charge: \(timeToFullCharge) min", systemImage: "clock")
                        .font(.subheadline)
                        .fontWeight(.regular)
                }
                if !isCharging && isPluggedIn && levelBattery >= 80 {
                    Label("Charging on Hold: Desktop Mode", systemImage: "desktopcomputer")
                        .font(.subheadline)
                        .fontWeight(.regular)
                }
                    
            }
            .padding(.vertical, 8)

            Divider().background(Color.white)

            Button(action: openBatteryPreferences) {
                Label("Battery Settings", systemImage: "gearshape")
                    .fontWeight(.regular)
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain)
            .padding(.vertical, 8)
        }
        .padding()
        .frame(width: 280)
        .foregroundColor(.white)
    }

    private func openBatteryPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.battery") {
            openURL(url)
            onDismiss()
        }
    }
}

/// A view that displays the battery status and allows interaction to show detailed information.
struct BoringBatteryView: View {
    
    @State var batteryWidth: CGFloat = 26
    var isCharging: Bool = false
    var isInLowPowerMode: Bool = false
    var isPluggedIn: Bool = false
    var levelBattery: Float = 0
    var maxCapacity: Float = 0
    var timeToFullCharge: Int = 0
    @State var isForNotification: Bool = false
    
    @State private var showPopupMenu: Bool = false
    @State private var isPressed: Bool = false
    @State private var isHoveringButton: Bool = false
    @State private var isHoveringPopover: Bool = false
    @State private var hideTask: Task<Void, Never>? = nil

    @EnvironmentObject var vm: BoringViewModel

    var body: some View {
        Button(action: {
            withAnimation {
                showPopupMenu.toggle()
            }
        }) {
            HStack {
                if Defaults[.showBatteryPercentage] {
                    Text("\(Int32(levelBattery))%")
                        .font(.callout)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                BatteryView(
                    levelBattery: levelBattery,
                    isPluggedIn: isPluggedIn,
                    isCharging: isCharging,
                    isInLowPowerMode: isInLowPowerMode,
                    batteryWidth: batteryWidth,
                    isForNotification: isForNotification
                )
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .popover(
            isPresented: $showPopupMenu,
            arrowEdge: .bottom) {
            BatteryMenuView(
                isPluggedIn: isPluggedIn,
                isCharging: isCharging,
                levelBattery: levelBattery,
                maxCapacity: maxCapacity,
                timeToFullCharge: timeToFullCharge,
                isInLowPowerMode: isInLowPowerMode,
                onDismiss: { 
                    showPopupMenu = false
                }
            )
            .onHover { hovering in
                isHoveringPopover = hovering
                if hovering {
                    hideTask?.cancel()
                    hideTask = nil
                } else {
                    scheduleHideIfNeeded()
                }
            }
        }
        .onChange(of: showPopupMenu) {
            vm.isBatteryPopoverActive = showPopupMenu
        }
        .onDisappear {
            hideTask?.cancel()
            hideTask = nil
        }
    }

    private func scheduleHideIfNeeded() {
        if isHoveringButton || isHoveringPopover { return }
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await MainActor.run { withAnimation { showPopupMenu = false } }
        }
    }
}

// MARK: - Screen Edge Glow View (Entire Display Vignette)
struct ScreenEdgeGlowView: View {
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @State private var animatedIn: Bool = false

    var body: some View {
        GeometryReader { _ in
            let glowColor: Color = batteryModel.activeGlowColor ?? .red
            let isActive = animatedIn && batteryModel.isGlowActive

            ZStack {
                // Top screen edge bloom (pinned to top bezel, zero gap)
                LinearGradient(
                    stops: [
                        .init(color: glowColor.opacity(0.85), location: 0.0),
                        .init(color: glowColor.opacity(0.40), location: 0.35),
                        .init(color: glowColor.opacity(0.10), location: 0.70),
                        .init(color: Color.clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: isActive ? 120 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .opacity(isActive ? 1.0 : 0.0)

                // Bottom screen edge bloom (pinned to bottom bezel, zero gap)
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: glowColor.opacity(0.10), location: 0.30),
                        .init(color: glowColor.opacity(0.40), location: 0.65),
                        .init(color: glowColor.opacity(0.85), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: isActive ? 120 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .opacity(isActive ? 1.0 : 0.0)

                // Leading screen edge bloom (pinned to left bezel, zero gap)
                LinearGradient(
                    stops: [
                        .init(color: glowColor.opacity(0.85), location: 0.0),
                        .init(color: glowColor.opacity(0.40), location: 0.35),
                        .init(color: glowColor.opacity(0.10), location: 0.70),
                        .init(color: Color.clear, location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: isActive ? 120 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .opacity(isActive ? 1.0 : 0.0)

                // Trailing screen edge bloom (pinned to right bezel, zero gap)
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: glowColor.opacity(0.10), location: 0.30),
                        .init(color: glowColor.opacity(0.40), location: 0.65),
                        .init(color: glowColor.opacity(0.85), location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: isActive ? 120 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .opacity(isActive ? 1.0 : 0.0)

                // Atmospheric perimeter soft bloom
                Rectangle()
                    .strokeBorder(glowColor.opacity(0.45), lineWidth: isActive ? 24 : 0)
                    .blur(radius: 20)
                    .opacity(isActive ? 1.0 : 0.0)

                // Delicate perimeter neon rim
                Rectangle()
                    .strokeBorder(glowColor.opacity(0.75), lineWidth: 2)
                    .blur(radius: 2)
                    .opacity(isActive ? 1.0 : 0.0)
            }
            .animation(
                .easeInOut(duration: 0.65),
                value: isActive
            )
            .onAppear {
                if batteryModel.isGlowActive {
                    withAnimation(.easeInOut(duration: 0.65)) {
                        animatedIn = true
                    }
                }
            }
            .onChange(of: batteryModel.isGlowActive) { active in
                withAnimation(.easeInOut(duration: 0.65)) {
                    animatedIn = active
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Custom Floating Spring Toast View
struct CustomBatteryToastView: View {
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared

    var body: some View {
        let isLow = batteryModel.lastAlertTriggered == .lowBattery || (batteryModel.levelBattery <= Float(Defaults[.batteryLowThreshold]))
        let tintColor: Color = batteryModel.activeGlowColor ?? (isLow ? .red : .green)
        let displayPercentage = batteryModel.alertPercentage > 0 ? batteryModel.alertPercentage : Int(batteryModel.levelBattery)

        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tintColor.opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: isLow ? "battery.25" : "battery.100.bolt")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tintColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(batteryModel.alertHeadlineText ?? (isLow ? "Low Battery Warning" : "Battery Charged"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(batteryModel.alertBannerText ?? (isLow ? "Connect charger" : "Ready to unplug"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer(minLength: 8)

            Text("\(displayPercentage)%")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(tintColor.opacity(0.25))
                .foregroundStyle(tintColor)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 340)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.75))
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [tintColor.opacity(0.85), tintColor.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .shadow(color: tintColor.opacity(0.35), radius: 14, x: 0, y: 6)
        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    BoringBatteryView(
        batteryWidth: 30,
        isCharging: false,
        isInLowPowerMode: false,
        isPluggedIn: true,
        levelBattery: 80,
        maxCapacity: 100,
        timeToFullCharge: 10,
        isForNotification: false
    ).frame(width: 200, height: 200)
}
