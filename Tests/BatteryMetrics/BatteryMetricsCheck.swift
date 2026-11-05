import Foundation

@main
struct Check {
    @MainActor static func main() async {
        let empty = BatteryMetricsReader.decode(battery: [:], pack: [:])
        precondition(empty == .unavailable)
        let root: [String: Any] = ["CycleCount": 267, "DesignCycleCount9C": 1000,
            "BatteryData": ["FullChargeCapacity": 4296, "NominalChargeCapacity": 4423, "DesignCapacity": 4563]]
        let data = BatteryMetricsReader.decode(battery: root, pack: ["BatteryData": ["Temperature": 2709]])
        precondition(data.healthPercent == 96 && data.cycleCount == 267 && data.ratedCycleCount == 1000)
        precondition(abs(data.temperatureCelsius! - 27.09) < 0.001)
        let fallback = BatteryMetricsReader.decode(battery: ["Temperature": 0, "CycleCount": 0], pack: ["BatteryData": ["Temperature": 2915.5]])
        precondition(fallback.cycleCount == 0 && abs(fallback.temperatureCelsius! - 29.155) < 0.001)
        let direct = BatteryMetricsReader.decode(battery: ["Temperature": 3100.0, "DesignCapacity": 4000, "AppleRawMaxCapacity": 4200], pack: [:])
        precondition(direct.temperatureCelsius == 31 && direct.healthPercent == 100)
        let invalid = BatteryMetricsReader.decode(battery: ["Temperature": Double.nan, "CycleCount": -1, "DesignCycleCount9C": true, "NominalChargeCapacity": 4000, "DesignCapacity": 0], pack: [:])
        precondition(invalid == .unavailable)
        let partial = BatteryMetricsReader.decode(battery: ["BatteryData": ["FullChargeCapacity": 3000, "DesignCapacity": 4000]], pack: [:])
        precondition(partial.healthPercent == 75 && partial.temperatureCelsius == nil && partial.cycleCount == nil)
        let live = BatteryMetricsReader.read()
        print("Live metrics: health=\(String(describing: live.healthPercent)), temperature=\(String(describing: live.temperatureCelsius)), cycles=\(String(describing: live.cycleCount))")
        weak var releasedModel: BatteryMetricsModel?
        do {
            let model = BatteryMetricsModel()
            releasedModel = model
            precondition(model.snapshot == .unavailable, "Initialization must not start hardware reads")
            let task = Task { await model.monitorWhileVisible() }
            try? await Task.sleep(for: .milliseconds(200))
            task.cancel()
            let start = Date()
            await task.value
            precondition(Date().timeIntervalSince(start) < 1, "Cancellation must stop the sleeping loop immediately")
        }
        precondition(releasedModel == nil, "Leaving the page must release its metrics model")
        print("PASS: decoding, invalid/missing values, live hardware, cancellation and model release")
    }
}
