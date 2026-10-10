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
        // Weather Module (`Cmd + Shift + W` or `Option + W`)
        let triggerWeather: () -> Void = {
            Task { @MainActor in
                DinoCoordinator.shared.toggleOrMorphSlot(.weather)
            }
        }
        KeyboardShortcuts.onKeyDown(for: .selectWeatherModule, action: triggerWeather)
        KeyboardShortcuts.onKeyDown(for: .optionWeatherShortcut, action: triggerWeather)
        
        // Calendar Module (`Cmd + Shift + A` or `Option + C`)
        let triggerCalendar: () -> Void = {
            Task { @MainActor in
                Defaults[.showCalendar] = true
                DinoCoordinator.shared.toggleOrMorphSlot(.calendar)
            }
        }
        KeyboardShortcuts.onKeyDown(for: .selectCalendarModule, action: triggerCalendar)
        KeyboardShortcuts.onKeyDown(for: .optionCalendarShortcut, action: triggerCalendar)

        // Music Module (`Cmd + Shift + P` or `Option + P`)
        let triggerMusic: () -> Void = {
            Task { @MainActor in
                DinoCoordinator.shared.toggleOrMorphSlot(.music)
            }
        }
        KeyboardShortcuts.onKeyDown(for: .selectMusicModule, action: triggerMusic)
        KeyboardShortcuts.onKeyDown(for: .optionMusicShortcut, action: triggerMusic)
        
        // Pomodoro Module (`Cmd + Shift + O` or `Option + O`)
        let triggerPomodoro: () -> Void = {
            Task { @MainActor in
                Defaults[.pomodoroEnabled] = true
                DinoCoordinator.shared.toggleOrMorphSlot(.pomodoro)
            }
        }
        KeyboardShortcuts.onKeyDown(for: .selectPomodoroModule, action: triggerPomodoro)
        KeyboardShortcuts.onKeyDown(for: .optionPomodoroShortcut, action: triggerPomodoro)
        
        // Battery Module (`Cmd + Shift + B`)
        KeyboardShortcuts.onKeyDown(for: .selectBatteryModule) {
            Task { @MainActor in
                DinoCoordinator.shared.toggleOrMorphSlot(.battery)
            }
        }
        
        // Shelf Module (`Cmd + Shift + U`)
        KeyboardShortcuts.onKeyDown(for: .selectShelfModule) {
            Task { @MainActor in
                DinoCoordinator.shared.toggleOrMorphSlot(.shelf)
            }
        }
        
        // Emergency Exit / Escape: Close open card and restore P3 background immediately
        KeyboardShortcuts.onKeyDown(for: .pomodoroEmergencyExit) {
            Task { @MainActor in
                if BoringViewModel.shared.notchState == .open {
                    withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.78)) {
                        BoringViewModel.shared.close()
                        DinoCoordinator.shared.dismissOnDemand()
                    }
                } else if DinoCoordinator.shared.currentPriority == .p2OnDemand {
                    withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.78)) {
                        DinoCoordinator.shared.dismissOnDemand()
                    }
                }
            }
        }
    }
}
