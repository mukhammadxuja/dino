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

enum NotchTuningAxis {
    case width
    case height
}

@MainActor
final class NotchTuningPreviewState: ObservableObject {
    static let shared = NotchTuningPreviewState()
    static let rose = Color(red: 0.98, green: 0.24, blue: 0.40)

    @Published private(set) var activeAxis: NotchTuningAxis?
    @Published private(set) var draftValue = 0
    private var commitTask: Task<Void, Never>?
    private var pendingCommit: (@MainActor () -> Void)?
    private var previewBeganAt: Date = .distantPast

    func begin(_ axis: NotchTuningAxis, value: Int) {
        commitPendingChange()
        previewBeganAt = Date()
        if draftValue != value { draftValue = value }
        if activeAxis != axis { activeAxis = axis }
    }

    func update(_ value: Int) {
        if draftValue != value { draftValue = value }
    }

    func end(commit: @escaping @MainActor () -> Void) {
        commitTask?.cancel()
        pendingCommit = commit
        commitTask = Task { @MainActor in
            let remaining = max(0, 0.22 - Date().timeIntervalSince(previewBeganAt))
            if remaining > 0 {
                try? await Task.sleep(for: .milliseconds(Int(remaining * 1000)))
            }
            guard !Task.isCancelled else { return }
            activeAxis = nil
            try? await Task.sleep(for: .milliseconds(340))
            guard !Task.isCancelled else { return }
            commitPendingChange()
        }
    }

    private func commitPendingChange() {
        commitTask?.cancel()
        commitTask = nil
        let commit = pendingCommit
        pendingCommit = nil
        commit?()
    }
}

// MARK: - 3. Island Visual Style (Dark vs Glass)
public enum IslandStyle: String, CaseIterable, Identifiable, Defaults.Serializable {
    case dark = "Dark"
    case glass = "Glass"

    public var id: String { rawValue }
}

// MARK: - 4. Island Visibility (On Hover vs Always Visible vs On Click)
public enum IslandVisibility: String, CaseIterable, Identifiable, Defaults.Serializable {
    case onHover = "On Hover"
    case onClick = "On Click"
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
    static let displayShowOn = Key<DisplayShowOn>("displayShowOn", default: .automatic)
}

// MARK: - 7. Notification Names
public extension Notification.Name {
    static let displaySettingsChanged = Notification.Name("displaySettingsChanged")
    static let formFactorChanged = Notification.Name("formFactorChanged")
}
