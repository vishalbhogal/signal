// Badge.swift
// Signal
//
// Created by Vishal Bhogal on 27/04/26.

import Foundation

// MARK: - Badge Definition

struct BadgeDefinition {
    let id: String
    let title: String
    let description: String
    let symbolName: String

    // How many park/landmark visits unlock this badge
    let threshold: Int

    static let all: [BadgeDefinition] = [
        BadgeDefinition(id: "explorer_1",  title: "Fresh Air",     description: "Visited your first nearby park",     symbolName: "leaf.fill",      threshold: 1),
        BadgeDefinition(id: "explorer_5",  title: "Park Hopper",   description: "Visited 5 parks or landmarks",       symbolName: "tree.fill",      threshold: 5),
        BadgeDefinition(id: "explorer_10", title: "Nature Seeker", description: "Visited 10 parks or landmarks",      symbolName: "mountain.2.fill",threshold: 10),
        BadgeDefinition(id: "explorer_25", title: "Trail Blazer",  description: "Visited 25 parks or landmarks",      symbolName: "figure.hiking",  threshold: 25),
    ]
}

// MARK: - Badge Cache Key
//
// A type-safe enum for the keys we store in TwoLevelCache.
// Using an enum instead of raw strings prevents typos like
// "badge.visitcount" vs "badge.visitCount" causing silent cache misses.
//
// CustomStringConvertible is required by DiskCache so it can turn the key
// into a filename (e.g. "visitCount.json" on disk).
enum BadgeCacheKey: String, CustomStringConvertible {
    case visitCount = "visitCount"
    case earnedIDs  = "earnedIDs"

    // `description` is what CustomStringConvertible requires.
    // DiskCache calls "\(key)" which invokes this → becomes the JSON filename.
    var description: String { rawValue }
}

// MARK: - Badge Store
//
// ─────────────────────────────────────────────────────────────────────────────
// CACHING STRATEGY
// ─────────────────────────────────────────────────────────────────────────────
//
// BadgeStore uses TWO separate TwoLevelCache instances because each piece of
// data has a different type (Int vs [String]):
//
//   visitCache  — TwoLevelCache<BadgeCacheKey, Int>
//                 Stores the park visit counter (e.g. 5).
//
//   badgeCache  — TwoLevelCache<BadgeCacheKey, [String]>
//                 Stores earned badge IDs as an array (e.g. ["explorer_1","explorer_5"]).
//                 Set<String> isn't storable directly; we convert to/from [String].
//
// Each cache is two-level (L1 memory → L2 disk).
// On first launch both caches are empty → MISS → store returns a default.
// After the first write, subsequent reads get a memory HIT (fast path).
// After an app restart, memory is cold → MISS on L1 → HIT on L2 → L1 is warmed.
// ─────────────────────────────────────────────────────────────────────────────

final class BadgeStore {

    // ── Singleton ─────────────────────────────────────────────────────────────
    // Production code uses BadgeStore.shared so there is one counter for the app.
    static let shared = BadgeStore()

    // ── Two caches, typed independently ──────────────────────────────────────
    private let visitCache: TwoLevelCache<BadgeCacheKey, Int>
    private let badgeCache: TwoLevelCache<BadgeCacheKey, [String]>

    // ── Init ──────────────────────────────────────────────────────────────────
    // `namespace` scopes the disk cache files to a subfolder.
    // Tests pass a unique UUID namespace → isolated files, no cross-test pollution.
    // Default value means production code just calls BadgeStore().
    init(namespace: String = "signal.badges") {
        visitCache = TwoLevelCache(namespace: "\(namespace).visits")
        badgeCache = TwoLevelCache(namespace: "\(namespace).earned")
    }

    // ── Visit counter ─────────────────────────────────────────────────────────
    // Reading goes through TwoLevelCache.get() — L1 then L2.
    // First read after install: MISS → returns 0 (default).
    // Subsequent reads same session: L1 HIT (memory, instant).
    // Read after app restart: L1 MISS → L2 HIT (disk) → warms L1.
    var parkVisitCount: Int {
        get { visitCache.get(forKey: .visitCount) ?? 0 }
        set { visitCache.set(newValue, forKey: .visitCount) }
    }

    // ── Earned badge IDs ──────────────────────────────────────────────────────
    // Stored as [String] (Codable) and exposed as Set<String> (O(1) contains).
    // First read: MISS → returns empty set (default).
    var earnedBadgeIDs: Set<String> {
        // ?? [] handles the MISS case: no array on disk yet → empty set.
        Set(badgeCache.get(forKey: .earnedIDs) ?? [])
    }

    // ── Public API ────────────────────────────────────────────────────────────
    // Called by ExploreManager when the user taps "Check In".
    @discardableResult
    func recordParkVisit() -> [BadgeDefinition] {
        parkVisitCount += 1      // write new count to both cache levels
        return checkAndAward()
    }

    // ── Private: badge unlock logic ───────────────────────────────────────────
    private func checkAndAward() -> [BadgeDefinition] {
        // Read current state from the cache (will be an L1 HIT — we just wrote).
        let already = earnedBadgeIDs
        let count   = parkVisitCount

        // Filter the badge catalog: not yet earned AND threshold now met.
        let newly = BadgeDefinition.all.filter {
            !already.contains($0.id) && count >= $0.threshold
        }

        if !newly.isEmpty {
            // Merge new badge IDs into the existing set and persist both levels.
            let updated = already.union(newly.map { $0.id })
            badgeCache.set(Array(updated), forKey: .earnedIDs)
        }

        return newly
    }

    // ── Test / logout helper ──────────────────────────────────────────────────
    // Wipes both cache levels for both keys.
    // Called in tearDown() of unit tests to clean up disk files between runs.
    func clearAll() {
        visitCache.clear()
        badgeCache.clear()
    }
}
