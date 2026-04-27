//
//  BurnoutRiskEngineTests.swift
//  Signal
//
//  Created by Vishal Bhogal on 27/04/26.
//


import XCTest
@testable import Signal

// MARK: - Burnout Risk Engine Tests

final class BurnoutRiskEngineTests: XCTestCase {

    private let engine = MockBurnoutRiskEngine()

    // Helper — builds a features struct from simple named arguments.
    private func features(
        sleep: Double = 8,
        hrv: Double = 70,
        work: Double = 8,
        steps: Double = 10_000,
        activeMinutes: Double = 30,
        sleepDeficitDays: Int = 0,
        highWorkloadDays: Int = 0
    ) -> WeeklyBehavioralFeatures {
        WeeklyBehavioralFeatures(
            avgSleepHours: sleep,
            avgStepCount: steps,
            avgActiveMinutes: activeMinutes,
            avgHRV: hrv,
            avgWorkHours: work,
            sleepDeficitDays: sleepDeficitDays,
            highWorkloadDays: highWorkloadDays
        )
    }

    func test_idealInputs_produceLowRisk() async throws {
        // Perfect sleep, HRV, steps, work hours → should be well below 0.35.
        let score = try await engine.predict(features: features())
        XCTAssertEqual(score.level, .low)
        XCTAssertLessThan(score.score, 0.35)
    }

    func test_wornDownInputs_produceHighRisk() async throws {
        // Worst-case: 4 h sleep, 20 ms HRV, 14 h work, 0 steps.
        let score = try await engine.predict(features: features(
            sleep: 4, hrv: 20, work: 14, steps: 0, activeMinutes: 0
        ))
        XCTAssertEqual(score.level, .high)
        XCTAssertGreaterThan(score.score, 0.65)
    }

    func test_borderlineInputs_produceModerateRisk() async throws {
        // Values close to midpoints of each scale.
        let score = try await engine.predict(features: features(
            sleep: 6, hrv: 20, work: 12, steps: 2_000, activeMinutes: 10
        ))
        XCTAssertEqual(score.level, .moderate)
        XCTAssertGreaterThanOrEqual(score.score, 0.35)
        XCTAssertLessThan(score.score, 0.65)
    }

    func test_scoreIsAlwaysClampedBetweenZeroAndOne() async throws {
        // Extreme bad inputs — score must never exceed 1.0.
        let bad = try await engine.predict(features: features(
            sleep: 0, hrv: 0, work: 24, steps: 0, activeMinutes: 0
        ))
        XCTAssertLessThanOrEqual(bad.score, 1.0)
        XCTAssertGreaterThanOrEqual(bad.score, 0.0)

        // Extreme good inputs — score must never go below 0.0.
        let good = try await engine.predict(features: features(
            sleep: 12, hrv: 200, work: 0, steps: 50_000, activeMinutes: 120
        ))
        XCTAssertGreaterThanOrEqual(good.score, 0.0)
        XCTAssertLessThanOrEqual(good.score, 1.0)
    }

    func test_scoreDate_isRecentlySet() async throws {
        let before = Date()
        let score = try await engine.predict(features: features())
        let after = Date()
        XCTAssertGreaterThanOrEqual(score.date, before)
        XCTAssertLessThanOrEqual(score.date, after)
    }
}