//
//  DinoHotKeyManager.swift
//  Dino
//
//  Created for Dino Architecture Evolution.
//

import AppKit
import Defaults
import Foundation
import KeyboardShortcuts
import SwiftUI

@MainActor
public final class DinoHotKeyManager {
    public static let shared = DinoHotKeyManager()
    
    private init() {}
    
    public func registerAllShortcuts() {
        // Weather Module (`Cmd + Shift + W`)
        KeyboardShortcuts.onKeyDown(for: .selectWeatherModule) {
            Task { @MainActor in
                withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.8)) {
                    DinoCoordinator.shared.activateOnDemand(.weather, timeout: 5.0)
                }
            }
        }
        
        // Music Module (`Cmd + Shift + P`)
        KeyboardShortcuts.onKeyDown(for: .selectMusicModule) {
            Task { @MainActor in
                withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.8)) {
                    Defaults[.activeModule] = .music
                    BoringViewCoordinator.shared.currentView = .home
                    DinoCoordinator.shared.activateOnDemand(.music, timeout: 5.0)
                }
            }
        }
        
        // Pomodoro Module (`Cmd + Shift + O`)
        KeyboardShortcuts.onKeyDown(for: .selectPomodoroModule) {
            Task { @MainActor in
                withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.8)) {
                    Defaults[.activeModule] = .pomodoro
                    Defaults[.pomodoroEnabled] = true
                    BoringViewCoordinator.shared.currentView = .home
                    DinoCoordinator.shared.activateOnDemand(.pomodoro, timeout: 5.0)
                }
            }
        }
        
        // Calendar Module (`Cmd + Shift + A`)
        KeyboardShortcuts.onKeyDown(for: .selectCalendarModule) {
            Task { @MainActor in
                withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.8)) {
                    Defaults[.activeModule] = .calendar
                    Defaults[.showCalendar] = true
                    BoringViewCoordinator.shared.currentView = .home
                    DinoCoordinator.shared.activateOnDemand(.calendar, timeout: 5.0)
                }
            }
        }
        
        // Battery Module (`Cmd + Shift + B`)
        KeyboardShortcuts.onKeyDown(for: .selectBatteryModule) {
            Task { @MainActor in
                withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.8)) {
                    Defaults[.activeModule] = .battery
                    BoringViewCoordinator.shared.currentView = .home
                    DinoCoordinator.shared.activateOnDemand(.battery, timeout: 4.0)
                }
            }
        }
        
        // Shelf Module (`Cmd + Shift + U`)
        KeyboardShortcuts.onKeyDown(for: .selectShelfModule) {
            Task { @MainActor in
                withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.8)) {
                    Defaults[.activeModule] = .shelf
                    BoringViewCoordinator.shared.currentView = .shelf
                    DinoCoordinator.shared.activateOnDemand(.shelf, timeout: nil) // Pinned
                }
            }
        }
    }
}
