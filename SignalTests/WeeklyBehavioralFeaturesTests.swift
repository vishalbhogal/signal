//
//  WeeklyBehavioralFeaturesTests.swift
//  Signal
//
//  Created by Vishal Bhogal on 27/04/26.
//

import XCTest
@testable import Signal
// MARK: - WeeklyBehavioralFeatures compute(from:) Tests

final class WeeklyBehavioralFeaturesTests: XCTestCase {

    private func makeSnapshot(
        daysAgo: Int,
        sleep: Double,
        steps: Int,
        hrv: Double,
        work: Double,
        activeMinutes: Int = 30
    ) -> DailyHealthSnapshot {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return DailyHealthSnapshot(
            id: UUID(),
            date: date,
            sleepHours: sleep,
            stepCount: steps,
            activeMinutes: activeMinutes,
            heartRateVariability: hrv,
            workHours: work
        )
    }

    func test_compute_averagesCorrectly() {
        let snaps = [
            makeSnapshot(daysAgo: 0, sleep: 6, steps: 4_000, hrv: 30, work: 10),
            makeSnapshot(daysAgo: 1, sleep: 8, steps: 8_000, hrv: 50, work: 8),
        ]
        let f = WeeklyBehavioralFeatures.compute(from: snaps)
        XCTAssertEqual(f.avgSleepHours, 7.0, accuracy: 0.001)
        XCTAssertEqual(f.avgStepCount, 6_000, accuracy: 0.001)
        XCTAssertEqual(f.avgHRV, 40.0, accuracy: 0.001)
        XCTAssertEqual(f.avgWorkHours, 9.0, accuracy: 0.001)
    }

    func test_compute_sleepDeficitDays_countedCorrectly() {
        // Sleep < 6.0 h counts as a deficit day.
        let snaps = [
            makeSnapshot(daysAgo: 0, sleep: 5.9, steps: 5_000, hrv: 40, work: 8), // deficit
            makeSnapshot(daysAgo: 1, sleep: 6.0, steps: 5_000, hrv: 40, work: 8), // not deficit (boundary)
            makeSnapshot(daysAgo: 2, sleep: 4.5, steps: 5_000, hrv: 40, work: 8), // deficit
        ]
        let f = WeeklyBehavioralFeatures.compute(from: snaps)
        XCTAssertEqual(f.sleepDeficitDays, 2)
    }

    func test_compute_highWorkloadDays_countedCorrectly() {
        // Work > 10.0 h counts as a high-workload day.
        let snaps = [
            makeSnapshot(daysAgo: 0, sleep: 7, steps: 5_000, hrv: 40, work: 10.1), // high
            makeSnapshot(daysAgo: 1, sleep: 7, steps: 5_000, hrv: 40, work: 10.0), // not high (boundary)
            makeSnapshot(daysAgo: 2, sleep: 7, steps: 5_000, hrv: 40, work: 9.9),  // not high
        ]
        let f = WeeklyBehavioralFeatures.compute(from: snaps)
        XCTAssertEqual(f.highWorkloadDays, 1)
    }

    func test_compute_emptyArray_returnsZeroedFeatures() {
        let f = WeeklyBehavioralFeatures.compute(from: [])
        XCTAssertEqual(f.avgSleepHours, 0)
        XCTAssertEqual(f.avgHRV, 0)
        XCTAssertEqual(f.sleepDeficitDays, 0)
    }
}
