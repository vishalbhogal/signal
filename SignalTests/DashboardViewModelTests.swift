//
//  DashboardViewModelTests.swift
//  Signal
//
//  Created by Vishal Bhogal on 27/04/26.
//


import XCTest
@testable import Signal

// MARK: - Dashboard ViewModel Tests

@MainActor
final class DashboardViewModelTests: XCTestCase {

    func test_initialState_isIdle() {
        let vm = DashboardViewModel(
            healthService: MockHealthDataService(),
            riskEngine: MockBurnoutRiskEngine()
        )
        if case .idle = vm.state { } else {
            XCTFail("Expected .idle, got \(vm.state)")
        }
    }

    func test_loadData_transitionsToLoaded() async throws {
        let vm = DashboardViewModel(
            healthService: MockHealthDataService(),
            riskEngine: MockBurnoutRiskEngine()
        )
        vm.loadData()

        // Poll until loaded — the mock has a 0.4 s delay.
        try await Task.sleep(nanoseconds: 1_000_000_000)

        if case .loaded(let data) = vm.state {
            XCTAssertEqual(data.snapshots.count, 7)
            XCTAssertEqual(data.statItems.count, 4)
            XCTAssertFalse(data.insights.isEmpty)
        } else {
            XCTFail("Expected .loaded, got \(vm.state)")
        }
    }

    func test_loadData_withFailingService_transitionsToError() async throws {
        let vm = DashboardViewModel(
            healthService: FailingHealthDataService(),
            riskEngine: MockBurnoutRiskEngine()
        )
        vm.loadData()
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 s — no delay in failing mock

        if case .error = vm.state { } else {
            XCTFail("Expected .error, got \(vm.state)")
        }
    }

    func test_statItems_matchFeaturesDerivedFromSameSnapshots() async throws {
        let vm = DashboardViewModel(
            healthService: MockHealthDataService(),
            riskEngine: MockBurnoutRiskEngine()
        )
        vm.loadData()
        try await Task.sleep(nanoseconds: 1_000_000_000)

        guard case .loaded(let data) = vm.state else {
            return XCTFail("Not loaded")
        }

        // Sleep stat value must match the average derived from the same snapshots.
        let sleepStat = data.statItems.first { $0.title == "Sleep" }!
        let expectedSleep = String(format: "%.1f", data.features.avgSleepHours)
        XCTAssertEqual(sleepStat.value, expectedSleep,
                       "Stat chip value must match ViewModel features — not a separate random draw")
    }

    // MARK: buildStatItems (pure, no async)

    func test_buildStatItems_returnsAllFourMetrics() {
        let features = WeeklyBehavioralFeatures(
            avgSleepHours: 7, avgStepCount: 5_000, avgActiveMinutes: 25,
            avgHRV: 42, avgWorkHours: 9, sleepDeficitDays: 1, highWorkloadDays: 1
        )
        let snaps = (0..<7).map { i -> DailyHealthSnapshot in
            DailyHealthSnapshot(
                id: UUID(),
                date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!,
                sleepHours: 7, stepCount: 5_000, activeMinutes: 25,
                heartRateVariability: 42, workHours: 9
            )
        }
        let items = DashboardViewModel.buildStatItems(from: features, snapshots: snaps)
        XCTAssertEqual(items.count, 4)
        let titles = items.map(\.title)
        XCTAssertEqual(titles, ["Sleep", "Steps", "HRV", "Shift"])
    }

    func test_buildStatItems_sparklineLength_matchesSnapshotCount() {
        let features = WeeklyBehavioralFeatures(
            avgSleepHours: 7, avgStepCount: 5_000, avgActiveMinutes: 25,
            avgHRV: 42, avgWorkHours: 9, sleepDeficitDays: 0, highWorkloadDays: 0
        )
        let snaps = (0..<7).map { i -> DailyHealthSnapshot in
            DailyHealthSnapshot(
                id: UUID(),
                date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!,
                sleepHours: 7, stepCount: 5_000, activeMinutes: 25,
                heartRateVariability: 42, workHours: 9
            )
        }
        let items = DashboardViewModel.buildStatItems(from: features, snapshots: snaps)
        for item in items {
            XCTAssertEqual(item.sparklineValues.count, 7,
                           "\(item.title) sparkline should have 7 points for 7 days")
        }
    }
}

// MARK: - Test Doubles

/// A health service that always throws — used to verify the ViewModel's error state.
private final class FailingHealthDataService: HealthDataServiceProtocol {
    func fetchWeeklySnapshots() async throws -> [DailyHealthSnapshot] {
        throw URLError(.notConnectedToInternet)
    }
    func fetchProfile() async throws -> ClinicianProfile {
        throw URLError(.notConnectedToInternet)
    }
}