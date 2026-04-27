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
enum BadgeCacheKey: String, CustomStringConvertible {
    case visitCount = "visitCount"
    case earnedIDs  = "earnedIDs"
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
    static let shared = BadgeStore()
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

    var parkVisitCount: Int {
        get { visitCache.get(forKey: .visitCount) ?? 0 }
        set { visitCache.set(newValue, forKey: .visitCount) }
    }

    var earnedBadgeIDs: Set<String> {
        Set(badgeCache.get(forKey: .earnedIDs) ?? [])
    }

    @discardableResult
    func recordParkVisit() -> [BadgeDefinition] {
        parkVisitCount += 1
        return checkAndAward()
    }

    private func checkAndAward() -> [BadgeDefinition] {
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
