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
    @State private var step: Int = 0
    @State private var timer: Timer? = nil
    
    // Perimeter path for 3x3 grid (8 outer cells clockwise)
    private let perimeterPath: [(row: Int, col: Int)] = [
        (0, 0), (0, 1), (0, 2),
        (1, 2),
        (2, 2), (2, 1), (2, 0),
        (1, 0)
    ]
    
    public init(accentColor: Color = Color(red: 1.0, green: 0.50, blue: 0.40)) {
        self.accentColor = accentColor
    }
    
    public var body: some View {
        ZStack {
            // Ambient Radial Glow Behind Pixel Grid
            Circle()
                .fill(accentColor)
                .frame(width: 9, height: 9)
                .blur(radius: 2.5)
                .opacity(0.7)
            
            // 3x3 Pixel Grid (Compact, refined)
            VStack(spacing: 0.8) {
                ForEach(0..<3, id: \.self) { r in
                    HStack(spacing: 0.8) {
                        ForEach(0..<3, id: \.self) { c in
                            pixelCell(row: r, col: c)
                        }
                    }
                }
            }
            .frame(width: 8.5, height: 8.5)
        }
        .frame(width: 10, height: 10)
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
        
        RoundedRectangle(cornerRadius: 0.4, style: .continuous)
            .fill(accentColor.opacity(opacity))
            .frame(width: 2.0, height: 2.0)
            .shadow(color: accentColor.opacity(opacity > 0.6 ? 0.8 : 0), radius: 0.6, x: 0, y: 0)
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

// MARK: - Animated 3-Dots Component for Waiting States

public struct AnimatedCyclingDots: View {
    @State private var dotCount: Int = 1
    @State private var timer: Timer? = nil
    
    public init() {}
    
    public var body: some View {
        Text(String(repeating: ".", count: dotCount))
            .font(.system(size: 9.5, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(width: 12, alignment: .leading)
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

// MARK: - Progressive 3-Segment Subtitle View (50% action, 65% target, 80% detail)

public struct FormattedSubtitleView: View {
    public let text: String
    
    public init(_ text: String) {
        self.text = text
    }
    
    public var body: some View {
        let segments = parseSegments(text)
        HStack(spacing: 3.5) {
            if segments.count == 3 {
                Text(segments[0])
                    .foregroundColor(Color.white.opacity(0.50))
                Text(segments[1])
                    .foregroundColor(Color.white.opacity(0.65))
                Text(segments[2])
                    .foregroundColor(Color.white.opacity(0.80))
            } else if segments.count == 2 {
                Text(segments[0])
                    .foregroundColor(Color.white.opacity(0.50))
                Text(segments[1])
                    .foregroundColor(Color.white.opacity(0.80))
            } else {
                Text(text)
                    .foregroundColor(Color.white.opacity(0.60))
            }
        }
        .font(.system(size: 8.0, weight: .regular, design: .rounded))
        .lineLimit(1)
        .truncationMode(.middle)
    }
    
    private func parseSegments(_ input: String) -> [String] {
        let parts = input.components(separatedBy: " ").filter { !$0.isEmpty }
        guard parts.count >= 3 else {
            if parts.count == 2 { return [parts[0], parts[1]] }
            return [input]
        }
        
        let first = parts[0]
        let middle = parts[1]
        let last = parts[2...].joined(separator: " ")
        return [first, middle, last]
    }
}

// MARK: - Centered 2-Line Dynamic Notch View (Zero Height Expansion, Scaled Safe Insets)

public struct AntigravityInlineHUD: View {
    @ObservedObject var manager = AntigravityManager.shared
    
    public init() {}
    
    public var body: some View {
        Group {
            switch manager.currentPhase {
            case .idle:
                EmptyView()
                
            case .taskCompleted(let summary):
                // Done / Completion State: Centered checkmark circle + "Done"
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(Color(red: 0.20, green: 0.92, blue: 0.42))
                        .shadow(color: Color(red: 0.20, green: 0.92, blue: 0.42).opacity(0.5), radius: 2.5)
                    
                    VStack(alignment: .center, spacing: 0.5) {
                        Text("Done")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        if !summary.isEmpty && summary != "Done" && summary != "Task completed successfully" {
                            Text(summary)
                                .font(.system(size: 8.0, weight: .regular, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.80))
                                .lineLimit(1)
                        }
                    }
                }
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                
            case .working:
                // Immediate working state when prompt is sent
                VStack(alignment: .center, spacing: 0.8) {
                    FormattedSubtitleView(manager.currentPhase.subtitle)
                    
                    HStack(spacing: 3.5) {
                        PixelSnakeLoader(accentColor: manager.currentPhase.accentColor)
                        
                        Text("Working")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        
                        AnimatedCyclingDots()
                    }
                }
                .transition(.opacity)
                
            case .waitingInput, .askingPermission:
                // Waiting for user response / permission state with animated 3 dots
                VStack(alignment: .center, spacing: 0.8) {
                    FormattedSubtitleView(manager.currentPhase.subtitle)
                    
                    HStack(spacing: 3.5) {
                        PixelSnakeLoader(accentColor: manager.currentPhase.accentColor)
                        
                        Text("Waiting your response")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        
                        AnimatedCyclingDots()
                    }
                }
                .transition(.opacity)
                
            default:
                // Standard 2-Line Active Progress State (Centered items, compact sizes)
                VStack(alignment: .center, spacing: 0.8) {
                    // Row 1: Progressive 3-segment formatted subtitle (e.g. "Read", "Sidebar.jsx", "44 lines")
                    FormattedSubtitleView(manager.currentPhase.subtitle)
                    
                    // Row 2: Pixel Snake Loading Animation + State Name (White, semibold)
                    HStack(spacing: 4.0) {
                        PixelSnakeLoader(accentColor: manager.currentPhase.accentColor)
                        
                        Text(manager.currentPhase.title)
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 1)
        .fixedSize(horizontal: true, vertical: false)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: manager.currentPhase)
    }
}

// MARK: - Open Notch Floating View

public struct AntigravityOpenNotchView: View {
    @ObservedObject var manager = AntigravityManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 6) {
            // Row 1: Muted subtitle
            Text(manager.currentPhase.subtitle)
                .font(.system(size: 11.5, weight: .regular, design: .rounded))
                .foregroundColor(Color.white.opacity(0.60))
                .lineLimit(1)
                .truncationMode(.middle)
            
            // Row 2: Pixel snake + Main Title
            HStack(spacing: 8) {
                if case .taskCompleted = manager.currentPhase {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 0.20, green: 0.92, blue: 0.42))
                } else {
                    PixelSnakeLoader(accentColor: manager.currentPhase.accentColor)
                        .scaleEffect(1.2)
                }
                
                Text(manager.currentPhase.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: manager.currentPhase)
    }
}

// MARK: - Demo Showcase Controls

public struct AntigravityDemoView: View {
    @ObservedObject var manager = AntigravityManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 16) {
            Text("Antigravity 2-Line Dynamic Notch Demo")
                .font(.headline)
                .foregroundColor(.white)
            
            // Simulated Notch Preview (Strict fixed height ~32px)
            ZStack {
                Capsule()
                    .fill(Color.black)
                    .frame(height: 32)
                
                AntigravityInlineHUD()
            }
            .padding(.horizontal, 30)
            
            // Trigger Buttons
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 8) {
                btn(title: "Reading", phase: .reading(file: "_app.tsx", lines: 55))
                btn(title: "Editing", phase: .editing(file: "NotchHomeView.swift", changes: "+18 -4"))
                btn(title: "Analyzing", phase: .analyzing(query: "Searching struct NotchHomeView"))
                btn(title: "Command", phase: .runningCommand(command: "swift build"))
                btn(title: "Planning", phase: .planning(step: "Phase 2: UI implementation"))
                btn(title: "Thinking", phase: .thinking(thought: "Optimizing layout parameters"))
                btn(title: "Wait Response", phase: .waitingInput(question: "Select option 1 or 2"))
                btn(title: "Done (5s)", phase: .taskCompleted(summary: "All changes committed"))
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

// MARK: - Preview

#Preview("2-Line Antigravity Notch") {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        
        VStack(spacing: 30) {
            // Simulated macOS Notch bar
            HStack {
                Spacer()
                ZStack {
                    Capsule()
                        .fill(Color.black)
                        .frame(width: 220, height: 32)
                    
                    AntigravityInlineHUD()
                }
                Spacer()
            }
            .frame(height: 32)
            .background(Color.black.opacity(0.8))
            
            AntigravityDemoView()
        }
    }
    .frame(width: 500, height: 440)
    .onAppear {
        AntigravityManager.shared.setPhase(.reading(file: "_app.tsx", lines: 55))
    }
}
