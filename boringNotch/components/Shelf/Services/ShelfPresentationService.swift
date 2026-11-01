import AppKit
import Foundation

// Icons are created on the worker and handed off for read-only use by the UI.
struct ShelfItemPresentation: @unchecked Sendable {
    let displayName: String
    let icon: NSImage
    let fileURL: URL?
    let refreshedBookmark: Data?
    let modificationDate: Date?
    let fileSize: Int?
    let localizedName: String?

    var thumbnailRevision: String {
        "\(modificationDate?.timeIntervalSince1970 ?? 0):\(fileSize ?? 0)"
    }
}

@MainActor
final class ShelfPresentationService {
    static let shared = ShelfPresentationService()

    private struct Entry {
        let kind: ShelfItemKind
        let presentation: ShelfItemPresentation
    }
    private struct Request {
        let kind: ShelfItemKind
        let token: UUID
        let task: Task<ShelfItemPresentation?, Never>
    }

    private var cache: [UUID: Entry] = [:]
    private var requests: [UUID: Request] = [:]
    private let worker = DispatchQueue(label: "com.mukhammadxuja.dino.shelf.metadata", qos: .userInitiated)

    func cachedPresentation(for item: ShelfItem) -> ShelfItemPresentation? {
        guard let entry = cache[item.id], entry.kind == item.kind else { return nil }
        return entry.presentation
    }

    func invalidate(_ id: UUID) {
        cache[id] = nil
        requests.removeValue(forKey: id)?.task.cancel()
    }

    func presentation(for item: ShelfItem) async -> ShelfItemPresentation {
        let fallback = cachedPresentation(for: item) ?? ShelfItemPresentation(
            displayName: item.fallbackDisplayName, icon: item.fallbackIcon, fileURL: nil,
            refreshedBookmark: nil, modificationDate: nil, fileSize: nil, localizedName: nil
        )
        guard case .file(let data) = item.kind else { return fallback }

        if let request = requests[item.id], request.kind == item.kind {
            return await request.task.value ?? fallback
        }
        requests.removeValue(forKey: item.id)?.task.cancel()
        let previous = cachedPresentation(for: item)
        let token = UUID()
        let worker = worker
        let task = Task<ShelfItemPresentation?, Never> {
            await withCheckedContinuation { continuation in
                worker.async {
                    continuation.resume(returning: Self.readFilePresentation(bookmarkData: data, previous: previous))
                }
            }
        }
        requests[item.id] = Request(kind: item.kind, token: token, task: task)
        let result = await task.value
        // A rename or removal may invalidate this request while file access is in flight.
        if requests[item.id]?.token == token {
            requests[item.id] = nil
            if let result {
                cache[item.id] = Entry(kind: item.kind, presentation: result)
            }
        }
        return result ?? fallback
    }

    private nonisolated static func readFilePresentation(
        bookmarkData: Data, previous: ShelfItemPresentation?
    ) -> ShelfItemPresentation? {
        let resolved = Bookmark(data: bookmarkData).resolve()
        guard let url = resolved.url else { return nil }
        return url.accessSecurityScopedResource { url in
            let values = try? url.resourceValues(forKeys: [.localizedNameKey, .contentModificationDateKey, .fileSizeKey])
            let name = values?.localizedName ?? url.lastPathComponent
            let unchanged = previous?.fileURL == url
                && previous?.localizedName == name
                && previous?.modificationDate == values?.contentModificationDate
                && previous?.fileSize == values?.fileSize
                && values?.contentModificationDate != nil

            let reusable = unchanged ? previous : nil
            return ShelfItemPresentation(
                displayName: reusable?.displayName ?? readDisplayName(at: url, fallback: name),
                icon: reusable?.icon ?? NSWorkspace.shared.icon(forFile: url.path),
                fileURL: url,
                refreshedBookmark: resolved.refreshedData,
                modificationDate: values?.contentModificationDate,
                fileSize: values?.fileSize,
                localizedName: name
            )
        }
    }

    private nonisolated static func readDisplayName(at url: URL, fallback: String) -> String {
        if url.pathExtension.lowercased() == "json", url.path.contains("TextBlocks") {
            struct TextBlock: Decodable { let content: String; let title: String? }
            if let data = try? Data(contentsOf: url), let block = try? JSONDecoder().decode(TextBlock.self, from: data) {
                if let title = block.title, !title.isEmpty { return title }
                let firstLine = block.content.components(separatedBy: .newlines).first ?? block.content
                return firstLine.count > 50 ? String(firstLine.prefix(47)) + "..." : firstLine
            }
        } else if url.pathExtension.lowercased() == "webloc", url.path.contains("WebLocs") {
            if let data = try? Data(contentsOf: url),
               let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
               let urlString = plist["URL"] as? String {
                return (plist["Title"] as? String) ?? urlString
            }
        }
        return fallback
    }
}
