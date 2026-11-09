// xcrun swiftc -module-cache-path /tmp/dino-lock-art-cache boringNotch/models/LockScreenArtworkLayout.swift Tests/LockScreenArtwork/main.swift -o /tmp/dino-lock-art-check && /tmp/dino-lock-art-check
import Foundation
import CoreGraphics

var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
    checks += 1
}

for frame in [CGRect(x: 0, y: 0, width: 1470, height: 956),
              CGRect(x: 0, y: 0, width: 1280, height: 800),
              CGRect(x: -1920, y: 0, width: 1920, height: 1080),
              CGRect(x: 1470, y: -200, width: 2560, height: 1440)] {
    for offset: CGFloat in [130, 185] {
        let layout = LockScreenArtworkLayout(screenFrame: frame, playerBottomOffset: offset)
        expect(layout.canExpand, "Artwork fits a normal display")
        expect(frame.contains(layout.artworkFrame), "Artwork stays on its own display")
        expect(abs(layout.artworkFrame.midX - frame.midX) < 0.001, "Artwork is horizontally centered")
        expect(layout.artworkFrame.width == layout.artworkFrame.height, "Artwork stays square")
        expect(layout.artworkFrame.width <= min(420, frame.width * 0.28, frame.height * 0.34), "Cover size adapts to display dimensions")
        expect(layout.artworkFrame.minY >= layout.playerFrame.maxY + 24, "The expanded cover does not cover playback controls")
        expect(layout.artworkFrame.maxY <= frame.maxY - LockScreenArtworkLayout.clockTop(for: frame.height) - 45 + 0.01, "Artwork stays below the compact clock/date row")
        let upper = frame.maxY - LockScreenArtworkLayout.clockTop(for: frame.height) - 45
        let lower = layout.playerFrame.maxY + 24
        expect(abs((upper - layout.artworkFrame.maxY) - (layout.artworkFrame.minY - lower)) < 0.01, "Artwork is centered between the clock and player")
        expect(layout.playerFrame.minY == frame.minY + offset, "Preserve the native passcode clearance on offset displays")
    }
}
for frame in [CGRect(x: 0, y: 0, width: 1470, height: 956),
              CGRect(x: -1920, y: -100, width: 1920, height: 1080),
              CGRect(x: 0, y: 0, width: 1280, height: 800)] {
    let single = LockScreenArtworkLayout(screenFrame: frame, playerBottomOffset: 185)
    let split = LockScreenArtworkLayout(screenFrame: frame, playerBottomOffset: 185, showingLyrics: true)
    expect(split.canExpand, "The cover and lyrics fit a supported display")
    expect(split.artworkFrame.midX < single.artworkFrame.midX, "The cover moves left when lyrics open")
    expect(split.lyricsFrame.minX > split.artworkFrame.maxX, "Lyrics appear to the right of the cover")
    expect(frame.contains(split.lyricsFrame), "Lyrics remain on the correct display")
    expect(split.lyricsFrame.minY >= split.playerFrame.maxY + 24 - 0.01, "Lyrics do not cover the compact player")
    expect(abs(split.lyricsFrame.midY - split.artworkFrame.midY) < 0.01, "Lyrics and artwork align at their vertical centers")
    let availableHeight = frame.maxY - LockScreenArtworkLayout.clockTop(for: frame.height) - 45 - split.playerFrame.maxY - 24
    expect(split.lyricsFrame.height < min(460, availableHeight), "Lyrics leave a little extra space on smaller displays")
    expect(split.lyricsFrame.height > split.artworkFrame.height, "Lyrics remain taller than the cover on common displays")
    expect(split.lyricsFrame.maxY <= frame.maxY - LockScreenArtworkLayout.clockTop(for: frame.height) - 25 + 0.01, "Lyrics leave clearance below the clock")
    expect(split.artworkWindowFrame.contains(split.artworkFrame.insetBy(dx: -78, dy: -78)), "Shadow margins include three blur radii and the vertical offset")
    expect(split.artworkFrame.width <= min(frame.width * 0.28, frame.height * 0.34), "Split cover respects the same responsive size cap")
}
expect(LockScreenMediaMode.artwork.isExpanded && LockScreenMediaMode.lyrics.isExpanded, "Artwork and lyrics share the expanded session")
expect(!LockScreenMediaMode.compact.isExpanded, "Compact mode restores the normal display selection")
let row = LockScreenClockRowLayout(centerX: 640, timeWidth: 64, dateWidth: 240)
expect(row.timeCenterX + 32 < row.dateCenterX - 120, "Time appears before the date, separated by a gap")
expect((row.timeCenterX - 32 + row.dateCenterX + 120) / 2 == 640, "The combined clock/date row stays centered")
let laptop = LockScreenArtworkLayout(screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956), playerBottomOffset: 185)
let desktop = LockScreenArtworkLayout(screenFrame: CGRect(x: 0, y: 0, width: 2560, height: 1440), playerBottomOffset: 185)
expect(laptop.artworkFrame.width < desktop.artworkFrame.width, "Built-in sized displays get a smaller cover than large external displays")
expect(laptop.artworkFrame.width < 350, "The laptop cover stays comfortably below the previous 431-point size")
let small = LockScreenArtworkLayout(screenFrame: CGRect(x: 0, y: 0, width: 640, height: 480), playerBottomOffset: 185)
expect(!small.canExpand, "Do not expand where artwork would obscure authentication or playback")
expect(small.artworkFrame.width >= 0, "Small displays never produce negative layout sizes")
let iso = ISO8601DateFormatter()
let utc = TimeZone(secondsFromGMT: 0)!
expect(LockScreenClockRowLayout.dateText(for: iso.date(from: "2026-11-09T12:00:00Z")!, timeZone: utc) == "Mon 9 Nov", "Date uses the requested short weekday/day/month order")
expect(LockScreenClockRowLayout.dateText(for: iso.date(from: "2026-11-01T12:00:00Z")!, timeZone: utc) == "Sun 1 Nov", "Single digit dates have no leading zero")
expect(LockScreenClockRowLayout.dateText(for: iso.date(from: "2026-11-08T22:00:00Z")!, timeZone: TimeZone(identifier: "Asia/Tashkent")!) == "Mon 9 Nov", "Date respects the local time zone across midnight")
expect(LockScreenClockRowLayout.dateText(for: iso.date(from: "2027-01-01T12:00:00Z")!, timeZone: utc) == "Fri 1 Jan", "Month names remain abbreviated across the year boundary")
print("Lock screen artwork layout: \(checks) checks passed")
