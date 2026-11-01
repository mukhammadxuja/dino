//
//  ThumbnailService.swift
//  boringNotch
//
//  Created by Alexander on 2025-10-07.
//

import Foundation
import AppKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

actor ThumbnailService {
    static let shared = ThumbnailService()

    private struct BaseKey: Hashable {
        let url: URL
        let width: CGFloat
        let height: CGFloat
    }

    private struct CacheKey: Hashable {
        let base: BaseKey
        let revision: String
    }

    private struct CacheEntry {
        let image: NSImage
        let byteCost: Int
    }

    private struct PendingRequest {
        let id: UUID
        let task: Task<NSImage?, Never>
    }

    private struct RevisionState {
        let revision: String
        let generation: UUID
    }

    private var cache: [CacheKey: CacheEntry] = [:]
    private var accessOrder: [CacheKey] = []
    private var cacheBytes = 0
    private var pendingRequests: [CacheKey: PendingRequest] = [:]
    private var revisions: [BaseKey: RevisionState] = [:]
    private let maxEntries = 128
    private let maxBytes = 32 * 1024 * 1024
    private let thumbnailGenerator = QLThumbnailGenerator.shared

    private init() {}
    
    func thumbnail(for url: URL, size: CGSize, revision: String = "") async -> NSImage? {
        let base = BaseKey(url: url.standardizedFileURL, width: size.width, height: size.height)
        let key = CacheKey(base: base, revision: revision)
        if revisions[base]?.revision != revision {
            revisions[base] = RevisionState(revision: revision, generation: UUID())
            for oldKey in Array(cache.keys) where oldKey.base == base { removeCached(oldKey) }
        }
        guard let generation = revisions[base]?.generation else { return nil }

        if let cached = cache[key] {
            touch(key)
            return cached.image
        }

        if let pending = pendingRequests[key] {
            return await pending.task.value
        }

        let requestID = UUID()
        let task = Task<NSImage?, Never> {
            let thumbnail = await generateQuickLookThumbnail(for: url, size: size)
            if let thumbnail, revisions[base]?.generation == generation {
                store(thumbnail, for: key)
            }
            if pendingRequests[key]?.id == requestID { pendingRequests[key] = nil }
            pruneRevision(for: base)
            return thumbnail
        }

        pendingRequests[key] = PendingRequest(id: requestID, task: task)
        return await task.value
    }

    func clearCache() {
        cache.removeAll()
        accessOrder.removeAll()
        cacheBytes = 0
        pendingRequests.values.forEach { $0.task.cancel() }
        pendingRequests.removeAll()
        revisions.removeAll()
    }

    func clearCache(for url: URL) {
        let fileURL = url.standardizedFileURL
        for key in Array(cache.keys) where key.base.url == fileURL { removeCached(key) }
        for key in Array(pendingRequests.keys) where key.base.url == fileURL {
            pendingRequests.removeValue(forKey: key)?.task.cancel()
        }
        revisions = revisions.filter { $0.key.url != fileURL }
    }

    private func touch(_ key: CacheKey) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    private func removeCached(_ key: CacheKey) {
        if let entry = cache.removeValue(forKey: key) { cacheBytes -= entry.byteCost }
        accessOrder.removeAll { $0 == key }
    }

    private func store(_ image: NSImage, for key: CacheKey) {
        let cost = Int(max(1, image.size.width) * max(1, image.size.height) * 4)
        guard cost <= maxBytes else { return }
        removeCached(key)
        while cache.count >= maxEntries || cacheBytes + cost > maxBytes {
            guard let oldest = accessOrder.first else { break }
            removeCached(oldest)
            pruneRevision(for: oldest.base)
        }
        cache[key] = CacheEntry(image: image, byteCost: cost)
        cacheBytes += cost
        touch(key)
    }

    private func pruneRevision(for base: BaseKey) {
        guard !cache.keys.contains(where: { $0.base == base }),
              !pendingRequests.keys.contains(where: { $0.base == base }) else { return }
        revisions[base] = nil
    }
    
    // MARK: - Private Methods
    
    private func generateQuickLookThumbnail(for url: URL, size: CGSize) async -> NSImage? {
        let scale = await MainActor.run { NSScreen.main?.backingScaleFactor ?? 2.0 }
        
        return await url.accessSecurityScopedResource { scopedURL in
            let request = QLThumbnailGenerator.Request(
                fileAt: scopedURL,
                size: size,
                scale: scale,
                representationTypes: .all
            )
            request.iconMode = true

            return await withCheckedContinuation { (continuation: CheckedContinuation<NSImage?, Never>) in
                thumbnailGenerator.generateBestRepresentation(for: request) { representation, error in
                    if let rep = representation {
                        continuation.resume(returning: rep.nsImage)
                    } else {
                        if let err = error { 
                            NSLog("⚠️ ThumbnailService: thumbnail error for \(scopedURL.path): \(err.localizedDescription)") 
                        }
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
}

// MARK: - Extensions

extension QLThumbnailRepresentation {
    var nsImage: NSImage {
        return NSImage(cgImage: self.cgImage, size: self.cgImage.size)
    }
}

extension CGImage {
    var size: NSSize {
        return NSSize(width: self.width, height: self.height)
    }
}
