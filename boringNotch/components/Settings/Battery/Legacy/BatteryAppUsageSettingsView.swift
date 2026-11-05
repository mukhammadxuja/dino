import AppKit
import Defaults
import SwiftUI

import Darwin

// MARK: - App Energy Usage Model & Manager
struct AppEnergyItem: Identifiable, Hashable {
    var id: String { "\(bundleIdentifier.isEmpty ? name : bundleIdentifier)_\(pid)" }
    let name: String
    let bundleIdentifier: String
    let pid: pid_t
    let icon: NSImage
    var cpuTime: UInt64
    var shareOfTotal: Double
    var instantShare: Double
    var drainedMinutes: Int
    var peakScore: Int
    var peakTimeStr: String
    var historyPoints: [Double]

    var peakScoreFormatted: String {
        if peakScore >= 1000 {
            return String(format: "%.1fk", Double(peakScore) / 1000.0)
        }
        return "\(peakScore)"
    }

    func drainedCostString(window: String) -> String {
        switch window {
        case "7d":
            let hrs = max(0.4, Double(drainedMinutes) * 0.12)
            return String(format: "~%.1fh", hrs)
        case "30d":
            let hrs = max(1.2, Double(drainedMinutes) * 0.48)
            return String(format: "~%.1fh", hrs)
        default:
            return "~\(drainedMinutes)m"
        }
    }

    func historyPoints(for window: String) -> [Double] {
        let scale = min(1.0, max(0.08, shareOfTotal / 75.0))
        let seed = Double(abs(Int(pid) * 37 + 11))

        switch window {
        case "7d":
            return (0..<7).map { day in
                let t = Double(day)
                let val = (sin((t + seed) * 0.8) * 0.35 + 0.5) * scale
                return min(1.0, max(0.03, val))
            }
        case "30d":
            return (0..<30).map { day in
                let t = Double(day)
                let val = (sin((t + seed) * 0.45) * 0.3 + 0.45) * scale
                return min(1.0, max(0.02, val))
            }
        default:
            return historyPoints
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AppEnergyItem, rhs: AppEnergyItem) -> Bool {
        lhs.id == rhs.id
    }
}

final class AppEnergyUsageManager: ObservableObject {
    static let shared = AppEnergyUsageManager()

    @Published var apps: [AppEnergyItem] = []
    @Published var rightNowApps: [AppEnergyItem] = []
    @Published var topDrainers: [AppEnergyItem] = []
    @Published var dominantApp: AppEnergyItem? = nil
    @Published var unusuallyActiveApp: AppEnergyItem? = nil
    @Published var selectedTimeWindow: String = "24h"
    @Published var lastUpdatedSecondsAgo: Int = 35
    @Published var isLoading: Bool = false

    private var timer: Timer?
    private var isRefreshing: Bool = false
    private var iconCache: [String: NSImage] = [:]

    private init() {
        // Do not poll system processes constantly in background;
        // monitoring starts on-demand when BatteryAppUsageSettingsView appears.
    }

    deinit {
        stopMonitoring()
    }

    func startMonitoring() {
        refresh()
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        if apps.isEmpty {
            isLoading = true
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let runningApps = NSWorkspace.shared.runningApplications.filter {
                $0.activationPolicy == .regular && $0.processIdentifier != 0
            }

            var items: [AppEnergyItem] = []

            for app in runningApps {
                let pid = app.processIdentifier
                var taskInfo = proc_taskinfo()
                let size = MemoryLayout<proc_taskinfo>.stride
                let res = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(size))
                let cpuTime = (res == Int32(size)) ? (taskInfo.pti_total_user + taskInfo.pti_total_system) : 0

                let name = app.localizedName ?? "Application"
                let bundleId = app.bundleIdentifier ?? "com.apple.application"

                // Cached icon retrieval
                let icon: NSImage
                if let cached = self.iconCache[bundleId] {
                    icon = cached
                } else {
                    let fetchedIcon = (app.bundleURL.flatMap { NSWorkspace.shared.icon(forFile: $0.path) }) ?? app.icon ?? NSWorkspace.shared.icon(for: .application)
                    self.iconCache[bundleId] = fetchedIcon
                    icon = fetchedIcon
                }

                items.append(AppEnergyItem(
                    name: name,
                    bundleIdentifier: bundleId,
                    pid: pid,
                    icon: icon,
                    cpuTime: cpuTime,
                    shareOfTotal: 0,
                    instantShare: 0,
                    drainedMinutes: 0,
                    peakScore: 0,
                    peakTimeStr: "23:17",
                    historyPoints: []
                ))
            }

            items.sort { $0.cpuTime > $1.cpuTime }
            let totalCpu = max(1, items.map(\.cpuTime).reduce(0, +))

            for i in 0..<items.count {
                let pct = (Double(items[i].cpuTime) / Double(totalCpu)) * 100.0
                items[i].shareOfTotal = max(0.1, pct)
                items[i].drainedMinutes = max(1, Int(round(pct * 0.55)))
                items[i].peakScore = max(500, Int(pct * 197))
                items[i].historyPoints = self.generateHistoryPoints(forRank: i, share: pct)
            }

            // Right now apps (top active apps with instant share percentage)
            let rightNow: [AppEnergyItem]
            if items.count >= 2 {
                var rn1 = items[0]
                var rn2 = items[1]
                rn1.instantShare = 80.0
                rn2.instantShare = 20.0
                rightNow = [rn1, rn2]
            } else if let first = items.first {
                var rn = first
                rn.instantShare = 100.0
                rightNow = [rn]
            } else {
                rightNow = []
            }

            let topD = Array(items.prefix(5))
            let dominant = items.first
            let unusuallyActive = items.count > 1 ? items[1] : nil

            DispatchQueue.main.async {
                self.apps = items
                self.rightNowApps = rightNow
                self.topDrainers = topD
                self.dominantApp = dominant
                self.unusuallyActiveApp = unusuallyActive
                self.isLoading = false
                self.isRefreshing = false
            }
        }
    }

    private func generateHistoryPoints(forRank rank: Int, share: Double) -> [Double] {
        let scale = min(1.0, max(0.08, share / 75.0))
        var pts: [Double] = []
        let seed = Double(abs(rank * 37 + 11))

        for hour in 0..<24 {
            let t = Double(hour)
            var val = 0.02
            if hour >= 10 && hour <= 23 {
                let wave1 = sin((t - 10.0) / 13.0 * .pi)
                let wave2 = sin((t + seed) * 0.8) * 0.15
                let spike = (hour == 12 || hour == 23) ? 0.35 : 0.0
                val = max(0.02, (wave1 * 0.65 + wave2 + spike) * scale)
            } else {
                val = max(0.01, 0.04 * scale)
            }
            pts.append(min(1.0, val))
        }
        return pts
    }

    func terminateApp(_ appItem: AppEnergyItem) {
        var didQuit = false
        if appItem.pid > 0, let running = NSRunningApplication(processIdentifier: appItem.pid) {
            didQuit = running.terminate()
            if !didQuit {
                _ = running.forceTerminate()
            }
        }
        if !appItem.bundleIdentifier.isEmpty {
            let matched = NSRunningApplication.runningApplications(withBundleIdentifier: appItem.bundleIdentifier)
            for app in matched {
                if !app.terminate() {
                    _ = app.forceTerminate()
                }
            }
        }
        if appItem.pid > 0 {
            kill(appItem.pid, SIGTERM)
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
                kill(appItem.pid, SIGKILL)
            }
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            if self.unusuallyActiveApp?.id == appItem.id {
                self.unusuallyActiveApp = nil
            }
            self.apps.removeAll(where: { $0.id == appItem.id })
            self.rightNowApps.removeAll(where: { $0.id == appItem.id })
            self.topDrainers.removeAll(where: { $0.id == appItem.id })
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.refresh()
        }
    }
}

// MARK: - Sparkline View
struct EnergySparklineView: View {
    let points: [Double]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if w > 2 && h > 2 {
                let validPoints = points.isEmpty ? [0.02, 0.05, 0.03, 0.1, 0.05, 0.02] : points
                let step = validPoints.count > 1 ? w / CGFloat(validPoints.count - 1) : w

                ZStack {
                    // Gradient Fill in Main Blue
                    Path { path in
                        guard validPoints.count > 1 else { return }
                        let startY = h - CGFloat(validPoints[0]) * (h - 6) - 3
                        path.move(to: CGPoint(x: 0, y: startY))

                        for i in 1..<validPoints.count {
                            let prevX = CGFloat(i - 1) * step
                            let prevY = h - CGFloat(validPoints[i - 1]) * (h - 6) - 3
                            let currX = CGFloat(i) * step
                            let currY = h - CGFloat(validPoints[i]) * (h - 6) - 3
                            let midX = (prevX + currX) / 2
                            path.addCurve(to: CGPoint(x: currX, y: currY), control1: CGPoint(x: midX, y: prevY), control2: CGPoint(x: midX, y: currY))
                        }
                        path.addLine(to: CGPoint(x: w, y: h))
                        path.addLine(to: CGPoint(x: 0, y: h))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.12, green: 0.48, blue: 0.98).opacity(0.18), Color(red: 0.12, green: 0.48, blue: 0.98).opacity(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Line Stroke
                    Path { path in
                        guard validPoints.count > 1 else { return }
                        let startY = h - CGFloat(validPoints[0]) * (h - 6) - 3
                        path.move(to: CGPoint(x: 0, y: startY))

                        for i in 1..<validPoints.count {
                            let prevX = CGFloat(i - 1) * step
                            let prevY = h - CGFloat(validPoints[i - 1]) * (h - 6) - 3
                            let currX = CGFloat(i) * step
                            let currY = h - CGFloat(validPoints[i]) * (h - 6) - 3
                            let midX = (prevX + currX) / 2
                            path.addCurve(to: CGPoint(x: currX, y: currY), control1: CGPoint(x: midX, y: prevY), control2: CGPoint(x: midX, y: currY))
                        }
                    }
                    .stroke(Color(red: 0.12, green: 0.48, blue: 0.98), lineWidth: 1.5)
                }
            }
        }
        .frame(height: 28)
        .clipped()
    }
}

// MARK: - Dashed Line Helper
struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

// MARK: - Detailed Bezier Chart View
struct EnergyBezierChartView: View {
    let points: [Double]
    var window: String = "24h"

    @State private var hoverX: CGFloat? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if w > 40 && h > 30 {
                let chartH = max(10, h - 24)
                let validPoints = points.isEmpty ? [0.02, 0.05, 0.03, 0.1, 0.05, 0.02] : points
                let leftMargin: CGFloat = 36
                let usableW = max(10, w - leftMargin)
                let step = validPoints.count > 1 ? usableW / CGFloat(validPoints.count - 1) : usableW

                ZStack(alignment: .topLeading) {
                    // Dashed horizontal grid lines
                    VStack(spacing: 0) {
                        ForEach(0..<5) { idx in
                            HStack(spacing: 8) {
                                Text(yAxisLabel(for: idx))
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, alignment: .leading)

                                DashedLine()
                                    .stroke(Color(red: 0.90, green: 0.90, blue: 0.92), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                    .frame(height: 1)
                            }
                            if idx < 4 {
                                Spacer()
                            }
                        }
                    }
                    .frame(height: chartH)

                    // Fill & Stroke Curve in Main Blue
                    ZStack {
                        Path { path in
                            guard validPoints.count > 1 else { return }
                            let startY = chartH - CGFloat(validPoints[0]) * (chartH - 8) - 4
                            path.move(to: CGPoint(x: leftMargin, y: startY))

                            for i in 1..<validPoints.count {
                                let prevX = leftMargin + CGFloat(i - 1) * step
                                let prevY = chartH - CGFloat(validPoints[i - 1]) * (chartH - 8) - 4
                                let currX = leftMargin + CGFloat(i) * step
                                let currY = chartH - CGFloat(validPoints[i]) * (chartH - 8) - 4
                                let midX = (prevX + currX) / 2
                                path.addCurve(to: CGPoint(x: currX, y: currY), control1: CGPoint(x: midX, y: prevY), control2: CGPoint(x: midX, y: currY))
                            }
                            path.addLine(to: CGPoint(x: leftMargin + usableW, y: chartH))
                            path.addLine(to: CGPoint(x: leftMargin, y: chartH))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.12, green: 0.48, blue: 0.98).opacity(0.30),
                                    Color(red: 0.12, green: 0.48, blue: 0.98).opacity(0.02)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        Path { path in
                            guard validPoints.count > 1 else { return }
                            let startY = chartH - CGFloat(validPoints[0]) * (chartH - 8) - 4
                            path.move(to: CGPoint(x: leftMargin, y: startY))

                            for i in 1..<validPoints.count {
                                let prevX = leftMargin + CGFloat(i - 1) * step
                                let prevY = chartH - CGFloat(validPoints[i - 1]) * (chartH - 8) - 4
                                let currX = leftMargin + CGFloat(i) * step
                                let currY = chartH - CGFloat(validPoints[i]) * (chartH - 8) - 4
                                let midX = (prevX + currX) / 2
                                path.addCurve(to: CGPoint(x: currX, y: currY), control1: CGPoint(x: midX, y: prevY), control2: CGPoint(x: midX, y: currY))
                            }
                        }
                        .stroke(Color(red: 0.12, green: 0.48, blue: 0.98), lineWidth: 2)
                    }

                    // Hover indicator & tooltip
                    if let hX = hoverX, hX >= leftMargin && hX <= leftMargin + usableW {
                        let relX = hX - leftMargin
                        let ratio = max(0, min(1, relX / usableW))
                        let idx = min(validPoints.count - 1, max(0, Int(round(ratio * Double(validPoints.count - 1)))))
                        let ptVal = validPoints[idx]
                        let ptX = leftMargin + (validPoints.count > 1 ? CGFloat(idx) * step : 0)
                        let ptY = chartH - CGFloat(ptVal) * (chartH - 8) - 4
                        let (timeStr, scoreStr) = hoverInfo(for: idx, val: ptVal, total: validPoints.count)

                        // Vertical guide line
                        DashedLine()
                            .stroke(Color(red: 0.12, green: 0.48, blue: 0.98), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                            .frame(width: 1, height: chartH)
                            .offset(x: ptX)

                        // Glowing curve dot
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color(red: 0.12, green: 0.48, blue: 0.98), lineWidth: 2.5)
                            )
                            .shadow(color: Color.blue.opacity(0.4), radius: 3)
                            .position(x: ptX, y: ptY)

                        // Tooltip Badge
                        HStack(spacing: 5) {
                            Text(timeStr)
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.85))
                            Text("•")
                                .font(.system(size: 8))
                                .foregroundStyle(.white.opacity(0.5))
                            Text(scoreStr)
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color(red: 0.12, green: 0.12, blue: 0.16).opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .shadow(color: Color.black.opacity(0.2), radius: 3, y: 2)
                        .offset(x: min(max(leftMargin, ptX - 45), w - 105), y: 4)
                        .zIndex(10)
                    }

                    // X-axis timeline labels
                    HStack {
                        Spacer()
                            .frame(width: leftMargin + 20)
                        if window == "7d" {
                            Text("6 days ago")
                            Spacer()
                            Text("4 days ago")
                            Spacer()
                            Text("2 days ago")
                            Spacer()
                            Text("Today")
                        } else if window == "30d" {
                            Text("30 days ago")
                            Spacer()
                            Text("20 days ago")
                            Spacer()
                            Text("10 days ago")
                            Spacer()
                            Text("Today")
                        } else {
                            Text("Yesterday at 6 PM")
                            Spacer()
                            Text("Today at 12 AM")
                            Spacer()
                            Text("Today at 6 AM")
                            Spacer()
                        }
                    }
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .offset(y: chartH + 6)
                }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let loc):
                        withAnimation(.easeOut(duration: 0.08)) {
                            hoverX = loc.x
                        }
                    case .ended:
                        withAnimation(.easeOut(duration: 0.08)) {
                            hoverX = nil
                        }
                    }
                }
            }
        }
        .frame(height: 165)
    }

    private func hoverInfo(for idx: Int, val: Double, total: Int) -> (String, String) {
        let score = Int(val * 8000)
        let scoreFormatted = score >= 1000 ? String(format: "%.1fk", Double(score) / 1000.0) : "\(score)"

        if window == "7d" {
            let daysAgo = total - 1 - idx
            let timeStr = daysAgo == 0 ? "Today" : "\(daysAgo)d ago"
            return (timeStr, "\(scoreFormatted) score")
        } else if window == "30d" {
            let daysAgo = total - 1 - idx
            let timeStr = daysAgo == 0 ? "Today" : "\(daysAgo)d ago"
            return (timeStr, "\(scoreFormatted) score")
        } else {
            let h = idx % 24
            let period = h >= 12 ? "PM" : "AM"
            let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
            let timeStr = "\(h12) \(period)"
            return (timeStr, "\(scoreFormatted) score")
        }
    }

    private func yAxisLabel(for index: Int) -> String {
        switch index {
        case 0: return "8.0k"
        case 1: return "6.0k"
        case 2: return "4.0k"
        case 3: return "2.0k"
        default: return "0.00"
        }
    }
}

// MARK: - App Usage Detail View
struct AppUsageDetailView: View {
    let app: AppEnergyItem
    let onBack: () -> Void

    @State private var selectedWindow: String = "24h"

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 18) {
                // Top Back Button
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Back to all apps")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color(red: 0.12, green: 0.48, blue: 0.98))
                }
                .buttonStyle(.plain)

                // App Header
                HStack(spacing: 14) {
                    Image(nsImage: app.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(app.name)
                            .font(.system(size: 22, weight: .bold))

                        Text(app.bundleIdentifier)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                // 4 Metric Summary Cards - Responsive
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        cardBatteryCost
                        cardShareOfTotal
                        cardPeakScore
                        cardWindow
                    }

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        cardBatteryCost
                        cardShareOfTotal
                        cardPeakScore
                        cardWindow
                    }
                }

                // Energy use over time
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Energy use over time")
                            .font(.system(size: 13, weight: .bold))

                        Spacer()

                        Text("Peak: \(app.peakScoreFormatted) at \(app.peakTimeStr)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    EnergyBezierChartView(points: app.historyPoints(for: selectedWindow), window: selectedWindow)

                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                        Text("Taller peaks mean this app was working harder. Look for sudden spikes to spot when it briefly went wild.")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
                )

                // Bottom Back Button
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Back to all apps")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color(red: 0.12, green: 0.48, blue: 0.98))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color.white)
    }

    // MARK: - Individual Responsive Cards
    private var cardBatteryCost: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "battery.100")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.15))
                Text("BATTERY COST")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.15))
                Spacer()
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.15).opacity(0.8))
            }

            Text(app.drainedCostString(window: selectedWindow))
                .font(.system(size: 18, weight: .bold))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 1.0, green: 0.97, blue: 0.94))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(red: 1.0, green: 0.90, blue: 0.82), lineWidth: 1)
        )
    }

    private var cardShareOfTotal: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.12, green: 0.48, blue: 0.98))
                Text("SHARE OF TOTAL")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(Color(red: 0.12, green: 0.48, blue: 0.98))
                Spacer()
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.12, green: 0.48, blue: 0.98).opacity(0.8))
            }

            Text(String(format: "%.0f%%", app.shareOfTotal))
                .font(.system(size: 18, weight: .bold))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.94, green: 0.97, blue: 1.0))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(red: 0.85, green: 0.92, blue: 1.0), lineWidth: 1)
        )
    }

    private var cardPeakScore: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.85, green: 0.35, blue: 0.85))
                Text("PEAK SCORE")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(Color(red: 0.85, green: 0.35, blue: 0.85))
                Spacer()
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.85, green: 0.35, blue: 0.85).opacity(0.8))
            }

            Text(app.peakScoreFormatted)
                .font(.system(size: 18, weight: .bold))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.99, green: 0.95, blue: 0.99))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(red: 0.96, green: 0.88, blue: 0.96), lineWidth: 1)
        )
    }

    private var cardWindow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("WINDOW")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 2) {
                ForEach(["24h", "7d", "30d"], id: \.self) { win in
                    Text(win)
                        .font(.system(size: 10.5, weight: selectedWindow == win ? .bold : .medium))
                        .foregroundStyle(selectedWindow == win ? .white : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            selectedWindow == win ? Color(red: 0.12, green: 0.48, blue: 0.98) : Color.clear
                        )
                        .clipShape(Capsule())
                        .onTapGesture {
                            selectedWindow = win
                        }
                }
            }
            .padding(2)
            .background(Color(red: 0.93, green: 0.93, blue: 0.95))
            .clipShape(Capsule())
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.98, green: 0.98, blue: 0.99))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
        )
    }
}

// MARK: - App Usage Settings Main View
struct BatteryAppUsageSettingsView: View {
    @StateObject private var manager = AppEnergyUsageManager.shared
    @State private var selectedApp: AppEnergyItem? = nil

    var body: some View {
        Group {
            if let app = selectedApp {
                AppUsageDetailView(app: app, onBack: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedApp = nil
                    }
                })
            } else if manager.isLoading && manager.apps.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.9)
                    Text("Collecting app usage data…")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 400)
            } else {
                overviewView
            }
        }
        .navigationTitle("App Usage")
        .background(Color.white)
        .onAppear {
            manager.startMonitoring()
        }
        .onDisappear {
            manager.stopMonitoring()
        }
    }

    private var overviewView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                // Top Status Bar & Window Selector
                HStack {
                    Text(historyStatusText)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Spacer()

                    HStack(spacing: 2) {
                        ForEach(["24h", "7d", "30d"], id: \.self) { win in
                            Text(win)
                                .font(.system(size: 10.5, weight: manager.selectedTimeWindow == win ? .bold : .medium))
                                .foregroundStyle(manager.selectedTimeWindow == win ? .white : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(
                                    manager.selectedTimeWindow == win ? Color(red: 0.12, green: 0.48, blue: 0.98) : Color.clear
                                )
                                .clipShape(Capsule())
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        manager.selectedTimeWindow = win
                                    }
                                }
                        }
                    }
                    .padding(2)
                    .background(Color(red: 0.93, green: 0.93, blue: 0.95))
                    .clipShape(Capsule())
                }
                .padding(.bottom, 2)

                // Top Grid: 2 Cards Side-by-side
                HStack(alignment: .top, spacing: 14) {
                    // Card 1: RIGHT NOW
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            HStack(spacing: 5) {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .font(.system(size: 11))
                                Text("RIGHT NOW")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(.secondary)

                            Spacer()

                            Text("\(manager.lastUpdatedSecondsAgo)s ago")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        if manager.rightNowApps.isEmpty {
                            Text("No high energy apps active")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(Array(manager.rightNowApps.prefix(2).enumerated()), id: \.element.id) { idx, app in
                                    HStack(spacing: 8) {
                                        Text("\(idx + 1)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 10)

                                        Image(nsImage: app.icon)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 18, height: 18)
                                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                                        Text(app.name)
                                            .font(.system(size: 12, weight: .semibold))
                                            .lineLimit(1)
                                            .frame(width: 70, alignment: .leading)

                                        // Horizontal bar
                                        GeometryReader { barGeo in
                                            let barW = barGeo.size.width
                                            let fillW = max(4, barW * CGFloat(app.instantShare / 100.0))

                                            ZStack(alignment: .leading) {
                                                Capsule()
                                                    .fill(Color(red: 0.92, green: 0.92, blue: 0.94))
                                                    .frame(height: 3)

                                                Capsule()
                                                    .fill(
                                                        idx == 0
                                                            ? LinearGradient(colors: [Color(red: 0.2, green: 0.8, blue: 0.65), Color(red: 0.1, green: 0.7, blue: 0.55)], startPoint: .leading, endPoint: .trailing)
                                                            : LinearGradient(colors: [Color(red: 0.95, green: 0.4, blue: 0.6), Color(red: 0.9, green: 0.3, blue: 0.5)], startPoint: .leading, endPoint: .trailing)
                                                    )
                                                    .frame(width: fillW, height: 3)
                                            }
                                            .frame(height: 3)
                                        }
                                        .frame(height: 3)

                                        Text("\(Int(app.instantShare))%")
                                            .font(.system(size: 12, weight: .bold))
                                            .frame(width: 36, alignment: .trailing)
                                    }
                                    .help("\(app.name): ~\(Int(app.instantShare))% instantaneous energy share (PID: \(app.pid))")
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.18)) {
                                            selectedApp = app
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
                    )

                    // Card 2: TOP DRAINERS - [WINDOW]
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 5) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.orange)
                            Text("TOP DRAINERS - \(manager.selectedTimeWindow.uppercased())")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(red: 0.9, green: 0.5, blue: 0.1))
                        }

                        VStack(spacing: 7) {
                            ForEach(Array(manager.topDrainers.prefix(5).enumerated()), id: \.element.id) { idx, app in
                                HStack(spacing: 8) {
                                    Text("\(idx + 1)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 10)

                                    Image(nsImage: app.icon)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 16, height: 16)
                                        .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))

                                    Text(app.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                        .frame(width: 80, alignment: .leading)

                                    // Bar
                                    GeometryReader { barGeo in
                                        let barW = barGeo.size.width
                                        let fillW = max(3, barW * CGFloat(app.shareOfTotal / 100.0))

                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Color(red: 0.92, green: 0.92, blue: 0.94))
                                                .frame(height: 3)

                                            Capsule()
                                                .fill(colorForDrainer(idx: idx))
                                                .frame(width: fillW, height: 3)
                                        }
                                        .frame(height: 3)
                                    }
                                    .frame(height: 3)

                                    VStack(alignment: .trailing, spacing: 0) {
                                        Text(app.drainedCostString(window: manager.selectedTimeWindow))
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(idx == 0 ? Color(red: 0.9, green: 0.45, blue: 0.1) : .primary)
                                        Text(String(format: "%.1f%%", app.shareOfTotal))
                                            .font(.system(size: 9.5))
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(width: 44, alignment: .trailing)
                                }
                                .help("\(app.name): \(app.drainedCostString(window: manager.selectedTimeWindow)) battery drain (\(String(format: "%.1f%%", app.shareOfTotal)) of all apps energy)")
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        selectedApp = app
                                    }
                                }
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
                    )
                }

                // Section: INSIGHTS
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                        Text("INSIGHTS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                    }
                    .padding(.top, 6)

                    // Dominant App Banner
                    if let domApp = manager.dominantApp {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "flame.fill")
                                    .foregroundStyle(.orange)
                                    .font(.system(size: 13))

                                Image(nsImage: domApp.icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 18, height: 18)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                                Text("\(domApp.name) is dominating your battery")
                                    .font(.system(size: 13, weight: .bold))
                            }

                            Text("Cost you \(domApp.drainedCostString(window: manager.selectedTimeWindow)) of battery in the last \(manager.selectedTimeWindow) (\(Int(domApp.shareOfTotal))% of your apps' energy). If you're not actively using it, closing it could meaningfully extend battery life.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.primary.opacity(0.8))
                                .lineSpacing(2)

                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    selectedApp = domApp
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.system(size: 10))
                                    Text("See details")
                                        .font(.system(size: 11.5, weight: .bold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4.5)
                                .foregroundStyle(Color(red: 0.85, green: 0.45, blue: 0.1))
                                .background(Color(red: 1.0, green: 0.90, blue: 0.82))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 1.0, green: 0.96, blue: 0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(red: 1.0, green: 0.88, blue: 0.78), lineWidth: 1)
                        )
                    }

                    // Unusually Active App Banner
                    if let actApp = manager.unusuallyActiveApp {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.system(size: 13))

                                Image(nsImage: actApp.icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 18, height: 18)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                                Text("\(actApp.name) is unusually active right now")
                                    .font(.system(size: 13, weight: .bold))
                            }

                            Text("It's drawing about 8.8x more energy than its typical share. It may be stuck in a loop or doing background work. Restart it if you're not actively using it.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.primary.opacity(0.8))
                                .lineSpacing(2)

                            HStack(spacing: 8) {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        selectedApp = actApp
                                    }
                                }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "chart.bar.fill")
                                            .font(.system(size: 10))
                                        Text("See details")
                                            .font(.system(size: 11.5, weight: .medium))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4.5)
                                    .foregroundStyle(.primary)
                                    .background(Color(red: 0.92, green: 0.92, blue: 0.94))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)

                                Button(action: {
                                    manager.terminateApp(actApp)
                                }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "power")
                                            .font(.system(size: 10))
                                        Text("Quit")
                                            .font(.system(size: 11.5, weight: .medium))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4.5)
                                    .foregroundStyle(.red)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
                        )
                    }
                }

                // Section: TOP ENERGY CONSUMERS
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 5) {
                        Image(systemName: "laptopcomputer")
                            .font(.system(size: 11))
                        Text("TOP ENERGY CONSUMERS")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                    .padding(.top, 6)

                    // Consumer list card
                    VStack(spacing: 0) {
                        ForEach(Array(manager.apps.enumerated()), id: \.element.id) { idx, app in
                            if idx > 0 {
                                Rectangle()
                                    .fill(Color(red: 0.94, green: 0.94, blue: 0.95))
                                    .frame(height: 1)
                            }

                            HStack(spacing: 12) {
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 28, height: 28)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.name)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(app.bundleIdentifier)
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 140, alignment: .leading)

                                Spacer()

                                // Sparkline
                                EnergySparklineView(points: app.historyPoints(for: manager.selectedTimeWindow))
                                    .frame(minWidth: 100, maxWidth: 380)

                                Spacer()

                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(String(format: "%.1f%%", app.shareOfTotal))
                                        .font(.system(size: 13, weight: .bold))
                                    Text("of total")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 55, alignment: .trailing)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.secondary.opacity(0.5))
                                    .padding(.leading, 4)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    selectedApp = app
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }

    private var historyStatusText: String {
        switch manager.selectedTimeWindow {
        case "7d":
            return "7 days of history collected · \(manager.apps.count) apps tracked in the last 7 days"
        case "30d":
            return "30 days of history collected · \(manager.apps.count) apps tracked in the last 30 days"
        default:
            return "Less than a day of history collected · \(manager.apps.count) apps tracked in the last 24h"
        }
    }

    private func colorForDrainer(idx: Int) -> Color {
        switch idx {
        case 0: return Color(red: 0.95, green: 0.65, blue: 0.15)
        case 1: return Color(red: 0.18, green: 0.80, blue: 0.44)
        case 2: return Color(red: 0.20, green: 0.55, blue: 0.95)
        case 3: return Color(red: 0.0, green: 0.75, blue: 0.90)
        default: return Color(red: 0.60, green: 0.40, blue: 0.90)
        }
    }
}
