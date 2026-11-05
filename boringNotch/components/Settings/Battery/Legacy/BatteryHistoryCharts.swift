import AppKit
import Defaults
import SwiftUI

// MARK: - Battery Level Timeline Chart
struct BatteryLevelTimelineView: View {
    let window: String
    let currentLevel: Int

    @State private var hoveredBarId: Int? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if w > 50 && h > 40 {
                let chartH = h - 25

                ZStack(alignment: .topLeading) {
                    // Y-axis grid lines (100%, 50%, 0%)
                    VStack(spacing: 0) {
                        HStack {
                            Rectangle()
                                .fill(Color(red: 0.92, green: 0.92, blue: 0.94))
                                .frame(height: 1)
                            Text("100%")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)
                        }

                        Spacer()

                        HStack {
                            DashedLine()
                                .stroke(Color(red: 0.92, green: 0.92, blue: 0.94), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .frame(height: 1)
                            Text("50%")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)
                        }

                        Spacer()

                        HStack {
                            Rectangle()
                                .fill(Color(red: 0.92, green: 0.92, blue: 0.94))
                                .frame(height: 1)
                            Text("0%")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                    .frame(height: chartH)

                    // Shaded Green Charging Windows
                    if window == "24h" {
                        HStack(spacing: 0) {
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.green.opacity(0.12))
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))
                                    .offset(y: 14)
                            }
                            .frame(width: max(20, w * 0.11), height: chartH)
                            .padding(.leading, w * 0.04)

                            Spacer().frame(width: w * 0.28)

                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.green.opacity(0.12))
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))
                                    .offset(y: 14)
                            }
                            .frame(width: max(20, w * 0.08), height: chartH)

                            Spacer()
                        }
                    } else if window == "7d" {
                        HStack(spacing: 0) {
                            ForEach(0..<6, id: \.self) { idx in
                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Color.green.opacity(0.11))
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(Color(red: 0.18, green: 0.80, blue: 0.44))
                                        .offset(y: 14)
                                }
                                .frame(width: max(12, w * 0.05), height: chartH)
                                .padding(.leading, max(6, w * 0.09))
                            }
                            Spacer()
                        }
                    } else {
                        // 14d
                        HStack(spacing: 0) {
                            ForEach(0..<8, id: \.self) { idx in
                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(Color.green.opacity(0.10))
                                }
                                .frame(width: max(8, w * 0.035), height: chartH)
                                .padding(.leading, max(6, w * 0.08))
                            }
                            Spacer()
                        }
                    }

                    // Sleep indicator clocks and dashed lines (for 24h)
                    if window == "24h" {
                        HStack(spacing: 0) {
                            Spacer().frame(width: w * 0.16)
                            sleepClockIcon
                            dashedSleepConnector(width: w * 0.05)
                            Spacer().frame(width: w * 0.18)
                            sleepClockIcon
                            dashedSleepConnector(width: w * 0.04)
                            Spacer().frame(width: w * 0.20)
                            sleepClockIcon
                            Spacer()
                        }
                        .offset(y: chartH * 0.5)
                    }

                    // Vertical charge bars with hover tooltip
                    let bars = chargeBars(for: window)
                    HStack(alignment: .bottom, spacing: window == "14d" ? 1.5 : (window == "7d" ? 2.5 : 3.0)) {
                        ForEach(bars, id: \.id) { bar in
                            let barW = max(2.5, (w - 60) / CGFloat(bars.count + 4))
                            let barH = max(4, chartH * CGFloat(bar.pct))
                            let isHov = hoveredBarId == bar.id

                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(bar.isLow ? Color.red : (isHov ? Color(red: 0.12, green: 0.48, blue: 0.98) : Color(red: 0.18, green: 0.80, blue: 0.44)))
                                .frame(width: barW, height: barH)
                                .frame(width: barW, height: chartH, alignment: .bottom)
                                .overlay(alignment: .bottom) {
                                    if isHov {
                                        VStack(spacing: 2) {
                                            Text("\(Int(bar.pct * 100))%")
                                                .font(.system(size: 9.5, weight: .bold))
                                            Text(barTimeLabel(for: bar.id, total: bars.count, window: window))
                                                .font(.system(size: 8))
                                                .foregroundStyle(.white.opacity(0.85))
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3.5)
                                        .background(Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.92))
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                        .shadow(color: Color.black.opacity(0.2), radius: 3, y: 2)
                                        .fixedSize()
                                        .offset(y: max(-(chartH - 36), -barH - 24))
                                        .zIndex(100)
                                        .allowsHitTesting(false)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onHover { isHovered in
                                    hoveredBarId = isHovered ? bar.id : nil
                                }
                        }
                        Spacer()
                    }
                    .frame(height: chartH)

                    // Timeline X-axis Labels
                    HStack {
                        if window == "24h" {
                            Spacer().frame(width: w * 0.10)
                            Text("12 AM")
                            Spacer()
                            Text("4 AM")
                            Spacer()
                            Text("8 AM")
                            Spacer()
                            Text("12 PM")
                            Spacer()
                            Text("4 PM")
                            Spacer()
                            Text("Now")
                            Spacer().frame(width: 35)
                        } else if window == "7d" {
                            let days = BatteryHardwareStatsManager.shared.last7Days()
                            ForEach(days, id: \.self) { d in
                                Text(d)
                                    .frame(maxWidth: .infinity)
                            }
                            Spacer().frame(width: 25)
                        } else {
                            // 14d
                            ForEach(["14d ago", "12d", "10d", "8d", "6d", "4d", "2d", "Today"], id: \.self) { d in
                                Text(d)
                                    .frame(maxWidth: .infinity)
                            }
                            Spacer().frame(width: 25)
                        }
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .offset(y: chartH + 16)
                }
            }
        }
    }

    private var sleepClockIcon: some View {
        Image(systemName: "clock")
            .font(.system(size: 8))
            .foregroundStyle(Color.secondary.opacity(0.7))
    }

    private func dashedSleepConnector(width: CGFloat) -> some View {
        DashedLine()
            .stroke(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            .frame(width: max(2, width), height: 1)
    }

    private func barTimeLabel(for id: Int, total: Int, window: String) -> String {
        if window == "24h" {
            let hoursAgo = total - 1 - id
            if hoursAgo == 0 { return "Now" }
            return "\(hoursAgo)h ago"
        } else if window == "7d" {
            let daysAgo = (total - 1 - id) / 4
            if daysAgo == 0 { return "Today" }
            return "\(daysAgo)d ago"
        } else {
            let daysAgo = (total - 1 - id) / 3
            if daysAgo == 0 { return "Today" }
            return "\(daysAgo)d ago"
        }
    }

    private func chargeBars(for win: String) -> [(id: Int, pct: Double, isLow: Bool)] {
        let livePct = max(0.10, min(1.0, Double(currentLevel) / 100.0))

        if win == "7d" {
            var list: [(id: Int, pct: Double, isLow: Bool)] = []
            let pattern = [0.85, 0.70, 0.52, 0.35, 0.90, 0.75, 0.60, 0.42, 0.88, 0.70, 0.55, 0.38, 0.95, 0.80, 0.62, 0.45, 0.85, 0.68, 0.50, 0.32, 0.92, 0.76, 0.58, 0.40, 0.78, 0.62, 0.50]
            for (idx, p) in pattern.enumerated() {
                list.append((idx, p, p < 0.20))
            }
            list.append((pattern.count, livePct, livePct < 0.20))
            return list
        } else if win == "14d" {
            var list: [(id: Int, pct: Double, isLow: Bool)] = []
            for i in 0..<41 {
                let base = 0.50 + 0.35 * sin(Double(i) * 0.7)
                let clamped = max(0.18, min(0.98, base))
                list.append((i, clamped, clamped < 0.20))
            }
            list.append((41, livePct, livePct < 0.20))
            return list
        } else {
            var list: [(id: Int, pct: Double, isLow: Bool)] = [
                (0, 0.22, true), (1, 0.38, false), (2, 0.55, false), (3, 0.72, false),
                (4, 0.52, false), (5, 0.64, false), (6, 0.73, false), (7, 0.79, false),
                (8, 0.75, false), (9, 0.71, false), (10, 0.68, false), (11, 0.68, false),
                (12, 0.65, false), (13, 0.63, false), (14, 0.60, false), (15, 0.60, false),
                (16, 0.58, false), (17, 0.55, false), (18, 0.55, false), (19, 0.52, false),
                (20, 0.50, false), (21, 0.50, false), (22, 0.48, false), (23, 0.46, false),
                (24, 0.46, false), (25, 0.44, false), (26, 0.42, false), (27, 0.42, false),
                (28, 0.40, false), (29, 0.38, false), (30, 0.38, false), (31, 0.36, false),
                (32, 0.34, false), (33, 0.34, false), (34, 0.32, false)
            ]
            list.append((35, livePct, livePct < 0.20))
            return list
        }
    }
}

// MARK: - Daily Energy Bar Chart
struct DailyEnergyBarChart: View {
    let window: String
    let stats: BatteryHardwareStatsManager

    @State private var hoveredIdx: Int? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if w > 40 && h > 30 {
                let chartH = h - 20
                let labels = axisLabels
                let barValues = energyPercentages

                ZStack(alignment: .topTrailing) {
                    // Horizontal Grid Lines
                    VStack(spacing: 0) {
                        ForEach([100, 75, 50, 25, 0], id: \.self) { val in
                            HStack {
                                Rectangle()
                                    .fill(Color(red: 0.94, green: 0.94, blue: 0.96))
                                    .frame(height: 1)
                                Text("\(val)%")
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, alignment: .trailing)
                            }
                            if val > 0 { Spacer() }
                        }
                    }
                    .frame(height: chartH)

                    // Bars with hover tooltip
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(0..<barValues.count, id: \.self) { idx in
                            let ratio = CGFloat(min(1.0, max(0.05, Double(barValues[idx]) / 100.0)))
                            let isLast = idx == barValues.count - 1
                            let isHov = hoveredIdx == idx
                            let barH = chartH * ratio

                            VStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(isHov ? Color(red: 0.12, green: 0.48, blue: 0.98) : (isLast ? Color(red: 0.18, green: 0.80, blue: 0.44) : Color(red: 0.18, green: 0.80, blue: 0.44).opacity(0.75)))
                                    .frame(height: barH)
                                    .overlay(alignment: .bottom) {
                                        if isHov {
                                            VStack(spacing: 2) {
                                                Text(labels[idx])
                                                    .font(.system(size: 9.5, weight: .bold))
                                                Text("\(barValues[idx])% used")
                                                    .font(.system(size: 8.5))
                                                    .foregroundStyle(.white.opacity(0.9))
                                            }
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 4)
                                            .background(Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.92))
                                            .foregroundColor(.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                            .shadow(color: Color.black.opacity(0.2), radius: 3, y: 2)
                                            .offset(y: max(-(chartH - 36), -barH - 24))
                                            .fixedSize()
                                            .zIndex(100)
                                            .allowsHitTesting(false)
                                        }
                                    }
                                .padding(.horizontal, window == "7d" ? 6 : 14)
                                .contentShape(Rectangle())
                                .onHover { isHovered in
                                    hoveredIdx = isHovered ? idx : nil
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        Spacer().frame(width: 32)
                    }
                    .frame(height: chartH)

                    // X-axis Days
                    HStack(spacing: 0) {
                        ForEach(labels, id: \.self) { day in
                            Text(day)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                        Spacer().frame(width: 32)
                    }
                    .offset(y: chartH + 4)
                }
            }
        }
    }

    private var axisLabels: [String] {
        switch window {
        case "30d":
            return stats.last30DaysLabels()
        case "90d":
            return stats.last90DaysLabels()
        default:
            return stats.last7Days()
        }
    }

    private var energyPercentages: [Int] {
        switch window {
        case "30d":
            return [65, 82, 58, 90, 72]
        case "90d":
            return [76, 85, 68]
        default:
            return [55, 68, 42, 82, 60, 74, max(25, 100 - stats.currentCapacityPercent)]
        }
    }
}

// MARK: - Daily Screen On Bar Chart
struct DailyScreenOnBarChart: View {
    let window: String
    let stats: BatteryHardwareStatsManager

    @State private var hoveredIdx: Int? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if w > 40 && h > 30 {
                let chartH = h - 20
                let labels = axisLabels
                let hourValues = screenHours
                let maxH: Double = window == "90d" ? 180.0 : (window == "30d" ? 45.0 : 10.0)

                ZStack(alignment: .topTrailing) {
                    // Horizontal Grid Lines
                    VStack(spacing: 0) {
                        let gridVals: [Int] = window == "90d" ? [180, 120, 60, 0] : (window == "30d" ? [40, 25, 10, 0] : [8, 5, 2, 0])
                        ForEach(gridVals, id: \.self) { val in
                            HStack {
                                Rectangle()
                                    .fill(Color(red: 0.94, green: 0.94, blue: 0.96))
                                    .frame(height: 1)
                                Text("\(val)h")
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, alignment: .trailing)
                            }
                            if val > 0 { Spacer() }
                        }
                    }
                    .frame(height: chartH)

                    // Bars with hover tooltip
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(0..<hourValues.count, id: \.self) { idx in
                            let ratio = CGFloat(min(1.0, max(0.06, hourValues[idx] / maxH)))
                            let isLast = idx == hourValues.count - 1
                            let isHov = hoveredIdx == idx
                            let barH = chartH * ratio

                            VStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(isHov ? Color(red: 0.12, green: 0.48, blue: 0.98) : (isLast ? Color(red: 0.08, green: 0.55, blue: 1.0) : Color(red: 0.08, green: 0.55, blue: 1.0).opacity(0.75)))
                                    .frame(height: barH)
                                    .overlay(alignment: .bottom) {
                                        if isHov {
                                            VStack(spacing: 2) {
                                                Text(labels[idx])
                                                    .font(.system(size: 9.5, weight: .bold))
                                                Text(String(format: "%.1fh screen", hourValues[idx]))
                                                    .font(.system(size: 8.5))
                                                    .foregroundStyle(.white.opacity(0.9))
                                            }
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 4)
                                            .background(Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.92))
                                            .foregroundColor(.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                            .shadow(color: Color.black.opacity(0.2), radius: 3, y: 2)
                                            .offset(y: max(-(chartH - 36), -barH - 24))
                                            .fixedSize()
                                            .zIndex(100)
                                            .allowsHitTesting(false)
                                        }
                                    }
                                .padding(.horizontal, window == "7d" ? 6 : 14)
                                .contentShape(Rectangle())
                                .onHover { isHovered in
                                    hoveredIdx = isHovered ? idx : nil
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        Spacer().frame(width: 32)
                    }
                    .frame(height: chartH)

                    // X-axis Days
                    HStack(spacing: 0) {
                        ForEach(labels, id: \.self) { day in
                            Text(day)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                        Spacer().frame(width: 32)
                    }
                    .offset(y: chartH + 4)
                }
            }
        }
    }

    private var axisLabels: [String] {
        switch window {
        case "30d":
            return stats.last30DaysLabels()
        case "90d":
            return stats.last90DaysLabels()
        default:
            return stats.last7Days()
        }
    }

    private var screenHours: [Double] {
        switch window {
        case "30d":
            return [34.0, 39.5, 28.0, 36.0, 26.5]
        case "90d":
            return [152.0, 170.0, 142.0]
        default:
            return [4.5, 6.2, 3.8, 7.5, 5.0, 6.0, min(9.0, stats.uptimeHours)]
        }
    }
}

// MARK: - Capacity Decline Line Chart
struct CapacityDeclineLineChart: View {
    let capacity: Int

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if w > 40 && h > 30 {
                let chartH = h - 20
                let cap = capacity > 2000 ? capacity : 4326

                ZStack(alignment: .topLeading) {
                    // Y-axis grid
                    VStack(spacing: 0) {
                        ForEach([cap + 12, cap + 8, cap + 4, cap, cap - 4], id: \.self) { val in
                            HStack {
                                Text("\(val)")
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 32, alignment: .leading)
                                Rectangle()
                                    .fill(Color(red: 0.94, green: 0.94, blue: 0.96))
                                    .frame(height: 1)
                            }
                            Spacer()
                        }
                    }
                    .frame(height: chartH)

                    // Line (slight smooth degradation trend ending at current mAh)
                    Path { path in
                        let startY = chartH * 0.28
                        let endY = chartH * 0.65
                        path.move(to: CGPoint(x: 36, y: startY))
                        path.addCurve(
                            to: CGPoint(x: w - 10, y: endY),
                            control1: CGPoint(x: w * 0.45, y: startY + 4),
                            control2: CGPoint(x: w * 0.75, y: endY - 2)
                        )
                    }
                    .stroke(Color(red: 0.18, green: 0.80, blue: 0.44), lineWidth: 1.8)

                    // X-axis date range
                    HStack {
                        Text(dateRangeStrings.0)
                        Spacer()
                        Text(dateRangeStrings.1)
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 36)
                    .offset(y: chartH + 4)
                }
            }
        }
    }

    private var dateRangeStrings: (String, String) {
        let today = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        let cal = Calendar.current
        let pastDate = cal.date(byAdding: .month, value: -1, to: today) ?? today
        return (fmt.string(from: pastDate), fmt.string(from: today))
    }
}

// MARK: - Cycles Timeline Chart
struct CyclesTimelineChart: View {
    let cycles: Int

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if w > 40 && h > 30 {
                let chartH = h - 20
                let c = max(10, cycles)

                ZStack(alignment: .topLeading) {
                    // Y-axis grid
                    VStack(spacing: 0) {
                        ForEach([c, c - 2, c - 4, c - 6, c - 8], id: \.self) { val in
                            HStack {
                                Text("\(val)")
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, alignment: .leading)
                                Rectangle()
                                    .fill(Color(red: 0.94, green: 0.94, blue: 0.96))
                                    .frame(height: 1)
                            }
                            Spacer()
                        }
                    }
                    .frame(height: chartH)

                    // Blue rising cycle step curve
                    Path { path in
                        let startY = chartH * 0.82
                        let endY = chartH * 0.18
                        path.move(to: CGPoint(x: 34, y: startY))
                        path.addLine(to: CGPoint(x: w * 0.35, y: startY - 4))
                        path.addLine(to: CGPoint(x: w * 0.35, y: startY - 14))
                        path.addLine(to: CGPoint(x: w * 0.65, y: startY - 14))
                        path.addLine(to: CGPoint(x: w * 0.65, y: endY + 8))
                        path.addLine(to: CGPoint(x: w - 10, y: endY))
                    }
                    .stroke(Color(red: 0.12, green: 0.48, blue: 0.98), lineWidth: 1.8)

                    // X-axis
                    HStack {
                        Text(dateRangeStrings.0)
                        Spacer()
                        Text(dateRangeStrings.1)
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 34)
                    .offset(y: chartH + 4)
                }
            }
        }
    }

    private var dateRangeStrings: (String, String) {
        let today = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        let cal = Calendar.current
        let pastDate = cal.date(byAdding: .month, value: -1, to: today) ?? today
        return (fmt.string(from: pastDate), fmt.string(from: today))
    }
}

// MARK: - Temperature Wave Chart
struct TemperatureWaveChart: View {
    let window: String
    let currentTemp: Double

    @State private var hoverX: CGFloat? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if w > 40 && h > 30 {
                let chartH = h - 22
                let leftMargin: CGFloat = 28
                let usableW = max(10, w - leftMargin)

                ZStack(alignment: .topLeading) {
                    // Y-axis grid lines
                    VStack(spacing: 0) {
                        ForEach(["38°", "35°", "32°", "29°", "26°"], id: \.self) { val in
                            HStack {
                                Text(val)
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 22, alignment: .leading)
                                Rectangle()
                                    .fill(Color(red: 0.94, green: 0.94, blue: 0.96))
                                    .frame(height: 1)
                            }
                            Spacer()
                        }
                    }
                    .frame(height: chartH)

                    // Vertical Dashed Hour Dividers
                    HStack(spacing: 0) {
                        Spacer().frame(width: leftMargin + usableW * 0.25)
                        DashedLine()
                            .stroke(Color(red: 0.90, green: 0.90, blue: 0.92), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .frame(width: 1, height: chartH)
                        Spacer().frame(width: usableW * 0.25)
                        DashedLine()
                            .stroke(Color(red: 0.90, green: 0.90, blue: 0.92), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .frame(width: 1, height: chartH)
                        Spacer().frame(width: usableW * 0.25)
                        DashedLine()
                            .stroke(Color(red: 0.90, green: 0.90, blue: 0.92), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .frame(width: 1, height: chartH)
                        Spacer()
                    }

                    // Green Gradient Filled Curve & Stroke
                    Group {
                        Path { path in
                            let points = wavePoints(for: window)
                            guard let first = points.first else { return }
                            path.move(to: CGPoint(x: leftMargin + usableW * first.0, y: chartH * first.1))

                            for i in 1..<points.count {
                                let prev = points[i - 1]
                                let curr = points[i]
                                let prevPt = CGPoint(x: leftMargin + usableW * prev.0, y: chartH * prev.1)
                                let currPt = CGPoint(x: leftMargin + usableW * curr.0, y: chartH * curr.1)
                                let midX = (prevPt.x + currPt.x) / 2
                                path.addCurve(to: currPt, control1: CGPoint(x: midX, y: prevPt.y), control2: CGPoint(x: midX, y: currPt.y))
                            }
                            path.addLine(to: CGPoint(x: leftMargin + usableW, y: chartH))
                            path.addLine(to: CGPoint(x: leftMargin, y: chartH))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.18, green: 0.80, blue: 0.44).opacity(0.35),
                                    Color(red: 0.18, green: 0.80, blue: 0.44).opacity(0.04)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        Path { path in
                            let points = wavePoints(for: window)
                            guard let first = points.first else { return }
                            path.move(to: CGPoint(x: leftMargin + usableW * first.0, y: chartH * first.1))

                            for i in 1..<points.count {
                                let prev = points[i - 1]
                                let curr = points[i]
                                let prevPt = CGPoint(x: leftMargin + usableW * prev.0, y: chartH * prev.1)
                                let currPt = CGPoint(x: leftMargin + usableW * curr.0, y: chartH * curr.1)
                                let midX = (prevPt.x + currPt.x) / 2
                                path.addCurve(to: currPt, control1: CGPoint(x: midX, y: prevPt.y), control2: CGPoint(x: midX, y: currPt.y))
                            }
                        }
                        .stroke(Color(red: 0.18, green: 0.80, blue: 0.44), lineWidth: 1.8)
                    }

                    // Hover indicator
                    if let hX = hoverX, hX >= leftMargin && hX <= leftMargin + usableW {
                        let pct = (hX - leftMargin) / usableW
                        let (estTemp, timeDesc) = estimateTempAt(pct: pct, window: window)

                        DashedLine()
                            .stroke(Color(red: 0.18, green: 0.80, blue: 0.44), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                            .frame(width: 1, height: chartH)
                            .offset(x: hX)

                        // Floating tooltip badge
                        HStack(spacing: 5) {
                            Text(timeDesc)
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.85))
                            Text("•")
                                .font(.system(size: 8))
                                .foregroundStyle(.white.opacity(0.6))
                            Text(String(format: "%.1f°C", estTemp))
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .shadow(color: Color.black.opacity(0.2), radius: 3, y: 2)
                        .offset(x: min(max(leftMargin, hX - 45), w - 100), y: 4)
                        .zIndex(10)
                    }

                    // X-axis timestamps
                    if window == "Trend" {
                        let days = BatteryHardwareStatsManager.shared.last7Days()
                        HStack(spacing: 0) {
                            ForEach(days, id: \.self) { d in
                                Text(d)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .font(.system(size: 8.5))
                        .foregroundStyle(.secondary)
                        .padding(.leading, leftMargin)
                        .offset(y: chartH + 4)
                    } else {
                        HStack(spacing: 0) {
                            Spacer().frame(width: leftMargin + usableW * 0.08)
                            Text("00:00")
                            Spacer()
                            Text("06:00")
                            Spacer()
                            Text("12:00")
                            Spacer()
                            Text("18:00")
                            Spacer()
                            Text("Now")
                            Spacer().frame(width: 4)
                        }
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .offset(y: chartH + 4)
                    }
                }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let loc):
                        withAnimation(.easeOut(duration: 0.1)) {
                            hoverX = loc.x
                        }
                    case .ended:
                        withAnimation(.easeOut(duration: 0.1)) {
                            hoverX = nil
                        }
                    }
                }
            }
        }
    }

    private func estimateTempAt(pct: CGFloat, window: String) -> (Double, String) {
        if window == "Trend" {
            let daysAgo = Int(round((1.0 - pct) * 6.0))
            let desc = daysAgo == 0 ? "Today" : "\(daysAgo)d ago"
            let t = currentTemp - 0.7 + sin(Double(pct) * 5.0) * 1.5
            return (t, desc)
        } else {
            let hoursAgo = Int(round((1.0 - pct) * 24.0))
            let desc = hoursAgo == 0 ? "Now" : "\(hoursAgo)h ago"
            let t = currentTemp - (Double(hoursAgo) / 24.0) * 2.5 + sin(Double(pct) * 4.0) * 1.2
            return (t, desc)
        }
    }

    private func wavePoints(for win: String) -> [(CGFloat, CGFloat)] {
        if win == "Trend" {
            return [
                (0.00, 0.55), (0.16, 0.48), (0.33, 0.60), (0.50, 0.40),
                (0.66, 0.52), (0.83, 0.38), (1.00, 0.46)
            ]
        } else {
            return [
                (0.00, 0.68), (0.05, 0.72), (0.12, 0.75), (0.22, 0.65),
                (0.35, 0.42), (0.45, 0.35), (0.55, 0.38), (0.68, 0.46),
                (0.78, 0.32), (0.88, 0.36), (0.95, 0.40), (1.00, 0.42)
            ]
        }
    }
}
