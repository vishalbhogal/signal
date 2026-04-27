// Badge.swift
// Signal
//
//  Created by Vishal Bhogal on 27/04/26.
// Static badge catalog + UserDefaults-backed store.
// Explorer badges are awarded when the clinician visits parks / landmarks
// via the Explore Nearby section on the Dashboard.

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

// MARK: - Badge Store

/// Persists earned badge IDs and the cumulative park-visit count in UserDefaults.
/// All access is synchronous and safe on the main thread.
final class BadgeStore {

    /// Production singleton — uses the standard UserDefaults suite.
    static let shared = BadgeStore()

    private let defaults: UserDefaults
    private let earnedKey = "signal.earnedBadgeIDs"
    private let visitKey  = "signal.parkVisitCount"

    /// Designated init — accepts any UserDefaults suite so tests can inject an
    /// isolated suite and avoid polluting (or depending on) production storage.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Total number of explore-spot check-ins recorded.
    var parkVisitCount: Int {
        get { defaults.integer(forKey: visitKey) }
        set { defaults.set(newValue, forKey: visitKey) }
    }

    /// Set of badge IDs the user has already earned.
    var earnedBadgeIDs: Set<String> {
        Set(defaults.stringArray(forKey: earnedKey) ?? [])
    }

    /// Increments the visit counter and returns any newly unlocked badges.
    @discardableResult
    func recordParkVisit() -> [BadgeDefinition] {
        parkVisitCount += 1
        return checkAndAward()
    }

    private func checkAndAward() -> [BadgeDefinition] {
        let already = earnedBadgeIDs
        let count   = parkVisitCount
        let newly   = BadgeDefinition.all.filter { !already.contains($0.id) && count >= $0.threshold }
        if !newly.isEmpty {
            let updated = already.union(newly.map { $0.id })
            defaults.set(Array(updated), forKey: earnedKey)
        }
        return newly
    }
}
