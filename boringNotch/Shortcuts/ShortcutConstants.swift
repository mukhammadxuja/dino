//
//  Constants.swift
//  boringNotch
//
//  Created by Richard Kunkli on 16/08/2024.
//

import KeyboardShortcuts
import SwiftUI

extension KeyboardShortcuts.Name {
    static let clipboardHistoryPanel = Self("clipboardHistoryPanel", default: .init(.c, modifiers: [.shift, .command]))
    static let toggleMicrophone = Self("toggleMicrophone", default: .init(.f5, modifiers: [.function]))
    static let decreaseBacklight = Self("decreaseBacklight", default: .init(.f1, modifiers: [.command]))
    static let increaseBacklight = Self("increaseBacklight", default: .init(.f2, modifiers: [.command]))
    static let toggleSneakPeek = Self("toggleSneakPeek", default: .init(.h, modifiers: [.command, .shift]))
    static let toggleNotchOpen = Self("toggleNotchOpen", default: .init(.i, modifiers: [.command, .shift]))
    static let pomodoroEmergencyExit = Self("pomodoroEmergencyExit", default: .init(.escape, modifiers: []))
    
    // Module selection shortcuts
    static let selectMusicModule = Self("selectMusicModule", default: .init(.p, modifiers: [.command, .shift]))
    static let selectPomodoroModule = Self("selectPomodoroModule", default: .init(.o, modifiers: [.command, .shift]))
    static let selectCalendarModule = Self("selectCalendarModule", default: .init(.a, modifiers: [.command, .shift]))
    static let selectBatteryModule = Self("selectBatteryModule", default: .init(.b, modifiers: [.command, .shift]))
    static let selectCodingModule = Self("selectCodingModule", default: .init(.d, modifiers: [.command, .shift]))
    static let selectShelfModule = Self("selectShelfModule", default: .init(.u, modifiers: [.command, .shift]))
}
