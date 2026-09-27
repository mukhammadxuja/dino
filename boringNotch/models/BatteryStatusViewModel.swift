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
    @Published private(set) var statusText: String = ""

    @Published var isGlowActive: Bool = false
    @Published var activeGlowColor: Color? = nil
    @Published var alertBannerText: String? = nil
    @Published var alertHeadlineText: String? = nil
    @Published var alertPercentage: Int = 0
    @Published var isCustomToastPresented: Bool = false

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
        let lowLimit = Defaults[.batteryLowThreshold]
        let highLimit = Defaults[.batteryHighThreshold]

        if !isCharging && !isPluggedIn && intLevel <= lowLimit {
            if lastAlertTriggered != .lowBattery {
                lastAlertTriggered = .lowBattery
                triggerAlert(type: .lowBattery)
            }
        } else if (isCharging || isPluggedIn) && intLevel >= highLimit {
            if lastAlertTriggered != .highBattery {
                lastAlertTriggered = .highBattery
                triggerAlert(type: .highBattery)
            }
        } else {
            if intLevel > lowLimit + 3 && intLevel < highLimit - 3 {
                lastAlertTriggered = nil
            }
        }
    }

    func triggerAlert(type: BatteryAlertType, isSimulation: Bool = false) {
        guard Defaults[.batteryAlertsEnabled] || isSimulation else { return }

        let glowColor: Color
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

        let currentLevel = isSimulation
            ? (type == .lowBattery ? Defaults[.batteryLowThreshold] : Defaults[.batteryHighThreshold])
            : Int(levelBattery)

        self.alertPercentage = currentLevel

        let headline = (type == .lowBattery) ? "Low Battery Warning" : "Battery Charged"
        let alertText = (type == .lowBattery) ? "Connect charger" : "Ready to unplug"

        self.alertHeadlineText = headline
        self.alertBannerText = alertText

        // 1. Audio cue
        if Defaults[.batterySoundEnabled] {
            Defaults[.batterySoundName].play()
        }

        // 2. Glow effect (Around entire screen): Smooth easeInOut, NO spring bounce
        if Defaults[.batteryGlowEnabled] {
            withAnimation(.easeInOut(duration: 0.65)) {
                self.activeGlowColor = glowColor
                self.isGlowActive = true
            }
        }

        // 3. Toast / Notification: Spring bounce effect!
        if Defaults[.batteryToastEnabled] {
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

        // Synchronized dismissal
        glowDismissTask?.cancel()
        customToastDismissTask?.cancel()
        glowDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.65)) {
                self.isGlowActive = false
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                self.isCustomToastPresented = false
            }
        }
    }

    func triggerSimulation(type: BatteryAlertType) {
        triggerAlert(type: type, isSimulation: true)
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
