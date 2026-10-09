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
    @State private var isToastVisible: Bool = false

    var body: some View {
        GeometryReader { _ in
            let glowColor: Color = batteryModel.activeGlowColor ?? .red
            let isActive = animatedIn && batteryModel.isGlowActive
            let bloomDepth = Defaults[.batteryGlowIntensity].bloomDepth
            let maxOpacity = Defaults[.batteryGlowIntensity].maxOpacity

            ZStack {
                // Top screen edge bloom (pinned to top bezel, zero gap)
                LinearGradient(
                    stops: [
                        .init(color: glowColor.opacity(maxOpacity), location: 0.0),
                        .init(color: glowColor.opacity(maxOpacity * 0.45), location: 0.35),
                        .init(color: glowColor.opacity(maxOpacity * 0.12), location: 0.70),
                        .init(color: Color.clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: isActive ? bloomDepth : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .opacity(isActive ? 1.0 : 0.0)

                // Bottom screen edge bloom (pinned to bottom bezel, zero gap)
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: glowColor.opacity(maxOpacity * 0.12), location: 0.30),
                        .init(color: glowColor.opacity(maxOpacity * 0.45), location: 0.65),
                        .init(color: glowColor.opacity(maxOpacity), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: isActive ? bloomDepth : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .opacity(isActive ? 1.0 : 0.0)

                // Leading screen edge bloom (pinned to left bezel, zero gap)
                LinearGradient(
                    stops: [
                        .init(color: glowColor.opacity(maxOpacity), location: 0.0),
                        .init(color: glowColor.opacity(maxOpacity * 0.45), location: 0.35),
                        .init(color: glowColor.opacity(maxOpacity * 0.12), location: 0.70),
                        .init(color: Color.clear, location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: isActive ? bloomDepth : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .opacity(isActive ? 1.0 : 0.0)

                // Trailing screen edge bloom (pinned to right bezel, zero gap)
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: glowColor.opacity(maxOpacity * 0.12), location: 0.30),
                        .init(color: glowColor.opacity(maxOpacity * 0.45), location: 0.65),
                        .init(color: glowColor.opacity(maxOpacity), location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: isActive ? bloomDepth : 0)
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

                // Centered Floating Toast when Position is Center
                if batteryModel.alertPosition == "Center" {
                    CustomBatteryToastView()
                        .scaleEffect(isToastVisible ? 1.0 : 0.72, anchor: .center)
                        .opacity(isToastVisible ? 1.0 : 0.0)
                }
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
                if batteryModel.isCustomToastPresented && batteryModel.alertPosition == "Center" {
                    isToastVisible = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                        withAnimation(.spring(response: 0.48, dampingFraction: 0.65)) {
                            isToastVisible = true
                        }
                    }
                }
            }
            .onChange(of: batteryModel.isGlowActive) { active in
                withAnimation(.easeInOut(duration: 0.65)) {
                    animatedIn = active
                }
            }
            .onChange(of: batteryModel.isCustomToastPresented) { presented in
                if presented && batteryModel.alertPosition == "Center" {
                    isToastVisible = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                        withAnimation(.spring(response: 0.48, dampingFraction: 0.65)) {
                            isToastVisible = true
                        }
                    }
                } else {
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.65)) {
                        isToastVisible = false
                    }
                }
            }
            .onChange(of: batteryModel.alertTriggerId) { _ in
                if batteryModel.isCustomToastPresented && batteryModel.alertPosition == "Center" {
                    isToastVisible = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                        withAnimation(.spring(response: 0.48, dampingFraction: 0.65)) {
                            isToastVisible = true
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Custom Floating Spring Toast View
struct CustomBatteryToastView: View {
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @State private var animatedProgress: CGFloat = 0.0

    var body: some View {
        let isLow = batteryModel.lastAlertTriggered == .lowBattery || (batteryModel.levelBattery <= Float(Defaults[.batteryLowThreshold]))
        let defaultNeon = isLow
            ? Color(red: 255/255, green: 69/255, blue: 58/255) // Neon Red (#FF453A)
            : Color(red: 48/255, green: 209/255, blue: 88/255) // Neon Green (#30D158)
        let tintColor: Color = batteryModel.activeGlowColor ?? defaultNeon
        let displayPercentage = batteryModel.alertPercentage > 0 ? batteryModel.alertPercentage : Int(batteryModel.levelBattery)
        let targetProgress = min(max(CGFloat(displayPercentage) / 100.0, 0.0), 1.0)
        let remainingTimeText = batteryModel.formattedRemainingTime

        HStack(spacing: 12) {
            // Interactive Horizontal Motion Slider
            GeometryReader { geo in
                let trackWidth = geo.size.width
                let trackHeight: CGFloat = 4.0
                let centerY = geo.size.height / 2.0
                let badgeWidth: CGFloat = 38.0
                let badgeHeight: CGFloat = 21.0
                
                let fillWidth = max(0, trackWidth * animatedProgress)
                let halfBadge = badgeWidth / 2.0
                let badgeX = min(max(fillWidth, halfBadge), max(halfBadge, trackWidth - halfBadge))

                ZStack(alignment: .leading) {
                    // 1. Dark background track line
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: trackWidth, height: trackHeight)
                        .position(x: trackWidth / 2.0, y: centerY)

                    // 2. Active filled progress line (left to badge)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tintColor.opacity(0.85), tintColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, badgeX), height: trackHeight)
                        .position(x: max(0, badgeX) / 2.0, y: centerY)

                    // 3. One-sided Aerodynamic Speed Trail (Havo oqimi / slipstream)
                    if isLow {
                        // Low battery: head moves leftward -> speed trail shoots out on the RIGHT side
                        let trailWidth = min(trackWidth - (badgeX + halfBadge * 0.5), 50.0)
                        if trailWidth > 0 {
                            LinearGradient(
                                colors: [
                                    tintColor.opacity(0.85),
                                    tintColor.opacity(0.35),
                                    tintColor.opacity(0.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: trailWidth, height: 6.5)
                            .blur(radius: 4.0)
                            .position(x: badgeX + halfBadge * 0.5 + (trailWidth / 2.0), y: centerY)
                        }

                        // Asymmetric soft bloom trailing to the right
                        Capsule()
                            .fill(tintColor.opacity(0.40))
                            .frame(width: badgeWidth + 14, height: badgeHeight + 8)
                            .blur(radius: 9)
                            .position(x: badgeX + 5, y: centerY)
                    } else {
                        // Charged / Charging: head moves rightward -> speed trail shoots out on the LEFT side
                        let trailWidth = min(badgeX - halfBadge * 0.5, 50.0)
                        if trailWidth > 0 {
                            LinearGradient(
                                colors: [
                                    tintColor.opacity(0.0),
                                    tintColor.opacity(0.35),
                                    tintColor.opacity(0.85)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: trailWidth, height: 6.5)
                            .blur(radius: 4.0)
                            .position(x: (badgeX - halfBadge * 0.5) - (trailWidth / 2.0), y: centerY)
                        }

                        // Asymmetric soft bloom trailing to the left
                        Capsule()
                            .fill(tintColor.opacity(0.40))
                            .frame(width: badgeWidth + 14, height: badgeHeight + 8)
                            .blur(radius: 9)
                            .position(x: badgeX - 5, y: centerY)
                    }

                    // 4. Value Capsule Badge (⚡ + Percentage)
                    ZStack {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [tintColor, tintColor.opacity(0.92)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.75)
                            )
                            // Directional shadow: only trails on the slipstream side
                            .shadow(
                                color: tintColor.opacity(0.70),
                                radius: 7,
                                x: isLow ? 5 : -5,
                                y: 0
                            )

                        HStack(spacing: 2.0) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 9.0, weight: .black))
                                .foregroundStyle(Color.white.opacity(0.95))

                            Text("\(displayPercentage)")
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white)
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(width: badgeWidth, height: badgeHeight)
                    .position(x: badgeX, y: centerY)
                }
            }
            .frame(height: 24)

            // Remaining Time Estimate (~15m)
            Text(remainingTimeText)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(tintColor)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.leading, 18)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
        .frame(width: 250, height: 48)
        .background(
            ZStack {
                Capsule()
                    .fill(Color.black)

                Capsule()
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.75)
            }
        )
        .shadow(
            color: tintColor.opacity(0.20),
            radius: 12,
            x: isLow ? 3 : -3,
            y: 4
        )
        .shadow(color: Color.black.opacity(0.75), radius: 14, x: 0, y: 5)
        .scaleEffect(Defaults[.batteryToastSize].scale, anchor: .top)
        .onAppear {
            triggerSpringAnimation(target: targetProgress, isLow: isLow)
        }
        .onChange(of: batteryModel.alertTriggerId) { _ in
            triggerSpringAnimation(target: targetProgress, isLow: isLow)
        }
        .onChange(of: displayPercentage) { _ in
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                animatedProgress = targetProgress
            }
        }
    }

    private func triggerSpringAnimation(target: CGFloat, isLow: Bool) {
        if isLow {
            // Rush backwards from right to left
            animatedProgress = min(1.0, target + 0.35)
        } else {
            // Rush forward from left to right
            animatedProgress = max(0.0, target - 0.35)
        }
        withAnimation(.spring(response: 0.65, dampingFraction: 0.72)) {
            animatedProgress = target
        }
    }
}

// MARK: - Mini Preview of Custom Battery Toast for Settings
struct CustomBatteryToastMiniPreview: View {
    var percentage: Int
    var colorHex: String? = nil
    var isCharged: Bool = false

    var body: some View {
        let isLow = !isCharged && (percentage <= Defaults[.batteryLowThreshold])
        let defaultNeon = isLow
            ? Color(red: 255/255, green: 69/255, blue: 58/255)
            : Color(red: 48/255, green: 209/255, blue: 88/255)
        let tintColor: Color = colorHex != nil ? Color.fromHex(colorHex!) : defaultNeon
        let progress = min(max(CGFloat(percentage) / 100.0, 0.0), 1.0)
        let timeText = isLow ? "~15m" : (isCharged ? "100%" : "~1h 15m")

        HStack(spacing: 8) {
            GeometryReader { geo in
                let trackWidth = geo.size.width
                let centerY = geo.size.height / 2.0
                let badgeWidth: CGFloat = 30.0
                let badgeHeight: CGFloat = 16.0
                let halfBadge = badgeWidth / 2.0
                let fillWidth = max(0, trackWidth * progress)
                let badgeX = min(max(fillWidth, halfBadge), max(halfBadge, trackWidth - halfBadge))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: trackWidth, height: 3)
                        .position(x: trackWidth / 2.0, y: centerY)

                    Capsule()
                        .fill(tintColor)
                        .frame(width: max(0, badgeX), height: 3)
                        .position(x: max(0, badgeX) / 2.0, y: centerY)

                    if isLow {
                        let trailWidth = min(trackWidth - (badgeX + halfBadge * 0.5), 35.0)
                        if trailWidth > 0 {
                            LinearGradient(
                                colors: [tintColor.opacity(0.85), tintColor.opacity(0.0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: trailWidth, height: 5)
                            .blur(radius: 2.5)
                            .position(x: badgeX + halfBadge * 0.5 + (trailWidth / 2.0), y: centerY)
                        }
                    } else {
                        let trailWidth = min(badgeX - halfBadge * 0.5, 35.0)
                        if trailWidth > 0 {
                            LinearGradient(
                                colors: [tintColor.opacity(0.0), tintColor.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: trailWidth, height: 5)
                            .blur(radius: 2.5)
                            .position(x: (badgeX - halfBadge * 0.5) - (trailWidth / 2.0), y: centerY)
                        }
                    }

                    ZStack {
                        Capsule()
                            .fill(tintColor)
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5))
                            .shadow(color: tintColor.opacity(0.6), radius: 4, x: isLow ? 3 : -3, y: 0)

                        HStack(spacing: 1.5) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(Color.white)

                            Text("\(percentage)")
                                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white)
                        }
                    }
                    .frame(width: badgeWidth, height: badgeHeight)
                    .position(x: badgeX, y: centerY)
                }
            }
            .frame(height: 18)

            Text(timeText)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundStyle(tintColor)
                .fixedSize()
        }
        .padding(.leading, 10)
        .padding(.trailing, 9)
        .padding(.vertical, 5)
        .frame(width: 175, height: 32)
        .background(
            ZStack {
                Capsule().fill(Color.black)
                Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            }
        )
        .shadow(color: tintColor.opacity(0.2), radius: 6, x: 0, y: 2)
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
