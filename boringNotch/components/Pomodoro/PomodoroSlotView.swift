//
//  PomodoroSlotView.swift
//  Dino
//
//  Created for Dino Architecture Evolution.
//

import Defaults
import SwiftUI

public struct PomodoroClosedPillView: View {
    @ObservedObject private var pomodoro = PomodoroManager.shared
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 8) {
            // Leading: Icon
            Image(systemName: pomodoro.phase == .focus ? "timer" : "cup.and.saucer.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(pomodoro.phase == .focus ? .red : .teal)
            
            Spacer(minLength: 0)
            
            // Trailing: Formatted time e.g. 24:50
            Text(formattedTime(pomodoro.remainingTime))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
    }
    
    private func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

public struct PomodoroExpandedCardView: View {
    @ObservedObject private var pomodoro = PomodoroManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Label(pomodoro.phase.title, systemImage: pomodoro.phase == .focus ? "flame.fill" : "cup.and.saucer.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(pomodoro.phase == .focus ? .orange : .teal)
                
                Spacer()
                
                Text("Session \(pomodoro.completedFocusSessions + 1)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            // Time Display
            Text(formattedTime(pomodoro.remainingTime))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            
            // Control Buttons
            HStack(spacing: 12) {
                Button(action: {
                    if pomodoro.state == .running {
                        pomodoro.pause()
                    } else {
                        pomodoro.start()
                    }
                }) {
                    Text(pomodoro.state == .running ? "Pause" : "Start")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button(action: { pomodoro.skip() }) {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(6)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                Button(action: { pomodoro.reset() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(6)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 280, height: 130)
    }
    
    private func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
