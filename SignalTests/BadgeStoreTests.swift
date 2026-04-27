//
//  BadgeStoreTests 2.swift
//  Signal
//
//  Created by Vishal Bhogal on 27/04/26.
//

import XCTest
@testable import Signal

// MARK: - Badge Store Tests

final class BadgeStoreTests: XCTestCase {

    // Each test needs an isolated store so visits don't bleed between tests.
    // We use a dedicated UserDefaults suite so production defaults are untouched.
    private var defaults: UserDefaults!
    private var store: BadgeStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "SignalTests.\(UUID())")!
        store = BadgeStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaults.description)
        super.tearDown()
    }

    func test_firstVisit_unlocksFirstBadge() {
        let earned = store.recordParkVisit()
        XCTAssertEqual(earned.count, 1)
        XCTAssertEqual(earned.first?.id, "explorer_1")
    }

    func test_sameThreshold_notAwardedTwice() {
        store.recordParkVisit()  // unlocks explorer_1
        let second = store.recordParkVisit()
        XCTAssertFalse(second.contains { $0.id == "explorer_1" })
    }

    func test_reachingHigherThreshold_unlocksCorrectBadge() {
        for _ in 0..<4 { store.recordParkVisit() }
        let fifth = store.recordParkVisit()  // visit #5
        XCTAssertTrue(fifth.contains { $0.id == "explorer_5" })
    }

    func test_parkVisitCount_incrementsEachCall() {
        XCTAssertEqual(store.parkVisitCount, 0)
        store.recordParkVisit()
        XCTAssertEqual(store.parkVisitCount, 1)
        store.recordParkVisit()
        XCTAssertEqual(store.parkVisitCount, 2)
    }

    func test_earnedBadgeIDs_persistAcrossStoreLookups() {
        store.recordParkVisit()
        // Create a second store pointing at the same defaults.
        let store2 = BadgeStore(defaults: defaults)
        XCTAssertTrue(store2.earnedBadgeIDs.contains("explorer_1"))
    }
}
