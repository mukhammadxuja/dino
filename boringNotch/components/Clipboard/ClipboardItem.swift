//
//  ClipboardItem.swift
//  boringNotch
//
//  Created for Dino Architecture Evolution.
//

import AppKit
import Foundation
import SwiftUI

public enum ClipboardItemType: String, Codable, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case text = "Text"
    case link = "Links"
    case image = "Images"
    case color = "Colors"
    case file = "Files"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .text: return "doc.text.fill"
        case .link: return "link"
        case .image: return "photo.fill"
        case .color: return "paintpalette.fill"
        case .file: return "folder.fill"
        }
    }
}

public struct ClipboardItem: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let type: ClipboardItemType
    public let stringValue: String?
    public let imageData: Data?
    public let previewTitle: String
    public let previewSubtitle: String
    public let sourceAppName: String?
    public let timestamp: Date
    public var isPinned: Bool

    public init(
        id: UUID = UUID(),
        type: ClipboardItemType,
        stringValue: String? = nil,
        imageData: Data? = nil,
        previewTitle: String,
        previewSubtitle: String,
        sourceAppName: String? = nil,
        timestamp: Date = Date(),
        isPinned: Bool = false
    ) {
        self.id = id
        self.type = type
        self.stringValue = stringValue
        self.imageData = imageData
        self.previewTitle = previewTitle
        self.previewSubtitle = previewSubtitle
        self.sourceAppName = sourceAppName
        self.timestamp = timestamp
        self.isPinned = isPinned
    }

    public var formattedTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r, g, b, a: Double
        if hexSanitized.count == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if hexSanitized.count == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

