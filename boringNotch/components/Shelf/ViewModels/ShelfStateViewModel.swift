//
//  ShelfStateViewModel.swift
//  boringNotch
//
//  Created by Alexander on 2025-10-09.

import Foundation
import AppKit

@MainActor
final class ShelfStateViewModel: ObservableObject {
    static let shared = ShelfStateViewModel()

    @Published private(set) var items: [ShelfItem] = [] {
        didSet {
            guard oldValue != items else { return }
            let currentByID = Dictionary(items.map { ($0.id, $0.kind) }, uniquingKeysWith: { _, last in last })
            for old in oldValue where currentByID[old.id] != old.kind {
                ShelfPresentationService.shared.invalidate(old.id)
            }
            if hasLoaded { persistence.save(items) }
        }
    }

    @Published private(set) var isLoading = true
    var isEmpty: Bool { items.isEmpty }

    private let persistence: ShelfPersistenceService
    private var hasLoaded = false
    private var pendingDrops = 0
    private var cleanupTask: Task<Void, Never>?
    private var lastCleanupAt: Date?
    private var pendingBookmarkUpdates: [UUID: (original: Data, refreshed: Data)] = [:]
    private var updateTask: Task<Void, Never>?

    init(persistence: ShelfPersistenceService = .shared) {
        self.persistence = persistence
        Task { [weak self] in
            let stored = await persistence.load()
            guard let self else { return }
            // A drop may have completed while the saved list was loading.
            let pending = self.items
            var merged = stored
            if !pending.isEmpty {
                var seen = Set(stored.map { $0.identityKey })
                for item in pending where seen.insert(item.identityKey).inserted {
                    merged.append(item)
                }
            }
            if self.items != merged { self.items = merged }
            self.hasLoaded = true
            if merged != stored { persistence.save(merged) }
            self.isLoading = self.pendingDrops > 0
        }
    }

    deinit {
        cleanupTask?.cancel()
        updateTask?.cancel()
    }

    func add(_ newItems: [ShelfItem]) {
        guard !newItems.isEmpty else { return }
        var merged = items
        var seen = Set(merged.map { $0.identityKey })
        for item in newItems where seen.insert(item.identityKey).inserted {
            merged.append(item)
        }
        if merged != items { items = merged }
    }

    func remove(_ item: ShelfItem) {
        guard items.contains(where: { $0.id == item.id }) else { return }
        item.cleanupStoredData()
        items.removeAll { $0.id == item.id }
    }

    func updateBookmark(for item: ShelfItem, bookmark: Data) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }),
              items[idx].kind == item.kind,
              case .file(let oldData) = items[idx].kind,
              oldData != bookmark else { return }
        items[idx].kind = .file(bookmark: bookmark)
    }

    private func scheduleDeferredBookmarkUpdate(for item: ShelfItem, bookmark: Data) {
        guard case .file(let original) = item.kind else { return }
        pendingBookmarkUpdates[item.id] = (original, bookmark)
        guard updateTask == nil else { return }
        updateTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled else { return }
            let updates = self.pendingBookmarkUpdates
            self.pendingBookmarkUpdates.removeAll()
            self.updateTask = nil
            var updated = self.items
            for (id, data) in updates {
                if let idx = updated.firstIndex(where: { $0.id == id }),
                   updated[idx].kind == .file(bookmark: data.original) {
                    updated[idx].kind = .file(bookmark: data.refreshed)
                }
            }
            if updated != self.items { self.items = updated }
        }
    }

    func load(_ providers: [NSItemProvider]) {
        guard !providers.isEmpty else { return }
        pendingDrops += 1
        isLoading = true
        Task { [weak self] in
            let dropped = await ShelfDropService.items(from: providers)
            guard let self else { return }
            self.add(dropped)
            self.pendingDrops -= 1
            self.isLoading = !self.hasLoaded || self.pendingDrops > 0
        }
    }

    func cleanupInvalidItems() {
        guard hasLoaded, cleanupTask == nil,
              lastCleanupAt.map({ Date().timeIntervalSince($0) >= 10 }) ?? true else { return }
        lastCleanupAt = Date()
        let snapshot = items.map(ShelfItemRecord.init)
        cleanupTask = Task { [weak self] in
            let invalid = await Task.detached(priority: .utility) {
                snapshot.filter { record in
                    guard case .file(let data) = record.kind else { return false }
                    guard let url = Bookmark(data: data).resolveURL() else { return true }
                    return url.accessSecurityScopedResource { !FileManager.default.fileExists(atPath: $0.path) }
                }
            }.value
            guard let self, !Task.isCancelled else { return }
            self.cleanupTask = nil
            let invalidByID = Dictionary(invalid.map { ($0.id, $0.kind) }, uniquingKeysWith: { _, last in last })
            // Remove only unchanged entries from this snapshot, preserving additions/renames.
            let kept = self.items.filter { invalidByID[$0.id] != $0.kind }
            if kept != self.items { self.items = kept }
        }
    }

    func resolveFileURL(for item: ShelfItem) -> URL? {
        guard case .file(let bookmarkData) = item.kind else { return nil }
        let bookmark = Bookmark(data: bookmarkData)
        let result = bookmark.resolve()
        if let refreshed = result.refreshedData, refreshed != bookmarkData {
            NSLog("Bookmark for \(item) stale; refreshing")
            scheduleDeferredBookmarkUpdate(for: item, bookmark: refreshed)
        }
        return result.url
    }

    func resolveAndUpdateBookmark(for item: ShelfItem) -> URL? {
        guard case .file(let bookmarkData) = item.kind else { return nil }
        let bookmark = Bookmark(data: bookmarkData)
        let result = bookmark.resolve()
        if let refreshed = result.refreshedData, refreshed != bookmarkData {
            NSLog("Bookmark for \(item) stale; refreshing")
            updateBookmark(for: item, bookmark: refreshed)
        }
        return result.url
    }

    func resolveFileURLs(for items: [ShelfItem]) -> [URL] {
        var urls: [URL] = []
        for it in items {
            if let u = resolveFileURL(for: it) { urls.append(u) }
        }
        return urls
    }
}
