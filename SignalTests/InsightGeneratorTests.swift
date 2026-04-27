//
//  InsightGeneratorTests.swift
//  Signal
//
//  Created by Vishal Bhogal on 27/04/26.
//

import XCTest
@testable import Signal

// MARK: - Insight Generator Tests

final class InsightGeneratorTests: XCTestCase {

    private func features(
        sleepDeficit: Int = 0,
        avgHRV: Double = 50,
        highWorkloadDays: Int = 0,
        avgSteps: Double = 7_000
    ) -> WeeklyBehavioralFeatures {
        WeeklyBehavioralFeatures(
            avgSleepHours: 7,
            avgStepCount: avgSteps,
            avgActiveMinutes: 30,
            avgHRV: avgHRV,
            avgWorkHours: 8,
            sleepDeficitDays: sleepDeficit,
            highWorkloadDays: highWorkloadDays
        )
    }

    func test_noFlags_returnsPositiveInsight() {
        let insights = InsightGenerator.generateInsights(from: features())
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.title, "Looking good this week")
    }

    func test_sleepDeficit3Days_triggersSleepInsight() {
        let insights = InsightGenerator.generateInsights(from: features(sleepDeficit: 3))
        XCTAssertTrue(insights.contains { $0.title == "Sleep debt detected" })
    }

    func test_sleepDeficit2Days_doesNotTrigger() {
        // Threshold is 3 — 2 days must NOT fire the rule.
        let insights = InsightGenerator.generateInsights(from: features(sleepDeficit: 2))
        XCTAssertFalse(insights.contains { $0.title == "Sleep debt detected" })
    }

    func test_lowHRV_triggersHRVInsight() {
        let insights = InsightGenerator.generateInsights(from: features(avgHRV: 34))
        XCTAssertTrue(insights.contains { $0.title == "Low heart rate variability" })
    }

    func test_normalHRV_doesNotTrigger() {
        // Threshold is < 35 — exactly 35 must NOT fire.
        let insights = InsightGenerator.generateInsights(from: features(avgHRV: 35))
        XCTAssertFalse(insights.contains { $0.title == "Low heart rate variability" })
    }

    func test_highWorkload4Days_triggersOverworkInsight() {
        let insights = InsightGenerator.generateInsights(from: features(highWorkloadDays: 4))
        XCTAssertTrue(insights.contains { $0.title == "Extended work hours pattern" })
    }

    func test_lowSteps_triggersActivityInsight() {
        let insights = InsightGenerator.generateInsights(from: features(avgSteps: 3_999))
        XCTAssertTrue(insights.contains { $0.title == "Low physical activity" })
    }

    func test_multipleFlags_areOrderedByPriority() {
        // All four rules fire simultaneously.
        let all = features(sleepDeficit: 3, avgHRV: 20, highWorkloadDays: 5, avgSteps: 1_000)
        let insights = InsightGenerator.generateInsights(from: all)
        // Priority 1 < 2 < 3 < 4 — must appear in ascending order.
        let priorities = insights.map { $0.priority }
        XCTAssertEqual(priorities, priorities.sorted())
    }

    func test_allFlagsActive_returnsExactlyFourInsights() {
        let all = features(sleepDeficit: 5, avgHRV: 10, highWorkloadDays: 6, avgSteps: 500)
        XCTAssertEqual(InsightGenerator.generateInsights(from: all).count, 4)
    }
}
