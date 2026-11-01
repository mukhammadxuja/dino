import Foundation

// Keeps the on-disk schema independent of MainActor-isolated UI models.
struct ShelfItemRecord: Codable, Equatable, Sendable {
    let id: UUID
    let kind: ShelfItemKind
    let isTemporary: Bool

    @MainActor init(_ item: ShelfItem) {
        id = item.id
        kind = item.kind
        isTemporary = item.isTemporary
    }

    @MainActor func makeItem() -> ShelfItem {
        ShelfItem(id: id, kind: kind, isTemporary: isTemporary)
    }
}

// The serial queue owns all file access and lastSavedRecords.
final class ShelfPersistenceService: @unchecked Sendable {
    static let shared = ShelfPersistenceService()
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.mukhammadxuja.dino.shelf.persistence", qos: .utility)
    private var lastSavedRecords: [ShelfItemRecord]?

    init(fileURL: URL? = nil) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.fileURL = fileURL ?? support.appendingPathComponent("boringNotch/Shelf/items.json")
    }

    @MainActor func load() async -> [ShelfItem] {
        let records: [ShelfItemRecord] = await withCheckedContinuation { continuation in
            queue.async {
                let records = self.loadRecords()
                self.lastSavedRecords = records
                continuation.resume(returning: records)
            }
        }
        return records.map { $0.makeItem() }
    }

    @MainActor func save(_ items: [ShelfItem]) {
        let records = items.map(ShelfItemRecord.init)
        // Enqueue synchronously so successive main-actor mutations keep their order.
        queue.async {
            guard records != self.lastSavedRecords else { return }
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted]
                let data = try encoder.encode(records)
                try FileManager.default.createDirectory(at: self.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: self.fileURL, options: .atomic)
                self.lastSavedRecords = records
            } catch {
                NSLog("Failed to save shelf items: %@", error.localizedDescription)
            }
        }
    }

    /// Only used during app termination, after UI work has stopped.
    func flush() {
        queue.sync {}
    }

    private func loadRecords() -> [ShelfItemRecord] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        if let records = try? decoder.decode([ShelfItemRecord].self, from: data) {
            return records
        }
        // Preserve the existing recovery of valid entries in a partially damaged file.
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return [] }
        return array.compactMap { value in
            guard JSONSerialization.isValidJSONObject(value),
                  let itemData = try? JSONSerialization.data(withJSONObject: value) else { return nil }
            return try? decoder.decode(ShelfItemRecord.self, from: itemData)
        }
    }
}
