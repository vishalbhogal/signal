// DashboardViewModel.swift
// Signal
//
//  Created by Vishal Bhogal on 27/04/26.
// ─────────────────────────────────────────────────────────────────────────────
// COMBINE — WHY IT'S USED HERE
// ─────────────────────────────────────────────────────────────────────────────
//
// Combine is Apple's reactive framework. Instead of the ViewController
// asking "what's the data right now?", it *subscribes* to publishers
// on the ViewModel and is automatically notified when data changes.
//
// Key concepts used below:
//
//   @Published var x: T
//     Creates a Publisher that emits a new value every time `x` is set.
//     The ViewController subscribes to $x (the projected value).
//
//   AnyCancellable
//     A token returned by .sink() or .assign(). As long as you hold it,
//     the subscription stays alive. When it's deallocated, the subscription
//     is cancelled — preventing zombie subscriptions.
//
//   .receive(on: DispatchQueue.main)
//     Ensures UI updates happen on the main thread, because UIKit is not
//     thread-safe. Async work runs on background threads; this hops back.
//
// ─────────────────────────────────────────────────────────────────────────────

import Foundation
import Combine
import UIKit

// MARK: - Stat Item
struct StatItem: Sendable {
    let title: String
    let value: String
    let unit: String
    let iconName: String
    let bubbleColor: UIColor        // Pastel bubble behind the icon
    let iconColor: UIColor          // Darker tint for the icon itself
    let sparklineValues: [Double]   // 7 daily values for the mini sparkline
}

extension StatItem: Hashable {
    static func == (lhs: StatItem, rhs: StatItem) -> Bool {
        lhs.title == rhs.title && lhs.value == rhs.value && lhs.unit == rhs.unit
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(value)
        hasher.combine(unit)
    }
}

// MARK: - Dashboard State
enum DashboardState {
    case idle                   // App just launched, nothing loaded yet
    case loading                // Async fetch is in progress
    case loaded(DashboardData)  // Data is ready — pass it as associated value
    case error(String)          // Something went wrong — show error message
}


struct DashboardData {
    let riskScore: BurnoutRiskScore
    let snapshots: [DailyHealthSnapshot]
    let insights: [HealthInsight]
    let features: WeeklyBehavioralFeatures
    let statItems: [StatItem]
}

// MARK: - ViewModel
@MainActor
final class DashboardViewModel: ObservableObject {
    // MARK: Published State
    @Published private(set) var state: DashboardState = .idle
    
    // MARK: Dependencies
    private let healthService: HealthDataServiceProtocol
    private let riskEngine: BurnoutRiskEngineProtocol

    // MARK: Init
    init(healthService: HealthDataServiceProtocol,
         riskEngine: BurnoutRiskEngineProtocol) {
        self.healthService = healthService
        self.riskEngine = riskEngine
    }

    // MARK: - Data Loading
    func loadData() {
        state = .loading

        // Task { } creates a new async context from a sync context.
        // Without Task, you can't call `await` inside a regular function.
        Task {
            do {
                let snapshots = try await healthService.fetchWeeklySnapshots()
                let features  = WeeklyBehavioralFeatures.compute(from: snapshots)
                let riskScore = try await riskEngine.predict(features: features)
                let insights = InsightGenerator.generateInsights(from: features)
                let statItems = Self.buildStatItems(from: features, snapshots: snapshots)
                state = .loaded(DashboardData(
                    riskScore: riskScore,
                    snapshots: snapshots,
                    insights: insights,
                    features: features,
                    statItems: statItems
                ))
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Stat Item Builder
    static func buildStatItems(from features: WeeklyBehavioralFeatures,
                               snapshots: [DailyHealthSnapshot]) -> [StatItem] {
        // Sort oldest → newest so the sparkline reads left-to-right in time.
        let sorted = snapshots.sorted { $0.date < $1.date }
        return [
            StatItem(
                title: "Sleep",
                value: String(format: "%.1f", features.avgSleepHours),
                unit: "hrs",
                iconName: "moon.fill",
                bubbleColor: Signal.Colors.sleepBubble,
                iconColor:   Signal.Colors.sleepIcon,
                sparklineValues: sorted.map { $0.sleepHours }
            ),
            StatItem(
                title: "Steps",
                value: "\(Int(features.avgStepCount))",
                unit: "avg",
                iconName: "figure.walk",
                bubbleColor: Signal.Colors.stepsBubble,
                iconColor:   Signal.Colors.stepsIcon,
                sparklineValues: sorted.map { Double($0.stepCount) / 1000 }
            ),
            StatItem(
                title: "HRV",
                value: "\(Int(features.avgHRV))",
                unit: "ms",
                iconName: "waveform.path.ecg",
                bubbleColor: Signal.Colors.hrvBubble,
                iconColor:   Signal.Colors.hrvIcon,
                sparklineValues: sorted.map { $0.heartRateVariability }
            ),
            StatItem(
                title: "Shift",
                value: String(format: "%.1f", features.avgWorkHours),
                unit: "hrs",
                iconName: "briefcase.fill",
                bubbleColor: Signal.Colors.workBubble,
                iconColor:   Signal.Colors.workIcon,
                sparklineValues: sorted.map { $0.workHours }
            )
        ]
    }
}
