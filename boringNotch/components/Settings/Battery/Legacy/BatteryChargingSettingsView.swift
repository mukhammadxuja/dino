import AppKit
import Defaults
import SwiftUI

// MARK: - Charging Settings
struct ChargingInfoPopoverView: View {
    let title: String
    let description: String
    let example: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }

            Text(description)
                .font(.system(size: 11.5))
                .foregroundStyle(.primary.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 5) {
                Text("EXAMPLE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Text(example)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 330)
    }
}

struct ChargingSlider: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let activeColor: Color

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let thumbRadius: CGFloat = 7.5
            let usableWidth = max(1, totalWidth - thumbRadius * 2)
            let progress = max(0, min(1, CGFloat(value - range.lowerBound) / CGFloat(range.upperBound - range.lowerBound)))
            let thumbOffset = progress * usableWidth

            ZStack(alignment: .leading) {
                // Inactive track
                Capsule()
                    .fill(Color(red: 0.88, green: 0.88, blue: 0.90))
                    .frame(height: 4)

                // Active track
                Capsule()
                    .fill(activeColor)
                    .frame(width: max(0, thumbOffset + thumbRadius), height: 4)

                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 15, height: 15)
                    .overlay(
                        Circle()
                            .strokeBorder(activeColor, lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
                    .offset(x: thumbOffset)
            }
            .frame(height: 20)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let locationX = max(0, min(usableWidth, gesture.location.x - thumbRadius))
                        let pct = locationX / usableWidth
                        let newVal = Int(round(Double(range.lowerBound) + Double(pct) * Double(range.upperBound - range.lowerBound)))
                        value = max(range.lowerBound, min(range.upperBound, newVal))
                    }
            )
        }
        .frame(height: 20)
    }
}

struct BatteryChargingSettingsView: View {
    @Default(.chargeLimitEnabled) private var chargeLimitEnabled
    @Default(.chargeLimitValue) private var chargeLimitValue
    @Default(.showCableChargeStatus) private var showCableChargeStatus
    @Default(.sailingModeEnabled) private var sailingModeEnabled
    @Default(.sailingModeDropValue) private var sailingModeDropValue
    @Default(.heatProtectionEnabled) private var heatProtectionEnabled
    @Default(.sleepPreventionEnabled) private var sleepPreventionEnabled
    @Default(.automaticDischargeEnabled) private var automaticDischargeEnabled

    @State private var showChargeLimitPopover: Bool = false
    @State private var showCablePopover: Bool = false
    @State private var showSailingPopover: Bool = false
    @State private var showHeatPopover: Bool = false
    @State private var showSleepPopover: Bool = false
    @State private var showDischargePopover: Bool = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                // Header description only (Title is in the window titlebar)
                Text("Protect your battery's long-term health with a suite of safeguards.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.48))
                    .padding(.bottom, 4)

                // Card 1: Charge Limit
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.green.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Image(systemName: "shield.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))
                            Image(systemName: "heart.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Charge Limit")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Pause charging at your target so the battery sits in a healthier range.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(action: { showChargeLimitPopover.toggle() }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showChargeLimitPopover, arrowEdge: .trailing) {
                            ChargingInfoPopoverView(
                                title: "Charge Limit",
                                description: "Sets a ceiling on how far your battery charges. Staying in the 50–80% band can roughly double the number of healthy cycles your battery sees. When you hit the limit, BoringNotch tells the hardware to stop accepting power so the adapter runs the Mac directly.",
                                example: "You set the limit to 80%. The battery climbs from 60% → 80%, at which point BoringNotch pauses charging. The Mac keeps running off the adapter, and the battery sits flat at 80% until you unplug or lower the limit."
                            )
                        }

                        Toggle("", isOn: $chargeLimitEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .tint(.effectiveAccent)
                    }

                    if chargeLimitEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Text("Stop charging at")
                                    .font(.system(size: 12.5, weight: .semibold))
                                Text("\(chargeLimitValue)%")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(red: 0.12, green: 0.65, blue: 0.32))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(red: 0.88, green: 0.96, blue: 0.90))
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            }

                            Text("80% is a good default for long-term battery health.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)

                            ChargingSlider(
                                value: $chargeLimitValue,
                                range: 50...100,
                                activeColor: Color(red: 0.18, green: 0.80, blue: 0.44)
                            )

                            GeometryReader { geo in
                                let w = geo.size.width
                                ZStack(alignment: .leading) {
                                    Text("50%")
                                        .position(x: 12, y: 7)
                                    Text("80%")
                                        .position(x: 12 + (w - 24) * 0.6, y: 7)
                                    Text("100%")
                                        .position(x: w - 16, y: 7)
                                }
                            }
                            .frame(height: 14)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        }

                        Rectangle()
                            .fill(Color(red: 0.93, green: 0.93, blue: 0.95))
                            .frame(height: 1)

                        // Cable Status Row
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.green.opacity(0.12))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "cable.connector")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Show charge status on the cable")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Green when held at your limit, amber while charging.")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button(action: { showCablePopover.toggle() }) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $showCablePopover, arrowEdge: .trailing) {
                                ChargingInfoPopoverView(
                                    title: "Cable Status Light",
                                    description: "Turns your MagSafe cable into a charge-status indicator. While the battery charges toward your limit the ring glows amber; the moment BoringNotch holds it at your limit it switches to green, so the cable tells the truth about *your* healthy charge level, not Apple's 100%.\n\nThis only changes the light, never the charging itself. (LED control is hardware-specific; on some Mac models the color may differ.)",
                                    example: "Limit set to 80%. You plug in at 60% and the cable glows amber. At 80% BoringNotch pauses charging and the cable turns green, even though the battery isn't 'full' by Apple's definition."
                                )
                            }

                            Toggle("", isOn: $showCableChargeStatus)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .tint(.effectiveAccent)
                        }

                        // Active Status Banner
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Active, charging normally")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text("BoringNotch will pause charging when you hit \(chargeLimitValue)%.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color(red: 0.93, green: 0.97, blue: 0.94))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

                // Card 2: Sailing Mode
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.cyan.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Image(systemName: "sailboat.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(red: 0.0, green: 0.68, blue: 0.90))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sailing Mode")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Let the battery drift a little below the limit before topping it back up.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(action: { showSailingPopover.toggle() }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showSailingPopover, arrowEdge: .trailing) {
                            ChargingInfoPopoverView(
                                title: "Sailing Mode",
                                description: "Without Sailing Mode, BoringNotch would toggle charging on and off every time the battery drifts even a single percent below the limit. A tiny power spike drops you from 80% to 79%, charging kicks back on, and the cycle repeats. That constant churn is real wear.\n\nSailing Mode introduces a comfort zone: once you hit the limit, BoringNotch keeps charging paused and lets the battery quietly drift down by the configured amount before resuming. You choose how much drift is OK (1–20%).",
                                example: "Limit is 80%, sailing threshold is 5%. You hit 80%, charging pauses. Over a few hours the battery drifts to 77%, still within the comfort zone, still paused. When it reaches 75%, BoringNotch resumes charging back up to 80%."
                            )
                        }

                        Toggle("", isOn: $sailingModeEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .tint(.effectiveAccent)
                    }

                    if sailingModeEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Text("Resume charging when battery drops by")
                                    .font(.system(size: 12.5, weight: .semibold))
                                Text("\(sailingModeDropValue)%")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(red: 0.0, green: 0.62, blue: 0.85))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(red: 0.88, green: 0.95, blue: 0.99))
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            }

                            ChargingSlider(
                                value: $sailingModeDropValue,
                                range: 1...20,
                                activeColor: Color(red: 0.0, green: 0.75, blue: 0.95)
                            )

                            HStack {
                                Text("1%")
                                Spacer()
                                Text("20%")
                            }
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
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

                // Card 3: Heat Protection
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.orange.opacity(0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: "thermometer.sun.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 0.98, green: 0.55, blue: 0.2))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Heat Protection")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Pause charging when the battery gets too hot, regardless of percent.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(action: { showHeatPopover.toggle() }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showHeatPopover, arrowEdge: .trailing) {
                        ChargingInfoPopoverView(
                            title: "Heat Protection",
                            description: "Charging a hot battery accelerates long-term degradation. Heat Protection watches the battery's internal temperature and pauses charging whenever it crosses your threshold, regardless of how full the battery is. Charging resumes automatically once the battery cools.\n\nApple recommends avoiding ambient temperatures above 35°C. A battery-side limit of 35–40°C is a reasonable starting point; lower is more conservative.",
                            example: "Your Mac is at 60% charging toward 80%. You kick off a demanding video export and the battery climbs to 42°C. With Heat Protection set to 40°C, BoringNotch pauses charging. The Mac keeps running off the adapter, and once the battery cools below 40°C, charging resumes automatically."
                        )
                    }

                    Toggle("", isOn: $heatProtectionEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(.effectiveAccent)
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

                // Card 4: Sleep Prevention
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.purple.opacity(0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: "moon.fill")
                            .font(.system(size: 13.5))
                            .foregroundStyle(Color(red: 0.48, green: 0.38, blue: 0.9))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sleep Prevention")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Keep the Mac awake until the limit is reached, even with the lid closed.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(action: { showSleepPopover.toggle() }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showSleepPopover, arrowEdge: .trailing) {
                        ChargingInfoPopoverView(
                            title: "Sleep Prevention",
                            description: "By default, macOS puts your Mac to sleep when you close the lid. While asleep, BoringNotch can't manage charging, so the battery may end up at 100% before you open it again.\n\nSleep Prevention holds an IOKit power assertion that keeps the Mac awake (display off) until the charge limit is reached. Once you hit the limit, or unplug, the assertion releases and the Mac sleeps normally.",
                            example: "You plug in at 60% with a limit of 80% and close the lid for the night. Normally the Mac would sleep and wake at 100%. With Sleep Prevention on, it stays lightly awake until 80%, hits the limit, releases the assertion, and sleeps at exactly 80%, where it stays until morning."
                        )
                    }

                    Toggle("", isOn: $sleepPreventionEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(.effectiveAccent)
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

                // Card 5: Automatic Discharge
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.pink.opacity(0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: "arrow.down.to.line.compact")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.65))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Automatic Discharge")
                                .font(.system(size: 13, weight: .semibold))
                            Text("BETA")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color(red: 0.9, green: 0.52, blue: 0.1))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color(red: 1.0, green: 0.94, blue: 0.85))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                        Text("Run the Mac off the battery until it reaches your limit, then switch to the adapter.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(action: { showDischargePopover.toggle() }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showDischargePopover, arrowEdge: .trailing) {
                        ChargingInfoPopoverView(
                            title: "Automatic Discharge",
                            description: "Run the Mac off the battery until it reaches your limit, then switch to the adapter. This helps safely discharge down from a higher percentage without needing to unplug the charging cable manually.",
                            example: "Your Mac is currently at 95% while plugged in. If your limit is 80%, Automatic Discharge runs the battery down to 80%, and then seamlessly switches to drawing power from the power adapter."
                        )
                    }

                    Toggle("", isOn: $automaticDischargeEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(.effectiveAccent)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color.white)
        .navigationTitle("Charging")
        .accentColor(.effectiveAccent)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: chargeLimitEnabled)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: sailingModeEnabled)
    }
}
