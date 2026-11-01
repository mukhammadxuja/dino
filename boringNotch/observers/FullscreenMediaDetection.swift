//
//  FullscreenMediaDetection.swift
//  boringNotch
//
//  Created by Richard Kunkli on 06/09/2024.
//

import Foundation
import Combine
import Defaults
import MacroVisionKit

@MainActor
final class FullscreenMediaDetector: ObservableObject {
    static let shared = FullscreenMediaDetector()
    
    @Published var fullscreenStatus: [String: Bool] = [:]
    
    private var monitorTask: Task<Void, Never>?
    private var latestSpaces: [MacroVisionKit.FullScreenMonitor.SpaceInfo] = []
    private var optionSubscription: AnyCancellable?
    private var musicSourceSubscription: AnyCancellable?
    
    private init() {
        startMonitoring()
        optionSubscription = Defaults.publisher(.hideNotchOption)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateStatus(with: self.latestSpaces)
            }
        musicSourceSubscription = MusicManager.shared.$bundleIdentifier
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateStatus(with: self.latestSpaces)
            }
    }
    
    deinit {
        monitorTask?.cancel()
    }
    
    private func startMonitoring() {
        monitorTask = Task { @MainActor in
            let stream = await FullScreenMonitor.shared.spaceChanges()
            for await spaces in stream {
                latestSpaces = spaces
                updateStatus(with: spaces)
            }
        }
    }
    
    private func updateStatus(with spaces: [MacroVisionKit.FullScreenMonitor.SpaceInfo]) {
        var newStatus: [String: Bool] = [:]
        
        for space in spaces {
            if let uuid = space.screenUUID {
                let shouldDetect: Bool
                switch Defaults[.hideNotchOption] {
                case .always:
                    shouldDetect = true
                case .nowPlayingOnly:
                    if let bundle = MusicManager.shared.bundleIdentifier {
                        shouldDetect = space.runningApps.contains(bundle)
                    } else {
                        shouldDetect = false
                    }
                case .never:
                    shouldDetect = false
                }
                newStatus[uuid] = shouldDetect
            }
        }
        
        if fullscreenStatus != newStatus {
            fullscreenStatus = newStatus
        }
    }
}

