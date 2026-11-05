# Battery metrics checks

Run from the repository root on macOS. This executable checks registry fallback decoding, valid zero cycles, missing/invalid values, and cancellation/model release. It also prints one live hardware reading without requiring a battery to be present.

```sh
mkdir -p /private/tmp/dino-battery-metrics-check
xcrun swiftc -parse-as-library -module-cache-path /private/tmp/dino-battery-metrics-check/ModuleCache boringNotch/components/Settings/Battery/BatteryMetricsReader.swift boringNotch/components/Settings/Battery/BatteryMetricsModel.swift Tests/BatteryMetrics/BatteryMetricsCheck.swift -o /private/tmp/dino-battery-metrics-check/check
/private/tmp/dino-battery-metrics-check/check
```
