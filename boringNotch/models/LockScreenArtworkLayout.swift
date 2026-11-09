import Foundation
import CoreGraphics

enum LockScreenMediaMode {
    case compact, artwork, lyrics

    var isExpanded: Bool { self != .compact }
}

struct LockScreenClockRowLayout {
    let timeCenterX: CGFloat
    let dateCenterX: CGFloat

    init(centerX: CGFloat, timeWidth: CGFloat, dateWidth: CGFloat, spacing: CGFloat = 16) {
        timeCenterX = centerX - (dateWidth + spacing) / 2
        dateCenterX = centerX + (timeWidth + spacing) / 2
    }

    static func dateText(for date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: date)
    }
}

struct LockScreenArtworkLayout {
    static let shadowPadding: CGFloat = 88
    static func clockTop(for height: CGFloat) -> CGFloat {
        min(125, max(70, height * 0.105))
    }
    let screenFrame: CGRect
    let playerFrame: CGRect
    let artworkFrame: CGRect
    let lyricsFrame: CGRect

    init(screenFrame: CGRect, playerBottomOffset: CGFloat, showingLyrics: Bool = false) {
        self.screenFrame = screenFrame
        playerFrame = CGRect(x: screenFrame.midX - 177.5, y: screenFrame.minY + playerBottomOffset, width: 355, height: 176)
        let bottom = playerFrame.maxY + 24
        let top = screenFrame.maxY - Self.clockTop(for: screenFrame.height) - 45
        let widthBudget = showingLyrics ? (screenFrame.width - 144 - 48) / 2 : screenFrame.width - 80
        let responsiveCap = min(420, screenFrame.width * 0.28, screenFrame.height * 0.34)
        let side = max(0, min(responsiveCap, widthBudget, (top - bottom) * 0.9))
        let lyricsWidth = max(0, min(440, widthBudget))
        let groupWidth = showingLyrics ? side + 48 + lyricsWidth : side
        let left = screenFrame.midX - groupWidth / 2
        let centerY = (top + bottom) / 2
        artworkFrame = CGRect(x: left, y: centerY - side / 2, width: side, height: side)
        // Scale the lyrics gently with the display while keeping them centered on the cover.
        let lyricsHeight = max(0, min(460, screenFrame.height * 0.42, (top - bottom) * 0.96))
        lyricsFrame = CGRect(x: left + side + 48, y: centerY - lyricsHeight / 2, width: lyricsWidth, height: lyricsHeight)
    }

    var canExpand: Bool { artworkFrame.width >= 160 }
    var artworkWindowFrame: CGRect { artworkFrame.insetBy(dx: -Self.shadowPadding, dy: -Self.shadowPadding) }
    var lyricsWindowFrame: CGRect { lyricsFrame.insetBy(dx: -Self.shadowPadding, dy: -Self.shadowPadding) }
}
