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

// MARK: - Badge Store

// We use it here to remember:
//   1. How many parks the user has visited (an Int)
//   2. Which badge IDs they've already earned (an array of Strings)
// ─────────────────────────────────────────────────────────────────────────────

final class BadgeStore {
    // one source of truth
    // for persistent state (like a visit counter).
    static let shared = BadgeStore()
    private let defaults: UserDefaults
    private let earnedKey = "signal.earnedBadgeIDs"
    private let visitKey  = "signal.parkVisitCount"
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var parkVisitCount: Int {
        get { defaults.integer(forKey: visitKey) }
        set { defaults.set(newValue, forKey: visitKey) }
    }

    var earnedBadgeIDs: Set<String> {
        Set(defaults.stringArray(forKey: earnedKey) ?? [])
    }

    @discardableResult
    func recordParkVisit() -> [BadgeDefinition] {
        parkVisitCount += 1
        return checkAndAward()
    }

    // This runs after every visit
    private func checkAndAward() -> [BadgeDefinition] {
        let already = earnedBadgeIDs
        let count = parkVisitCount

        // Find badges that are BOTH:
        //   a) not already earned
        //   b) threshold is now met
        let newly = BadgeDefinition.all.filter { !already.contains($0.id) && count >= $0.threshold }
        if !newly.isEmpty {
            let updated = already.union(newly.map { $0.id })
            defaults.set(Array(updated), forKey: earnedKey)
        }

        // Return the newly earned badges so the ViewController can show an alert.
        return newly
    }
}
