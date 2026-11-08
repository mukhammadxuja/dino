// Run: xcrun swiftc -module-cache-path /tmp/dino-lyrics-module-cache
// boringNotch/models/PlaybackState.swift boringNotch/components/Music/LyricsTimeline.swift Tests/LyricsTimeline/main.swift
// -o /tmp/dino-lyrics-tests && /tmp/dino-lyrics-tests
import Foundation

var checkCount = 0

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
    checkCount += 1
}

let parsed = LyricsTimeline.parseLRC("""
[ar:Concept artist]
[00:01.5]First phrase
[00:04.050][00:10.125]Repeated phrase
[00:08.00]
[00:70]Invalid timestamp
""")
expect(parsed.count == 4, "Parse repeated timestamps and preserve instrumental markers")
expect(parsed.map(\.time) == [1.5, 4.05, 8, 10.125], "Respect one, two, and three decimal timestamp precision")
expect(parsed[2].text.isEmpty, "Empty timed lines end the previous phrase")

let timeline = LyricsTimeline(synced: parsed, plain: "")
expect(timeline.activeLine(at: 0) == nil, "No active phrase before the vocals start")
expect(timeline.activeLine(at: 1.5) == 0, "Activate at the exact line boundary")
expect(timeline.activeLine(at: 5) == 1, "Follow playback forwards")
expect(timeline.activeLine(at: 8) == 2, "Show an instrumental marker during the gap")
expect(timeline.activeLine(at: 2) == 0, "Follow seeking backwards")
expect(timeline.activeLine(at: 20) == 3, "Keep the final line after its start")

let plain = LyricsTimeline(synced: [], plain: "First line\n\nSecond line")
expect(!plain.isSynced && plain.lines.count == 2, "Plain lyrics remain readable without fabricated timing")
expect(plain.activeLine(at: 15) == nil, "Untimed lyrics do not auto-scroll with playback")
let empty = LyricsTimeline(synced: [], plain: "")
expect(empty.lines.isEmpty && empty.activeLine(at: 0) == nil, "Handle missing lyrics")

var follow = LyricsScrollFollowState()
expect(follow.isFollowingPlayback && !follow.showsSync, "Start by following playback")
follow.beginBrowsing()
expect(!follow.isFollowingPlayback && !follow.showsSync, "Manual input suspends auto-scroll without showing Sync at the anchor")
follow.updateActiveLine(distanceFromAnchor: -65)
expect(follow.showsSync, "Scrolling past the active line reveals Sync")
follow.updateActiveLine(distanceFromAnchor: 90)
expect(follow.showsSync && !follow.isFollowingPlayback, "Browsing earlier lines also reveals Sync and remains detached")
follow.updateActiveLine(distanceFromAnchor: 3)
expect(!follow.showsSync, "Do not show Sync while the active line is at its anchor")
follow.updateActiveLine(distanceFromAnchor: 100)
follow.resume()
expect(follow.isFollowingPlayback && !follow.showsSync, "Sync resumes playback following and clears displacement")
follow.updateActiveLine(distanceFromAnchor: -40)
expect(!follow.showsSync, "Programmatic animation does not reveal Sync")

expect(timeline.inlineText(at: 0) == "First phrase", "Show the first lyric during an intro instead of dropping the compact line")
expect(timeline.inlineText(at: 8.5) == "Repeated phrase", "Keep the last text visible during instrumental markers")
expect(timeline.inlineText(at: 2) == "First phrase", "Compact captions follow backwards seeks")
expect(plain.inlineText(at: 15) == "First line", "Plain captions show a single line")
expect(empty.inlineText(at: 0).isEmpty, "Missing lyrics remain empty")
expect(empty.contentState(isFetching: true) == .loading, "A new track displays a skeleton while loading")
expect(empty.contentState(isFetching: false) == .unavailable, "An empty completed response displays Lyrics not found")
expect(timeline.contentState(isFetching: true) == .loading, "Loading takes precedence over any previous lyrics")
expect(timeline.contentState(isFetching: false) == .available, "Loaded text replaces the skeleton")
let instrumental = LyricsTimeline(synced: [(0, ""), (10, "   ")], plain: "")
expect(instrumental.contentState(isFetching: false) == .unavailable, "Instrumental-only data is not presented as available lyrics")
let resolved = LyricsTimeline.resolveSearchResults([
    ["instrumental": true],
    ["plainLyrics": "  ", "syncedLyrics": ""],
    ["plainLyrics": "Actual lyrics", "syncedLyrics": "[00:01]Actual lyrics"]
])
expect(resolved.plain == "Actual lyrics", "Skip empty and instrumental search matches")
expect(resolved.synced == "[00:01]Actual lyrics", "Preserve timing from the usable match")
let syncedOnly = LyricsTimeline.resolveSearchResults([["syncedLyrics": "[00:02]Timed only"]])
expect(syncedOnly.synced == "[00:02]Timed only", "Accept lyrics that only have timed text")
expect(LyricsTimeline.resolveSearchResults([]).plain.isEmpty, "Handle searches with no matches")

let seekDate = Date(timeIntervalSince1970: 1_000)
var seekState = PlaybackSeekState()
seekState.begin(at: 90, now: seekDate)
expect(!seekState.accepts(position: 12, timestamp: seekDate.addingTimeInterval(-0.1), now: seekDate, isPlaying: true, playbackRate: 1), "An in-flight old poll cannot undo a lyrics jump")
expect(!seekState.accepts(position: 12.1, timestamp: seekDate.addingTimeInterval(0.1), now: seekDate.addingTimeInterval(0.1), isPlaying: true, playbackRate: 1), "Keep the selected position while the seek command is being applied")
expect(seekState.accepts(position: 90.3, timestamp: seekDate.addingTimeInterval(0.3), now: seekDate.addingTimeInterval(0.3), isPlaying: true, playbackRate: 1), "Accept acknowledgement at the selected lyric")
expect(!seekState.accepts(position: 12.1, timestamp: seekDate.addingTimeInterval(0.1), now: seekDate.addingTimeInterval(0.4), isPlaying: true, playbackRate: 1), "A delayed sample cannot replace an acknowledged seek")
expect(seekState.accepts(position: 91, timestamp: seekDate.addingTimeInterval(1), now: seekDate.addingTimeInterval(1), isPlaying: true, playbackRate: 1), "Continue tracking the real playback position after acknowledgement")
seekState.begin(at: 30, now: seekDate.addingTimeInterval(2))
expect(!seekState.accepts(position: 92, timestamp: seekDate.addingTimeInterval(2.1), now: seekDate.addingTimeInterval(2.1), isPlaying: true, playbackRate: 1), "Backward jumps reject the old forward position")
expect(seekState.accepts(position: 30.2, timestamp: seekDate.addingTimeInterval(2.2), now: seekDate.addingTimeInterval(2.2), isPlaying: true, playbackRate: 1), "Acknowledge a backward jump")
seekState.begin(at: 60, now: seekDate.addingTimeInterval(3))
seekState.begin(at: 120, now: seekDate.addingTimeInterval(3.1))
expect(!seekState.accepts(position: 60.2, timestamp: seekDate.addingTimeInterval(3.2), now: seekDate.addingTimeInterval(3.2), isPlaying: true, playbackRate: 1), "The latest rapid selection wins over an earlier seek")
expect(seekState.accepts(position: 120.2, timestamp: seekDate.addingTimeInterval(3.3), now: seekDate.addingTimeInterval(3.3), isPlaying: true, playbackRate: 1), "Acknowledge the latest selected line")
seekState.begin(at: 30, now: seekDate.addingTimeInterval(4))
expect(seekState.accepts(position: 30, timestamp: seekDate.addingTimeInterval(4.5), now: seekDate.addingTimeInterval(4.5), isPlaying: false, playbackRate: 1), "Seeking while paused does not assume playback progression")
seekState.begin(at: 90, now: seekDate.addingTimeInterval(5))
expect(!seekState.accepts(position: 30, timestamp: seekDate.addingTimeInterval(5.5), now: seekDate.addingTimeInterval(5.5), isPlaying: false, playbackRate: 1), "Wait briefly for a delayed seek acknowledgement")
expect(seekState.accepts(position: 30, timestamp: seekDate.addingTimeInterval(7.1), now: seekDate.addingTimeInterval(7.1), isPlaying: false, playbackRate: 1), "Recover to actual playback if the controller rejects the seek")
seekState.begin(at: 60, now: seekDate.addingTimeInterval(8))
seekState.reset()
expect(seekState.accepts(position: 0, timestamp: seekDate, now: seekDate.addingTimeInterval(8), isPlaying: true, playbackRate: 1), "Track/controller changes clear seek protection")

print("Lyrics timeline and scroll following: \(checkCount) checks passed")
