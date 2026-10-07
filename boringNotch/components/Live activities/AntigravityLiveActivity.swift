//
//  AntigravityLiveActivity.swift
//  boringNotch
//
//  Created for Antigravity Real-time Process Indicator.
//

import SwiftUI

// MARK: - Custom 3x3 Pixel Snake Loader (Matches Reference & 14 Dynamic Colors)

public struct PixelSnakeLoader: View {
    public let accentColor: Color
    public let size: CGFloat
    @State private var step: Int = 0
    @State private var timer: Timer? = nil
    
    // Perimeter path for 3x3 grid (8 outer cells clockwise)
    private let perimeterPath: [(row: Int, col: Int)] = [
        (0, 0), (0, 1), (0, 2),
        (1, 2),
        (2, 2), (2, 1), (2, 0),
        (1, 0)
    ]
    
    public init(accentColor: Color = Color(red: 1.0, green: 0.50, blue: 0.40), size: CGFloat = 13.5) {
        self.accentColor = accentColor
        self.size = size
    }
    
    private var cellSize: CGFloat { size * 0.25 }
    private var cellSpacing: CGFloat { size * 0.08 }
    
    public var body: some View {
        ZStack {
            // Ambient Radial Glow Behind Pixel Grid
            Circle()
                .fill(accentColor)
                .frame(width: size * 0.9, height: size * 0.9)
                .blur(radius: size * 0.22)
                .opacity(0.7)
            
            // 3x3 Pixel Grid
            VStack(spacing: cellSpacing) {
                ForEach(0..<3, id: \.self) { r in
                    HStack(spacing: cellSpacing) {
                        ForEach(0..<3, id: \.self) { c in
                            pixelCell(row: r, col: c)
                        }
                    }
                }
            }
            .frame(width: size * 0.9, height: size * 0.9)
        }
        .frame(width: size, height: size)
        .onAppear {
            startSnakeAnimation()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    @ViewBuilder
    private func pixelCell(row: Int, col: Int) -> some View {
        let opacity = calculatePixelOpacity(row: row, col: col)
        
        RoundedRectangle(cornerRadius: 0.6, style: .continuous)
            .fill(accentColor.opacity(opacity))
            .frame(width: cellSize, height: cellSize)
            .shadow(color: accentColor.opacity(opacity > 0.6 ? 0.8 : 0), radius: 0.8, x: 0, y: 0)
    }
    
    private func calculatePixelOpacity(row: Int, col: Int) -> Double {
        if row == 1 && col == 1 {
            return 0.04 // Center is empty
        }
        
        guard let index = perimeterPath.firstIndex(where: { $0.row == row && $0.col == col }) else {
            return 0.04
        }
        
        let head = step % 8
        let d0 = head // Head (100% Brightness)
        let d1 = (head - 1 + 8) % 8 // Trail 1
        let d2 = (head - 2 + 8) % 8 // Trail 2
        let d3 = (head - 3 + 8) % 8 // Tail
        
        if index == d0 {
            return 1.0
        } else if index == d1 {
            return 0.75
        } else if index == d2 {
            return 0.45
        } else if index == d3 {
            return 0.20
        } else {
            return 0.05
        }
    }
    
    private func startSnakeAnimation() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.10, repeats: true) { _ in
            step = (step + 1) % 8
        }
    }
}

// MARK: - Sunburst Radiating Checkmark for Completed State (Matching loader size with sun rays)

public struct SunburstCheckmark: View {
    public let size: CGFloat
    @State private var rayScale: CGFloat = 0.5
    @State private var rayOpacity: Double = 0.3
    @State private var rotation: Double = 0.0
    
    public init(size: CGFloat = 13.5) {
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            // Radiating Sunburst Rays (Short radiating lines expanding outward)
            ForEach(0..<8, id: \.self) { i in
                Capsule()
                    .fill(Color(red: 0.20, green: 0.95, blue: 0.45))
                    .frame(width: max(1.2, size * 0.10), height: size * 0.36)
                    .offset(y: -size * 0.76)
                    .rotationEffect(.degrees(Double(i) * 45.0 + rotation))
                    .opacity(rayOpacity)
                    .scaleEffect(rayScale)
            }
            
            // Central Soft Glow
            Circle()
                .fill(Color(red: 0.20, green: 0.95, blue: 0.45))
                .frame(width: size * 1.1, height: size * 1.1)
                .blur(radius: size * 0.25)
                .opacity(0.6)
            
            // Circled Checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: size, weight: .bold))
                .foregroundColor(Color(red: 0.20, green: 0.95, blue: 0.45))
                .shadow(color: Color(red: 0.20, green: 0.95, blue: 0.45).opacity(0.7), radius: 2.0)
        }
        .frame(width: size * 1.8, height: size * 1.8)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                rayScale = 1.15
                rayOpacity = 0.95
                rotation = 22.5
            }
        }
    }
}

// MARK: - Binary Matrix Rain Animation (Vertical drifting 0 and 1 streams with alternating speeds)

public struct BinaryMatrixRainView: View {
    @State private var phase: CGFloat = 0
    @State private var timer: Timer? = nil
    
    private let columns: [[String]] = [
        ["0", "1", "0", "0", "1", "1", "0", "1"],
        ["1", "0", "1", "1", "0", "0", "1", "0"],
        ["0", "0", "1", "0", "1", "1", "0", "1"],
        ["1", "1", "0", "1", "0", "0", "1", "1"],
        ["0", "1", "1", "0", "1", "0", "0", "0"],
        ["1", "0", "0", "1", "0", "1", "1", "0"],
        ["0", "1", "0", "1", "1", "0", "1", "0"],
        ["1", "1", "0", "0", "1", "0", "0", "1"],
        ["0", "0", "1", "1", "0", "1", "0", "1"],
        ["1", "0", "1", "0", "0", "1", "1", "0"],
        ["0", "1", "1", "0", "1", "0", "0", "1"],
        ["1", "0", "0", "1", "1", "0", "1", "0"]
    ]
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(0..<columns.count, id: \.self) { colIndex in
                    let col = columns[colIndex]
                    // Alternating speeds: Even columns move faster, odd columns move slower
                    let isFast = (colIndex % 2 == 0)
                    let speedFactor: CGFloat = isFast ? 1.75 : 0.85
                    let initialOffset: CGFloat = CGFloat((colIndex * 17) % 50)
                    
                    VStack(spacing: 4) {
                        ForEach(0..<col.count * 3, id: \.self) { itemIndex in
                            let char = col[itemIndex % col.count]
                            Text(char)
                                .font(.system(size: 9.2, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.30))
                        }
                    }
                    // Moving upward continuously
                    .offset(y: -((phase * speedFactor + initialOffset).truncatingRemainder(dividingBy: 60)))
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .clipped()
            .mask(
                // Vignette mask: binary matrix is 30% visible on sides, masked out in the middle behind text for readability
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.95), location: 0.0),
                        .init(color: .white.opacity(0.40), location: 0.16),
                        .init(color: .clear, location: 0.35),
                        .init(color: .clear, location: 0.65),
                        .init(color: .white.opacity(0.40), location: 0.84),
                        .init(color: .white.opacity(0.95), location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .onAppear {
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { _ in
                phase += 1.0
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

// MARK: - Animated 3-Dots Component for Waiting States

public struct AnimatedCyclingDots: View {
    public let fontSize: CGFloat
    @State private var dotCount: Int = 1
    @State private var timer: Timer? = nil
    
    public init(fontSize: CGFloat = 13.5) {
        self.fontSize = fontSize
    }
    
    public var body: some View {
        Text(String(repeating: ".", count: dotCount))
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(width: fontSize * 1.2, alignment: .leading)
            .onAppear {
                timer?.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { _ in
                    dotCount = (dotCount % 3) + 1
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
    }
}

// MARK: - Antigravity Dynamic Live Activity View (Matrix Rain Background + Inline [Loading] [State] [File])

public struct AntigravityLiveActivity: View {
    @ObservedObject var manager = AntigravityManager.shared
    @EnvironmentObject var vm: BoringViewModel
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // MARK: - Background Matrix Binary Streams (0 & 1 with masked center)
            BinaryMatrixRainView()
                .opacity(manager.currentPhase != .idle ? 1.0 : 0.0)
                .allowsHitTesting(false)
            
            // MARK: - Foreground Content
            VStack(spacing: 0) {
                // Safe spacer for MacBook physical camera notch
                Rectangle()
                    .fill(Color.clear)
                    .frame(
                        width: max(0, vm.closedNotchSize.width - 20),
                        height: vm.effectiveClosedNotchHeight
                    )
                
                // Unified Status Row: [Loader / SunburstCheckmark] [Action Title] [Target File / Detail]
                HStack(alignment: .center, spacing: 6.5) {
                    switch manager.currentPhase {
                    case .idle:
                        EmptyView()
                        
                    case .working(let task):
                        PixelSnakeLoader(accentColor: manager.currentPhase.accentColor, size: 13.5)
                        
                        Text("Working")
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .fixedSize()
                        
                        if !task.isEmpty {
                            Text(task)
                                .font(.system(size: 12.0, weight: .regular, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.50))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            AnimatedCyclingDots(fontSize: 13.5)
                        }
                        
                    case .waitingInput(let question):
                        PixelSnakeLoader(accentColor: manager.currentPhase.accentColor, size: 13.5)
                        
                        Text("Waiting response")
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .fixedSize()
                        
                        if !question.isEmpty {
                            Text(question)
                                .font(.system(size: 12.0, weight: .regular, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.50))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            AnimatedCyclingDots(fontSize: 13.5)
                        }
                        
                    case .askingPermission(let action):
                        PixelSnakeLoader(accentColor: manager.currentPhase.accentColor, size: 13.5)
                        
                        Text("Permission")
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .fixedSize()
                        
                        if !action.isEmpty {
                            Text(action)
                                .font(.system(size: 12.0, weight: .regular, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.50))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            AnimatedCyclingDots(fontSize: 13.5)
                        }
                        
                    case .taskCompleted(let summary):
                        SunburstCheckmark(size: 13.5)
                        
                        Text(summary.isEmpty || summary == "Done" || summary == "Task completed successfully" ? "Task Completed Successfully" : summary)
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .fixedSize()
                        
                    default:
                        PixelSnakeLoader(accentColor: manager.currentPhase.accentColor, size: 13.5)
                        
                        Text(manager.currentPhase.actionTitle)
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .fixedSize()
                        
                        if let detail = manager.currentPhase.targetDetail {
                            Text(detail)
                                .font(.system(size: 12.0, weight: .regular, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.50))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 16)
                .padding(.bottom, 9)
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: manager.currentPhase)
    }
}

// MARK: - Centered Inline HUD fallback

public struct AntigravityInlineHUD: View {
    @ObservedObject var manager = AntigravityManager.shared
    
    public init() {}
    
    public var body: some View {
        AntigravityLiveActivity()
    }
}

// MARK: - Demo Showcase Controls

public struct AntigravityDemoView: View {
    @ObservedObject var manager = AntigravityManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 16) {
            Text("Antigravity Dynamic Notch Demo")
                .font(.headline)
                .foregroundColor(.white)
            
            // Trigger Buttons
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 8) {
                btn(title: "Reading", phase: .reading(file: "_app.tsx", lines: 55))
                btn(title: "Editing", phase: .editing(file: "NotchHomeView.swift", changes: "+18 -4"))
                btn(title: "Analyzing", phase: .analyzing(query: "Searching struct NotchHomeView"))
                btn(title: "Command", phase: .runningCommand(command: "swift build"))
                btn(title: "Planning", phase: .planning(step: "Phase 2: UI implementation"))
                btn(title: "Thinking", phase: .thinking(thought: "Optimizing layout parameters"))
                btn(title: "Wait Response", phase: .waitingInput(question: "Select option 1 or 2"))
                btn(title: "Done (5s)", phase: .taskCompleted(summary: "Task Completed Successfully"))
            }
            .padding(.horizontal)
            
            HStack(spacing: 14) {
                Button("▶ Run Automated Demo") {
                    manager.startDemoSequence()
                }
                .buttonStyle(.borderedProminent)
                
                Button("⏹ Reset / Idle") {
                    manager.stopDemo()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(Color(white: 0.1))
        .cornerRadius(14)
    }
    
    private func btn(title: String, phase: AntigravityPhase) -> some View {
        Button(action: {
            manager.setPhase(phase)
        }) {
            Text(title)
                .font(.system(size: 10.5, weight: .medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
    }
}
