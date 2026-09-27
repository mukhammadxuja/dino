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

    func play(fileName: String, fileExtension: String, subdirectory: String? = nil, volume: Float = 1.0) {
        _ = playIfAvailable(fileName: fileName, fileExtension: fileExtension, subdirectory: subdirectory, volume: volume)
    }

    @discardableResult
    func playIfAvailable(fileName: String, fileExtension: String, subdirectory: String? = nil, volume: Float = 1.0) -> Bool {
        let key = Self.keyFor(fileName: fileName, fileExtension: fileExtension, subdirectory: subdirectory)

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
            existing.volume = volume
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
            player.volume = volume
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

    func pause(fileName: String, fileExtension: String, subdirectory: String? = nil) {
        let key = Self.keyFor(fileName: fileName, fileExtension: fileExtension, subdirectory: subdirectory)
        if let player = Self.players[key], player.isPlaying {
            player.pause()
        }
    }

    @discardableResult
    func resume(fileName: String, fileExtension: String, subdirectory: String? = nil) -> Bool {
        let key = Self.keyFor(fileName: fileName, fileExtension: fileExtension, subdirectory: subdirectory)
        if let player = Self.players[key] {
            if !player.isPlaying {
                player.play()
                Self.currentlyPlayingKey = key
            }
            return true
        }
        return false
    }

    func stop(fileName: String, fileExtension: String, subdirectory: String? = nil) {
        let key = Self.keyFor(fileName: fileName, fileExtension: fileExtension, subdirectory: subdirectory)
        if let player = Self.players[key] {
            if player.isPlaying {
                player.stop()
            }
            player.currentTime = 0
            if Self.currentlyPlayingKey == key {
                Self.currentlyPlayingKey = nil
            }
        }
    }

    func isPlaying(fileName: String, fileExtension: String, subdirectory: String? = nil) -> Bool {
        let key = Self.keyFor(fileName: fileName, fileExtension: fileExtension, subdirectory: subdirectory)
        return Self.players[key]?.isPlaying ?? false
    }

    func stopAll() {
        for (_, player) in Self.players {
            if player.isPlaying {
                player.stop()
            }
            player.currentTime = 0
        }
        Self.currentlyPlayingKey = nil
    }

    private static func keyFor(fileName: String, fileExtension: String, subdirectory: String? = nil) -> String {
        [subdirectory, "\(fileName).\(fileExtension)"]
            .compactMap { $0 }
            .joined(separator: "/")
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

// MARK: - CustomSoundManager
import Defaults

@MainActor
final class CustomSoundManager: ObservableObject {
    static let shared = CustomSoundManager()

    private var audioPlayer: AVAudioPlayer?

    private var customSoundsDirectory: URL {
        let dir = documentsDirectory.appendingPathComponent("CustomSounds", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func importSound() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.audio, .mp3, .wav, .aiff]
        panel.title = "Import Custom Alert Sound"
        panel.prompt = "Import"

        if panel.runModal() == .OK, let selectedURL = panel.url {
            let filename = selectedURL.lastPathComponent
            let destinationURL = customSoundsDirectory.appendingPathComponent(filename)

            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: selectedURL, to: destinationURL)

                var currentSounds = Defaults[.customBatterySounds]
                if !currentSounds.contains(filename) {
                    currentSounds.append(filename)
                    Defaults[.customBatterySounds] = currentSounds
                }
                playCustom(soundName: filename)
            } catch {
                print("⚠️ [CustomSoundManager] Failed to import sound: \(error)")
            }
        }
    }

    func deleteSound(name: String) {
        let destinationURL = customSoundsDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: destinationURL)

        var currentSounds = Defaults[.customBatterySounds]
        currentSounds.removeAll { $0 == name }
        Defaults[.customBatterySounds] = currentSounds
    }

    func playCustom(soundName: String) {
        let fileURL = customSoundsDirectory.appendingPathComponent(soundName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            NSSound.beep()
            return
        }

        do {
            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("⚠️ [CustomSoundManager] Failed to play: \(error)")
            NSSound.beep()
        }
    }

    func playAny(soundName: String) {
        if Defaults[.customBatterySounds].contains(soundName) {
            playCustom(soundName: soundName)
        } else if let choice = BatterySoundChoice(rawValue: soundName) {
            choice.play()
        } else if let sound = NSSound(named: NSSound.Name(soundName)) {
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}

