//
//  ShelfItem.swift
//  boringNotch
//
//  Created by Alexander on 2025-09-24.
//

import AppKit
import Foundation

enum ShelfItemKind: Codable, Equatable, Sendable {
    case file(bookmark: Data)
    case text(string: String)
    case link(url: URL)

    enum CodingKeys: String, CodingKey { case type, value }

    enum KindTag: String, Codable { case file, text, link }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(KindTag.self, forKey: .type)
        switch type {
        case .file:
            let data = try container.decode(Data.self, forKey: .value)
            self = .file(bookmark: data)
        case .text:
            self = .text(string: try container.decode(String.self, forKey: .value))
        case .link:
            self = .link(url: try container.decode(URL.self, forKey: .value))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .file(let bookmark):
            try container.encode(KindTag.file, forKey: .type)
            try container.encode(bookmark, forKey: .value)
        case .text(let string):
            try container.encode(KindTag.text, forKey: .type)
            try container.encode(string, forKey: .value)
        case .link(let url):
            try container.encode(KindTag.link, forKey: .type)
            try container.encode(url, forKey: .value)
        }
    }

}

@MainActor
struct ShelfItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var kind: ShelfItemKind
    var isTemporary: Bool
    init(id: UUID = UUID(), kind: ShelfItemKind, isTemporary: Bool = false) {
        self.id = id
        self.kind = kind
        self.isTemporary = isTemporary
    }
    
    // Rendering only reads prepared values. File access is handled by ShelfPresentationService.
    var displayName: String {
        ShelfPresentationService.shared.cachedPresentation(for: self)?.displayName ?? fallbackDisplayName
    }

    var fallbackDisplayName: String {
        switch kind {
        case .file:
            return String(localized: "File")
        case .text(let string):
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        case .link(let url):
            let value = url.absoluteString
            if value.hasPrefix("https://") { return String(value.dropFirst(8)) }
            if value.hasPrefix("http://") { return String(value.dropFirst(7)) }
            return value
        }
    }

    var fileURL: URL? {
        guard case .file = kind else { return nil }
        return ShelfStateViewModel.shared.resolveFileURL(for: self)
    }
    
    var URL: URL? {
        if case let .file(bookmark) = kind { return resolvedContext(for: bookmark)?.url }
        else if case let .link(url) = kind { return url }
        else { return nil }
    }
    
    var icon: NSImage {
        ShelfPresentationService.shared.cachedPresentation(for: self)?.icon ?? fallbackIcon
    }

    var fallbackIcon: NSImage {
        switch kind {
        case .file: return Self.fileIcon
        case .text: return Self.textIcon
        case .link: return Self.linkIcon
        }
    }

    private static let fileIcon = thumbnailSymbolImage(systemName: "doc") ?? NSImage()
    private static let textIcon = thumbnailSymbolImage(systemName: "text.justifyleft") ?? NSImage()
    private static let linkIcon = thumbnailSymbolImage(systemName: "link") ?? NSImage()

    func cleanupStoredData() {
        guard case let .file(bookmark) = kind,
              let context = resolvedContext(for: bookmark) else { return }
        
        let url = context.url
        
        // Handle temporary files
        if isTemporary {
            TemporaryFileStorageService.shared.removeTemporaryFileIfNeeded(at: url)
            return
        }
    }
}

private extension ShelfItem {
   static func thumbnailSymbolImage(
        systemName: String,
    size: CGSize = CGSize(width: 64, height: 80), 
    symbolPointSize: CGFloat = 38,
    backgroundColor: NSColor = NSColor.white,
    symbolColor: NSColor = NSColor.labelColor
    ) -> NSImage? {
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let rect = CGRect(origin: .zero, size: size)
        let cornerRadius = min(size.width, size.height) * 0.06
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), xRadius: cornerRadius, yRadius: cornerRadius)
        backgroundColor.setFill()
        path.fill()

        if let symbol = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) {
            let symbolSize = CGSize(width: symbolPointSize, height: symbolPointSize)
            let symbolOrigin = CGPoint(
                x: (size.width - symbolSize.width) / 2,
                y: (size.height - symbolSize.height) / 2
            )
            let symbolRect = CGRect(origin: symbolOrigin, size: symbolSize)
            symbol.draw(in: symbolRect)
        }

        return image
    }
}

// MARK: - Identity key for deduplication
extension ShelfItem {
    var identityKey: String {
        switch kind {
        case .file(let bookmark):
            if let url = resolvedContext(for: bookmark)?.url {
                return "file://" + url.standardizedFileURL.path
            }
            return "file://missing/" + bookmark.base64EncodedString()
        case .link(let u):
            return "link://" + u.absoluteString
        case .text(let s):
            return "text://" + s
        }
    }
}

// MARK: - Private helpers
private extension ShelfItem {
    func resolvedContext(for bookmarkData: Data) -> (url: URL, bookmark: Data)? {
        let bookmark = Bookmark(data: bookmarkData)
        if let url = bookmark.resolveURL() {
            return (url, bookmark.refreshedData ?? bookmarkData)
        }
        return nil
    }
}
