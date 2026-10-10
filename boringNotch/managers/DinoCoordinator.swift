//
//  DinoCoordinator.swift
//  Dino
//
//  Created for Dino Architecture Evolution.
//

import Combine
import Foundation
import SwiftUI

// MARK: - Dino Slot Types
public enum DinoSlot: Equatable, Hashable, Sendable {
    case idle
    case music
    case pomodoro
    case weather
    case calendar
    case shelf
    case battery
    case download
    case webcam
    case hud(HUDType)
    
    public enum HUDType: Equatable, Hashable, Sendable {
        case volume(value: Double)
        case brightness(value: Double)
        case backlight(value: Double)
        case micMute(isMuted: Bool)
    }
}

// MARK: - Slot Priority
public enum SlotPriority: Int, Comparable, Sendable {
    case p4Idle = 0
    case p3Background = 1
    case p2OnDemand = 2
    case p1Toast = 3
    
    public static func < (lhs: SlotPriority, rhs: SlotPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Expanded Size Presets
public enum ExpandedSizePreset: Sendable {
    case compact   // 280 x 90 pt (Battery, Quick Controls, Mini Timer)
    case standard  // 360 x 145 pt (Music Player, 5-day Weather)
    case large     // 440 x 210 pt (Calendar Hub, Shelf / Files)
    
    public var size: CGSize {
        switch self {
        case .compact:
            return CGSize(width: 280, height: 90)
        case .standard:
            return CGSize(width: 360, height: 145)
        case .large:
            return CGSize(width: 440, height: 210)
        }
    }
}

// MARK: - Dino Coordinator
@MainActor
public final class DinoCoordinator: ObservableObject {
    public static let shared = DinoCoordinator()
    
    // MARK: - Published State
    @Published public private(set) var activeSlot: DinoSlot = .idle
    @Published public private(set) var secondarySlot: DinoSlot? = nil
    @Published public private(set) var currentPriority: SlotPriority = .p4Idle
    @Published public var isExpanded: Bool = false
    
    // MARK: - Internal Timers & Tasks
    private var toastDismissTask: Task<Void, Never>?
    private var onDemandDismissTask: Task<Void, Never>?
    
    // Stack to remember previous background state when interrupted by Toast or OnDemand
    private var backgroundSlot: DinoSlot = .idle
    
    private init() {
        setupBackgroundObservers()
    }
    
    // MARK: - Public API
    
    /// Trigger a P1 Toast (e.g., Volume HUD, Brightness, Charger)
    /// Automatically interrupts the current view and restores it after `duration`.
    public func triggerToast(_ slot: DinoSlot, duration: TimeInterval = 1.5) {
        toastDismissTask?.cancel()
        toastDismissTask = nil
        
        // Save current background state if we are interrupting
        if currentPriority < .p1Toast {
            // Keep existing backgroundSlot
        }
        
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.78)) {
            self.activeSlot = slot
            self.currentPriority = .p1Toast
        }
        
        toastDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self.dismissToast()
        }
    }
    
    /// Activate a P2 On-Demand feat via Shortcut or Menu (e.g., Weather, Pomodoro, Calendar)
    /// If `timeout` is provided (and not 0), auto-dismisses back to backgroundSlot after timeout.
    public func activateOnDemand(_ slot: DinoSlot, timeout: TimeInterval? = 5.0) {
        onDemandDismissTask?.cancel()
        onDemandDismissTask = nil
        
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.78)) {
            self.activeSlot = slot
            self.currentPriority = .p2OnDemand
        }
        
        if let timeout = timeout, timeout > 0 {
            onDemandDismissTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self.dismissOnDemand()
            }
        }
    }
    
    /// Dismiss the active on-demand slot and return to the underlying background/idle slot
    public func dismissOnDemand() {
        onDemandDismissTask?.cancel()
        onDemandDismissTask = nil
        
        guard currentPriority == .p2OnDemand else { return }
        
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.78)) {
            self.activeSlot = self.backgroundSlot
            self.currentPriority = (self.backgroundSlot == .idle) ? .p4Idle : .p3Background
            self.isExpanded = false
        }
    }
    
    /// Deactivate a specific slot if it is currently active
    public func deactivateSlot(_ slot: DinoSlot) {
        onDemandDismissTask?.cancel()
        onDemandDismissTask = nil
        
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.78)) {
            if self.activeSlot == slot {
                self.activeSlot = (self.backgroundSlot == slot) ? .idle : self.backgroundSlot
                self.currentPriority = (self.activeSlot == .idle) ? .p4Idle : .p3Background
                self.isExpanded = false
            }
        }
    }
    
    /// Dismiss the active toast immediately
    public func dismissToast() {
        toastDismissTask?.cancel()
        toastDismissTask = nil
        
        guard currentPriority == .p1Toast else { return }
        
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.78)) {
            self.activeSlot = self.backgroundSlot
            self.currentPriority = (self.backgroundSlot == .idle) ? .p4Idle : .p3Background
        }
    }
    
    /// Expand current slot into full card
    public func toggleExpanded() {
        withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.8)) {
            self.isExpanded.toggle()
        }
    }
    
    public func collapse() {
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.8)) {
            self.isExpanded = false
        }
    }
    
    /// Returns the recommended expanded size preset for the active slot
    public var currentSizePreset: ExpandedSizePreset {
        switch activeSlot {
        case .battery, .hud:
            return .compact
        case .music, .weather, .pomodoro, .webcam:
            return .standard
        case .calendar, .shelf, .download:
            return .large
        case .idle:
            return .compact
        }
    }
    
    // MARK: - Background State Calculation
    
    /// Recalculates the P3 background slot based on active background managers
    public func updateBackgroundState(
        isMusicPlaying: Bool,
        isPomodoroRunning: Bool,
        isDownloading: Bool
    ) {
        var newBackground: DinoSlot = .idle
        var newSecondary: DinoSlot? = nil
        
        if isMusicPlaying && isPomodoroRunning {
            newBackground = .music
            newSecondary = .pomodoro
        } else if isMusicPlaying {
            newBackground = .music
        } else if isPomodoroRunning {
            newBackground = .pomodoro
        } else if isDownloading {
            newBackground = .download
        }
        
        self.backgroundSlot = newBackground
        self.secondarySlot = newSecondary
        
        // If no high-priority toast or on-demand is active, update activeSlot immediately
        if currentPriority <= .p3Background {
            withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.78)) {
                self.activeSlot = newBackground
                self.currentPriority = (newBackground == .idle) ? .p4Idle : .p3Background
            }
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func setupBackgroundObservers() {
        Publishers.CombineLatest(
            MusicManager.shared.$isPlaying,
            PomodoroManager.shared.$state
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] isPlaying, pomodoroState in
            self?.updateBackgroundState(
                isMusicPlaying: isPlaying,
                isPomodoroRunning: (pomodoroState == .running),
                isDownloading: false
            )
        }
        .store(in: &cancellables)
    }
}
