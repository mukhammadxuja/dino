import SwiftUI

struct BatterySettingsView: View {
    @StateObject private var metrics = BatteryMetricsModel()
    @Environment(\.controlActiveState) private var controlActiveState

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 18) {
                summaryCards

                Text("Notifications")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)

                BatteryNotificationSettingsView()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color.white)
        .accentColor(.effectiveAccent)
        .navigationTitle("Battery")
        .task(id: controlActiveState) {
            guard controlActiveState != .inactive else { return }
            await metrics.monitorWhileVisible()
        }
    }

    private var summaryCards: some View {
        let data = metrics.snapshot
        return HStack(alignment: .top, spacing: 12) {
            BatteryMetricCard(
                title: "HEALTH", icon: "heart.fill",
                value: data.healthPercent.map { "\($0)%" } ?? "—",
                status: data.healthPercent.map { $0 >= 80 ? "Good" : "Service recommended" } ?? "Unavailable",
                tint: data.healthPercent.map { $0 >= 80 ? Color.green : .orange } ?? .secondary,
                infoTitle: "Battery Health",
                info: "Maximum charge capacity compared with the battery's design capacity. The card uses nominal capacity when provided by your Mac.",
                tip: "Avoid excessive heat and deep discharge to protect battery lifespan."
            )
            BatteryMetricCard(
                title: "TEMPERATURE", icon: "thermometer.medium",
                value: data.temperatureCelsius.map { String(format: "%.1f°C", $0) } ?? "—",
                status: data.temperatureCelsius.map { $0 < 36 ? "Normal" : ($0 < 42 ? "Warm" : "High") } ?? "Unavailable",
                tint: data.temperatureCelsius.map { $0 < 36 ? Color.green : ($0 < 42 ? .orange : .red) } ?? .secondary,
                infoTitle: "Battery Temperature",
                info: "Current battery sensor temperature. If your Mac does not expose a reading, the card shows an unavailable value.",
                tip: "Keep the Mac on a firm surface with clear airflow."
            )
            BatteryMetricCard(
                title: "CYCLES", icon: "arrow.2.squarepath",
                value: data.cycleCount.map(String.init) ?? "—",
                status: data.cycleCount.map { _ in data.ratedCycleCount.map { "of \($0) rated" } ?? "Charge cycles" } ?? "Unavailable",
                tint: data.cycleCount == nil ? .secondary : .blue,
                infoTitle: "Battery Cycle Count",
                info: "One cycle is the cumulative use of 100% of battery capacity. Count and rated cycles come from the battery hardware.",
                tip: "Cycle count is one indicator of battery wear; check health alongside it."
            )
        }
    }
}

private struct BatteryMetricCard: View {
    let title: String
    let icon: String
    let value: String
    let status: String
    let tint: Color
    let infoTitle: String
    let info: String
    let tip: String
    @State private var showsInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(title)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Button { showsInfo.toggle() } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("About \(infoTitle)")
                .popover(isPresented: $showsInfo, arrowEdge: .top) {
                    GeneralInfoPopoverView(title: infoTitle, description: info, tip: tip)
                }
            }
            .font(.system(size: 10, weight: .semibold))

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .monospacedDigit()
            Text(status)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
        }
    }
}
