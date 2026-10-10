//
//  DinoSlotContainerView.swift
//  Dino
//
//  Created for Dino Architecture Evolution.
//

import SwiftUI

public struct DinoSlotContainerView: View {
    @ObservedObject private var coordinator = DinoCoordinator.shared
    
    public init() {}
    
    public var body: some View {
        Group {
            if coordinator.isExpanded {
                expandedContentView
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
            } else {
                closedPillContentView
                    .transition(.opacity)
            }
        }
        .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.78), value: coordinator.isExpanded)
        .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.78), value: coordinator.activeSlot)
    }
    
    // MARK: - Closed Pill Content View
    @ViewBuilder
    private var closedPillContentView: some View {
        if coordinator.activeSlot == .music && coordinator.secondarySlot == .pomodoro {
            // Dual Active: Left Music, Right Pomodoro
            HStack(spacing: 8) {
                // Leading: Music Visualizer
                MusicVisualizerBarsView()
                    .frame(width: 16, height: 12)
                
                Spacer(minLength: 0)
                
                // Trailing: Pomodoro Timer
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.red)
                    Text(PomodoroManager.shared.formattedRemainingTime)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 8)
        } else {
            switch coordinator.activeSlot {
            case .music:
                MusicClosedPillView()
            case .pomodoro:
                PomodoroClosedPillView()
            case .weather:
                WeatherClosedPillView()
            case .battery:
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    Text("85%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
            case .hud(let type):
                hudClosedView(type: type)
            case .idle, .calendar, .shelf, .download, .webcam, .coding:
                EmptyView()
            }
        }
    }
    
    // MARK: - Expanded Card Content View
    @ViewBuilder
    private var expandedContentView: some View {
        switch coordinator.activeSlot {
        case .music:
            MusicExpandedCardView()
        case .pomodoro:
            PomodoroExpandedCardView()
        case .weather:
            WeatherExpandedCardView()
        default:
            MusicExpandedCardView()
        }
    }
    
    @ViewBuilder
    private func hudClosedView(type: DinoSlot.HUDType) -> some View {
        switch type {
        case .volume(let val):
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 12))
                ProgressView(value: val)
                    .progressViewStyle(.linear)
                    .tint(.white)
            }
            .padding(.horizontal, 10)
        case .brightness(let val):
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 12))
                ProgressView(value: val)
                    .progressViewStyle(.linear)
                    .tint(.white)
            }
            .padding(.horizontal, 10)
        case .backlight(let val):
            HStack(spacing: 8) {
                Image(systemName: "keyboard.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 12))
                ProgressView(value: val)
                    .progressViewStyle(.linear)
                    .tint(.white)
            }
            .padding(.horizontal, 10)
        case .micMute(let isMuted):
            HStack(spacing: 6) {
                Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                    .foregroundColor(isMuted ? .red : .green)
                Text(isMuted ? "Muted" : "Unmuted")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
        }
    }
}
