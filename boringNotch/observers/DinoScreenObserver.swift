//
//  DinoScreenObserver.swift
//  boringNotch
//

import Cocoa
import Defaults

@MainActor
final class DinoScreenObserver {
    static let shared = DinoScreenObserver()

    private var previousScreens: [NSScreen]?
    private var pointerMonitor: Any?
    private var lastPointerScreenUUID: String?

    var onScreenParametersChanged: (() -> Void)?
    var onPointerScreenChanged: (() -> Void)?

    private init() {
        previousScreens = NSScreen.screens
    }

    // MARK: - Screen Resolution Logic

    func targetScreens() -> [NSScreen] {
        let selection = Defaults[.displaySelection]
        let showOn = Defaults[.displayShowOn]
        let allScreens = NSScreen.screens

        switch selection {
        case .builtin:
            if let builtin = allScreens.first(where: { $0.isBuiltin }) ?? allScreens.first {
                return [builtin]
            }
            return []
        case .external:
            let externals = allScreens.filter { !$0.isBuiltin }
            guard !externals.isEmpty else {
                return allScreens.count > 1 ? [allScreens.last!] : allScreens
            }
            switch showOn {
            case .allDisplays:
                return externals
            case .followPointer:
                let mouseLoc = NSEvent.mouseLocation
                if let pointerScreen = externals.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) {
                    return [pointerScreen]
                }
                return [externals.first!]
            case .automatic:
                if let main = NSScreen.main, externals.contains(main) {
                    return [main]
                }
                return [externals.first!]
            }
        case .both:
            let builtin = allScreens.first(where: { $0.isBuiltin }) ?? allScreens.first
            let externals = allScreens.filter { !$0.isBuiltin }
            switch showOn {
            case .allDisplays:
                return allScreens
            case .followPointer:
                let mouseLoc = NSEvent.mouseLocation
                if let pointerScreen = allScreens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) {
                    return [pointerScreen]
                }
                return allScreens
            case .automatic:
                var result: [NSScreen] = []
                if let b = builtin { result.append(b) }
                if let ext = externals.first { result.append(ext) }
                return result.isEmpty ? allScreens : result
            }
        }
    }

    func targetLockScreenScreens(preferredScreenUUID: String?) -> [NSScreen] {
        if Defaults[.showOnAllDisplays] {
            return NSScreen.screens
        }

        if let preferredScreen = NSScreen.screen(withUUID: preferredScreenUUID ?? "") {
            return [preferredScreen]
        }

        if let main = NSScreen.main {
            return [main]
        }

        return NSScreen.screens.prefix(1).map { $0 }
    }

    // MARK: - Change Detection

    func hasScreenConfigurationChanged() -> Bool {
        let currentScreens = NSScreen.screens

        let screensChanged =
            currentScreens.count != previousScreens?.count
            || Set(currentScreens.compactMap { $0.displayUUID })
                != Set(previousScreens?.compactMap { $0.displayUUID } ?? [])
            || Set(currentScreens.map { $0.frame }) != Set(previousScreens?.map { $0.frame } ?? [])

        previousScreens = currentScreens
        return screensChanged
    }

    func deviceHasNotch() -> Bool {
        for screen in NSScreen.screens {
            if screen.safeAreaInsets.top > 0 {
                return true
            }
        }
        return false
    }

    // MARK: - Pointer Tracking

    func setupPointerTracking(onChanged: @escaping () -> Void) {
        if let monitor = pointerMonitor {
            NSEvent.removeMonitor(monitor)
            pointerMonitor = nil
        }

        guard Defaults[.displayShowOn] == .followPointer else { return }

        self.onPointerScreenChanged = onChanged

        pointerMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            guard let self = self else { return }
            let mouseLoc = NSEvent.mouseLocation
            let currentScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) })
            let currentUUID = currentScreen?.displayUUID

            if let currentUUID = currentUUID, currentUUID != self.lastPointerScreenUUID {
                self.lastPointerScreenUUID = currentUUID
                Task { @MainActor in
                    self.onPointerScreenChanged?()
                }
            }
        }
    }

    func stopPointerTracking() {
        if let monitor = pointerMonitor {
            NSEvent.removeMonitor(monitor)
            pointerMonitor = nil
        }
        onPointerScreenChanged = nil
    }
}
