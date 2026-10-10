//
//  DinoCoordinator.swift
//  Dino
//
//  Created for Dino Architecture Evolution.
//

import Combine
import Defaults
import Foundation
import SwiftUI

// MARK: - Dual Activity Side Selection
public enum DualActivitySide: Sendable {
    case leading   // Chap tomon (masalan: Musiqa)
    case trailing  // O'ng tomon (masalan: Pomodoro)
}

// MARK: - Dino Slot Types
public enum DinoSlot: Equatable, Hashable, Sendable {
    case idle
    case music
    case pomodoro
    case weather
    case calendar
    case shelf
    case battery
    case coding
    case download
    case webcam
    case hud(HUDType)
    
    public enum HUDType: Equatable, Hashable, Sendable {
        case volume(value: Double)
        case brightness(value: Double)
        case backlight(value: Double)
        case micMute(isMuted: Bool)
    }
    
    var asActiveModule: ActiveNotchModule {
        switch self {
        case .idle: return .none
        case .music: return .music
        case .pomodoro: return .pomodoro
        case .calendar: return .calendar
        case .battery: return .battery
        case .coding: return .coding
        case .shelf: return .shelf
        case .weather, .download, .webcam, .hud: return .none
        }
    }
    
    var asNotchView: NotchViews {
        switch self {
        case .shelf: return .shelf
        case .calendar: return .calendar
        default: return .home
        }
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

// MARK: - Dino Coordinator (Single Source of Truth)
@MainActor
public final class DinoCoordinator: ObservableObject {
    public static let shared = DinoCoordinator()
    
    // MARK: - Published State (SSOT)
    @Published public private(set) var activeSlot: DinoSlot = .idle
    @Published public private(set) var secondarySlot: DinoSlot? = nil
    @Published public private(set) var currentPriority: SlotPriority = .p4Idle
    @Published public var isExpanded: Bool = false
    
    // MARK: - Priority Stack Entry (Interrupt & Resume)
    public struct PriorityStackEntry: Equatable, Sendable {
        public let slot: DinoSlot
        public let priority: SlotPriority
        public let secondarySlot: DinoSlot?
        public let timestamp: Date
    }
    
    // Stack to handle interrupts (e.g. P1 interrupts P2, P2 interrupts P3)
    private var interruptStack: [PriorityStackEntry] = []
    
    // MARK: - Internal Timers & Tasks
    private var toastDismissTask: Task<Void, Never>?
    private var onDemandDismissTask: Task<Void, Never>?
    
    // Underlying background slot when no higher priority feat is active
    public private(set) var backgroundSlot: DinoSlot = .idle
    
    // Loop-prevention guard during SSOT synchronization
    private var isSyncing: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupBackgroundObservers()
        setupLegacyStateSync()
    }
    
    // MARK: - Public State Query
    
    public var isDualActivityActive: Bool {
        (activeSlot == .music && secondarySlot == .pomodoro) ||
        (activeSlot == .pomodoro && secondarySlot == .music)
    }
    
    // MARK: - Dual Activity Switching
    
    /// Swaps primary (activeSlot) and secondarySlot when dual activities are running
    public func swapActiveAndSecondary() {
        guard let sec = secondarySlot else { return }
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.78)) {
            let prevActive = self.activeSlot
            self.activeSlot = sec
            self.secondarySlot = prevActive
            self.syncLegacyState(for: self.activeSlot)
        }
    }
    
    /// Activates the clicked side of dual activity: leading (Music) or trailing (Pomodoro)
    public func activateDualSlotSide(_ side: DualActivitySide) {
        switch side {
        case .leading:
            if activeSlot != .music {
                swapActiveAndSecondary()
            }
        case .trailing:
            if activeSlot != .pomodoro {
                swapActiveAndSecondary()
            }
        }
    }
    
    // MARK: - Direct & On-Demand Slot Activation (SSOT)
    
    /// Directly sets the active slot and synchronizes legacy state
    public func activateSlotDirectly(_ slot: DinoSlot) {
        onDemandDismissTask?.cancel()
        onDemandDismissTask = nil
        interruptStack.removeAll()
        
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.78)) {
            self.activeSlot = slot
            self.currentPriority = (slot == .idle) ? .p4Idle : .p2OnDemand
            self.syncLegacyState(for: slot)
        }
    }
    
    /// Trigger a P1 Toast (e.g., Volume HUD, Brightness, Charger)
    /// Automatically interrupts the current view and restores it after `duration`.
    public func triggerToast(_ slot: DinoSlot, duration: TimeInterval = 1.5) {
        toastDismissTask?.cancel()
        toastDismissTask = nil
        
        // Push currently active slot to the interrupt stack if priority is lower than P1
        if currentPriority < .p1Toast {
            interruptStack.append(
                PriorityStackEntry(
                    slot: activeSlot,
                    priority: currentPriority,
                    secondarySlot: secondarySlot,
                    timestamp: Date()
                )
            )
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
        
        // Save current background state to interrupt stack
        if currentPriority <= .p3Background {
            interruptStack.removeAll { $0.priority <= .p3Background }
            interruptStack.append(
                PriorityStackEntry(
                    slot: activeSlot,
                    priority: currentPriority,
                    secondarySlot: secondarySlot,
                    timestamp: Date()
                )
            )
        }
        
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.78)) {
            self.activeSlot = slot
            self.currentPriority = .p2OnDemand
            self.syncLegacyState(for: slot)
        }
        
        if let timeout = timeout, timeout > 0 {
            onDemandDismissTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self.dismissOnDemand()
            }
        }
    }
    
    /// Pause auto-dismiss timer when user hovers or interacts with on-demand module
    public func pauseOnDemandDismiss() {
        onDemandDismissTask?.cancel()
        onDemandDismissTask = nil
    }
    
    /// Resume auto-dismiss timer after user leaves on-demand module
    public func resumeOnDemandDismiss(timeout: TimeInterval = 5.0) {
        guard currentPriority == .p2OnDemand else { return }
        onDemandDismissTask?.cancel()
        onDemandDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self.dismissOnDemand()
        }
    }
    
    /// Dismiss the active on-demand slot and return to the underlying background/idle slot
    public func dismissOnDemand() {
        onDemandDismissTask?.cancel()
        onDemandDismissTask = nil
        
        guard currentPriority == .p2OnDemand else { return }
        
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.78)) {
            if let previous = interruptStack.popLast(), previous.priority <= .p3Background {
                self.activeSlot = previous.slot
                self.secondarySlot = previous.secondarySlot
                self.currentPriority = previous.priority
                self.isExpanded = false
                self.syncLegacyState(for: previous.slot)
            } else {
                self.activeSlot = self.backgroundSlot
                self.currentPriority = (self.backgroundSlot == .idle) ? .p4Idle : .p3Background
                self.isExpanded = false
                self.syncLegacyState(for: self.backgroundSlot)
            }
        }
    }
    
    /// Deactivate a specific slot if it is currently active
    public func deactivateSlot(_ slot: DinoSlot) {
        onDemandDismissTask?.cancel()
        onDemandDismissTask = nil
        interruptStack.removeAll { $0.slot == slot }
        
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.78)) {
            if self.activeSlot == slot {
                self.activeSlot = (self.backgroundSlot == slot) ? .idle : self.backgroundSlot
                self.currentPriority = (self.activeSlot == .idle) ? .p4Idle : .p3Background
                self.isExpanded = false
                self.syncLegacyState(for: self.activeSlot)
            }
        }
    }
    
    /// Dismiss the active toast immediately and restore interrupted state
    public func dismissToast() {
        toastDismissTask?.cancel()
        toastDismissTask = nil
        
        guard currentPriority == .p1Toast else { return }
        
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.78)) {
            if let previous = interruptStack.popLast() {
                self.activeSlot = previous.slot
                self.secondarySlot = previous.secondarySlot
                self.currentPriority = previous.priority
                self.syncLegacyState(for: previous.slot)
            } else {
                self.activeSlot = self.backgroundSlot
                self.currentPriority = (self.backgroundSlot == .idle) ? .p4Idle : .p3Background
                self.syncLegacyState(for: self.backgroundSlot)
            }
        }
    }
    
    // MARK: - BoringViewModel Open/Close Integration
    
    /// Expand current slot into full card
    public func toggleExpanded() {
        if BoringViewModel.shared.notchState == .open {
            BoringViewModel.shared.close()
        } else {
            BoringViewModel.shared.open()
        }
    }
    
    public func expand() {
        if BoringViewModel.shared.notchState != .open {
            BoringViewModel.shared.open()
        }
    }
    
    public func collapse() {
        if BoringViewModel.shared.notchState == .open {
            BoringViewModel.shared.close()
        }
    }

    // MARK: - Smart Shortcut Toggling & Seamless Morphing
    
    /// Handles intelligent hotkey triggering:
    /// - 1st press (closed): opens the card directly
    /// - 2nd press (same slot open): closes card and returns to previous P3 background
    /// - Cross-shortcut press (different slot open): smoothly morphs content and size in-place without closing
    public func toggleOrMorphSlot(_ slot: DinoSlot) {
        let isOpen = BoringViewModel.shared.notchState == .open
        let isCurrentSame = (activeSlot == slot)
        
        if isOpen && isCurrentSame {
            // Case 2: 2nd press on same slot -> Close card and return to underlying P3 background
            withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.78)) {
                BoringViewModel.shared.close()
                self.dismissOnDemand()
            }
        } else if isOpen && !isCurrentSame {
            // Case 3: Switch between shortcuts while open -> In-place seamless morph without closing!
            withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.76)) {
                self.activateOnDemand(slot, timeout: nil)
                BoringViewModel.shared.open()
            }
        } else {
            // Case 1: 1st press while closed -> Open card directly
            withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.74)) {
                self.activateOnDemand(slot, timeout: nil)
                BoringViewModel.shared.open()
            }
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
        case .idle, .coding:
            return .standard
        }
    }
    
    // MARK: - Legacy Synchronization (SSOT)
    
    private func syncLegacyState(for slot: DinoSlot) {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        
        switch slot {
        case .shelf:
            BoringViewCoordinator.shared.currentView = .shelf
        case .music, .pomodoro, .calendar, .battery, .coding, .weather, .idle:
            BoringViewCoordinator.shared.currentView = .home
        case .download, .webcam, .hud:
            break
        }
    }
    
    private func setupLegacyStateSync() {
        // Observe Defaults[.activeModule] changes from UI / Settings
        Defaults.publisher(.activeModule)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                guard let self = self, !self.isSyncing else { return }
                let module = change.newValue
                if self.currentPriority <= .p2OnDemand {
                    switch module {
                    case .music:
                        if self.activeSlot != .music { self.activateSlotDirectly(.music) }
                    case .pomodoro:
                        if self.activeSlot != .pomodoro { self.activateSlotDirectly(.pomodoro) }
                    case .calendar:
                        if self.activeSlot != .calendar { self.activateSlotDirectly(.calendar) }
                    case .battery:
                        if self.activeSlot != .battery { self.activateSlotDirectly(.battery) }
                    case .shelf:
                        if self.activeSlot != .shelf { self.activateSlotDirectly(.shelf) }
                    case .coding:
                        if self.activeSlot != .coding { self.activateSlotDirectly(.coding) }
                    case .none:
                        break
                    }
                }
            }
            .store(in: &cancellables)
            
        // Observe BoringViewCoordinator tab switches
        BoringViewCoordinator.shared.$currentView
            .receive(on: DispatchQueue.main)
            .sink { [weak self] view in
                guard let self = self, !self.isSyncing else { return }
                switch view {
                case .shelf:
                    if self.activeSlot != .shelf { self.activateSlotDirectly(.shelf) }
                case .calendar:
                    if self.activeSlot != .calendar { self.activateSlotDirectly(.calendar) }
                case .home:
                    if self.activeSlot == .shelf || self.activeSlot == .calendar {
                        self.activateSlotDirectly(self.backgroundSlot)
                    }
                }
            }
            .store(in: &cancellables)
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
                self.syncLegacyState(for: newBackground)
            }
        }
    }
    
    private func setupBackgroundObservers() {
        Publishers.CombineLatest3(
            MusicManager.shared.$isPlaying,
            MusicManager.shared.$isPlayerIdle,
            PomodoroManager.shared.$state
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] isPlaying, isPlayerIdle, pomodoroState in
            let hasMusic = isPlaying || !isPlayerIdle
            let hasPomodoro = (pomodoroState != .idle)
            self?.updateBackgroundState(
                isMusicPlaying: hasMusic,
                isPomodoroRunning: hasPomodoro,
                isDownloading: false
            )
        }
        .store(in: &cancellables)
    }
}
