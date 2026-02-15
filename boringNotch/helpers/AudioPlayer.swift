//
//  AudioPlayer.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 09/08/24.
//

import Foundation
import AVFoundation
import AppKit

class AudioPlayer {
    private static var players: [String: AVAudioPlayer] = [:]
    private static var tempURLsByKey: [String: URL] = [:]
    private static var currentlyPlayingKey: String?

    func play(fileName: String, fileExtension: String, subdirectory: String? = nil) {
        _ = playIfAvailable(fileName: fileName, fileExtension: fileExtension, subdirectory: subdirectory)
    }

    @discardableResult
    func playIfAvailable(fileName: String, fileExtension: String, subdirectory: String? = nil) -> Bool {
        let key = [subdirectory, "\(fileName).\(fileExtension)"]
            .compactMap { $0 }
            .joined(separator: "/")

        if let currentKey = Self.currentlyPlayingKey, currentKey != key, let currentPlayer = Self.players[currentKey] {
            if currentPlayer.isPlaying {
                currentPlayer.stop()
            }
            currentPlayer.currentTime = 0
        }

        if let existing = Self.players[key] {
            if existing.isPlaying {
                existing.stop()
            }
            existing.currentTime = 0
            existing.play()
            Self.currentlyPlayingKey = key
            return true
        }

        let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension, subdirectory: subdirectory)
            ?? Bundle.main.url(forResource: fileName, withExtension: fileExtension)
            ?? Self.findResourceURL(fileName: fileName, fileExtension: fileExtension)
            ?? Self.writeAssetToTempURLIfNeeded(key: key, assetName: fileName, fileExtension: fileExtension)
            ?? Self.writeAssetToTempURLIfNeeded(key: key, assetName: "sounds/\(fileName)", fileExtension: fileExtension)

        guard let url else {
            print("⚠️ [AudioPlayer] Resource not found: \(key)")
            return false
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = 0
            player.prepareToPlay()
            Self.players[key] = player
            player.play()
            Self.currentlyPlayingKey = key
            return true
        } catch {
            print("⚠️ [AudioPlayer] Failed to play \(url.lastPathComponent): \(error.localizedDescription)")
            return false
        }
    }

    private static func findResourceURL(fileName: String, fileExtension: String) -> URL? {
        let target = "\(fileName).\(fileExtension)"

        // Common cases
        if let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension, subdirectory: "sounds") {
            return url
        }

        // Fallback: scan all resources of this extension in the bundle.
        if let urls = Bundle.main.urls(forResourcesWithExtension: fileExtension, subdirectory: nil) {
            return urls.first(where: { $0.lastPathComponent.caseInsensitiveCompare(target) == .orderedSame })
        }

        return nil
    }

    private static func writeAssetToTempURLIfNeeded(key: String, assetName: String, fileExtension: String) -> URL? {
        if let existing = tempURLsByKey[key], FileManager.default.fileExists(atPath: existing.path) {
            return existing
        }

        guard let asset = NSDataAsset(name: assetName) else {
            return nil
        }

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("boringNotch_audio_\(key.replacingOccurrences(of: "/", with: "_"))")
            .appendingPathExtension(fileExtension)

        do {
            try asset.data.write(to: tmp, options: .atomic)
            tempURLsByKey[key] = tmp
            return tmp
        } catch {
            print("⚠️ [AudioPlayer] Failed writing asset \(assetName) to temp: \(error.localizedDescription)")
            return nil
        }
    }
}
