//
//  DisplaySettings.swift
//  boringNotch
//

import SwiftUI
import Defaults

// MARK: - 1. Display Selection (Built-in, External, Both)
public enum DisplaySelection: String, CaseIterable, Identifiable, Defaults.Serializable {
    case builtin = "Built-in"
    case external = "External"
    case both = "Both"

    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .builtin:
            return "laptopcomputer"
        case .external:
            return "display"
        case .both:
            return "display.2"
        }
    }
}

// MARK: - 2. Form Factor (Notch vs Island)
public enum DisplayFormFactor: String, CaseIterable, Identifiable, Defaults.Serializable {
    case notch = "Notch"
    case island = "Island"

    public var id: String { rawValue }
}

// MARK: - 3. Island Visual Style (Dark vs Glass)
public enum IslandStyle: String, CaseIterable, Identifiable, Defaults.Serializable {
    case dark = "Dark"
    case glass = "Glass"

    public var id: String { rawValue }
}

// MARK: - 4. Island Visibility (On Hover vs Always Visible)
public enum IslandVisibility: String, CaseIterable, Identifiable, Defaults.Serializable {
    case onHover = "On Hover"
    case alwaysVisible = "Always Visible"

    public var id: String { rawValue }
}

// MARK: - 5. Multi-display Show On Target
public enum DisplayShowOn: String, CaseIterable, Identifiable, Defaults.Serializable {
    case automatic = "Automatic"
    case allDisplays = "All displays"
    case followPointer = "Follow pointer"

    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .automatic:
            return "sparkles"
        case .allDisplays:
            return "rectangle.on.rectangle"
        case .followPointer:
            return "cursorarrow.rays"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .automatic:
            return "Automatically manages displays based on current activity."
        case .allDisplays:
            return "Shown on your built-in display and every external display at the same time."
        case .followPointer:
            return "Shown on the display where your pointer is."
        }
    }
}

// MARK: - 6. Defaults Keys Extension for Display & Island Settings
extension Defaults.Keys {
    // Displays configuration
    static let displaySelection = Key<DisplaySelection>("displaySelection", default: .builtin)
    
    // Form Factor per display type
    static let builtinFormFactor = Key<DisplayFormFactor>("builtinFormFactor", default: .notch)
    static let externalFormFactor = Key<DisplayFormFactor>("externalFormFactor", default: .island)
    
    // Island appearance & behavior
    static let islandStyle = Key<IslandStyle>("islandStyle", default: .dark)
    static let islandVisibility = Key<IslandVisibility>("islandVisibility", default: .onHover)
    static let displayShowOn = Key<DisplayShowOn>("displayShowOn", default: .allDisplays)
}

// MARK: - 7. Notification Names
public extension Notification.Name {
    static let displaySettingsChanged = Notification.Name("displaySettingsChanged")
}
