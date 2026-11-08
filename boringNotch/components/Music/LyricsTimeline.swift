import Foundation

struct LyricsScrollFollowState {
    private(set) var isFollowingPlayback = true
    private(set) var isActiveLineDisplaced = false

    var showsSync: Bool { !isFollowingPlayback && isActiveLineDisplaced }

    mutating func beginBrowsing() {
        isFollowingPlayback = false
    }

    mutating func updateActiveLine(distanceFromAnchor: Double) {
        isActiveLineDisplaced = abs(distanceFromAnchor) > 20
    }

    mutating func resume() {
        isFollowingPlayback = true
        isActiveLineDisplaced = false
    }
}

/// Track the active lyric line using timestamps supplied by the provider.
struct LyricsTimeline {
    enum ContentState {
        case loading, available, unavailable
    }

    struct Line: Identifiable {
        let id: Int
        let text: String
        let start: Double?
    }

    let lines: [Line]
    let isSynced: Bool

    var hasText: Bool {
        lines.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func contentState(isFetching: Bool) -> ContentState {
        isFetching ? .loading : (hasText ? .available : .unavailable)
    }

    /// Keep the compact caption readable during pauses, intros, and instrumental gaps.
    func inlineText(at position: Double) -> String {
        guard isSynced else { return lines.first?.text ?? "" }
        if let active = activeLine(at: position),
           let line = lines[...active].last(where: { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return line.text
        }
        return lines.first(where: { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.text ?? ""
    }

    static func resolveSearchResults(_ results: [[String: Any]]) -> (plain: String, synced: String) {
        for result in results {
            let plain = (result["plainLyrics"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let synced = (result["syncedLyrics"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !plain.isEmpty || !synced.isEmpty { return (plain, synced) }
        }
        return ("", "")
    }

    init(synced: [(time: Double, text: String)], plain: String) {
        isSynced = !synced.isEmpty
        if synced.isEmpty {
            lines = plain.split(whereSeparator: \.isNewline).enumerated().map {
                Line(id: $0.offset, text: String($0.element), start: nil)
            }
        } else {
            lines = synced.enumerated().map { index, line in
                Line(id: index, text: line.text, start: line.time)
            }
        }
    }

    func activeLine(at position: Double) -> Int? {
        guard isSynced else { return nil }
        var low = 0
        var high = lines.count
        while low < high {
            let mid = (low + high) / 2
            if (lines[mid].start ?? 0) <= position { low = mid + 1 } else { high = mid }
        }
        return low == 0 ? nil : low - 1
    }

    static func parseLRC(_ lrc: String) -> [(time: Double, text: String)] {
        guard let regex = try? NSRegularExpression(pattern: #"\[(\d+):(\d{2}(?:\.\d{1,3})?)\]"#) else { return [] }
        var result: [(time: Double, text: String)] = []
        for line in lrc.components(separatedBy: .newlines) {
            let source = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: source.length))
            guard let last = matches.last else { continue }
            let text = source.substring(from: NSMaxRange(last.range)).trimmingCharacters(in: .whitespaces)
            for match in matches {
                guard let minutes = Double(source.substring(with: match.range(at: 1))),
                      let seconds = Double(source.substring(with: match.range(at: 2))), seconds < 60 else { continue }
                result.append((minutes * 60 + seconds, text))
            }
        }
        return result.sorted { $0.time < $1.time }
    }
}
