//
//  BadgeStoreTests.swift
//  Signal
//

import XCTest
@testable import Signal

final class BadgeStoreTests: XCTestCase {

    // Each test gets a unique namespace → isolated disk files + fresh memory cache.
    // No test can accidentally read data written by a previous test.
    private var namespace: String!
    private var store: BadgeStore!

    override func setUp() {
        super.setUp()
        // UUID ensures each test run has its own clean namespace, like a fresh install.
        namespace = "SignalTests.\(UUID().uuidString)"
        store = BadgeStore(namespace: namespace)
    }

    override func tearDown() {
        // Clean up the disk cache files this test wrote, so they don't accumulate.
        store.clearAll()
        super.tearDown()
    }

    func test_firstVisit_unlocksFirstBadge() {
        let earned = store.recordParkVisit()
        XCTAssertEqual(earned.count, 1)
        XCTAssertEqual(earned.first?.id, "explorer_1")
    }

    func test_sameThreshold_notAwardedTwice() {
        store.recordParkVisit()          // unlocks explorer_1
        let second = store.recordParkVisit()
        XCTAssertFalse(second.contains { $0.id == "explorer_1" })
    }

    func test_reachingHigherThreshold_unlocksCorrectBadge() {
        for _ in 0..<4 { store.recordParkVisit() }
        let fifth = store.recordParkVisit()   // visit #5
        XCTAssertTrue(fifth.contains { $0.id == "explorer_5" })
    }

    func test_parkVisitCount_incrementsEachCall() {
        XCTAssertEqual(store.parkVisitCount, 0)
        store.recordParkVisit()
        XCTAssertEqual(store.parkVisitCount, 1)
        store.recordParkVisit()
        XCTAssertEqual(store.parkVisitCount, 2)
    }

    func test_earnedBadgeIDs_persistAcrossStoreInstances() {
        // Write via store (writes L1 memory + L2 disk).
        store.recordParkVisit()

        // New instance with the SAME namespace → its L1 is cold (empty memory cache).
        // It should get an L2 disk HIT and find the badge we just earned.
        let store2 = BadgeStore(namespace: namespace)
        XCTAssertTrue(store2.earnedBadgeIDs.contains("explorer_1"),
                      "Badge earned in one store instance must persist to another via disk cache")
    }
}
