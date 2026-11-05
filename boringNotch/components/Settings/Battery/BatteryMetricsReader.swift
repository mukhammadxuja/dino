import Foundation
import IOKit

struct BatteryMetricsSnapshot: Equatable, Sendable {
    var healthPercent: Int?
    var temperatureCelsius: Double?
    var cycleCount: Int?
    var ratedCycleCount: Int?

    static let unavailable = BatteryMetricsSnapshot()
}

enum BatteryMetricsReader {
    static func read() -> BatteryMetricsSnapshot {
        decode(
            battery: properties(matching: IOServiceMatching("AppleSmartBattery")),
            pack: properties(matching: IOServiceNameMatching("AppleSmartBatteryPack"))
        )
    }

    // Registry dictionaries are used only during this read; the UI retains four numbers.
    private static func properties(matching: CFMutableDictionary?) -> [String: Any] {
        guard let matching else { return [:] }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return [:] }
        defer { IOObjectRelease(service) }

        var result: [String: Any] = [:]
        for key in ["BatteryData", "NominalChargeCapacity", "AppleRawMaxCapacity",
                    "DesignCapacity", "CycleCount", "DesignCycleCount9C", "Temperature"] {
            if let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0) {
                result[key] = value.takeRetainedValue()
            }
        }
        return result
    }

    static func decode(battery: [String: Any], pack: [String: Any]) -> BatteryMetricsSnapshot {
        let data = battery["BatteryData"] as? [String: Any] ?? [:]
        let packData = pack["BatteryData"] as? [String: Any] ?? [:]

        // On Apple silicon, NominalChargeCapacity reflects maximum capacity;
        // FullChargeCapacity can be lower due to the current charge conditions.
        let capacity = firstPositive([
            battery["NominalChargeCapacity"], data["NominalChargeCapacity"],
            packData["NominalChargeCapacity"], battery["AppleRawMaxCapacity"],
            packData["AppleRawMaxCapacity"], data["FullChargeCapacity"]
        ])
        let design = firstPositive([battery["DesignCapacity"], data["DesignCapacity"], packData["DesignCapacity"]])
        let health: Int?
        if let capacity, let design {
            health = Int(min(100, max(0, floor(capacity / design * 100))))
        } else {
            health = nil
        }

        // Newer macOS versions expose temperature on the pack instead of the
        // public battery service. Values use hundredths of a degree Celsius.
        let temperature = [battery["Temperature"], data["Temperature"], pack["Temperature"], packData["Temperature"]]
            .compactMap(number)
            .map { $0 / 100 }
            .first { $0 > 0 && $0 < 100 }

        return BatteryMetricsSnapshot(
            healthPercent: health,
            temperatureCelsius: temperature,
            cycleCount: firstCount([battery["CycleCount"], data["CycleCount"], packData["CycleCount"]], allowZero: true),
            ratedCycleCount: firstCount([battery["DesignCycleCount9C"], pack["DesignCycleCount9C"], packData["DesignCycleCount9C"]], allowZero: false)
        )
    }

    private static func number(_ value: Any?) -> Double? {
        guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(), value.doubleValue.isFinite else { return nil }
        return value.doubleValue
    }

    private static func firstPositive(_ values: [Any?]) -> Double? {
        values.compactMap(number).first { $0 > 0 }
    }

    private static func firstCount(_ values: [Any?], allowZero: Bool) -> Int? {
        guard let value = values.compactMap(number).first(where: {
            $0 >= (allowZero ? 0 : 1) && $0 < 1_000_000 && $0.rounded(.towardZero) == $0
        }) else { return nil }
        return Int(value)
    }
}
