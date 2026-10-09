import Cocoa
import Defaults
import Foundation
import IOKit.ps
import SwiftUI
import UserNotifications

/// A view model that manages and monitors the battery status of the device
class BatteryStatusViewModel: ObservableObject {

    private var wasCharging: Bool = false
    private var powerSourceChangedCallback: IOPowerSourceCallbackType?
    private var runLoopSource: Unmanaged<CFRunLoopSource>?

    @ObservedObject var coordinator = BoringViewCoordinator.shared

    enum BatteryAlertType {
        case lowBattery
        case highBattery
    }

    @Published private(set) var levelBattery: Float = 0.0
    @Published private(set) var maxCapacity: Float = 0.0
    @Published private(set) var isPluggedIn: Bool = false
    @Published private(set) var isCharging: Bool = false
    @Published private(set) var isInLowPowerMode: Bool = false
    @Published private(set) var isInitial: Bool = false
    @Published private(set) var timeToFullCharge: Int = 0
    @Published private(set) var timeToEmpty: Int = 0
    @Published private(set) var statusText: String = ""

    var formattedRemainingTime: String {
        let level = alertPercentage > 0 ? alertPercentage : Int(levelBattery)
        let isLowAlert = lastAlertTriggered == .lowBattery || level <= Defaults[.batteryLowThreshold]

        if isCharging || isPluggedIn {
            if timeToFullCharge > 0 {
                if timeToFullCharge >= 60 {
                    let h = timeToFullCharge / 60
                    let m = timeToFullCharge % 60
                    return m > 0 ? "~\(h)h \(m)m" : "~\(h)h"
                } else {
                    return "~\(timeToFullCharge)m"
                }
            } else if level >= 100 {
                return "100%"
            } else {
                return "~15m"
            }
        } else if isLowAlert {
            if level <= 10 {
                return "~15m"
            } else if level <= 20 {
                return "~25m"
            } else {
                return "~35m"
            }
        } else {
            if timeToEmpty > 0 && timeToEmpty < 1000 {
                if timeToEmpty >= 60 {
                    let h = timeToEmpty / 60
                    let m = timeToEmpty % 60
                    return m > 0 ? "~\(h)h \(m)m" : "~\(h)h"
                } else {
                    return "~\(timeToEmpty)m"
                }
            } else {
                if level <= 10 {
                    return "~15m"
                } else if level <= 20 {
                    return "~30m"
                } else if level <= 50 {
                    return "~1h 15m"
                } else {
                    return "~2h 45m"
                }
            }
        }
    }

    @Published var isGlowActive: Bool = false
    @Published var activeGlowColor: Color? = nil
    @Published var alertBannerText: String? = nil
    @Published var alertHeadlineText: String? = nil
    @Published var alertPercentage: Int = 0
    @Published var isCustomToastPresented: Bool = false

    @Published var alertPosition: String = "Top"
    @Published var alertTriggerId: UUID = UUID()
    private var triggeredLowAlertIds: Set<UUID> = []
    private var isChargedAlertTriggered: Bool = false

    private var glowDismissTask: Task<Void, Never>?
    private var customToastDismissTask: Task<Void, Never>?
    @Published private(set) var lastAlertTriggered: BatteryAlertType? = nil

    private let managerBattery = BatteryActivityManager.shared
    private var managerBatteryId: Int?

    static let shared = BatteryStatusViewModel()

    /// Initializes the view model with a given BoringViewModel instance
    /// - Parameter vm: The BoringViewModel instance
    private init() {
        setupPowerStatus()
        setupMonitor()
    }

    /// Sets up the initial power status by fetching battery information
    private func setupPowerStatus() {
        let batteryInfo = managerBattery.initializeBatteryInfo()
        updateBatteryInfo(batteryInfo)
    }

    /// Sets up the monitor to observe battery events
    private func setupMonitor() {
        managerBatteryId = managerBattery.addObserver { [weak self] event in
            guard let self = self else { return }
            self.handleBatteryEvent(event)
        }
    }

    /// Handles battery events and updates the corresponding properties
    /// - Parameter event: The battery event to handle
    private func handleBatteryEvent(_ event: BatteryActivityManager.BatteryEvent) {
        switch event {
        case .powerSourceChanged(let isPluggedIn):
            print("🔌 Power source: \(isPluggedIn ? "Connected" : "Disconnected")")
            withAnimation {
                self.isPluggedIn = isPluggedIn
                self.statusText = isPluggedIn ? "Plugged In" : "Unplugged"
                self.notifyImportanChangeStatus()
            }

        case .batteryLevelChanged(let level):
            print("🔋 Battery level: \(Int(level))%")
            withAnimation {
                self.levelBattery = level
            }
            self.checkThresholds(level: level)

        case .lowPowerModeChanged(let isEnabled):
            print("⚡ Low power mode: \(isEnabled ? "Enabled" : "Disabled")")
            self.notifyImportanChangeStatus()
            withAnimation {
                self.isInLowPowerMode = isEnabled
                self.statusText = "Low Power: \(self.isInLowPowerMode ? "On" : "Off")"
            }

        case .isChargingChanged(let isCharging):
            print("🔌 Charging: \(isCharging ? "Yes" : "No")")
            print("maxCapacity: \(self.maxCapacity)")
            print("levelBattery: \(self.levelBattery)")
            self.notifyImportanChangeStatus()
            withAnimation {
                self.isCharging = isCharging
                self.statusText =
                    isCharging
                    ? "Charging battery"
                    : (self.levelBattery < self.maxCapacity ? "Not charging" : "Full charge")
            }

        case .timeToFullChargeChanged(let time):
            print("🕒 Time to full charge: \(time) minutes")
            withAnimation {
                self.timeToFullCharge = time
            }

        case .maxCapacityChanged(let capacity):
            print("🔋 Max capacity: \(capacity)")
            withAnimation {
                self.maxCapacity = capacity
            }

        case .error(let description):
            print("⚠️ Error: \(description)")
        }
    }

    /// Updates the battery information with the given BatteryInfo instance
    /// - Parameter batteryInfo: The BatteryInfo instance containing the battery data
    private func updateBatteryInfo(_ batteryInfo: BatteryInfo) {
        withAnimation {
            self.levelBattery = batteryInfo.currentCapacity
            self.isPluggedIn = batteryInfo.isPluggedIn
            self.isCharging = batteryInfo.isCharging
            self.isInLowPowerMode = batteryInfo.isInLowPowerMode
            self.timeToFullCharge = batteryInfo.timeToFullCharge
            self.timeToEmpty = batteryInfo.timeToEmpty
            self.maxCapacity = batteryInfo.maxCapacity
            self.statusText = batteryInfo.isPluggedIn ? "Plugged In" : "Unplugged"
        }
    }

    /// Notifies important changes in the battery status with an optional delay
    /// - Parameter delay: The delay before notifying the change, default is 0.0
    private func notifyImportanChangeStatus(delay: Double = 0.0) {
        Task {
            try? await Task.sleep(for: .seconds(delay))
            self.coordinator.toggleExpandingView(status: true, type: .battery)
        }
    }

    private func checkThresholds(level: Float) {
        guard Defaults[.batteryAlertsEnabled] else { return }

        let intLevel = Int(level)

        if !isCharging && !isPluggedIn {
            // Running on battery -> check configured low battery alerts
            let alerts = Defaults[.lowBatteryAlerts].filter { $0.isEnabled }
            for alert in alerts.sorted(by: { $0.percentage > $1.percentage }) {
                if intLevel <= alert.percentage {
                    if !triggeredLowAlertIds.contains(alert.id) {
                        triggeredLowAlertIds.insert(alert.id)
                        triggerAlert(
                            type: .lowBattery,
                            percentage: alert.percentage,
                            colorHex: alert.colorHex,
                            position: alert.position,
                            soundName: alert.soundName,
                            borderGlow: alert.borderGlow,
                            isSimulation: false
                        )
                    }
                } else if intLevel > alert.percentage + 3 {
                    triggeredLowAlertIds.remove(alert.id)
                }
            }
            isChargedAlertTriggered = false
        } else if isCharging || isPluggedIn {
            // Plugged in or charging -> reset low battery triggers
            triggeredLowAlertIds.removeAll()

            let chargedThreshold = Defaults[.chargedAlertThreshold]
            if intLevel >= chargedThreshold {
                if !isChargedAlertTriggered {
                    isChargedAlertTriggered = true
                    triggerAlert(
                        type: .highBattery,
                        percentage: chargedThreshold,
                        colorHex: "#34C759",
                        position: Defaults[.chargedAlertPosition],
                        soundName: Defaults[.chargedAlertSoundEnabled] ? Defaults[.chargedAlertSoundName].rawValue : nil,
                        borderGlow: Defaults[.chargedAlertGlowEnabled],
                        isSimulation: false
                    )
                }
            } else if intLevel < chargedThreshold - 3 {
                isChargedAlertTriggered = false
            }
        }
    }

    func triggerAlert(
        type: BatteryAlertType,
        percentage: Int? = nil,
        colorHex: String? = nil,
        position: String = "Top",
        soundName: String? = nil,
        borderGlow: Bool = true,
        isSimulation: Bool = false
    ) {
        guard Defaults[.batteryAlertsEnabled] || isSimulation else { return }

        let glowColor: Color
        if let hex = colorHex {
            glowColor = Color.fromHex(hex)
        } else {
            switch Defaults[.batteryGlowColorMode] {
            case .dynamic:
                glowColor = (type == .lowBattery) ? .red : .green
            case .red:
                glowColor = .red
            case .green:
                glowColor = .green
            case .custom:
                glowColor = .effectiveAccent
            }
        }

        let currentLevel = percentage ?? (isSimulation
            ? (type == .lowBattery ? 20 : Defaults[.chargedAlertThreshold])
            : Int(levelBattery))

        self.alertPercentage = currentLevel
        self.alertPosition = position
        self.lastAlertTriggered = type
        self.alertTriggerId = UUID()

        let headline = (type == .lowBattery) ? "Low Battery Warning" : "Battery Charged"
        let alertText = (type == .lowBattery) ? "Connect charger" : "Ready to unplug"

        self.alertHeadlineText = headline
        self.alertBannerText = alertText

        // 1. Audio cue
        let soundToPlay = soundName ?? (Defaults[.batterySoundEnabled] ? Defaults[.batterySoundName].rawValue : nil)
        if let sound = soundToPlay, !sound.isEmpty && sound != "None" {
            CustomSoundManager.shared.playAny(soundName: sound)
        }

        // 2. Glow effect (Around entire screen): Smooth easeInOut
        if borderGlow && Defaults[.batteryGlowEnabled] {
            withAnimation(.easeInOut(duration: 0.65)) {
                self.activeGlowColor = glowColor
                self.isGlowActive = true
            }
        } else {
            self.activeGlowColor = glowColor
            self.isGlowActive = false
        }

        // 3. Toast / Notification
        if Defaults[.batteryToastEnabled] {
            if position == "Center" {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                    self.isCustomToastPresented = true
                }
            } else {
                switch Defaults[.batteryToastType] {
                case .dynamicNotch:
                    self.statusText = alertText
                    self.coordinator.toggleExpandingView(status: true, type: .battery)
                case .customToast:
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                        self.isCustomToastPresented = true
                    }
                }
            }
        }

        // Synchronized dismissal
        glowDismissTask?.cancel()
        customToastDismissTask?.cancel()
        glowDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.65)) {
                self.isGlowActive = false
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                self.isCustomToastPresented = false
            }
        }
    }

    func triggerSimulation(
        type: BatteryAlertType,
        percentage: Int? = nil,
        colorHex: String? = nil,
        position: String = "Top",
        soundName: String? = nil,
        borderGlow: Bool = true
    ) {
        triggerAlert(
            type: type,
            percentage: percentage,
            colorHex: colorHex,
            position: position,
            soundName: soundName,
            borderGlow: borderGlow,
            isSimulation: true
        )
    }

    private func postNativeNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "batteryAlert_\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    deinit {
        print("🔌 Cleaning up battery monitoring...")
        if let managerBatteryId: Int = managerBatteryId {
            managerBattery.removeObserver(byId: managerBatteryId)
        }
    }

}
