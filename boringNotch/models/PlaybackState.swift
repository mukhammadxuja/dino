//
//  PlaybackState.swift
//  boringNotch
//
//  Created by Alexander on 2025-03-29.
//

import Foundation

/// Keep an optimistic seek position until the controller acknowledges it.
struct PlaybackSeekState {
    private var target: TimeInterval?
    private var requestedAt: Date?
    private var minimumTimestamp: Date?

    mutating func begin(at position: TimeInterval, now: Date) {
        target = position
        requestedAt = now
        minimumTimestamp = now
    }

    mutating func reset() {
        self = PlaybackSeekState()
    }

    mutating func accepts(position: TimeInterval, timestamp: Date, now: Date, isPlaying: Bool, playbackRate: Double) -> Bool {
        guard let minimumTimestamp else { return true }
        guard timestamp >= minimumTimestamp else { return false }
        if let target, let requestedAt {
            let progressed = isPlaying ? max(0, timestamp.timeIntervalSince(requestedAt)) * playbackRate : 0
            let acknowledged = abs(position - (target + progressed)) <= 1
            // A failed/rejected seek must eventually recover to the actual player time.
            guard acknowledged || now.timeIntervalSince(requestedAt) >= 2 else { return false }
            self.target = nil
            self.requestedAt = nil
        }
        self.minimumTimestamp = timestamp
        return true
    }
}

enum RepeatMode: Int, Codable {
    case off = 1
    case one = 2
    case all = 3
}

struct PlaybackState {
    var bundleIdentifier: String
    var isPlaying: Bool = false
    var title: String = "I'm Handsome"
    var artist: String = "Me"
    var album: String = "Self Love"
    var currentTime: Double = 0
    var duration: Double = 0
    var playbackRate: Double = 1
    var isShuffled: Bool = false
    var repeatMode: RepeatMode = .off
    var lastUpdated: Date = Date.distantPast
    var artwork: Data?
    var volume: Double = 0.5
    var isFavorite: Bool = false
}

extension PlaybackState: Equatable {
    static func == (lhs: PlaybackState, rhs: PlaybackState) -> Bool {
        return lhs.bundleIdentifier == rhs.bundleIdentifier
            && lhs.isPlaying == rhs.isPlaying
            && lhs.title == rhs.title
            && lhs.artist == rhs.artist
            && lhs.album == rhs.album
            && lhs.currentTime == rhs.currentTime
            && lhs.duration == rhs.duration
            && lhs.isShuffled == rhs.isShuffled
            && lhs.repeatMode == rhs.repeatMode
            && lhs.artwork == rhs.artwork
            && lhs.isFavorite == rhs.isFavorite
    }
}
